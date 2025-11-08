<div align="center">

<p>
  <img src="https://raw.githubusercontent.com/vento007/graph_kit/main/media/graph_kit_logo.png" alt="Graph Kit Logo" width="420" />
</p>

<h1 align="center">graph kit — lightweight typed directed multigraph + pattern queries</h1>

<p align="center"><em>In-memory, typed directed multigraph with powerful and performant Cypher-inspired pattern queries</em></p>

<p align="center">
  <a href="https://pub.dev/packages/graph_kit">
    <img src="https://img.shields.io/pub/v/graph_kit.svg" alt="Pub">
  </a>
  <a href="https://opensource.org/licenses/MIT">
    <img src="https://img.shields.io/badge/license-MIT-purple.svg" alt="License: MIT">
  </a>
  <a href="https://dart.dev/">
    <img src="https://img.shields.io/badge/dart-3.8.1%2B-blue.svg" alt="Dart Version">
  </a>
  <img src="https://img.shields.io/badge/platform-flutter%20|%20dart%20|%20web%20|%20native-blue.svg" alt="Platform Support">
  <a href="https://github.com/vento007/graph_kit/issues">
    <img src="https://img.shields.io/github/issues/vento007/graph_kit.svg" alt="Open Issues">
  </a>
  <a href="https://github.com/vento007/graph_kit/pulls">
    <img src="https://img.shields.io/github/issues-pr/vento007/graph_kit.svg" alt="Pull Requests">
  </a>
  <a href="https://github.com/vento007/graph_kit/graphs/contributors">
    <img src="https://img.shields.io/github/contributors/vento007/graph_kit.svg" alt="Contributors">
  </a>
  <img src="https://img.shields.io/github/last-commit/vento007/graph_kit.svg" alt="Last Commit">

</p>

<hr>

</div>

In-memory, typed directed multigraph with:

- **Typed nodes** (e.g., `Person`, `Team`, `Project`, `Resource`)
- **Typed edges** (e.g., `WORKS_FOR`, `MANAGES`, `ASSIGNED_TO`, `DEPENDS_ON`)
- **Multiple relationships** between the same nodes
- **Advanced Cypher queries** with WHERE clauses, RETURN projection, logical operators, variable-length paths, and edge variable comparison
- **Complete path results** with Neo4j-style edge information
- **Graph algorithms** for analysis (shortest path, connected components, topological sort, reachability)

## Table of Contents

