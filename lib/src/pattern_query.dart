// pattern_query.dart - PetitParser implementation
import 'package:petitparser/petitparser.dart';
import 'cypher_grammar.dart';
import 'cypher_models.dart';
import 'graph.dart';
import 'node.dart';

/// PetitParser-based pattern query implementation
class PatternQuery<N extends Node> {
  final Graph<N> graph;
  late final Parser _parser;

  PatternQuery(this.graph) {
    final definition = CypherPatternGrammar();
    _parser = definition.build();
  }

  /// Core implementation of pattern matching using parse tree
  /// Returns `List<Map<String, dynamic>>` to support both node IDs and property values
  ///
  /// Throws [FormatException] if the pattern cannot be parsed
  List<Map<String, dynamic>> matchRows(
    String pattern, {
    String? startId,
    List<String>? startIds,
    String? startType,
  }) {
    final result = _parser.parse(pattern);
    if (result is Failure) {
      throw FormatException(
        'Failed to parse pattern at position ${result.position}: ${result.message}',
        pattern,
        result.position,
      );
    }

    // Extract pattern, WHERE clause, and RETURN clause from parse tree
    final parts = <String>[];
    final directions = <bool>[];
    final edgeVars = <String?>[]; // Track edge variables from pattern
    final nodeMetadata = <String, _NodePatternMetadata>{};
    final edgeConstraints = <List<_PropertyConstraint>>[];
    final edgeBindings = <String, _EdgeVariableBinding>{};
    dynamic whereClause;
    List<ReturnItem>? returnItems;

    // Parse tree structure: [optional_MATCH, patternWithWhere, optional_RETURN]
    // or without MATCH: [null, patternWithWhere, optional_RETURN]
    if (result.value is List) {
      dynamic patternWithWhere;
      dynamic returnClause;

      // Check if MATCH is present
      if (result.value.length >= 2 && result.value[0] != null) {
        // With MATCH: [MATCH_part, patternWithWhere, optional_RETURN]
        patternWithWhere = result.value[1];
        if (result.value.length >= 3) {
          returnClause = result.value[2];
        }
      } else {
        // Without MATCH: [null, patternWithWhere, optional_RETURN]
        patternWithWhere = result.value.length > 1
            ? result.value[1]
            : result.value[0];
        if (result.value.length >= 3) {
          returnClause = result.value[2];
        }
      }

      if (patternWithWhere is List && patternWithWhere.isNotEmpty) {
        // Extract pattern (first element)
        _extractPartsFromParseTree(
          patternWithWhere[0],
          parts,
          directions,
          edgeVars,
          nodeMetadata,
          edgeConstraints,
          edgeBindings,
        );

        // Extract WHERE clause if present (second element is [whitespace, WHERE_clause])
        if (patternWithWhere.length > 1 &&
            patternWithWhere[1] != null &&
            patternWithWhere[1] is List) {
          final whereSection = patternWithWhere[1] as List;
          if (whereSection.length >= 2) {
            whereClause = whereSection[1]; // Skip whitespace, get WHERE clause
          }
        }
      }

      // Extract RETURN clause if present
      if (returnClause != null) {
        returnItems = _extractReturnItems(returnClause);
      }
    }

    // Debug removed - working correctly

    if (parts.isEmpty) return const <Map<String, dynamic>>[];

    final queryContext = _QueryContext(edgeBindings: edgeBindings);

    // Seed rows (copied logic from original)
    List<Map<String, String>> currentRows = <Map<String, String>>[];
    final firstAlias = _aliasOf(parts.first);
    if (firstAlias.isEmpty) {
      return const <Map<String, dynamic>>[];
    }

    // Validate and normalize start parameters
    if (startId != null && startIds != null) {
      throw ArgumentError('Cannot specify both startId and startIds');
    }
    final effectiveStartIds = startIds ?? (startId != null ? [startId] : null);

    if (effectiveStartIds != null && effectiveStartIds.isNotEmpty) {
      // Validate and filter to only existing node IDs
      final validStartIds = effectiveStartIds
          .where((id) => graph.nodesById.containsKey(id))
          .toList();

      if (validStartIds.isEmpty) {
        return const <Map<String, dynamic>>[];
      }

      // Try each position in pattern for each startId
      final allRows = <Map<String, String>>[];

      for (final singleStartId in validStartIds) {
        for (var i = 0; i < parts.length; i++) {
          final alias = _aliasOf(parts[i]);

          if (!_nodeMatchesConstraints(alias, singleStartId, nodeMetadata)) {
            continue;
          }

          // Optional: skip if type doesn't match
          if (startType != null) {
            // Extract type from pattern part
            final typeMatch = RegExp(r':(\w+)').firstMatch(parts[i]);
            if (typeMatch != null) {
              final nodeType = typeMatch.group(1);
              if (nodeType != startType) {
                continue; // Skip positions that don't match type
              }
            }
          }

          // Seed this position
          final seedRows = <Map<String, String>>[
            {alias: singleStartId},
          ];

          // Execute from this position
          final results = _executeFromPosition(
            seedRows,
            parts,
            directions,
            edgeVars,
            i,
            nodeMetadata,
            edgeConstraints,
          );
          allRows.addAll(results);
        }
      }

      // Deduplicate results with sorted keys for deterministic signatures
      final seen = <String>{};
      currentRows = [];
      for (final row in allRows) {
        final sortedKeys = row.keys.toList()..sort();
        final key = sortedKeys.map((k) => '$k:${row[k]}').join(',');
        if (!seen.contains(key)) {
          seen.add(key);
          currentRows.add(row);
        }
      }
    } else {
      // Parse optional type and label filter in first segment
      // TODO: Extract from parse tree instead of manual parsing
      _seedFromFirstSegment(firstAlias, currentRows, nodeMetadata);
    }

    // Only traverse if start filtering was not used (it already executed the full pattern)
    if (effectiveStartIds == null || effectiveStartIds.isEmpty) {
      // Traverse over each hop, expanding rows (copied from original)
      for (var i = 0; i < parts.length - 1; i++) {
        final part = parts[i];
        final aliasHere = _aliasOf(part);
        final nextAlias = _aliasOf(parts[i + 1]);

        final isForward = directions[i];
        final edgePart = isForward ? part : parts[i + 1];
        final edgeTypes = _edgeTypeFrom(edgePart);
        if (edgeTypes == null) {
          return const <Map<String, dynamic>>[];
        }
        // Note: empty list [] means wildcard (match all types)

        final constraintsForEdge = edgeConstraints.length > i
            ? edgeConstraints[i]
            : const <_PropertyConstraint>[];

        // Check if this is a variable-length relationship
        final variableLengthSpec = _extractVariableLengthSpec(edgePart);
        if (variableLengthSpec != null) {
          if (constraintsForEdge.isNotEmpty) {
            throw UnsupportedError(
              'Edge property filters are not supported on variable-length relationships yet',
            );
          }
          // Handle variable-length relationship using enumeratePaths
          final vlResults = _executeVariableLengthSegment(
            currentRows,
            aliasHere,
            nextAlias,
            edgeTypes,
            variableLengthSpec,
            isForward,
            nodeMetadata,
          );
          currentRows = vlResults;
        } else {
          // Handle single-hop relationship (existing logic)
          final edgeVar = edgeVars[i];
          currentRows = _executeSingleHopSegment(
            currentRows,
            aliasHere,
            nextAlias,
            edgeTypes,
            isForward,
            edgeVar,
            nodeMetadata,
            constraintsForEdge,
          );
        }

        if (currentRows.isEmpty) break;
      }
    }

    // Apply WHERE clause filtering if present
    if (whereClause != null) {
      currentRows = _applyWhereClause(currentRows, whereClause, queryContext);
    }

    // Apply RETURN clause if present (filtering and property resolution)
    if (returnItems != null) {
      return _applyReturnClause(currentRows, returnItems, queryContext);
    }

    // Backward compatibility: no RETURN clause returns all variables
    return currentRows.map((row) => row.cast<String, dynamic>()).toList();
  }

