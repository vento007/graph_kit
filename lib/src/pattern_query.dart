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
  List<Map<String, dynamic>> matchRows(String pattern, {String? startId, List<String>? startIds, String? startType}) {
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
        patternWithWhere = result.value.length > 1 ? result.value[1] : result.value[0];
        if (result.value.length >= 3) {
          returnClause = result.value[2];
        }
      }

      if (patternWithWhere is List && patternWithWhere.isNotEmpty) {
        // Extract pattern (first element)
        _extractPartsFromParseTree(patternWithWhere[0], parts, directions);

        // Extract WHERE clause if present (second element is [whitespace, WHERE_clause])
        if (patternWithWhere.length > 1 && patternWithWhere[1] != null && patternWithWhere[1] is List) {
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

          // Optional: skip if type doesn't match
          if (startType != null) {
            // Extract type from pattern part
            final typeMatch = RegExp(r':(\w+)').firstMatch(parts[i]);
            if (typeMatch != null) {
              final nodeType = typeMatch.group(1);
              if (nodeType != startType) {
                continue;  // Skip positions that don't match type
              }
            }
          }

          // Seed this position
          final seedRows = <Map<String, String>>[{alias: singleStartId}];

          // Execute from this position
          final results = _executeFromPosition(seedRows, parts, directions, i);
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
      _seedFromFirstSegment(parts.first, firstAlias, currentRows);
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
        if (edgeTypes == null || edgeTypes.isEmpty) {
          return const <Map<String, dynamic>>[];
        }

        // Check if this is a variable-length relationship
        final variableLengthSpec = _extractVariableLengthSpec(edgePart);
        if (variableLengthSpec != null) {
          // Handle variable-length relationship using enumeratePaths
          final vlResults = _executeVariableLengthSegment(
            currentRows, aliasHere, nextAlias, edgeTypes, variableLengthSpec, isForward
          );
          currentRows = vlResults;
        } else {
          // Handle single-hop relationship (existing logic)
          currentRows = _executeSingleHopSegment(
            currentRows, aliasHere, nextAlias, edgeTypes, isForward
          );
        }

        if (currentRows.isEmpty) break;
      }
    }

    // Apply WHERE clause filtering if present
    if (whereClause != null) {
      currentRows = _applyWhereClause(currentRows, whereClause);
    }

    // Apply RETURN clause if present (filtering and property resolution)
    if (returnItems != null) {
      return _applyReturnClause(currentRows, returnItems);
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
    int startIndex,
  ) {
    var currentRows = seedRows;

    // Execute backward from startIndex-1 to 0
    for (var i = startIndex - 1; i >= 0; i--) {
      final aliasHere = _aliasOf(parts[i + 1]); // Current position (reversed)
      final nextAlias = _aliasOf(parts[i]);      // Target position

      // Get edge info from appropriate part
      final isForwardInPattern = directions[i];
      final edgePart = isForwardInPattern ? parts[i] : parts[i + 1];
      final edgeTypes = _edgeTypeFrom(edgePart);

      if (edgeTypes == null || edgeTypes.isEmpty) {
        return const <Map<String, String>>[];
      }

      // Reverse direction when going backward
      final isForward = !isForwardInPattern;

      // Check for variable-length
      final variableLengthSpec = _extractVariableLengthSpec(edgePart);
      if (variableLengthSpec != null) {
        currentRows = _executeVariableLengthSegment(
          currentRows, aliasHere, nextAlias, edgeTypes, variableLengthSpec, isForward
        );
      } else {
        currentRows = _executeSingleHopSegment(
          currentRows, aliasHere, nextAlias, edgeTypes, isForward
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

      if (edgeTypes == null || edgeTypes.isEmpty) {
        return const <Map<String, String>>[];
      }

      // Check for variable-length
      final variableLengthSpec = _extractVariableLengthSpec(edgePart);
      if (variableLengthSpec != null) {
        currentRows = _executeVariableLengthSegment(
          currentRows, aliasHere, nextAlias, edgeTypes, variableLengthSpec, isForward
        );
      } else {
        currentRows = _executeSingleHopSegment(
          currentRows, aliasHere, nextAlias, edgeTypes, isForward
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
  ) {
    final nextRows = <Map<String, String>>[];
    final seen = <String>{};

    for (final row in currentRows) {
      final srcId = row[aliasHere];
      if (srcId == null) continue;

      // Collect neighbors matching ANY of the edge types (OR logic)
      final allNeighbors = <String>{};
      for (final edgeType in edgeTypes) {
        final neighbors = isForward
            ? graph.outNeighbors(srcId, edgeType)
            : graph.inNeighbors(srcId, edgeType);
        allNeighbors.addAll(neighbors);
      }

      for (final nb in allNeighbors) {
        final newRow = Map<String, String>.from(row);
        newRow[nextAlias] = nb;
        final keys = newRow.keys.toList()..sort();
        final sig = keys.map((k) => '$k=${newRow[k]}').join('|');
        if (seen.add(sig)) {
          nextRows.add(newRow);
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
          srcId, edgeType, vlSpec, isForward
        );
        allDestinations.addAll(destinations);
      }

      for (final destId in allDestinations) {
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

  Map<String, Set<String>> match(String pattern, {String? startId, List<String>? startIds, String? startType}) {
    final paths = matchPaths(pattern, startId: startId, startIds: startIds, startType: startType);
    final results = <String, Set<String>>{};
    for (final path in paths) {
      for (final entry in path.nodes.entries) {
        results.putIfAbsent(entry.key, () => <String>{}).add(entry.value);
      }
    }
    return results;
  }

  List<PathMatch> matchPaths(String pattern, {String? startId, List<String>? startIds, String? startType}) {
    final hasReturn = RegExp(r'\s+RETURN\s+', caseSensitive: false).hasMatch(pattern);

    if (!hasReturn) {
      final rows = matchRows(pattern, startId: startId, startIds: startIds, startType: startType);
      final pathMatches = <PathMatch>[];

      for (final row in rows) {
        final nodeIds = <String, String>{};
        for (final entry in row.entries) {
          if (entry.value is String) nodeIds[entry.key] = entry.value as String;
        }
        final sequences = _buildPathEdgeSequencesForRow(pattern, nodeIds);
        for (final edges in sequences) {
          pathMatches.add(PathMatch(nodes: Map<String, String>.from(nodeIds), edges: edges));
        }
      }
      return pathMatches;
    }

    final filteredRows = matchRows(pattern, startId: startId, startIds: startIds);
    final patternWithoutReturn = pattern.replaceAll(RegExp(r'\s+RETURN\s+.+$', caseSensitive: false), '');
    final unfilteredRows = matchRows(patternWithoutReturn, startId: startId, startIds: startIds);

    final pathMatches = <PathMatch>[];

    for (var i = 0; i < filteredRows.length && i < unfilteredRows.length; i++) {
      final filteredIds = <String, String>{};
      for (final entry in filteredRows[i].entries) {
        if (entry.value is String) filteredIds[entry.key] = entry.value as String;
      }

      final unfilteredIds = <String, String>{};
      for (final entry in unfilteredRows[i].entries) {
        if (entry.value is String) unfilteredIds[entry.key] = entry.value as String;
      }

      final sequences = _buildPathEdgeSequencesForRow(patternWithoutReturn, unfilteredIds);
      for (final edges in sequences) {
        pathMatches.add(PathMatch(nodes: Map<String, String>.from(filteredIds), edges: edges));
      }
    }

    return pathMatches;
  }

  // Extract segments and directions from parse tree (visible for testing)
  void extractPartsFromParseTreeForTesting(dynamic parseTree, List<String> parts, List<bool> directions) {
    _extractPartsFromParseTree(parseTree, parts, directions);
  }

  void _extractPartsFromParseTree(dynamic parseTree, List<String> parts, List<bool> directions) {
    if (parseTree is! List) return;

    // First element is the initial segment
    final firstSegment = parseTree[0];
    parts.add(_flattenSegment(firstSegment));

    // Remaining elements are [connection, segment] pairs
    if (parseTree.length > 1 && parseTree[1] is List) {
      final connections = parseTree[1] as List;
      for (final connectionPair in connections) {
        if (connectionPair is List && connectionPair.length >= 2) {
          final connection = connectionPair[0];
          final segment = connectionPair[1];

          // Determine direction from connection
          final connectionStr = _flattenConnection(connection);
          directions.add(connectionStr.contains('->'));

          // Add edge info to the appropriate part based on direction
          final edgeInfo = _extractEdgeFromConnection(connection);
          final isForward = connectionStr.contains('->');

          if (isForward) {
            // Forward: edge info goes with current (source) part
            if (parts.isNotEmpty && edgeInfo.isNotEmpty) {
              parts[parts.length - 1] = parts[parts.length - 1] + edgeInfo;
            }
            parts.add(_flattenSegment(segment));
          } else {
            // Backward: edge info goes with next (target) part
            final nextSegment = _flattenSegment(segment);
            if (edgeInfo.isNotEmpty) {
              parts.add(nextSegment + edgeInfo);
            } else {
              parts.add(nextSegment);
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


  String _flattenSegment(dynamic segment) {
    if (segment is List && segment.length >= 3) {
      final variable = _flattenToString(segment[0]);
      final nodeType = segment[1] != null ? ':${_flattenToString(segment[1]).replaceFirst(':', '')}' : '';
      final labelFilter = segment[2] != null ? _flattenToString(segment[2]) : '';
      return variable + nodeType + labelFilter;
    }
    return _flattenToString(segment);
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

  void _seedFromFirstSegment(String firstPart, String firstAlias, List<Map<String, String>> currentRows) {
    // Extract type and label info from the first part string
    // Since we already flattened the parse tree to a string, we can parse it similar to original
    String? nodeType;
    String? labelOp; // '=' or '~'
    String? labelVal;

    // Remove edge info from descriptor for seeding (e.g., "person:Person[:WORKS_FOR]" -> "person:Person")
    String descriptor = firstPart;
    final edgeStart = descriptor.indexOf('[');
    if (edgeStart != -1) {
      descriptor = descriptor.substring(0, edgeStart);
    }
    String head = descriptor;

    // Handle label filter
    final braceStart = descriptor.indexOf('{');
    if (braceStart != -1) {
      if (!descriptor.endsWith('}')) {
        return; // malformed label filter
      }
      head = descriptor.substring(0, braceStart).trim();
      final inside = descriptor
          .substring(braceStart + 1, descriptor.length - 1)
          .trim();
      final m = RegExp(r'^label\s*([=~])\s*(.+)$').firstMatch(inside);
      if (m != null) {
        labelOp = m.group(1);
        labelVal = m.group(2);
        if (labelVal == null || labelVal.trim().isEmpty) {
          return;
        }
      } else if (inside.isNotEmpty) {
        return; // malformed
      }
    }

    // Handle node type
    if (head.contains(':')) {
      final typeParts = head.split(':');
      nodeType = typeParts.length > 1 ? typeParts[1].trim() : null;
    }

    // Seed by scanning nodes matching type/label (copied from original)
    for (final node in graph.nodesById.values) {
      if (nodeType != null && node.type != nodeType) continue;
      if (labelOp != null && labelVal != null) {
        if (labelOp == '=') {
          if (node.label != labelVal) continue;
        } else if (labelOp == '~') {
          final hay = node.label.toLowerCase();
          final needle = labelVal.toLowerCase();
          if (!hay.contains(needle)) continue;
        }
      }
      currentRows.add({firstAlias: node.id});
    }
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
          if (c == ']') break;
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
              if (fullContent.contains('*')) {
                fullContent = fullContent.split('*')[0];
              }
              // Split by | to support multiple types
              final types = fullContent.split('|').map((t) => t.trim()).where((t) => t.isNotEmpty).toList();
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
        if (ch == '-' && i + 1 < cleanPattern.length && cleanPattern[i + 1] == '>') {
          parts.add(cleanPattern.substring(lastSplit, i).trim());
          directions.add(true);
          i += 2;
          lastSplit = i;
          continue;
        }
        if (ch == '<' && i + 1 < cleanPattern.length && cleanPattern[i + 1] == '-') {
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
      final edgeTypes = _edgeTypeFrom(edgePart);
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

      // Create the edge based on direction
      if (isForward) {
        edges.add(
          PathEdge(
            from: row[fromVar]!,
            to: row[toVar]!,
            type: actualEdgeType,
            fromVariable: fromVar,
            toVariable: toVar,
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
          ),
        );
      }
    }

    return edges;
  }

  List<List<PathEdge>> _buildPathEdgeSequencesForRow(String pattern, Map<String, String> row) {
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
        if (ch == '-' && i + 1 < cleanPattern.length && cleanPattern[i + 1] == '>') {
          parts.add(cleanPattern.substring(lastSplit, i).trim());
          directions.add(true);
          i += 2;
          lastSplit = i;
          continue;
        }
        if (ch == '<' && i + 1 < cleanPattern.length && cleanPattern[i + 1] == '-') {
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
      if (!row.containsKey(fromVar) || !row.containsKey(toVar)) return const <List<PathEdge>>[];

      final edgePart = isForward ? fromPart : toPart;
      final edgeTypes = _edgeTypeFrom(edgePart);
      if (edgeTypes == null || edgeTypes.isEmpty) return const <List<PathEdge>>[];

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

        final hopEdge = isForward
            ? PathEdge(from: row[fromVar]!, to: row[toVar]!, type: actualType, fromVariable: fromVar, toVariable: toVar)
            : PathEdge(from: row[toVar]!, to: row[fromVar]!, type: actualType, fromVariable: toVar, toVariable: fromVar);

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

          final edge = isForward
              ? PathEdge(from: currentId, to: nb, type: type, fromVariable: fromVariable, toVariable: toVariable)
              : PathEdge(from: nb, to: currentId, type: type, fromVariable: toVariable, toVariable: fromVariable);

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
    // Updated regex to handle multiple types with | separator and variable-length *
    part = part.replaceAll(RegExp(r'\[\s*:[^\]]*\]'), '').trim();
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

  // --- Utility finder methods (copied from original) ---

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
    return ReturnItem(
      variable: valueStr.trim(),
      alias: alias,
    );
  }
  
  /// Apply RETURN clause: filter variables and resolve properties
  /// 
  /// Throws [ArgumentError] if:
  /// - A requested variable doesn't exist in the pattern
  /// - Duplicate aliases are specified
  List<Map<String, dynamic>> _applyReturnClause(
    List<Map<String, String>> rows,
    List<ReturnItem> returnItems,
  ) {
    if (returnItems.isEmpty) {
      return rows.map((row) => row.cast<String, dynamic>()).toList();
    }
    
    // Validate: check for duplicate AS aliases (explicit duplicates only)
    final aliasNames = <String>{};
    for (final item in returnItems) {
      if (item.alias != null) {
        if (!aliasNames.add(item.alias!)) {
          throw ArgumentError('Duplicate alias in RETURN clause: ${item.alias}');
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
            'Available variables: ${availableVars.join(", ")}'
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
          // Property access: person.name
          final nodeId = row[item.sourceVariable];
          if (nodeId != null) {
            final node = graph.nodesById[nodeId];
            final value = node?.properties?[item.propertyName];
            resultRow[columnName] = value; // Can be null if property doesn't exist
          } else {
            resultRow[columnName] = null; // Variable not in row
          }
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
  List<Map<String, String>> _applyWhereClause(List<Map<String, String>> rows, dynamic whereClause) {
    if (whereClause == null) return rows;

    return rows.where((row) => _evaluateWhereExpression(row, whereClause)).toList();
  }

  bool _evaluateWhereExpression(Map<String, String> row, dynamic whereExpr) {
    if (whereExpr is! List) return true;

    // Navigate to the actual WHERE expression content
    // Structure: [WHERE, whitespace, expression]
    if (whereExpr.length >= 3 && whereExpr[0] == 'WHERE') {
      return _evaluateExpression(row, whereExpr[2]);
    }

    // Direct expression evaluation
    return _evaluateExpression(row, whereExpr);
  }

  bool _evaluateExpression(Map<String, String> row, dynamic expr) {
    if (expr is! List) return true;
    if (expr.isEmpty) return true;

    // Handle OR expressions (lower precedence)
    // Structure: [first_term, [OR_operations]*]
    if (expr.length >= 2 && expr[1] is List) {
      final orOperations = expr[1] as List;
      bool result = _evaluateAndExpression(row, expr[0]);

      for (final op in orOperations) {
        if (op is List && op.length >= 4 && _containsString(op, 'OR')) {
          final rightExpr = op[3]; // The expression after OR
          final rightResult = _evaluateAndExpression(row, rightExpr);
          result = result || rightResult;
        }
      }
      return result;
    }

    // Single expression (no OR)
    return _evaluateAndExpression(row, expr);
  }

  bool _evaluateAndExpression(Map<String, String> row, dynamic expr) {
    if (expr is! List) return true;
    if (expr.isEmpty) return true;

    // Handle AND expressions (higher precedence)
    // Structure: [first_term, [AND_operations]*]
    if (expr.length >= 2 && expr[1] is List) {
      final andOperations = expr[1] as List;
      bool result = _evaluatePrimaryExpression(row, expr[0]);

      for (final op in andOperations) {
        if (op is List && op.length >= 4 && _containsString(op, 'AND')) {
          final rightExpr = op[3]; // The expression after AND
          final rightResult = _evaluatePrimaryExpression(row, rightExpr);
          result = result && rightResult;
        }
      }
      return result;
    }

    // Single expression (no AND)
    return _evaluatePrimaryExpression(row, expr);
  }

  bool _evaluatePrimaryExpression(Map<String, String> row, dynamic expr) {
    if (expr is! List) return true;
    if (expr.isEmpty) return true;

    // Check for parenthesized expressions: [('(', whitespace, content, whitespace, ')')]
    if (expr.length == 5 && expr[0] == '(' && expr[4] == ')') {
      return _evaluateExpression(row, expr[2]); // Evaluate the content inside parentheses
    }

    // Check for comparison expressions: [property_expr, whitespace, operator, whitespace, value]
    if (expr.length == 5) {
      return _evaluateComparisonExpression(row, expr);
    }

    return true;
  }

  bool _evaluateComparisonExpression(Map<String, String> row, dynamic expr) {
    if (expr is! List || expr.length != 5) return false;

    // Extract property expression (e.g., "person.age")
    final propertyExpr = expr[0];
    final operator = expr[2];
    final valueExpr = expr[4];

    final propertyStr = _flattenToString(propertyExpr);
    final operatorStr = _flattenToString(operator);
    final valueStr = _flattenToString(valueExpr);

    // Parse property.field
    final propMatch = RegExp(r'(\w+)\.(\w+)').firstMatch(propertyStr);
    if (propMatch == null) return false; // Invalid property syntax should fail

    final variable = propMatch.group(1)!;
    final property = propMatch.group(2)!;

    // Get node ID from row
    final nodeId = row[variable];
    if (nodeId == null) return false; // Variable doesn't exist in row should fail

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

  bool _compareValues(dynamic propValue, String operator, dynamic comparisonValue) {
    try {
      // Boolean comparison
      if (propValue is bool && comparisonValue is bool) {
        switch (operator) {
          case '=': return propValue == comparisonValue;
          case '!=': return propValue != comparisonValue;
          default: return false; // Other operators not supported for booleans
        }
      }
      
      // Numeric comparison
      if (propValue is num && comparisonValue is num) {
        switch (operator) {
          case '>': return propValue > comparisonValue;
          case '<': return propValue < comparisonValue;
          case '>=': return propValue >= comparisonValue;
          case '<=': return propValue <= comparisonValue;
          case '=': return propValue == comparisonValue;
          case '!=': return propValue != comparisonValue;
        }
      }
      
      // String comparison
      final propStr = propValue.toString();
      final compStr = comparisonValue.toString();

      switch (operator) {
        case '=': return propStr == compStr;
        case '!=': return propStr != compStr;
        case 'CONTAINS': return propStr.toLowerCase().contains(compStr.toLowerCase());
        default: return false; // Other operators not supported for strings
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