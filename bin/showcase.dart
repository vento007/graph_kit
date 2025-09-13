import 'package:graph_kit/graph_kit.dart';  

// Define types at top level
class EdgeTypes {
  static const memberOf = EdgeType('MEMBER_OF');
  static const canAccess = EdgeType('CAN_ACCESS');
  static const hasSkill = EdgeType('HAS_SKILL');
}

class NodeTypes {
  static const user = NodeType('User');
  static const group = NodeType('Group');
  static const resource = NodeType('Resource');
}

/// Comprehensive showcase of the graph_traverse package capabilities
void main(List<String> args) {
  print('🌟 GRAPH TRAVERSE PACKAGE SHOWCASE');
  print('==================================\n');

  if (args.isNotEmpty) {
    final demo = args[0].toLowerCase();
    switch (demo) {
      case 'basic':
        _demoBasicOperations();
        break;
      case 'patterns':
        _demoPatternQueries();
        break;
      case 'rows':
        _demoRowResults();
        break;
      case 'traversal':
        _demoSubgraphTraversal();
        break;
      case 'typed':
        _demoTypedOperations();
        break;
      default:
        print('❌ Unknown demo: $demo');
        _showUsage();
    }
  } else {
    print('🎯 Running all demos...\n');
    _demoBasicOperations();
    _demoPatternQueries();
    _demoRowResults();
    _demoSubgraphTraversal();
    _demoTypedOperations();
  }
}

void _showUsage() {
  print('Usage: dart run bin/showcase.dart [demo_name]');
  print('');
  print('Available demos:');
  print('  basic     - Basic graph operations');
  print('  patterns  - Pattern query examples');
  print('  rows      - Row-wise query results');
  print('  traversal - Subgraph traversal');
  print('  typed     - Type-safe operations');
  print('  (no args) - Run all demos');
}

void _demoBasicOperations() {
  print('📦 BASIC GRAPH OPERATIONS');
  print('=========================\n');

  final graph = Graph<Node>();
  
  print('1️⃣  Creating nodes and edges:');
  // Add nodes
  graph.addNode(Node(id: 'user1', type: 'User', label: 'Alice'));
  graph.addNode(Node(id: 'group1', type: 'Group', label: 'Developers'));
  graph.addNode(Node(id: 'resource1', type: 'Resource', label: 'Database'));
  
  // Add edges
  graph.addEdge('user1', 'MEMBER_OF', 'group1');
  graph.addEdge('group1', 'CAN_ACCESS', 'resource1');
  
  print('   ✓ Added 3 nodes and 2 edges');
  print('   ✓ Graph has ${graph.nodesById.length} nodes');
  print('');

  print('2️⃣  Basic lookups:');
  final user = graph.nodesById['user1'];
  print('   • User: ${user?.label} (type: ${user?.type})');
  
  final userGroups = graph.outNeighbors('user1', 'MEMBER_OF');
  print('   • User groups: $userGroups');
  
  final hasAccess = graph.hasEdge('group1', 'CAN_ACCESS', 'resource1');
  print('   • Group can access resource: $hasAccess');
  print('');

  print('3️⃣  Adjacency exploration:');
  print('   • Outgoing from user1: ${graph.out['user1']}');
  print('   • Incoming to group1: ${graph.inn['group1']}');
  print('');
  
  _separator();
}

