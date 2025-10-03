# Type Safety Analysis for graph_kit

## Executive Summary

**Current State**: graph_kit uses a **hybrid typing approach** - generic node types (`Graph<N extends Node>`) with string-based properties (`Map<String, dynamic>`).

**Key Finding**: The package **should NOT** fully align with traditional OOP class hierarchies. Graph databases fundamentally differ from OOP - they prioritize flexible, runtime-queryable relationships over compile-time type hierarchies.

**Recommendation**: Implement a **progressive typing strategy** that offers multiple levels of type safety while preserving the package's core flexibility and query power.

---

## 1. Current Typing Architecture

### What's Already Typed ✅
```dart
// 1. Generic node types
Graph<N extends Node>              // ✅ Type-safe at graph level
PatternQuery<N extends Node>       // ✅ Generic-aware queries

// 2. Type-safe wrappers for constants
EdgeType('WORKS_FOR')              // ✅ Prevents string typos
NodeType('Person')                 // ✅ Type-safe node types

// 3. Typed extensions
graph.addEdgeT(src, EdgeTypes.memberOf, dst)  // ✅ IDE autocomplete
query.findByTypeT(NodeTypes.user)             // ✅ Compile-time safety
```

### What's Untyped ❌
```dart
// 1. Node properties - CORE ISSUE
properties: Map<String, dynamic>?  // ❌ No type safety
node.properties?['age']            // ❌ Runtime-only validation
node.properties?['salary']         // ❌ Typos caught at runtime

// 2. Query results
Map<String, Set<String>>           // ❌ Just IDs, no type info
List<Map<String, String>>          // ❌ String dictionaries

// 3. Property access in WHERE clauses
WHERE person.age > 30              // ❌ No compile-time validation
WHERE person.sallary > 50000       // ❌ Typo goes undetected
```

---

## 2. The Fundamental Question: Should Graphs Be OOP?

### Why Graph Databases ≠ OOP

**Graph Database Philosophy:**
- **Schema flexibility**: Add properties without migration
- **Dynamic relationships**: Edges created at runtime
- **Query-driven**: Structure emerges from queries, not classes
- **Polyglot data**: Same node can have different property sets

**OOP Philosophy:**
- **Compile-time contracts**: Strict interfaces
- **Class hierarchies**: IS-A relationships
- **Method behavior**: Objects know how to manipulate themselves
- **Homogeneous**: All instances of a class have same structure

**The Mismatch:**
```dart
// OOP approach - rigid
class Person {
  final String id;
  final int age;
  final double salary;
  Person(this.id, this.age, this.salary);
}

// What happens when you need to add properties?
class Person {
  final String id;
  final int age;
  final double salary;
  final String? department;  // ❌ Migration required
  final bool? isContractor;  // ❌ Breaks existing code
}

// Graph approach - flexible
Node(
  id: 'person1',
  properties: {'age': 30, 'salary': 85000}  // ✅ Extensible
)
// Later: Just add properties as needed
Node(
  id: 'person2', 
  properties: {'age': 28, 'salary': 90000, 'department': 'Engineering'}  // ✅ No migration
)
```

### When OOP Makes Sense in Graphs

**Yes, use OOP for:**
1. **Domain-specific node types** (custom `Node` subclasses)
2. **Type-safe constants** (`EdgeType`, `NodeType` wrappers)
3. **Query builders** (fluent APIs for pattern construction)
4. **Result transformers** (map node data to domain objects)

**No, DON'T use OOP for:**
1. **Property schemas** (kills flexibility)
2. **Relationship modeling** (edges are data, not methods)
3. **Query patterns** (Cypher is declarative, not imperative)

---

## 3. Typing Strategies: Progressive Approaches

### Strategy 1: **Status Quo Plus** (Minimal Changes)
*Add opt-in type safety without breaking flexibility*

