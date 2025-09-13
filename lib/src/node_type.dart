// node_type.dart

/// A type-safe wrapper for node type identifiers in graph operations.
///
/// This class provides an open-enum pattern that offers type safety while
/// remaining extensible. Applications can define domain-specific node types
/// without modifying the core library.
///
/// ## Benefits
/// - **Type safety**: Prevents string typos in node type parameters
/// - **Extensible**: Applications can define custom node types
/// - **Seamless integration**: `toString()` returns the raw string value
///
/// ## Usage
/// ```dart
/// class NodeTypes {
///   static const user = NodeType('User');
///   static const group = NodeType('Group');
///   static const policy = NodeType('Policy');
/// }
/// 
/// // Use with typed extensions
/// final userIds = query.findByTypeT(NodeTypes.user);
/// 
/// // Still works in pattern strings
/// final pattern = '${NodeTypes.user}:User-[:MEMBER_OF]->group';
/// ```
class NodeType {
  /// The string value of this node type.
  final String value;

  /// Creates a new node type with the given string [value].
  const NodeType(this.value);

  @override
  String toString() => value;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is NodeType && other.value == value;

  @override
  int get hashCode => value.hashCode;
}