- [1. Quick Preview](#1-quick-preview)
- [2. Complete Usage Examples](#2-complete-usage-examples)
  - [2.9 RETURN Clause - Property Projection](#29-return-clause---property-projection)
- [3. Graph Algorithms](#3-graph-algorithms)
- [4. Generic Traversal Utilities](#4-generic-traversal-utilities)
- [5. Pattern Query Examples](#5-pattern-query-examples)
- [6. Mini-Cypher Reference](#6-mini-cypher-reference)
  - [6.1 Advanced WHERE Clauses and Complex Filtering](#61-advanced-where-clauses-and-complex-filtering)
- [7. Comparison with Cypher](#7-comparison-with-cypher)
- [8. Design and performance](#8-design-and-performance)
- [9. JSON Serialization](#9-json-serialization)
- [10. Graph Layout for Visualizations](#10-graph-layout-for-visualizations)
- [11. Examples index](#11-examples-index)
- [License](#license)

---

## Complete Cypher Query Language Guide

**GraphKit supports a powerful subset of Cypher** - the query language used by Neo4j. For comprehensive documentation on all query features including advanced WHERE clauses, edge variable comparison, logical operators, and complex filtering:

### **[Read the Complete Cypher Guide](https://github.com/vento007/graph_kit/blob/main/CYPHER_GUIDE.md)**

The guide covers:
- **Edge Variable Comparison** - `WHERE type(r2) = type(r)` for multi-hop path consistency
- **Complex WHERE Clauses** - Parentheses, logical operators, property filtering
- **Variable-Length Paths** - `[:TYPE*1..3]` for flexible hop ranges
- **Multiple Edge Types** - `[:TYPE1|TYPE2]` for OR matching
- **RETURN Projection** - Property access with AS aliases
- **Real-World Examples** - HR queries, project management, organizational analysis

---

## 1. Quick Preview

<p align="center">
  <img src="https://raw.githubusercontent.com/vento007/graph_kit/main/media/screenshoot3.png" alt="Graph Kit demo preview" width="840" />
  <br/>
  <em>Interactive graph algorithms demo showing centrality analysis in the Flutter app.</em>

</p>

## 2. Complete Usage Examples

This section provides copy-paste ready examples demonstrating all major query methods with a sample graph. Each example can be run as a standalone Dart script.

### 2.1 Setup: Sample Graph

```dart
import 'package:graph_kit/graph_kit.dart';

void main() {
  // Create graph and add sample data
  final graph = Graph<Node>();

  // Add people
  graph.addNode(Node(id: 'alice', type: 'Person', label: 'Alice Cooper'));
  graph.addNode(Node(id: 'bob', type: 'Person', label: 'Bob Wilson'));
  graph.addNode(Node(id: 'charlie', type: 'Person', label: 'Charlie Davis'));

  // Add teams
  graph.addNode(Node(id: 'engineering', type: 'Team', label: 'Engineering'));
  graph.addNode(Node(id: 'design', type: 'Team', label: 'Design Team'));
  graph.addNode(Node(id: 'marketing', type: 'Team', label: 'Marketing'));

  // Add projects
  graph.addNode(Node(id: 'web_app', type: 'Project', label: 'Web Application'));
  graph.addNode(Node(id: 'mobile_app', type: 'Project', label: 'Mobile App'));
  graph.addNode(Node(id: 'campaign', type: 'Project', label: 'Ad Campaign'));

  // Add relationships
  graph.addEdge('alice', 'WORKS_FOR', 'engineering');
  graph.addEdge('bob', 'WORKS_FOR', 'engineering');
  graph.addEdge('charlie', 'MANAGES', 'engineering');
  graph.addEdge('charlie', 'MANAGES', 'design');
  graph.addEdge('charlie', 'MANAGES', 'marketing');
  graph.addEdge('engineering', 'ASSIGNED_TO', 'web_app');
  graph.addEdge('engineering', 'ASSIGNED_TO', 'mobile_app');
  graph.addEdge('design', 'ASSIGNED_TO', 'mobile_app');
  graph.addEdge('marketing', 'ASSIGNED_TO', 'campaign');
  graph.addEdge('alice', 'LEADS', 'web_app');

  final query = PatternQuery(graph);

  // Run examples below...
}
```

### 2.2 Basic Queries - Get Single Type

```dart
// Get all people, query.match returns Map<String, Set<String>>
final people = query.match('person:Person');
print(people); // {person: {alice, bob, charlie}}

// Get all teams, query.match returns Map<String, Set<String>>
final teams = query.match('team:Team');
print(teams); // {team: {engineering, design, marketing}}

// Get all projects, query.match returns Map<String, Set<String>>
final projects = query.match('project:Project');
print(projects); // {project: {web_app, mobile_app, campaign}}
```

### 2.3 Relationship Queries - Get Connected Nodes

```dart
// Find who works for teams, query.match returns Map<String, Set<String>>
final workers = query.match('person:Person-[:WORKS_FOR]->team:Team');
print(workers); // {person: {alice, bob}, team: {engineering}}

// Find who manages teams, query.match returns Map<String, Set<String>>
final managers = query.match('person:Person-[:MANAGES]->team:Team');
print(managers); // {person: {charlie}, team: {engineering, design, marketing}}

// Find team assignments to projects, query.match returns Map<String, Set<String>>
final assignments = query.match('team:Team-[:ASSIGNED_TO]->project:Project');
print(assignments); // {team: {engineering, design, marketing}, project: {web_app, mobile_app, campaign}}
```

### 2.4 Queries from Specific Starting Points

#### Multiple Starting Nodes (startIds)

Query from multiple starting nodes simultaneously. Perfect for search results or filtering by multiple IDs:

```dart
// Search returns multiple matching users - query from all of them
final searchResults = ['alice', 'bob', 'charlie'];
final projects = query.match(
  'person-[:WORKS_FOR]->team-[:ASSIGNED_TO]->project',
  startIds: searchResults
);
// Returns all projects connected to any of the matched users

// Query from multiple teams
final multiTeamView = query.match(
  'team-[:ASSIGNED_TO]->project',
  startIds: ['engineering', 'design']
);
print(multiTeamView); // {team: {engineering, design}, project: {web_app, mobile_app, landing_page}}

// Automatically deduplicates when multiple starts find the same path
final paths = query.matchPaths(
  'person-[:WORKS_FOR]->team',
  startIds: ['alice', 'bob']  // Both in same team
);
// Returns unique paths (deduplicated)
```

#### Single Starting Node (startId)

> **Note:** `startId` will be deprecated in 0.9.0 in favor of `startIds` for API consistency. Use `startIds: ['single_node']` for new code.

```dart
// What does Alice work on?
final aliceWork = query.match(
  'person-[:WORKS_FOR]->team-[:ASSIGNED_TO]->project',
  startId: 'alice'  // Deprecated: use startIds: ['alice']
);
print(aliceWork); // {person: {alice}, team: {engineering}, project: {web_app, mobile_app}}

// Who works on the web app project?
final webAppTeam = query.match(
  'project<-[:ASSIGNED_TO]-team<-[:WORKS_FOR]-person',
  startId: 'web_app'  // Deprecated: use startIds: ['web_app']
);
print(webAppTeam); // {project: {web_app}, team: {engineering}, person: {alice, bob}}
```

#### Starting from Middle or Last Elements

Start parameters can match **any position** in the pattern, not just the first element:

```dart
// Start from middle element (team)
final teamConnections = query.matchPaths(
  'person-[:WORKS_FOR]->team-[:ASSIGNED_TO]->project',
  startIds: ['engineering']  // team is in the middle!
);
// Returns paths where 'team' variable = 'engineering'

// Start from last element (project)
final projectPaths = query.matchPaths(
  'person-[:WORKS_FOR]->team-[:ASSIGNED_TO]->project',
  startIds: ['web_app']  // project is last!
);
// Returns paths where 'project' variable = 'web_app'

// Multiple middle starts
final middleChain = query.matchPaths(
  'a->b->c->d->e',
  startIds: ['node_c', 'node_d']  // Start from multiple middle elements
);
```

#### Performance Optimization with startType

When starting from middle/last elements, use `startType` to skip unnecessary position checks:

```dart
// Without startType: checks all 3 positions (person, team, project)
final paths = query.matchPaths(
  'person-[:WORKS_FOR]->team-[:ASSIGNED_TO]->project',
  startIds: ['engineering']
);

// With startType: ONLY checks 'team' position (faster!)
final paths = query.matchPaths(
  'person-[:WORKS_FOR]->team-[:ASSIGNED_TO]->project',
  startIds: ['engineering'],
  startType: 'Team'  // Optimization hint
);
```

**When to use `startType`:**
- Starting from middle or last positions
- Large patterns (4+ elements)
- Performance-critical queries
- You know the node type of your starting nodes

### 2.5 Row-wise Results - Preserve Path Relationships

```dart
// Get specific person-team-project combinations, query.matchRows returns List<Map<String, String>>
final rows = query.matchRows('person-[:WORKS_FOR]->team-[:ASSIGNED_TO]->project');
print(rows);
// [
//   {person: alice, team: engineering, project: web_app},
//   {person: alice, team: engineering, project: mobile_app},
//   {person: bob, team: engineering, project: web_app},
//   {person: bob, team: engineering, project: mobile_app}
// ]

// Access individual path data
print(rows.first); // {person: alice, team: engineering, project: web_app}
print(rows.first['person']); // alice
print(rows.first['team']); // engineering
```

### 2.6 Complete Path Results with Edge Information

```dart
// Get complete path information, query.matchPaths returns List<PathMatch>
final paths = query.matchPaths('person-[:WORKS_FOR]->team-[:ASSIGNED_TO]->project');
print(paths.length); // 4

// Print all paths with edges
for (final path in paths) {
  print(path.nodes); // {person: alice, team: engineering, project: web_app}
  for (final edge in path.edges) {
    print('  ${edge.from} -[:${edge.type}]-> ${edge.to}'); // alice -[:WORKS_FOR]-> engineering
  }
}
```

### 2.7 Multiple Pattern Queries

```dart
// Get all of Alice's connections, query.matchMany returns Map<String, Set<String>>
final aliceConnections = query.matchMany([
  'person-[:WORKS_FOR]->team',
  'person-[:LEADS]->project'
], startIds: ['alice']);
print(aliceConnections); // {person: {alice}, team: {engineering}, project: {web_app}}

// Combine multiple relationship types, query.matchMany returns Map<String, Set<String>>
final allConnections = query.matchMany([
  'person:Person-[:WORKS_FOR]->team:Team',
  'person:Person-[:MANAGES]->team:Team',
  'person:Person-[:LEADS]->project:Project'
]);
print(allConnections); // {person: {alice, bob, charlie}, team: {engineering, design, marketing}, project: {web_app}}
```

### 2.8 WHERE Clause Filtering

```dart
// Add people with properties for filtering examples
graph.addNode(Node(
  id: 'alice',
  type: 'Person',
  label: 'Alice Cooper',
  properties: {'age': 28, 'department': 'Engineering', 'salary': 85000}
));
graph.addNode(Node(
  id: 'bob',
  type: 'Person',
  label: 'Bob Wilson',
  properties: {'age': 35, 'department': 'Engineering', 'salary': 95000}
));

// Filter by age - query.matchRows returns List<Map<String, String>>
final seniors = query.matchRows('MATCH person:Person WHERE person.age > 30');
print(seniors); // [{person: bob}]

// Filter by department - query.matchRows returns List<Map<String, String>>
final engineers = query.matchRows('MATCH person:Person WHERE person.department = "Engineering"');
print(engineers); // [{person: alice}, {person: bob}]

// Combine conditions with AND - query.matchRows returns List<Map<String, String>>
final seniorEngineers = query.matchRows('MATCH person:Person WHERE person.age > 30 AND person.department = "Engineering"');
print(seniorEngineers); // [{person: bob}]

// Use OR conditions - query.matchRows returns List<Map<String, String>>
final youngOrWellPaid = query.matchRows('MATCH person:Person WHERE person.age < 30 OR person.salary > 90000');
print(youngOrWellPaid); // [{person: alice}, {person: bob}]

// Complex filtering with relationships - query.matchRows returns List<Map<String, String>>
final seniorWorkers = query.matchRows('MATCH person:Person-[:WORKS_FOR]->team:Team WHERE person.age > 30');
print(seniorWorkers); // [{person: bob, team: engineering}]

// Edge variable comparison for multi-hop path consistency
// Add nodes with edge type prefixes
graph.addNode(Node(id: 'hub', type: 'Hub', label: 'Hub1'));
graph.addNode(Node(id: 'dest1', type: 'Dest', label: 'Dest1'));
graph.addNode(Node(id: 'dest2', type: 'Dest', label: 'Dest2'));
graph.addEdge('alice', 'ROUTE_alice', 'hub');
graph.addEdge('hub', 'ROUTE_alice', 'dest1'); // Same type as alice's edge
graph.addEdge('hub', 'ROUTE_bob', 'dest2');   // Different type

// Enforce same edge type across both hops - query.match returns Map<String, Set<String>>
final consistentPaths = query.match(
  'person-[r]->hub-[r2]->dest WHERE type(r) STARTS WITH "ROUTE_" AND type(r2) = type(r)'
);
print(consistentPaths); // {person: {alice}, hub: {hub}, dest: {dest1}}
// Only dest1 is returned because its edge type (ROUTE_alice) matches alice's edge type

// Find paths with DIFFERENT edge types - query.match returns Map<String, Set<String>>
final mixedPaths = query.match(
  'person-[r]->hub-[r2]->dest WHERE type(r2) != type(r)'
);
print(mixedPaths); // {person: {alice}, hub: {hub}, dest: {dest2}}
```

### 2.9 RETURN Clause - Property Projection

The RETURN clause lets you project specific variables and properties, creating clean, production-ready result sets instead of raw node IDs.

**Why use RETURN?**
- **Clean data**: Get only what you need (no extra lookups)
- **Custom names**: Use AS aliases for readable column names
- **Type-safe patterns**: Combine with Dart 3 destructuring
- **Performance**: Reduces data transfer and processing

#### Basic RETURN - Variable Projection

```dart
// Without RETURN: Get node IDs (requires separate lookups)
final rawResults = query.matchRows('MATCH person:Person-[:WORKS_FOR]->team:Team');
print(rawResults); // [{person: alice, team: engineering}, ...]

// With RETURN: Get only what you need
final results = query.matchRows('MATCH person:Person-[:WORKS_FOR]->team:Team RETURN person, team');
print(results); // [{person: alice, team: engineering}, ...]
// Same format, but explicitly controlled
```

#### Property Access - Get Actual Data

```dart
// RETURN properties directly from nodes
final employeeData = query.matchRows(
  'MATCH person:Person-[:WORKS_FOR]->team:Team RETURN person.name, person.salary, team.name'
);
print(employeeData);
// [
//   {'person.name': 'Alice Cooper', 'person.salary': 85000, 'team.name': 'Engineering'},
//   {'person.name': 'Bob Wilson', 'person.salary': 95000, 'team.name': 'Engineering'}
// ]

// Access values
print(employeeData.first['person.name']); // Alice Cooper
print(employeeData.first['person.salary']); // 85000
```

#### AS Aliases - Custom Column Names

```dart
// Use AS to create readable column names
final cleanResults = query.matchRows(
  'MATCH person:Person-[:WORKS_FOR]->team:Team '
  'RETURN person.name AS employee, person.salary AS pay, team.name AS department'
);
print(cleanResults);
// [
//   {employee: 'Alice Cooper', pay: 85000, department: 'Engineering'},
//   {employee: 'Bob Wilson', pay: 95000, department: 'Engineering'}
// ]

// Much cleaner access!
print(cleanResults.first['employee']); // Alice Cooper
print(cleanResults.first['department']); // Engineering
```

#### Destructuring - Type-Safe Access (Dart 3)

Use Dart's pattern matching to destructure results type-safely:

```dart
// Destructure in a loop
final results = query.matchRows(
  'MATCH person:Person WHERE person.salary > 90000 '
  'RETURN person.name AS name, person.salary AS salary, person.department AS dept'
);

for (var {'name': employeeName, 'salary': pay, 'dept': department} in results) {
  print('$employeeName earns \$$pay in $department');
}
// Output:
// Bob Wilson earns $95000 in Engineering
```

Shorter syntax for single result:

```dart
final topEarner = query.matchRows(
  'MATCH person:Person RETURN person.name AS name, person.salary AS salary'
).first;

var {'name': name, 'salary': salary} = topEarner;
print('$name: \$$salary'); // Uses destructured variables directly
```

#### Combining WHERE + RETURN

```dart
// Filter with WHERE, then project with RETURN
final seniorEngineers = query.matchRows(
  'MATCH person:Person-[:WORKS_FOR]->team:Team '
  'WHERE person.age > 30 AND team.name = "Engineering" '
  'RETURN person.name AS engineer, person.age AS yearsOld, team.name AS teamName'
);

for (var {'engineer': name, 'yearsOld': age} in seniorEngineers) {
  print('$name ($age years old)');
}
```

#### Real-World Example - Employee Directory

```dart
// Complete employee report query
final report = query.matchRows(
  'MATCH person:Person-[:WORKS_FOR]->team:Team-[:WORKS_ON]->project:Project '
  'WHERE person.salary >= 85000 '
  'RETURN person.name AS employee, '
  '       person.role AS title, '
  '       person.salary AS compensation, '
  '       team.name AS department, '
  '       project.name AS currentProject'
);

// Use destructuring for clean output
for (var {
  'employee': name,
  'title': role,
  'compensation': salary,
  'department': dept,
  'currentProject': project
} in report) {
  print('$name ($role) - $dept - \$$salary - Working on: $project');
}
// Output:
// Alice Cooper (Senior Engineer) - Engineering - $85000 - Working on: Web Application
// Bob Wilson (Staff Engineer) - Engineering - $95000 - Working on: Mobile App
```

#### RETURN vs Raw IDs - Quick Comparison

| Approach | Result Format | Use Case |
|----------|---------------|----------|
| **No RETURN** | Node IDs only | When you need to hydrate objects elsewhere |
| **RETURN variables** | `{person: 'alice', team: 'engineering'}` | ID-based hydration pattern |
| **RETURN properties** | `{'person.name': 'Alice', 'team.name': 'Engineering'}` | Direct property access |
| **RETURN with AS** | `{employee: 'Alice', dept: 'Engineering'}` | Clean, production-ready data |

**Try the interactive demo:**
```bash
cd example
flutter run
# Select "RETURN Clause Projection" to see live examples
```

### 2.10 Utility Methods

```dart
// Find by type, query.findByType returns Set<String>
final allPeople = query.findByType('Person');
print(allPeople); // {alice, bob, charlie}

// Find by exact label, query.findByLabelEquals returns Set<String>
final aliceIds = query.findByLabelEquals('Alice Cooper');
print(aliceIds); // {alice}

// Find by label substring, query.findByLabelContains returns Set<String>
final bobUsers = query.findByLabelContains('bob');
print(bobUsers); // {bob}

// Direct edge traversal, query.outFrom returns Set<String>
final aliceTeams = query.outFrom('alice', 'WORKS_FOR');
print(aliceTeams); // {engineering}

// Reverse edge traversal, query.inTo returns Set<String>
final engineeringWorkers = query.inTo('engineering', 'WORKS_FOR');
print(engineeringWorkers); // {alice, bob}
```

### 2.11 Summary of Query Methods

| Method | Returns | Use Case |
|--------|---------|----------|
| `match()` | `Map<String, Set<String>>` | Get grouped node IDs by variable |
| `matchMany()` | `Map<String, Set<String>>` | Combine multiple patterns |
| `matchRows()` | `List<Map<String, String>>` | Preserve path relationships |
| `matchPaths()` | `List<PathMatch>` | Complete path + edge information |
| `findByType()` | `Set<String>` | All nodes of specific type |
| `findByLabelEquals()` | `Set<String>` | Nodes by exact label match |
| `findByLabelContains()` | `Set<String>` | Nodes by label substring |
| `outFrom()`/`inTo()` | `Set<String>` | Direct edge traversal |

## 3. Graph Algorithms

Graph Kit includes efficient implementations of common graph algorithms for analysis and pathfinding:

### Available Algorithms

- **Shortest Path** - Find optimal routes between nodes using BFS (counts hops)
- **Path Enumeration** - Find all possible routes between nodes within hop limits
- **Connected Components** - Identify groups of interconnected nodes
- **Reachability Analysis** - Discover all nodes reachable from a starting point
- **Topological Sort** - Order nodes by dependencies (useful for build systems, task scheduling)
- **Centrality Analysis** - Identify important nodes (betweenness and closeness centrality)

<p align="center">
  <img src="https://raw.githubusercontent.com/vento007/graph_kit/main/media/shortest_path.png" alt="Shortest path algorithm visualization" width="600" />
  <br/>
  <em>Shortest path visualization highlighting the optimal route between selected nodes.</em>
</p>

### Quick Example

```dart
import 'package:graph_kit/graph_kit.dart';

// Create a dependency graph
final graph = Graph<Node>();
graph.addNode(Node(id: 'core', type: 'Package', label: 'Core'));
graph.addNode(Node(id: 'utils', type: 'Package', label: 'Utils'));
graph.addNode(Node(id: 'app', type: 'Package', label: 'App'));

// Add dependencies (app depends on utils, utils depends on core)
graph.addEdge('utils', 'DEPENDS_ON', 'core');
graph.addEdge('app', 'DEPENDS_ON', 'utils');

// Use graph algorithms
final algorithms = GraphAlgorithms(graph);

// Find shortest path (counts hops)
final path = algorithms.shortestPath('app', 'core');
print('Path: ${path.path}'); // [app, utils, core]
print('Distance: ${path.distance}'); // 2

// Find all possible paths
final allPaths = enumeratePaths(graph, 'app', 'core', maxHops: 4);
print('Routes: ${allPaths.paths.length}'); // All alternative routes

// Get build order (topological sort)
final buildOrder = algorithms.topologicalSort();
print('Build order: $buildOrder'); // [core, utils, app]

// Find connected components
final components = algorithms.connectedComponents();
print('Components: $components'); // [{core, utils, app}]

// Check reachability
final reachable = algorithms.reachableFrom('app');
print('App can reach: $reachable'); // {app, utils, core}

// Check what can reach a target
final reachableBy = algorithms.reachableBy('core');
print('Can reach core: $reachableBy'); // {app, utils, core}

// Check all connected nodes (bidirectional)
final reachableAll = algorithms.reachableAll('utils');
print('Connected to utils: $reachableAll'); // {app, utils, core}

// Find critical bridge nodes
final betweenness = algorithms.betweennessCentrality();
print('Bridge nodes: ${betweenness.entries.where((e) => e.value > 0.3).map((e) => e.key)}');

// Find communication hubs
final closeness = algorithms.closenessCentrality();
print('Most central: ${closeness.entries.reduce((a, b) => a.value > b.value ? a : b).key}');
```


### Visual Demo

Run the interactive Flutter demo to see graph algorithms in action:

```bash
cd example
flutter run
```

- Switch to **"Graph Algorithms"** tab
- Click nodes to see shortest paths
- View connected components with color coding
- See topological sort with dependency levels
- Explore reachability analysis

### Command Line Demo

For a focused algorithms demonstration:

```bash
dart run bin/algorithms_demo.dart
```

This shows practical examples of:
- Package dependency analysis
- Build order optimization
- Component isolation detection
- Shortest path finding

## 4. Generic Traversal Utilities

For BFS-style subgraph exploration around nodes within hop limits. Unlike pattern queries that follow specific paths, this explores neighborhoods in all directions using specified edge types.

```dart
// Using the same graph setup from section 2...
// Add this to your existing code:

// Explore everything within 2 hops from Alice, expandSubgraph returns SubgraphResult
final aliceSubgraph = expandSubgraph(
  graph,
  seeds: {'alice'},
  edgeTypesRightward: {'WORKS_FOR', 'MANAGES', 'ASSIGNED_TO', 'LEADS'},
  forwardHops: 2,
  backwardHops: 0,
);
print(aliceSubgraph.nodes); // {alice, engineering, web_app, mobile_app}
print(aliceSubgraph.edges.length); // 4

// Explore everything connected to engineering team, expandSubgraph returns SubgraphResult
final engineeringSubgraph = expandSubgraph(
  graph,
  seeds: {'engineering'},
  edgeTypesRightward: {'ASSIGNED_TO'},
  edgeTypesLeftward: {'WORKS_FOR', 'MANAGES'},
  forwardHops: 1,
  backwardHops: 1,
);
print(engineeringSubgraph.nodes); // {engineering, web_app, mobile_app, alice, bob, charlie}
print(engineeringSubgraph.edges.length); // 5

// Find everyone within 2 hops of projects, expandSubgraph returns SubgraphResult
final projectEcosystem = expandSubgraph(
  graph,
  seeds: {'web_app', 'mobile_app', 'campaign'},
  edgeTypesRightward: {'WORKS_FOR', 'MANAGES'},
  edgeTypesLeftward: {'ASSIGNED_TO', 'LEADS'},
  forwardHops: 0,
  backwardHops: 2,
);
print(projectEcosystem.nodes); // {web_app, mobile_app, campaign, engineering, alice, design, marketing}
print(projectEcosystem.edges.length); // 7
```

### When to use vs Pattern Queries

| Use Case | Pattern Queries | expandSubgraph |
|----------|----------------|----------------|
| **Specific paths** | `person-[:WORKS_FOR]->team-[:ASSIGNED_TO]->project` | No |
| **Neighborhood exploration** | No | Yes - "Everything around Alice" |
| **Impact analysis** | No | Yes - "What's affected by this change?" |
| **Subgraph extraction** | No | Yes - For visualization/analysis |
| **Known relationships** | Yes - Clear path patterns | No |
| **Unknown structure** | No | Yes - Explore what's connected |

## 5. Pattern Query Examples

- **Simple patterns**: `"user:User"` → `{alice, bob, charlie}`
- **Forward patterns**: `"user-[:MEMBER_OF]->group"`
- **Backward patterns**: `"resource<-[:CAN_ACCESS]-group<-[:MEMBER_OF]-user"` → `{alice, bob}`
- **Label filtering**: `"user:User{label~Admin}"` → `{bob}`
- **Multiple edge types**: `"person-[:WORKS_FOR|VOLUNTEERS_AT]->org"` → matches ANY of the specified relationship types
- **Mixed directions**: `"person1-[:WORKS_FOR]->team<-[:MANAGES]-manager"` → finds common connections and shared relationships
- **Variable-length paths**: `"manager-[:MANAGES*1..3]->subordinate"` → finds direct and indirect reports

## 6. Mini-Cypher Reference

GraphKit uses a simplified version of **Cypher** - the query language used by Neo4j (the most popular graph database). Think of it like SQL for graphs.

### What is Cypher?

Cypher is a language designed to describe patterns in graphs. Instead of writing complex code to traverse relationships, you draw the path with text:

- **SQL**: `SELECT * FROM users WHERE department = 'engineering'`
- **Cypher**: `person:Person-[:WORKS_FOR]->team:Team{label=Engineering}`

### What is "Mini-Cypher"?

GraphKit supports a **subset** of Cypher - the most useful parts without the complexity:

**Supported**: Basic patterns, node types, relationships, label filters, variable-length paths, WHERE clauses with logical operators, parentheses, CONTAINS operator for substring matching
**Not supported**: Aggregations, complex subqueries

This gives you the power of graph queries without learning the full Cypher language.

### How to Build Pattern Queries

Think of pattern queries like giving directions. Instead of "turn left at the store", you're saying "follow this relationship to that type of thing".

### Step 1: Start with What You Want to Find

When you want to find all people in your company, you write:
```dart
query.match('person:Person')
```

This breaks down into:
- **`person`** = What you want to call them in your results (like a nickname)
- **`:`** = "that are of type"
- **`Person`** = The actual type of thing you're looking for

Think of it like: "Find me all things of type Person, and I'll call them 'person' in my results"

### Step 2: Connect Things with Arrows

Now say you want to know "who works where". You connect person to team:
```dart
query.match('person:Person-[:WORKS_FOR]->team:Team')
```

Reading left to right:
- **`person:Person`** = "Start with a person"
- **`-[`** = "who has a connection"
- **`:WORKS_FOR`** = "of type WORKS_FOR"
- **`]->`** = "that points to"
- **`team:Team`** = "a team"

Like saying: "Show me people who have a WORKS_FOR arrow pointing to teams"

### Step 3: The Arrow Direction Matters!

**Right arrow `->` means "going out from":**
```dart
person-[:WORKS_FOR]->team    // Person points to team (person works FOR the team)
```

**Left arrow `<-` means "coming in to":**
```dart
team<-[:WORKS_FOR]-person    // Person points to team (team is worked for BY person)
```

Same relationship, different starting point!

### Step 4: Chain Multiple Steps

Want to follow a longer path? Just keep adding arrows:
```dart
person-[:WORKS_FOR]->team-[:ASSIGNED_TO]->project
```

This means:
1. Start with a person
2. Follow their WORKS_FOR connection to a team
3. Follow that team's ASSIGNED_TO connection to a project

Like following a trail: person → team → project

### Step 5: Filter by Name

Want to find a specific person? Add their name in curly braces:
```dart
person:Person{label=Alice Cooper}     // Find exactly "Alice Cooper"
person:Person{label~alice}            // Find anyone with "alice" in their name
```

The `~` means "contains" (like a fuzzy search)

### Quick Examples to Try

```dart
// Simple: Find all people
query.match('person:Person')
// Returns: {person: {alice, bob, charlie}}

// Connection: Who works where?
query.match('person-[:WORKS_FOR]->team')
// Returns: {person: {alice, bob}, team: {engineering}}

// Chain: Follow a path through the graph
query.match('person-[:WORKS_FOR]->team-[:ASSIGNED_TO]->project')
// Returns: {person: {alice, bob}, team: {engineering}, project: {web_app, mobile_app}}

// Backwards: What teams work on this project?
query.match('project<-[:ASSIGNED_TO]-team', startIds: ['web_app'])
// Returns: {project: {web_app}, team: {engineering}}

// Filter: Find specific person
query.match('person:Person{label~Alice}')
// Returns: {person: {alice}}
```

**Remember:** The names you pick (`person`, `team`, etc.) become the keys in your results!

### Variable-Length Paths

Variable-length paths let you find connections across multiple hops without specifying the exact number of steps:

```dart
// Use the unified PatternQuery (includes all advanced features)
final query = PatternQuery(graph);

// Find all direct and indirect reports (1-3 management levels)
query.match('manager-[:MANAGES*1..3]->subordinate')

// Find anyone at least 2 levels down the hierarchy
query.match('manager-[:MANAGES*2..]->subordinate')

// Find dependencies up to 4 steps away
query.match('component-[:DEPENDS_ON*..4]->dependency')

// Find all reachable dependencies (unlimited hops)
query.match('component-[:DEPENDS_ON*]->dependency')
```

**Variable-length syntax:**
- `[:TYPE*]` - Unlimited hops
- `[:TYPE*1..3]` - Between 1 and 3 hops
- `[:TYPE*2..]` - 2 or more hops
- `[:TYPE*..4]` - Up to 4 hops
- `[:TYPE*2]` - Exactly 2 hops

**Note:** Variable-length paths are fully supported in the unified `PatternQuery` implementation.

### 6.1 Advanced WHERE Clauses and Complex Filtering

For sophisticated filtering beyond basic patterns, GraphKit supports full WHERE clause syntax with logical operators and parentheses.

**[Complete Cypher Query Language Guide](https://github.com/vento007/graph_kit/blob/main/CYPHER_GUIDE.md)**

The comprehensive guide covers:
- Complex logical expressions with parentheses: `(A AND B) OR (C AND D)`
- Multiple comparison operators: `>`, `<`, `>=`, `<=`, `=`, `!=`
- Real-world query examples for HR, project management, and organizational analysis
- Property filtering best practices and performance tips
- Error handling and troubleshooting

Quick examples:
```cypher
// Complex filtering with parentheses
MATCH person:Person WHERE (person.age > 40 AND person.salary > 100000) OR person.department = "Management"

// Multi-hop with filtering
MATCH person:Person-[:WORKS_FOR]->team:Team-[:WORKS_ON]->project:Project WHERE person.salary > 80000 AND project.status = "active"
```

**Try the Interactive WHERE Demo:**
```bash
cd example
flutter run -t lib/where_demo.dart
```
The demo includes sample queries, real-time query execution, and a comprehensive dataset for testing complex WHERE clauses.

## 7. Comparison with Cypher

| Feature               | Real Cypher | graph_kit           |
|-----------------------|-------------|---------------------|
| Mixed directions      | Yes         | Yes                 |
| Variable length paths | Yes         | Yes                 |
| Multiple edge types   | `[:TYPE1\|TYPE2]` | Yes                 |
| Multiple patterns     | `pattern1, pattern2` | No                  |
| Optional matches      | Yes         | Via `matchMany`     |
| WHERE clauses         | Yes         | Yes                 |
| Logical operators     | Yes         | Yes (AND, OR)       |
| Parentheses           | Yes         | Yes                 |

## 8. Design and performance

- Traversal from known IDs (`startIds`) is fast:
  - Each hop uses adjacency maps; cost is proportional to the edges visited.
  - Multiple start points are processed independently and deduplicated.
- Seeding by type (`alias:Type`) does a one-time node scan to find initial seeds.
  - For small/medium graphs, this is effectively instant; indexing can be added later if needed.
- `matchMany([...])` mirrors "multiple MATCH/OPTIONAL MATCH" lines in Cypher by running several independent chains from the same start and unioning results.

## 9. JSON Serialization

Save and load graphs to/from JSON for persistence and data exchange:

```dart
import 'dart:io';
import 'package:graph_kit/graph_kit.dart';

// Build your graph
final graph = Graph<Node>();
graph.addNode(Node(id: 'alice', type: 'User', label: 'Alice',
  properties: {'email': 'alice@example.com', 'active': true}));
graph.addNode(Node(id: 'team1', type: 'Team', label: 'Engineering'));
graph.addEdge('alice', 'MEMBER_OF', 'team1');

// Serialize to JSON
final json = graph.toJson();
final jsonString = graph.toJsonString(pretty: true);

// Save to file
await File('graph.json').writeAsString(jsonString);

// Load from file
final loadedJson = await File('graph.json').readAsString();
final restoredGraph = GraphSerializer.fromJsonString(loadedJson, Node.fromJson);

// Graph is fully restored - queries work immediately
final query = PatternQuery(restoredGraph);
final members = query.match('team<-[:MEMBER_OF]-user', startIds: ['team1']);
print(members['user']); // {alice}
```

## 10. Graph Layout for Visualizations

Automatically compute layer/column positions for graph visualizations, eliminating brittle hardcoded positioning logic.

### The Problem

Hardcoding column positions breaks when graph structure changes:

```dart
// BAD: Hardcoded switch statement - breaks when patterns change
final column = switch (nodeType) {
  'Group' => 0,
  'Policy' => 1,
  'Asset' => 2,
  'Virtual' => 3,
  _ => 0,
};
```

### The Solution: GraphLayout

```dart
final paths = query.matchPaths('group->policy->asset->virtual');
final layout = paths.computeLayout();

// Column positions computed automatically!
final groupColumn = layout.variableLayer('group');      // 0
final policyColumn = layout.variableLayer('policy');    // 1
final assetColumn = layout.variableLayer('asset');      // 2
final virtualColumn = layout.variableLayer('virtual');  // 3
```

### Key Features

**Automatic positioning**: Computes layer/column for every node based on graph structure

**Two positioning modes**:
- `nodeDepths` - Exact structural position for each node ID
- `variableDepths` - Typical position for grouping by variable name (uses median to handle outliers)

**Handles edge cases gracefully**:
- Orphan nodes (disconnected from roots)
- Cycles
- Multiple disconnected components
- Nodes reachable via multiple paths

### Basic Usage

```dart
// Get path results
final paths = query.matchPaths('group-[:HAS_POLICY]->policy-[:GRANTS_ACCESS]->asset');
final layout = paths.computeLayout();

// Get column for pattern variables
final policyColumn = layout.variableLayer('policy');

// Get column for specific node ID
final nodeColumn = layout.layerFor('node_123');

// Render by column
for (var layer = 0; layer <= layout.maxDepth; layer++) {
  final nodesInColumn = layout.nodesInLayer(layer);
  renderColumn(layer, nodesInColumn);
}
```

### Layout Strategies

Two strategies available (default: `longestPath`):

```dart
// Pattern order (fast, predictable - follows query left-to-right)
final layout = paths.computeLayout(strategy: LayerStrategy.pattern);

// Longest path (best for complex graphs with diamonds, minimizes crossings)
final layout = paths.computeLayout(strategy: LayerStrategy.longestPath);
```

### GraphLayout Properties

```dart
layout.maxDepth           // Number of layers - 1
layout.roots              // Root nodes (layer 0 entry points)
layout.allNodes           // All unique node IDs in paths
layout.allEdges           // All unique edges in paths
layout.nodeDepths         // Map<String, int> of node ID → layer
layout.variableDepths     // Map<String, int> of variable → typical layer
layout.nodesByLayer       // Map<int, Set<String>> of layer → node IDs
```

### Complete Example

See `bin/layout_demo.dart` for a comprehensive before/after comparison showing how GraphLayout eliminates hardcoded positioning.

**Why use GraphLayout?**
- ✓ No hardcoded column positions
- ✓ Automatically adapts to graph structure changes
- ✓ Handles orphan nodes, cycles, disconnected components
- ✓ Works with any pattern, any node types
- ✓ Both structural and grouped positioning available

## 11. Examples index

### Dart CLI Examples
- `bin/showcase.dart` – comprehensive graph demo with multiple query examples
- `bin/access_control.dart` – access control patterns with users, groups, and resources
- `bin/project_dependencies.dart` – project dependency analysis and traversal
- `bin/social_network.dart` – social network relationships and friend recommendations
- `bin/serialization_demo.dart` – JSON serialization and persistence
- `bin/algorithms_demo.dart` – graph algorithms demonstration with dependency analysis

Run any example:
```bash
dart run bin/showcase.dart
dart run bin/access_control.dart
```

### Flutter Example App
Interactive graph visualization with pattern queries:

```bash
cd example

# Main demo - visual graph with pattern queries
flutter run

# WHERE clause demo - interactive Cypher query testing
flutter run -t lib/where_demo.dart

# RETURN clause demo - property projection and destructuring
flutter run -t lib/return_demo.dart

# Features:
# - Visual graph with nodes and edges
# - Live pattern query execution
# - WHERE clause testing with sample data
# - RETURN clause with before/after comparison
# - Destructuring examples
# - Path highlighting and visualization
# - Example queries with one-click execution
```

## License

See `LICENSE`.