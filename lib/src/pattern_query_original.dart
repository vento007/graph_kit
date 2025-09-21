// // pattern_query.dart
// import 'graph.dart';
// import 'node.dart';

// /// Represents an edge in a path result, containing connection information.
// class PathEdge {
//   /// Source node ID
//   final String from;

//   /// Target node ID
//   final String to;

//   /// Edge type (e.g., 'WORKS_FOR', 'MANAGES')
//   final String type;

//   /// Variable name for source node from pattern (e.g., 'person')
//   final String fromVariable;

//   /// Variable name for target node from pattern (e.g., 'team')
//   final String toVariable;

//   const PathEdge({
//     required this.from,
//     required this.to,
//     required this.type,
//     required this.fromVariable,
//     required this.toVariable,
//   });

//   @override
//   String toString() => '$fromVariable($from) -[:$type]-> $toVariable($to)';

//   @override
//   bool operator ==(Object other) =>
//       identical(this, other) ||
//       other is PathEdge &&
//           runtimeType == other.runtimeType &&
//           from == other.from &&
//           to == other.to &&
//           type == other.type &&
//           fromVariable == other.fromVariable &&
//           toVariable == other.toVariable;

//   @override
//   int get hashCode =>
//       from.hashCode ^
//       to.hashCode ^
//       type.hashCode ^
//       fromVariable.hashCode ^
//       toVariable.hashCode;
// }

// /// Represents a complete path match result with both nodes and edges.
// class PathMatch {
//   /// Map of variable names to node IDs (same format as matchRows)
//   final Map<String, String> nodes;

//   /// Ordered list of edges in the path
//   final List<PathEdge> edges;

//   const PathMatch({required this.nodes, required this.edges});

//   @override
//   String toString() => 'PathMatch(nodes: $nodes, edges: $edges)';

//   @override
//   bool operator ==(Object other) =>
//       identical(this, other) ||
//       other is PathMatch &&
//           runtimeType == other.runtimeType &&
//           _mapEquals(nodes, other.nodes) &&
//           _listEquals(edges, other.edges);

//   @override
//   int get hashCode => nodes.hashCode ^ edges.hashCode;

//   bool _mapEquals<K, V>(Map<K, V> a, Map<K, V> b) {
//     if (identical(a, b)) return true;
//     if (a.length != b.length) return false;
//     for (final key in a.keys) {
//       if (!b.containsKey(key) || a[key] != b[key]) return false;
//     }
//     return true;
//   }

//   bool _listEquals<T>(List<T> a, List<T> b) {
//     if (identical(a, b)) return true;
//     if (a.length != b.length) return false;
//     for (int i = 0; i < a.length; i++) {
//       if (a[i] != b[i]) return false;
//     }
//     return true;
//   }
// }

// /// A powerful pattern-based query engine for graph traversal, inspired by Cypher.
// ///
// /// This class provides methods to execute graph queries using a mini-language
// /// that supports directional edges, type filtering, and label matching.
// ///
// /// ## Pattern Syntax
// /// - **Node aliases**: `user`, `group`, `policy` (variable names for results)
// /// - **Node types**: `user:User` (filter by node type)
// /// - **Label filters**: `user{label=Alice}` (exact) or `user{label~ice}` (contains)
// /// - **Directional edges**: `-[:MEMBER_OF]->` (outgoing) or `<-[:MEMBER_OF]-` (incoming)
// ///
// /// ## Example Patterns
// /// ```dart
// /// // All users and their groups
// /// 'user:User-[:MEMBER_OF]->group'
// ///
// /// // Policies from a specific user
// /// 'user-[:MEMBER_OF]->group-[:SOURCE]->policy'
// ///
// /// // Users who can reach a specific destination (backward traversal)
// /// 'destination<-[:DESTINATION]-group<-[:MEMBER_OF]-user'
// /// ```
// ///
// /// ## Usage
// /// ```dart
// /// final graph = Graph<Node>();
// /// // ... add nodes and edges ...
// ///
// /// final query = PatternQuery(graph);
// /// final results = query.match('user:User-[:MEMBER_OF]->group');
// /// print(results['user']);  // Set of user IDs
// /// print(results['group']); // Set of group IDs
// /// ```
// class PatternQuery<N extends Node> {
//   /// The graph to execute queries against.
//   final Graph<N> graph;

