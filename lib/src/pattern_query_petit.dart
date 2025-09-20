// pattern_query_petit.dart
import 'package:petitparser/petitparser.dart';
import 'graph.dart';
import 'node.dart';

/// Represents variable-length relationship specifications.
class VariableLengthSpec {
  /// Minimum number of hops (null means no minimum)
  final int? minHops;

  /// Maximum number of hops (null means no maximum)
  final int? maxHops;

  const VariableLengthSpec({this.minHops, this.maxHops});

  /// Returns true if this represents unlimited hops (*)
  bool get isUnlimited => minHops == null && maxHops == null;

  /// Returns the effective maximum hops for path enumeration
  int get effectiveMaxHops => maxHops ?? 10; // Default reasonable limit

  /// Returns the effective minimum hops
  int get effectiveMinHops => minHops ?? 1;

  @override
  String toString() {
    if (isUnlimited) return '*';
    if (minHops != null && maxHops != null) return '*$minHops..$maxHops';
    if (minHops != null) return '*$minHops..';
    if (maxHops != null) return '*..$maxHops';
    return '*';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VariableLengthSpec &&
          runtimeType == other.runtimeType &&
          minHops == other.minHops &&
          maxHops == other.maxHops;

  @override
  int get hashCode => minHops.hashCode ^ maxHops.hashCode;
}

/// Represents an edge in a path result, containing connection information.
class PathEdge {
  /// Source node ID
  final String from;

  /// Target node ID
  final String to;

  /// Edge type (e.g., 'WORKS_FOR', 'MANAGES')
  final String type;

  /// Variable-length specification if this is a variable-length edge
  final VariableLengthSpec? variableLength;

  /// Variable name for source node from pattern (e.g., 'person')
  final String fromVariable;

  /// Variable name for target node from pattern (e.g., 'team')
  final String toVariable;

  const PathEdge({
    required this.from,
    required this.to,
    required this.type,
    required this.fromVariable,
    required this.toVariable,
    this.variableLength,
  });

  @override
  String toString() {
    final vlStr = variableLength != null ? variableLength.toString() : '';
    return '$fromVariable($from) -[:$type$vlStr]-> $toVariable($to)';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PathEdge &&
          runtimeType == other.runtimeType &&
          from == other.from &&
          to == other.to &&
          type == other.type &&
          fromVariable == other.fromVariable &&
          toVariable == other.toVariable &&
          variableLength == other.variableLength;

  @override
  int get hashCode =>
      from.hashCode ^
      to.hashCode ^
      type.hashCode ^
      fromVariable.hashCode ^
      toVariable.hashCode ^
      variableLength.hashCode;
}

/// Represents a complete path match result with both nodes and edges.
class PathMatch {
  /// Map of variable names to node IDs (same format as matchRows)
  final Map<String, String> nodes;

  /// Ordered list of edges in the path
  final List<PathEdge> edges;

  const PathMatch({required this.nodes, required this.edges});

  @override
  String toString() => 'PathMatch(nodes: $nodes, edges: $edges)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PathMatch &&
          runtimeType == other.runtimeType &&
          _mapEquals(nodes, other.nodes) &&
          _listEquals(edges, other.edges);

  @override
  int get hashCode => nodes.hashCode ^ edges.hashCode;

  bool _mapEquals<K, V>(Map<K, V> a, Map<K, V> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (final key in a.keys) {
      if (!b.containsKey(key) || a[key] != b[key]) return false;
    }
    return true;
  }