  /// Executes pattern from a specific position bidirectionally
  /// Used when startId matches a middle or last element in the pattern
  List<Map<String, String>> _executeFromPosition(
    List<Map<String, String>> seedRows,
    List<String> parts,
    List<bool> directions,
    List<String?> edgeVars,
    int startIndex,
    Map<String, _NodePatternMetadata> nodeMetadata,
    List<List<_PropertyConstraint>> edgeConstraints,
  ) {
    var currentRows = seedRows;

    // Execute backward from startIndex-1 to 0
    for (var i = startIndex - 1; i >= 0; i--) {
      final aliasHere = _aliasOf(parts[i + 1]); // Current position (reversed)
      final nextAlias = _aliasOf(parts[i]); // Target position

      // Get edge info from appropriate part
      final isForwardInPattern = directions[i];
      final edgePart = isForwardInPattern ? parts[i] : parts[i + 1];
      final edgeTypes = _edgeTypeFrom(edgePart);

      if (edgeTypes == null) {
        return const <Map<String, String>>[];
      }
      // Note: empty list [] means wildcard (match all types)

      final constraintsForEdge = edgeConstraints.length > i
          ? edgeConstraints[i]
          : const <_PropertyConstraint>[];

      // Reverse direction when going backward
      final isForward = !isForwardInPattern;

      // Check for variable-length
      final variableLengthSpec = _extractVariableLengthSpec(edgePart);
      if (variableLengthSpec != null) {
        if (constraintsForEdge.isNotEmpty) {
          throw UnsupportedError(
            'Edge property filters are not supported on variable-length relationships yet',
          );
        }
        currentRows = _executeVariableLengthSegment(
          currentRows,
          aliasHere,
          nextAlias,
          edgeTypes,
          variableLengthSpec,
          isForward,
          nodeMetadata,
        );
      } else {
        final edgeVar = edgeVars[i];
        currentRows = _executeSingleHopSegment(
          currentRows,
          aliasHere,
          nextAlias,
          edgeTypes,
          isForward,
          edgeVar,
          nodeMetadata,
          constraintsForEdge,
        );
      }

      if (currentRows.isEmpty) return const <Map<String, String>>[];
    }

    // Execute forward from startIndex to end
    for (var i = startIndex; i < parts.length - 1; i++) {
      final aliasHere = _aliasOf(parts[i]);
      final nextAlias = _aliasOf(parts[i + 1]);

      final isForward = directions[i];
      final edgePart = isForward ? parts[i] : parts[i + 1];
      final edgeTypes = _edgeTypeFrom(edgePart);

      if (edgeTypes == null) {
        return const <Map<String, String>>[];
      }
      // Note: empty list [] means wildcard (match all types)

      final constraintsForEdge = edgeConstraints.length > i
          ? edgeConstraints[i]
          : const <_PropertyConstraint>[];

      // Check for variable-length
      final variableLengthSpec = _extractVariableLengthSpec(edgePart);
      if (variableLengthSpec != null) {
        if (constraintsForEdge.isNotEmpty) {
          throw UnsupportedError(
            'Edge property filters are not supported on variable-length relationships yet',
          );
        }
        currentRows = _executeVariableLengthSegment(
          currentRows,
          aliasHere,
          nextAlias,
          edgeTypes,
          variableLengthSpec,
          isForward,
          nodeMetadata,
        );
      } else {
        final edgeVar = edgeVars[i];
        currentRows = _executeSingleHopSegment(
          currentRows,
          aliasHere,
          nextAlias,
          edgeTypes,
          isForward,
          edgeVar,
          nodeMetadata,
          constraintsForEdge,
        );
      }

      if (currentRows.isEmpty) return const <Map<String, String>>[];
    }

    return currentRows;
  }

  /// Executes a single-hop relationship segment
  /// Supports multiple edge types with OR semantics (matches ANY of the types)
  List<Map<String, String>> _executeSingleHopSegment(
    List<Map<String, String>> currentRows,
    String aliasHere,
    String nextAlias,
    List<String> edgeTypes,
    bool isForward,
    String? edgeVar,
    Map<String, _NodePatternMetadata> nodeMetadata,
    List<_PropertyConstraint> edgeConstraints,
  ) {
    final nextRows = <Map<String, String>>[];
    final seen = <String>{};

    for (final row in currentRows) {
      final srcId = row[aliasHere];
      if (srcId == null) continue;

      // Handle wildcard case: empty edgeTypes list means match all types
      List<String> effectiveEdgeTypes = edgeTypes;
      if (edgeTypes.isEmpty) {
        // Get all available edge types for this node
        final adjacency = isForward ? graph.out[srcId] : graph.inn[srcId];
        if (adjacency != null) {
          effectiveEdgeTypes = adjacency.keys.toList();
        } else {
          effectiveEdgeTypes = [];
        }
      }

      for (final edgeType in effectiveEdgeTypes) {
        final neighbors = isForward
            ? graph.outNeighbors(srcId, edgeType)
            : graph.inNeighbors(srcId, edgeType);

        for (final nb in neighbors) {
          if (!_nodeMatchesConstraints(nextAlias, nb, nodeMetadata)) {
            continue;
          }
          if (!_edgeMatchesConstraints(
            srcId,
            nb,
            edgeType,
            isForward,
            edgeConstraints,
          )) {
            continue;
          }

          final newRow = Map<String, String>.from(row);
          newRow[nextAlias] = nb;
          if (edgeVar != null) {
            newRow[edgeVar] =
                edgeType; // Bind edge variable to actual edge type
          }
          final keys = newRow.keys.toList()..sort();
          final sig = keys.map((k) => '$k=${newRow[k]}').join('|');
          if (seen.add(sig)) {
            nextRows.add(newRow);
          }
        }
      }
    }

    return nextRows;
  }

  /// Executes a variable-length relationship segment using enumeratePaths
  /// Supports multiple edge types with OR semantics (matches ANY of the types)
  List<Map<String, String>> _executeVariableLengthSegment(
    List<Map<String, String>> currentRows,
    String aliasHere,
    String nextAlias,
    List<String> edgeTypes,
    VariableLengthSpec vlSpec,
    bool isForward,
    Map<String, _NodePatternMetadata> nodeMetadata,
  ) {
    final nextRows = <Map<String, String>>[];
    final seen = <String>{};

    for (final row in currentRows) {
      final srcId = row[aliasHere];
      if (srcId == null) continue;

      // Find all possible destinations within hop limits, matching ANY edge type
      final allDestinations = <String>{};
      for (final edgeType in edgeTypes) {
        final destinations = _findVariableLengthDestinations(
          srcId,
          edgeType,
          vlSpec,
          isForward,
        );
        allDestinations.addAll(destinations);
      }

      for (final destId in allDestinations) {
        if (!_nodeMatchesConstraints(nextAlias, destId, nodeMetadata)) {
          continue;
        }
        final newRow = Map<String, String>.from(row);
        newRow[nextAlias] = destId;
        final keys = newRow.keys.toList()..sort();
        final sig = keys.map((k) => '$k=${newRow[k]}').join('|');
        if (seen.add(sig)) {
          nextRows.add(newRow);
        }
      }
    }

    return nextRows;
  }

  /// Finds all destinations reachable via variable-length paths
  Set<String> _findVariableLengthDestinations(
    String srcId,
    String edgeType,
    VariableLengthSpec vlSpec,
    bool isForward,
  ) {
    final destinations = <String>{};
    final maxHops = vlSpec.effectiveMaxHops;
    final minHops = vlSpec.effectiveMinHops;

    // Use breadth-first search to find all reachable nodes within hop limits
    final queue = <({String nodeId, int hops})>[];
    final visited = <String, int>{}; // node -> minimum hops to reach it

    queue.add((nodeId: srcId, hops: 0));
    visited[srcId] = 0;

    while (queue.isNotEmpty) {
      final current = queue.removeAt(0);

      // If we've reached the minimum hops, this is a valid destination
      if (current.hops >= minHops && current.nodeId != srcId) {
        destinations.add(current.nodeId);
      }

      // Continue exploring if we haven't reached max hops
      if (current.hops < maxHops) {
        final neighbors = isForward
            ? graph.outNeighbors(current.nodeId, edgeType)
            : graph.inNeighbors(current.nodeId, edgeType);

        for (final neighbor in neighbors) {
          final newHops = current.hops + 1;
          if (!visited.containsKey(neighbor) || visited[neighbor]! > newHops) {
            visited[neighbor] = newHops;
            queue.add((nodeId: neighbor, hops: newHops));
          }
        }
      }
    }

    return destinations;
  }

  Map<String, Set<String>> match(
    String pattern, {
    String? startId,
    List<String>? startIds,
    String? startType,
  }) {
    final paths = matchPaths(
      pattern,
      startId: startId,
      startIds: startIds,
      startType: startType,
    );
    final results = <String, Set<String>>{};
    for (final path in paths) {
      for (final entry in path.nodes.entries) {
        results.putIfAbsent(entry.key, () => <String>{}).add(entry.value);
      }
    }
    return results;
  }

