// pattern_query.dart
import 'graph.dart';
import 'node.dart';

/// A powerful pattern-based query engine for graph traversal, inspired by Cypher.
///
/// This class provides methods to execute graph queries using a mini-language
/// that supports directional edges, type filtering, and label matching.
///
/// ## Pattern Syntax
/// - **Node aliases**: `user`, `group`, `policy` (variable names for results)
/// - **Node types**: `user:User` (filter by node type)
/// - **Label filters**: `user{label=Alice}` (exact) or `user{label~ice}` (contains)
/// - **Directional edges**: `-[:MEMBER_OF]->` (outgoing) or `<-[:MEMBER_OF]-` (incoming)
///
/// ## Example Patterns
/// ```dart
/// // All users and their groups
/// 'user:User-[:MEMBER_OF]->group'
/// 
/// // Policies from a specific user
/// 'user-[:MEMBER_OF]->group-[:SOURCE]->policy'
/// 
/// // Users who can reach a specific destination (backward traversal)
/// 'destination<-[:DESTINATION]-group<-[:MEMBER_OF]-user'
/// ```
///
/// ## Usage
/// ```dart
/// final graph = Graph<Node>();
/// // ... add nodes and edges ...
/// 
/// final query = PatternQuery(graph);
/// final results = query.match('user:User-[:MEMBER_OF]->group');
/// print(results['user']);  // Set of user IDs
/// print(results['group']); // Set of group IDs
/// ```
class PatternQuery<N extends Node> {
  /// The graph to execute queries against.
  final Graph<N> graph;
  
  /// Creates a new pattern query engine for the given [graph].
  PatternQuery(this.graph);
  
