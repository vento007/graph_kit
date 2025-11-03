import 'package:test/test.dart';
import 'package:graph_kit/graph_kit.dart';

void main() {
  group('GraphLayout', () {
    test('simple linear path - basic depth assignment', () {
      // Graph: alice -> bob -> charlie -> dave
      final graph = Graph<Node>();
      graph.addNode(Node(id: 'alice', type: 'Person', label: 'Alice'));
      graph.addNode(Node(id: 'bob', type: 'Person', label: 'Bob'));
      graph.addNode(Node(id: 'charlie', type: 'Person', label: 'Charlie'));
      graph.addNode(Node(id: 'dave', type: 'Person', label: 'Dave'));

      graph.addEdge('alice', 'KNOWS', 'bob');
      graph.addEdge('bob', 'KNOWS', 'charlie');
      graph.addEdge('charlie', 'KNOWS', 'dave');

      final query = PatternQuery(graph);
      final paths = query.matchPaths(
        'a-[:KNOWS]->b-[:KNOWS]->c-[:KNOWS]->d',
        startId: 'alice',
      );

      final layout = paths.computeLayout();

      // Verify node depths
      expect(layout.nodeDepths['alice'], 0);
      expect(layout.nodeDepths['bob'], 1);
      expect(layout.nodeDepths['charlie'], 2);
      expect(layout.nodeDepths['dave'], 3);

      // Verify variable depths
      expect(layout.variableDepths['a'], 0);
      expect(layout.variableDepths['b'], 1);
      expect(layout.variableDepths['c'], 2);
      expect(layout.variableDepths['d'], 3);

      // Verify roots and max depth
      expect(layout.roots, {'alice'});
      expect(layout.maxDepth, 3);

      // Verify layers
      expect(layout.nodesInLayer(0), {'alice'});
      expect(layout.nodesInLayer(1), {'bob'});
      expect(layout.nodesInLayer(2), {'charlie'});
      expect(layout.nodesInLayer(3), {'dave'});
    });

    test('diamond pattern - node at max depth from multiple paths', () {
      // Graph:     alice
      //           /     \
      //         bob     charlie
      //           \     /
      //            dave
      final graph = Graph<Node>();
      graph.addNode(Node(id: 'alice', type: 'Person', label: 'Alice'));
      graph.addNode(Node(id: 'bob', type: 'Person', label: 'Bob'));
      graph.addNode(Node(id: 'charlie', type: 'Person', label: 'Charlie'));
      graph.addNode(Node(id: 'dave', type: 'Person', label: 'Dave'));

      graph.addEdge('alice', 'KNOWS', 'bob');
      graph.addEdge('alice', 'KNOWS', 'charlie');
      graph.addEdge('bob', 'KNOWS', 'dave');
      graph.addEdge('charlie', 'KNOWS', 'dave');

      final query = PatternQuery(graph);
      final paths = query.matchPaths('a-[:KNOWS]->b-[:KNOWS]->c', startId: 'alice');

      final layout = paths.computeLayout();

      // Expected: dave should be at MAX depth (2, not 1)
      expect(layout.nodeDepths['alice'], 0);
      expect(layout.nodeDepths['bob'], 1);
      expect(layout.nodeDepths['charlie'], 1);
      expect(layout.nodeDepths['dave'], 2);

      // Verify layer grouping
      expect(layout.nodesByLayer[0], {'alice'});
      expect(layout.nodesByLayer[1], {'bob', 'charlie'});
      expect(layout.nodesByLayer[2], {'dave'});

      expect(layout.maxDepth, 2);
    });

    test('orphan nodes - variable median depth handles outliers', () {
      // Graph:
      //   g1 -> p1 -> a1
      //   g2 -> p2 -> a2
      //   p_orphan -> a3  (orphan policy, no group)
      final graph = Graph<Node>();
      graph.addNode(Node(id: 'g1', type: 'Group', label: 'Group 1'));
      graph.addNode(Node(id: 'g2', type: 'Group', label: 'Group 2'));
      graph.addNode(Node(id: 'p1', type: 'Policy', label: 'Policy 1'));
      graph.addNode(Node(id: 'p2', type: 'Policy', label: 'Policy 2'));
      graph.addNode(Node(id: 'p_orphan', type: 'Policy', label: 'Orphan Policy'));
      graph.addNode(Node(id: 'a1', type: 'Asset', label: 'Asset 1'));
      graph.addNode(Node(id: 'a2', type: 'Asset', label: 'Asset 2'));
      graph.addNode(Node(id: 'a3', type: 'Asset', label: 'Asset 3'));

      graph.addEdge('g1', 'CONTAINS', 'p1');
      graph.addEdge('g2', 'CONTAINS', 'p2');
      graph.addEdge('p1', 'APPLIES', 'a1');
      graph.addEdge('p2', 'APPLIES', 'a2');
      graph.addEdge('p_orphan', 'APPLIES', 'a3');

      final query = PatternQuery(graph);
      final pathsWithGroup = query.matchPaths('group-[:CONTAINS]->policy-[:APPLIES]->asset');
      final pathsOrphan = query.matchPaths('policy-[:APPLIES]->asset', startId: 'p_orphan');

      final allPaths = [...pathsWithGroup, ...pathsOrphan];
      final layout = allPaths.computeLayout();

      // Node depths (MAX):
      expect(layout.nodeDepths['g1'], 0);
      expect(layout.nodeDepths['g2'], 0);
      expect(layout.nodeDepths['p1'], 1);
      expect(layout.nodeDepths['p2'], 1);
      expect(layout.nodeDepths['p_orphan'], 0); // Orphan at depth 0

      // Variable depths (MEDIAN):
      // 'policy': [0, 1, 1] -> sorted -> median at index 1 = 1
      expect(layout.variableDepths['policy'], 1); // Median is 1, not 0!
      expect(layout.variableDepths['group'], 0);
      expect(layout.variableDepths['asset'], greaterThan(0));
    });

    test('access control graph - eliminates hardcoding', () {
      // Real-world scenario: group -> policy -> asset -> virtualAsset
      final graph = Graph<Node>();

      graph.addNode(Node(id: 'eng', type: 'Group', label: 'Engineering'));
      graph.addNode(Node(id: 'pol1', type: 'Policy', label: 'SSH Access'));
      graph.addNode(Node(id: 'srv1', type: 'Asset', label: 'Web Server'));
      graph.addNode(Node(id: 'virt1', type: 'Virtual', label: 'SSH Port'));

      graph.addEdge('eng', 'CONTAINS', 'pol1');
      graph.addEdge('pol1', 'APPLIES_TO', 'srv1');
      graph.addEdge('srv1', 'CONNECTS_TO', 'virt1');

      final query = PatternQuery(graph);
      final paths = query.matchPaths(
        'group-[:CONTAINS]->policy-[:APPLIES_TO]->asset-[:CONNECTS_TO]->virtual',
      );

      final layout = paths.computeLayout();

      // This is what replaces hardcoded switch statements!
      final groupLayer = layout.variableDepths['group']!;
      final policyLayer = layout.variableDepths['policy']!;
      final assetLayer = layout.variableDepths['asset']!;
      final virtualLayer = layout.variableDepths['virtual']!;

      expect(groupLayer, 0);
      expect(policyLayer, 1);
      expect(assetLayer, 2);
      expect(virtualLayer, 3);

      // Verify ordering
      expect(groupLayer < policyLayer, true);
      expect(policyLayer < assetLayer, true);
      expect(assetLayer < virtualLayer, true);

      // Convenience methods work
      expect(layout.variableLayer('policy'), 1);
      expect(layout.layerFor('pol1'), 1);
      expect(layout.nodesInLayer(1), {'pol1'});
    });

    test('disconnected components - multiple roots', () {
      // Component A: a1 -> a2 -> a3
      // Component B: b1 -> b2 (separate graph)
      final graph = Graph<Node>();

      graph.addNode(Node(id: 'a1', type: 'Node', label: 'A1'));
      graph.addNode(Node(id: 'a2', type: 'Node', label: 'A2'));
      graph.addNode(Node(id: 'a3', type: 'Node', label: 'A3'));
      graph.addNode(Node(id: 'b1', type: 'Node', label: 'B1'));
      graph.addNode(Node(id: 'b2', type: 'Node', label: 'B2'));

      graph.addEdge('a1', 'NEXT', 'a2');
      graph.addEdge('a2', 'NEXT', 'a3');
      graph.addEdge('b1', 'NEXT', 'b2');

      final query = PatternQuery(graph);
      final pathsA = query.matchPaths('x-[:NEXT]->y-[:NEXT]->z', startId: 'a1');
      final pathsB = query.matchPaths('x-[:NEXT]->y', startId: 'b1');
      final allPaths = [...pathsA, ...pathsB];

      final layout = allPaths.computeLayout();

      // Both components start at depth 0
      expect(layout.roots, containsAll(['a1', 'b1']));
      expect(layout.nodeDepths['a1'], 0);
      expect(layout.nodeDepths['b1'], 0);

      // But continue independently
      expect(layout.nodeDepths['a3'], 2);
      expect(layout.nodeDepths['b2'], 1);
    });

    test('cycles - falls back to longest path strategy', () {
      // Graph: a -> b -> c -> a (cycle!)
      final graph = Graph<Node>();
      graph.addNode(Node(id: 'a', type: 'Node', label: 'A'));
      graph.addNode(Node(id: 'b', type: 'Node', label: 'B'));
      graph.addNode(Node(id: 'c', type: 'Node', label: 'C'));

      graph.addEdge('a', 'NEXT', 'b');
      graph.addEdge('b', 'NEXT', 'c');
      graph.addEdge('c', 'NEXT', 'a'); // Creates cycle

      final query = PatternQuery(graph);
      final paths = query.matchPaths('x-[:NEXT]->y-[:NEXT]->z', startId: 'a');

      // Should not throw even with cycles
      final layout = paths.computeLayout();

      // Should have valid layout
      expect(layout.nodeDepths.isNotEmpty, true);
      expect(layout.maxDepth, greaterThanOrEqualTo(0));
    });

    test('mixed directions - backward arrows handled', () {
      // Pattern: asset<-[:APPLIES]-policy->group
      // (policy in middle, arrows go both ways)
      final graph = Graph<Node>();
      graph.addNode(Node(id: 'asset1', type: 'Asset', label: 'Asset 1'));
      graph.addNode(Node(id: 'policy1', type: 'Policy', label: 'Policy 1'));
      graph.addNode(Node(id: 'group1', type: 'Group', label: 'Group 1'));

      graph.addEdge('policy1', 'APPLIES', 'asset1');
      graph.addEdge('policy1', 'MEMBER', 'group1');

      final query = PatternQuery(graph);
      final paths = query.matchPaths(
        'asset<-[:APPLIES]-policy-[:MEMBER]->group',
      );

      final layout = paths.computeLayout();

      // With mixed directions, verify structure makes sense
      expect(layout.nodeDepths.isNotEmpty, true);
      expect(layout.maxDepth, greaterThanOrEqualTo(0));

      // At least one root should exist
      expect(layout.roots.isNotEmpty, true);
    });

    test('variable-length patterns - handles flexible depths', () {
      // Pattern: a-[:KNOWS*1..3]->b
      // Could match: a->b, a->x->b, a->x->y->b
      final graph = Graph<Node>();
      graph.addNode(Node(id: 'start', type: 'Person', label: 'Start'));
      graph.addNode(Node(id: 'mid1', type: 'Person', label: 'Middle 1'));
      graph.addNode(Node(id: 'mid2', type: 'Person', label: 'Middle 2'));
      graph.addNode(Node(id: 'end1', type: 'Person', label: 'End 1'));
      graph.addNode(Node(id: 'end2', type: 'Person', label: 'End 2'));
      graph.addNode(Node(id: 'end3', type: 'Person', label: 'End 3'));

      graph.addEdge('start', 'KNOWS', 'end1'); // 1 hop
      graph.addEdge('start', 'KNOWS', 'mid1');
      graph.addEdge('mid1', 'KNOWS', 'end2'); // 2 hops
      graph.addEdge('start', 'KNOWS', 'mid2');
      graph.addEdge('mid2', 'KNOWS', 'mid1');
      graph.addEdge('mid1', 'KNOWS', 'end3'); // 3 hops

      final query = PatternQuery(graph);
      final paths = query.matchPaths('start-[:KNOWS*1..3]->end', startId: 'start');

      final layout = paths.computeLayout();

      // Start nodes always at 0
      expect(layout.variableDepths['start'], 0);

      // End nodes could be at 1, 2, or 3 - median handles this
      final endDepth = layout.variableDepths['end'];
      expect(endDepth, greaterThanOrEqualTo(1));
      expect(endDepth, lessThanOrEqualTo(3));
    });

    test('empty paths - handles gracefully', () {
      final paths = <PathMatch>[];
      final layout = paths.computeLayout();

      expect(layout.nodeDepths, isEmpty);
      expect(layout.nodesByLayer, isEmpty);
      expect(layout.variableDepths, isEmpty);
      expect(layout.roots, isEmpty);
      expect(layout.maxDepth, 0);
      expect(layout.allNodes, isEmpty);
      expect(layout.allEdges, isEmpty);
    });

    test('both strategies on same simple graph', () {
      // Graph: a -> b -> c -> d
      final graph = Graph<Node>();
      graph.addNode(Node(id: 'a', type: 'Node', label: 'A'));
      graph.addNode(Node(id: 'b', type: 'Node', label: 'B'));
      graph.addNode(Node(id: 'c', type: 'Node', label: 'C'));
      graph.addNode(Node(id: 'd', type: 'Node', label: 'D'));

      graph.addEdge('a', 'X', 'b');
      graph.addEdge('b', 'X', 'c');
      graph.addEdge('c', 'X', 'd');

      final query = PatternQuery(graph);
      final paths = query.matchPaths('a-[:X]->b-[:X]->c-[:X]->d', startId: 'a');

      final layoutPattern = paths.computeLayout(strategy: LayerStrategy.pattern);
      final layoutLongest = paths.computeLayout(strategy: LayerStrategy.longestPath);

      // For simple linear path, both should give same result
      expect(layoutPattern.nodeDepths, layoutLongest.nodeDepths);
      expect(layoutPattern.variableDepths, layoutLongest.variableDepths);

      // Both should produce same layering
      expect(layoutPattern.nodeDepths['a'], 0);
      expect(layoutPattern.nodeDepths['b'], 1);
      expect(layoutPattern.nodeDepths['c'], 2);
      expect(layoutPattern.nodeDepths['d'], 3);
    });

    test('single node with no edges', () {
      final graph = Graph<Node>();
      graph.addNode(Node(id: 'lonely', type: 'Node', label: 'Lonely'));

      final query = PatternQuery(graph);
      // matchPaths with just a single node
      final paths = query.matchPaths('x', startId: 'lonely');

      final layout = paths.computeLayout();

      expect(layout.nodeDepths['lonely'], 0);
      expect(layout.roots, {'lonely'});
      expect(layout.maxDepth, 0);
      expect(layout.variableDepths['x'], 0);
    });

    test('layerFor and nodesInLayer convenience methods', () {
      final graph = Graph<Node>();
      graph.addNode(Node(id: 'a', type: 'Node', label: 'A'));
      graph.addNode(Node(id: 'b', type: 'Node', label: 'B'));
      graph.addNode(Node(id: 'c', type: 'Node', label: 'C'));

      graph.addEdge('a', 'NEXT', 'b');
      graph.addEdge('a', 'NEXT', 'c');

      final query = PatternQuery(graph);
      final paths = query.matchPaths('x-[:NEXT]->y', startId: 'a');
      final layout = paths.computeLayout();

      // layerFor
      expect(layout.layerFor('a'), 0);
      expect(layout.layerFor('b'), 1);
      expect(layout.layerFor('c'), 1);
      expect(layout.layerFor('nonexistent'), 0); // Default

      // nodesInLayer
      expect(layout.nodesInLayer(0), {'a'});
      expect(layout.nodesInLayer(1), {'b', 'c'});
      expect(layout.nodesInLayer(999), isEmpty); // Non-existent layer
    });

    test('toString provides useful debug info', () {
      final graph = Graph<Node>();
      graph.addNode(Node(id: 'a', type: 'Node', label: 'A'));
      graph.addNode(Node(id: 'b', type: 'Node', label: 'B'));
      graph.addEdge('a', 'NEXT', 'b');

      final query = PatternQuery(graph);
      final paths = query.matchPaths('x-[:NEXT]->y', startId: 'a');
      final layout = paths.computeLayout();

      final str = layout.toString();
      expect(str, contains('GraphLayout'));
      expect(str, contains('maxDepth'));
      expect(str, contains('roots'));
    });
  });
}
