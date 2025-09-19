import 'package:test/test.dart';
import 'package:graph_kit/graph_kit.dart';

/// Additional edge cases and boundary conditions that could break in production
void main() {
  group('Unicode and Special Characters', () {
    test('node IDs and labels with unicode and special characters', () {
      final graph = Graph<Node>();
      final query = PatternQuery(graph);

      // Unicode characters in IDs and labels
      graph.addNode(Node(id: '用户_123', type: 'User', label: 'Alice 🎉'));
      graph.addNode(
        Node(id: 'group-with-dashes', type: 'Group', label: 'Team #1 & 2'),
      );
      graph.addNode(
        Node(
          id: 'node.with.dots',
          type: 'Resource',
          label: 'File: "config.json"',
        ),
      );

      // Special characters that might conflict with pattern syntax
      graph.addNode(
        Node(id: 'weird[]{}()', type: 'Special', label: 'Contains: []{}()'),
      );
      graph.addNode(
        Node(id: 'arrows-><-', type: 'Arrows', label: 'Has -> and <-'),
      );

      // Edge types with special characters
      graph.addEdge('用户_123', 'MEMBER_OF', 'group-with-dashes');
      graph.addEdge('group-with-dashes', 'HAS_ACCESS_TO', 'node.with.dots');
      graph.addEdge('weird[]{}()', 'CONNECTS_TO', 'arrows-><-');

      // These should all work without breaking the parser
      expect(graph.nodesById['用户_123']?.label, equals('Alice 🎉'));

      // Pattern queries with unicode IDs
      final result1 = query.match(
        'user-[:MEMBER_OF]->group',
        startId: '用户_123',
      );
      expect(result1['group'], contains('group-with-dashes'));

      // Type filtering should work with special characters
      final specialNodes = query.match('node:Special');
      expect(specialNodes['node'], contains('weird[]{}()'));
    });

    test('very long strings and IDs', () {
      final graph = Graph<Node>();
      final query = PatternQuery(graph);

      // Very long ID (1000 characters)
      final longId = 'a' * 1000;
      final longType = 'VeryLongTypeNameThatExceedsNormalLimits' * 10;
      final longLabel = 'Very long label ' * 100;

      graph.addNode(Node(id: longId, type: longType, label: longLabel));
      graph.addNode(Node(id: 'normal', type: 'Normal', label: 'Normal'));
      graph.addEdge(longId, 'VERY_LONG_EDGE_TYPE_NAME' * 5, 'normal');

      // Should handle long strings without issues
      expect(graph.nodesById[longId]?.type, equals(longType));

      final result = query.match(
        'long-[:${'VERY_LONG_EDGE_TYPE_NAME' * 5}]->normal',
        startId: longId,
      );
      expect(result['normal'], contains('normal'));
    });

    test('empty and whitespace strings', () {
      final graph = Graph<Node>();
      final query = PatternQuery(graph);

      // Empty strings (should be handled gracefully)
      expect(
        () => graph.addNode(Node(id: '', type: 'User', label: 'Empty ID')),
        returnsNormally,
      );
      expect(
        () => graph.addNode(Node(id: 'user', type: '', label: 'Empty Type')),
        returnsNormally,
      );
      expect(
        () => graph.addNode(Node(id: 'user2', type: 'User', label: '')),
        returnsNormally,
      );

      // Whitespace-only strings
      graph.addNode(Node(id: '   ', type: '  ', label: '   '));
      graph.addNode(
        Node(
          id: 'tab\t\tnode',
          type: 'Type\nWith\nNewlines',
          label: 'Label\r\nWith\r\nCRLF',
        ),
      );

      // Patterns with whitespace should parse correctly
      // Should handle whitespace in patterns gracefully without crashing
      expect(
        () => query.match('  user  :  User  ', startId: 'user'),
        returnsNormally,
      );
    });
  });

  group('Resource Exhaustion and Performance Limits', () {
    test('extremely wide graph (many edges from one node)', () {
      final graph = Graph<Node>();
      final query = PatternQuery(graph);

      // One node connected to 1000 others
      graph.addNode(Node(id: 'hub', type: 'Hub', label: 'Central Hub'));
      for (int i = 0; i < 1000; i++) {
        graph.addNode(Node(id: 'spoke_$i', type: 'Spoke', label: 'Spoke $i'));
        graph.addEdge('hub', 'CONNECTS_TO', 'spoke_$i');
      }

      // Should handle very wide graphs efficiently
      final neighbors = graph.outNeighbors('hub', 'CONNECTS_TO');
      expect(neighbors, hasLength(1000));

      // Pattern query should work but may be slow
      final result = query.match('hub-[:CONNECTS_TO]->spoke', startId: 'hub');
      expect(result['spoke'], hasLength(1000));

      // Subgraph expansion should limit properly
      final expansion = expandSubgraph(
        graph,
        seeds: {'hub'},
        edgeTypesRightward: {'CONNECTS_TO'},
        forwardHops: 1,
      );
      expect(expansion.nodes, hasLength(1001)); // hub + 1000 spokes
    });

    test('very deep graph (long chains)', () {
      final graph = Graph<Node>();

      // Create a chain of 1000 nodes
      for (int i = 0; i < 1000; i++) {
        graph.addNode(Node(id: 'node_$i', type: 'Node', label: 'Node $i'));
        if (i > 0) {
          graph.addEdge('node_${i - 1}', 'NEXT', 'node_$i');
        }
      }

      // Deep expansion should work without stack overflow
      final deepExpansion = expandSubgraph(
        graph,
        seeds: {'node_0'},
        edgeTypesRightward: {'NEXT'},
        forwardHops: 500,
      );
      expect(deepExpansion.nodes, hasLength(501)); // node_0 through node_500

      // Very deep backward expansion
      final backwardExpansion = expandSubgraph(
        graph,
        seeds: {'node_999'},
        edgeTypesRightward: {}, // No forward edges
        edgeTypesLeftward: {'NEXT'},
        backwardHops: 500,
      );
      expect(
        backwardExpansion.nodes,
        hasLength(501),
      ); // node_499 through node_999
    });

    test('complete graph (everyone connected to everyone)', () {
      final graph = Graph<Node>();

      // Create a complete graph of 50 nodes (50 * 49 = 2450 edges)
      const nodeCount = 50;
      for (int i = 0; i < nodeCount; i++) {
        graph.addNode(Node(id: 'n$i', type: 'Node', label: 'Node $i'));
      }

      for (int i = 0; i < nodeCount; i++) {
        for (int j = 0; j < nodeCount; j++) {
          if (i != j) {
            graph.addEdge('n$i', 'CONNECTS', 'n$j');
          }
        }
      }

      // Every node should have 49 outgoing edges
      for (int i = 0; i < nodeCount; i++) {
        expect(graph.outNeighbors('n$i', 'CONNECTS'), hasLength(nodeCount - 1));
      }

      // Expansion should handle exponential growth
      final expansion = expandSubgraph(
        graph,
        seeds: {'n0'},
        edgeTypesRightward: {'CONNECTS'},
        forwardHops: 2,
      );
      expect(
        expansion.nodes,
        hasLength(nodeCount),
      ); // Should reach all nodes in 2 hops
    });
  });

  group('Pattern Syntax Edge Cases', () {
    test('patterns with unusual whitespace and formatting', () {
      final graph = Graph<Node>();
      final query = PatternQuery(graph);

      graph.addNode(Node(id: 'alice', type: 'User', label: 'Alice'));
      graph.addNode(Node(id: 'team1', type: 'Team', label: 'Team 1'));
      graph.addEdge('alice', 'MEMBER_OF', 'team1');

      // Patterns with various whitespace should all work
      final patterns = [
        'user-[:MEMBER_OF]->team', // Normal
        '  user  -  [ : MEMBER_OF ] ->  team  ', // Lots of spaces
        'user-[:MEMBER_OF]->team', // No spaces
        '\tuser\t-\t[:\tMEMBER_OF\t]\t->\tteam\t', // Tabs
        '\nuser\n-\n[:\nMEMBER_OF\n]\n->\nteam\n', // Newlines
      ];

      for (final pattern in patterns) {
        final result = query.match(pattern, startId: 'alice');
        expect(
          result['team'],
          contains('team1'),
          reason: 'Pattern failed: "$pattern"',
        );
      }
    });

    test('duplicate variable names in patterns', () {
      final graph = Graph<Node>();
      final query = PatternQuery(graph);

      graph.addNode(Node(id: 'alice', type: 'User', label: 'Alice'));
      graph.addNode(Node(id: 'team1', type: 'Team', label: 'Team 1'));
      graph.addNode(Node(id: 'project1', type: 'Project', label: 'Project 1'));
      graph.addEdge('alice', 'MEMBER_OF', 'team1');
      graph.addEdge('team1', 'WORKS_ON', 'project1');

      // Pattern with duplicate variable name "user"
      final result = query.match(
        'user-[:MEMBER_OF]->team-[:WORKS_ON]->user',
        startId: 'alice',
      );

      // Should use the last occurrence of "user" variable
      expect(result['user'], contains('project1'));
      expect(result['team'], contains('team1'));
    });

    test('edge types conflicting with pattern syntax', () {
      final graph = Graph<Node>();
      final query = PatternQuery(graph);

      graph.addNode(Node(id: 'a', type: 'Node', label: 'A'));
      graph.addNode(Node(id: 'b', type: 'Node', label: 'B'));

      // Edge types that contain pattern syntax characters
      graph.addEdge('a', 'EDGE->WITH->ARROWS', 'b');
      graph.addEdge('a', 'EDGE:WITH:COLONS', 'b');
      graph.addEdge('a', 'EDGE[WITH]BRACKETS', 'b');

      // These should work if properly escaped/handled
      final result1 = query.match('a-[:EDGE->WITH->ARROWS]->b', startId: 'a');
      expect(result1, isNot(isEmpty));

      final result2 = query.match('a-[:EDGE:WITH:COLONS]->b', startId: 'a');
      expect(result2, isNot(isEmpty));

      final result3 = query.match('a-[:EDGE[WITH]BRACKETS]->b', startId: 'a');
      expect(result3, isNot(isEmpty));
    });

    test('extremely long patterns', () {
      final graph = Graph<Node>();
      final query = PatternQuery(graph);

      // Create a chain of 20 nodes
      String prevId = 'start';
      graph.addNode(Node(id: prevId, type: 'Node', label: 'Start'));

      for (int i = 1; i <= 20; i++) {
        final currentId = 'node$i';
        graph.addNode(Node(id: currentId, type: 'Node', label: 'Node $i'));
        graph.addEdge(prevId, 'NEXT', currentId);
        prevId = currentId;
      }

      // Build a very long pattern programmatically
      final patternParts = <String>['start'];
      for (int i = 1; i <= 20; i++) {
        patternParts.add('-[:NEXT]->n$i');
      }
      final longPattern = patternParts.join('');

      // Should handle very long patterns
      final result = query.match(longPattern, startId: 'start');
      expect(result['n20'], contains('node20'));
    });
  });

  group('Numerical and Boundary Edge Cases', () {
    test('expandSubgraph with extreme hop counts', () {
      final graph = Graph<Node>();

      // Simple 3-node chain
      graph.addNode(Node(id: 'a', type: 'Node', label: 'A'));
      graph.addNode(Node(id: 'b', type: 'Node', label: 'B'));
      graph.addNode(Node(id: 'c', type: 'Node', label: 'C'));
      graph.addEdge('a', 'NEXT', 'b');
      graph.addEdge('b', 'NEXT', 'c');

      // Zero hops should just return the seed
      final expansion0 = expandSubgraph(
        graph,
        seeds: {'a'},
        edgeTypesRightward: {'NEXT'},
        forwardHops: 0,
      );
      expect(expansion0.nodes, equals({'a'}));
      expect(expansion0.edges, isEmpty);

      // Extremely large hop count should not cause issues
      final expansionHuge = expandSubgraph(
        graph,
        seeds: {'a'},
        edgeTypesRightward: {'NEXT'},
        forwardHops: 1000000,
      );
      expect(
        expansionHuge.nodes,
        equals({'a', 'b', 'c'}),
      ); // Can't go beyond graph

      // Negative hop count should be treated as 0 or handled gracefully
      final expansionNegative = expandSubgraph(
        graph,
        seeds: {'a'},
        edgeTypesRightward: {'NEXT'},
        forwardHops: -5,
      );
      expect(expansionNegative.nodes, contains('a')); // At least the seed
    });

    test('empty edge type sets', () {
      final graph = Graph<Node>();

      graph.addNode(Node(id: 'a', type: 'Node', label: 'A'));
      graph.addNode(Node(id: 'b', type: 'Node', label: 'B'));
      graph.addEdge('a', 'CONNECTS', 'b');

      // Empty edge type sets should return just the seeds
      final expansion = expandSubgraph(
        graph,
        seeds: {'a'},
        edgeTypesRightward: <String>{},
        forwardHops: 5,
      );
      expect(expansion.nodes, equals({'a'}));
      expect(expansion.edges, isEmpty);

      // Empty edge types in both directions
      final expansion2 = expandSubgraph(
        graph,
        seeds: {'a'},
        edgeTypesRightward: <String>{},
        forwardHops: 2,
        edgeTypesLeftward: <String>{},
        backwardHops: 2,
      );
      expect(expansion2.nodes, equals({'a'}));
    });
  });

  group('Complex Graph Topologies', () {
    test('graphs with multiple edge types between same nodes', () {
      final graph = Graph<Node>();
      final query = PatternQuery(graph);

      graph.addNode(Node(id: 'alice', type: 'Person', label: 'Alice'));
      graph.addNode(Node(id: 'bob', type: 'Person', label: 'Bob'));

      // Many different relationship types
      final edgeTypes = [
        'FRIEND',
        'COLLEAGUE',
        'NEIGHBOR',
        'MENTOR',
        'STUDENT',
        'COLLABORATOR',
        'COMPETITOR',
        'FAMILY',
        'ACQUAINTANCE',
        'ENEMY',
      ];

      for (final edgeType in edgeTypes) {
        graph.addEdge('alice', edgeType, 'bob');
        graph.addEdge('bob', edgeType, 'alice'); // Bidirectional
      }

      // Each edge type should work independently
      for (final edgeType in edgeTypes) {
        expect(graph.outNeighbors('alice', edgeType), contains('bob'));
        expect(graph.outNeighbors('bob', edgeType), contains('alice'));

        final result = query.match(
          'person-[:$edgeType]->other',
          startId: 'alice',
        );
        expect(result['other'], contains('bob'));
      }

      // Mixed edge type expansion
      final expansion = expandSubgraph(
        graph,
        seeds: {'alice'},
        edgeTypesRightward: edgeTypes.take(5).toSet(),
        forwardHops: 1,
      );
      expect(expansion.edges, hasLength(5)); // 5 different edge types to bob
    });

    test('star topology with central hub', () {
      final graph = Graph<Node>();
      final query = PatternQuery(graph);

      // Central hub connected to 100 leaf nodes
      graph.addNode(Node(id: 'hub', type: 'Hub', label: 'Central Hub'));
      for (int i = 0; i < 100; i++) {
        graph.addNode(Node(id: 'leaf$i', type: 'Leaf', label: 'Leaf $i'));
        graph.addEdge('hub', 'CONNECTS', 'leaf$i');
        graph.addEdge('leaf$i', 'REPORTS_TO', 'hub');
      }

      // Hub should have 100 outgoing and 100 incoming connections
      expect(graph.outNeighbors('hub', 'CONNECTS'), hasLength(100));
      expect(graph.inNeighbors('hub', 'REPORTS_TO'), hasLength(100));

      // Pattern queries from hub should find all leaves
      final fromHub = query.match('hub-[:CONNECTS]->leaf', startId: 'hub');
      expect(fromHub['leaf'], hasLength(100));

      // Backward pattern from hub should find all leaves
      final toHub = query.match('hub<-[:REPORTS_TO]-leaf', startId: 'hub');
      expect(toHub['leaf'], hasLength(100));

      // No leaf should reach other leaves directly (2-hop required through hub)
      final leafToLeaf = expandSubgraph(
        graph,
        seeds: {'leaf0'},
        edgeTypesRightward: {'REPORTS_TO', 'CONNECTS'},
        forwardHops: 2,
      );
      expect(leafToLeaf.nodes, hasLength(101)); // leaf0 + hub + 99 other leaves
    });
  });

  group('Error Handling and Recovery', () {
    test('operations on corrupted/inconsistent graph state', () {
      final graph = Graph<Node>();
      final query = PatternQuery(graph);

      // Add nodes and edges
      graph.addNode(Node(id: 'alice', type: 'User', label: 'Alice'));
      graph.addNode(Node(id: 'bob', type: 'User', label: 'Bob'));
      graph.addEdge('alice', 'FRIEND', 'bob');

      // Overwrite node with different type
      graph.addNode(Node(id: 'alice', type: 'Admin', label: 'Alice Admin'));

      // Graph should remain consistent
      expect(graph.nodesById['alice']?.type, equals('Admin'));
      expect(graph.outNeighbors('alice', 'FRIEND'), contains('bob'));

      // Queries should still work
      final result = query.match(
        'admin:Admin-[:FRIEND]->user',
        startId: 'alice',
      );
      expect(result['user'], contains('bob'));
    });

    test('concurrent-like operations (simulated)', () {
      final graph = Graph<Node>();

      // Simulate rapid additions and modifications
      for (int i = 0; i < 1000; i++) {
        graph.addNode(Node(id: 'user$i', type: 'User', label: 'User $i'));
        if (i > 0) {
          graph.addEdge('user${i - 1}', 'FOLLOWS', 'user$i');
        }

        // Occasionally update existing nodes
        if (i % 10 == 0 && i > 0) {
          graph.addNode(
            Node(id: 'user${i ~/ 2}', type: 'UpdatedUser', label: 'Updated'),
          );
        }
      }

      // Graph should remain consistent after rapid modifications
      expect(graph.nodesById.length, equals(1000));

      // Pattern queries should work correctly
      final query = PatternQuery(graph);
      final users = query.match('user:User');
      final updatedUsers = query.match('user:UpdatedUser');

      expect(users['user'], isNotNull);
      expect(updatedUsers['user'], isNotNull);
      expect(
        users['user']!.length + updatedUsers['user']!.length,
        equals(1000),
      );
    });
  });
}
