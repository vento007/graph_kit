import 'graph.dart';
import 'node.dart';

/// A lightweight representation of a directed, typed edge in the graph.
///
/// Used primarily in traversal results to represent the edges that were
/// traversed during subgraph expansion operations.
class EdgeTriple {
  /// Source node ID of this edge.
  final String src;

  /// Type/label of this edge (e.g., 'MEMBER_OF', 'SOURCE').
  final String type;

  /// Destination node ID of this edge.
  final String dst;

  /// Creates a new edge triple.
  const EdgeTriple(this.src, this.type, this.dst);

  @override
  bool operator ==(Object other) {
    return other is EdgeTriple &&
        other.src == src &&
        other.type == type &&
        other.dst == dst;
  }

  @override
  int get hashCode => Object.hash(src, type, dst);

  @override
  String toString() => 'EdgeTriple($src -[$type]-> $dst)';
}

/// The result of a subgraph expansion operation.
///
/// Contains the nodes and edges discovered during traversal, along with
/// distance information from the seed nodes in both directions.
///
/// This is returned by [expandSubgraph] and provides a complete view of
/// the subgraph including connectivity and hop distances.
class SubgraphResult {
  /// Set of node IDs included in the subgraph.
  final Set<String> nodes;

  /// Set of directed typed edges included in the subgraph.
  final Set<EdgeTriple> edges;

  /// Distance (in hops) from seed nodes via forward/outgoing edges.
  ///
  /// Maps node IDs to their minimum distance from any seed node when
  /// traversing in the forward direction.
  final Map<String, int> forwardDist;

  /// Distance (in hops) from seed nodes via backward/incoming edges.
  ///
  /// Maps node IDs to their minimum distance from any seed node when
  /// traversing in the backward direction.
  final Map<String, int> backwardDist;

  /// Creates a new subgraph result.
  const SubgraphResult({
    required this.nodes,
    required this.edges,
    required this.forwardDist,
    required this.backwardDist,
  });
}

class _FrontierItem {
  final String id;
  final int dist;
  const _FrontierItem(this.id, this.dist);
}

/// Generic closure expansion collecting nodes/edges and distances.
class EdgeExpansion {
  final Set<String> nodes = <String>{};
  final Set<EdgeTriple> edges = <EdgeTriple>{};
  final Map<String, int> dist = <String, int>{};
}

EdgeExpansion _expand<N extends Node>(
  Graph<N> g,
  Set<String> seeds, {
  required Set<String> edgeTypes,
  required int maxHops,
  required bool inbound,
}) {
  final exp = EdgeExpansion();
  final queue = <_FrontierItem>[];
  for (final s in seeds) {
    // Only add seeds that actually exist in the graph
    if (g.nodesById.containsKey(s)) {
      exp.nodes.add(s);
      exp.dist[s] = 0;
      queue.add(_FrontierItem(s, 0));
    }
  }
  int qi = 0;
  while (qi < queue.length) {
    final cur = queue[qi++];
    if (cur.dist >= maxHops) continue;

    // Traverse across all allowed edge types
    for (final et in edgeTypes) {
      final neighbors = inbound
          ? g.inNeighbors(cur.id, et)
          : g.outNeighbors(cur.id, et);
      for (final nb in neighbors) {
        // Record the actual directed edge with proper orientation
        final e = inbound
            ? EdgeTriple(nb, et, cur.id)
            : EdgeTriple(cur.id, et, nb);
        exp.edges.add(e);
        if (!exp.dist.containsKey(nb)) {
          exp.dist[nb] = cur.dist + 1;
          exp.nodes.add(nb);
          queue.add(_FrontierItem(nb, cur.dist + 1));
        }
      }
    }
  }
  return exp;
}

/// Expand forward (rightward) from seeds for up to [maxHops] using [edgeTypes].
EdgeExpansion expandForward<N extends Node>(
  Graph<N> g,
  Set<String> seeds, {
  required Set<String> edgeTypes,
  int maxHops = 2,
}) {
  return _expand(
    g,
    seeds,
    edgeTypes: edgeTypes,
    maxHops: maxHops,
    inbound: false,
  );
}

/// Expand backward (leftward) from seeds for up to [maxHops] using [edgeTypes].
EdgeExpansion expandBackward<N extends Node>(
  Graph<N> g,
  Set<String> seeds, {
  required Set<String> edgeTypes,
  int maxHops = 1,
}) {
  return _expand(
    g,
    seeds,
    edgeTypes: edgeTypes,
    maxHops: maxHops,
    inbound: true,
  );
}