//   /// Creates a new pattern query engine for the given [graph].
//   PatternQuery(this.graph);

//   /// Executes a single pattern query and returns grouped results.
//   ///
//   /// Takes a pattern string and returns a map where keys are variable names
//   /// from the pattern and values are sets of matching node IDs.
//   ///
//   /// Parameters:
//   /// - [pattern]: The pattern string to execute (e.g., "user-[:MEMBER_OF]->group")
//   /// - [startId]: Optional starting node ID. If provided, the query begins from
//   ///   this specific node. If null, the first segment must include type/label
//   ///   filters to seed the query.
//   ///
//   /// Returns a map from variable names to sets of node IDs.
//   ///
//   /// Example:
//   /// ```dart
//   /// // Starting from a specific user
//   /// final results = query.match('user-[:MEMBER_OF]->group', startId: 'u1');
//   /// print(results['user']);  // {'u1'}
//   /// print(results['group']); // {'g1', 'g2'}
//   ///
//   /// // Using type filtering to seed
//   /// final results = query.match('user:User-[:MEMBER_OF]->group');
//   /// print(results['user']);  // {'u1', 'u2', 'u3'}
//   /// print(results['group']); // {'g1', 'g2', 'g3'}
//   /// ```
//   Map<String, Set<String>> match(String pattern, {String? startId}) {
//     // Use matchPaths to get correct connected paths only
//     final paths = matchPaths(pattern, startId: startId);

//     // Extract nodes from actual paths
//     final results = <String, Set<String>>{};
//     for (final path in paths) {
//       for (final entry in path.nodes.entries) {
//         results.putIfAbsent(entry.key, () => <String>{}).add(entry.value);
//       }
//     }
//     return results;
//   }

//   /// Executes multiple patterns and unions the results by variable name.
//   ///
//   /// This method is equivalent to running multiple independent queries and
//   /// combining their results, similar to multiple MATCH clauses in Cypher.
//   /// Results are unioned - if the same node ID appears in multiple patterns
//   /// for the same variable, it appears only once in the final result.
//   ///
//   /// Parameters:
//   /// - [patterns]: List of pattern strings to execute
//   /// - [startId]: Optional starting node ID applied to all patterns
//   ///
//   /// Returns a map where each key is a variable name and each value is the
//   /// union of all node IDs matching that variable across all patterns.
//   ///
//   /// Example:
//   /// ```dart
//   /// final results = query.matchMany([
//   ///   'user-[:HAS_CLIENT]->client',
//   ///   'user-[:MEMBER_OF]->group-[:SOURCE]->policy',
//   ///   'user-[:MEMBER_OF]->group-[:DESTINATION]->asset',
//   /// ], startId: 'u1');
//   ///
//   /// // Results contain all related entities from the user
//   /// print(results['client']); // All clients
//   /// print(results['group']);  // All groups
//   /// print(results['policy']); // All policies
//   /// print(results['asset']);  // All assets
//   /// ```
//   Map<String, Set<String>> matchMany(List<String> patterns, {String? startId}) {
//     final combined = <String, Set<String>>{};

//     for (final pattern in patterns) {
//       final results = match(pattern, startId: startId);
//       for (final entry in results.entries) {
//         combined.putIfAbsent(entry.key, () => {}).addAll(entry.value);
//       }
//     }

//     return combined;
//   }

