import 'dart:collection';

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
/// - Nodes are stored by id and exposed through the read-only [nodesById] view
/// - Outgoing adjacency is exposed through the read-only [out] view
/// - Incoming adjacency is exposed through the read-only [inn] view
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
  /// Internal outgoing adjacency map: srcId -> edgeType -> {dstId}.
  final Map<String, Map<String, Set<String>>> _out = {};

  /// Internal incoming adjacency map: dstId -> edgeType -> {srcId}.
  final Map<String, Map<String, Set<String>>> _inn = {};

  /// Internal node storage by ID for fast node lookup.
  final Map<String, N> _nodesById = {};

  /// Edge storage keyed by source -> edgeType -> destination.
  ///
  /// Each entry stores the unique edge object with optional properties.
  final Map<String, Map<String, Map<String, Edge>>> _edges = {};

  /// Read-only node storage by ID.
  ///
  /// Use [addNode], [replaceNode], and [removeNode] to mutate graph nodes.
  Map<String, N> get nodesById => UnmodifiableMapView(_nodesById);

  /// Read-only outgoing adjacency view: srcId -> edgeType -> {dstId}.
  ///
  /// Use graph mutation methods instead of mutating adjacency directly.
  Map<String, Map<String, Set<String>>> get out => _readOnlyAdjacency(_out);

  /// Read-only incoming adjacency view: dstId -> edgeType -> {srcId}.
  ///
  /// Use graph mutation methods instead of mutating adjacency directly.
  Map<String, Map<String, Set<String>>> get inn => _readOnlyAdjacency(_inn);

  /// Returns the node with [id], if it exists.
  N? getNode(String id) => _nodesById[id];

  /// Returns true if a node with [id] exists.
  bool containsNode(String id) => _nodesById.containsKey(id);

  /// All nodes in insertion order.
  Iterable<N> get nodes => _nodesById.values;

  /// All node IDs in insertion order.
  Iterable<String> get nodeIds => _nodesById.keys;

  /// Number of nodes in the graph.
  int get nodeCount => _nodesById.length;

  /// Number of stored edges in the graph.
  int get edgeCount => _edges.values.fold<int>(
    0,
    (count, edgesByType) =>
        count +
        edgesByType.values.fold<int>(
          0,
          (typeCount, edgesByDst) => typeCount + edgesByDst.length,
        ),
  );

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
  void addNode(N node) {
    replaceNode(node);
  }

  /// Adds or replaces a node and returns the previous node, if any.
  ///
  /// Existing edges connected to [node.id] are preserved. This is the
  /// recommended way to update immutable node data while keeping graph
  /// structure intact.
  N? replaceNode(N node) {
    final previous = _nodesById[node.id];

    _nodesById[node.id] = node;
    _out.putIfAbsent(node.id, () => {});
    _inn.putIfAbsent(node.id, () => {});

    return previous;
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

  /// Returns the stored edge object, if any, for the given identifiers.
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
    final srcByType = _out.putIfAbsent(src, () => {});
    final srcTypeSet = srcByType.putIfAbsent(edgeType, () => <String>{});
    srcTypeSet.add(dst);

    final dstByType = _inn.putIfAbsent(dst, () => {});
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

  /// Removes a directed edge from [src] to [dst] with the given [edgeType].
  ///
  /// Returns `true` if any matching edge data existed.
  bool removeEdge(String src, String edgeType, String dst) {
    final removedOut = _removeAdjacency(_out, src, edgeType, dst);
    final removedIn = _removeAdjacency(_inn, dst, edgeType, src);
    final removedStored = _removeStoredEdge(src, edgeType, dst);

    return removedOut || removedIn || removedStored;
  }

  /// Moves an existing edge to a new source and/or destination.
  ///
  /// This is useful for reparenting relationships, such as moving a game piece
  /// from one cell to another or changing a person to a different department.
  /// Existing edge properties are preserved unless [properties] is provided.
  bool moveEdge({
    required String oldSrc,
    required String edgeType,
    required String oldDst,
    String? newSrc,
    String? newDst,
    Map<String, dynamic>? properties,
  }) {
    final existing = getEdge(oldSrc, edgeType, oldDst);
    if (existing == null && !hasEdge(oldSrc, edgeType, oldDst)) {
      return false;
    }

    final targetSrc = newSrc ?? oldSrc;
    final targetDst = newDst ?? oldDst;
    final movedProperties = properties ?? existing?.properties;

    if (targetSrc == oldSrc && targetDst == oldDst) {
      if (properties != null) {
        addEdge(oldSrc, edgeType, oldDst, properties: properties);
      }
      return true;
    }

    removeEdge(oldSrc, edgeType, oldDst);
    addEdge(targetSrc, edgeType, targetDst, properties: movedProperties);
    return true;
  }

  /// Replaces all outgoing edges of [edgeType] from [src] with one edge to [dst].
  ///
  /// This is useful when a source should have exactly one destination for a
  /// relationship, such as assigning a person to one current department.
  /// Returns the number of existing outgoing edges removed before adding the
  /// new edge.
  int setOutgoingEdge(
    String src,
    String edgeType,
    String dst, {
    Map<String, dynamic>? properties,
  }) {
    final removed = clearEdgesFrom(src, edgeType: edgeType);
    addEdge(src, edgeType, dst, properties: properties);
    return removed;
  }

  /// Replaces all incoming edges of [edgeType] to [dst] with one edge from [src].
  ///
  /// This is useful when a destination should have exactly one source for a
  /// relationship, such as reparenting a game piece into one current cell.
  /// Returns the number of existing incoming edges removed before adding the
  /// new edge.
  int setIncomingEdge(
    String dst,
    String edgeType,
    String src, {
    Map<String, dynamic>? properties,
  }) {
    final removed = clearEdgesTo(dst, edgeType: edgeType);
    addEdge(src, edgeType, dst, properties: properties);
    return removed;
  }

  /// Removes a node and all edges connected to it.
  ///
  /// This keeps the outgoing adjacency map, incoming adjacency map, and stored
  /// edge metadata consistent. Returns `true` if the node or any incident edge
  /// existed.
  bool removeNode(String id) {
    final hadNode = _nodesById.containsKey(id);
    final removedOutgoing = clearEdgesFrom(id);
    final removedIncoming = clearEdgesTo(id);

    _nodesById.remove(id);
    _out.remove(id);
    _inn.remove(id);

    return hadNode || removedOutgoing > 0 || removedIncoming > 0;
  }

  /// Removes all outgoing edges from [src].
  ///
  /// If [edgeType] is provided, only outgoing edges with that type are removed.
  /// Returns the number of edges removed.
  int clearEdgesFrom(String src, {String? edgeType}) {
    final edgesToRemove = <({String type, String dst})>[];
    final edgesByType = _out[src];

    if (edgesByType == null) return 0;

    if (edgeType != null) {
      for (final dst in edgesByType[edgeType] ?? const <String>{}) {
        edgesToRemove.add((type: edgeType, dst: dst));
      }
    } else {
      for (final entry in edgesByType.entries) {
        for (final dst in entry.value) {
          edgesToRemove.add((type: entry.key, dst: dst));
        }
      }
    }

    var removed = 0;
    for (final edge in edgesToRemove) {
      if (removeEdge(src, edge.type, edge.dst)) removed++;
    }

    return removed;
  }

  /// Removes all incoming edges to [dst].
  ///
  /// If [edgeType] is provided, only incoming edges with that type are removed.
  /// Returns the number of edges removed.
  int clearEdgesTo(String dst, {String? edgeType}) {
    final edgesToRemove = <({String type, String src})>[];
    final edgesByType = _inn[dst];

    if (edgesByType == null) return 0;

    if (edgeType != null) {
      for (final src in edgesByType[edgeType] ?? const <String>{}) {
        edgesToRemove.add((type: edgeType, src: src));
      }
    } else {
      for (final entry in edgesByType.entries) {
        for (final src in entry.value) {
          edgesToRemove.add((type: entry.key, src: src));
        }
      }
    }

    var removed = 0;
    for (final edge in edgesToRemove) {
      if (removeEdge(edge.src, edge.type, dst)) removed++;
    }

    return removed;
  }

  /// Removes all nodes, edges, and adjacency data from the graph.
  void clear() {
    _nodesById.clear();
    _out.clear();
    _inn.clear();
    _edges.clear();
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
    final neighbors = _out[src]?[edgeType];
    if (neighbors == null) return const <String>{};
    return UnmodifiableSetView(neighbors);
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
    final neighbors = _inn[dst]?[edgeType];
    if (neighbors == null) return const <String>{};
    return UnmodifiableSetView(neighbors);
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
    return _out[src]?[edgeType]?.contains(dst) ?? false;
  }

  Map<String, Map<String, Set<String>>> _readOnlyAdjacency(
    Map<String, Map<String, Set<String>>> source,
  ) {
    return _ReadOnlyAdjacencyMap(source);
  }

  bool _removeAdjacency(
    Map<String, Map<String, Set<String>>> adjacency,
    String nodeId,
    String edgeType,
    String otherNodeId,
  ) {
    final edgesByType = adjacency[nodeId];
    if (edgesByType == null) return false;

    final neighbors = edgesByType[edgeType];
    if (neighbors == null) return false;

    final removed = neighbors.remove(otherNodeId);
    if (neighbors.isEmpty) {
      edgesByType.remove(edgeType);
    }
    if (edgesByType.isEmpty && !_nodesById.containsKey(nodeId)) {
      adjacency.remove(nodeId);
    }

    return removed;
  }

  bool _removeStoredEdge(String src, String edgeType, String dst) {
    final edgesByType = _edges[src];
    if (edgesByType == null) return false;

    final edgesByDst = edgesByType[edgeType];
    if (edgesByDst == null) return false;

    final removed = edgesByDst.remove(dst) != null;
    if (edgesByDst.isEmpty) {
      edgesByType.remove(edgeType);
    }
    if (edgesByType.isEmpty) {
      _edges.remove(src);
    }

    return removed;
  }
}

