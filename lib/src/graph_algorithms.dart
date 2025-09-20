import 'dart:collection';

import 'graph.dart';
import 'node.dart';

/// Result of a shortest path query.
class ShortestPathResult {
  /// The path from source to destination as a list of node IDs.
  /// Empty if no path exists.
  final List<String> path;

  /// The total distance/cost of the path.
  /// [double.infinity] if no path exists.
  final double distance;

  /// Whether a path was found between source and destination.
  final bool found;

  const ShortestPathResult({
    required this.path,
    required this.distance,
    required this.found,
  });

  @override
  String toString() => found
    ? 'ShortestPathResult(path: $path, distance: $distance)'
    : 'ShortestPathResult(no path found)';
}

/// Graph algorithms for analysis and traversal.
///
/// Provides common graph algorithms including shortest path, connected components,
/// reachability analysis, and topological sorting.
///
/// Example:
/// ```dart
/// final graph = Graph<Node>();
/// // ... add nodes and edges ...
///
/// final algorithms = GraphAlgorithms(graph);
/// final path = algorithms.shortestPath('start', 'end');
/// if (path.found) {
///   print('Shortest path: ${path.path}');
/// }
/// ```
class GraphAlgorithms<T extends Node> {
  /// The graph to perform algorithms on.
  final Graph<T> graph;

  /// Creates a new graph algorithms instance for the given [graph].
  GraphAlgorithms(this.graph);

  /// Finds the shortest path between two nodes using BFS.
  ///
  /// Returns a [ShortestPathResult] containing the path, distance (number of hops),
  /// and whether a path was found.
  ///
  /// Parameters:
  /// - [from]: Source node ID
  /// - [to]: Destination node ID
  /// - [edgeType]: Optional edge type filter
  ///
  /// Example:
  /// ```dart
  /// final result = algorithms.shortestPath('a', 'c');
  /// if (result.found) {
  ///   print('Path: ${result.path}, Distance: ${result.distance}');
  /// }
  /// ```
  ShortestPathResult shortestPath(
    String from,
    String to, {
    String? edgeType,
  }) {
    if (!graph.nodesById.containsKey(from) || !graph.nodesById.containsKey(to)) {
      return const ShortestPathResult(
        path: [],
        distance: double.infinity,
        found: false,
      );
    }

    if (from == to) {
      return ShortestPathResult(
        path: [from],
        distance: 0,
        found: true,
      );
    }

    return _bfsShortestPath(from, to, edgeType);
  }

  /// Finds all connected components in the graph.
  ///
  /// Returns a list of sets, where each set contains the node IDs
  /// in one connected component. Uses union-find algorithm for efficiency.
  ///
  /// Parameters:
  /// - [edgeType]: Optional edge type filter
  ///
  /// Example:
  /// ```dart
  /// final components = algorithms.connectedComponents();
  /// print('Found ${components.length} components');
  /// for (final component in components) {
  ///   print('Component: $component');
  /// }
  /// ```
  List<Set<String>> connectedComponents({String? edgeType}) {
    final visited = <String>{};
    final components = <Set<String>>[];

    for (final nodeId in graph.nodesById.keys) {
      if (!visited.contains(nodeId)) {
        final component = <String>{};
        _dfsComponent(nodeId, visited, component, edgeType);
        if (component.isNotEmpty) {
          components.add(component);
        }
      }
    }

    return components;
  }

  /// Finds all nodes reachable from a given starting node.
  ///
  /// Uses depth-first search to find all nodes that can be reached
  /// by following outgoing edges from the starting node.
  ///
  /// Parameters:
  /// - [nodeId]: Starting node ID
  /// - [edgeType]: Optional edge type filter
  ///
  /// Returns a set containing the starting node and all reachable nodes.
  ///
  /// Example:
  /// ```dart
  /// final reachable = algorithms.reachableFrom('start');
  /// print('Can reach ${reachable.length} nodes from start');
  /// ```
  Set<String> reachableFrom(String nodeId, {String? edgeType}) {
    if (!graph.nodesById.containsKey(nodeId)) {
      return <String>{};
    }

    final reachable = <String>{};
    final stack = <String>[nodeId];

    while (stack.isNotEmpty) {
      final current = stack.removeLast();
      if (reachable.contains(current)) continue;

      reachable.add(current);

      // Add all outgoing neighbors
      final outgoing = graph.out[current];
      if (outgoing != null) {
        for (final edgeTypeKey in outgoing.keys) {
          if (edgeType == null || edgeTypeKey == edgeType) {
            for (final neighbor in outgoing[edgeTypeKey]!) {
              if (!reachable.contains(neighbor)) {
                stack.add(neighbor);
              }
            }
          }
        }
      }
    }

    return reachable;
  }