//   /// Executes a pattern and returns row-wise bindings, similar to Cypher MATCH results.
//   ///
//   /// Unlike [match] which groups results by variable name, this method returns
//   /// each complete path as a separate row, preserving the relationships between
//   /// variables. This is useful when you need to know which specific combinations
//   /// of nodes are connected.
//   ///
//   /// Each row is a map from variable name to the specific node ID matched in
//   /// that path traversal.
//   ///
//   /// Parameters:
//   /// - [pattern]: The pattern string to execute
//   /// - [startId]: Optional starting node ID
//   ///
//   /// Returns a list of maps, where each map represents one complete path match.
//   ///
//   /// Example:
//   /// ```dart
//   /// final rows = query.matchRows(
//   ///   'user-[:MEMBER_OF]->group-[:SOURCE]->policy-[:DESTINATION]->asset',
//   ///   startId: 'u1'
//   /// );
//   ///
//   /// // Each row shows a complete path:
//   /// // [{user: u1, group: g1, policy: p1, asset: a1},
//   /// //  {user: u1, group: g1, policy: p2, asset: a2},
//   /// //  {user: u1, group: g2, policy: p3, asset: a3}]
//   ///
//   /// // Build asset -> policies mapping from rows
//   /// final assetToPolicies = <String, Set<String>>{};
//   /// for (final row in rows) {
//   ///   final asset = row['asset']!;
//   ///   final policy = row['policy']!;
//   ///   assetToPolicies.putIfAbsent(asset, () => {}).add(policy);
//   /// }
//   /// ```
//   List<Map<String, String>> matchRows(String pattern, {String? startId}) {
//     // Strip optional MATCH keyword (Cypher compatibility)
//     var cleanPattern = pattern.trim();
//     if (cleanPattern.toUpperCase().startsWith('MATCH ')) {
//       cleanPattern = cleanPattern.substring(6).trim();
//     }

//     // Empty or whitespace-only pattern -> no results
//     if (cleanPattern.isEmpty) return const <Map<String, String>>[];

//     // Malformed edge bracket usage: has '[' but no matching ']'
//     if (cleanPattern.contains('[') && !cleanPattern.contains(']')) {
//       return const <Map<String, String>>[];
//     }

//     // Split by arrows while preserving direction metadata, but ignore arrows inside []
//     final parts = <String>[];
//     final directions = <bool>[]; // true = forward (->), false = backward (<-)

//     int i = 0;
//     int bracketDepth = 0; // depth in square brackets
//     int lastSplit = 0;
//     while (i < cleanPattern.length) {
//       final ch = cleanPattern[i];
//       if (ch == '[') {
//         bracketDepth++;
//         i++;
//         continue;
//       }
//       if (ch == ']') {
//         bracketDepth = bracketDepth > 0 ? bracketDepth - 1 : -1;
//         if (bracketDepth < 0) {
//           // Unbalanced bracket -> malformed
//           return const <Map<String, String>>[];
//         }
//         i++;
//         continue;
//       }
//       if (bracketDepth == 0) {
//         // forward ->
//         if (ch == '-' && i + 1 < cleanPattern.length && cleanPattern[i + 1] == '>') {
//           parts.add(cleanPattern.substring(lastSplit, i));
//           directions.add(true);
//           i += 2;
//           lastSplit = i;
//           continue;
//         }
//         // backward <-
//         if (ch == '<' && i + 1 < cleanPattern.length && cleanPattern[i + 1] == '-') {
//           parts.add(cleanPattern.substring(lastSplit, i));
//           directions.add(false);
//           i += 2;
//           lastSplit = i;
//           continue;
//         }
//       }
//       i++;
//     }
//     // final segment
//     parts.add(cleanPattern.substring(lastSplit));

//     if (parts.isEmpty) return const <Map<String, String>>[];

//     // Helper to extract alias name from a part
//     String aliasOf(String part) {
//       if (part.startsWith('[')) {
//         // Part starts with edge info like "[:EDGE]-varname"
//         final afterEdge = part.substring(part.indexOf('-') + 1);
//         return afterEdge.split(RegExp(r'[-\[:]')).first.trim();
//       } else {
//         // Normal case: "varname" or "varname:Type" or "varname-[:EDGE]"
//         return part.split(RegExp(r'[-\[:]')).first.trim();
//       }
//     }

//     // Seed rows
//     List<Map<String, String>> currentRows = <Map<String, String>>[];
//     final firstAlias = aliasOf(parts.first);
//     if (firstAlias.isEmpty) {
//       return const <Map<String, String>>[];
//     }
//     if (startId != null) {
//       currentRows = <Map<String, String>>[
//         {firstAlias: startId},
//       ];
//     } else {
//       // Parse optional type and label filter in first segment
//       String descriptor = firstAlias; // e.g., user:User{label~Mark}
//       String? nodeType;
//       String? labelOp; // '=' or '~'
//       String? labelVal;

