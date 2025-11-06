import 'package:test/test.dart';
import 'package:graph_kit/graph_kit.dart';

void main() {
  group('startIds Multi-Start Pattern Queries', () {
    test('Scenario 1: Simple chain with multiple starts', () {
      final graph = Graph<Node>();
      graph.addNode(Node(id: 'a', type: 'N', label: 'A'));
      graph.addNode(Node(id: 'b', type: 'N', label: 'B'));
      graph.addNode(Node(id: 'c', type: 'N', label: 'C'));
      graph.addNode(Node(id: 'd', type: 'N', label: 'D'));
      graph.addNode(Node(id: 'e', type: 'N', label: 'E'));

      graph.addEdge('a', 'LINK', 'b');
      graph.addEdge('b', 'LINK', 'c');
      graph.addEdge('c', 'LINK', 'd');
      graph.addEdge('d', 'LINK', 'e');

      final query = PatternQuery(graph);
      final paths = query.matchPaths(
        'n1-[:LINK]->n2-[:LINK]->n3-[:LINK]->n4-[:LINK]->n5',
        startIds: ['a', 'c'],
      );

      expect(paths.length, 1, reason: 'Should find 1 unique path (deduplicated)');

      final path = paths[0];
      expect(path.nodes['n1'], 'a');
      expect(path.nodes['n2'], 'b');
      expect(path.nodes['n3'], 'c');
      expect(path.nodes['n4'], 'd');
      expect(path.nodes['n5'], 'e');
      expect(path.edges.length, 4);
    });

    test('Scenario 2: Diamond pattern with multiple starts', () {
      final graph = Graph<Node>();
      graph.addNode(Node(id: 'a', type: 'N', label: 'A'));
      graph.addNode(Node(id: 'b', type: 'N', label: 'B'));
      graph.addNode(Node(id: 'c', type: 'N', label: 'C'));
      graph.addNode(Node(id: 'd', type: 'N', label: 'D'));

      graph.addEdge('a', 'EDGE', 'b');
      graph.addEdge('a', 'EDGE', 'c');
      graph.addEdge('b', 'EDGE', 'd');
      graph.addEdge('c', 'EDGE', 'd');

      final query = PatternQuery(graph);
      final paths = query.matchPaths(
        'n1-[:EDGE]->n2-[:EDGE]->n3',
        startIds: ['b', 'c'],
      );

      expect(paths.length, 2, reason: 'Should find 2 unique paths (a->b->d, a->c->d)');

      final pathStrings = paths.map((p) =>
        p.edges.map((e) => '${e.from}->${e.to}').join(',')
      ).toSet();

      expect(pathStrings, containsAll(['a->b,b->d', 'a->c,c->d']));
    });

    test('Scenario 3: Variable-length with multiple starts', () {
      final graph = Graph<Node>();
      graph.addNode(Node(id: 'ceo', type: 'Person', label: 'CEO'));
      graph.addNode(Node(id: 'dir1', type: 'Person', label: 'Director 1'));
      graph.addNode(Node(id: 'dir2', type: 'Person', label: 'Director 2'));
      graph.addNode(Node(id: 'mgr1', type: 'Person', label: 'Manager 1'));
      graph.addNode(Node(id: 'mgr2', type: 'Person', label: 'Manager 2'));
      graph.addNode(Node(id: 'mgr3', type: 'Person', label: 'Manager 3'));

      graph.addEdge('ceo', 'MANAGES', 'dir1');
      graph.addEdge('ceo', 'MANAGES', 'dir2');
      graph.addEdge('dir1', 'MANAGES', 'mgr1');
      graph.addEdge('dir1', 'MANAGES', 'mgr2');
      graph.addEdge('dir2', 'MANAGES', 'mgr3');

      final query = PatternQuery(graph);
      final paths = query.matchPaths(
        'boss-[:MANAGES*1..2]->subordinate',
        startIds: ['dir1', 'dir2'],
      );

      expect(paths.length, greaterThanOrEqualTo(5),
        reason: 'Should find paths from both directors (1-hop and 2-hop)');

      final subordinates = paths.map((p) => p.nodes['subordinate']).toSet();
      expect(subordinates, containsAll(['mgr1', 'mgr2', 'mgr3']));

      final pathsFromDir1 = paths.where((p) =>
        p.edges.any((e) => e.from == 'dir1' || e.to == 'dir1')
      ).length;
      expect(pathsFromDir1, greaterThan(0), reason: 'Should have paths from dir1');

      final pathsFromDir2 = paths.where((p) =>
        p.edges.any((e) => e.from == 'dir2' || e.to == 'dir2')
      ).length;
      expect(pathsFromDir2, greaterThan(0), reason: 'Should have paths from dir2');
    });

    test('Scenario 4a: Edge case - empty list behaves like no filtering', () {
      final graph = Graph<Node>();
      graph.addNode(Node(id: 'a', type: 'N', label: 'A'));
      graph.addNode(Node(id: 'b', type: 'N', label: 'B'));
      graph.addEdge('a', 'LINK', 'b');

      final query = PatternQuery(graph);
      final pathsEmpty = query.matchPaths('n1-[:LINK]->n2', startIds: []);
      final pathsNull = query.matchPaths('n1-[:LINK]->n2');

      expect(pathsEmpty.length, pathsNull.length,
        reason: 'Empty startIds should behave like no filtering');
    });

    test('Scenario 4b: Edge case - single item same as startId', () {
      final graph = Graph<Node>();
      graph.addNode(Node(id: 'alice', type: 'Person', label: 'Alice'));
      graph.addNode(Node(id: 'bob', type: 'Person', label: 'Bob'));
      graph.addEdge('alice', 'KNOWS', 'bob');

      final query = PatternQuery(graph);
      final pathsStartId = query.matchPaths('p1-[:KNOWS]->p2', startId: 'alice');
      final pathsStartIds = query.matchPaths('p1-[:KNOWS]->p2', startIds: ['alice']);

      expect(pathsStartIds.length, pathsStartId.length,
        reason: 'Single startIds should behave like startId');
      expect(pathsStartIds[0].nodes, pathsStartId[0].nodes);
    });

    test('Scenario 4c: Edge case - non-existent IDs filtered out', () {
      final graph = Graph<Node>();
      graph.addNode(Node(id: 'alice', type: 'Person', label: 'Alice'));
      graph.addNode(Node(id: 'bob', type: 'Person', label: 'Bob'));
      graph.addNode(Node(id: 'charlie', type: 'Person', label: 'Charlie'));
      graph.addEdge('alice', 'KNOWS', 'bob');
      graph.addEdge('charlie', 'KNOWS', 'bob');

      final query = PatternQuery(graph);
      final paths = query.matchPaths(
        'p1-[:KNOWS]->p2',
        startIds: ['alice', 'nonexistent', 'charlie'],
      );

      expect(paths.length, 2, reason: 'Should only match alice and charlie');

      final p1Values = paths.map((p) => p.nodes['p1']).toSet();
      expect(p1Values, containsAll(['alice', 'charlie']));
      expect(p1Values, isNot(contains('nonexistent')));
    });

    test('Scenario 4d: Edge case - all non-existent returns empty', () {
      final graph = Graph<Node>();
      graph.addNode(Node(id: 'alice', type: 'Person', label: 'Alice'));
      graph.addNode(Node(id: 'bob', type: 'Person', label: 'Bob'));
      graph.addEdge('alice', 'KNOWS', 'bob');

      final query = PatternQuery(graph);
      final paths = query.matchPaths(
        'p1-[:KNOWS]->p2',
        startIds: ['fake1', 'fake2', 'fake3'],
      );

      expect(paths.length, 0, reason: 'All non-existent IDs should return empty');
    });

    test('Scenario 5: Complex deduplication', () {
      final graph = Graph<Node>();
      graph.addNode(Node(id: 'alice', type: 'Person', label: 'Alice'));
      graph.addNode(Node(id: 'bob', type: 'Person', label: 'Bob'));
      graph.addNode(Node(id: 'team1', type: 'Team', label: 'Team 1'));
      graph.addNode(Node(id: 'team2', type: 'Team', label: 'Team 2'));
      graph.addNode(Node(id: 'project1', type: 'Project', label: 'Project 1'));

      graph.addEdge('alice', 'WORKS_FOR', 'team1');
      graph.addEdge('alice', 'WORKS_FOR', 'team2');
      graph.addEdge('bob', 'WORKS_FOR', 'team1');
      graph.addEdge('team1', 'OWNS', 'project1');
      graph.addEdge('team2', 'OWNS', 'project1');

      final query = PatternQuery(graph);
      final paths = query.matchPaths(
        'person-[:WORKS_FOR]->team-[:OWNS]->project',
        startIds: ['alice', 'team1'],
      );

      expect(paths.length, 3, reason: 'Should find 3 unique paths with deduplication');

      final pathSigs = paths.map((p) =>
        '${p.nodes['person']}->${p.nodes['team']}->${p.nodes['project']}'
      ).toList();

      final aliceTeam1Project1Count = pathSigs.where((s) => s == 'alice->team1->project1').length;
      expect(aliceTeam1Project1Count, 1,
        reason: 'alice->team1->project1 should appear exactly once (deduplicated)');

      expect(pathSigs.toSet().length, 3, reason: 'Should have 3 distinct paths');
    });

    test('Scenario 6: Mixed directions with multiple starts', () {
      final graph = Graph<Node>();
      graph.addNode(Node(id: 'a', type: 'N', label: 'A'));
      graph.addNode(Node(id: 'b', type: 'N', label: 'B'));
      graph.addNode(Node(id: 'c', type: 'N', label: 'C'));
      graph.addNode(Node(id: 'd', type: 'N', label: 'D'));

      graph.addEdge('a', 'EDGE', 'b');
      graph.addEdge('c', 'EDGE', 'b');
      graph.addEdge('c', 'EDGE', 'd');

      final query = PatternQuery(graph);
      final paths = query.matchPaths(
        'n1-[:EDGE]->n2<-[:EDGE]-n3-[:EDGE]->n4',
        startIds: ['b', 'c'],
      );

      expect(paths.length, greaterThan(0), reason: 'Should find paths with mixed directions');

      // Verify the expected path is among the results
      final expectedPath = paths.where((p) =>
        p.nodes['n1'] == 'a' &&
        p.nodes['n2'] == 'b' &&
        p.nodes['n3'] == 'c' &&
        p.nodes['n4'] == 'd'
      ).toList();

      expect(expectedPath.length, greaterThan(0),
        reason: 'Expected path a->b<-c->d should be included in results');
    });

    test('Scenario 7: Validation - both startId and startIds throws error', () {
      final graph = Graph<Node>();
      graph.addNode(Node(id: 'alice', type: 'Person', label: 'Alice'));
      graph.addNode(Node(id: 'bob', type: 'Person', label: 'Bob'));
      graph.addEdge('alice', 'KNOWS', 'bob');

      final query = PatternQuery(graph);

      expect(
        () => query.matchPaths('p1-[:KNOWS]->p2', startId: 'alice', startIds: ['bob']),
        throwsA(isA<ArgumentError>()),
        reason: 'Providing both startId and startIds should throw ArgumentError',
      );
    });

    test('startIds works with matchRows', () {
      final graph = Graph<Node>();
      graph.addNode(Node(id: 'a', type: 'N', label: 'A'));
      graph.addNode(Node(id: 'b', type: 'N', label: 'B'));
      graph.addNode(Node(id: 'c', type: 'N', label: 'C'));
      graph.addEdge('a', 'LINK', 'b');
      graph.addEdge('b', 'LINK', 'c');

      final query = PatternQuery(graph);
      final rows = query.matchRows('n1-[:LINK]->n2', startIds: ['a', 'b']);

      expect(rows.length, 2);
      expect(rows[0]['n1'], 'a');
      expect(rows[0]['n2'], 'b');
      expect(rows[1]['n1'], 'b');
      expect(rows[1]['n2'], 'c');
    });

    test('startIds works with match', () {
      final graph = Graph<Node>();
      graph.addNode(Node(id: 'a', type: 'N', label: 'A'));
      graph.addNode(Node(id: 'b', type: 'N', label: 'B'));
      graph.addNode(Node(id: 'c', type: 'N', label: 'C'));
      graph.addEdge('a', 'LINK', 'b');
      graph.addEdge('b', 'LINK', 'c');

      final query = PatternQuery(graph);
      final results = query.match('n1-[:LINK]->n2', startIds: ['a', 'b']);

      expect(results['n1'], containsAll(['a', 'b']));
      expect(results['n2'], containsAll(['b', 'c']));
    });

    test('startIds works with matchRowsMany', () {
      final graph = Graph<Node>();
      graph.addNode(Node(id: 'a', type: 'N', label: 'A'));
      graph.addNode(Node(id: 'b', type: 'N', label: 'B'));
      graph.addNode(Node(id: 'c', type: 'N', label: 'C'));
      graph.addEdge('a', 'LINK', 'b');
      graph.addEdge('b', 'LINK', 'c');

      final query = PatternQuery(graph);
      final rows = query.matchRowsMany(
        ['n1-[:LINK]->n2', 'n1-[:LINK]->n3'],
        startIds: ['a', 'b'],
      );

      expect(rows.length, greaterThan(0));
    });

    test('startIds works with matchMany', () {
      final graph = Graph<Node>();
      graph.addNode(Node(id: 'a', type: 'N', label: 'A'));
      graph.addNode(Node(id: 'b', type: 'N', label: 'B'));
      graph.addNode(Node(id: 'c', type: 'N', label: 'C'));
      graph.addEdge('a', 'LINK', 'b');
      graph.addEdge('b', 'LINK', 'c');

      final query = PatternQuery(graph);
      final results = query.matchMany(
        ['n1-[:LINK]->n2', 'x-[:LINK]->y'],
        startIds: ['a', 'b'],
      );

      expect(results, isNotEmpty);
    });

    test('startIds works with matchPathsMany', () {
      final graph = Graph<Node>();
      graph.addNode(Node(id: 'a', type: 'N', label: 'A'));
      graph.addNode(Node(id: 'b', type: 'N', label: 'B'));
      graph.addNode(Node(id: 'c', type: 'N', label: 'C'));
      graph.addEdge('a', 'LINK', 'b');
      graph.addEdge('b', 'LINK', 'c');

      final query = PatternQuery(graph);
      final paths = query.matchPathsMany(
        ['n1-[:LINK]->n2', 'x-[:LINK]->y'],
        startIds: ['a', 'b'],
      );

      expect(paths.length, greaterThan(0));
    });
  });
}