  /// Performs a topological sort of the graph.
  ///
  /// Returns nodes in topological order (dependencies before dependents).
  /// For dependency graphs where "A DEPENDS_ON B" means A needs B to be done first,
  /// the result will have B before A.
  ///
  /// Throws [ArgumentError] if the graph contains cycles.
  ///
  /// Uses Kahn's algorithm for efficiency and cycle detection.
  ///
  /// Parameters:
  /// - [edgeType]: Optional edge type filter
  ///
  /// Example:
  /// ```dart
  /// try {
  ///   final sorted = algorithms.topologicalSort();
  ///   print('Execution order: $sorted');
  /// } catch (e) {
  ///   print('Graph contains cycles!');
  /// }
  /// ```
  List<String> topologicalSort({String? edgeType}) {
    final outDegree = <String, int>{};
    final queue = Queue<String>();
    final result = <String>[];

    // Initialize out-degree count for all nodes
    for (final nodeId in graph.nodesById.keys) {
      outDegree[nodeId] = 0;
    }

    // Calculate out-degrees (for dependency edges, we want nodes with no dependencies first)
    for (final srcId in graph.out.keys) {
      final outgoing = graph.out[srcId]!;
      for (final edgeTypeKey in outgoing.keys) {
        if (edgeType == null || edgeTypeKey == edgeType) {
          outDegree[srcId] = (outDegree[srcId] ?? 0) + outgoing[edgeTypeKey]!.length;
        }
      }
    }

    // Add all nodes with out-degree 0 to queue (no dependencies)
    for (final entry in outDegree.entries) {
      if (entry.value == 0) {
        queue.add(entry.key);
      }
    }

    // Process queue
    while (queue.isNotEmpty) {
      final current = queue.removeFirst();
      result.add(current);

      // Find nodes that depend on current and reduce their dependency count
      final incoming = graph.inn[current];
      if (incoming != null) {
        for (final edgeTypeKey in incoming.keys) {
          if (edgeType == null || edgeTypeKey == edgeType) {
            for (final dependent in incoming[edgeTypeKey]!) {
              outDegree[dependent] = outDegree[dependent]! - 1;
              if (outDegree[dependent] == 0) {
                queue.add(dependent);
              }
            }
          }
        }
      }
    }

    // Check for cycles
    if (result.length != graph.nodesById.length) {
      throw ArgumentError('Graph contains cycles - topological sort not possible');
    }

    return result;
  }

  /// BFS shortest path for unweighted graphs.
  ShortestPathResult _bfsShortestPath(String from, String to, String? edgeType) {
    final queue = Queue<String>();
    final visited = <String>{};
    final parent = <String, String?>{};

    queue.add(from);
    visited.add(from);
    parent[from] = null;

    while (queue.isNotEmpty) {
      final current = queue.removeFirst();

      if (current == to) {
        // Reconstruct path
        final path = <String>[];
        String? node = to;
        while (node != null) {
          path.insert(0, node);
          node = parent[node];
        }

        return ShortestPathResult(
          path: path,
          distance: path.length - 1.0,
          found: true,
        );
      }

      // Explore neighbors in a consistent order for deterministic results
      final outgoing = graph.out[current];
      if (outgoing != null) {
        final neighbors = <String>[];
        for (final edgeTypeKey in outgoing.keys) {
          if (edgeType == null || edgeTypeKey == edgeType) {
            neighbors.addAll(outgoing[edgeTypeKey]!);
          }
        }

        // Sort neighbors for consistent path selection in case of ties
        neighbors.sort();

        for (final neighbor in neighbors) {
          if (!visited.contains(neighbor)) {
            visited.add(neighbor);
            parent[neighbor] = current;
            queue.add(neighbor);
          }
        }
      }
    }

    return const ShortestPathResult(
      path: [],
      distance: double.infinity,
      found: false,
    );
  }

  /// DFS helper for connected components.
  void _dfsComponent(
    String nodeId,
    Set<String> visited,
    Set<String> component,
    String? edgeType,
  ) {
    if (visited.contains(nodeId)) return;

    visited.add(nodeId);
    component.add(nodeId);

    // Explore outgoing edges
    final outgoing = graph.out[nodeId];
    if (outgoing != null) {
      for (final edgeTypeKey in outgoing.keys) {
        if (edgeType == null || edgeTypeKey == edgeType) {
          for (final neighbor in outgoing[edgeTypeKey]!) {
            _dfsComponent(neighbor, visited, component, edgeType);
          }
        }
      }
    }

    // Explore incoming edges (treat as undirected for components)
    final incoming = graph.inn[nodeId];
    if (incoming != null) {
      for (final edgeTypeKey in incoming.keys) {
        if (edgeType == null || edgeTypeKey == edgeType) {
          for (final neighbor in incoming[edgeTypeKey]!) {
            _dfsComponent(neighbor, visited, component, edgeType);
          }
        }
      }
    }
  }
}