//       // If alias actually contains :Type and/or {label...} they would have been included in the part
//       // Recompute using the full first part instead of just alias
//       descriptor = parts.first.split(RegExp(r'[-\[]')).first.trim();
//       String head = descriptor;
//       final braceStart = descriptor.indexOf('{');
//       if (braceStart != -1) {
//         if (!descriptor.endsWith('}')) {
//           // malformed label filter
//           return const <Map<String, String>>[];
//         }
//         head = descriptor.substring(0, braceStart).trim();
//         final inside = descriptor
//             .substring(braceStart + 1, descriptor.length - 1)
//             .trim();
//         final m = RegExp(r'^label\s*([=~])\s*(.+)$').firstMatch(inside);
//         if (m != null) {
//           labelOp = m.group(1);
//           labelVal = m.group(2);
//           if (labelVal == null || labelVal.trim().isEmpty) {
//             return const <Map<String, String>>[];
//           }
//         } else if (inside.isNotEmpty) {
//           return const <Map<String, String>>[];
//         }
//       }
//       if (head.contains(':')) {
//         final typeParts = head.split(':');
//         nodeType = typeParts.length > 1 ? typeParts[1].trim() : null;
//       }


//       // Seed by scanning nodes matching type/label
//       for (final node in graph.nodesById.values) {
//         if (nodeType != null && node.type != nodeType) continue;
//         if (labelOp != null && labelVal != null) {
//           if (labelOp == '=') {
//             if (node.label != labelVal) continue;
//           } else if (labelOp == '~') {
//             final hay = node.label.toLowerCase();
//             final needle = labelVal.toLowerCase();
//             if (!hay.contains(needle)) continue;
//           }
//         }
//         currentRows.add({firstAlias: node.id});
//       }
//     }

//     // Traverse over each hop, expanding rows
//     for (var i = 0; i < parts.length - 1; i++) {
//       final part = parts[i];
//       final aliasHere = aliasOf(part);
//       final nextAlias = aliasOf(parts[i + 1]);

//       // For backward patterns, edge info is in the next part
//       final isForward = directions[i];
//       final edgePart = isForward ? part : parts[i + 1];
//       final edgeType = _edgeTypeFrom(edgePart);
//       if (edgeType == null) {
//         // No edge specified; cannot advance
//         return const <Map<String, String>>[];
//       }
//       final edgeTypeTrimmed = edgeType.trim();
//       if (edgeTypeTrimmed.isEmpty) return const <Map<String, String>>[];

//       final nextRows = <Map<String, String>>[];
//       final seen = <String>{}; // dedupe identical rows

//       for (final row in currentRows) {
//         final srcId = row[aliasHere];
//         if (srcId == null) continue;
//         final neighbors = isForward
//             ? graph.outNeighbors(srcId, edgeTypeTrimmed)
//             : graph.inNeighbors(srcId, edgeTypeTrimmed);
//         for (final nb in neighbors) {
//           final newRow = Map<String, String>.from(row);
//           newRow[nextAlias] = nb;
//           // Row signature for dedupe: stable by sorting keys
//           final keys = newRow.keys.toList()..sort();
//           final sig = keys.map((k) => '$k=${newRow[k]}').join('|');
//           if (seen.add(sig)) {
//             nextRows.add(newRow);
//           }
//         }
//       }

//       currentRows = nextRows;
//       if (currentRows.isEmpty) break; // no more matches possible
//     }

//     return currentRows;
//   }

//   /// Execute multiple patterns and concatenate row results (deduplicated).
//   List<Map<String, String>> matchRowsMany(
//     List<String> patterns, {
//     String? startId,
//   }) {
//     final out = <Map<String, String>>[];
//     final seen = <String>{};
//     for (final p in patterns) {
//       final rows = matchRows(p, startId: startId);
//       for (final r in rows) {
//         final keys = r.keys.toList()..sort();
//         final sig = keys.map((k) => '$k=${r[k]}').join('|');
//         if (seen.add(sig)) out.add(r);
//       }
//     }
//     return out;
//   }

