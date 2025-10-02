/// Data models for Cypher query results and specifications.
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

/// Represents variable-length relationship specifications.
class VariableLengthSpec {
  /// Minimum number of hops (null means no minimum)
  final int? minHops;

  /// Maximum number of hops (null means no maximum)
  final int? maxHops;

  const VariableLengthSpec({this.minHops, this.maxHops});

  /// Returns true if this represents unlimited hops (*)
  bool get isUnlimited => minHops == null && maxHops == null;

  /// Returns the effective maximum hops for path enumeration
  int get effectiveMaxHops => maxHops ?? 10; // Default reasonable limit

  /// Returns the effective minimum hops
  int get effectiveMinHops => minHops ?? 1;

  @override
  String toString() {
    if (isUnlimited) return '*';
    if (minHops != null && maxHops != null) return '*$minHops..$maxHops';
    if (minHops != null) return '*$minHops..';
    if (maxHops != null) return '*..$maxHops';
    return '*';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VariableLengthSpec &&
          runtimeType == other.runtimeType &&
          minHops == other.minHops &&
          maxHops == other.maxHops;

  @override
  int get hashCode => minHops.hashCode ^ maxHops.hashCode;
}

/// Represents a single item in a RETURN clause.
class ReturnItem {
  /// Variable name (for simple returns like "RETURN person")
  final String? variable;
  
  /// Variable name for property access (for "RETURN person.name", this is "person")
  final String? propertyVariable;
  
  /// Property name for property access (for "RETURN person.name", this is "name")
  final String? propertyName;
  
  /// Optional alias (for "RETURN person AS p" or "RETURN person.name AS displayName")
  final String? alias;
  
  const ReturnItem({
    this.variable,
    this.propertyVariable,
    this.propertyName,
    this.alias,
  });
  
  /// Returns true if this is a property access (person.name)
  bool get isProperty => propertyVariable != null && propertyName != null;
  
  /// Returns the column name to use in results (alias if present, otherwise default)
  String get columnName {
    if (alias != null) return alias!;
    if (isProperty) return '$propertyVariable.$propertyName';
    return variable!;
  }
  
  /// Returns the source variable name (for looking up in row data)
  String get sourceVariable => propertyVariable ?? variable!;
  
  @override
  String toString() {
    if (isProperty) {
      return alias != null 
        ? '$propertyVariable.$propertyName AS $alias'
        : '$propertyVariable.$propertyName';
    }
    return alias != null ? '$variable AS $alias' : variable!;
  }
}