void _demoPatternQueries() {
  print('🔍 PATTERN QUERY EXAMPLES');
  print('=========================\n');

  final graph = _buildExampleGraph();
  final query = PatternQuery(graph);

  print('1️⃣  Simple pattern matching:');
  final users = query.match('user:User');
  print('   Pattern: "user:User"');
  print('   Found users: ${users['user']}');
  print('');

  print('2️⃣  Traversal patterns:');
  final userAccess = query.match(
    'user-[:MEMBER_OF]->group-[:CAN_ACCESS]->resource',
    startId: 'alice'
  );
  print('   Pattern: "user-[:MEMBER_OF]->group-[:CAN_ACCESS]->resource"');
  print('   Starting from: alice');
  print('   Alice can access: ${userAccess['resource']}');
  print('');

  print('3️⃣  Multiple pattern matching:');
  final aliceNetwork = query.matchMany([
    'user-[:MEMBER_OF]->group',
    'user-[:HAS_SKILL]->skill',
    'user-[:WORKS_IN]->location',
  ], startId: 'alice');
  
  print('   Multiple patterns from alice:');
  for (final entry in aliceNetwork.entries) {
    if (entry.value.isNotEmpty) {
      print('   • ${entry.key}: ${entry.value}');
    }
  }
  print('');

  print('4️⃣  Backward traversal:');
  final resourceUsers = query.match(
    'resource<-[:CAN_ACCESS]-group<-[:MEMBER_OF]-user',
    startId: 'database'
  );
  print('   Pattern: "resource<-[:CAN_ACCESS]-group<-[:MEMBER_OF]-user"');
  print('   Users who can access database: ${resourceUsers['user']}');
  print('');

  print('5️⃣  Label filtering:');
  final adminUsers = query.match('user:User{label~Admin}');
  print('   Pattern: "user:User{label~Admin}" (contains "Admin")');
  print('   Admin users: ${adminUsers['user']}');
  print('');

  _separator();
}

void _demoRowResults() {
  print('📋 ROW-WISE QUERY RESULTS');
  print('=========================\n');

  final graph = _buildExampleGraph();
  final query = PatternQuery(graph);

  print('1️⃣  Row results vs grouped results:');
  
  // Grouped results
  final grouped = query.match(
    'user-[:MEMBER_OF]->group-[:CAN_ACCESS]->resource'
  );
  print('   Grouped results:');
  for (final entry in grouped.entries) {
    print('   • ${entry.key}: ${entry.value}');
  }
  print('');

  // Row results
  final rows = query.matchRows(
    'user-[:MEMBER_OF]->group-[:CAN_ACCESS]->resource'
  );
  print('   Row results (showing relationships):');
  for (final row in rows) {
    final user = graph.nodesById[row['user']]?.label;
    final group = graph.nodesById[row['group']]?.label;
    final resource = graph.nodesById[row['resource']]?.label;
    print('   • $user → $group → $resource');
  }
  print('');

  print('2️⃣  Building mappings from rows:');
  final userToResources = <String, Set<String>>{};
  for (final row in rows) {
    final user = row['user']!;
    final resource = row['resource']!;
    userToResources.putIfAbsent(user, () => {}).add(resource);
  }
  
  print('   User → Resources mapping:');
  for (final entry in userToResources.entries) {
    final userName = graph.nodesById[entry.key]?.label;
    final resourceNames = entry.value
        .map((id) => graph.nodesById[id]?.label)
        .join(', ');
    print('   • $userName: $resourceNames');
  }
  print('');

  _separator();
}

void _demoSubgraphTraversal() {
  print('🗺️  SUBGRAPH TRAVERSAL');
  print('=====================\n');

  final graph = _buildExampleGraph();

  print('1️⃣  Forward expansion:');
  final forward = expandSubgraph(
    graph,
    seeds: {'alice'},
    edgeTypesRightward: {'MEMBER_OF', 'CAN_ACCESS', 'HAS_SKILL'},
    forwardHops: 2,
  );
  
  print('   Starting from alice, 2 hops forward:');
  print('   • Nodes found: ${forward.nodes.length}');
  print('   • Edges traversed: ${forward.edges.length}');
  print('   • Forward distances: ${forward.forwardDist}');
  print('');

  print('2️⃣  Bidirectional expansion:');
  final bidirectional = expandSubgraph(
    graph,
    seeds: {'developers'},
    edgeTypesRightward: {'CAN_ACCESS'},
    edgeTypesLeftward: {'MEMBER_OF'},
    forwardHops: 1,
    backwardHops: 1,
  );
  
  print('   Starting from developers group:');
  print('   • Total nodes: ${bidirectional.nodes.length}');
  print('   • Forward reach: ${bidirectional.forwardDist}');
  print('   • Backward reach: ${bidirectional.backwardDist}');
  print('');

  print('3️⃣  Edge analysis:');
  print('   Edges in subgraph:');
  for (final edge in forward.edges) {
    final src = graph.nodesById[edge.src]?.label ?? edge.src;
    final dst = graph.nodesById[edge.dst]?.label ?? edge.dst;
    print('   • $src -[${edge.type}]-> $dst');
  }
  print('');

  _separator();
}