//   /// Executes a pattern and returns complete path information including edges.
//   ///
//   /// Similar to [matchRows] but returns [PathMatch] objects that include both
//   /// the node mappings and the ordered edges in each path, providing complete
//   /// path information like Neo4j.
//   ///
//   /// Each [PathMatch] contains:
//   /// - `nodes`: Map of variable names to node IDs (same as matchRows)
//   /// - `edges`: Ordered list of [PathEdge] objects showing connections
//   ///
//   /// Example:
//   /// ```dart
//   /// final paths = query.matchPaths('person-[:WORKS_FOR]->team-[:ASSIGNED_TO]->project');
//   /// for (final path in paths) {
//   ///   print('Nodes: ${path.nodes}'); // {person: alice, team: engineering, project: web_app}
//   ///   for (final edge in path.edges) {
//   ///     print(edge); // person(alice) -[:WORKS_FOR]-> team(engineering)
//   ///   }
//   /// }
//   /// ```
//   ///
//   /// Returns a list of [PathMatch] objects, where each represents one complete
//   /// path through the graph with both node and edge information.
//   List<PathMatch> matchPaths(String pattern, {String? startId}) {
//     // First get the regular row results
//     final rows = matchRows(pattern, startId: startId);

//     // Convert each row to a PathMatch with edge information
//     final pathMatches = <PathMatch>[];

//     for (final row in rows) {
//       final edges = _buildEdgesForRow(pattern, row);
//       pathMatches.add(PathMatch(nodes: row, edges: edges));
//     }

//     return pathMatches;
//   }

//   /// Execute multiple patterns and return path matches with edge information.
//   ///
//   /// Similar to [matchRowsMany] but returns [PathMatch] objects with complete
//   /// path information including edges.
//   List<PathMatch> matchPathsMany(List<String> patterns, {String? startId}) {
//     final out = <PathMatch>[];
//     final seen = <String>{};

//     for (final pattern in patterns) {
//       final paths = matchPaths(pattern, startId: startId);
//       for (final path in paths) {
//         final keys = path.nodes.keys.toList()..sort();
//         final sig = keys.map((k) => '$k=${path.nodes[k]}').join('|');
//         if (seen.add(sig)) out.add(path);
//       }
//     }

//     return out;
//   }

//   /// Build PathEdge objects for a given row result by parsing the pattern.
//   List<PathEdge> _buildEdgesForRow(String pattern, Map<String, String> row) {
//     final edges = <PathEdge>[];

//     // Strip optional MATCH keyword
//     var cleanPattern = pattern.trim();
//     if (cleanPattern.toUpperCase().startsWith('MATCH ')) {
//       cleanPattern = cleanPattern.substring(6).trim();
//     }

//     // Parse the pattern to extract edge information with bracket-aware splitting
//     final parts = <String>[];
//     final directions = <bool>[]; // true = forward (->), false = backward (<-)

//     int i = 0;
//     int bracketDepth = 0;
//     int lastSplit = 0;
//     while (i < cleanPattern.length) {
//       final ch = cleanPattern[i];
//       if (ch == '[') {
//         bracketDepth++;
//         i++;
//         continue;
//       }
//       if (ch == ']') {
//         bracketDepth = bracketDepth > 0 ? bracketDepth - 1 : -1;
//         if (bracketDepth < 0) {
//           // malformed
//           break;
//         }
//         i++;
//         continue;
//       }
//       if (bracketDepth == 0) {
//         if (ch == '-' && i + 1 < cleanPattern.length && cleanPattern[i + 1] == '>') {
//           parts.add(cleanPattern.substring(lastSplit, i).trim());
//           directions.add(true);
//           i += 2;
//           lastSplit = i;
//           continue;
//         }
//         if (ch == '<' && i + 1 < cleanPattern.length && cleanPattern[i + 1] == '-') {
//           parts.add(cleanPattern.substring(lastSplit, i).trim());
//           directions.add(false);
//           i += 2;
//           lastSplit = i;
//           continue;
//         }
//       }
//       i++;
//     }
//     if (lastSplit <= cleanPattern.length) {
//       final tail = cleanPattern.substring(lastSplit).trim();
//       if (tail.isNotEmpty) parts.add(tail);
//     }