/// Builds a subgraph by expanding from seed nodes in both directions.
///
/// This function performs bidirectional BFS expansion from the given seed nodes,
/// collecting all reachable nodes and edges within the specified hop limits.
/// It can also apply reachability filters to prune the result.
///
/// ## Parameters
/// - [g]: The graph to traverse
/// - [seeds]: Starting node IDs for expansion
/// - [edgeTypesRightward]: Edge types to follow in forward direction
/// - [edgeTypesLeftward]: Edge types to follow in backward direction (defaults to [edgeTypesRightward])
/// - [forwardHops]: Maximum hops in forward direction (default: 2)
/// - [backwardHops]: Maximum hops in backward direction (default: 0)
/// - [requireReachableFrom]: Keep only nodes reachable from these filter nodes
/// - [requireCanReach]: Keep only nodes that can reach these filter nodes
///
/// ## Returns
/// A [SubgraphResult] containing the expanded subgraph with nodes, edges,
/// and distance information.
///
/// ## Example
/// ```dart
/// // Expand 2 hops forward and 1 hop backward from user u1
/// final result = expandSubgraph(
///   graph,
///   seeds: {'u1'},
///   edgeTypesRightward: {'MEMBER_OF', 'HAS_CLIENT'},
///   forwardHops: 2,
///   backwardHops: 1,
/// );
///
/// print('Nodes: ${result.nodes.length}');
/// print('Edges: ${result.edges.length}');
/// for (final edge in result.edges) {
///   print('${edge.src} -[${edge.type}]-> ${edge.dst}');
/// }
/// ```
SubgraphResult expandSubgraph<N extends Node>(
  Graph<N> g, {
  required Set<String> seeds,
  required Set<String> edgeTypesRightward,
  Set<String>? edgeTypesLeftward,
  int forwardHops = 2,
  int backwardHops = 0,
  Set<String> requireReachableFrom = const {},
  Set<String> requireCanReach = const {},
}) {
  final etR = edgeTypesRightward;
  final etL = edgeTypesLeftward ?? etR;

  final fwd = expandForward(g, seeds, edgeTypes: etR, maxHops: forwardHops);
  final bwd = expandBackward(g, seeds, edgeTypes: etL, maxHops: backwardHops);

  // Union
  final nodes = <String>{...fwd.nodes, ...bwd.nodes};
  final edges = <EdgeTriple>{...fwd.edges, ...bwd.edges};

  // Optional pruning by masks.
  if (requireReachableFrom.isNotEmpty) {
    final allowed = _expand(
      g,
      requireReachableFrom,
      edgeTypes: etR,
      maxHops: 32,
      inbound: false,
    ).nodes;
    nodes.retainAll(allowed);
  }
  if (requireCanReach.isNotEmpty) {
    final allowed = _expand(
      g,
      requireCanReach,
      edgeTypes: etL,
      maxHops: 32,
      inbound: true,
    ).nodes;
    nodes.retainAll(allowed);
  }

  // Drop edges whose endpoints were pruned.
  edges.removeWhere((e) => !nodes.contains(e.src) || !nodes.contains(e.dst));

  return SubgraphResult(
    nodes: nodes,
    edges: edges,
    forwardDist: Map.unmodifiable(fwd.dist),
    backwardDist: Map.unmodifiable(bwd.dist),
  );
}

/// Result of path enumeration containing all discovered paths.
class PathEnumerationResult {
  /// All simple paths found from source to target.
  final List<List<String>> paths;

  /// Number of paths that were truncated due to hop limit.
  final int truncatedPaths;

  /// Total number of nodes explored during search.
  final int nodesExplored;

  const PathEnumerationResult({
    required this.paths,
    required this.truncatedPaths,
    required this.nodesExplored,
  });

  /// Returns true if any paths were found.
  bool get hasPaths => paths.isNotEmpty;

  /// Returns the shortest path by hop count, or null if no paths exist.
  List<String>? get shortestPath => paths.isEmpty ? null :
    paths.reduce((a, b) => a.length <= b.length ? a : b);
}

/// Enumerates all simple paths between two nodes within a hop limit.
///
/// Finds all possible routes from [from] to [to] that:
/// - Don't revisit nodes (simple paths)
/// - Stay within [maxHops] limit
/// - Use only specified [edgeTypes] if provided
///
/// Uses subgraph expansion to optimize search space before path enumeration.
///
/// Example:
/// ```dart
/// final result = enumeratePaths(graph, 'teamA', 'core', maxHops: 4);
/// print('Found ${result.paths.length} paths');
/// for (final path in result.paths) {
///   print('Path: ${path.join(' -> ')}');
/// }
/// ```
PathEnumerationResult enumeratePaths(
  Graph<Node> graph,
  String from,
  String to, {
  required int maxHops,
  Set<String>? edgeTypes,
}) {
  // Early validation
  if (!graph.nodesById.containsKey(from) || !graph.nodesById.containsKey(to)) {
    return const PathEnumerationResult(paths: [], truncatedPaths: 0, nodesExplored: 0);
  }

  if (from == to) {
    return PathEnumerationResult(paths: [[from]], truncatedPaths: 0, nodesExplored: 1);
  }

  // Pre-prune search space using subgraph expansion
  final subgraph = expandSubgraph(
    graph,
    seeds: {from},
    edgeTypesRightward: edgeTypes ?? graph.out.values
        .expand((nodeEdges) => nodeEdges.keys)
        .toSet(),
    forwardHops: maxHops,
    backwardHops: 0,
  );

  // If target not reachable within hop limit, return empty
  if (!subgraph.nodes.contains(to)) {
    return const PathEnumerationResult(paths: [], truncatedPaths: 0, nodesExplored: 0);
  }

  // DFS path enumeration within pruned subgraph
  final allPaths = <List<String>>[];
  int truncatedCount = 0;
  final exploredNodes = <String>{};

  void dfs(String current, List<String> currentPath, Set<String> visited) {
    exploredNodes.add(current);

    if (current == to) {
      allPaths.add(List.from(currentPath));
      return;
    }

    if (currentPath.length >= maxHops) {
      truncatedCount++;
      return;
    }

    final outgoing = graph.out[current];
    if (outgoing == null) return;

    for (final edgeType in outgoing.keys) {
      if (edgeTypes != null && !edgeTypes.contains(edgeType)) continue;

      for (final neighbor in outgoing[edgeType]!) {
        // Only explore nodes in our pruned subgraph
        if (!subgraph.nodes.contains(neighbor)) continue;
        if (visited.contains(neighbor)) continue; // Avoid cycles

        currentPath.add(neighbor);
        visited.add(neighbor);

        dfs(neighbor, currentPath, visited);

        visited.remove(neighbor);
        currentPath.removeLast();
      }
    }
  }

  dfs(from, [from], {from});

  return PathEnumerationResult(
    paths: allPaths,
    truncatedPaths: truncatedCount,
    nodesExplored: exploredNodes.length,
  );
}