void _demoTypedOperations() {
  print('🔒 TYPE-SAFE OPERATIONS');
  print('======================\n');

  final graph = Graph<Node>();
  final query = PatternQuery(graph);

  print('1️⃣  Using typed edge operations:');
  
  // Add nodes
  graph.addNode(Node(id: 'alice', type: 'User', label: 'Alice'));
  graph.addNode(Node(id: 'devs', type: 'Group', label: 'Developers'));
  
  // Type-safe edge operations
  graph.addEdgeT('alice', EdgeTypes.memberOf, 'devs');
  
  final aliceGroups = graph.outNeighborsT('alice', EdgeTypes.memberOf);
  final hasEdge = graph.hasEdgeT('alice', EdgeTypes.memberOf, 'devs');
  
  print('   ✓ Added typed edge: alice -[MEMBER_OF]-> devs');
  print('   ✓ Alice\'s groups: $aliceGroups');
  print('   ✓ Has membership edge: $hasEdge');
  print('');

  print('2️⃣  Type-safe queries:');
  final users = query.findByTypeT(NodeTypes.user);
  print('   ✓ Found users with typed query: $users');
  
  final neighbors = query.outFromT('alice', EdgeTypes.memberOf);
  print('   ✓ Alice\'s typed neighbors: $neighbors');
  print('');

  print('3️⃣  Benefits of typed operations:');
  print('   • Compile-time safety (no string typos)');
  print('   • Better IDE support (autocomplete)');
  print('   • Refactoring friendly');
  print('   • Still works in pattern strings:');
  print('     Pattern: "user-[:${EdgeTypes.memberOf}]->group"');
  print('');

  _separator();
}

Graph<Node> _buildExampleGraph() {
  final graph = Graph<Node>();

  // Users
  graph.addNode(Node(id: 'alice', type: 'User', label: 'Alice Developer'));
  graph.addNode(Node(id: 'bob', type: 'User', label: 'Bob Admin'));
  graph.addNode(Node(id: 'charlie', type: 'User', label: 'Charlie User'));

  // Groups
  graph.addNode(Node(id: 'developers', type: 'Group', label: 'Developers'));
  graph.addNode(Node(id: 'admins', type: 'Group', label: 'Administrators'));

  // Resources
  graph.addNode(Node(id: 'database', type: 'Resource', label: 'Database'));
  graph.addNode(Node(id: 'files', type: 'Resource', label: 'File System'));

  // Skills
  graph.addNode(Node(id: 'dart', type: 'Skill', label: 'Dart Programming'));
  graph.addNode(Node(id: 'sql', type: 'Skill', label: 'SQL'));

  // Locations
  graph.addNode(Node(id: 'office', type: 'Location', label: 'Main Office'));

  // Relationships
  graph.addEdge('alice', 'MEMBER_OF', 'developers');
  graph.addEdge('bob', 'MEMBER_OF', 'admins');
  graph.addEdge('bob', 'MEMBER_OF', 'developers'); // Bob is in both groups

  graph.addEdge('developers', 'CAN_ACCESS', 'database');
  graph.addEdge('developers', 'CAN_ACCESS', 'files');
  graph.addEdge('admins', 'CAN_ACCESS', 'database');
  graph.addEdge('admins', 'CAN_ACCESS', 'files');

  graph.addEdge('alice', 'HAS_SKILL', 'dart');
  graph.addEdge('bob', 'HAS_SKILL', 'sql');

  graph.addEdge('alice', 'WORKS_IN', 'office');
  graph.addEdge('bob', 'WORKS_IN', 'office');

  return graph;
}

void _separator() {
  print('${'─' * 50}\n');
}