```dart
// Add property schema validation (optional)
class PropertySchema {
  final Map<String, Type> required;
  final Map<String, Type> optional;
  
  const PropertySchema({this.required = const {}, this.optional = const {}});
  
  bool validate(Map<String, dynamic> properties) {
    // Runtime validation
    for (final entry in required.entries) {
      if (!properties.containsKey(entry.key)) return false;
      if (properties[entry.key].runtimeType != entry.value) return false;
    }
    return true;
  }
}

// Use in node types
class PersonNode extends Node {
  static final schema = PropertySchema(
    required: {'age': int, 'salary': double},
    optional: {'department': String, 'isActive': bool},
  );
  
  PersonNode({
    required super.id,
    required super.label,
    required super.properties,
  }) : super(type: 'Person') {
    if (!schema.validate(properties ?? {})) {
      throw ArgumentError('Invalid properties for PersonNode');
    }
  }
  
  // Type-safe getters (opt-in)
  int get age => properties!['age'] as int;
  double get salary => properties!['salary'] as double;
  String? get department => properties?['department'] as String?;
}

// Usage - BACKWARD COMPATIBLE
final graph = Graph<Node>();

// Old way still works
graph.addNode(Node(
  id: 'alice',
  type: 'Person',
  label: 'Alice',
  properties: {'age': 30, 'salary': 85000}  // ✅ Still flexible
));

// New way - type-safe if you want it
graph.addNode(PersonNode(
  id: 'bob',
  label: 'Bob',
  properties: {'age': 28, 'salary': 90000, 'department': 'Engineering'}
));

final bob = graph.nodesById['bob'] as PersonNode;
print(bob.age);  // ✅ Type-safe access
```

**Pros:**
- ✅ Backward compatible
- ✅ Opt-in type safety
- ✅ No performance overhead if not used

**Cons:**
- ❌ Boilerplate for each node type
- ❌ Query results still untyped
- ❌ Runtime validation only

---

### Strategy 2: **Typed Properties with Code Generation**
*Use Dart's code generation for zero-boilerplate type safety*

```dart
// Define schema with annotations
@NodeSchema('Person')
class PersonSchema {
  final int age;
  final double salary;
  final String department;
  final bool? isActive;  // nullable = optional
  
  const PersonSchema({
    required this.age,
    required this.salary,
    required this.department,
    this.isActive,
  });
}

// Code generator produces:
class PersonNode extends Node {
  PersonNode({
    required super.id,
    required super.label,
    required int age,
    required double salary,
    required String department,
    bool? isActive,
  }) : super(
    type: 'Person',
    properties: {
      'age': age,
      'salary': salary,
      'department': department,
      if (isActive != null) 'isActive': isActive,
    },
  );
  
  // Generated type-safe getters
  int get age => properties!['age'] as int;
  double get salary => properties!['salary'] as double;
  String get department => properties!['department'] as String;
  bool? get isActive => properties?['isActive'] as bool?;
  
  // Generated factory from properties
  factory PersonNode.fromProperties(String id, String label, Map<String, dynamic> props) {
    return PersonNode(
      id: id,
      label: label,
      age: props['age'] as int,
      salary: props['salary'] as double,
      department: props['department'] as String,
      isActive: props['isActive'] as bool?,
    );
  }
}

// Usage - clean and type-safe
graph.addNode(PersonNode(
  id: 'alice',
  label: 'Alice Cooper',
  age: 35,
  salary: 120000,
  department: 'Engineering',
));

final alice = graph.nodesById['alice'] as PersonNode;
print(alice.salary);  // ✅ Fully typed
```

**Pros:**
- ✅ Zero boilerplate (generated)
- ✅ Full IDE support
- ✅ Compile-time validation

**Cons:**
- ❌ Adds build complexity
- ❌ Still doesn't solve query results
- ❌ Less flexible for ad-hoc properties

---

### Strategy 3: **Typed Query Results with Mappers**
*Transform query results into typed domain objects*

```dart
// Result mapper abstraction
abstract class ResultMapper<T> {
  T fromNode(Node node);
  List<T> fromNodeSet(Set<String> nodeIds, Graph graph);
}

class PersonMapper implements ResultMapper<PersonData> {
  @override
  PersonData fromNode(Node node) {
    return PersonData(
      id: node.id,
      label: node.label,
      age: node.properties?['age'] as int? ?? 0,
      salary: node.properties?['salary'] as double? ?? 0,
      department: node.properties?['department'] as String?,
    );
  }
  
  @override
  List<PersonData> fromNodeSet(Set<String> nodeIds, Graph graph) {
    return nodeIds
        .map((id) => graph.nodesById[id])
        .whereType<Node>()
        .map(fromNode)
        .toList();
  }
}

// Typed query extensions
extension TypedQuery<N extends Node> on PatternQuery<N> {
  List<T> matchTyped<T>(
    String pattern, 
    String variable,
    ResultMapper<T> mapper,
    {String? startId}
  ) {
    final results = match(pattern, startId: startId);
    final nodeIds = results[variable] ?? {};
    return mapper.fromNodeSet(nodeIds, graph);
  }
}

// Usage - type-safe results
final query = PatternQuery(graph);
final seniors = query.matchTyped(
  'MATCH person:Person WHERE person.age > 30',
  'person',
  PersonMapper(),
);

// Now you have typed results!
for (final person in seniors) {
  print('${person.label}: \$${person.salary}');  // ✅ Full type safety
}
```