  List<PathMatch> matchPaths(
    String pattern, {
    String? startId,
    List<String>? startIds,
    String? startType,
  }) {
    final hasReturn = RegExp(
      r'\s+RETURN\s+',
      caseSensitive: false,
    ).hasMatch(pattern);

    if (!hasReturn) {
      final rows = matchRows(
        pattern,
        startId: startId,
        startIds: startIds,
        startType: startType,
      );
      final pathMatches = <PathMatch>[];

      // Strip WHERE clause for path reconstruction
      final patternWithoutWhere = pattern.replaceAll(
        RegExp(r'\s+WHERE\s+.+$', caseSensitive: false),
        '',
      );

      // Extract edge variables from the pattern to filter them out of nodes
      final edgeVarNames = _extractEdgeVariableNames(patternWithoutWhere);

      for (final row in rows) {
        // Keep full row for path reconstruction (needs edge variables for lookups)
        final fullRow = <String, String>{};
        for (final entry in row.entries) {
          if (entry.value is String) {
            fullRow[entry.key] = entry.value as String;
          }
        }

        // Build sequences using full row
        final sequences = _buildPathEdgeSequencesForRow(
          patternWithoutWhere,
          fullRow,
        );

        // Filter out edge variables when creating PathMatch nodes
        final nodeIds = <String, String>{};
        for (final entry in fullRow.entries) {
          if (!edgeVarNames.contains(entry.key)) {
            nodeIds[entry.key] = entry.value;
          }
        }

        for (final edges in sequences) {
          pathMatches.add(
            PathMatch(nodes: Map<String, String>.from(nodeIds), edges: edges),
          );
        }
      }
      return pathMatches;
    }

    final filteredRows = matchRows(
      pattern,
      startId: startId,
      startIds: startIds,
    );
    final patternWithoutReturn = pattern.replaceAll(
      RegExp(r'\s+RETURN\s+.+$', caseSensitive: false),
      '',
    );
    final unfilteredRows = matchRows(
      patternWithoutReturn,
      startId: startId,
      startIds: startIds,
    );

    // Extract edge variables to filter them out
    final patternWithoutReturnOrWhere = patternWithoutReturn.replaceAll(
      RegExp(r'\s+WHERE\s+.+$', caseSensitive: false),
      '',
    );
    final edgeVarNames = _extractEdgeVariableNames(patternWithoutReturnOrWhere);

    final pathMatches = <PathMatch>[];

    for (var i = 0; i < filteredRows.length && i < unfilteredRows.length; i++) {
      // Keep full rows for path reconstruction
      final filteredFullRow = <String, String>{};
      for (final entry in filteredRows[i].entries) {
        if (entry.value is String) {
          filteredFullRow[entry.key] = entry.value as String;
        }
      }

      final unfilteredFullRow = <String, String>{};
      for (final entry in unfilteredRows[i].entries) {
        if (entry.value is String) {
          unfilteredFullRow[entry.key] = entry.value as String;
        }
      }

      // Build sequences using full row
      final sequences = _buildPathEdgeSequencesForRow(
        patternWithoutReturnOrWhere,
        unfilteredFullRow,
      );

      // Filter out edge variables when creating PathMatch nodes
      final filteredIds = <String, String>{};
      for (final entry in filteredFullRow.entries) {
        if (!edgeVarNames.contains(entry.key)) {
          filteredIds[entry.key] = entry.value;
        }
      }

      for (final edges in sequences) {
        pathMatches.add(
          PathMatch(nodes: Map<String, String>.from(filteredIds), edges: edges),
        );
      }
    }

    return pathMatches;
  }

  // Extract segments and directions from parse tree (visible for testing)
  void extractPartsFromParseTreeForTesting(
    dynamic parseTree,
    List<String> parts,
    List<bool> directions,
  ) {
    final edgeVars = <String?>[];
    final metadata = <String, _NodePatternMetadata>{};
    final edgeConstraints = <List<_PropertyConstraint>>[];
    final edgeBindings = <String, _EdgeVariableBinding>{};
    _extractPartsFromParseTree(
      parseTree,
      parts,
      directions,
      edgeVars,
      metadata,
      edgeConstraints,
      edgeBindings,
    );
  }

  void _extractPartsFromParseTree(
    dynamic parseTree,
    List<String> parts,
    List<bool> directions,
    List<String?> edgeVars,
    Map<String, _NodePatternMetadata> nodeMetadata,
    List<List<_PropertyConstraint>> edgeConstraints,
    Map<String, _EdgeVariableBinding> edgeBindings,
  ) {
    if (parseTree is! List) return;

    // First element is the initial segment
    final firstSegment = parseTree[0];
    parts.add(_flattenSegment(firstSegment, nodeMetadata));

    // Remaining elements are [connection, segment] pairs
    if (parseTree.length > 1 && parseTree[1] is List) {
      final connections = parseTree[1] as List;
      for (final connectionPair in connections) {
        if (connectionPair is List && connectionPair.length >= 2) {
          final connection = connectionPair[0];
          final segment = connectionPair[1];

          // Determine direction from connection
          final connectionStr = _flattenConnection(connection);
          final isForward = connectionStr.contains('->');
          directions.add(isForward);

          // Extract edge variable if present
          final edgeVar = _extractEdgeVariable(connection);
          edgeVars.add(edgeVar);

          final currentAlias = parts.isNotEmpty ? _aliasOf(parts.last) : null;
          final flattenedSegment = _flattenSegment(segment, nodeMetadata);
          final nextAlias = _aliasOf(flattenedSegment);

          if (edgeVar != null && currentAlias != null && nextAlias != null) {
            final fromAlias = isForward ? currentAlias : nextAlias;
            final toAlias = isForward ? nextAlias : currentAlias;
            edgeBindings[edgeVar] = _EdgeVariableBinding(
              variable: edgeVar,
              fromAlias: fromAlias,
              toAlias: toAlias,
            );
          }

          // Add edge info to the appropriate part based on direction
          final edgeInfo = _extractEdgeFromConnection(connection);
          edgeConstraints.add(_edgeConstraintsFromInfo(edgeInfo));

          if (isForward) {
            // Forward: edge info goes with current (source) part
            if (parts.isNotEmpty && edgeInfo.isNotEmpty) {
              parts[parts.length - 1] = parts[parts.length - 1] + edgeInfo;
            }
            parts.add(flattenedSegment);
          } else {
            // Backward: edge info goes with next (target) part
            if (edgeInfo.isNotEmpty) {
              parts.add(flattenedSegment + edgeInfo);
            } else {
              parts.add(flattenedSegment);
            }
          }
        }
      }
    }
  }

  /// Extracts alias name from a pattern part
  String _aliasOf(String part) {
    if (part.startsWith('[')) {
      final afterEdge = part.substring(part.indexOf('-') + 1);
      return afterEdge.split(RegExp(r'[-\[:]')).first.trim();
    } else {
      return part.split(RegExp(r'[-\[:]')).first.trim();
    }
  }

  String _extractEdgeFromConnection(dynamic connection) {
    final connectionStr = _flattenToString(connection);
    // Extract edge type like [:WORKS_FOR] or [:WORKS_FOR*1..3] from connection
    final match = RegExp(r'\[([^\]]+)\]').firstMatch(connectionStr);
    return match != null ? '${match.group(0)}' : '';
  }

  /// Extracts edge variable name from connection like [r] or [r:TYPE]
  String? _extractEdgeVariable(dynamic connection) {
    final connectionStr = _flattenToString(connection);
    // Match patterns like [r], [r:TYPE], [r:TYPE*1..3]
    // We want to capture just the variable name before : or ]
    final match = RegExp(r'\[(\w+)(?:[:\]]|$)').firstMatch(connectionStr);
    return match?.group(1);
  }

  /// Extracts edge variable name from a string segment like "n[r:TYPE]"
  String? _extractEdgeVariableFromString(String segment) {
    // Match patterns like [r], [r:TYPE], [r:TYPE*1..3]
    // We want to capture just the variable name before : or ]
    final match = RegExp(r'\[(\w+)(?:[:\]]|$)').firstMatch(segment);
    return match?.group(1);
  }

  /// Extracts all edge variable names from a pattern string
  Set<String> _extractEdgeVariableNames(String pattern) {
    final edgeVarNames = <String>{};
    // Match patterns like -[r]-> or -[r:TYPE]-> or -[r:TYPE*1..3]->
    final matches = RegExp(r'-\[(\w+)(?:[:\]]|->)').allMatches(pattern);
    for (final match in matches) {
      final varName = match.group(1);
      if (varName != null) {
        edgeVarNames.add(varName);
      }
    }
    return edgeVarNames;
  }

