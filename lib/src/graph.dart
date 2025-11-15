import 'edge.dart';
import 'node.dart';

/// A generic directed multi-graph with typed edges and efficient adjacency storage.
///
/// This graph implementation supports:
/// - Multiple edges between the same pair of nodes (multi-graph)
/// - Directed edges with string-based types (e.g., 'MEMBER_OF', 'HAS_CLIENT')
/// - Generic node types extending [Node]
/// - Fast neighbor lookup in both directions
///
/// ## Storage Structure
/// - Nodes are stored by id in [nodesById]
/// - Outgoing adjacency is stored in [out] as: `srcId -> edgeType -> {dstId}`
/// - Incoming adjacency is stored in [inn] as: `dstId -> edgeType -> {srcId}`
///
/// ## Example Usage
/// ```dart
/// final graph = Graph<Node>();
/// graph.addNode(Node(id: 'u1', type: 'User', label: 'Alice'));
/// graph.addNode(Node(id: 'g1', type: 'Group', label: 'Admins'));
/// graph.addEdge('u1', 'MEMBER_OF', 'g1');
///
/// print(graph.outNeighbors('u1', 'MEMBER_OF')); // {'g1'}
/// print(graph.hasEdge('u1', 'MEMBER_OF', 'g1')); // true
/// ```
class Graph<N extends Node> {
  /// Outgoing adjacency map: srcId -> edgeType -> {dstId}.
  ///
  /// Used for efficient forward traversal from a source node.
  final Map<String, Map<String, Set<String>>> out = {};

  /// Incoming adjacency map: dstId -> edgeType -> {srcId}.
  ///
  /// Used for efficient backward traversal to a destination node.
  final Map<String, Map<String, Set<String>>> inn = {};

  /// Node storage by ID for fast node lookup.
  ///
  /// Maps node IDs to their corresponding node instances.
  final Map<String, N> nodesById = {};

  /// Edge storage keyed by source -> edgeType -> destination.
  ///
  /// Each entry stores the unique edge object (with optional properties).
  final Map<String, Map<String, Map<String, Edge>>> _edges = {};

  /// Adds or replaces a node in the graph.
  ///
  /// If a node with the same [id] already exists, it will be replaced.
  /// This also initializes empty adjacency entries for the node.
  ///
  /// Example:
  /// ```dart
  /// final user = Node(id: 'u1', type: 'User', label: 'Alice');
  /// graph.addNode(user);
  /// ```
  void addNode(N n) {
    nodesById[n.id] = n;
    out.putIfAbsent(n.id, () => {});
    inn.putIfAbsent(n.id, () => {});
  }

  /// Returns all edges in the graph. Useful for serialization and inspection.
  Iterable<Edge> get edges sync* {
    for (final edgesByType in _edges.values) {
      for (final edgesByDst in edgesByType.values) {
        for (final edge in edgesByDst.values) {
          yield edge;
        }
      }
    }
  }

  /// Returns the stored edge object (if any) for the given identifiers.
  Edge? getEdge(String src, String edgeType, String dst) {
    return _edges[src]?[edgeType]?[dst];
  }

  /// Returns the properties map for a given edge, if stored.
  Map<String, dynamic>? edgeProperties(
    String src,
    String edgeType,
    String dst,
  ) {
    return getEdge(src, edgeType, dst)?.properties;
  }

  /// Adds a directed edge from [src] to [dst] with the given [edgeType].
  ///
  /// Creates adjacency entries even if the nodes haven't been added via [addNode].
  /// This allows building the graph structure before all nodes are known,
  /// but does not auto-create node instances to maintain type safety.
  ///
  /// Parameters:
  /// - [src]: Source node ID
  /// - [edgeType]: Type/label of the edge (e.g., 'MEMBER_OF', 'HAS_CLIENT')
  /// - [dst]: Destination node ID
  ///
  /// Example:
  /// ```dart
  /// graph.addEdge('u1', 'MEMBER_OF', 'g1');
  /// graph.addEdge('u1', 'HAS_CLIENT', 'c1');
  /// ```
  void addEdge(
    String src,
    String edgeType,
    String dst, {
    Map<String, dynamic>? properties,
  }) {
    final srcByType = out.putIfAbsent(src, () => {});
    final srcTypeSet = srcByType.putIfAbsent(edgeType, () => <String>{});
    srcTypeSet.add(dst);

    final dstByType = inn.putIfAbsent(dst, () => {});
    final dstTypeSet = dstByType.putIfAbsent(edgeType, () => <String>{});
    dstTypeSet.add(src);

    final edgesByType = _edges.putIfAbsent(src, () => {});
    final edgesByDst = edgesByType.putIfAbsent(edgeType, () => {});
    final existing = edgesByDst[dst];

    if (existing != null) {
      if (properties != null) {
        edgesByDst[dst] = existing.copyWith(properties: properties);
      }
    } else {
      edgesByDst[dst] = Edge(
        src: src,
        type: edgeType,
        dst: dst,
        properties: properties,
      );
    }
  }

  /// Returns the set of destination node IDs reachable from [src] via [edgeType].
  ///
  /// Used for forward traversal. Returns an empty set if no such edges exist.
  ///
  /// Example:
  /// ```dart
  /// final groups = graph.outNeighbors('u1', 'MEMBER_OF');
  /// print(groups); // {'g1', 'g2'}
  /// ```
  Set<String> outNeighbors(String src, String edgeType) {
    return out[src]?[edgeType] ?? const <String>{};
  }

  /// Returns the set of source node IDs that can reach [dst] via [edgeType].
  ///
  /// Used for backward traversal. Returns an empty set if no such edges exist.
  ///
  /// Example:
  /// ```dart
  /// final users = graph.inNeighbors('g1', 'MEMBER_OF');
  /// print(users); // {'u1', 'u2'}
  /// ```
  Set<String> inNeighbors(String dst, String edgeType) {
    return inn[dst]?[edgeType] ?? const <String>{};
  }

  /// Returns `true` if a directed edge exists from [src] to [dst] with [edgeType].
  ///
  /// Example:
  /// ```dart
  /// if (graph.hasEdge('u1', 'MEMBER_OF', 'g1')) {
  ///   print('User u1 is a member of group g1');
  /// }
  /// ```
  bool hasEdge(String src, String edgeType, String dst) {
    return out[src]?[edgeType]?.contains(dst) ?? false;
  }
}
