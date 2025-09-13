import 'package:test/test.dart';
import 'package:graph_kit/graph_kit.dart';

/// Comprehensive stress tests designed to find edge cases and break graph_kit
void main() {
  group('Graph Edge Cases', () {
    test('empty graph operations should not crash', () {
      final graph = Graph<Node>();
      final query = PatternQuery(graph);

      // Empty graph queries
      expect(query.match('user:User'), equals({}));
      expect(query.match('user-[:ANY]->target'), equals({}));
      expect(query.matchRows('user-[:ANY]->target'), equals([]));
      expect(query.matchMany(['user:User', 'group:Group']), equals({}));
      expect(query.matchRowsMany(['user:User', 'group:Group']), equals([]));

      // Non-existent nodes
      expect(graph.outNeighbors('nonexistent', 'ANY'), isEmpty);
      expect(graph.inNeighbors('nonexistent', 'ANY'), isEmpty);
      expect(graph.hasEdge('a', 'EDGE', 'b'), isFalse);

      // Expansion on empty graph
      final expansion = expandSubgraph(graph, seeds: {'fake'},
        edgeTypesRightward: {'EDGE'}, forwardHops: 5);
      expect(expansion.nodes, isEmpty);
      expect(expansion.edges, isEmpty);
    });

    test('self-loops and cycles should work correctly', () {
      final graph = Graph<Node>();
      final query = PatternQuery(graph);

      // Self-loops
      graph.addNode(Node(id: 'alice', type: 'Person', label: 'Alice'));
      graph.addEdge('alice', 'MANAGES', 'alice'); // Alice manages herself

      expect(graph.outNeighbors('alice', 'MANAGES'), contains('alice'));
      expect(graph.inNeighbors('alice', 'MANAGES'), contains('alice'));

      // Pattern should handle self-loops
      final result = query.match('person-[:MANAGES]->manager', startId: 'alice');
      expect(result['person'], contains('alice'));
      expect(result['manager'], contains('alice'));

      // Longer cycles
      graph.addNode(Node(id: 'bob', type: 'Person', label: 'Bob'));
      graph.addNode(Node(id: 'charlie', type: 'Person', label: 'Charlie'));
      graph.addEdge('alice', 'REPORTS_TO', 'bob');
      graph.addEdge('bob', 'REPORTS_TO', 'charlie');
      graph.addEdge('charlie', 'REPORTS_TO', 'alice'); // Circular reporting!

      // Should traverse the cycle
      final cycle = query.match('person-[:REPORTS_TO]->boss-[:REPORTS_TO]->grandboss',
        startId: 'alice');
      expect(cycle['person'], contains('alice'));
      expect(cycle['boss'], contains('bob'));
      expect(cycle['grandboss'], contains('charlie'));
    });

    test('multiple edges between same nodes (multigraph)', () {
      final graph = Graph<Node>();
      final query = PatternQuery(graph);

      graph.addNode(Node(id: 'alice', type: 'Person', label: 'Alice'));
      graph.addNode(Node(id: 'bob', type: 'Person', label: 'Bob'));

      // Multiple relationship types between Alice and Bob
      graph.addEdge('alice', 'FRIEND', 'bob');
      graph.addEdge('alice', 'COLLEAGUE', 'bob');
      graph.addEdge('alice', 'NEIGHBOR', 'bob');
      graph.addEdge('bob', 'MENTOR', 'alice'); // Reverse direction

      // Each edge type should work independently
      expect(graph.outNeighbors('alice', 'FRIEND'), contains('bob'));
      expect(graph.outNeighbors('alice', 'COLLEAGUE'), contains('bob'));
      expect(graph.outNeighbors('alice', 'NEIGHBOR'), contains('bob'));
      expect(graph.outNeighbors('alice', 'MENTOR'), isEmpty);
      expect(graph.inNeighbors('alice', 'MENTOR'), contains('bob'));

      // Pattern queries for specific edge types
      final friends = query.match('person-[:FRIEND]->friend', startId: 'alice');
      expect(friends['friend'], contains('bob'));

      final mentees = query.match('mentor-[:MENTOR]->mentee', startId: 'bob');
      expect(mentees['mentee'], contains('alice'));
    });

    test('large graph performance and correctness', () {
      final graph = Graph<Node>();
      final query = PatternQuery(graph);

      // Create a large hierarchical structure
      // 100 users, 10 teams, 5 departments, 1 company
      for (int i = 0; i < 100; i++) {
        graph.addNode(Node(id: 'user$i', type: 'User', label: 'User $i'));
        graph.addNode(Node(id: 'team${i ~/ 10}', type: 'Team', label: 'Team ${i ~/ 10}'));
        graph.addEdge('user$i', 'MEMBER_OF', 'team${i ~/ 10}');
      }

      for (int i = 0; i < 10; i++) {
        graph.addNode(Node(id: 'dept${i ~/ 2}', type: 'Department', label: 'Dept ${i ~/ 2}'));
        graph.addEdge('team$i', 'PART_OF', 'dept${i ~/ 2}');
      }

      for (int i = 0; i < 5; i++) {
        graph.addNode(Node(id: 'company', type: 'Company', label: 'ACME Corp'));
        graph.addEdge('dept$i', 'PART_OF', 'company');
      }

      // Query all users (should find 100)
      final allUsers = query.match('user:User');
      expect(allUsers['user'], hasLength(100));

      // Deep traversal: user -> team -> dept -> company
      final userToCompany = query.match(
        'user-[:MEMBER_OF]->team-[:PART_OF]->dept-[:PART_OF]->company',
        startId: 'user0'
      );
      expect(userToCompany['company'], contains('company'));

      // Backward traversal: find all users in company
      final companyUsers = query.match(
        'company<-[:PART_OF]-dept<-[:PART_OF]-team<-[:MEMBER_OF]-user',
        startId: 'company'
      );
      expect(companyUsers['user'], hasLength(100));

      // Row-wise results should preserve paths correctly
      final rows = query.matchRows(
        'user-[:MEMBER_OF]->team-[:PART_OF]->dept',
        startId: 'user25' // User 25 is in team 2, dept 1
      );
      expect(rows, hasLength(1));
      expect(rows.first['user'], equals('user25'));
      expect(rows.first['team'], equals('team2'));
      expect(rows.first['dept'], equals('dept1'));
    });
  });

  group('Pattern Query Edge Cases', () {
    test('malformed patterns should fail gracefully', () {
      final graph = Graph<Node>();
      final query = PatternQuery(graph);

      graph.addNode(Node(id: 'alice', type: 'User', label: 'Alice'));

      // These should not crash, just return empty results
      expect(query.match(''), equals({}));
      expect(query.match('   '), equals({}));
      expect(query.match('user[:INVALID'), equals({}));
      expect(query.match('user-[:MISSING_BRACKET>target'), equals({}));
      expect(query.match('user<-[:BACKWARDS'), equals({}));
      expect(query.match('user-[:EDGE]->'), equals({}));
      expect(query.match('-[:EDGE]->target'), equals({}));

      // Invalid label filters
      expect(query.match('user:User{invalid}'), equals({}));
      expect(query.match('user:User{label}'), equals({}));
      expect(query.match('user:User{label=}'), equals({}));
    });

    test('complex label filtering', () {
      final graph = Graph<Node>();
      final query = PatternQuery(graph);

      // Add users with various labels
      graph.addNode(Node(id: 'alice', type: 'User', label: 'Alice Admin'));
      graph.addNode(Node(id: 'bob', type: 'User', label: 'Bob Manager'));
      graph.addNode(Node(id: 'charlie', type: 'User', label: 'Charlie Admin'));
      graph.addNode(Node(id: 'dave', type: 'User', label: 'Dave User'));
      graph.addNode(Node(id: 'eve', type: 'User', label: 'Eve ADMIN')); // Different case

      // Exact match filtering
      final exactMatch = query.match('user:User{label=Alice Admin}');
      expect(exactMatch['user'], equals({'alice'}));

      // Substring filtering (case-insensitive)
      final adminUsers = query.match('user:User{label~admin}');
      expect(adminUsers['user'], containsAll(['alice', 'charlie', 'eve']));
      expect(adminUsers['user'], hasLength(3));

      // Case variations
      final upperAdmin = query.match('user:User{label~ADMIN}');
      expect(upperAdmin['user'], containsAll(['alice', 'charlie', 'eve']));

      // Non-matching substring
      final noMatch = query.match('user:User{label~xyz}');
      expect(noMatch['user'], isNull); // Pattern matching returns null for empty results
    });

    test('type filtering edge cases', () {
      final graph = Graph<Node>();
      final query = PatternQuery(graph);

      // Nodes with similar type names
      graph.addNode(Node(id: 'user1', type: 'User', label: 'User 1'));
      graph.addNode(Node(id: 'user2', type: 'UserProfile', label: 'Profile'));
      graph.addNode(Node(id: 'user3', type: 'SuperUser', label: 'Super'));
      graph.addNode(Node(id: 'user4', type: 'user', label: 'Lowercase')); // Different case

      // Exact type matching should be case-sensitive
      final users = query.match('item:User');
      expect(users['item'], equals({'user1'}));

      final profiles = query.match('item:UserProfile');
      expect(profiles['item'], equals({'user2'}));

      // Non-existent type
      final none = query.match('item:NonExistent');
      expect(none, equals({}));
    });

    test('variable name edge cases', () {
      final graph = Graph<Node>();
      final query = PatternQuery(graph);

      graph.addNode(Node(id: 'alice', type: 'User', label: 'Alice'));
      graph.addNode(Node(id: 'team1', type: 'Team', label: 'Engineering'));
      graph.addEdge('alice', 'MEMBER_OF', 'team1');

      // Variable names with special characters (within regex limits)
      final result1 = query.match('user123-[:MEMBER_OF]->team456', startId: 'alice');
      expect(result1['user123'], contains('alice'));
      expect(result1['team456'], contains('team1'));

      // Single character variable names
      final result2 = query.match('u-[:MEMBER_OF]->t', startId: 'alice');
      expect(result2['u'], contains('alice'));
      expect(result2['t'], contains('team1'));

      // Long variable names
      final result3 = query.match('veryLongUserVariableName-[:MEMBER_OF]->veryLongTeamVariableName',
        startId: 'alice');
      expect(result3['veryLongUserVariableName'], contains('alice'));
      expect(result3['veryLongTeamVariableName'], contains('team1'));
    });

    test('deep and wide graph traversal', () {
      final graph = Graph<Node>();
      final query = PatternQuery(graph);

      // Create a deep chain: root -> level1 -> level2 -> ... -> level10
      String prevId = 'root';
      graph.addNode(Node(id: prevId, type: 'Node', label: 'Root'));

      for (int level = 1; level <= 10; level++) {
        final currentId = 'level$level';
        graph.addNode(Node(id: currentId, type: 'Node', label: 'Level $level'));
        graph.addEdge(prevId, 'NEXT', currentId);
        prevId = currentId;
      }

      // Forward traversal through the entire chain
      final forward = query.match(
        'start-[:NEXT]->l1-[:NEXT]->l2-[:NEXT]->l3-[:NEXT]->l4-[:NEXT]->end',
        startId: 'root'
      );
      expect(forward['start'], contains('root'));
      expect(forward['end'], contains('level5'));

      // Backward traversal
      final backward = query.match(
        'end<-[:NEXT]-l4<-[:NEXT]-l3<-[:NEXT]-l2<-[:NEXT]-l1<-[:NEXT]-start',
        startId: 'level5'
      );
      expect(backward['start'], contains('root'));
      expect(backward['end'], contains('level5'));

      // Create a wide graph: one node connected to 50 others
      graph.addNode(Node(id: 'center', type: 'Hub', label: 'Center'));
      for (int i = 0; i < 50; i++) {
        graph.addNode(Node(id: 'spoke$i', type: 'Spoke', label: 'Spoke $i'));
        graph.addEdge('center', 'CONNECTS', 'spoke$i');
      }

      // Query should handle many neighbors
      final spokes = query.match('hub-[:CONNECTS]->spoke', startId: 'center');
      expect(spokes['spoke'], hasLength(50));
    });
  });

  group('Subgraph Traversal Edge Cases', () {
    test('boundary conditions and limits', () {
      final graph = Graph<Node>();

      // Linear chain
      for (int i = 0; i < 10; i++) {
        graph.addNode(Node(id: 'n$i', type: 'Node', label: 'Node $i'));
        if (i > 0) {
          graph.addEdge('n${i-1}', 'NEXT', 'n$i');
        }
      }

      // Test different hop limits
      final expansion0 = expandSubgraph(graph, seeds: {'n0'},
        edgeTypesRightward: {'NEXT'}, forwardHops: 0);
      expect(expansion0.nodes, equals({'n0'}));
      expect(expansion0.edges, isEmpty);

      final expansion1 = expandSubgraph(graph, seeds: {'n0'},
        edgeTypesRightward: {'NEXT'}, forwardHops: 1);
      expect(expansion1.nodes, equals({'n0', 'n1'}));
      expect(expansion1.edges, hasLength(1));

      final expansion5 = expandSubgraph(graph, seeds: {'n5'},
        edgeTypesRightward: {'NEXT'}, forwardHops: 3,
        edgeTypesLeftward: {'NEXT'}, backwardHops: 2);
      expect(expansion5.nodes, containsAll(['n3', 'n4', 'n5', 'n6', 'n7', 'n8']));

      // Expansion beyond graph limits should not crash
      final expansionHuge = expandSubgraph(graph, seeds: {'n0'},
        edgeTypesRightward: {'NEXT'}, forwardHops: 100);
      expect(expansionHuge.nodes, hasLength(10)); // All nodes
    });

    test('disconnected components', () {
      final graph = Graph<Node>();

      // Create two separate components
      // Component 1: a1 <-> a2 <-> a3
      graph.addNode(Node(id: 'a1', type: 'A', label: 'A1'));
      graph.addNode(Node(id: 'a2', type: 'A', label: 'A2'));
      graph.addNode(Node(id: 'a3', type: 'A', label: 'A3'));
      graph.addEdge('a1', 'CONNECTS', 'a2');
      graph.addEdge('a2', 'CONNECTS', 'a3');

      // Component 2: b1 <-> b2 <-> b3
      graph.addNode(Node(id: 'b1', type: 'B', label: 'B1'));
      graph.addNode(Node(id: 'b2', type: 'B', label: 'B2'));
      graph.addNode(Node(id: 'b3', type: 'B', label: 'B3'));
      graph.addEdge('b1', 'CONNECTS', 'b2');
      graph.addEdge('b2', 'CONNECTS', 'b3');

      // Expansion from a1 should only reach component A
      final expansionA = expandSubgraph(graph, seeds: {'a1'},
        edgeTypesRightward: {'CONNECTS'}, forwardHops: 5);
      expect(expansionA.nodes, equals({'a1', 'a2', 'a3'}));
      expect(expansionA.nodes, isNot(contains('b1')));

      // Pattern queries should not cross components
      final query = PatternQuery(graph);
      final result = query.match('start:A-[:CONNECTS]->end', startId: 'a1');
      expect(result['end'], equals({'a2'})); // Only a2, not b1 or b2
    });

    test('mixed edge types and directions', () {
      final graph = Graph<Node>();

      // Create a mini org chart
      graph.addNode(Node(id: 'ceo', type: 'Person', label: 'CEO'));
      graph.addNode(Node(id: 'cto', type: 'Person', label: 'CTO'));
      graph.addNode(Node(id: 'dev1', type: 'Person', label: 'Developer 1'));
      graph.addNode(Node(id: 'dev2', type: 'Person', label: 'Developer 2'));

      graph.addEdge('cto', 'REPORTS_TO', 'ceo');
      graph.addEdge('dev1', 'REPORTS_TO', 'cto');
      graph.addEdge('dev2', 'REPORTS_TO', 'cto');
      graph.addEdge('dev1', 'COLLABORATES_WITH', 'dev2');
      graph.addEdge('dev2', 'COLLABORATES_WITH', 'dev1');

      // Expansion with multiple edge types
      final expansion = expandSubgraph(graph, seeds: {'ceo'},
        edgeTypesRightward: {'COLLABORATES_WITH'}, forwardHops: 2,
        edgeTypesLeftward: {'REPORTS_TO'}, backwardHops: 2);

      expect(expansion.nodes, containsAll(['ceo', 'cto', 'dev1', 'dev2']));

      // Verify distances are calculated correctly
      expect(expansion.backwardDist['ceo'], equals(0));
      expect(expansion.backwardDist['cto'], equals(1));
      expect(expansion.backwardDist['dev1'], equals(2));
      expect(expansion.backwardDist['dev2'], equals(2));
    });
  });

  group('Data Integrity and Consistency', () {
    test('duplicate nodes and edges', () {
      final graph = Graph<Node>();

      final alice1 = Node(id: 'alice', type: 'User', label: 'Alice 1');
      final alice2 = Node(id: 'alice', type: 'User', label: 'Alice 2');

      // Adding same ID twice should overwrite
      graph.addNode(alice1);
      graph.addNode(alice2);

      expect(graph.nodesById['alice']?.label, equals('Alice 2'));
      expect(graph.nodesById.length, equals(1));

      // Adding same edge multiple times should not create duplicates
      graph.addNode(Node(id: 'bob', type: 'User', label: 'Bob'));
      graph.addEdge('alice', 'FRIEND', 'bob');
      graph.addEdge('alice', 'FRIEND', 'bob');
      graph.addEdge('alice', 'FRIEND', 'bob');

      final friends = graph.outNeighbors('alice', 'FRIEND');
      expect(friends, equals({'bob'})); // Should only appear once
    });

    test('node and edge consistency after modifications', () {
      final graph = Graph<Node>();
      final query = PatternQuery(graph);

      // Build initial graph
      graph.addNode(Node(id: 'alice', type: 'User', label: 'Alice'));
      graph.addNode(Node(id: 'bob', type: 'User', label: 'Bob'));
      graph.addNode(Node(id: 'team1', type: 'Team', label: 'Team 1'));

      graph.addEdge('alice', 'MEMBER_OF', 'team1');
      graph.addEdge('bob', 'MEMBER_OF', 'team1');

      // Initial query works
      final initial = query.match('user-[:MEMBER_OF]->team', startId: 'alice');
      expect(initial['team'], contains('team1'));

      // Remove bob node - this should not affect alice's patterns
      // Note: Current implementation doesn't have removeNode, but edges should handle missing nodes

      // Add more complex structure
      graph.addNode(Node(id: 'project1', type: 'Project', label: 'Project 1'));
      graph.addEdge('team1', 'ASSIGNED_TO', 'project1');

      // Multi-hop query should work
      final multiHop = query.match('user-[:MEMBER_OF]->team-[:ASSIGNED_TO]->project',
        startId: 'alice');
      expect(multiHop['project'], contains('project1'));

      // Update node label and verify it doesn't break structure
      graph.addNode(Node(id: 'alice', type: 'User', label: 'Alice Updated'));
      final afterUpdate = query.match('user-[:MEMBER_OF]->team', startId: 'alice');
      expect(afterUpdate['team'], contains('team1'));
    });
  });
}