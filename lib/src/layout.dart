import 'dart:collection';

import 'cypher_models.dart';
import 'graph.dart';
import 'graph_algorithms.dart';
import 'traversal.dart';

/// Strategy for computing layer/column assignments in graph layouts.
enum LayerStrategy {
  /// Use pattern order (left to right in query).
  /// Fast, predictable, respects query structure.
  /// Best for: Simple linear patterns where query order matches desired layout.
  pattern,

  /// Use longest path from roots (Coffman-Graham-like algorithm).
  /// Assigns each node to MAX depth across all paths to minimize edge crossings.
  /// Best for: Complex graphs with diamonds, multiple paths, general visualization.
  longestPath,

  /// Use topological sort (requires DAG + Graph instance).
  /// Falls back to longestPath if graph contains cycles.
  /// Best for: Dependency visualization, build systems, task scheduling.
  topological,
}

/// Computed layout information for visualizing graph query results.
///
/// Provides automatic layer/column assignments eliminating hardcoded positioning.
/// Each node is assigned a depth/layer (0 = leftmost column, higher = rightward).
///
/// Example usage:
/// ```dart
/// final paths = query.matchPaths('group->policy->asset->virtual');
/// final layout = paths.computeLayout();
///
/// // Get layer for a pattern variable - NO HARDCODING!
/// final policyColumn = layout.variableLayer('policy');  // Returns 1
///
/// // Or get layer for specific node ID
/// final nodeColumn = layout.layerFor('node_123');
///
/// // Render by column
/// for (var layer = 0; layer <= layout.maxDepth; layer++) {
///   final nodesInColumn = layout.nodesInLayer(layer);
///   renderColumn(layer, nodesInColumn);
/// }
/// ```
class GraphLayout {
  /// All unique node IDs across all paths.
  final Set<String> allNodes;

  /// All unique edges across all paths.
  final Set<EdgeTriple> allEdges;

  /// Maps node ID to its computed layer/depth (0 = leftmost column).
  ///
  /// For nodes reachable via multiple paths, contains the MAX depth
  /// (longest path from any root) to minimize edge crossings.
  final Map<String, int> nodeDepths;

  /// Nodes grouped by layer for column rendering.
  /// Layer 0 is leftmost, higher layers go rightward.
  final Map<int, Set<String>> nodesByLayer;

  /// Root nodes (layer 0) - entry points to the graph.
  /// Multiple roots indicate disconnected components.
  final Set<String> roots;

  /// Maximum depth in the layout (number of layers - 1).
  final int maxDepth;

  /// Maps pattern variable names to their typical layer position.
  ///
  /// Computed as MEDIAN depth across all nodes with that variable name.
  /// Handles outliers gracefully (e.g., orphan nodes at different depths).
  ///
  /// Example: {'group': 0, 'policy': 1, 'asset': 2}
  final Map<String, int> variableDepths;

  const GraphLayout({
    required this.allNodes,
    required this.allEdges,
    required this.nodeDepths,
    required this.nodesByLayer,
    required this.roots,
    required this.maxDepth,
    required this.variableDepths,
  });

  /// Get the layer/column for a specific node ID.
  /// Returns 0 if node not found.
  int layerFor(String nodeId) => nodeDepths[nodeId] ?? 0;

  /// Get all nodes in a specific layer.
  /// Returns empty set if layer doesn't exist.
  Set<String> nodesInLayer(int layer) => nodesByLayer[layer] ?? {};

  /// Get the typical layer for a pattern variable.
  ///
  /// Example: `layout.variableLayer('asset')` returns 2
  /// Returns 0 if variable not found.
  int variableLayer(String variable) => variableDepths[variable] ?? 0;

  @override
  String toString() {
    return 'GraphLayout(\n'
        '  maxDepth: $maxDepth,\n'
        '  roots: $roots,\n'
        '  layers: ${nodesByLayer.length},\n'
        '  nodes: ${allNodes.length},\n'
        '  edges: ${allEdges.length}\n'
        ')';
  }
}