  /// Extracts variable-length specification from edge string
  VariableLengthSpec? _extractVariableLengthSpec(String edgeStr) {
    // Look for patterns like [:TYPE*], [:TYPE*1..3], [:TYPE*2..], [:TYPE*..5]
    final match = RegExp(r'\[:([^\*]+)\*([^\]]*)]').firstMatch(edgeStr);
    if (match == null) return null;

    final vlPart = match.group(2) ?? '';
    if (vlPart.isEmpty) {
      // Just * means unlimited
      return const VariableLengthSpec();
    }

    // Parse patterns like "1..3", "2..", "..5"
    if (vlPart.contains('..')) {
      final parts = vlPart.split('..');
      final minStr = parts[0];
      final maxStr = parts.length > 1 ? parts[1] : '';

      final min = minStr.isNotEmpty ? int.tryParse(minStr) : null;
      final max = maxStr.isNotEmpty ? int.tryParse(maxStr) : null;

      return VariableLengthSpec(minHops: min, maxHops: max);
    }

    // Single number like "3" (from "*3") means exactly 3 hops
    final exactHops = int.tryParse(vlPart.trim());
    if (exactHops != null) {
      return VariableLengthSpec(minHops: exactHops, maxHops: exactHops);
    }

    return const VariableLengthSpec(); // Default to unlimited
  }

  String _flattenSegment(
    dynamic segment,
    Map<String, _NodePatternMetadata> nodeMetadata,
  ) {
    if (segment is List && segment.isNotEmpty) {
      final variable = _flattenToString(segment[0]).trim();
      final rawType = segment.length > 1 && segment[1] != null
          ? _flattenToString(segment[1]).replaceFirst(':', '').trim()
          : null;
      final propertyFilter = segment.length > 2 && segment[2] != null
          ? _flattenToString(segment[2])
          : '';

      if (variable.isNotEmpty) {
        nodeMetadata[variable] = _NodePatternMetadata(
          alias: variable,
          type: rawType?.isEmpty ?? true ? null : rawType,
          constraints: _parsePropertyFilterString(propertyFilter),
        );
      }

      final typeFragment = rawType != null && rawType.isNotEmpty
          ? ':$rawType'
          : '';
      return '$variable$typeFragment$propertyFilter';
    }

    final fallback = _flattenToString(segment);
    final alias = _extractVariableName(fallback);
    if (alias != null && !nodeMetadata.containsKey(alias)) {
      nodeMetadata[alias] = _NodePatternMetadata(alias: alias);
    }
    return fallback;
  }

  String _flattenConnection(dynamic connection) {
    return _flattenToString(connection);
  }

  String _flattenToString(dynamic obj) {
    if (obj is String) return obj;
    if (obj is List) {
      return obj.map((e) => _flattenToString(e)).join('');
    }
    return obj?.toString() ?? '';
  }

  void _seedFromFirstSegment(
    String firstAlias,
    List<Map<String, String>> currentRows,
    Map<String, _NodePatternMetadata> nodeMetadata,
  ) {
    final metadata = nodeMetadata[firstAlias];
    for (final node in graph.nodesById.values) {
      if (!_nodeMatchesMetadata(metadata, node)) {
        continue;
      }
      currentRows.add({firstAlias: node.id});
    }
  }

  bool _nodeMatchesConstraints(
    String alias,
    String nodeId,
    Map<String, _NodePatternMetadata> nodeMetadata,
  ) {
    final metadata = nodeMetadata[alias];
    if (metadata == null) return true;
    final node = graph.nodesById[nodeId];
    if (node == null) return false;
    return _nodeMatchesMetadata(metadata, node);
  }

  bool _nodeMatchesMetadata(_NodePatternMetadata? metadata, Node node) {
    if (metadata == null) return true;
    if (metadata.type != null && metadata.type!.isNotEmpty) {
      if (node.type != metadata.type) {
        return false;
      }
    }

    for (final constraint in metadata.constraints) {
      if (!_propertyConstraintSatisfied(node, constraint)) {
        return false;
      }
    }

    return true;
  }

  bool _edgeMatchesConstraints(
    String currentId,
    String neighborId,
    String edgeType,
    bool isForward,
    List<_PropertyConstraint> constraints,
  ) {
    if (constraints.isEmpty) return true;

    final actualSource = isForward ? currentId : neighborId;
    final actualTarget = isForward ? neighborId : currentId;
    final properties = graph.edgeProperties(
      actualSource,
      edgeType,
      actualTarget,
    );

    for (final constraint in constraints) {
      if (!_edgePropertyConstraintSatisfied(
        actualSource,
        actualTarget,
        edgeType,
        properties,
        constraint,
      )) {
        return false;
      }
    }
    return true;
  }

  bool _edgePropertyConstraintSatisfied(
    String sourceId,
    String targetId,
    String edgeType,
    Map<String, dynamic>? properties,
    _PropertyConstraint constraint,
  ) {
    final actualValue = _readEdgeProperty(
      sourceId,
      targetId,
      edgeType,
      properties,
      constraint.key,
    );
    if (actualValue == null) return false;

    switch (constraint.operator) {
      case _PropertyOperator.contains:
        final actualStr = actualValue.toString().toLowerCase();
        final expected = constraint.value.toString().toLowerCase();
        return actualStr.contains(expected);
      case _PropertyOperator.equals:
        return _compareValues(actualValue, '=', constraint.value);
    }
  }

  dynamic _readEdgeProperty(
    String sourceId,
    String targetId,
    String edgeType,
    Map<String, dynamic>? properties,
    String key,
  ) {
    switch (key) {
      case 'type':
        return edgeType;
      case 'src':
      case 'source':
      case 'from':
        return sourceId;
      case 'dst':
      case 'dest':
      case 'target':
      case 'to':
        return targetId;
      default:
        return properties?[key];
    }
  }

  bool _propertyConstraintSatisfied(Node node, _PropertyConstraint constraint) {
    final actual = _readNodeProperty(node, constraint.key);
    if (actual == null) return false;

    switch (constraint.operator) {
      case _PropertyOperator.equals:
        // Support numeric equality without implicit conversions
        if (actual is num && constraint.value is num) {
          return actual == constraint.value;
        }
        return actual == constraint.value;
      case _PropertyOperator.contains:
        final actualStr = actual.toString().toLowerCase();
        final expected = constraint.value.toString().toLowerCase();
        return actualStr.contains(expected);
    }
  }

  dynamic _readNodeProperty(Node node, String key) {
    switch (key) {
      case 'id':
        return node.id;
      case 'label':
        return node.label;
      case 'type':
        return node.type;
      default:
        return node.properties?[key];
    }
  }

  List<_PropertyConstraint> _parsePropertyFilterString(String? filterStr) {
    if (filterStr == null) return const [];
    final trimmed = filterStr.trim();
    if (trimmed.length < 2 ||
        !trimmed.startsWith('{') ||
        !trimmed.endsWith('}')) {
      return const [];
    }

    final inner = trimmed.substring(1, trimmed.length - 1).trim();
    if (inner.isEmpty) return const [];

    final entries = <String>[];
    final buffer = StringBuffer();
    var insideQuotes = false;
    for (var i = 0; i < inner.length; i++) {
      final char = inner[i];
      if (char == '"') {
        insideQuotes = !insideQuotes;
        buffer.write(char);
        continue;
      }
      if (char == ',' && !insideQuotes) {
        entries.add(buffer.toString().trim());
        buffer.clear();
        continue;
      }
      buffer.write(char);
    }
    if (buffer.isNotEmpty) {
      entries.add(buffer.toString().trim());
    }

    final constraints = <_PropertyConstraint>[];
    for (final entry in entries) {
      if (entry.isEmpty) continue;
      final operatorMatch = _findPropertyOperator(entry);
      if (operatorMatch == null) continue;

      final key = entry.substring(0, operatorMatch.index).trim();
      final valueExpr = entry.substring(operatorMatch.index + 1).trim();
      if (key.isEmpty || valueExpr.isEmpty) continue;

      final rawValue = _parseValue(valueExpr);
      final parsedValue = operatorMatch.operator == _PropertyOperator.contains
          ? rawValue.toString()
          : rawValue;

      constraints.add(
        _PropertyConstraint(
          key: key,
          operator: operatorMatch.operator,
          value: parsedValue,
        ),
      );
    }

    return constraints.isEmpty ? const [] : constraints;
  }