**Pros:**
- ✅ Type-safe results
- ✅ Separation of concerns
- ✅ Flexible mapping logic

**Cons:**
- ❌ Boilerplate for each type
- ❌ Doesn't help with property access in graph

---

### Strategy 4: **Phantom Types for Compile-Time Guarantees**
*Use Dart's type system for compile-time property validation*

```dart
// Property type tags
class PropertyKey<T> {
  final String name;
  const PropertyKey(this.name);
}

// Define property keys with types
class PersonProps {
  static const age = PropertyKey<int>('age');
  static const salary = PropertyKey<double>('salary');
  static const department = PropertyKey<String>('department');
  static const isActive = PropertyKey<bool>('isActive');
}

// Typed property access
extension TypedProperties on Node {
  T? get<T>(PropertyKey<T> key) {
    return properties?[key.name] as T?;
  }
  
  T getOrElse<T>(PropertyKey<T> key, T defaultValue) {
    return get(key) ?? defaultValue;
  }
}

// Usage - compile-time type checking
final person = graph.nodesById['alice']!;

// ✅ Type-safe: returns int?
final age = person.get(PersonProps.age);

// ✅ Type-safe: returns double
final salary = person.getOrElse(PersonProps.salary, 0.0);

// ❌ Compile error: type mismatch
// final wrong = person.get(PersonProps.age) as String;  // Won't compile!

// ✅ Autocomplete works
person.get(PersonProps.  // IDE shows: age, salary, department, isActive
```

**Pros:**
- ✅ Compile-time type safety
- ✅ Minimal boilerplate
- ✅ IDE autocomplete
- ✅ No runtime overhead

**Cons:**
- ❌ Doesn't prevent missing properties
- ❌ Still need to define keys for each domain

---

### Strategy 5: **Full OOP (NOT RECOMMENDED)**
*Traditional class hierarchy approach*

```dart
// ❌ This is what you SHOULDN'T do

abstract class GraphEntity {
  String get id;
  String get type;
  String get label;
}

class Person extends GraphEntity {
  @override
  final String id;
  @override
  String get type => 'Person';
  @override
  final String label;
  
  final int age;
  final double salary;
  final String department;
  
  Person(this.id, this.label, this.age, this.salary, this.department);
}

class Team extends GraphEntity {
  @override
  final String id;
  @override
  String get type => 'Team';
  @override
  final String label;
  
  final double budget;
  final int headcount;
  
  Team(this.id, this.label, this.budget, this.headcount);
}

// Now you need separate graphs or lose type safety
final personGraph = Graph<Person>();  // ❌ Can only store Person
final teamGraph = Graph<Team>();      // ❌ Can only store Team

// ❌ Can't model relationships between different types!
```

**Why This Fails:**
1. ❌ **Cross-type relationships impossible**: Can't have Person→Team edges in typed graph
2. ❌ **Schema rigidity**: Adding properties requires code changes
3. ❌ **Query complexity**: Pattern queries work on heterogeneous graphs
4. ❌ **Serialization nightmare**: Need custom serializer per type
5. ❌ **Loses graph database advantages**: Basically back to SQL JOIN hell

---

## 4. Recommended Approach: Hybrid Strategy

### **Best Practice: Combine Strategies 1, 3, and 4**