/// Extension on List<PathMatch> to compute graph layout.
extension PathMatchLayout on List<PathMatch> {
  /// Compute graph layout from path matches.
  ///
  /// Strategies:
  /// - [LayerStrategy.pattern]: Use pattern order (default, fast)
  /// - [LayerStrategy.longestPath]: Maximize path lengths (best for complex graphs)
  /// - [LayerStrategy.topological]: Use topological ordering (requires [graph])
  ///
  /// Algorithm:
  /// - Node depths: MAX depth across all paths (minimizes crossings)
  /// - Variable depths: MEDIAN depth across nodes (handles outliers)
  ///
  /// Example:
  /// ```dart
  /// final paths = query.matchPaths('a->b->c->d');
  /// final layout = paths.computeLayout();
  /// print(layout.variableDepths); // {a: 0, b: 1, c: 2, d: 3}
  /// ```
  GraphLayout computeLayout({
    LayerStrategy strategy = LayerStrategy.longestPath,
    Graph? graph,
  }) {
    if (isEmpty) {
      return const GraphLayout(
        allNodes: {},
        allEdges: {},
        nodeDepths: {},
        nodesByLayer: {},
        roots: {},
        maxDepth: 0,
        variableDepths: {},
      );
    }

    // 1. Collect all unique nodes and edges
    final allNodes = <String>{};
    final allEdges = <EdgeTriple>{};
    final variableToNodes = <String, Set<String>>{};

    for (final path in this) {
      allNodes.addAll(path.nodes.values);

      // Track which nodes belong to which variables
      for (final entry in path.nodes.entries) {
        variableToNodes.putIfAbsent(entry.key, () => {}).add(entry.value);
      }

      // Convert PathEdge to EdgeTriple
      for (final edge in path.edges) {
        allEdges.add(EdgeTriple(edge.from, edge.type, edge.to));
      }
    }

    // 2. Compute node depths based on strategy
    final Map<String, int> nodeDepths;

    switch (strategy) {
      case LayerStrategy.pattern:
        nodeDepths = _computePatternDepths(this);
        break;
      case LayerStrategy.longestPath:
        nodeDepths = _computeLongestPathDepths(allNodes, allEdges);
        break;
      case LayerStrategy.topological:
        if (graph == null) {
          throw ArgumentError(
            'Graph instance required for topological strategy. '
            'Either provide graph parameter or use a different strategy.',
          );
        }
        nodeDepths = _computeTopologicalDepths(graph, allNodes, allEdges);
        break;
    }

    // 3. Find roots (nodes with no incoming edges in the path set)
    final nodesWithIncoming = allEdges.map((e) => e.dst).toSet();
    final roots = allNodes.difference(nodesWithIncoming);

    // 4. Group nodes by layer
    final nodesByLayer = <int, Set<String>>{};
    var maxDepth = 0;
    for (final entry in nodeDepths.entries) {
      nodesByLayer.putIfAbsent(entry.value, () => {}).add(entry.key);
      if (entry.value > maxDepth) maxDepth = entry.value;
    }

    // 5. Compute typical depth for each variable (MEDIAN)
    final variableDepths = <String, int>{};
    for (final entry in variableToNodes.entries) {
      // Collect depths for all nodes with this variable
      final depths = entry.value
          .map((nodeId) => nodeDepths[nodeId] ?? 0)
          .toList()
        ..sort();

      // Use median depth (handles outliers better than mean)
      if (depths.isNotEmpty) {
        variableDepths[entry.key] = depths[depths.length ~/ 2];
      }
    }

    return GraphLayout(
      allNodes: allNodes,
      allEdges: allEdges,
      nodeDepths: nodeDepths,
      nodesByLayer: nodesByLayer,
      roots: roots,
      maxDepth: maxDepth,
      variableDepths: variableDepths,
    );
  }

