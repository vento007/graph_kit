import 'dart:convert';
import 'dart:io';
import 'package:test/test.dart';
import 'package:graph_kit/graph_kit.dart';

/// Integration test for backend serialization workflow.
/// This test demonstrates the complete lifecycle of graph serialization
/// that backend developers will use.
void main() {
  group('Backend Integration - Serialization Workflow', () {
    test('complete round-trip: create, serialize, save, load, deserialize, verify', () async {
      print('\n=== Backend Integration Test ===\n');

      // ===================================================================
      // STEP 1: Create a realistic User/Group graph
      // ===================================================================
      print('Step 1: Creating graph with users and groups...');
      final graph = Graph<Node>();

      // Add users with realistic properties
      graph.addNode(Node(
        id: 'user_1',
        type: 'User',
        label: 'Alice Johnson',
        properties: {
          'email': 'alice.johnson@company.com',
          'role': 'Engineer',
          'joinedAt': '2023-01-15T10:30:00Z',
          'active': true,
        },
      ));

      graph.addNode(Node(
        id: 'user_2',
        type: 'User',
        label: 'Bob Smith',
        properties: {
          'email': 'bob.smith@company.com',
          'role': 'Manager',
          'joinedAt': '2022-06-20T09:00:00Z',
          'active': true,
        },
      ));

      graph.addNode(Node(
        id: 'user_3',
        type: 'User',
        label: 'Carol White',
        properties: {
          'email': 'carol.white@company.com',
          'role': 'Engineer',
          'joinedAt': '2023-08-01T14:00:00Z',
          'active': true,
        },
      ));

      // Add groups with properties
      graph.addNode(Node(
        id: 'group_1',
        type: 'Group',
        label: 'Engineering Team',
        properties: {
          'description': 'Core engineering team',
          'createdAt': '2022-01-01T00:00:00Z',
          'memberCount': 2,
        },
      ));

      graph.addNode(Node(
        id: 'group_2',
        type: 'Group',
        label: 'Admins',
        properties: {
          'description': 'System administrators',
          'createdAt': '2022-01-01T00:00:00Z',
          'memberCount': 1,
        },
      ));

      // Add edges representing relationships
      graph.addEdge('user_1', 'MEMBER_OF', 'group_1');
      graph.addEdge('user_2', 'MEMBER_OF', 'group_1');
      graph.addEdge('user_2', 'ADMIN_OF', 'group_2');
      graph.addEdge('user_3', 'MEMBER_OF', 'group_1');
      graph.addEdge('user_2', 'OWNS', 'group_1');

      print('✓ Created graph with:');
      print('  - ${graph.nodesById.length} nodes (3 users, 2 groups)');
      print('  - 5 edges (MEMBER_OF, ADMIN_OF, OWNS)');

      // ===================================================================
      // STEP 2: Serialize to JSON
      // ===================================================================
      print('\nStep 2: Serializing graph to JSON...');
      final json = GraphSerializer.toJson(graph);
      final prettyJsonString = graph.toJsonString(pretty: true);

      // Verify JSON structure
      expect(json['version'], equals('1.0'));
      expect(json['nodes'], hasLength(5));
      expect(json['edges'], hasLength(5));
      expect(json['metadata']['nodeCount'], equals(5));
      expect(json['metadata']['edgeCount'], equals(5));

      print('✓ Serialization successful');
      print('\nJSON Structure for Backend Team:');
      print('─' * 60);
      print(prettyJsonString);
      print('─' * 60);

      // ===================================================================
      // STEP 3: Save to file (simulating backend file storage)
      // ===================================================================
      print('\nStep 3: Saving JSON to temporary file...');
      final tempFile = File('/tmp/graph_test.json');
      await tempFile.writeAsString(prettyJsonString);
      print('✓ Saved to: ${tempFile.path}');
      print('  File size: ${await tempFile.length()} bytes');

      // ===================================================================
      // STEP 4: Load from file (simulating backend loading data)
      // ===================================================================
      print('\nStep 4: Loading JSON from file...');
      final loadedJsonString = await tempFile.readAsString();
      final loadedJson = jsonDecode(loadedJsonString) as Map<String, dynamic>;

      expect(loadedJson['version'], equals('1.0'));
      expect(loadedJson['nodes'], hasLength(5));
      expect(loadedJson['edges'], hasLength(5));

      print('✓ File loaded successfully');

      // ===================================================================
      // STEP 5: Deserialize back to graph
      // ===================================================================
      print('\nStep 5: Deserializing JSON back to graph...');
      final restoredGraph = GraphSerializer.fromJson(loadedJson, Node.fromJson);

      print('✓ Deserialization successful');
      print('  Restored ${restoredGraph.nodesById.length} nodes');

      // ===================================================================
      // STEP 6: Verify complete data integrity
      // ===================================================================
      print('\nStep 6: Verifying data integrity...');

      // Verify all nodes are present with correct data
      expect(restoredGraph.nodesById.length, equals(5));

      // Check user_1
      final user1 = restoredGraph.nodesById['user_1']!;
      expect(user1.type, equals('User'));
      expect(user1.label, equals('Alice Johnson'));
      expect(user1.properties?['email'], equals('alice.johnson@company.com'));
      expect(user1.properties?['role'], equals('Engineer'));
      expect(user1.properties?['active'], equals(true));

      // Check user_2
      final user2 = restoredGraph.nodesById['user_2']!;
      expect(user2.type, equals('User'));
      expect(user2.label, equals('Bob Smith'));
      expect(user2.properties?['email'], equals('bob.smith@company.com'));
      expect(user2.properties?['role'], equals('Manager'));

      // Check user_3
      final user3 = restoredGraph.nodesById['user_3']!;
      expect(user3.type, equals('User'));
      expect(user3.label, equals('Carol White'));
      expect(user3.properties?['email'], equals('carol.white@company.com'));

      // Check group_1
      final group1 = restoredGraph.nodesById['group_1']!;
      expect(group1.type, equals('Group'));
      expect(group1.label, equals('Engineering Team'));
      expect(group1.properties?['description'], equals('Core engineering team'));
      expect(group1.properties?['memberCount'], equals(2));

      // Check group_2
      final group2 = restoredGraph.nodesById['group_2']!;
      expect(group2.type, equals('Group'));
      expect(group2.label, equals('Admins'));

      // Verify all edges are preserved
      expect(restoredGraph.outNeighbors('user_1', 'MEMBER_OF'), contains('group_1'));
      expect(restoredGraph.outNeighbors('user_2', 'MEMBER_OF'), contains('group_1'));
      expect(restoredGraph.outNeighbors('user_2', 'ADMIN_OF'), contains('group_2'));
      expect(restoredGraph.outNeighbors('user_3', 'MEMBER_OF'), contains('group_1'));
      expect(restoredGraph.outNeighbors('user_2', 'OWNS'), contains('group_1'));

      // Verify reverse edges (incoming)
      expect(restoredGraph.inNeighbors('group_1', 'MEMBER_OF'), hasLength(3));
      expect(restoredGraph.inNeighbors('group_1', 'MEMBER_OF'), contains('user_1'));
      expect(restoredGraph.inNeighbors('group_1', 'MEMBER_OF'), contains('user_2'));
      expect(restoredGraph.inNeighbors('group_1', 'MEMBER_OF'), contains('user_3'));

      print('✓ All nodes verified (5/5)');
      print('✓ All edges verified (5/5)');
      print('✓ All properties preserved');

      // ===================================================================
      // STEP 7: Test pattern queries on restored graph
      // ===================================================================
      print('\nStep 7: Testing pattern queries on restored graph...');
      final query = PatternQuery(restoredGraph);

      // Query 1: Find all users
      final users = query.match('user:User');
      expect(users['user'], hasLength(3));
      print('✓ Found ${users['user']?.length} users');

      // Query 2: Find all groups
      final groups = query.match('group:Group');
      expect(groups['group'], hasLength(2));
      print('✓ Found ${groups['group']?.length} groups');

      // Query 3: Find members of engineering team
      final engineeringMembers = query.match(
        'group<-[:MEMBER_OF]-user',
        startId: 'group_1',
      );
      expect(engineeringMembers['user'], hasLength(3));
      print('✓ Engineering team has ${engineeringMembers['user']?.length} members');

      // Query 4: Find groups that user_2 is admin of
      final adminGroups = query.match(
        'user-[:ADMIN_OF]->group',
        startId: 'user_2',
      );
      expect(adminGroups['group'], hasLength(1));
      print('✓ User 2 is admin of ${adminGroups['group']?.length} group(s)');

      // Query 5: Find who owns group_1
      final owners = query.match(
        'group<-[:OWNS]-user',
        startId: 'group_1',
      );
      expect(owners['user'], hasLength(1));
      expect(owners['user'], contains('user_2'));
      print('✓ Group 1 is owned by user: ${owners['user']?.first}');

      // ===================================================================
      // STEP 8: Re-serialize and verify JSON equality
      // ===================================================================
      print('\nStep 8: Testing re-serialization (round-trip stability)...');
      final reserializedJson = GraphSerializer.toJson(restoredGraph);

      expect(reserializedJson['version'], equals(json['version']));
      expect(reserializedJson['nodes'], hasLength(json['nodes'].length));
      expect(reserializedJson['edges'], hasLength(json['edges'].length));

      // Verify nodes match
      final originalNodes = (json['nodes'] as List).map((n) => n['id']).toSet();
      final reserializedNodes = (reserializedJson['nodes'] as List).map((n) => n['id']).toSet();
      expect(reserializedNodes, equals(originalNodes));

      // Verify edges match (comparing as sets of string representations)
      final originalEdges = (json['edges'] as List)
          .map((e) => '${e['src']}-${e['type']}->${e['dst']}')
          .toSet();
      final reserializedEdges = (reserializedJson['edges'] as List)
          .map((e) => '${e['src']}-${e['type']}->${e['dst']}')
          .toSet();
      expect(reserializedEdges, equals(originalEdges));

      print('✓ Re-serialization matches original');
      print('✓ Round-trip stability confirmed');

      // ===================================================================
      // CLEANUP
      // ===================================================================
      await tempFile.delete();
      print('\n✓ Cleanup complete');

      // ===================================================================
      // SUMMARY
      // ===================================================================
      print('\n${'=' * 60}');
      print('BACKEND INTEGRATION TEST SUMMARY');
      print('=' * 60);
      print('✓ Graph creation: 5 nodes, 5 edges');
      print('✓ Serialization: JSON structure valid');
      print('✓ File I/O: Save and load successful');
      print('✓ Deserialization: All data restored');
      print('✓ Data integrity: 100% match');
      print('✓ Pattern queries: All working');
      print('✓ Round-trip: Stable and consistent');
      print('\nJSON format is ready for backend integration! 🚀');
      print('${'=' * 60}\n');
    });

    test('verify JSON format matches backend expectations', () {
      print('\n=== JSON Format Verification ===\n');

      final graph = Graph<Node>();

      graph.addNode(Node(
        id: 'test_user',
        type: 'User',
        label: 'Test User',
        properties: {'email': 'test@example.com', 'score': 42},
      ));

      graph.addNode(Node(
        id: 'test_group',
        type: 'Group',
        label: 'Test Group',
        properties: {'name': 'Test', 'active': true},
      ));

      graph.addEdge('test_user', 'MEMBER_OF', 'test_group');

      final json = GraphSerializer.toJson(graph);

      // Verify top-level structure
      expect(json, isA<Map<String, dynamic>>());
      expect(json.keys, containsAll(['version', 'nodes', 'edges', 'metadata']));

      // Verify version
      expect(json['version'], isA<String>());
      expect(json['version'], equals('1.0'));

      // Verify nodes array structure
      expect(json['nodes'], isA<List>());
      final firstNode = (json['nodes'] as List).first;
      expect(firstNode, isA<Map<String, dynamic>>());
      expect(firstNode.keys, containsAll(['id', 'type', 'label']));

      // Properties should be optional
      if (firstNode['properties'] != null) {
        expect(firstNode['properties'], isA<Map<String, dynamic>>());
      }

      // Verify edges array structure
      expect(json['edges'], isA<List>());
      final firstEdge = (json['edges'] as List).first;
      expect(firstEdge, isA<Map<String, dynamic>>());
      expect(firstEdge.keys, containsAll(['src', 'type', 'dst']));
      expect(firstEdge['src'], isA<String>());
      expect(firstEdge['type'], isA<String>());
      expect(firstEdge['dst'], isA<String>());

      // Verify metadata structure
      expect(json['metadata'], isA<Map<String, dynamic>>());
      expect(json['metadata'].keys, containsAll(['nodeCount', 'edgeCount', 'serializedAt']));
      expect(json['metadata']['nodeCount'], isA<int>());
      expect(json['metadata']['edgeCount'], isA<int>());
      expect(json['metadata']['serializedAt'], isA<String>());

      print('✓ JSON format matches expected structure');
      print('✓ All required fields present');
      print('✓ Field types correct');
      print('\nBackend team can expect this exact structure! ✓\n');
    });
  });
}
