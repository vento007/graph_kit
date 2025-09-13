// extensions_typed.dart

import 'graph.dart';
import 'node.dart';
import 'edge_type.dart';
import 'node_type.dart';
import 'pattern_query.dart';

/// Typed convenience methods for [Graph] using [EdgeType] wrappers.
///
/// These extensions provide type-safe alternatives to the string-based
/// graph methods, helping prevent typos and providing better IDE support.
extension GraphTyped<N extends Node> on Graph<N> {
  /// Adds a typed edge. See [Graph.addEdge].
  void addEdgeT(String src, EdgeType edgeType, String dst) =>
      addEdge(src, edgeType.value, dst);

  /// Gets typed outbound neighbors. See [Graph.outNeighbors].
  Set<String> outNeighborsT(String src, EdgeType edgeType) =>
      outNeighbors(src, edgeType.value);

  /// Gets typed inbound neighbors. See [Graph.inNeighbors].
  Set<String> inNeighborsT(String dst, EdgeType edgeType) =>
      inNeighbors(dst, edgeType.value);

  /// Checks for typed edge existence. See [Graph.hasEdge].
  bool hasEdgeT(String src, EdgeType edgeType, String dst) =>
      hasEdge(src, edgeType.value, dst);
}

/// Typed convenience methods for [PatternQuery] using [EdgeType] and [NodeType] wrappers.
///
/// These extensions provide type-safe alternatives to the string-based
/// query methods for better compile-time safety.
extension PatternQueryTyped<N extends Node> on PatternQuery<N> {
  /// Gets typed outbound neighbors. See [PatternQuery.outFrom].
  Set<String> outFromT(String srcId, EdgeType edgeType) =>
      outFrom(srcId, edgeType.value);

  /// Gets typed inbound neighbors. See [PatternQuery.inTo].
  Set<String> inToT(String dstId, EdgeType edgeType) =>
      inTo(dstId, edgeType.value);

  /// Finds nodes by typed node type. See [PatternQuery.findByType].
  Set<String> findByTypeT(NodeType type) => findByType(type.value);
}