  bool _listEquals<T>(List<T> a, List<T> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// Grammar definition for Cypher-like patterns
class CypherPatternGrammar extends GrammarDefinition {
  @override
  Parser start() => ref0(pattern).end();

  Parser pattern() => ref0(segment) & (ref0(connection) & ref0(segment)).star();

  Parser segment() => ref0(variable) & ref0(nodeType).optional() & ref0(labelFilter).optional();

  Parser variable() => letter() & (letter() | digit() | char('_')).star();

  Parser nodeType() => char(':') & ref0(variable);

  Parser labelFilter() =>
    char('{') &
    string('label') &
    (char('=') | char('~')) &
    ref0(labelValue) &
    char('}');

  Parser labelValue() =>
    (letter() | digit() | char('_') | char(' ')).plus();

  Parser connection() => ref0(forwardArrow) | ref0(backwardArrow);

  Parser forwardArrow() => (string('->') | (char('-') & ref0(edgeType) & string('->')));

  Parser backwardArrow() => string('<-') & ref0(edgeType).optional() & char('-');

  Parser edgeType() => char('[') & char(':') & ref0(variable) & ref0(variableLengthModifier).optional() & char(']');

  Parser variableLengthModifier() =>
    char('*') &
    (
      (digit().plus().flatten() & string('..') & digit().plus().flatten()) | // *min..max
      (digit().plus().flatten() & string('..')) |                           // *min..
      (string('..') & digit().plus().flatten()) |                           // *..max
      digit().plus().flatten() |                                            // *n (exact)
      epsilon()                                                             // just *
    ).optional();
}

/// PetitParser-based pattern query implementation
class PetitPatternQuery<N extends Node> {
  final Graph<N> graph;
  late final Parser _parser;

  PetitPatternQuery(this.graph) {
    final definition = CypherPatternGrammar();
    _parser = definition.build();
  }

  /// Core implementation of pattern matching using parse tree
  List<Map<String, String>> matchRows(String pattern, {String? startId}) {
    final result = _parser.parse(pattern);
    if (result is Failure) {
      return const <Map<String, String>>[];
    }

    // TODO: Convert parse tree to parts and directions
    // For now, we'll use the same structure as original parser
    final parts = <String>[];
    final directions = <bool>[];

    // This is where we'll extract from parse tree instead of manual parsing
    _extractPartsFromParseTree(result.value, parts, directions);

    // Debug removed - working correctly

    if (parts.isEmpty) return const <Map<String, String>>[];

    // Helper to extract alias name from a part (copied from original)
    String aliasOf(String part) {
      if (part.startsWith('[')) {
        final afterEdge = part.substring(part.indexOf('-') + 1);
        return afterEdge.split(RegExp(r'[-\[:]')).first.trim();
      } else {
        return part.split(RegExp(r'[-\[:]')).first.trim();
      }
    }

    // Seed rows (copied logic from original)
    List<Map<String, String>> currentRows = <Map<String, String>>[];
    final firstAlias = aliasOf(parts.first);
    if (firstAlias.isEmpty) {
      return const <Map<String, String>>[];
    }

    if (startId != null) {
      currentRows = <Map<String, String>>[
        {firstAlias: startId},
      ];
    } else {
      // Parse optional type and label filter in first segment
      // TODO: Extract from parse tree instead of manual parsing
      _seedFromFirstSegment(parts.first, firstAlias, currentRows);
    }

    // Traverse over each hop, expanding rows (copied from original)
    for (var i = 0; i < parts.length - 1; i++) {
      final part = parts[i];
      final aliasHere = aliasOf(part);
      final nextAlias = aliasOf(parts[i + 1]);

      final isForward = directions[i];
      final edgePart = isForward ? part : parts[i + 1];
      final edgeType = _edgeTypeFrom(edgePart);
      if (edgeType == null) {
        return const <Map<String, String>>[];
      }
      final edgeTypeTrimmed = edgeType.trim();
      if (edgeTypeTrimmed.isEmpty) return const <Map<String, String>>[];

      // Check if this is a variable-length relationship
      final variableLengthSpec = _extractVariableLengthSpec(edgePart);
      if (variableLengthSpec != null) {
        // Handle variable-length relationship using enumeratePaths
        final vlResults = _executeVariableLengthSegment(
          currentRows, aliasHere, nextAlias, edgeTypeTrimmed, variableLengthSpec, isForward
        );
        currentRows = vlResults;
      } else {
        // Handle single-hop relationship (existing logic)
        currentRows = _executeSingleHopSegment(
          currentRows, aliasHere, nextAlias, edgeTypeTrimmed, isForward
        );
      }

      if (currentRows.isEmpty) break;
    }

    return currentRows;
  }

  /// Executes a single-hop relationship segment
  List<Map<String, String>> _executeSingleHopSegment(
    List<Map<String, String>> currentRows,
    String aliasHere,
    String nextAlias,
    String edgeType,
    bool isForward,
  ) {
    final nextRows = <Map<String, String>>[];
    final seen = <String>{};

    for (final row in currentRows) {
      final srcId = row[aliasHere];
      if (srcId == null) continue;
      final neighbors = isForward
          ? graph.outNeighbors(srcId, edgeType)
          : graph.inNeighbors(srcId, edgeType);
      for (final nb in neighbors) {
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
  List<Map<String, String>> _executeVariableLengthSegment(
    List<Map<String, String>> currentRows,
    String aliasHere,
    String nextAlias,
    String edgeType,
    VariableLengthSpec vlSpec,
    bool isForward,
  ) {
    final nextRows = <Map<String, String>>[];
    final seen = <String>{};

    for (final row in currentRows) {
      final srcId = row[aliasHere];
      if (srcId == null) continue;

      // Find all possible destinations within hop limits
      final destinations = _findVariableLengthDestinations(
        srcId, edgeType, vlSpec, isForward
      );

      for (final destId in destinations) {
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

  Map<String, Set<String>> match(String pattern, {String? startId}) {
    final paths = matchPaths(pattern, startId: startId);
    final results = <String, Set<String>>{};
    for (final path in paths) {
      for (final entry in path.nodes.entries) {
        results.putIfAbsent(entry.key, () => <String>{}).add(entry.value);
      }
    }
    return results;
  }

  List<PathMatch> matchPaths(String pattern, {String? startId}) {
    final rows = matchRows(pattern, startId: startId);
    final pathMatches = <PathMatch>[];
    for (final row in rows) {
      final edges = _buildEdgesForRow(pattern, row);
      pathMatches.add(PathMatch(nodes: row, edges: edges));
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
  String? _edgeTypeFrom(String segment) {
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
              // Extract just the edge type (before *)
              final fullContent = segment.substring(contentStart, k);
              if (fullContent.contains('*')) {
                return fullContent.split('*')[0];
              }
              return fullContent;
            }
          }
          k++;
        }
        return null;
      }
    }
    return null;
  }

  List<PathEdge> _buildEdgesForRow(String pattern, Map<String, String> row) {
    // TODO: Build edges from parse tree instead of re-parsing pattern
    // For now, return empty list - this will be implemented in a future version
    return <PathEdge>[];
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
  List<Map<String, String>> matchRowsMany(
    List<String> patterns, {
    String? startId,
  }) {
    final out = <Map<String, String>>[];
    final seen = <String>{};
    for (final p in patterns) {
      final rows = matchRows(p, startId: startId);
      for (final r in rows) {
        final keys = r.keys.toList()..sort();
        final sig = keys.map((k) => '$k=${r[k]}').join('|');
        if (seen.add(sig)) out.add(r);
      }
    }
    return out;
  }

  /// Execute multiple patterns and unions the results by variable name.
  Map<String, Set<String>> matchMany(List<String> patterns, {String? startId}) {
    final combined = <String, Set<String>>{};
    for (final pattern in patterns) {
      final results = match(pattern, startId: startId);
      for (final entry in results.entries) {
        combined.putIfAbsent(entry.key, () => {}).addAll(entry.value);
      }
    }
    return combined;
  }

  /// Execute multiple patterns and return path matches with edge information.
  List<PathMatch> matchPathsMany(List<String> patterns, {String? startId}) {
    final out = <PathMatch>[];
    final seen = <String>{};
    for (final pattern in patterns) {
      final paths = matchPaths(pattern, startId: startId);
      for (final path in paths) {
        final keys = path.nodes.keys.toList()..sort();
        final sig = keys.map((k) => '$k=${path.nodes[k]}').join('|');
        if (seen.add(sig)) out.add(path);
      }
    }
    return out;
  }
}