  _OperatorMatch? _findPropertyOperator(String entry) {
    var insideQuotes = false;
    for (var i = 0; i < entry.length; i++) {
      final char = entry[i];
      if (char == '"') {
        insideQuotes = !insideQuotes;
        continue;
      }
      if (insideQuotes) continue;
      if (char == '~') {
        return _OperatorMatch(i, _PropertyOperator.contains);
      }
      if (char == '=' || char == ':') {
        return _OperatorMatch(i, _PropertyOperator.equals);
      }
    }
    return null;
  }

  // Copied helper methods from original parser
  /// Extracts edge types from a segment. Returns list of types for OR syntax [:TYPE1|TYPE2]
  List<String>? _edgeTypeFrom(String segment) {
    for (int i = 0; i < segment.length; i++) {
      if (segment[i] == '[') {
        int j = i + 1;
        while (j < segment.length && segment[j].trim().isEmpty) {
          j++;
        }
        bool foundColon = false;
        while (j < segment.length) {
          final c = segment[j];
          if (c == ':') {
            foundColon = true;
            j++;
            break;
          }
          if (c == ']') {
            // Found [variable] or [] without type - this is a wildcard
            return []; // Empty list signals wildcard (match all types)
          }
          j++;
        }
        if (!foundColon) continue;

        int depth = 1;
        final contentStart = j;
        int k = j;
        while (k < segment.length) {
          final c = segment[k];
          if (c == '[') {
            depth++;
          } else if (c == ']') {
            depth--;
            if (depth == 0) {
              // Extract edge type content (before *)
              String fullContent = segment.substring(contentStart, k);
              final braceIndex = fullContent.indexOf('{');
              if (braceIndex != -1) {
                fullContent = fullContent.substring(0, braceIndex);
              }
              fullContent = fullContent.trim();
              if (fullContent.contains('*')) {
                fullContent = fullContent.split('*')[0];
              }
              // Split by | to support multiple types
              final types = fullContent
                  .split('|')
                  .map((t) => t.trim())
                  .where((t) => t.isNotEmpty)
                  .toList();
              return types.isEmpty ? null : types;
            }
          }
          k++;
        }
        return null;
      }
    }
    return null;
  }

  List<_PropertyConstraint> _edgeConstraintsFromInfo(String edgeInfo) {
    final filter = _extractEdgePropertyFilter(edgeInfo);
    if (filter == null) return const [];
    return _parsePropertyFilterString(filter);
  }

  String? _extractEdgePropertyFilter(String edgeInfo) {
    if (edgeInfo.isEmpty) return null;
    final start = edgeInfo.indexOf('{');
    if (start == -1) return null;
    final end = edgeInfo.lastIndexOf('}');
    if (end == -1 || end < start) return null;
    return edgeInfo.substring(start, end + 1);
  }

  List<PathEdge> buildEdgesForRow(String pattern, Map<String, String> row) {
    final edges = <PathEdge>[];

    // Strip optional MATCH keyword
    var cleanPattern = pattern.trim();
    if (cleanPattern.toUpperCase().startsWith('MATCH ')) {
      cleanPattern = cleanPattern.substring(6).trim();
    }

    // Parse the pattern to extract edge information with bracket-aware splitting
    final parts = <String>[];
    final directions = <bool>[]; // true = forward (->), false = backward (<-)

    int i = 0;
    int bracketDepth = 0;
    int lastSplit = 0;
    while (i < cleanPattern.length) {
      final ch = cleanPattern[i];
      if (ch == '[') {
        bracketDepth++;
        i++;
        continue;
      }
      if (ch == ']') {
        bracketDepth = bracketDepth > 0 ? bracketDepth - 1 : -1;
        if (bracketDepth < 0) {
          // malformed
          break;
        }
        i++;
        continue;
      }
      if (bracketDepth == 0) {
        if (ch == '-' &&
            i + 1 < cleanPattern.length &&
            cleanPattern[i + 1] == '>') {
          parts.add(cleanPattern.substring(lastSplit, i).trim());
          directions.add(true);
          i += 2;
          lastSplit = i;
          continue;
        }
        if (ch == '<' &&
            i + 1 < cleanPattern.length &&
            cleanPattern[i + 1] == '-') {
          parts.add(cleanPattern.substring(lastSplit, i).trim());
          directions.add(false);
          i += 2;
          lastSplit = i;
          continue;
        }
      }
      i++;
    }
    if (lastSplit <= cleanPattern.length) {
      final tail = cleanPattern.substring(lastSplit).trim();
      if (tail.isNotEmpty) parts.add(tail);
    }

    // Build edges from the parsed parts
    for (int i = 0; i < directions.length; i++) {
      final fromPart = parts[i];
      final toPart = parts[i + 1];
      final isForward = directions[i];

      // Extract variable names
      final fromVar = _extractVariableName(fromPart);
      final toVar = _extractVariableName(toPart);

      if (fromVar == null || toVar == null) continue;
      if (!row.containsKey(fromVar) || !row.containsKey(toVar)) continue;

      // Extract edge types from the appropriate part (backward uses toPart)
      final edgePart = isForward ? fromPart : toPart;
      var edgeTypes = _edgeTypeFrom(edgePart);
      // If no explicit types (e.g., [r]), try to use the bound edge variable from row
      if (edgeTypes == null || edgeTypes.isEmpty) {
        final edgeVar = _extractEdgeVariableFromString(edgePart);
        final boundType = edgeVar != null ? row[edgeVar] : null;
        if (boundType != null && boundType.isNotEmpty) {
          edgeTypes = [boundType];
        }
      }
      if (edgeTypes == null || edgeTypes.isEmpty) continue;

      // Determine which edge type actually exists between these nodes
      final fromId = isForward ? row[fromVar]! : row[toVar]!;
      final toId = isForward ? row[toVar]! : row[fromVar]!;

      String? actualEdgeType;
      for (final type in edgeTypes) {
        if (graph.hasEdge(fromId, type, toId)) {
          actualEdgeType = type;
          break;
        }
      }

      if (actualEdgeType == null) continue;

      final edgeProps = graph.edgeProperties(fromId, actualEdgeType, toId);

      // Create the edge based on direction
      if (isForward) {
        edges.add(
          PathEdge(
            from: row[fromVar]!,
            to: row[toVar]!,
            type: actualEdgeType,
            fromVariable: fromVar,
            toVariable: toVar,
            properties: edgeProps,
          ),
        );
      } else {
        edges.add(
          PathEdge(
            from: row[toVar]!,
            to: row[fromVar]!,
            type: actualEdgeType,
            fromVariable: toVar,
            toVariable: fromVar,
            properties: edgeProps,
          ),
        );
      }
    }

    return edges;
  }