```dart
// 1. Keep Node flexible (base case)
class Node {
  final String id;
  final String type;
  final String label;
  final Map<String, dynamic>? properties;
  // ... existing implementation
}

// 2. Add PropertyKey pattern (Strategy 4)
class PropertyKey<T> {
  final String name;
  const PropertyKey(this.name);
}

extension TypedProperties on Node {
  T? get<T>(PropertyKey<T> key) => properties?[key.name] as T?;
  T getOrElse<T>(PropertyKey<T> key, T defaultValue) => get(key) ?? defaultValue;
}

// 3. Domain-specific node types (Strategy 1 - opt-in)
class PersonNode extends Node {
  // Define property keys
  static const age = PropertyKey<int>('age');
  static const salary = PropertyKey<double>('salary');
  static const department = PropertyKey<String>('department');
  
  PersonNode({
    required super.id,
    required super.label,
    required super.properties,
  }) : super(type: 'Person');
  
  // Type-safe getters using PropertyKey
  int get age => getOrElse(PersonNode.age, 0);
  double get salary => getOrElse(PersonNode.salary, 0.0);
  String? get department => get(PersonNode.department);
}

// 4. Result mappers for complex queries (Strategy 3)
class PersonResult {
  final String id;
  final String label;
  final int age;
  final double salary;
  final String? department;
  
  PersonResult.fromNode(Node node)
    : id = node.id,
      label = node.label,
      age = node.get(PersonNode.age) ?? 0,
      salary = node.get(PersonNode.salary) ?? 0.0,
      department = node.get(PersonNode.department);
}

extension TypedQueryResults<N extends Node> on PatternQuery<N> {
  List<T> matchMapped<T>(
    String pattern,
    String variable,
    T Function(Node) mapper,
    {String? startId}
  ) {
    final results = match(pattern, startId: startId);
    return (results[variable] ?? {})
        .map((id) => graph.nodesById[id])
        .whereType<Node>()
        .map(mapper)
        .toList();
  }
}

// Usage Examples:

// Basic usage - still flexible
graph.addNode(Node(
  id: 'alice',
  type: 'Person',
  label: 'Alice',
  properties: {'age': 35, 'salary': 120000, 'department': 'Engineering'}
));

// Type-safe access when needed
final alice = graph.nodesById['alice']!;
final age = alice.get(PersonNode.age);  // ✅ int?
final salary = alice.getOrElse(PersonNode.salary, 0.0);  // ✅ double

// Type-safe query results
final seniors = query.matchMapped(
  'MATCH person:Person WHERE person.age > 30',
  'person',
  PersonResult.fromNode,
);

for (final person in seniors) {
  print('${person.label}: \$${person.salary}');  // ✅ Fully typed
}
```

---

## 5. Implementation Roadmap

### Phase 1: Foundation (Non-Breaking)
1. Add `PropertyKey<T>` class
2. Add `TypedProperties` extension to `Node`
3. Add examples showing typed access patterns
4. Update documentation with best practices

### Phase 2: Convenience (Additive)
1. Add `TypedQueryResults` extension to `PatternQuery`
2. Create example domain models (PersonNode, TeamNode, etc.)
3. Add result mapper helpers
4. Create migration guide

### Phase 3: Advanced (Optional)
1. Add optional code generation package (`graph_kit_codegen`)
2. Schema validation utilities
3. Type-safe query builder API
4. Advanced mapper utilities

---

## 6. Dart/Flutter Specific Considerations

### Why This Matters for Dart/Flutter

**Dart's Strengths:**
- Strong type system with generic constraints
- Extension methods (perfect for opt-in typing)
- Const constructors (zero-overhead type tags)
- Tree-shaking (unused typed features cost nothing)

**Flutter Use Cases:**
```dart
// State management - typed results prevent UI bugs
class PersonListState {
  final List<PersonResult> people;  // ✅ Type-safe
  // vs
  final List<Map<String, String>> people;  // ❌ Error-prone
}

// Widget builders - autocomplete prevents typos
Widget buildPersonCard(PersonResult person) {
  return Card(
    child: Text('${person.label}: \$${person.salary}'),
    // vs accessing person['sallary'] and getting null
  );
}

// Repository pattern - typed domain layer
class PersonRepository {
  final Graph<Node> graph;
  final PatternQuery<Node> query;
  
  Future<List<PersonResult>> getSeniorEngineers() async {
    return query.matchMapped(
      'MATCH p:Person WHERE p.age > 30 AND p.department = "Engineering"',
      'p',
      PersonResult.fromNode,
    );
  }
}
```

### Performance Characteristics

**Zero-Cost Abstractions:**
```dart
// PropertyKey<T> is const - no runtime allocation
const salary = PropertyKey<double>('salary');

// Extension methods - inlined by compiler
node.get(salary);  // Compiles to: properties?['salary'] as double?

// Generic constraints - erased at runtime
Graph<PersonNode>  // Same runtime type as Graph<Node>
```

**When NOT to Use Strong Typing:**
- Ad-hoc analytics (exploratory queries)
- Schema-less data import (JSON ingestion)
- Rapid prototyping (structure not finalized)
- Generic graph algorithms (works on any node type)

---

## 7. Comparison with Other Graph Libraries

### Neo4j (Java/Cypher)
- **Approach**: Schema-optional, runtime validation
- **Properties**: `Map<String, Object>` (similar to graph_kit)
- **Type Safety**: Optional via drivers, not enforced

### JanusGraph (Java)
- **Approach**: Schema definition at graph level
- **Properties**: Typed property keys (similar to Strategy 4)
- **Type Safety**: Runtime validation against schema

