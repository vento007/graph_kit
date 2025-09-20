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
- A minimal, Cypher-inspired pattern engine for traversal
- **Complete path results** with Neo4j-style edge information
- **Graph algorithms** for analysis (shortest path, connected components, topological sort, reachability)

## Table of Contents

- [1. Quick Preview](#1-quick-preview)
- [2. Complete Usage Examples](#2-complete-usage-examples)
- [3. Graph Algorithms](#3-graph-algorithms)
- [4. Generic Traversal Utilities](#4-generic-traversal-utilities)
- [5. Pattern Query Examples](#5-pattern-query-examples)
- [6. Mini-Cypher Reference](#6-mini-cypher-reference)
- [7. Comparison with Cypher](#7-comparison-with-cypher)
- [8. Design and performance](#8-design-and-performance)
- [9. JSON Serialization](#9-json-serialization)
- [10. Examples index](#10-examples-index)
- [License](#license)


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

```dart
// What does Alice work on? query.match with startId returns Map<String, Set<String>>
final aliceWork = query.match(
  'person-[:WORKS_FOR]->team-[:ASSIGNED_TO]->project',
  startId: 'alice'
);
print(aliceWork); // {person: {alice}, team: {engineering}, project: {web_app, mobile_app}}

// What does Charlie manage? query.match with startId returns Map<String, Set<String>>
final charlieManages = query.match(
  'person-[:MANAGES]->team',
  startId: 'charlie'
);
print(charlieManages); // {person: {charlie}, team: {engineering, design, marketing}}

// Who works on the web app project? query.match with startId returns Map<String, Set<String>>
final webAppTeam = query.match(
  'project<-[:ASSIGNED_TO]-team<-[:WORKS_FOR]-person',
  startId: 'web_app'
);
print(webAppTeam); // {project: {web_app}, team: {engineering}, person: {alice, bob}}
```

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
], startId: 'alice');
print(aliceConnections); // {person: {alice}, team: {engineering}, project: {web_app}}

// Combine multiple relationship types, query.matchMany returns Map<String, Set<String>>
final allConnections = query.matchMany([
  'person:Person-[:WORKS_FOR]->team:Team',
  'person:Person-[:MANAGES]->team:Team',
  'person:Person-[:LEADS]->project:Project'
]);
print(allConnections); // {person: {alice, bob, charlie}, team: {engineering, design, marketing}, project: {web_app}}
```

### 2.8 Utility Methods

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

### 2.9 Summary of Query Methods

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

## 6. Mini-Cypher Reference

GraphKit uses a simplified version of **Cypher** - the query language used by Neo4j (the most popular graph database). Think of it like SQL for graphs.

### What is Cypher?

Cypher is a language designed to describe patterns in graphs. Instead of writing complex code to traverse relationships, you draw the path with text:

- **SQL**: `SELECT * FROM users WHERE department = 'engineering'`
- **Cypher**: `person:Person-[:WORKS_FOR]->team:Team{label=Engineering}`

### What is "Mini-Cypher"?

GraphKit supports a **subset** of Cypher - the most useful parts without the complexity:

**Supported**: Basic patterns, node types, relationships, label filters
**Not supported**: Complex WHERE clauses, variable-length paths, aggregations

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
query.match('project<-[:ASSIGNED_TO]-team', startId: 'web_app')
// Returns: {project: {web_app}, team: {engineering}}

// Filter: Find specific person
query.match('person:Person{label~Alice}')
// Returns: {person: {alice}}
```

**Remember:** The names you pick (`person`, `team`, etc.) become the keys in your results!

## 7. Comparison with Cypher

| Feature               | Real Cypher | graph_kit           |
|-----------------------|-------------|---------------------|
| Mixed directions      | Yes         | No                  |
| Variable length paths | Yes         | No                  |
| Optional matches      | Yes         | Via `matchMany`     |
| WHERE clauses         | Yes         | Via label filters   |

## 8. Design and performance

- Traversal from a known ID (`startId`) is fast:
  - Each hop uses adjacency maps; cost is proportional to the edges visited.
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
final members = query.match('team<-[:MEMBER_OF]-user', startId: 'team1');
print(members['user']); // {alice}
```

## 10. Examples index

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
flutter run
# Features:
# - Visual graph with nodes and edges
# - Live pattern query execution
# - Path highlighting and visualization
# - Example queries with one-click execution
```

## License

See `LICENSE`.