//     // Build edges from the parsed parts
//     for (int i = 0; i < directions.length; i++) {
//       final fromPart = parts[i];
//       final toPart = parts[i + 1];
//       final isForward = directions[i];

//       // Extract variable names
//       final fromVar = _extractVariableName(fromPart);
//       final toVar = _extractVariableName(toPart);

//       if (fromVar == null || toVar == null) continue;
//       if (!row.containsKey(fromVar) || !row.containsKey(toVar)) continue;

//       // Extract edge type from the appropriate part (backward uses toPart)
//       final edgePart = isForward ? fromPart : toPart;
//       final edgeType = _edgeTypeFrom(edgePart)?.trim();
//       if (edgeType == null || edgeType.isEmpty) continue;

//       // Create the edge based on direction
//       if (isForward) {
//         edges.add(
//           PathEdge(
//             from: row[fromVar]!,
//             to: row[toVar]!,
//             type: edgeType,
//             fromVariable: fromVar,
//             toVariable: toVar,
//           ),
//         );
//       } else {
//         edges.add(
//           PathEdge(
//             from: row[toVar]!,
//             to: row[fromVar]!,
//             type: edgeType,
//             fromVariable: toVar,
//             toVariable: fromVar,
//           ),
//         );
//       }
//     }

//     return edges;
//   }

//   /// Extract variable name from a pattern part (e.g., "user:User{label=Alice}" -> "user")
//   String? _extractVariableName(String part) {
//     if (part.isEmpty) return null;

//     // Handle parts that start with edge syntax like "[:LEADS]-person"
//     if (part.startsWith('[')) {
//       // Find the end of the edge syntax and look for variable after dash
//       final edgeEnd = part.indexOf(']');
//       if (edgeEnd != -1) {
//         final afterEdge = part.substring(edgeEnd + 1).trim();
//         if (afterEdge.startsWith('-')) {
//           final varPart = afterEdge.substring(1).trim();
//           if (varPart.isNotEmpty) {
//             part = varPart;
//           }
//         }
//       }
//     } else {
//       // Remove edge syntax if present in the middle or end
//       part = part.replaceAll(RegExp(r'\[\s*:\s*\w+\s*\]'), '').trim();
//       // Remove trailing dash that might be left after edge removal
//       part = part.replaceAll(RegExp(r'-+$'), '').trim();
//     }

//     // Variable name is before any : or { characters
//     final colonIdx = part.indexOf(':');
//     final braceIdx = part.indexOf('{');

//     int endIdx = part.length;
//     if (colonIdx != -1 && braceIdx != -1) {
//       endIdx = colonIdx < braceIdx ? colonIdx : braceIdx;
//     } else if (colonIdx != -1) {
//       endIdx = colonIdx;
//     } else if (braceIdx != -1) {
//       endIdx = braceIdx;
//     }

//     final varName = part.substring(0, endIdx).trim();
//     return varName.isEmpty ? null : varName;
//   }

//   /// Parse edge type from a segment containing an edge block like "[ : TYPE ]".
//   /// Supports nested square brackets inside TYPE and arbitrary characters.
//   String? _edgeTypeFrom(String segment) {
//     // Find '[' that begins an edge block
//     for (int i = 0; i < segment.length; i++) {
//       if (segment[i] == '[') {
//         // Scan to ':' before the matching ']' (allow whitespace)
//         int j = i + 1;
//         while (j < segment.length && segment[j].trim().isEmpty) {
//           j++;
//         }
//         bool foundColon = false;
//         while (j < segment.length) {
//           final c = segment[j];
//           if (c == ':') {
//             foundColon = true;
//             j++;
//             break;
//           }
//           if (c == ']') break;
//           j++;
//         }
//         if (!foundColon) continue; // not an edge block

//         // Now scan to matching closing bracket with nesting
//         int depth = 1;
//         final contentStart = j;
//         int k = j;
//         while (k < segment.length) {
//           final c = segment[k];
//           if (c == '[') {
//             depth++;
//           } else if (c == ']') {
//             depth--;
//             if (depth == 0) {
//               return segment.substring(contentStart, k);
//             }
//           }
//           k++;
//         }
//         return null; // unbalanced
//       }
//     }
//     return null;
//   }

