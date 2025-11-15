/// Represents a directed, typed edge in the graph with optional properties.
class Edge {
  /// Source node ID of this edge.
  final String src;

  /// Relationship type/label (e.g., 'MEMBER_OF').
  final String type;

  /// Destination node ID of this edge.
  final String dst;

  /// Optional metadata stored on the relationship.
  final Map<String, dynamic>? properties;

  /// Creates a new edge. Properties are stored as an unmodifiable map.
  Edge({
    required this.src,
    required this.type,
    required this.dst,
    Map<String, dynamic>? properties,
  }) : properties = _sanitizeProperties(properties);

  /// Returns a new instance with updated [properties].
  Edge copyWith({Map<String, dynamic>? properties}) {
    return Edge(
      src: src,
      type: type,
      dst: dst,
      properties: properties ?? this.properties,
    );
  }

  /// Convert edge to JSON map (used by serialization helpers).
  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{'src': src, 'type': type, 'dst': dst};

    if (properties != null && properties!.isNotEmpty) {
      json['properties'] = properties;
    }

    return json;
  }

  /// Create edge from JSON.
  factory Edge.fromJson(Map<String, dynamic> json) {
    return Edge(
      src: json['src'] as String,
      type: json['type'] as String,
      dst: json['dst'] as String,
      properties: json['properties'] as Map<String, dynamic>?,
    );
  }

  @override
  String toString() => 'Edge($src -[:$type]-> $dst, props: $properties)';

  static Map<String, dynamic>? _sanitizeProperties(
    Map<String, dynamic>? source,
  ) {
    if (source == null) return null;
    if (source.isEmpty) {
      return const <String, dynamic>{};
    }
    return Map<String, dynamic>.unmodifiable(Map<String, dynamic>.from(source));
  }
}