### TypeDB (TypeQL)
- **Approach**: Strict schema required
- **Properties**: Fully typed attributes
- **Type Safety**: Compile-time query validation
- **Trade-off**: Less flexible, more rigid

### **graph_kit Position**: 
**Schema-optional with progressive typing** - best of both worlds for Dart/Flutter.

---

## 8. Final Recommendations

### ✅ DO THIS:

1. **Implement PropertyKey pattern** (Strategy 4)
   - Minimal changes, maximum benefit
   - Opt-in type safety
   - Great IDE support

2. **Add result mappers** (Strategy 3)
   - Type-safe query results
   - Clean separation of concerns
   - Perfect for Flutter UI layer

3. **Encourage domain-specific nodes** (Strategy 1)
   - Document the pattern
   - Provide examples
   - Keep it optional

4. **Document typing best practices**
   - When to use strong typing
   - When to stay flexible
   - Migration patterns

### ❌ DON'T DO THIS:

1. **Force full OOP hierarchy** (Strategy 5)
   - Breaks graph database paradigm
   - Loses query flexibility
   - Poor developer experience

2. **Make typing mandatory**
   - Kills ad-hoc use cases
   - Reduces package appeal
   - Migration nightmare for users

3. **Over-engineer the solution**
   - Keep it simple
   - Dart patterns, not Java patterns
   - Progressive enhancement

---

## 9. Code Example: Complete Typed Workflow

```dart
// =============================================================================
// DOMAIN LAYER - Type definitions
// =============================================================================

// Property keys for compile-time safety
class PersonProps {
  static const age = PropertyKey<int>('age');
  static const salary = PropertyKey<double>('salary');
  static const department = PropertyKey<String>('department');
  static const level = PropertyKey<String>('level');
}

class TeamProps {
  static const budget = PropertyKey<double>('budget');
  static const headcount = PropertyKey<int>('headcount');
}

// Result types for UI layer
class PersonResult {
  final String id;
  final String label;
  final int age;
  final double salary;
  final String? department;
  
  PersonResult.fromNode(Node node)
    : id = node.id,
      label = node.label,
      age = node.getOrElse(PersonProps.age, 0),
      salary = node.getOrElse(PersonProps.salary, 0.0),
      department = node.get(PersonProps.department);
}

// =============================================================================
// DATA LAYER - Graph operations
// =============================================================================

class OrganizationGraph {
  final graph = Graph<Node>();
  late final query = PatternQuery(graph);
  
  void addPerson({
    required String id,
    required String label,
    required int age,
    required double salary,
    String? department,
  }) {
    graph.addNode(Node(
      id: id,
      type: 'Person',
      label: label,
      properties: {
        PersonProps.age.name: age,
        PersonProps.salary.name: salary,
        if (department != null) PersonProps.department.name: department,
      },
    ));
  }
  
  List<PersonResult> findSeniorEngineers() {
    return query.matchMapped(
      'MATCH p:Person WHERE p.age > 30 AND p.department = "Engineering"',
      'p',
      PersonResult.fromNode,
    );
  }
}

// =============================================================================
// UI LAYER - Flutter widgets
// =============================================================================

class SeniorEngineersWidget extends StatelessWidget {
  final OrganizationGraph orgGraph;
  
  @override
  Widget build(BuildContext context) {
    final seniors = orgGraph.findSeniorEngineers();
    
    return ListView.builder(
      itemCount: seniors.length,
      itemBuilder: (context, index) {
        final person = seniors[index];  // ✅ Fully typed!
        return ListTile(
          title: Text(person.label),
          subtitle: Text('Age: ${person.age}, Salary: \$${person.salary}'),
          // ✅ No runtime errors, full autocomplete
        );
      },
    );
  }
}
```

---

## 10. Conclusion

**Should graph_kit be more typed?** 

**Yes, but carefully.**

The package should:
1. ✅ Remain schema-optional (core strength)
2. ✅ Add opt-in type safety features (PropertyKey pattern)
3. ✅ Provide typed result transformations (mappers)
4. ✅ Encourage domain-specific node types (examples + docs)
5. ❌ NOT force OOP class hierarchies
6. ❌ NOT require schema definitions
7. ❌ NOT break existing flexibility

**The sweet spot**: Progressive type safety that lets developers choose their level of strictness based on use case.

**Implementation Priority**:
1. **High**: PropertyKey pattern + TypedProperties extension
2. **High**: Result mapper utilities + examples
3. **Medium**: Documentation + best practices guide
4. **Low**: Code generation (optional separate package)

This approach respects both graph database philosophy AND Dart/Flutter best practices.