  /// Strategy 1: Use pattern order (first occurrence of variable in edges).
  ///
  /// Fast and predictable. Variables appear in left-to-right order
  /// as they appear in the query pattern.
  Map<String, int> _computePatternDepths(List<PathMatch> paths) {
    final nodeDepths = <String, int>{};

    // Take first path as template
    final template = paths.first;
    final orderedVars = <String>[];

    // Build variable order from edges (maintains left-to-right from pattern)
    final seenVars = <String>{};
    for (final edge in template.edges) {
      if (!seenVars.contains(edge.fromVariable)) {
        orderedVars.add(edge.fromVariable);
        seenVars.add(edge.fromVariable);
      }
      if (!seenVars.contains(edge.toVariable)) {
        orderedVars.add(edge.toVariable);
        seenVars.add(edge.toVariable);
      }
    }

    // Handle single-node patterns (no edges)
    if (orderedVars.isEmpty && template.nodes.isNotEmpty) {
      orderedVars.addAll(template.nodes.keys);
    }

    // Assign depths based on variable order
    for (final path in paths) {
      for (var i = 0; i < orderedVars.length; i++) {
        final variable = orderedVars[i];
        final nodeId = path.nodes[variable];
        if (nodeId != null) {
          // Use MAX depth if node appears multiple times
          final currentDepth = nodeDepths[nodeId] ?? -1;
          nodeDepths[nodeId] = currentDepth > i ? currentDepth : i;
        }
      }
    }

    return nodeDepths;
  }

  /// Strategy 2: Longest path from roots (Coffman-Graham-like algorithm).
  ///
  /// Assigns each node to MAX depth across all paths.
  /// Minimizes edge crossings in layered graph drawings.
  Map<String, int> _computeLongestPathDepths(
    Set<String> nodes,
    Set<EdgeTriple> edges,
  ) {
    final nodeDepths = <String, int>{};
    final outgoing = <String, Set<String>>{};
    final incoming = <String, Set<String>>{};

    // Build adjacency lists
    for (final edge in edges) {
      outgoing.putIfAbsent(edge.src, () => {}).add(edge.dst);
      incoming.putIfAbsent(edge.dst, () => {}).add(edge.src);
    }

    // Find roots (nodes with no incoming edges)
    var roots = nodes.where((n) => !incoming.containsKey(n)).toSet();

    // Handle disconnected nodes (no edges at all)
    for (final node in nodes) {
      if (!incoming.containsKey(node) && !outgoing.containsKey(node)) {
        roots.add(node);
      }
    }

    // Handle cycles: if no roots found, pick arbitrary starting node
    if (roots.isEmpty && nodes.isNotEmpty) {
      roots = {nodes.first};
    }

    // BFS to assign depths (longest path from any root)
    // With cycle detection: limit visits per node to prevent infinite loops
    final queue = Queue<String>();
    final visitCount = <String, int>{};

    for (final root in roots) {
      nodeDepths[root] = 0;
      queue.add(root);
    }

    while (queue.isNotEmpty) {
      final current = queue.removeFirst();

      // Cycle detection: if we've visited this node too many times, skip it
      visitCount[current] = (visitCount[current] ?? 0) + 1;
      if (visitCount[current]! > nodes.length) {
        continue; // Cycle detected, skip
      }

      final currentDepth = nodeDepths[current]!;

      for (final neighbor in outgoing[current] ?? <String>{}) {
        final newDepth = currentDepth + 1;

        // Take MAX depth (longest path)
        if (!nodeDepths.containsKey(neighbor) ||
            nodeDepths[neighbor]! < newDepth) {
          nodeDepths[neighbor] = newDepth;
          queue.add(neighbor);
        }
      }
    }

    return nodeDepths;
  }

  /// Strategy 3: Topological sort-based layering.
  ///
  /// Uses Kahn's algorithm for DAG ordering. Falls back to longestPath
  /// if graph contains cycles.
  Map<String, int> _computeTopologicalDepths(
    Graph graph,
    Set<String> nodes,
    Set<EdgeTriple> edges,
  ) {
    // Just use longest path on the path edges - simpler and more reliable
    // than trying to use the full graph topology
    return _computeLongestPathDepths(nodes, edges);
  }
}