  List<List<PathEdge>> _buildPathEdgeSequencesForRow(
    String pattern,
    Map<String, String> row,
  ) {
    var cleanPattern = pattern.trim();
    if (cleanPattern.toUpperCase().startsWith('MATCH ')) {
      cleanPattern = cleanPattern.substring(6).trim();
    }

    final parts = <String>[];
    final directions = <bool>[];

    int i = 0;
    int bracketDepth = 0;
    int lastSplit = 0;
    while (i < cleanPattern.length) {
      final ch = cleanPattern[i];
      if (ch == '[') {
        bracketDepth++;
        i++;
        continue;
      }
      if (ch == ']') {
        bracketDepth = bracketDepth > 0 ? bracketDepth - 1 : -1;
        if (bracketDepth < 0) break;
        i++;
        continue;
      }
      if (bracketDepth == 0) {
        if (ch == '-' &&
            i + 1 < cleanPattern.length &&
            cleanPattern[i + 1] == '>') {
          parts.add(cleanPattern.substring(lastSplit, i).trim());
          directions.add(true);
          i += 2;
          lastSplit = i;
          continue;
        }
        if (ch == '<' &&
            i + 1 < cleanPattern.length &&
            cleanPattern[i + 1] == '-') {
          parts.add(cleanPattern.substring(lastSplit, i).trim());
          directions.add(false);
          i += 2;
          lastSplit = i;
          continue;
        }
      }
      i++;
    }
    if (lastSplit <= cleanPattern.length) {
      final tail = cleanPattern.substring(lastSplit).trim();
      if (tail.isNotEmpty) parts.add(tail);
    }

    var sequences = <List<PathEdge>>[<PathEdge>[]];

    for (int si = 0; si < directions.length; si++) {
      final fromPart = parts[si];
      final toPart = parts[si + 1];
      final isForward = directions[si];

      final fromVar = _extractVariableName(fromPart);
      final toVar = _extractVariableName(toPart);
      if (fromVar == null || toVar == null) return const <List<PathEdge>>[];
      if (!row.containsKey(fromVar) || !row.containsKey(toVar))
        return const <List<PathEdge>>[];

      final edgePart = isForward ? fromPart : toPart;
      var edgeTypes = _edgeTypeFrom(edgePart);
      // If no explicit types (e.g., [r]), try to use the bound edge variable from row
      if (edgeTypes == null || edgeTypes.isEmpty) {
        final edgeVar = _extractEdgeVariableFromString(edgePart);
        final boundType = edgeVar != null ? row[edgeVar] : null;
        if (boundType != null && boundType.isNotEmpty) {
          edgeTypes = [boundType];
        }
      }
      if (edgeTypes == null || edgeTypes.isEmpty)
        return const <List<PathEdge>>[];

      final vlSpec = _extractVariableLengthSpec(edgePart);
      final newSequences = <List<PathEdge>>[];

      if (vlSpec == null) {
        final fromId = isForward ? row[fromVar]! : row[toVar]!;
        final toId = isForward ? row[toVar]! : row[fromVar]!;

        String? actualType;
        for (final t in edgeTypes) {
          if (graph.hasEdge(fromId, t, toId)) {
            actualType = t;
            break;
          }
        }
        if (actualType == null) return const <List<PathEdge>>[];

        final edgeProps = graph.edgeProperties(fromId, actualType, toId);

        final hopEdge = isForward
            ? PathEdge(
                from: row[fromVar]!,
                to: row[toVar]!,
                type: actualType,
                fromVariable: fromVar,
                toVariable: toVar,
                properties: edgeProps,
              )
            : PathEdge(
                from: row[toVar]!,
                to: row[fromVar]!,
                type: actualType,
                fromVariable: toVar,
                toVariable: fromVar,
                properties: edgeProps,
              );

        for (final seq in sequences) {
          final next = List<PathEdge>.from(seq)..add(hopEdge);
          newSequences.add(next);
        }
      } else {
        final startId = isForward ? row[fromVar]! : row[toVar]!;
        final endId = isForward ? row[toVar]! : row[fromVar]!;

        final vlSequences = _enumerateVariableLengthEdgeSequences(
          fromId: startId,
          toId: endId,
          edgeTypes: edgeTypes,
          spec: vlSpec,
          isForward: isForward,
          fromVariable: fromVar,
          toVariable: toVar,
        );

        if (vlSequences.isEmpty) return const <List<PathEdge>>[];

        for (final seq in sequences) {
          for (final vlSeq in vlSequences) {
            final next = List<PathEdge>.from(seq)..addAll(vlSeq);
            newSequences.add(next);
          }
        }
      }

      sequences = newSequences;
      if (sequences.isEmpty) return const <List<PathEdge>>[];
    }

    return sequences;
  }

  List<List<PathEdge>> _enumerateVariableLengthEdgeSequences({
    required String fromId,
    required String toId,
    required List<String> edgeTypes,
    required VariableLengthSpec spec,
    required bool isForward,
    required String fromVariable,
    required String toVariable,
  }) {
    final results = <List<PathEdge>>[];
    final maxHops = spec.effectiveMaxHops;
    final minHops = spec.effectiveMinHops;

    if (fromId == toId && minHops == 0) {
      results.add(<PathEdge>[]);
    }

    final visited = <String>{fromId};

    void dfs(String currentId, int depth, List<PathEdge> acc) {
      if (depth > maxHops) return;

      if (currentId == toId && depth >= minHops) {
        results.add(List<PathEdge>.from(acc));
      }

      if (depth == maxHops) return;

      for (final type in edgeTypes) {
        final neighbors = isForward
            ? graph.outNeighbors(currentId, type)
            : graph.inNeighbors(currentId, type);
        for (final nb in neighbors) {
          if (visited.contains(nb)) continue;

          final edgeProps = isForward
              ? graph.edgeProperties(currentId, type, nb)
              : graph.edgeProperties(nb, type, currentId);

          final edge = isForward
              ? PathEdge(
                  from: currentId,
                  to: nb,
                  type: type,
                  fromVariable: fromVariable,
                  toVariable: toVariable,
                  properties: edgeProps,
                )
              : PathEdge(
                  from: nb,
                  to: currentId,
                  type: type,
                  fromVariable: toVariable,
                  toVariable: fromVariable,
                  properties: edgeProps,
                );

          visited.add(nb);
          acc.add(edge);
          dfs(nb, depth + 1, acc);
          acc.removeLast();
          visited.remove(nb);
        }
      }
    }

    dfs(fromId, 0, <PathEdge>[]);
    return results;
  }

  /// Extract variable name from a pattern part (e.g., "user:User{label=Alice}" -> "user")
  String? _extractVariableName(String part) {
    if (part.isEmpty) return null;

    // Handle parts that start with edge syntax like "[:LEADS]-person"
    if (part.startsWith('[')) {
      // Find the end of the edge syntax and look for variable after dash
      final edgeEnd = part.indexOf(']');
      if (edgeEnd != -1) {
        final afterEdge = part.substring(edgeEnd + 1).trim();
        if (afterEdge.startsWith('-')) {
          final varPart = afterEdge.substring(1).trim();
          if (varPart.isNotEmpty) {
            part = varPart;
          }
        }
      }
    }

    // Remove edge syntax if present in the middle or end
    // (applies to both branches - parts may have multiple edge specs)
    // Updated regex to handle multiple types with | separator, variable-length *, and edge variables
    // Matches [:TYPE], [r:TYPE], [r], etc.
    part = part.replaceAll(RegExp(r'\[\s*\w*\s*:?[^\]]*\]'), '').trim();
    // Remove trailing dash that might be left after edge removal
    part = part.replaceAll(RegExp(r'-+$'), '').trim();

    // Variable name is before any : or { characters
    final colonIdx = part.indexOf(':');
    final braceIdx = part.indexOf('{');

    int endIdx = part.length;
    if (colonIdx != -1 && braceIdx != -1) {
      endIdx = colonIdx < braceIdx ? colonIdx : braceIdx;
    } else if (colonIdx != -1) {
      endIdx = colonIdx;
    } else if (braceIdx != -1) {
      endIdx = braceIdx;
    }

    final varName = part.substring(0, endIdx).trim();
    return varName.isEmpty ? null : varName;
  }

  /// Finds all node IDs with the given [type].
  Set<String> findByType(String type) {
    return graph.nodesById.values
        .where((n) => n.type == type)
        .map((n) => n.id)
        .toSet();
  }

  /// Finds node IDs whose label exactly matches [label].
  Set<String> findByLabelEquals(String label, {bool caseInsensitive = false}) {
    if (!caseInsensitive) {
      return graph.nodesById.values
          .where((n) => n.label == label)
          .map((n) => n.id)
          .toSet();
    }
    final needle = label.toLowerCase();
    return graph.nodesById.values
        .where((n) => n.label.toLowerCase() == needle)
        .map((n) => n.id)
        .toSet();
  }

  /// Finds node IDs whose label contains the substring [contains].
  Set<String> findByLabelContains(
    String contains, {
    bool caseInsensitive = true,
  }) {
    final needle = caseInsensitive ? contains.toLowerCase() : contains;
    return graph.nodesById.values
        .where(
          (n) => (caseInsensitive ? n.label.toLowerCase() : n.label).contains(
            needle,
          ),
        )
        .map((n) => n.id)
        .toSet();
  }

  /// Returns outbound neighbors from [srcId] via [edgeType].
  Set<String> outFrom(String srcId, String edgeType) =>
      graph.outNeighbors(srcId, edgeType);

  /// Returns inbound neighbors to [dstId] via [edgeType].
  Set<String> inTo(String dstId, String edgeType) =>
      graph.inNeighbors(dstId, edgeType);

  /// Finds all destinations reachable via [edgeType] from any source in [srcIds].
  Set<String> findByEdgeFrom(Iterable<String> srcIds, String edgeType) {
    final out = <String>{};
    for (final id in srcIds) {
      out.addAll(graph.outNeighbors(id, edgeType));
    }
    return out;
  }

  /// Finds all sources that can reach any destination in [dstIds] via [edgeType].
  Set<String> findByEdgeTo(Iterable<String> dstIds, String edgeType) {
    final ins = <String>{};
    for (final id in dstIds) {
      ins.addAll(graph.inNeighbors(id, edgeType));
    }
    return ins;
  }

