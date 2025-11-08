import 'package:graph_kit/graph_kit.dart';
import 'package:test/test.dart';

void main() {
  group('Edge variable binding and WHERE type() filtering', () {
    late Graph<Node> graph;
    late PatternQuery<Node> query;

    test('Test 1: Policy-Asset Access Control (Real Use Case)', () {
      graph = Graph<Node>();

      // 2 policies, 3 assets
      graph.addNode(Node(id: 'p1', type: 'Policy', label: 'Admin Policy'));
      graph.addNode(Node(id: 'p2', type: 'Policy', label: 'User Policy'));
      graph.addNode(Node(id: 'a1', type: 'Asset', label: 'Server1'));
      graph.addNode(Node(id: 'a2', type: 'Asset', label: 'Server2'));
      graph.addNode(Node(id: 'a3', type: 'Asset', label: 'Server3'));

      // Policy 1: access to a1, a2
      graph.addEdge('p1', 'DIRECT_p1', 'a1');
      graph.addEdge('p1', 'DIRECT_p1', 'a2');

      // Policy 2: access to a2, a3
      graph.addEdge('p2', 'DIRECT_p2', 'a2');
      graph.addEdge('p2', 'DIRECT_p2', 'a3');

      query = PatternQuery(graph);

      // Click on Policy 1 - should only show a1, a2
      final results = query.match(
        'policy-[r]->asset WHERE type(r) STARTS WITH "DIRECT_p1"',
        startId: 'p1'
      );

      expect(results['asset'], containsAll(['a1', 'a2']));
      expect(results['asset']!.length, 2);
      expect(results['asset'], isNot(contains('a3')));
    });

    test('Test 2: Wildcard edge binding [r] matches all edge types', () {
      graph = Graph<Node>();
      graph.addNode(Node(id: 'n1', type: 'Node', label: 'Node1'));
      graph.addNode(Node(id: 'n2', type: 'Node', label: 'Node2'));
      graph.addNode(Node(id: 'n3', type: 'Node', label: 'Node3'));

      graph.addEdge('n1', 'TYPE_A', 'n2');
      graph.addEdge('n1', 'TYPE_B', 'n3');

      query = PatternQuery(graph);

      // [r] without type should match both edges
      final paths = query.matchPaths('n-[r]->m', startId: 'n1');

      expect(paths.length, 2, reason: '[r] should match both TYPE_A and TYPE_B edges');
    });

    test('Test 3: WHERE type(r) with exact match', () {
      graph = Graph<Node>();
      graph.addNode(Node(id: 'hub', type: 'Hub', label: 'Hub'));
      graph.addNode(Node(id: 'd1', type: 'Device', label: 'Device1'));
      graph.addNode(Node(id: 'd2', type: 'Device', label: 'Device2'));

      graph.addEdge('hub', 'DIRECT_ACCESS', 'd1');
      graph.addEdge('hub', 'INDIRECT_ACCESS', 'd2');

      query = PatternQuery(graph);

      final results = query.match(
        'hub-[r]->dest WHERE type(r) = "DIRECT_ACCESS"'
      );

      expect(results['dest'], contains('d1'));
      expect(results['dest'], isNot(contains('d2')));
      expect(results['dest']!.length, 1);
    });

    test('Test 4: STARTS WITH operator filters edge types by prefix', () {
      graph = Graph<Node>();
      graph.addNode(Node(id: 'hub', type: 'Hub', label: 'Hub'));
      graph.addNode(Node(id: 'd1', type: 'Device', label: 'Device1'));
      graph.addNode(Node(id: 'd2', type: 'Device', label: 'Device2'));
      graph.addNode(Node(id: 'other', type: 'Other', label: 'Other'));

      graph.addEdge('hub', 'DIRECT_ACCESS', 'd1');
      graph.addEdge('hub', 'DIRECT_MANAGE', 'd2');
      graph.addEdge('hub', 'INDIRECT_VIEW', 'other');

      query = PatternQuery(graph);

      final results = query.match(
        'hub-[r]->dest WHERE type(r) STARTS WITH "DIRECT_"'
      );

      expect(results['dest'], containsAll(['d1', 'd2']));
      expect(results['dest'], isNot(contains('other')));
      expect(results['dest']!.length, 2);
    });

    test('Test 5: Multiple edge types with filtering', () {
      graph = Graph<Node>();
      graph.addNode(Node(id: 'p', type: 'Policy', label: 'Policy'));
      graph.addNode(Node(id: 'a1', type: 'Asset', label: 'Asset1'));
      graph.addNode(Node(id: 'a2', type: 'Asset', label: 'Asset2'));
      graph.addNode(Node(id: 'a3', type: 'Asset', label: 'Asset3'));

      graph.addEdge('p', 'DIRECT_123', 'a1');
      graph.addEdge('p', 'DIRECT_456', 'a2');
      graph.addEdge('p', 'GRANTS_ACCESS', 'a3');

      query = PatternQuery(graph);

      final results = query.match(
        'p-[r]->a WHERE type(r) STARTS WITH "DIRECT_"'
      );

      expect(results['a'], containsAll(['a1', 'a2']));
      expect(results['a'], isNot(contains('a3')));
    });

    test('Test 6: Combined node and edge filtering', () {
      graph = Graph<Node>();
      graph.addNode(Node(id: 'p', type: 'Policy', label: 'Policy'));
      graph.addNode(Node(id: 'a1', type: 'Asset', label: 'Active Asset', properties: {'status': 'active'}));
      graph.addNode(Node(id: 'a2', type: 'Asset', label: 'Inactive Asset', properties: {'status': 'inactive'}));
      graph.addNode(Node(id: 'a3', type: 'Asset', label: 'Active Asset 2', properties: {'status': 'active'}));

      graph.addEdge('p', 'DIRECT_p', 'a1');
      graph.addEdge('p', 'DIRECT_p', 'a2');
      graph.addEdge('p', 'GRANTS_ACCESS', 'a3');

      query = PatternQuery(graph);

      final results = query.match(
        'p-[r]->a:Asset WHERE type(r) STARTS WITH "DIRECT_" AND a.status = "active"'
      );

      expect(results['a'], contains('a1'));
      expect(results['a'], isNot(contains('a2')), reason: 'Should exclude inactive asset');
      expect(results['a'], isNot(contains('a3')), reason: 'Should exclude GRANTS_ACCESS edge');
      expect(results['a']!.length, 1);
    });

    test('Test 7: Multiple edge variables in same pattern', () {
      graph = Graph<Node>();
      graph.addNode(Node(id: 'a', type: 'Node', label: 'A'));
      graph.addNode(Node(id: 'b', type: 'Node', label: 'B'));
      graph.addNode(Node(id: 'c', type: 'Node', label: 'C'));

      graph.addEdge('a', 'WORKS_FOR', 'b');
      graph.addEdge('b', 'MANAGES', 'c');
      graph.addEdge('b', 'REPORTS_TO', 'c'); // Alternative edge

      query = PatternQuery(graph);

      final paths = query.matchPaths(
        'a-[r1]->b-[r2]->c WHERE type(r1) = "WORKS_FOR" AND type(r2) = "MANAGES"'
      );

      expect(paths.length, 1);
      expect(paths[0].nodes['a'], 'a');
      expect(paths[0].nodes['b'], 'b');
      expect(paths[0].nodes['c'], 'c');
    });

    test('Test 8: Edge variable in RETURN clause', () {
      graph = Graph<Node>();
      graph.addNode(Node(id: 'n1', type: 'Node', label: 'Node1'));
      graph.addNode(Node(id: 'n2', type: 'Node', label: 'Node2'));

      graph.addEdge('n1', 'CONNECTS_TO', 'n2');

      query = PatternQuery(graph);

      final results = query.matchRows('n1-[r]->n2 RETURN n1, n2, r');

      expect(results.length, 1);
      expect(results[0]['n1'], 'n1');
      expect(results[0]['n2'], 'n2');
      expect(results[0]['r'], 'CONNECTS_TO');
    });

    test('Test 9: Backward compatibility - patterns without edge variables', () {
      graph = Graph<Node>();
      graph.addNode(Node(id: 'n1', type: 'Node', label: 'Node1'));
      graph.addNode(Node(id: 'n2', type: 'Node', label: 'Node2'));

      graph.addEdge('n1', 'EDGE_TYPE', 'n2');

      query = PatternQuery(graph);

      // Old style without edge variable should still work
      final results = query.match('n1:Node-[:EDGE_TYPE]->n2:Node');

      expect(results['n1'], contains('n1'));
      expect(results['n2'], contains('n2'));
    });

    test('Test 10: Edge variable with explicit type [r:TYPE]', () {
      graph = Graph<Node>();
      graph.addNode(Node(id: 'n1', type: 'Node', label: 'Node1'));
      graph.addNode(Node(id: 'n2', type: 'Node', label: 'Node2'));
      graph.addNode(Node(id: 'n3', type: 'Node', label: 'Node3'));

      graph.addEdge('n1', 'TYPE_A', 'n2');
      graph.addEdge('n1', 'TYPE_B', 'n3');

      query = PatternQuery(graph);

      // Bind edge variable with type constraint
      final results = query.match('n1-[r:TYPE_A]->n2');

      expect(results['n1'], contains('n1'));
      expect(results['n2'], contains('n2'));
      expect(results['n2'], isNot(contains('n3')));
    });
  });
}
