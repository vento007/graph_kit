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

  /// Finds all nodes that can reach a given target node.
  ///
  /// This is the inverse of [reachableFrom] - it follows incoming edges
  /// to find all nodes that have a path TO the target node.
  ///
  /// Returns a set containing all nodes that can reach the target node,
  /// including the target node itself.
  ///
  /// Parameters:
  /// - [nodeId]: The target node ID
  /// - [edgeType]: Optional edge type filter
  ///
  /// Example:
  /// ```dart
  /// final canReachTarget = algorithms.reachableBy('target');
  /// print('${canReachTarget.length} nodes can reach target');
  /// ```
  Set<String> reachableBy(String nodeId, {String? edgeType}) {
    if (!graph.nodesById.containsKey(nodeId)) {
      return <String>{};
    }

    final reachable = <String>{};
    final stack = <String>[nodeId];

    while (stack.isNotEmpty) {
      final current = stack.removeLast();
      if (reachable.contains(current)) continue;

      reachable.add(current);

      // Add all incoming neighbors
      final incoming = graph.inn[current];
      if (incoming != null) {
        for (final edgeTypeKey in incoming.keys) {
          if (edgeType == null || edgeTypeKey == edgeType) {
            for (final neighbor in incoming[edgeTypeKey]!) {
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

  /// Finds all nodes connected to a given node in both directions.
  ///
  /// This combines [reachableFrom] and [reachableBy] to find all nodes
  /// that are connected to the given node regardless of edge direction.
  ///
  /// Returns a set containing all nodes reachable from OR to the given node,
  /// including the node itself.
  ///
  /// Parameters:
  /// - [nodeId]: The center node ID
  /// - [edgeType]: Optional edge type filter
  ///
  /// Example:
  /// ```dart
  /// final connected = algorithms.reachableAll('center');
  /// print('${connected.length} nodes are connected to center');
  /// ```
  Set<String> reachableAll(String nodeId, {String? edgeType}) {
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

      // Add all incoming neighbors
      final incoming = graph.inn[current];
      if (incoming != null) {
        for (final edgeTypeKey in incoming.keys) {
          if (edgeType == null || edgeTypeKey == edgeType) {
            for (final neighbor in incoming[edgeTypeKey]!) {
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

  /// Calculates betweenness centrality for all nodes.
  ///
  /// Betweenness centrality measures how often a node acts as a bridge along
  /// the shortest paths between other nodes. Nodes with high betweenness
  /// centrality are critical connection points in the network.
  ///
  /// Returns a map from node ID to centrality score (0.0 to 1.0).
  ///
  /// Example:
  /// ```dart
  /// final centrality = algorithms.betweennessCentrality();
  /// final bridges = centrality.entries
  ///     .where((e) => e.value > 0.5)
  ///     .map((e) => e.key)
  ///     .toList();
  /// ```
  Map<String, double> betweennessCentrality({String? edgeType}) {
    final nodes = graph.nodesById.keys.toList();
    final centrality = <String, double>{};

    // Initialize centrality scores
    for (final node in nodes) {
      centrality[node] = 0.0;
    }

    // For each pair of nodes, find shortest paths and count how many
    // pass through each intermediate node
    for (int i = 0; i < nodes.length; i++) {
      for (int j = i + 1; j < nodes.length; j++) {
        final source = nodes[i];
        final target = nodes[j];

        final pathResult = shortestPath(source, target, edgeType: edgeType);
        if (pathResult.path.isNotEmpty && pathResult.path.length > 2) {
          // Count intermediate nodes (exclude source and target)
          for (int k = 1; k < pathResult.path.length - 1; k++) {
            final intermediateNode = pathResult.path[k];
            centrality[intermediateNode] = centrality[intermediateNode]! + 1.0;
          }
        }
      }
    }

    // Normalize by the maximum possible betweenness
    final maxPossible = (nodes.length - 1) * (nodes.length - 2) / 2;
    if (maxPossible > 0) {
      for (final node in nodes) {
        centrality[node] = centrality[node]! / maxPossible;
      }
    }

    return centrality;
  }

  /// Calculates closeness centrality for all nodes.
  ///
  /// Closeness centrality measures how close a node is to all other nodes
  /// in the network. Nodes with high closeness centrality can reach other
  /// nodes via shorter paths.
  ///
  /// Returns a map from node ID to centrality score (0.0 to 1.0).
  ///
  /// Example:
  /// ```dart
  /// final centrality = algorithms.closenessCentrality();
  /// final mostCentral = centrality.entries
  ///     .reduce((a, b) => a.value > b.value ? a : b)
  ///     .key;
  /// ```
  Map<String, double> closenessCentrality({String? edgeType}) {
    final nodes = graph.nodesById.keys.toList();
    final centrality = <String, double>{};

    for (final sourceNode in nodes) {
      double totalDistance = 0.0;
      int reachableNodes = 0;

      for (final targetNode in nodes) {
        if (sourceNode != targetNode) {
          final pathResult = shortestPath(sourceNode, targetNode, edgeType: edgeType);
          if (pathResult.path.isNotEmpty) {
            totalDistance += pathResult.distance;
            reachableNodes++;
          }
        }
      }

      // Closeness is reciprocal of average distance
      if (reachableNodes > 0 && totalDistance > 0) {
        centrality[sourceNode] = reachableNodes / totalDistance;
      } else {
        centrality[sourceNode] = 0.0;
      }
    }

    // Normalize to 0-1 range
    final maxCentrality = centrality.values.isEmpty ? 0.0 : centrality.values.reduce((a, b) => a > b ? a : b);
    if (maxCentrality > 0) {
      for (final node in nodes) {
        centrality[node] = centrality[node]! / maxCentrality;
      }
    }

    return centrality;
  }
}