  /// Executes a single pattern query and returns grouped results.
  ///
  /// Takes a pattern string and returns a map where keys are variable names
  /// from the pattern and values are sets of matching node IDs.
  ///
  /// Parameters:
  /// - [pattern]: The pattern string to execute (e.g., "user-[:MEMBER_OF]->group")
  /// - [startId]: Optional starting node ID. If provided, the query begins from
  ///   this specific node. If null, the first segment must include type/label
  ///   filters to seed the query.
  ///
  /// Returns a map from variable names to sets of node IDs.
  ///
  /// Example:
  /// ```dart
  /// // Starting from a specific user
  /// final results = query.match('user-[:MEMBER_OF]->group', startId: 'u1');
  /// print(results['user']);  // {'u1'}
  /// print(results['group']); // {'g1', 'g2'}
  ///
  /// // Using type filtering to seed
  /// final results = query.match('user:User-[:MEMBER_OF]->group');
  /// print(results['user']);  // {'u1', 'u2', 'u3'}
  /// print(results['group']); // {'g1', 'g2', 'g3'}
  /// ```
  Map<String, Set<String>> match(String pattern, {String? startId}) {
    final results = <String, Set<String>>{};

    // Strip optional MATCH keyword (Cypher compatibility)
    var cleanPattern = pattern.trim();
    if (cleanPattern.toUpperCase().startsWith('MATCH ')) {
      cleanPattern = cleanPattern.substring(6).trim();
    }

    // Split by arrows but keep direction
    final parts = <String>[];
    final directions = <bool>[]; // true = forward (->), false = backward (<-)

    var remaining = cleanPattern;
    while (remaining.contains('->') || remaining.contains('<-')) {
      final forwardIdx = remaining.indexOf('->');
      final backwardIdx = remaining.indexOf('<-');
      
      if (forwardIdx != -1 && (backwardIdx == -1 || forwardIdx < backwardIdx)) {
        parts.add(remaining.substring(0, forwardIdx));
        directions.add(true);
        remaining = remaining.substring(forwardIdx + 2);
      } else if (backwardIdx != -1) {
        parts.add(remaining.substring(0, backwardIdx));
        directions.add(false);
        remaining = remaining.substring(backwardIdx + 2);
      }
    }
    parts.add(remaining);
    
    // Process the pattern
    Set<String> currentNodes = startId != null ? {startId} : {};
    
    for (var i = 0; i < parts.length; i++) {
      final part = parts[i];
      
      // Extract variable name (handle parts that start with edge info)
      String varName;
      if (part.startsWith('[')) {
        // Part starts with edge info like "[:EDGE]-varname"
        final afterEdge = part.substring(part.indexOf('-') + 1);
        varName = afterEdge.split(RegExp(r'[-\[:]')).first.trim();
      } else {
        // Normal case: "varname" or "varname:Type" or "varname-[:EDGE]"
        varName = part.split(RegExp(r'[-\[:]')).first.trim();
      }
      
      // If first part and no startId, find matching nodes
      if (i == 0 && startId == null) {
        // Support syntax: name[:Type]{label=Exact} or {label~Substr}
        // Examples:
        //  - user:User                => all nodes of type User
        //  - user:User{label=Mark}    => type User AND label exactly 'Mark'
        //  - user{label~ark}          => any type, label contains 'ark' (case-insensitive)
        // IMPORTANT: When the first segment also contains an edge specifier
        // (e.g. "user:User-[:EDGE]"), we must strip everything after the
        // alias/type before extracting the filters. Mirror matchRows() logic.
        String descriptor = parts.first.split(RegExp(r'[-\[]')).first.trim();
        String? nodeType;
        String? labelOp; // '=' or '~'
        String? labelVal;

        // Extract optional {label...}
        String head = descriptor;
        final braceStart = descriptor.indexOf('{');
        if (braceStart != -1 && descriptor.endsWith('}')) {
          head = descriptor.substring(0, braceStart).trim();
          final inside = descriptor.substring(braceStart + 1, descriptor.length - 1).trim();
          final m = RegExp(r'^label\s*([=~])\s*(.+)$').firstMatch(inside);
          if (m != null) {
            labelOp = m.group(1);
            labelVal = m.group(2);
          } else if (inside.isNotEmpty) {
            // Malformed label filter - return empty results
            return <String, Set<String>>{};
          }
        }

        // Extract optional :Type from head
        if (head.contains(':')) {
          final typeParts = head.split(':');
          nodeType = typeParts.length > 1 ? typeParts[1].trim() : null;
        }

        // Find initial seed nodes by type and/or label filter
        if (nodeType != null || labelOp != null) {
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
            currentNodes.add(node.id);
          }
        }
      }
      
      // Store current nodes
      if (currentNodes.isNotEmpty) {
        results[varName] = currentNodes;
      }
      
      // Traverse edge if not last part
      if (i < parts.length - 1) {
        // For backward patterns, edge info is in the next part
        final isForward = directions[i];
        final edgePart = isForward ? part : parts[i + 1];
        final edgeMatch = RegExp(r'\[\s*:\s*(\w+)\s*\]').firstMatch(edgePart);
        if (edgeMatch == null) continue;

        final edgeType = edgeMatch.group(1)!;
        
        final nextNodes = <String>{};
        for (final nodeId in currentNodes) {
          if (isForward) {
            nextNodes.addAll(graph.outNeighbors(nodeId, edgeType));
          } else {
            nextNodes.addAll(graph.inNeighbors(nodeId, edgeType));
          }
        }
        
        currentNodes = nextNodes;
      }
    }
    
