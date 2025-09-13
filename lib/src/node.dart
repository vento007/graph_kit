/// A generic node in a graph with typed metadata.
///
/// Each node has a unique [id], a [type] for categorization,
/// a human-readable [label], and optional [properties] for additional data.
///
/// Example:
/// ```dart
/// final user = Node(
///   id: 'u1',
///   type: 'User',
///   label: 'John Doe',
///   properties: {'email': 'john@example.com'},
/// );
/// ```
///
/// Users can extend this class to create domain-specific nodes:
/// ```dart
/// class UserNode extends Node {
///   const UserNode({required super.id, required super.label})
///     : super(type: 'User');
/// }
/// ```
class Node {
  /// Unique identifier for this node.
  ///
  /// Must be unique within the graph. Used for graph operations
  /// and as keys in adjacency maps.
  final String id;

  /// The semantic type of this node (e.g., 'User', 'Group', 'Policy').
  ///
  /// Used for type-based filtering in pattern queries and traversals.
  final String type;

  /// Human-readable display name for this node.
  ///
  /// Used for label-based filtering and display purposes.
  final String label;

  /// Optional key-value properties for additional node data.
  ///
  /// Can store arbitrary metadata associated with this node.
  final Map<String, dynamic>? properties;

  /// Creates a new node with the given [id], [type], [label], and optional [properties].
  ///
  /// The [id] must be unique within the graph.
  /// The [type] and [label] are used for querying and display.
  const Node({
    required this.id,
    required this.type,
    required this.label,
    this.properties,
  });

  /// Creates a Node from JSON data
  ///
  /// Used for deserialization from JSON format
  factory Node.fromJson(Map<String, dynamic> json) {
    return Node(
      id: json['id'] as String,
      type: json['type'] as String,
      label: json['label'] as String,
      properties: json['properties'] as Map<String, dynamic>?,
    );
  }

  /// Converts this Node to JSON format
  ///
  /// Used for serialization to JSON format
  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'id': id,
      'type': type,
      'label': label,
    };

    if (properties != null && properties!.isNotEmpty) {
      json['properties'] = properties;
    }

    return json;
  }

  @override
  String toString() => 'Node(id: $id, type: $type, label: $label)';
}