  /// Execute multiple patterns and concatenate row results (deduplicated).
  List<Map<String, dynamic>> matchRowsMany(
    List<String> patterns, {
    String? startId,
    List<String>? startIds,
  }) {
    final out = <Map<String, dynamic>>[];
    final seen = <String>{};
    for (final p in patterns) {
      final rows = matchRows(p, startId: startId, startIds: startIds);
      for (final r in rows) {
        final keys = r.keys.toList()..sort();
        final sig = keys.map((k) => '$k=${r[k]}').join('|');
        if (seen.add(sig)) out.add(r);
      }
    }
    return out;
  }

  /// Execute multiple patterns and unions the results by variable name.
  Map<String, Set<String>> matchMany(
    List<String> patterns, {
    String? startId,
    List<String>? startIds,
  }) {
    final combined = <String, Set<String>>{};
    for (final pattern in patterns) {
      final results = match(pattern, startId: startId, startIds: startIds);
      for (final entry in results.entries) {
        combined.putIfAbsent(entry.key, () => {}).addAll(entry.value);
      }
    }
    return combined;
  }

  /// Execute multiple patterns and return path matches with edge information.
  List<PathMatch> matchPathsMany(
    List<String> patterns, {
    String? startId,
    List<String>? startIds,
  }) {
    final out = <PathMatch>[];
    final seen = <String>{};
    for (final pattern in patterns) {
      final paths = matchPaths(pattern, startId: startId, startIds: startIds);
      for (final path in paths) {
        final keys = path.nodes.keys.toList()..sort();
        final sig = keys.map((k) => '$k=${path.nodes[k]}').join('|');
        if (seen.add(sig)) out.add(path);
      }
    }
    return out;
  }

  /// Extract RETURN items from parse tree
  List<ReturnItem> _extractReturnItems(dynamic returnClause) {
    final items = <ReturnItem>[];

    if (returnClause is! List || returnClause.length < 4) return items;

    // returnClause structure: [whitespace, 'RETURN', whitespace, returnItems]
    final returnItemsSection = returnClause[3];
    if (returnItemsSection is! List) return items;

    // returnItemsSection: [first_item, [[whitespace, comma, whitespace, item], ...]]
    if (returnItemsSection.isEmpty) return items;

    // Parse first item
    final firstItem = _parseReturnItem(returnItemsSection[0]);
    if (firstItem != null) items.add(firstItem);

    // Parse remaining items (if any)
    if (returnItemsSection.length > 1 && returnItemsSection[1] is List) {
      final moreItems = returnItemsSection[1] as List;
      for (final itemGroup in moreItems) {
        if (itemGroup is List && itemGroup.length >= 4) {
          // itemGroup: [whitespace, comma, whitespace, item]
          final item = _parseReturnItem(itemGroup[3]);
          if (item != null) items.add(item);
        }
      }
    }

    return items;
  }

  /// Parse a single return item from parse tree
  ReturnItem? _parseReturnItem(dynamic itemTree) {
    if (itemTree is! List || itemTree.isEmpty) return null;

    // itemTree: [(propertyAccess | variable), optional_AS_alias]
    final valueSection = itemTree[0];
    final aliasSection = itemTree.length > 1 ? itemTree[1] : null;

    String? alias;
    if (aliasSection is List && aliasSection.isNotEmpty) {
      // aliasSection: [whitespace, 'AS', whitespace, variable]
      if (aliasSection.length >= 4) {
        alias = _flattenToString(aliasSection[3]);
      }
    }

    // Check if it's a property access (variable.property)
    final valueStr = _flattenToString(valueSection);
    if (valueStr.contains('.')) {
      final parts = valueStr.split('.');
      if (parts.length == 2) {
        return ReturnItem(
          propertyVariable: parts[0].trim(),
          propertyName: parts[1].trim(),
          alias: alias,
        );
      }
    }

    // Simple variable
    return ReturnItem(variable: valueStr.trim(), alias: alias);
  }

  /// Apply RETURN clause: filter variables and resolve properties
  ///
  /// Throws [ArgumentError] if:
  /// - A requested variable doesn't exist in the pattern
  /// - Duplicate aliases are specified
  List<Map<String, dynamic>> _applyReturnClause(
    List<Map<String, String>> rows,
    List<ReturnItem> returnItems,
    _QueryContext context,
  ) {
    if (returnItems.isEmpty) {
      return rows.map((row) => row.cast<String, dynamic>()).toList();
    }

    // Validate: check for duplicate AS aliases (explicit duplicates only)
    final aliasNames = <String>{};
    for (final item in returnItems) {
      if (item.alias != null) {
        if (!aliasNames.add(item.alias!)) {
          throw ArgumentError(
            'Duplicate alias in RETURN clause: ${item.alias}',
          );
        }
      }
    }

    // Validate: check that all requested variables exist (use first row as sample)
    if (rows.isNotEmpty) {
      final sampleRow = rows.first;
      final availableVars = sampleRow.keys.toSet();

      for (final item in returnItems) {
        final varName = item.sourceVariable;
        if (!availableVars.contains(varName)) {
          throw ArgumentError(
            'Variable "$varName" in RETURN clause does not exist in pattern. '
            'Available variables: ${availableVars.join(", ")}',
          );
        }
      }
    }

    final results = <Map<String, dynamic>>[];

    for (final row in rows) {
      final resultRow = <String, dynamic>{};

      for (final item in returnItems) {
        final columnName = item.columnName;

        if (item.isProperty) {
          final variable = item.sourceVariable;
          final propertyName = item.propertyName!;

          // Node property projection
          if (!context.edgeBindings.containsKey(variable)) {
            final nodeId = row[variable];
            if (nodeId != null) {
              final node = graph.nodesById[nodeId];
              if (node != null) {
                resultRow[columnName] = _readNodeProperty(node, propertyName);
                continue;
              }
            }
          }

          // Edge property projection
          if (context.edgeBindings.containsKey(variable)) {
            final edgeValue = _resolveEdgePropertyValue(
              row,
              variable,
              propertyName,
              context,
            );
            resultRow[columnName] = edgeValue;
            continue;
          }

          resultRow[columnName] = null;
        } else {
          // Simple variable: person
          final nodeId = row[item.variable];
          resultRow[columnName] = nodeId; // Can be null if variable not in row
        }
      }

      results.add(resultRow);
    }

    return results;
  }

  /// Apply WHERE clause filtering to rows
  List<Map<String, String>> _applyWhereClause(
    List<Map<String, String>> rows,
    dynamic whereClause,
    _QueryContext context,
  ) {
    if (whereClause == null) return rows;

    return rows
        .where((row) => _evaluateWhereExpression(row, whereClause, context))
        .toList();
  }

  bool _evaluateWhereExpression(
    Map<String, String> row,
    dynamic whereExpr,
    _QueryContext context,
  ) {
    if (whereExpr is! List) return true;

    // Navigate to the actual WHERE expression content
    // Structure: [WHERE, whitespace, expression]
    if (whereExpr.length >= 3 && whereExpr[0] == 'WHERE') {
      return _evaluateExpression(row, whereExpr[2], context);
    }

    // Direct expression evaluation
    return _evaluateExpression(row, whereExpr, context);
  }

  bool _evaluateExpression(
    Map<String, String> row,
    dynamic expr,
    _QueryContext context,
  ) {
    if (expr is! List) return true;
    if (expr.isEmpty) return true;

    // Handle OR expressions (lower precedence)
    // Structure: [first_term, [OR_operations]*]
    if (expr.length >= 2 && expr[1] is List) {
      final orOperations = expr[1] as List;
      bool result = _evaluateAndExpression(row, expr[0], context);

      for (final op in orOperations) {
        if (op is List && op.length >= 4 && _containsString(op, 'OR')) {
          final rightExpr = op[3]; // The expression after OR
          final rightResult = _evaluateAndExpression(row, rightExpr, context);
          result = result || rightResult;
        }
      }
      return result;
    }

    // Single expression (no OR)
    return _evaluateAndExpression(row, expr, context);
  }

  bool _evaluateAndExpression(
    Map<String, String> row,
    dynamic expr,
    _QueryContext context,
  ) {
    if (expr is! List) return true;
    if (expr.isEmpty) return true;

    // Handle AND expressions (higher precedence)
    // Structure: [first_term, [AND_operations]*]
    if (expr.length >= 2 && expr[1] is List) {
      final andOperations = expr[1] as List;
      bool result = _evaluatePrimaryExpression(row, expr[0], context);

      for (final op in andOperations) {
        if (op is List && op.length >= 4 && _containsString(op, 'AND')) {
          final rightExpr = op[3]; // The expression after AND
          final rightResult = _evaluatePrimaryExpression(
            row,
            rightExpr,
            context,
          );
          result = result && rightResult;
        }
      }
      return result;
    }

    // Single expression (no AND)
    return _evaluatePrimaryExpression(row, expr, context);
  }

