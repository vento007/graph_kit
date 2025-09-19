import 'package:test/test.dart';
import 'package:graph_kit/graph_kit.dart';

void main() {
  test('basic graph operations', () {
    final graph = Graph<Node>();
    final query = PatternQuery(graph);

    // Add nodes
    graph.addNode(Node(id: 'alice', type: 'User', label: 'Alice'));
    graph.addNode(Node(id: 'admins', type: 'Group', label: 'Administrators'));

    // Add edge
    graph.addEdge('alice', 'MEMBER_OF', 'admins');

    // Test basic operations
    expect(graph.nodesById.length, 2);
    expect(graph.hasEdge('alice', 'MEMBER_OF', 'admins'), isTrue);
    expect(graph.outNeighbors('alice', 'MEMBER_OF'), contains('admins'));

    // Test pattern query
    final results = query.match('user-[:MEMBER_OF]->group', startId: 'alice');
    expect(results['user'], contains('alice'));
    expect(results['group'], contains('admins'));
  });

  group('matchPaths functionality', () {
    late Graph<Node> graph;
    late PatternQuery<Node> query;

    setUp(() {
      graph = Graph<Node>();
      query = PatternQuery(graph);

      // Create test data: person -> team -> project structure
      graph.addNode(Node(id: 'alice', type: 'Person', label: 'Alice Cooper'));
      graph.addNode(Node(id: 'bob', type: 'Person', label: 'Bob Wilson'));
      graph.addNode(
        Node(id: 'engineering', type: 'Team', label: 'Engineering'),
      );
      graph.addNode(
        Node(id: 'web_app', type: 'Project', label: 'Web Application'),
      );
      graph.addNode(
        Node(id: 'mobile_app', type: 'Project', label: 'Mobile App'),
      );

      // Add edges
      graph.addEdge('alice', 'WORKS_FOR', 'engineering');
      graph.addEdge('bob', 'WORKS_FOR', 'engineering');
      graph.addEdge('engineering', 'ASSIGNED_TO', 'web_app');
      graph.addEdge('engineering', 'ASSIGNED_TO', 'mobile_app');
      graph.addEdge('alice', 'LEADS', 'web_app');
    });

    test('matchPaths returns PathMatch objects with nodes and edges', () {
      final paths = query.matchPaths('person-[:WORKS_FOR]->team');

      expect(paths.length, 2); // alice and bob both work for engineering

      // Check first path
      final path1 = paths.first;
      expect(path1.nodes.length, 2);
      expect(path1.nodes, containsPair('person', 'alice'));
      expect(path1.nodes, containsPair('team', 'engineering'));

      expect(path1.edges.length, 1);
      final edge = path1.edges.first;
      expect(edge.from, 'alice');
      expect(edge.to, 'engineering');
      expect(edge.type, 'WORKS_FOR');
      expect(edge.fromVariable, 'person');
      expect(edge.toVariable, 'team');
    });

    test('matchPaths handles multi-hop paths correctly', () {
      final paths = query.matchPaths(
        'person-[:WORKS_FOR]->team-[:ASSIGNED_TO]->project',
      );

      expect(paths.length, 4); // 2 people × 2 projects

      final alicePaths = paths
          .where((p) => p.nodes['person'] == 'alice')
          .toList();
      expect(alicePaths.length, 2);

      final pathToWebApp = alicePaths.firstWhere(
        (p) => p.nodes['project'] == 'web_app',
      );
      expect(pathToWebApp.edges.length, 2);

      // First edge: alice WORKS_FOR engineering
      final firstEdge = pathToWebApp.edges[0];
      expect(firstEdge.from, 'alice');
      expect(firstEdge.to, 'engineering');
      expect(firstEdge.type, 'WORKS_FOR');
      expect(firstEdge.fromVariable, 'person');
      expect(firstEdge.toVariable, 'team');

      // Second edge: engineering ASSIGNED_TO web_app
      final secondEdge = pathToWebApp.edges[1];
      expect(secondEdge.from, 'engineering');
      expect(secondEdge.to, 'web_app');
      expect(secondEdge.type, 'ASSIGNED_TO');
      expect(secondEdge.fromVariable, 'team');
      expect(secondEdge.toVariable, 'project');
    });

    test('matchPaths handles backward edges correctly', () {
      final paths = query.matchPaths('project<-[:LEADS]-person');

      expect(paths.length, 1); // only alice leads web_app

      final path = paths.first;
      expect(path.nodes['person'], 'alice');
      expect(path.nodes['project'], 'web_app');

      expect(path.edges.length, 1);
      final edge = path.edges.first;
      expect(edge.from, 'alice'); // Edge should be from alice to web_app
      expect(edge.to, 'web_app');
      expect(edge.type, 'LEADS');
      expect(edge.fromVariable, 'person');
      expect(edge.toVariable, 'project');
    });

    test('matchPaths with startId filters results correctly', () {
      final paths = query.matchPaths(
        'person-[:WORKS_FOR]->team-[:ASSIGNED_TO]->project',
        startId: 'alice',
      );

      expect(paths.length, 2); // alice connected to 2 projects
      expect(paths.every((p) => p.nodes['person'] == 'alice'), isTrue);
    });

    test('matchPaths returns empty list for non-matching patterns', () {
      final paths = query.matchPaths(
        'person-[:MANAGES]->team',
      ); // No MANAGES edges

      expect(paths, isEmpty);
    });

    test('matchPaths handles MATCH keyword correctly', () {
      final paths1 = query.matchPaths('person-[:WORKS_FOR]->team');
      final paths2 = query.matchPaths('MATCH person-[:WORKS_FOR]->team');

      expect(paths1.length, paths2.length);
      expect(paths1.first.nodes, paths2.first.nodes);
      expect(paths1.first.edges.first.type, paths2.first.edges.first.type);
    });

    test('PathEdge toString() provides readable output', () {
      final paths = query.matchPaths('person-[:WORKS_FOR]->team');
      final edge = paths.first.edges.first;
      final string = edge.toString();

      expect(string, contains('person(alice)'));
      expect(string, contains('-[:WORKS_FOR]->'));
      expect(string, contains('team(engineering)'));
    });

    test('PathMatch equality works correctly', () {
      final paths1 = query.matchPaths('person-[:WORKS_FOR]->team');
      final paths2 = query.matchPaths('person-[:WORKS_FOR]->team');

      expect(paths1.first, equals(paths2.first));
    });
  });

  group('matchPathsMany functionality', () {
    late Graph<Node> graph;
    late PatternQuery<Node> query;

    setUp(() {
      graph = Graph<Node>();
      query = PatternQuery(graph);

      graph.addNode(Node(id: 'alice', type: 'Person', label: 'Alice'));
      graph.addNode(
        Node(id: 'engineering', type: 'Team', label: 'Engineering'),
      );
      graph.addNode(Node(id: 'web_app', type: 'Project', label: 'Web App'));

      graph.addEdge('alice', 'WORKS_FOR', 'engineering');
      graph.addEdge('alice', 'LEADS', 'web_app');
    });

    test('matchPathsMany combines multiple patterns', () {
      final paths = query.matchPathsMany([
        'person-[:WORKS_FOR]->team',
        'person-[:LEADS]->project',
      ]);

      expect(paths.length, 2); // One path for each pattern

      final worksPaths = paths.where((p) => p.edges.first.type == 'WORKS_FOR');
      final leadsPaths = paths.where((p) => p.edges.first.type == 'LEADS');

      expect(worksPaths.length, 1);
      expect(leadsPaths.length, 1);
    });

    test('matchPathsMany deduplicates identical paths', () {
      final paths = query.matchPathsMany([
        'person-[:WORKS_FOR]->team',
        'person-[:WORKS_FOR]->team', // Duplicate pattern
      ]);

      expect(paths.length, 1); // Should be deduplicated
    });
  });

  group('match() method correctness', () {
    late Graph<Node> graph;
    late PatternQuery<Node> query;

    setUp(() {
      graph = Graph<Node>();
      query = PatternQuery(graph);

      // Create test data similar to demo app
      graph.addNode(Node(id: 'alice', type: 'Person', label: 'Alice Cooper'));
      graph.addNode(Node(id: 'bob', type: 'Person', label: 'Bob Wilson'));
      graph.addNode(
        Node(id: 'charlie', type: 'Person', label: 'Charlie Davis'),
      );
      graph.addNode(
        Node(id: 'engineering', type: 'Team', label: 'Engineering'),
      );
      graph.addNode(
        Node(id: 'web_app', type: 'Project', label: 'Web Application'),
      );

      // Only Alice leads a project
      graph.addEdge('alice', 'LEADS', 'web_app');

      // All people work for engineering (for contrast)
      graph.addEdge('alice', 'WORKS_FOR', 'engineering');
      graph.addEdge('bob', 'WORKS_FOR', 'engineering');
      graph.addEdge('charlie', 'WORKS_FOR', 'engineering');
    });

    test('match() should only return nodes in actual connected paths', () {
      // This pattern should only match Alice (who actually leads a project)
      final results = query.match('person:Person-[:LEADS]->project:Project');

      // Should only return Alice, not all people
      expect(results['person'], equals({'alice'}));
      expect(results['project'], equals({'web_app'}));

      // Should NOT include bob or charlie who don't lead any projects
      expect(results['person'], isNot(contains('bob')));
      expect(results['person'], isNot(contains('charlie')));
    });

    test('match() should be consistent with matchPaths() results', () {
      final matchResults = query.match(
        'person:Person-[:LEADS]->project:Project',
      );
      final pathResults = query.matchPaths(
        'person:Person-[:LEADS]->project:Project',
      );

      // Extract nodes from paths for comparison
      final pathNodes = <String, Set<String>>{};
      for (final path in pathResults) {
        for (final entry in path.nodes.entries) {
          pathNodes.putIfAbsent(entry.key, () => <String>{}).add(entry.value);
        }
      }

      // match() and matchPaths() should return the same nodes
      expect(matchResults, equals(pathNodes));
    });

    test('contrasting test: WORKS_FOR should return all connected people', () {
      // This should return all people since all work for engineering
      final results = query.match('person:Person-[:WORKS_FOR]->team:Team');

      expect(results['person'], equals({'alice', 'bob', 'charlie'}));
      expect(results['team'], equals({'engineering'}));
    });
  });
}
