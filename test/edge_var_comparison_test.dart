import 'package:graph_kit/graph_kit.dart';
import 'package:test/test.dart';

void main() {
  group('Edge Variable Comparison in WHERE Clause', () {
    late Graph<Node> graph;
    late PatternQuery query;

    setUp(() {
      graph = Graph<Node>();
      query = PatternQuery(graph);
    });

    test('type(r2) = type(r) enforces same edge type across hops', () {
      // Setup: Source with intermediate node that has edges with different type prefixes
      graph.addNode(Node(id: 's1', type: 'Source', label: 'Source1'));
      graph.addNode(Node(id: 'mid', type: 'Intermediate', label: 'Mid1'));
      graph.addNode(Node(id: 'dest1', type: 'Dest', label: 'Dest1'));
      graph.addNode(Node(id: 'dest2', type: 'Dest', label: 'Dest2'));

      // Source uses edge type PREFIX_abc123
      graph.addEdge('s1', 'PREFIX_abc123', 'mid');

      // Intermediate has multiple outgoing edges with different suffixes
      graph.addEdge('mid', 'PREFIX_abc123', 'dest1'); // SAME type ✓
      graph.addEdge('mid', 'PREFIX_xyz789', 'dest2'); // DIFFERENT type ✗

      // Query: Both edges must have SAME type
      final results = query.match(
        'source-[r]->intermediate-[r2]->destination WHERE type(r) STARTS WITH "PREFIX_" AND type(r2) = type(r)',
        startId: 's1',
      );

      // Should only find dest1 (PREFIX_abc123), NOT dest2 (PREFIX_xyz789)
      expect(results['destination'], ['dest1']);
      expect(results['destination'], isNot(contains('dest2')));
    });

    test('type(r2) = type(r) with exact type match', () {
      graph.addNode(Node(id: 'n1', type: 'Node', label: 'N1'));
      graph.addNode(Node(id: 'n2', type: 'Node', label: 'N2'));
      graph.addNode(Node(id: 'n3', type: 'Node', label: 'N3'));
      graph.addNode(Node(id: 'n4', type: 'Node', label: 'N4'));

      graph.addEdge('n1', 'TYPE_A', 'n2');
      graph.addEdge('n2', 'TYPE_A', 'n3'); // Same type
      graph.addEdge('n2', 'TYPE_B', 'n4'); // Different type

      final results = query.match(
        'a-[r]->b-[r2]->c WHERE type(r2) = type(r)',
        startId: 'n1',
      );

      // Should only find n3 (TYPE_A -> TYPE_A)
      expect(results['c'], ['n3']);
      expect(results['c'], isNot(contains('n4')));
    });

    test('type(r2) != type(r) finds paths with DIFFERENT edge types', () {
      graph.addNode(Node(id: 'n1', type: 'Node', label: 'N1'));
      graph.addNode(Node(id: 'n2', type: 'Node', label: 'N2'));
      graph.addNode(Node(id: 'n3', type: 'Node', label: 'N3'));
      graph.addNode(Node(id: 'n4', type: 'Node', label: 'N4'));

      graph.addEdge('n1', 'TYPE_A', 'n2');
      graph.addEdge('n2', 'TYPE_A', 'n3'); // Same type - should be excluded
      graph.addEdge('n2', 'TYPE_B', 'n4'); // Different type - should match

      final results = query.match(
        'a-[r]->b-[r2]->c WHERE type(r2) != type(r)',
        startId: 'n1',
      );

      // Should only find n4 (TYPE_A -> TYPE_B, different)
      expect(results['c'], ['n4']);
      expect(results['c'], isNot(contains('n3')));
    });

    test('Three-hop path with type(r2) = type(r) AND type(r3) = type(r)', () {
      graph.addNode(Node(id: 'n1', type: 'Node', label: 'N1'));
      graph.addNode(Node(id: 'n2', type: 'Node', label: 'N2'));
      graph.addNode(Node(id: 'n3', type: 'Node', label: 'N3'));
      graph.addNode(Node(id: 'n4', type: 'Node', label: 'N4'));
      graph.addNode(Node(id: 'n5', type: 'Node', label: 'N5'));

      // Chain with consistent TYPE_A
      graph.addEdge('n1', 'TYPE_A', 'n2');
      graph.addEdge('n2', 'TYPE_A', 'n3');
      graph.addEdge('n3', 'TYPE_A', 'n4'); // All TYPE_A ✓

      // Chain that breaks at third hop
      graph.addEdge('n3', 'TYPE_B', 'n5'); // Different type ✗

      final results = query.match(
        'a-[r]->b-[r2]->c-[r3]->d WHERE type(r2) = type(r) AND type(r3) = type(r)',
        startId: 'n1',
      );

      // Should only find n4 (TYPE_A throughout)
      expect(results['d'], ['n4']);
      expect(results['d'], isNot(contains('n5')));
    });

    test('Multi-source scenario with shared intermediate node', () {
      // Setup: Multiple sources with different edge types going through shared intermediate
      graph.addNode(Node(id: 's1', type: 'Source', label: 'Source1'));
      graph.addNode(Node(id: 's2', type: 'Source', label: 'Source2'));
      graph.addNode(Node(id: 'hub', type: 'Hub', label: 'SharedHub'));
      graph.addNode(Node(id: 'dest1', type: 'Dest', label: 'Dest1'));
      graph.addNode(Node(id: 'dest2', type: 'Dest', label: 'Dest2'));
      graph.addNode(Node(id: 'dest3', type: 'Dest', label: 'Dest3'));

      // Source1 uses CATEGORY_s1
      graph.addEdge('s1', 'CATEGORY_s1', 'hub');

      // Source2 uses CATEGORY_s2
      graph.addEdge('s2', 'CATEGORY_s2', 'hub');

      // Hub has edges with both types
      graph.addEdge('hub', 'CATEGORY_s1', 'dest1'); // Matches s1
      graph.addEdge('hub', 'CATEGORY_s1', 'dest2'); // Matches s1
      graph.addEdge('hub', 'CATEGORY_s2', 'dest3'); // Matches s2

      // Query from s1: should only get dest1 and dest2
      final results1 = query.match(
        'source-[r]->hub-[r2]->dest WHERE type(r) STARTS WITH "CATEGORY_" AND type(r2) = type(r)',
        startId: 's1',
      );

      expect(results1['dest'], containsAll(['dest1', 'dest2']));
      expect(results1['dest'], isNot(contains('dest3')));

      // Query from s2: should only get dest3
      final results2 = query.match(
        'source-[r]->hub-[r2]->dest WHERE type(r) STARTS WITH "CATEGORY_" AND type(r2) = type(r)',
        startId: 's2',
      );

      expect(results2['dest'], ['dest3']);
      expect(results2['dest'], isNot(contains('dest1')));
      expect(results2['dest'], isNot(contains('dest2')));
    });

    test('matchPaths with type(r2) = type(r) should work correctly', () {
      graph.addNode(Node(id: 's1', type: 'Source', label: 'Source1'));
      graph.addNode(Node(id: 'mid', type: 'Intermediate', label: 'Mid1'));
      graph.addNode(Node(id: 'dest1', type: 'Dest', label: 'Dest1'));
      graph.addNode(Node(id: 'dest2', type: 'Dest', label: 'Dest2'));

      graph.addEdge('s1', 'LINK_abc', 'mid');
      graph.addEdge('mid', 'LINK_abc', 'dest1'); // Same type
      graph.addEdge('mid', 'LINK_xyz', 'dest2'); // Different type

      final paths = query.matchPaths(
        'source-[r]->intermediate-[r2]->dest WHERE type(r2) = type(r)',
        startId: 's1',
      );

      // Should only find 1 path (to dest1)
      expect(paths.length, 1);
      expect(paths.first.nodes['dest'], 'dest1');

      // Verify edges have correct types
      expect(paths.first.edges.length, 2);
      expect(paths.first.edges[0].type, 'LINK_abc');
      expect(paths.first.edges[1].type, 'LINK_abc');
    });

    test('Backward compatibility: patterns without variable comparison still work', () {
      graph.addNode(Node(id: 'n1', type: 'Node', label: 'N1'));
      graph.addNode(Node(id: 'n2', type: 'Node', label: 'N2'));
      graph.addNode(Node(id: 'n3', type: 'Node', label: 'N3'));

      graph.addEdge('n1', 'TYPE_A', 'n2');
      graph.addEdge('n2', 'TYPE_B', 'n3');

      // Old-style WHERE clause (literal comparison only)
      final results = query.match(
        'a-[r]->b-[r2]->c WHERE type(r) = "TYPE_A"',
        startId: 'n1',
      );

      expect(results['c'], ['n3']);
    });

    test('type(r2) = type(r) with STARTS WITH prefix filter', () {
      graph.addNode(Node(id: 's1', type: 'Source', label: 'Source1'));
      graph.addNode(Node(id: 'hub', type: 'Hub', label: 'Hub1'));
      graph.addNode(Node(id: 'dest1', type: 'Dest', label: 'Dest1'));
      graph.addNode(Node(id: 'dest2', type: 'Dest', label: 'Dest2'));
      graph.addNode(Node(id: 'dest3', type: 'Dest', label: 'Dest3'));

      graph.addEdge('s1', 'TAG_abc123', 'hub');
      graph.addEdge('hub', 'TAG_abc123', 'dest1'); // Same, starts with TAG_ ✓
      graph.addEdge('hub', 'TAG_xyz789', 'dest2'); // Different, but starts with TAG_ ✗
      graph.addEdge('hub', 'OTHER_abc123', 'dest3'); // Doesn't start with TAG_ ✗

      final results = query.match(
        'source-[r]->hub-[r2]->dest WHERE type(r) STARTS WITH "TAG_" AND type(r2) = type(r)',
        startId: 's1',
      );

      // Should only find dest1 (exact match on TAG_abc123)
      expect(results['dest'], ['dest1']);
      expect(results['dest'], isNot(contains('dest2')));
      expect(results['dest'], isNot(contains('dest3')));
    });

    test('Complex multi-hop with mixed literal and variable comparisons', () {
      graph.addNode(Node(id: 'n1', type: 'TypeA', label: 'N1'));
      graph.addNode(Node(id: 'n2', type: 'TypeB', label: 'N2'));
      graph.addNode(Node(id: 'n3', type: 'TypeB', label: 'N3'));
      graph.addNode(Node(id: 'n4', type: 'TypeB', label: 'N4'));

      graph.addEdge('n1', 'CONNECTS', 'n2');
      graph.addEdge('n2', 'CONNECTS', 'n3'); // Same edge type
      graph.addEdge('n2', 'LINKS', 'n4'); // Different edge type

      // First edge must be "CONNECTS", second must match first
      final results = query.match(
        'a:TypeA-[r]->b:TypeB-[r2]->c:TypeB WHERE type(r) = "CONNECTS" AND type(r2) = type(r)',
        startId: 'n1',
      );

      expect(results['c'], ['n3']);
      expect(results['c'], isNot(contains('n4')));
    });
  });
}
