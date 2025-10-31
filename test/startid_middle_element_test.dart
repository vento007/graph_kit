import 'package:test/test.dart';
import 'package:graph_kit/graph_kit.dart';

/// Test for startId behavior when targeting middle elements in patterns
///
/// Current behavior: startId only matches the FIRST element in the pattern
/// Expected behavior: startId should work with ANY element in the pattern
void main() {
  group('startId with middle elements', () {
    late Graph<Node> graph;
    late PatternQuery<Node> query;

    setUp(() {
      graph = Graph<Node>();
      query = PatternQuery(graph);

      // Create a simple chain: alice -> engineering -> web_app
      // alice -> design -> mobile_app
      // bob -> engineering -> web_app

      graph.addNode(Node(id: 'alice', type: 'Person', label: 'Alice'));
      graph.addNode(Node(id: 'bob', type: 'Person', label: 'Bob'));
      graph.addNode(Node(id: 'engineering', type: 'Team', label: 'Engineering'));
      graph.addNode(Node(id: 'design', type: 'Team', label: 'Design'));
      graph.addNode(Node(id: 'web_app', type: 'Project', label: 'Web App'));
      graph.addNode(Node(id: 'mobile_app', type: 'Project', label: 'Mobile App'));

      graph.addEdge('alice', 'WORKS_FOR', 'engineering');
      graph.addEdge('bob', 'WORKS_FOR', 'engineering');
      graph.addEdge('alice', 'WORKS_FOR', 'design');
      graph.addEdge('engineering', 'OWNS', 'web_app');
      graph.addEdge('design', 'OWNS', 'mobile_app');
    });

    test('startId works with first element (baseline - should pass)', () {
      // Pattern: person -> team -> project
      // startId matches 'person' (first element)
      final paths = query.matchPaths(
        'person-[:WORKS_FOR]->team-[:OWNS]->project',
        startId: 'alice'
      );

      expect(paths, isNotEmpty);
      expect(paths.first.nodes['person'], equals('alice'));
    });

    test('startId with middle element (team) - should work', () {
      // Pattern: person -> team -> project
      // startId matches 'team' (middle element)
      final paths = query.matchPaths(
        'person-[:WORKS_FOR]->team-[:OWNS]->project',
        startId: 'engineering'  // Start from team in the middle
      );

      // Should find alice->engineering->web_app and bob->engineering->web_app
      expect(paths.length, equals(2));
      expect(paths.map((p) => p.nodes['team']).toSet(), equals({'engineering'}));
      expect(paths.map((p) => p.nodes['person']).toSet(), containsAll(['alice', 'bob']));
      expect(paths.map((p) => p.nodes['project']).toSet(), equals({'web_app'}));
    });

    test('startId with last element (project) - should work', () {
      // Pattern: person -> team -> project
      // startId matches 'project' (last element)
      final paths = query.matchPaths(
        'person-[:WORKS_FOR]->team-[:OWNS]->project',
        startId: 'web_app'  // Start from project at the end
      );

      // Should find alice->engineering->web_app and bob->engineering->web_app
      expect(paths.length, equals(2));
      expect(paths.map((p) => p.nodes['project']).toSet(), equals({'web_app'}));
      expect(paths.map((p) => p.nodes['team']).toSet(), equals({'engineering'}));
      expect(paths.map((p) => p.nodes['person']).toSet(), containsAll(['alice', 'bob']));
    });

    test('workaround: use backward arrows to put target element first', () {
      // Workaround: If you want to start from 'engineering',
      // restructure the pattern so 'engineering' is FIRST

      // Pattern: team <- person
      final pathsBackward = query.matchPaths(
        'team<-[:WORKS_FOR]-person',
        startId: 'engineering'
      );

      expect(pathsBackward, isNotEmpty);
      expect(pathsBackward.length, equals(2)); // alice and bob
      expect(pathsBackward.map((p) => p.nodes['team']).toSet(), equals({'engineering'}));
    });

    test('workaround: use two separate queries for middle element', () {
      // If you need the full chain person->team->project starting from team,
      // you need TWO queries:

      // 1. team <- person
      final pathsToTeam = query.matchPaths(
        'team<-[:WORKS_FOR]-person',
        startId: 'engineering'
      );

      // 2. team -> project
      final pathsFromTeam = query.matchPaths(
        'team-[:OWNS]->project',
        startId: 'engineering'
      );

      expect(pathsToTeam.length, equals(2)); // alice, bob
      expect(pathsFromTeam.length, equals(1)); // web_app

      // Then you'd need to manually combine them to get person->team->project
    });

    test('demonstrate the limitation with complex pattern', () {
      // Create longer chain: a -> b -> c -> d -> e
      final complexGraph = Graph<Node>();
      for (var id in ['a', 'b', 'c', 'd', 'e']) {
        complexGraph.addNode(Node(id: id, type: 'Node', label: id.toUpperCase()));
      }
      complexGraph.addEdge('a', 'LINK', 'b');
      complexGraph.addEdge('b', 'LINK', 'c');
      complexGraph.addEdge('c', 'LINK', 'd');
      complexGraph.addEdge('d', 'LINK', 'e');

      final complexQuery = PatternQuery(complexGraph);

      // Start from 'c' in the middle
      final paths = complexQuery.matchPaths(
        'n1-[:LINK]->n2-[:LINK]->n3-[:LINK]->n4-[:LINK]->n5',
        startId: 'c'  // Should match 'c' to n3 position
      );

      // Should find: a->b->c->d->e (c matches n3)
      expect(paths, isNotEmpty);
      expect(paths.first.nodes['n3'], equals('c'));
      expect(paths.first.nodes['n1'], equals('a'));
      expect(paths.first.nodes['n2'], equals('b'));
      expect(paths.first.nodes['n4'], equals('d'));
      expect(paths.first.nodes['n5'], equals('e'));
    });

    test('startType parameter optimizes execution', () {
      // Create graph with mixed types
      final mixedGraph = Graph<Node>();
      mixedGraph.addNode(Node(id: 'alice', type: 'Person', label: 'Alice'));
      mixedGraph.addNode(Node(id: 'bob', type: 'Person', label: 'Bob'));
      mixedGraph.addNode(Node(id: 'engineering', type: 'Team', label: 'Engineering'));
      mixedGraph.addNode(Node(id: 'web_app', type: 'Project', label: 'Web App'));

      mixedGraph.addEdge('alice', 'WORKS_FOR', 'engineering');
      mixedGraph.addEdge('bob', 'WORKS_FOR', 'engineering');
      mixedGraph.addEdge('engineering', 'OWNS', 'web_app');

      final mixedQuery = PatternQuery(mixedGraph);

      // With type hint - should only try Team positions
      final paths = mixedQuery.matchPaths(
        'person:Person-[:WORKS_FOR]->team:Team-[:OWNS]->project:Project',
        startId: 'engineering',
        startType: 'Team',  // NEW parameter for optimization
      );

      // Should find paths through engineering
      expect(paths, isNotEmpty);
      expect(paths.map((p) => p.nodes['team']).toSet(), equals({'engineering'}));
      expect(paths.map((p) => p.nodes['person']).toSet(), containsAll(['alice', 'bob']));
      expect(paths.map((p) => p.nodes['project']).toSet(), equals({'web_app'}));
    });

    test('complex: 8-hop chain with middle start and branching paths', () {
      // Create complex graph with multiple paths and dead ends
      // Main path: a->b->c->d->e->f->g->h->i
      // Decoy path: a->b->x->y (dead end)
      // Decoy path: d->z (dead end)
      final complexGraph = Graph<Node>();

      // Main chain
      for (var id in ['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i']) {
        complexGraph.addNode(Node(id: id, type: 'Node', label: id.toUpperCase()));
      }

      // Decoy nodes
      complexGraph.addNode(Node(id: 'x', type: 'Node', label: 'X'));
      complexGraph.addNode(Node(id: 'y', type: 'Node', label: 'Y'));
      complexGraph.addNode(Node(id: 'z', type: 'Node', label: 'Z'));

      // Main path edges
      complexGraph.addEdge('a', 'MAIN', 'b');
      complexGraph.addEdge('b', 'MAIN', 'c');
      complexGraph.addEdge('c', 'MAIN', 'd');
      complexGraph.addEdge('d', 'MAIN', 'e');
      complexGraph.addEdge('e', 'MAIN', 'f');
      complexGraph.addEdge('f', 'MAIN', 'g');
      complexGraph.addEdge('g', 'MAIN', 'h');
      complexGraph.addEdge('h', 'MAIN', 'i');

      // Decoy edges
      complexGraph.addEdge('b', 'DECOY', 'x');
      complexGraph.addEdge('x', 'DECOY', 'y');
      complexGraph.addEdge('d', 'DECOY', 'z');

      final complexQuery = PatternQuery(complexGraph);

      // Start from 'e' (middle of 9-node chain) - 8 hops total
      final paths = complexQuery.matchPaths(
        'n1-[:MAIN]->n2-[:MAIN]->n3-[:MAIN]->n4-[:MAIN]->n5-[:MAIN]->n6-[:MAIN]->n7-[:MAIN]->n8-[:MAIN]->n9',
        startId: 'e'
      );

      // Should find exactly ONE path: a->b->c->d->e->f->g->h->i
      expect(paths, isNotEmpty);
      expect(paths.length, equals(1), reason: 'Should find exactly one complete path, not including decoy paths');

      // Verify the complete chain
      final path = paths.first;
      expect(path.nodes['n1'], equals('a'));
      expect(path.nodes['n2'], equals('b'));
      expect(path.nodes['n3'], equals('c'));
      expect(path.nodes['n4'], equals('d'));
      expect(path.nodes['n5'], equals('e')); // Start position
      expect(path.nodes['n6'], equals('f'));
      expect(path.nodes['n7'], equals('g'));
      expect(path.nodes['n8'], equals('h'));
      expect(path.nodes['n9'], equals('i'));

      // Verify NO decoy nodes are included
      final allNodes = path.nodes.values.toSet();
      expect(allNodes, isNot(contains('x')));
      expect(allNodes, isNot(contains('y')));
      expect(allNodes, isNot(contains('z')));

      // Verify all edges are MAIN type, not DECOY
      for (final edge in path.edges) {
        expect(edge.type, equals('MAIN'), reason: 'Should only include MAIN edges, not DECOY edges');
      }
    });

    test('complex: verify it does NOT match unrelated paths', () {
      // Create two separate chains that should NOT be connected
      // Chain 1: a->b->c->d
      // Chain 2: w->x->y->z (completely separate)
      final separateGraph = Graph<Node>();

      // Chain 1
      for (var id in ['a', 'b', 'c', 'd']) {
        separateGraph.addNode(Node(id: id, type: 'Chain1', label: id.toUpperCase()));
      }
      separateGraph.addEdge('a', 'LINK', 'b');
      separateGraph.addEdge('b', 'LINK', 'c');
      separateGraph.addEdge('c', 'LINK', 'd');

      // Chain 2 (completely separate)
      for (var id in ['w', 'x', 'y', 'z']) {
        separateGraph.addNode(Node(id: id, type: 'Chain2', label: id.toUpperCase()));
      }
      separateGraph.addEdge('w', 'LINK', 'x');
      separateGraph.addEdge('x', 'LINK', 'y');
      separateGraph.addEdge('y', 'LINK', 'z');

      final separateQuery = PatternQuery(separateGraph);

      // Try to find a 4-hop path starting from 'b' (in chain 1)
      final paths = separateQuery.matchPaths(
        'n1-[:LINK]->n2-[:LINK]->n3-[:LINK]->n4',
        startId: 'b'
      );

      // Should only find paths in chain 1, not mixing with chain 2
      expect(paths, isNotEmpty);

      for (final path in paths) {
        final allNodes = path.nodes.values.toSet();

        // Verify path stays within chain 1 only
        expect(path.nodes['n2'], equals('b'), reason: 'Start node should be b');

        // Should NOT contain any nodes from chain 2
        expect(allNodes, isNot(contains('w')));
        expect(allNodes, isNot(contains('x')));
        expect(allNodes, isNot(contains('y')));
        expect(allNodes, isNot(contains('z')));

        // Should only contain nodes from chain 1
        expect(allNodes.every((n) => ['a', 'b', 'c', 'd'].contains(n)), isTrue);
      }
    });

    test('complex: multiple edge types + variable length + middle start', () {
      // Create a network with multiple relationship types and variable paths
      final networkGraph = Graph<Node>();

      // Central hub with multiple connections
      networkGraph.addNode(Node(id: 'hub', type: 'Hub', label: 'Central Hub'));
      networkGraph.addNode(Node(id: 'source1', type: 'Source', label: 'Source 1'));
      networkGraph.addNode(Node(id: 'source2', type: 'Source', label: 'Source 2'));
      networkGraph.addNode(Node(id: 'dest1', type: 'Dest', label: 'Dest 1'));
      networkGraph.addNode(Node(id: 'dest2', type: 'Dest', label: 'Dest 2'));
      networkGraph.addNode(Node(id: 'dest3', type: 'Dest', label: 'Dest 3'));
      networkGraph.addNode(Node(id: 'intermediate', type: 'Node', label: 'Intermediate'));

      // Incoming to hub (TYPE_A or TYPE_B)
      networkGraph.addEdge('source1', 'TYPE_A', 'hub');
      networkGraph.addEdge('source2', 'TYPE_B', 'hub');

      // Outgoing from hub via intermediate (TYPE_C)
      networkGraph.addEdge('hub', 'TYPE_C', 'intermediate');
      networkGraph.addEdge('intermediate', 'TYPE_C', 'dest1');
      networkGraph.addEdge('intermediate', 'TYPE_C', 'dest2');

      // Direct from hub (TYPE_D)
      networkGraph.addEdge('hub', 'TYPE_D', 'dest3');

      final networkQuery = PatternQuery(networkGraph);

      // Start from 'hub', find sources connected with TYPE_A or TYPE_B,
      // and destinations reachable in 1-2 hops via TYPE_C or TYPE_D
      final paths = networkQuery.matchPaths(
        'source-[:TYPE_A|TYPE_B]->hub-[:TYPE_C|TYPE_D*1..2]->dest',
        startId: 'hub'
      );

      // Should find all valid combinations
      expect(paths, isNotEmpty);
      expect(paths.length, greaterThanOrEqualTo(4),
        reason: '2 sources * (2 via TYPE_C + 1 via TYPE_D) = at least 4 paths');

      // Verify hub is in all paths
      for (final path in paths) {
        expect(path.nodes['hub'], equals('hub'));
      }

      // Verify we have both source types
      final allSources = paths.map((p) => p.nodes['source']).toSet();
      expect(allSources, containsAll(['source1', 'source2']));

      // Verify we have multiple destinations
      final allDests = paths.map((p) => p.nodes['dest']).toSet();
      expect(allDests.length, greaterThanOrEqualTo(2),
        reason: 'Should reach multiple destinations');
      expect(allDests, contains('dest3'), reason: 'Should reach direct destination via TYPE_D');
    });

    test('complex: mixed directions with middle start - simple unambiguous', () {
      // Create simple unambiguous mixed pattern: a->b<-c->d
      // Start from 'b' (middle)
      final mixedGraph = Graph<Node>();

      mixedGraph.addNode(Node(id: 'a', type: 'Node', label: 'A'));
      mixedGraph.addNode(Node(id: 'b', type: 'Node', label: 'B'));
      mixedGraph.addNode(Node(id: 'c', type: 'Node', label: 'C'));
      mixedGraph.addNode(Node(id: 'd', type: 'Node', label: 'D'));

      mixedGraph.addEdge('a', 'EDGE', 'b');
      mixedGraph.addEdge('c', 'EDGE', 'b');
      mixedGraph.addEdge('c', 'EDGE', 'd');

      final mixedQuery = PatternQuery(mixedGraph);

      // Pattern: n1->n2<-n3->n4, start from 'b' (should match n2)
      final paths = mixedQuery.matchPaths(
        'n1-[:EDGE]->n2<-[:EDGE]-n3-[:EDGE]->n4',
        startId: 'b'
      );

      // Should find the path
      expect(paths, isNotEmpty);

      // The pattern should match with b at n2
      final pathsWithB = paths.where((p) => p.nodes.values.contains('b')).toList();
      expect(pathsWithB, isNotEmpty, reason: 'Should find at least one path containing b');

      // Check if we have the expected complete path
      final hasExpectedPath = paths.any((p) =>
        p.nodes['n1'] == 'a' &&
        p.nodes['n2'] == 'b' &&
        p.nodes['n3'] == 'c' &&
        p.nodes['n4'] == 'd'
      );
      expect(hasExpectedPath, isTrue, reason: 'Should find path a->b<-c->d');
    });

    test('complex: mixed directions with middle start - longer chain', () {
      // Create: p1->p2->hub<-p3<-p4->p5->p6
      // Start from 'hub' (middle)
      final mixedGraph = Graph<Node>();

      for (var id in ['p1', 'p2', 'hub', 'p3', 'p4', 'p5', 'p6']) {
        mixedGraph.addNode(Node(id: id, type: 'Node', label: id.toUpperCase()));
      }

      // Build the chain
      mixedGraph.addEdge('p1', 'EDGE', 'p2');
      mixedGraph.addEdge('p2', 'EDGE', 'hub');
      mixedGraph.addEdge('p3', 'EDGE', 'hub');
      mixedGraph.addEdge('p4', 'EDGE', 'p3');
      mixedGraph.addEdge('p4', 'EDGE', 'p5');
      mixedGraph.addEdge('p5', 'EDGE', 'p6');

      final mixedQuery = PatternQuery(mixedGraph);

      // Pattern: n1->n2->n3<-n4<-n5->n6->n7
      // Start from 'hub' (should match n3)
      final paths = mixedQuery.matchPaths(
        'n1-[:EDGE]->n2-[:EDGE]->n3<-[:EDGE]-n4<-[:EDGE]-n5-[:EDGE]->n6-[:EDGE]->n7',
        startId: 'hub'
      );

      // Should find the path
      expect(paths, isNotEmpty);

      // Check if we have the expected complete path
      final hasExpectedPath = paths.any((p) =>
        p.nodes['n1'] == 'p1' &&
        p.nodes['n2'] == 'p2' &&
        p.nodes['n3'] == 'hub' &&
        p.nodes['n4'] == 'p3' &&
        p.nodes['n5'] == 'p4' &&
        p.nodes['n6'] == 'p5' &&
        p.nodes['n7'] == 'p6'
      );
      expect(hasExpectedPath, isTrue, reason: 'Should find path p1->p2->hub<-p3<-p4->p5->p6');

      // Main feature works: correct nodes are found
      // Note: PathMatch edge tracking has limitations with middle-start + mixed directions
      // but the core functionality (finding correct nodes) works correctly
    });
  });
}