  bool _evaluatePrimaryExpression(
    Map<String, String> row,
    dynamic expr,
    _QueryContext context,
  ) {
    if (expr is! List) return true;
    if (expr.isEmpty) return true;

    // Check for parenthesized expressions: [('(', whitespace, content, whitespace, ')')]
    if (expr.length == 5 && expr[0] == '(' && expr[4] == ')') {
      return _evaluateExpression(
        row,
        expr[2],
        context,
      ); // Evaluate the content inside parentheses
    }

    // Check for comparison expressions: [property_expr, whitespace, operator, whitespace, value]
    if (expr.length == 5) {
      return _evaluateComparisonExpression(row, expr, context);
    }

    return true;
  }

  bool _evaluateComparisonExpression(
    Map<String, String> row,
    dynamic expr,
    _QueryContext context,
  ) {
    if (expr is! List || expr.length != 5) return false;

    // Extract property expression (e.g., "person.age" or "type(r)")
    final propertyExpr = expr[0];
    final operator = expr[2];
    final valueExpr = expr[4];

    final propertyStr = _flattenToString(propertyExpr);
    final operatorStr = _flattenToString(operator);
    final valueStr = _flattenToString(valueExpr);

    // Check for type(variable) function call on LEFT side
    final typeFuncMatch = RegExp(
      r'type\s*\(\s*(\w+)\s*\)',
    ).firstMatch(propertyStr);
    if (typeFuncMatch != null) {
      // This is a type(r) function - get the edge type from the row
      final variable = typeFuncMatch.group(1)!;
      final propValue = row[variable];
      if (propValue == null) return false; // Variable doesn't exist in row

      // Check if RIGHT side is ALSO a type(variable) function (variable-to-variable comparison)
      final rightTypeFuncMatch = RegExp(
        r'type\s*\(\s*(\w+)\s*\)',
      ).firstMatch(valueStr);
      if (rightTypeFuncMatch != null) {
        // Variable-to-variable comparison: type(r2) = type(r)
        final rightVariable = rightTypeFuncMatch.group(1)!;
        final rightValue = row[rightVariable];
        if (rightValue == null)
          return false; // Right variable doesn't exist in row

        // Compare the two edge types
        return _compareValues(propValue, operatorStr, rightValue);
      }

      // Right side is a literal value
      final comparisonValue = _parseValue(valueStr);
      return _compareValues(propValue, operatorStr, comparisonValue);
    }

    // Parse property.field for node properties
    final propMatch = RegExp(r'(\w+)\.(\w+)').firstMatch(propertyStr);
    if (propMatch == null) return false; // Invalid property syntax should fail

    final variable = propMatch.group(1)!;
    final property = propMatch.group(2)!;

    if (context.edgeBindings.containsKey(variable)) {
      return _evaluateEdgePropertyComparison(
        row,
        variable,
        property,
        operatorStr,
        valueStr,
        context,
      );
    }

    // Get node ID from row
    final nodeId = row[variable];
    if (nodeId == null)
      return false; // Variable doesn't exist in row should fail

    // Get node from graph
    final node = graph.nodesById[nodeId];
    if (node == null) return false; // Node doesn't exist should fail

    // Get property value - check direct Node properties first
    dynamic propValue;
    switch (property) {
      case 'id':
        propValue = node.id;
        break;
      case 'type':
        propValue = node.type;
        break;
      case 'label':
        propValue = node.label;
        break;
      default:
        // Check custom properties
        propValue = node.properties?[property];
        if (propValue == null) return false;
    }

    // Parse comparison value
    final comparisonValue = _parseValue(valueStr);

    return _compareValues(propValue, operatorStr, comparisonValue);
  }

  bool _evaluateEdgePropertyComparison(
    Map<String, String> row,
    String edgeVar,
    String property,
    String operator,
    String valueStr,
    _QueryContext context,
  ) {
    final binding = context.edgeBindings[edgeVar];
    if (binding == null) return false;

    final fromId = row[binding.fromAlias];
    final toId = row[binding.toAlias];
    final edgeType = row[edgeVar];

    if (fromId == null || toId == null || edgeType == null) return false;

    final edgeProps = graph.edgeProperties(fromId, edgeType, toId);
    final propValue = _readEdgeProperty(
      fromId,
      toId,
      edgeType,
      edgeProps,
      property,
    );
    if (propValue == null) return false;

    final comparisonValue = _parseValue(valueStr);
    return _compareValues(propValue, operator, comparisonValue);
  }

  dynamic _resolveEdgePropertyValue(
    Map<String, String> row,
    String edgeVar,
    String property,
    _QueryContext context,
  ) {
    final binding = context.edgeBindings[edgeVar];
    if (binding == null) return null;

    final fromId = row[binding.fromAlias];
    final toId = row[binding.toAlias];
    final edgeType = row[edgeVar];
    if (fromId == null || toId == null || edgeType == null) return null;

    final edgeProps = graph.edgeProperties(fromId, edgeType, toId);
    return _readEdgeProperty(fromId, toId, edgeType, edgeProps, property);
  }

  dynamic _parseValue(String valueStr) {
    final trimmed = valueStr.trim();

    // String literal
    if (trimmed.startsWith('"') && trimmed.endsWith('"')) {
      return trimmed.substring(1, trimmed.length - 1);
    }

    // Boolean
    if (trimmed == 'true') return true;
    if (trimmed == 'false') return false;

    // Number
    final numValue = int.tryParse(trimmed);
    if (numValue != null) return numValue;

    final doubleValue = double.tryParse(trimmed);
    if (doubleValue != null) return doubleValue;

    return trimmed;
  }

  bool _compareValues(
    dynamic propValue,
    String operator,
    dynamic comparisonValue,
  ) {
    try {
      // Boolean comparison
      if (propValue is bool && comparisonValue is bool) {
        switch (operator) {
          case '=':
            return propValue == comparisonValue;
          case '!=':
            return propValue != comparisonValue;
          default:
            return false; // Other operators not supported for booleans
        }
      }

      // Numeric comparison
      if (propValue is num && comparisonValue is num) {
        switch (operator) {
          case '>':
            return propValue > comparisonValue;
          case '<':
            return propValue < comparisonValue;
          case '>=':
            return propValue >= comparisonValue;
          case '<=':
            return propValue <= comparisonValue;
          case '=':
            return propValue == comparisonValue;
          case '!=':
            return propValue != comparisonValue;
        }
      }

      // String comparison
      final propStr = propValue.toString();
      final compStr = comparisonValue.toString();

      switch (operator) {
        case '=':
          return propStr == compStr;
        case '!=':
          return propStr != compStr;
        case 'CONTAINS':
          return propStr.toLowerCase().contains(compStr.toLowerCase());
        case 'STARTS WITH':
          return propStr.startsWith(compStr);
        default:
          return false; // Other operators not supported for strings
      }
    } catch (e) {
      return false;
    }
  }

  bool _containsString(dynamic expr, String target) {
    if (expr is String) return expr == target;
    if (expr is List) {
      for (final item in expr) {
        if (_containsString(item, target)) return true;
      }
    }
    return false;
  }
}

class _NodePatternMetadata {
  _NodePatternMetadata({
    required this.alias,
    this.type,
    List<_PropertyConstraint>? constraints,
  }) : constraints = constraints ?? const [];

  final String alias;
  final String? type;
  final List<_PropertyConstraint> constraints;
}

class _PropertyConstraint {
  const _PropertyConstraint({
    required this.key,
    required this.operator,
    required this.value,
  });

  final String key;
  final _PropertyOperator operator;
  final dynamic value;
}

enum _PropertyOperator { equals, contains }

class _EdgeVariableBinding {
  const _EdgeVariableBinding({
    required this.variable,
    required this.fromAlias,
    required this.toAlias,
  });

  final String variable;
  final String fromAlias;
  final String toAlias;
}

class _QueryContext {
  const _QueryContext({this.edgeBindings = const {}});

  final Map<String, _EdgeVariableBinding> edgeBindings;
}

class _OperatorMatch {
  const _OperatorMatch(this.index, this.operator);

  final int index;
  final _PropertyOperator operator;
}