    return results;
  }
  
  /// Executes multiple patterns and unions the results by variable name.
  ///
  /// This method is equivalent to running multiple independent queries and
  /// combining their results, similar to multiple MATCH clauses in Cypher.
  /// Results are unioned - if the same node ID appears in multiple patterns
  /// for the same variable, it appears only once in the final result.
  ///
  /// Parameters:
  /// - [patterns]: List of pattern strings to execute
  /// - [startId]: Optional starting node ID applied to all patterns
  ///
  /// Returns a map where each key is a variable name and each value is the
  /// union of all node IDs matching that variable across all patterns.
  ///
  /// Example:
  /// ```dart
  /// final results = query.matchMany([
  ///   'user-[:HAS_CLIENT]->client',
  ///   'user-[:MEMBER_OF]->group-[:SOURCE]->policy',
  ///   'user-[:MEMBER_OF]->group-[:DESTINATION]->asset',
  /// ], startId: 'u1');
  /// 
  /// // Results contain all related entities from the user
  /// print(results['client']); // All clients
  /// print(results['group']);  // All groups  
  /// print(results['policy']); // All policies
  /// print(results['asset']);  // All assets
  /// ```
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

  /// Executes a pattern and returns row-wise bindings, similar to Cypher MATCH results.
  ///
  /// Unlike [match] which groups results by variable name, this method returns
  /// each complete path as a separate row, preserving the relationships between
  /// variables. This is useful when you need to know which specific combinations
  /// of nodes are connected.
  ///
  /// Each row is a map from variable name to the specific node ID matched in
  /// that path traversal.
  ///
  /// Parameters:
  /// - [pattern]: The pattern string to execute
  /// - [startId]: Optional starting node ID
  ///
  /// Returns a list of maps, where each map represents one complete path match.
  ///
  /// Example:
  /// ```dart
  /// final rows = query.matchRows(
  ///   'user-[:MEMBER_OF]->group-[:SOURCE]->policy-[:DESTINATION]->asset',
  ///   startId: 'u1'
  /// );
  /// 
  /// // Each row shows a complete path:
  /// // [{user: u1, group: g1, policy: p1, asset: a1},
  /// //  {user: u1, group: g1, policy: p2, asset: a2},
  /// //  {user: u1, group: g2, policy: p3, asset: a3}]
  /// 
  /// // Build asset -> policies mapping from rows
  /// final assetToPolicies = <String, Set<String>>{};
  /// for (final row in rows) {
  ///   final asset = row['asset']!;
  ///   final policy = row['policy']!;
  ///   assetToPolicies.putIfAbsent(asset, () => {}).add(policy);
  /// }
  /// ```
  List<Map<String, String>> matchRows(String pattern, {String? startId}) {
    // Split by arrows while preserving direction metadata
    final parts = <String>[];
    final directions = <bool>[]; // true = forward (->), false = backward (<-)

    var remaining = pattern;
    while (remaining.contains('->') || remaining.contains('<-')) {
      final forwardIdx = remaining.indexOf('->');
      final backwardIdx = remaining.indexOf('<-');

      if (forwardIdx != -1 && (backwardIdx == -1 || forwardIdx < backwardIdx)) {
        parts.add(remaining.substring(0, forwardIdx));
        directions.add(true);
        remaining = remaining.substring(forwardIdx + 2);
      } else if (backwardIdx != -1) {
        parts.add(remaining.substring(0, backwardIdx));
        directions.add(false);
        remaining = remaining.substring(backwardIdx + 2);
      }
    }
    parts.add(remaining);

    if (parts.isEmpty) return const <Map<String, String>>[];

    // Helper to extract alias name from a part
    String aliasOf(String part) {
      if (part.startsWith('[')) {
        // Part starts with edge info like "[:EDGE]-varname"
        final afterEdge = part.substring(part.indexOf('-') + 1);
        return afterEdge.split(RegExp(r'[-\[:]')).first.trim();
      } else {
        // Normal case: "varname" or "varname:Type" or "varname-[:EDGE]"
        return part.split(RegExp(r'[-\[:]')).first.trim();
      }
    }

    // Seed rows
    List<Map<String, String>> currentRows = <Map<String, String>>[];
    final firstAlias = aliasOf(parts.first);
    if (startId != null) {
      currentRows = <Map<String, String>>[{firstAlias: startId}];
    } else {
      // Parse optional type and label filter in first segment
      String descriptor = firstAlias; // e.g., user:User{label~Mark}
      String? nodeType;
      String? labelOp; // '=' or '~'
      String? labelVal;

      // If alias actually contains :Type and/or {label...} they would have been included in the part
      // Recompute using the full first part instead of just alias
      descriptor = parts.first.split(RegExp(r'[-\[]')).first.trim();
      String head = descriptor;
      final braceStart = descriptor.indexOf('{');
      if (braceStart != -1 && descriptor.endsWith('}')) {
        head = descriptor.substring(0, braceStart).trim();
        final inside = descriptor.substring(braceStart + 1, descriptor.length - 1).trim();
        final m = RegExp(r'^label\s*([=~])\s*(.+)$').firstMatch(inside);
        if (m != null) {
          labelOp = m.group(1);
          labelVal = m.group(2);
        }
      }
      if (head.contains(':')) {
        final typeParts = head.split(':');
        nodeType = typeParts.length > 1 ? typeParts[1].trim() : null;
      }

      // Seed by scanning nodes matching type/label
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

    // Traverse over each hop, expanding rows
    for (var i = 0; i < parts.length - 1; i++) {
      final part = parts[i];
      final aliasHere = aliasOf(part);
      final nextAlias = aliasOf(parts[i + 1]);

      final edgeMatch = RegExp(r'\[\s*:\s*(\w+)\s*\]').firstMatch(part);
      if (edgeMatch == null) {
        // No edge specified; cannot advance
        return const <Map<String, String>>[];
      }
      final edgeType = edgeMatch.group(1)!;
      final isForward = directions[i];

      final nextRows = <Map<String, String>>[];
      final seen = <String>{}; // dedupe identical rows

      for (final row in currentRows) {
        final srcId = row[aliasHere];
        if (srcId == null) continue;
        final neighbors = isForward
            ? graph.outNeighbors(srcId, edgeType)
            : graph.inNeighbors(srcId, edgeType);
        for (final nb in neighbors) {
          final newRow = Map<String, String>.from(row);
          newRow[nextAlias] = nb;
          // Row signature for dedupe: stable by sorting keys
          final keys = newRow.keys.toList()..sort();
          final sig = keys.map((k) => '$k=${newRow[k]}').join('|');
          if (seen.add(sig)) {
            nextRows.add(newRow);
          }
        }
      }

      currentRows = nextRows;
      if (currentRows.isEmpty) break; // no more matches possible
    }

    return currentRows;
  }
  
  /// Execute multiple patterns and concatenate row results (deduplicated).
  List<Map<String, String>> matchRowsMany(List<String> patterns, {String? startId}) {
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

  // --- Utility finder methods ---

  /// Finds all node IDs with the given [type].
  ///
  /// Example:
  /// ```dart
  /// final userIds = query.findByType('User');
  /// print(userIds); // {'u1', 'u2', 'u3'}
  /// ```
  Set<String> findByType(String type) {
    return graph.nodesById.values
        .where((n) => n.type == type)
        .map((n) => n.id)
        .toSet();
  }

  /// Finds node IDs whose label exactly matches [label].
  ///
  /// Parameters:
  /// - [label]: The exact label to match
  /// - [caseInsensitive]: Whether to ignore case (default: false)
  ///
  /// Example:
  /// ```dart
  /// final aliceIds = query.findByLabelEquals('Alice');
  /// final anyAlice = query.findByLabelEquals('alice', caseInsensitive: true);
  /// ```
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
  ///
  /// Parameters:
  /// - [contains]: The substring to search for
  /// - [caseInsensitive]: Whether to ignore case (default: true)
  ///
  /// Example:
  /// ```dart
  /// final matchingIds = query.findByLabelContains('admin');
  /// // Finds 'Administrator', 'admin', 'Admins', etc.
  /// ```
  Set<String> findByLabelContains(String contains, {bool caseInsensitive = true}) {
    final needle = caseInsensitive ? contains.toLowerCase() : contains;
    return graph.nodesById.values
        .where((n) => (caseInsensitive ? n.label.toLowerCase() : n.label).contains(needle))
        .map((n) => n.id)
        .toSet();
  }

  /// Returns outbound neighbors from [srcId] via [edgeType].
  ///
  /// This is a convenience wrapper around `graph.outNeighbors()`.
  Set<String> outFrom(String srcId, String edgeType) => graph.outNeighbors(srcId, edgeType);

  /// Returns inbound neighbors to [dstId] via [edgeType].
  ///
  /// This is a convenience wrapper around `graph.inNeighbors()`.
  Set<String> inTo(String dstId, String edgeType) => graph.inNeighbors(dstId, edgeType);

  /// Finds all destinations reachable via [edgeType] from any source in [srcIds].
  ///
  /// Useful for expanding from multiple starting points in one operation.
  ///
  /// Example:
  /// ```dart
  /// final groupIds = {'g1', 'g2', 'g3'};
  /// final allPolicies = query.findByEdgeFrom(groupIds, 'SOURCE');
  /// print(allPolicies); // All policies from any of these groups
  /// ```
  Set<String> findByEdgeFrom(Iterable<String> srcIds, String edgeType) {
    final out = <String>{};
    for (final id in srcIds) {
      out.addAll(graph.outNeighbors(id, edgeType));
    }
    return out;
  }

  /// Finds all sources that can reach any destination in [dstIds] via [edgeType].
  ///
  /// Useful for backward expansion from multiple destination points.
  ///
  /// Example:
  /// ```dart
  /// final assetIds = {'a1', 'a2', 'a3'};
  /// final allGroups = query.findByEdgeTo(assetIds, 'DESTINATION');
  /// print(allGroups); // All groups that have access to any of these assets
  /// ```
  Set<String> findByEdgeTo(Iterable<String> dstIds, String edgeType) {
    final ins = <String>{};
    for (final id in dstIds) {
      ins.addAll(graph.inNeighbors(id, edgeType));
    }
    return ins;
  }
}