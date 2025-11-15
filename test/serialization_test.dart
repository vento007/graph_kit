import 'package:test/test.dart';
import 'package:graph_kit/graph_kit.dart';

void main() {
  group('Graph Serialization', () {
    test('basic serialization and deserialization', () {
      final graph = Graph<Node>();

      // Add test data
      graph.addNode(Node(id: 'alice', type: 'User', label: 'Alice'));
      graph.addNode(Node(id: 'bob', type: 'User', label: 'Bob'));
      graph.addNode(Node(id: 'team1', type: 'Team', label: 'Engineering'));

      graph.addEdge('alice', 'MEMBER_OF', 'team1');
      graph.addEdge('bob', 'MEMBER_OF', 'team1');
      graph.addEdge('alice', 'MENTOR', 'bob');

      // Serialize to JSON
      final json = GraphSerializer.toJson(graph);

      // Verify JSON structure
      expect(json['version'], equals('1.0'));
      expect(json['nodes'], hasLength(3));
      expect(json['edges'], hasLength(3));
      expect(json['metadata']['nodeCount'], equals(3));
      expect(json['metadata']['edgeCount'], equals(3));

      // Deserialize back to graph
      final restoredGraph = GraphSerializer.fromJson(json, Node.fromJson);

      // Verify restored graph
      expect(restoredGraph.nodesById.length, equals(3));
      expect(restoredGraph.nodesById['alice']?.label, equals('Alice'));
      expect(restoredGraph.nodesById['bob']?.label, equals('Bob'));
      expect(restoredGraph.nodesById['team1']?.label, equals('Engineering'));

      // Verify edges are preserved
      expect(
        restoredGraph.outNeighbors('alice', 'MEMBER_OF'),
        contains('team1'),
      );
      expect(restoredGraph.outNeighbors('bob', 'MEMBER_OF'), contains('team1'));
      expect(restoredGraph.outNeighbors('alice', 'MENTOR'), contains('bob'));

      // Verify pattern queries still work
      final query = PatternQuery(restoredGraph);
      final teamMembers = query.match(
        'team<-[:MEMBER_OF]-user',
        startId: 'team1',
      );
      expect(teamMembers['user'], containsAll(['alice', 'bob']));
    });

    test('serialization with node properties', () {
      final graph = Graph<Node>();

      // Add nodes with properties
      graph.addNode(
        Node(
          id: 'alice',
          type: 'User',
          label: 'Alice',
          properties: {
            'email': 'alice@example.com',
            'age': 30,
            'active': true,
            'tags': ['engineer', 'team-lead'],
          },
        ),
      );

      graph.addNode(
        Node(
          id: 'project1',
          type: 'Project',
          label: 'Web App',
          properties: {
            'budget': 100000.50,
            'deadline': '2024-12-31',
            'priority': 'high',
          },
        ),
      );

      graph.addEdge('alice', 'ASSIGNED_TO', 'project1');

      // Serialize and deserialize
      final json = GraphSerializer.toJson(graph);
      final restored = GraphSerializer.fromJson(json, Node.fromJson);

      // Verify properties are preserved
      final aliceRestored = restored.nodesById['alice']!;
      expect(aliceRestored.properties?['email'], equals('alice@example.com'));
      expect(aliceRestored.properties?['age'], equals(30));
      expect(aliceRestored.properties?['active'], equals(true));
      expect(
        aliceRestored.properties?['tags'],
        equals(['engineer', 'team-lead']),
      );

      final projectRestored = restored.nodesById['project1']!;
      expect(projectRestored.properties?['budget'], equals(100000.50));
      expect(projectRestored.properties?['priority'], equals('high'));
    });

    test('serialization with edge properties', () {
      final graph = Graph<Node>();

      graph.addNode(Node(id: 'alice', type: 'User', label: 'Alice'));
      graph.addNode(Node(id: 'bob', type: 'User', label: 'Bob'));

      graph.addEdge(
        'alice',
        'KNOWS',
        'bob',
        properties: {'since': 2015, 'closeness': 0.9},
      );

      final json = GraphSerializer.toJson(graph);
      final edges = json['edges'] as List<dynamic>;
      expect(edges, hasLength(1));
      final edgeJson = edges.first as Map<String, dynamic>;
      expect(edgeJson['src'], equals('alice'));
      expect(edgeJson['dst'], equals('bob'));
      expect(edgeJson['type'], equals('KNOWS'));
      expect(edgeJson['properties'], equals({'since': 2015, 'closeness': 0.9}));

      final restored = GraphSerializer.fromJson(json, Node.fromJson);
      final restoredEdge = restored.getEdge('alice', 'KNOWS', 'bob');
      expect(restoredEdge?.properties?['since'], equals(2015));
      expect(restoredEdge?.properties?['closeness'], equals(0.9));
    });

    test('string serialization convenience methods', () {
      final graph = Graph<Node>();

      graph.addNode(Node(id: 'test', type: 'Test', label: 'Test Node'));
      graph.addEdge('test', 'SELF_LOOP', 'test');

      // Test JSON string serialization
      final jsonString = GraphSerializer.toJsonString(graph);
      expect(jsonString, isA<String>());

      final prettyJsonString = GraphSerializer.toJsonString(
        graph,
        pretty: true,
      );
      expect(prettyJsonString.contains('\n'), isTrue); // Pretty formatting

      // Test JSON string deserialization
      final restored = GraphSerializer.fromJsonString(
        jsonString,
        Node.fromJson,
      );
      expect(restored.nodesById['test']?.label, equals('Test Node'));
      expect(restored.outNeighbors('test', 'SELF_LOOP'), contains('test'));
    });

    test('extension methods on Graph class', () {
      final graph = Graph<Node>();

      graph.addNode(Node(id: 'node1', type: 'Type', label: 'Label'));

      // Test extension methods
      final json = graph.toJson();
      expect(json['nodes'], hasLength(1));

      final jsonString = graph.toJsonString();
      expect(jsonString, isA<String>());

      final prettyString = graph.toJsonString(pretty: true);
      expect(prettyString.contains('\n'), isTrue);
    });

    test('empty graph serialization', () {
      final graph = Graph<Node>();

      final json = GraphSerializer.toJson(graph);
      expect(json['nodes'], isEmpty);
      expect(json['edges'], isEmpty);
      expect(json['metadata']['nodeCount'], equals(0));
      expect(json['metadata']['edgeCount'], equals(0));

      final restored = GraphSerializer.fromJson(json, Node.fromJson);
      expect(restored.nodesById, isEmpty);
    });

    test('large graph serialization performance', () {
      final graph = Graph<Node>();

      // Create a large graph (100 nodes, ~200 edges)
      for (int i = 0; i < 100; i++) {
        graph.addNode(
          Node(
            id: 'node$i',
            type: 'TestNode',
            label: 'Node $i',
            properties: {'index': i, 'batch': i ~/ 10},
          ),
        );

        // Connect to previous 2 nodes (creates a dense graph)
        if (i > 0) {
          graph.addEdge('node$i', 'CONNECTS_TO', 'node${i - 1}');
        }
        if (i > 1) {
          graph.addEdge('node$i', 'ALSO_CONNECTS', 'node${i - 2}');
        }
      }

      // Should serialize and deserialize efficiently
      final stopwatch = Stopwatch()..start();
      final json = GraphSerializer.toJson(graph);
      final serializeTime = stopwatch.elapsedMilliseconds;

      stopwatch.reset();
      final restored = GraphSerializer.fromJson(json, Node.fromJson);
      final deserializeTime = stopwatch.elapsedMilliseconds;

      // Verify correctness
      expect(restored.nodesById.length, equals(100));
      expect(
        json['edges'],
        hasLength(197),
      ); // 99 CONNECTS_TO + 98 ALSO_CONNECTS edges

      // Performance should be reasonable (adjust thresholds as needed)
      expect(serializeTime, lessThan(100), reason: 'Serialization too slow');
      expect(
        deserializeTime,
        lessThan(100),
        reason: 'Deserialization too slow',
      );

      // Verify a few random nodes and edges
      expect(restored.nodesById['node42']?.label, equals('Node 42'));
      expect(restored.nodesById['node42']?.properties?['index'], equals(42));
      expect(
        restored.outNeighbors('node50', 'CONNECTS_TO'),
        contains('node49'),
      );
      expect(
        restored.outNeighbors('node50', 'ALSO_CONNECTS'),
        contains('node48'),
      );
    });
  });

  group('JSON Validation', () {
    test('validates correct JSON structure', () {
      final validJson = {
        'version': '1.0',
        'nodes': [
          {'id': 'a', 'type': 'TypeA', 'label': 'Label A'},
          {'id': 'b', 'type': 'TypeB', 'label': 'Label B'},
        ],
        'edges': [
          {'src': 'a', 'type': 'CONNECTS', 'dst': 'b'},
        ],
        'metadata': {'nodeCount': 2, 'edgeCount': 1},
      };

      expect(GraphSerializer.validateJson(validJson), isTrue);
    });

    test('rejects malformed JSON structures', () {
      // Missing version
      expect(
        () => GraphSerializer.validateJson({'nodes': [], 'edges': []}),
        throwsA(isA<FormatException>()),
      );

      // Missing nodes
      expect(
        () => GraphSerializer.validateJson({'version': '1.0', 'edges': []}),
        throwsA(isA<FormatException>()),
      );

      // Missing edges
      expect(
        () => GraphSerializer.validateJson({'version': '1.0', 'nodes': []}),
        throwsA(isA<FormatException>()),
      );

      // Nodes not a list
      expect(
        () => GraphSerializer.validateJson({
          'version': '1.0',
          'nodes': 'not-a-list',
          'edges': [],
        }),
        throwsA(isA<FormatException>()),
      );

      // Edges not a list
      expect(
        () => GraphSerializer.validateJson({
          'version': '1.0',
          'nodes': [],
          'edges': 'not-a-list',
        }),
        throwsA(isA<FormatException>()),
      );
    });

    test('validates node structure', () {
      // Node missing id
      expect(
        () => GraphSerializer.validateJson({
          'version': '1.0',
          'nodes': [
            {'type': 'Type', 'label': 'Label'},
          ],
          'edges': [],
        }),
        throwsA(isA<FormatException>()),
      );

      // Node with empty id
      expect(
        () => GraphSerializer.validateJson({
          'version': '1.0',
          'nodes': [
            {'id': '', 'type': 'Type', 'label': 'Label'},
          ],
          'edges': [],
        }),
        throwsA(isA<FormatException>()),
      );

      // Duplicate node IDs
      expect(
        () => GraphSerializer.validateJson({
          'version': '1.0',
          'nodes': [
            {'id': 'same', 'type': 'Type', 'label': 'Label1'},
            {'id': 'same', 'type': 'Type', 'label': 'Label2'},
          ],
          'edges': [],
        }),
        throwsA(isA<FormatException>()),
      );

      // Node missing type
      expect(
        () => GraphSerializer.validateJson({
          'version': '1.0',
          'nodes': [
            {'id': 'test', 'label': 'Label'},
          ],
          'edges': [],
        }),
        throwsA(isA<FormatException>()),
      );

      // Node missing label
      expect(
        () => GraphSerializer.validateJson({
          'version': '1.0',
          'nodes': [
            {'id': 'test', 'type': 'Type'},
          ],
          'edges': [],
        }),
        throwsA(isA<FormatException>()),
      );
    });

    test('validates edge structure and references', () {
      // Edge missing src
      expect(
        () => GraphSerializer.validateJson({
          'version': '1.0',
          'nodes': [
            {'id': 'a', 'type': 'Type', 'label': 'Label'},
          ],
          'edges': [
            {'type': 'EDGE', 'dst': 'a'},
          ],
        }),
        throwsA(isA<FormatException>()),
      );

      // Edge with empty src
      expect(
        () => GraphSerializer.validateJson({
          'version': '1.0',
          'nodes': [
            {'id': 'a', 'type': 'Type', 'label': 'Label'},
          ],
          'edges': [
            {'src': '', 'type': 'EDGE', 'dst': 'a'},
          ],
        }),
        throwsA(isA<FormatException>()),
      );

      // Edge referencing non-existent source
      expect(
        () => GraphSerializer.validateJson({
          'version': '1.0',
          'nodes': [
            {'id': 'a', 'type': 'Type', 'label': 'Label'},
          ],
          'edges': [
            {'src': 'nonexistent', 'type': 'EDGE', 'dst': 'a'},
          ],
        }),
        throwsA(isA<FormatException>()),
      );

      // Edge referencing non-existent destination
      expect(
        () => GraphSerializer.validateJson({
          'version': '1.0',
          'nodes': [
            {'id': 'a', 'type': 'Type', 'label': 'Label'},
          ],
          'edges': [
            {'src': 'a', 'type': 'EDGE', 'dst': 'nonexistent'},
          ],
        }),
        throwsA(isA<FormatException>()),
      );

      // Edge missing type
      expect(
        () => GraphSerializer.validateJson({
          'version': '1.0',
          'nodes': [
            {'id': 'a', 'type': 'Type', 'label': 'Label'},
          ],
          'edges': [
            {'src': 'a', 'dst': 'a'},
          ],
        }),
        throwsA(isA<FormatException>()),
      );
    });

    test('handles version compatibility', () {
      final futureVersionJson = {
        'version': '2.0', // Future version
        'nodes': [
          {'id': 'a', 'type': 'Type', 'label': 'Label'},
        ],
        'edges': [],
      };

      expect(
        () => GraphSerializer.fromJson(futureVersionJson, Node.fromJson),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('Error Handling', () {
    test('handles corrupted JSON gracefully', () {
      // Invalid JSON string
      expect(
        () => GraphSerializer.fromJsonString('invalid json', Node.fromJson),
        throwsA(isA<FormatException>()),
      );

      // Valid JSON but wrong structure
      expect(
        () => GraphSerializer.fromJsonString('{"not": "graph"}', Node.fromJson),
        throwsA(isA<FormatException>()),
      );
    });

    test('handles edge cases in deserialization', () {
      // Missing required node fields during deserialization
      final jsonWithBadNode = {
        'version': '1.0',
        'nodes': [
          {'id': 'test'},
        ], // Missing type and label
        'edges': [],
      };

      expect(
        () => GraphSerializer.fromJson(jsonWithBadNode, Node.fromJson),
        throwsA(isA<TypeError>()),
      );
    });

    test('preserves graph integrity on deserialization errors', () {
      final graph = Graph<Node>();
      graph.addNode(Node(id: 'existing', type: 'Type', label: 'Existing'));

      // This should not affect the existing graph
      final jsonWithInvalidEdge = {
        'version': '1.0',
        'nodes': [
          {'id': 'test', 'type': 'Type', 'label': 'Test'},
        ],
        'edges': [
          {'src': 'test', 'type': 'EDGE', 'dst': 'missing'},
        ],
      };

      expect(
        () => GraphSerializer.fromJson(jsonWithInvalidEdge, Node.fromJson),
        throwsA(isA<FormatException>()),
      );

      // Original graph should be unaffected
      expect(graph.nodesById['existing']?.label, equals('Existing'));
    });
  });

  group('Complex Graph Scenarios', () {
    test('handles unicode and special characters', () {
      final graph = Graph<Node>();

      // Unicode in all fields
      graph.addNode(
        Node(
          id: '用户_123',
          type: 'User类型',
          label: 'Alice 🎉',
          properties: {'描述': '这是一个测试', 'emoji': '🚀💯'},
        ),
      );

      graph.addNode(
        Node(
          id: 'special[]{}()',
          type: 'Type-with-dashes',
          label: 'Label with "quotes" and symbols!@#\$%',
        ),
      );

      graph.addEdge('用户_123', 'EDGE_WITH_UNICODE_中文', 'special[]{}()');

      // Serialize and deserialize
      final jsonString = GraphSerializer.toJsonString(graph);
      final restored = GraphSerializer.fromJsonString(
        jsonString,
        Node.fromJson,
      );

      // Verify unicode preservation
      expect(restored.nodesById['用户_123']?.label, equals('Alice 🎉'));
      expect(restored.nodesById['用户_123']?.properties?['描述'], equals('这是一个测试'));
      expect(
        restored.nodesById['special[]{}()']?.label,
        equals('Label with "quotes" and symbols!@#\$%'),
      );

      expect(
        restored.outNeighbors('用户_123', 'EDGE_WITH_UNICODE_中文'),
        contains('special[]{}()'),
      );
    });

    test('handles self-loops and cycles', () {
      final graph = Graph<Node>();

      graph.addNode(Node(id: 'a', type: 'Node', label: 'A'));
      graph.addNode(Node(id: 'b', type: 'Node', label: 'B'));
      graph.addNode(Node(id: 'c', type: 'Node', label: 'C'));

      // Self-loop
      graph.addEdge('a', 'SELF', 'a');

      // Cycle
      graph.addEdge('a', 'NEXT', 'b');
      graph.addEdge('b', 'NEXT', 'c');
      graph.addEdge('c', 'NEXT', 'a');

      // Multiple edges between same nodes
      graph.addEdge('a', 'EDGE1', 'b');
      graph.addEdge('a', 'EDGE2', 'b');

      final restored = GraphSerializer.fromJson(
        GraphSerializer.toJson(graph),
        Node.fromJson,
      );

      // Verify structure preservation
      expect(restored.outNeighbors('a', 'SELF'), contains('a'));
      expect(restored.outNeighbors('a', 'NEXT'), contains('b'));
      expect(restored.outNeighbors('b', 'NEXT'), contains('c'));
      expect(restored.outNeighbors('c', 'NEXT'), contains('a'));
      expect(restored.outNeighbors('a', 'EDGE1'), contains('b'));
      expect(restored.outNeighbors('a', 'EDGE2'), contains('b'));
    });

    test('preserves graph after complex operations', () {
      final graph = Graph<Node>();

      // Build complex graph
      for (int i = 0; i < 20; i++) {
        graph.addNode(
          Node(
            id: 'node$i',
            type: 'Type${i % 3}',
            label: 'Node $i',
            properties: {'value': i * 10, 'group': i ~/ 5},
          ),
        );
      }

      // Add various edge types with different patterns
      for (int i = 0; i < 20; i++) {
        if (i > 0) graph.addEdge('node$i', 'PREV', 'node${i - 1}');
        if (i % 3 == 0 && i > 0) {
          graph.addEdge('node$i', 'MULTIPLE', 'node${i ~/ 3}');
        }
        if (i % 7 == 0) graph.addEdge('node$i', 'SPECIAL', 'node0');
      }

      // Serialize
      final json = GraphSerializer.toJson(graph);
      final restored = GraphSerializer.fromJson(json, Node.fromJson);

      // Test pattern queries on restored graph
      final query = PatternQuery(restored);

      // Type-based query
      final type0Nodes = query.match('node:Type0');
      expect(type0Nodes['node'], isNotNull);
      expect(type0Nodes['node']!.length, greaterThan(0));

      // Multi-hop query
      final multihop = query.match(
        'start-[:PREV]->mid-[:PREV]->end',
        startId: 'node5',
      );
      expect(multihop['end'], contains('node3'));

      // Subgraph expansion should work identically
      final original = expandSubgraph(
        graph,
        seeds: {'node10'},
        edgeTypesRightward: {'PREV', 'MULTIPLE'},
        forwardHops: 3,
      );

      final restoredExpansion = expandSubgraph(
        restored,
        seeds: {'node10'},
        edgeTypesRightward: {'PREV', 'MULTIPLE'},
        forwardHops: 3,
      );

      expect(restoredExpansion.nodes, equals(original.nodes));
      expect(restoredExpansion.edges.length, equals(original.edges.length));
    });
  });
}