class _ReadOnlyAdjacencyMap extends MapBase<String, Map<String, Set<String>>> {
  _ReadOnlyAdjacencyMap(this._source);

  final Map<String, Map<String, Set<String>>> _source;

  @override
  Map<String, Set<String>>? operator [](Object? key) {
    final edgesByType = _source[key];
    if (edgesByType == null) return null;
    return _ReadOnlyEdgeTypeMap(edgesByType);
  }

  @override
  void operator []=(String key, Map<String, Set<String>> value) {
    throw _readOnlyGraphViewError();
  }

  @override
  void clear() {
    throw _readOnlyGraphViewError();
  }

  @override
  Iterable<String> get keys => _source.keys;

  @override
  Map<String, Set<String>>? remove(Object? key) {
    throw _readOnlyGraphViewError();
  }
}

class _ReadOnlyEdgeTypeMap extends MapBase<String, Set<String>> {
  _ReadOnlyEdgeTypeMap(this._source);

  final Map<String, Set<String>> _source;

  @override
  Set<String>? operator [](Object? key) {
    final neighbors = _source[key];
    if (neighbors == null) return null;
    return UnmodifiableSetView(neighbors);
  }

  @override
  void operator []=(String key, Set<String> value) {
    throw _readOnlyGraphViewError();
  }

  @override
  void clear() {
    throw _readOnlyGraphViewError();
  }

  @override
  Iterable<String> get keys => _source.keys;

  @override
  Set<String>? remove(Object? key) {
    throw _readOnlyGraphViewError();
  }
}

UnsupportedError _readOnlyGraphViewError() {
  return UnsupportedError(
    'Graph storage views are read-only. Use Graph mutation methods instead.',
  );
}
