import 'package:graph_kit/graph_kit.dart';
import 'package:test/test.dart';

void main() {
  group('Edge Variables in matchPaths()', () {
    late Graph<Node> graph;
    late PatternQuery query;

    setUp(() {
      graph = Graph<Node>();
      query = PatternQuery(graph);
    });

    test('PathMatch.nodes should NOT include edge variables', () {
      // Setup graph
      graph.addNode(Node(id: 'n1', type: 'Node', label: 'Node1'));
      graph.addNode(Node(id: 'n2', type: 'Node', label: 'Node2'));
      graph.addEdge('n1', 'CONNECTS', 'n2');

      // Query with edge variable
      final paths = query.matchPaths('a-[r:CONNECTS]->b', startId: 'n1');

      expect(paths.length, 1);
      final path = paths.first;

      // Path nodes should only have 'a' and 'b', NOT 'r'
      expect(path.nodes.keys, containsAll(['a', 'b']));
      expect(path.nodes.keys, isNot(contains('r')));
      expect(path.nodes['a'], 'n1');
      expect(path.nodes['b'], 'n2');
    });

    test('matchPaths with WHERE and edge variables should exclude edge vars from nodes', () {
      graph.addNode(Node(id: 'p1', type: 'Policy', label: 'Policy1'));
      graph.addNode(Node(id: 'a1', type: 'Asset', label: 'Asset1'));
      graph.addNode(Node(id: 'a2', type: 'Asset', label: 'Asset2'));
      graph.addEdge('p1', 'DIRECT_p1', 'a1');
      graph.addEdge('p1', 'RELAY_p1', 'a2');

      final paths = query.matchPaths(
        'policy-[r]->asset WHERE type(r) STARTS WITH "DIRECT"',
        startId: 'p1',
      );

      expect(paths.length, 1);
      final path = paths.first;

      // Should only have policy and asset, not r
      expect(path.nodes.keys, containsAll(['policy', 'asset']));
      expect(path.nodes.keys, isNot(contains('r')));
      expect(path.nodes['policy'], 'p1');
      expect(path.nodes['asset'], 'a1');
    });

    test('Multiple edge variables should all be excluded from nodes', () {
      graph.addNode(Node(id: 'n1', type: 'Node', label: 'N1'));
      graph.addNode(Node(id: 'n2', type: 'Node', label: 'N2'));
      graph.addNode(Node(id: 'n3', type: 'Node', label: 'N3'));
      graph.addEdge('n1', 'TYPE_A', 'n2');
      graph.addEdge('n2', 'TYPE_B', 'n3');

      final paths = query.matchPaths('a-[r1]->b-[r2]->c', startId: 'n1');

      expect(paths.length, 1);
      final path = paths.first;

      // Should only have a, b, c - not r1 or r2
      expect(path.nodes.keys, containsAll(['a', 'b', 'c']));
      expect(path.nodes.keys, isNot(contains('r1')));
      expect(path.nodes.keys, isNot(contains('r2')));
      expect(path.nodes['a'], 'n1');
      expect(path.nodes['b'], 'n2');
      expect(path.nodes['c'], 'n3');
    });

    test('Wildcard edge variable [r] should not appear in nodes', () {
      graph.addNode(Node(id: 'n1', type: 'Node', label: 'N1'));
      graph.addNode(Node(id: 'n2', type: 'Node', label: 'N2'));
      graph.addNode(Node(id: 'n3', type: 'Node', label: 'N3'));
      graph.addEdge('n1', 'TYPE_A', 'n2');
      graph.addEdge('n1', 'TYPE_B', 'n3');

      final paths = query.matchPaths('n-[r]->m', startId: 'n1');

      expect(paths.length, 2); // Both TYPE_A and TYPE_B
      for (final path in paths) {
        expect(path.nodes.keys, containsAll(['n', 'm']));
        expect(path.nodes.keys, isNot(contains('r')));
      }
    });

    test('Edge variables in multi-hop relay pattern should be excluded', () {
      graph.addNode(Node(id: 'p1', type: 'Policy', label: 'P1'));
      graph.addNode(Node(id: 'relay1', type: 'Relay', label: 'Relay1'));
      graph.addNode(Node(id: 'dest1', type: 'Dest', label: 'Dest1'));
      graph.addEdge('p1', 'VIRTUAL_p1', 'relay1');
      graph.addEdge('relay1', 'VIRTUAL_p1', 'dest1');

      final paths = query.matchPaths(
        'policy-[r1]->relay-[r2]->destination WHERE type(r1) STARTS WITH "VIRTUAL" AND type(r2) STARTS WITH "VIRTUAL"',
        startId: 'p1',
      );

      expect(paths.length, 1);
      final path = paths.first;

      // Should have policy, relay, destination but NOT r1 or r2
      expect(path.nodes.keys, containsAll(['policy', 'relay', 'destination']));
      expect(path.nodes.keys, isNot(contains('r1')));
      expect(path.nodes.keys, isNot(contains('r2')));
    });

    test('Backward compatibility: patterns without edge variables work unchanged', () {
      graph.addNode(Node(id: 'n1', type: 'Node', label: 'N1'));
      graph.addNode(Node(id: 'n2', type: 'Node', label: 'N2'));
      graph.addEdge('n1', 'CONNECTS', 'n2');

      final paths = query.matchPaths('a-[:CONNECTS]->b', startId: 'n1');

      expect(paths.length, 1);
      final path = paths.first;

      expect(path.nodes.keys, containsAll(['a', 'b']));
      expect(path.nodes['a'], 'n1');
      expect(path.nodes['b'], 'n2');
    });

    test('match() derived from matchPaths should also exclude edge variables', () {
      graph.addNode(Node(id: 'n1', type: 'Node', label: 'N1'));
      graph.addNode(Node(id: 'n2', type: 'Node', label: 'N2'));
      graph.addEdge('n1', 'TYPE_A', 'n2');

      final results = query.match('a-[r:TYPE_A]->b', startId: 'n1');

      // Should only have 'a' and 'b' keys, not 'r'
      expect(results.keys, containsAll(['a', 'b']));
      expect(results.keys, isNot(contains('r')));
      expect(results['a'], contains('n1'));
      expect(results['b'], contains('n2'));
    });

    test('RETURN clause with edge variables should exclude them from path nodes', () {
      graph.addNode(Node(id: 'n1', type: 'Node', label: 'N1'));
      graph.addNode(Node(id: 'n2', type: 'Node', label: 'N2'));
      graph.addEdge('n1', 'TYPE_A', 'n2');

      final paths = query.matchPaths('a-[r]->b RETURN a, b', startId: 'n1');

      expect(paths.length, 1);
      final path = paths.first;

      // Even with RETURN, edge variables should not be in nodes
      expect(path.nodes.keys, containsAll(['a', 'b']));
      expect(path.nodes.keys, isNot(contains('r')));
    });

    test('Complex real-world scenario: policy drill-down with multiple edge types', () {
      // Setup: UserGroup -> Policy -> (Assets via different edge types)
      graph.addNode(Node(id: 'ug1', type: 'UserGroup', label: 'Admins'));
      graph.addNode(Node(id: 'p1', type: 'Policy', label: 'Admin Policy'));
      graph.addNode(Node(id: 'a1', type: 'Asset', label: 'Server1'));
      graph.addNode(Node(id: 'a2', type: 'Asset', label: 'Server2'));
      graph.addNode(Node(id: 'a3', type: 'Asset', label: 'Database1'));

      graph.addEdge('ug1', 'HAS_POLICY', 'p1');
      graph.addEdge('p1', 'DIRECT_p1', 'a1');
      graph.addEdge('p1', 'DIRECT_p1', 'a2');
      graph.addEdge('p1', 'INDIRECT_p1', 'a3');

      final paths = query.matchPaths(
        'group-[:HAS_POLICY]->policy-[r]->asset WHERE type(r) STARTS WITH "DIRECT"',
        startId: 'p1',
        startType: 'Policy',
      );

      // Should find 2 paths (a1 and a2), not a3
      expect(paths.length, 2);

      for (final path in paths) {
        // Each path should have group, policy, asset but NOT r
        expect(path.nodes.keys, containsAll(['group', 'policy', 'asset']));
        expect(path.nodes.keys, isNot(contains('r')));

        // All paths should go through p1
        expect(path.nodes['policy'], 'p1');

        // Assets should only be a1 or a2, never a3
        expect(path.nodes['asset'], isIn(['a1', 'a2']));
      }
    });
  });
}
