// pattern_query_petit.dart
import 'package:petitparser/petitparser.dart';
import 'graph.dart';
import 'node.dart';

/// Represents an edge in a path result, containing connection information.
class PathEdge {
  /// Source node ID
  final String from;

  /// Target node ID
  final String to;

  /// Edge type (e.g., 'WORKS_FOR', 'MANAGES')
  final String type;

  /// Variable name for source node from pattern (e.g., 'person')
  final String fromVariable;

  /// Variable name for target node from pattern (e.g., 'team')
  final String toVariable;

  const PathEdge({
    required this.from,
    required this.to,
    required this.type,
    required this.fromVariable,
    required this.toVariable,
  });

  @override
  String toString() => '$fromVariable($from) -[:$type]-> $toVariable($to)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PathEdge &&
          runtimeType == other.runtimeType &&
          from == other.from &&
          to == other.to &&
          type == other.type &&
          fromVariable == other.fromVariable &&
          toVariable == other.toVariable;

  @override
  int get hashCode =>
      from.hashCode ^
      to.hashCode ^
      type.hashCode ^
      fromVariable.hashCode ^
      toVariable.hashCode;
}

/// Represents a complete path match result with both nodes and edges.
class PathMatch {
  /// Map of variable names to node IDs (same format as matchRows)
  final Map<String, String> nodes;

  /// Ordered list of edges in the path
  final List<PathEdge> edges;

  const PathMatch({required this.nodes, required this.edges});

  @override
  String toString() => 'PathMatch(nodes: $nodes, edges: $edges)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PathMatch &&
          runtimeType == other.runtimeType &&
          _mapEquals(nodes, other.nodes) &&
          _listEquals(edges, other.edges);

  @override
  int get hashCode => nodes.hashCode ^ edges.hashCode;

  bool _mapEquals<K, V>(Map<K, V> a, Map<K, V> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (final key in a.keys) {
      if (!b.containsKey(key) || a[key] != b[key]) return false;
    }
    return true;
  }

  bool _listEquals<T>(List<T> a, List<T> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// Grammar definition for Cypher-like patterns
class CypherPatternGrammar extends GrammarDefinition {
  Parser start() => ref0(pattern).end();

  Parser pattern() => ref0(segment) & (ref0(connection) & ref0(segment)).star();

  Parser segment() => ref0(variable) & ref0(nodeType).optional() & ref0(labelFilter).optional();

  Parser variable() => letter() & (letter() | digit() | char('_')).star();

  Parser nodeType() => char(':') & ref0(variable);

  Parser labelFilter() =>
    char('{') &
    string('label') &
    (char('=') | char('~')) &
    ref0(labelValue) &
    char('}');

  Parser labelValue() =>
    (letter() | digit() | char('_') | char(' ')).plus();

  Parser connection() => ref0(forwardArrow) | ref0(backwardArrow);

  Parser forwardArrow() => (string('->') | (char('-') & ref0(edgeType) & string('->')));

  Parser backwardArrow() => string('<-') & ref0(edgeType).optional() & char('-');

  Parser edgeType() => char('[') & char(':') & ref0(variable) & char(']');
}

/// PetitParser-based pattern query implementation
class PetitPatternQuery<N extends Node> {
  final Graph<N> graph;
  late final Parser _parser;

  PetitPatternQuery(this.graph) {
    final definition = CypherPatternGrammar();
    _parser = definition.build();
  }

  // Stub implementations for now - we'll build these incrementally
  Map<String, Set<String>> match(String pattern, {String? startId}) {
    final result = _parser.parse(pattern);
    if (result is Failure) {
      throw FormatException('Parse error: ${result.message}');
    }

    // TODO: Convert parse tree to query execution
    throw UnimplementedError('Parse tree interpretation coming soon');
  }

  List<Map<String, String>> matchRows(String pattern, {String? startId}) {
    // TODO: Implement with petitparser
    throw UnimplementedError('PetitParser implementation coming soon');
  }

  List<PathMatch> matchPaths(String pattern, {String? startId}) {
    // TODO: Implement with petitparser
    throw UnimplementedError('PetitParser implementation coming soon');
  }

  // All other methods would be implemented similarly...
}