//   // --- Utility finder methods ---

//   /// Finds all node IDs with the given [type].
//   ///
//   /// Example:
//   /// ```dart
//   /// final userIds = query.findByType('User');
//   /// print(userIds); // {'u1', 'u2', 'u3'}
//   /// ```
//   Set<String> findByType(String type) {
//     return graph.nodesById.values
//         .where((n) => n.type == type)
//         .map((n) => n.id)
//         .toSet();
//   }

//   /// Finds node IDs whose label exactly matches [label].
//   ///
//   /// Parameters:
//   /// - [label]: The exact label to match
//   /// - [caseInsensitive]: Whether to ignore case (default: false)
//   ///
//   /// Example:
//   /// ```dart
//   /// final aliceIds = query.findByLabelEquals('Alice');
//   /// final anyAlice = query.findByLabelEquals('alice', caseInsensitive: true);
//   /// ```
//   Set<String> findByLabelEquals(String label, {bool caseInsensitive = false}) {
//     if (!caseInsensitive) {
//       return graph.nodesById.values
//           .where((n) => n.label == label)
//           .map((n) => n.id)
//           .toSet();
//     }
//     final needle = label.toLowerCase();
//     return graph.nodesById.values
//         .where((n) => n.label.toLowerCase() == needle)
//         .map((n) => n.id)
//         .toSet();
//   }

//   /// Finds node IDs whose label contains the substring [contains].
//   ///
//   /// Parameters:
//   /// - [contains]: The substring to search for
//   /// - [caseInsensitive]: Whether to ignore case (default: true)
//   ///
//   /// Example:
//   /// ```dart
//   /// final matchingIds = query.findByLabelContains('admin');
//   /// // Finds 'Administrator', 'admin', 'Admins', etc.
//   /// ```
//   Set<String> findByLabelContains(
//     String contains, {
//     bool caseInsensitive = true,
//   }) {
//     final needle = caseInsensitive ? contains.toLowerCase() : contains;
//     return graph.nodesById.values
//         .where(
//           (n) => (caseInsensitive ? n.label.toLowerCase() : n.label).contains(
//             needle,
//           ),
//         )
//         .map((n) => n.id)
//         .toSet();
//   }

//   /// Returns outbound neighbors from [srcId] via [edgeType].
//   ///
//   /// This is a convenience wrapper around `graph.outNeighbors()`.
//   Set<String> outFrom(String srcId, String edgeType) =>
//       graph.outNeighbors(srcId, edgeType);

//   /// Returns inbound neighbors to [dstId] via [edgeType].
//   ///
//   /// This is a convenience wrapper around `graph.inNeighbors()`.
//   Set<String> inTo(String dstId, String edgeType) =>
//       graph.inNeighbors(dstId, edgeType);

//   /// Finds all destinations reachable via [edgeType] from any source in [srcIds].
//   ///
//   /// Useful for expanding from multiple starting points in one operation.
//   ///
//   /// Example:
//   /// ```dart
//   /// final groupIds = {'g1', 'g2', 'g3'};
//   /// final allPolicies = query.findByEdgeFrom(groupIds, 'SOURCE');
//   /// print(allPolicies); // All policies from any of these groups
//   /// ```
//   Set<String> findByEdgeFrom(Iterable<String> srcIds, String edgeType) {
//     final out = <String>{};
//     for (final id in srcIds) {
//       out.addAll(graph.outNeighbors(id, edgeType));
//     }
//     return out;
//   }

//   /// Finds all sources that can reach any destination in [dstIds] via [edgeType].
//   ///
//   /// Useful for backward expansion from multiple destination points.
//   ///
//   /// Example:
//   /// ```dart
//   /// final assetIds = {'a1', 'a2', 'a3'};
//   /// final allGroups = query.findByEdgeTo(assetIds, 'DESTINATION');
//   /// print(allGroups); // All groups that have access to any of these assets
//   /// ```
//   Set<String> findByEdgeTo(Iterable<String> dstIds, String edgeType) {
//     final ins = <String>{};
//     for (final id in dstIds) {
//       ins.addAll(graph.inNeighbors(id, edgeType));
//     }
//     return ins;
//   }
// }
