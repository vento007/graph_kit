/// A lightweight, in-memory graph library with pattern-based queries and efficient traversal.
///
/// This library provides a simple yet powerful graph data structure with:
/// - Generic typed nodes and edges
/// - Cypher-inspired pattern query language
/// - Bidirectional adjacency for fast traversal
/// - Subgraph expansion algorithms
/// - Type-safe operation extensions
///
/// ## Quick Start
///
/// ```dart
/// import 'package:graph_kit/graph_kit.dart';
///
/// // Create a graph
/// final graph = Graph<Node>();
/// final query = PatternQuery(graph);
///
/// // Add nodes and edges
/// graph.addNode(Node(id: 'alice', type: 'User', label: 'Alice'));
/// graph.addNode(Node(id: 'admins', type: 'Group', label: 'Administrators'));
/// graph.addEdge('alice', 'MEMBER_OF', 'admins');
///
/// // Query with patterns
/// final results = query.match('user-[:MEMBER_OF]->group', startId: 'alice');
/// print(results['group']); // {'admins'}
/// ```

library;

// Type safety helpers
export 'src/edge_type.dart';
export 'src/extensions_typed.dart';
export 'src/graph.dart';
export 'src/graph_algorithms.dart';
// Core graph components
export 'src/node.dart';
export 'src/node_type.dart';
export 'src/pattern_query.dart';
export 'src/pattern_query_petit.dart';
export 'src/serialization.dart';
export 'src/traversal.dart';
