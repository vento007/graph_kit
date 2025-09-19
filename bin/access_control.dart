import 'package:graph_kit/graph_kit.dart';

void main() {
  print('🔐 ACCESS CONTROL SYSTEM EXAMPLE');
  print('================================\n');

  final graph = Graph<Node>();
  final query = PatternQuery(graph);

  // Build the access control graph
  print('📋 Building access control graph...\n');

  // Users
  graph.addNode(Node(id: 'alice', type: 'User', label: 'Alice Smith'));
  graph.addNode(Node(id: 'bob', type: 'User', label: 'Bob Jones'));
  graph.addNode(Node(id: 'charlie', type: 'User', label: 'Charlie Brown'));

  // Groups
  graph.addNode(Node(id: 'admins', type: 'Group', label: 'Administrators'));
  graph.addNode(Node(id: 'editors', type: 'Group', label: 'Content Editors'));
  graph.addNode(Node(id: 'viewers', type: 'Group', label: 'Read Only Users'));

  // Resources
  graph.addNode(
    Node(id: 'prod_db', type: 'Resource', label: 'Production Database'),
  );
  graph.addNode(Node(id: 'logs', type: 'Resource', label: 'System Logs'));
  graph.addNode(Node(id: 'docs', type: 'Resource', label: 'Documentation'));
  graph.addNode(
    Node(id: 'reports', type: 'Resource', label: 'Analytics Reports'),
  );

  // User memberships
  graph.addEdge('alice', 'MEMBER_OF', 'admins');
  graph.addEdge('bob', 'MEMBER_OF', 'editors');
  graph.addEdge('charlie', 'MEMBER_OF', 'viewers');
  graph.addEdge('bob', 'MEMBER_OF', 'viewers'); // Bob is both editor and viewer

  // Group permissions
  graph.addEdge('admins', 'CAN_ACCESS', 'prod_db');
  graph.addEdge('admins', 'CAN_ACCESS', 'logs');
  graph.addEdge('admins', 'CAN_ACCESS', 'docs');
  graph.addEdge('admins', 'CAN_ACCESS', 'reports');

  graph.addEdge('editors', 'CAN_ACCESS', 'docs');
  graph.addEdge('editors', 'CAN_ACCESS', 'reports');

  graph.addEdge('viewers', 'CAN_ACCESS', 'docs');

  // Query examples
  print('🔍 QUERY EXAMPLES');
  print('==================\n');

  // 1. What can Alice access?
  print('1️⃣  What resources can Alice access?');
  final aliceAccess = query.match(
    'user-[:MEMBER_OF]->group-[:CAN_ACCESS]->resource',
    startId: 'alice',
  );
  _printResourceAccess('Alice', aliceAccess['resource'] ?? {}, graph);

  // 2. What can Bob access? (He's in multiple groups)
  print('2️⃣  What resources can Bob access?');
  final bobAccess = query.match(
    'user-[:MEMBER_OF]->group-[:CAN_ACCESS]->resource',
    startId: 'bob',
  );
  _printResourceAccess('Bob', bobAccess['resource'] ?? {}, graph);

  // 3. Who can access the production database?
  print('3️⃣  Who can access the Production Database?');
  final dbUsers = query.match(
    'resource<-[:CAN_ACCESS]-group<-[:MEMBER_OF]-user',
    startId: 'prod_db',
  );
  _printUserAccess('Production Database', dbUsers['user'] ?? {}, graph);

  // 4. Show complete access matrix
  print('4️⃣  Complete Access Matrix:');
  print('   User      | Resources');
  print('   ----------|----------------------------------');

  final allUsers = query.findByType('User');
  for (final userId in allUsers) {
    final userNode = graph.nodesById[userId];
    final userAccess = query.match(
      'user-[:MEMBER_OF]->group-[:CAN_ACCESS]->resource',
      startId: userId,
    );
    final resources = userAccess['resource'] ?? <String>{};
    final resourceNames = resources
        .map((id) => graph.nodesById[id]?.label ?? id)
        .join(', ');
    final userName = (userNode?.label ?? userId).padRight(9);
    print('   $userName | $resourceNames');
  }

  // 5. Find all administrators
  print('\n5️⃣  All users in the Administrators group:');
  final adminUsers = query.match('group-[:MEMBER_OF]<-user', startId: 'admins');
  for (final userId in adminUsers['user'] ?? <String>{}) {
    final user = graph.nodesById[userId];
    print('   • ${user?.label} (${user?.id})');
  }

  // 6. Resources accessible by any editor
  print('\n6️⃣  Resources accessible by Content Editors:');
  final editorResources = query.match(
    'group-[:CAN_ACCESS]->resource',
    startId: 'editors',
  );
  for (final resourceId in editorResources['resource'] ?? <String>{}) {
    final resource = graph.nodesById[resourceId];
    print('   • ${resource?.label}');
  }
}

void _printResourceAccess(
  String userName,
  Set<String> resourceIds,
  Graph<Node> graph,
) {
  if (resourceIds.isEmpty) {
    print('   $userName has no resource access\n');
    return;
  }

  print('   $userName can access:');
  for (final resourceId in resourceIds) {
    final resource = graph.nodesById[resourceId];
    print('   • ${resource?.label} ($resourceId)');
  }
  print('');
}

void _printUserAccess(
  String resourceName,
  Set<String> userIds,
  Graph<Node> graph,
) {
  if (userIds.isEmpty) {
    print('   No users can access $resourceName\n');
    return;
  }

  print('   Users who can access $resourceName:');
  for (final userId in userIds) {
    final user = graph.nodesById[userId];
    print('   • ${user?.label} ($userId)');
  }
  print('');
}
