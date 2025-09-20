# GraphKit AI Reference

## Core Classes
```dart
final graph = Graph<Node>();
final query = PatternQuery(graph);
final algorithms = GraphAlgorithms(graph);
```

## Graph Operations
```dart
graph.addNode(Node(id: 'a', type: 'Person', label: 'Alice'));
graph.addEdge('a', 'WORKS_FOR', 'b');
```

## Pattern Queries
```dart
// Basic: node type
query.match('person:Person')

// Relationships: forward/backward arrows
query.match('person-[:WORKS_FOR]->team')
query.match('project<-[:ASSIGNED_TO]-team')

// Multi-hop chains
query.match('person-[:WORKS_FOR]->team-[:ASSIGNED_TO]->project')

// Label filters
query.match('person:Person{label=Alice}')
query.match('person:Person{label~admin}')

// From specific start
query.match('person-[:WORKS_FOR]->team', startId: 'alice')
```

## Result Types
```dart
// Grouped nodes: Map<String, Set<String>>
final nodes = query.match('person-[:WORKS_FOR]->team');

// Path rows: List<Map<String, String>>
final rows = query.matchRows('person-[:WORKS_FOR]->team');

// Complete paths: List<PathMatch>
final paths = query.matchPaths('person-[:WORKS_FOR]->team');
```

## Algorithms
```dart
// Shortest path between nodes
final path = algorithms.shortestPath('start', 'end');

// Connected components
final components = algorithms.connectedComponents();

// Reachability analysis
final reachable = algorithms.reachableFrom('node');
final reachableBy = algorithms.reachableBy('target');
final reachableAll = algorithms.reachableAll('center');

// Topological sort (dependencies)
final sorted = algorithms.topologicalSort();

// Centrality analysis
final betweenness = algorithms.betweennessCentrality();
final closeness = algorithms.closenessCentrality();
```

## Traversal Utilities
```dart
// Expand subgraph around nodes
final result = expandSubgraph(
  graph,
  seeds: {'start'},
  edgeTypesRightward: {'WORKS_FOR'},
  forwardHops: 2,
  backwardHops: 1,
);
```

## Edge Type Filtering
All algorithms support optional `edgeType` parameter:
```dart
algorithms.shortestPath('a', 'b', edgeType: 'WORKS_FOR');
algorithms.reachableFrom('a', edgeType: 'CONNECTS');
```

## Serialization
```dart
final json = graph.toJsonString();
final restored = GraphSerializer.fromJsonString(json, Node.fromJson);
```