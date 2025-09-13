// edge_type.dart

/// A type-safe wrapper for edge type identifiers in graph operations.
///
/// This class provides an open-enum pattern that offers type safety while
/// remaining extensible. Unlike sealed enums, applications can define their
/// own edge types without modifying the library.
///
/// ## Benefits
/// - **Type safety**: Prevents string typos in edge type parameters
/// - **Extensible**: Applications can define custom edge types
/// - **Seamless integration**: `toString()` returns the raw string value
///
/// ## Usage
/// ```dart
/// class EdgeTypes {
///   static const memberOf = EdgeType('MEMBER_OF');
///   static const hasClient = EdgeType('HAS_CLIENT');
///   static const source = EdgeType('SOURCE');
/// }
/// 
/// // Use with typed extensions
/// graph.addEdgeT('u1', EdgeTypes.memberOf, 'g1');
/// 
/// // Still works in pattern strings
/// final pattern = 'user-[:${EdgeTypes.memberOf}]->group';
/// ```
class EdgeType {
  /// The string value of this edge type.
  final String value;

  /// Creates a new edge type with the given string [value].
  const EdgeType(this.value);

  @override
  String toString() => value;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is EdgeType && other.value == value;

  @override
  int get hashCode => value.hashCode;
}
