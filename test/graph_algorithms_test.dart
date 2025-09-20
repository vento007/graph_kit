import 'package:test/test.dart';
import 'package:graph_kit/graph_kit.dart';

void main() {
  group('Graph Algorithms', () {
    late Graph<Node> graph;
    late GraphAlgorithms<Node> algorithms;

    setUp(() {
      graph = Graph<Node>();
      algorithms = GraphAlgorithms(graph);
    });

    group('Shortest Path', () {
      test('finds shortest path in simple linear graph', () {
        // a -> b -> c -> d
        graph.addNode(Node(id: 'a', type: 'Node', label: 'A'));
        graph.addNode(Node(id: 'b', type: 'Node', label: 'B'));
        graph.addNode(Node(id: 'c', type: 'Node', label: 'C'));
        graph.addNode(Node(id: 'd', type: 'Node', label: 'D'));

        graph.addEdge('a', 'CONNECTS', 'b');
        graph.addEdge('b', 'CONNECTS', 'c');
        graph.addEdge('c', 'CONNECTS', 'd');

        final result = algorithms.shortestPath('a', 'd');

        expect(result.found, isTrue);
        expect(result.path, equals(['a', 'b', 'c', 'd']));
        expect(result.distance, equals(3));
      });

      test('finds shortest path with multiple routes', () {
        // a -> b -> d
        // a -> c -> d (both equal length)
        graph.addNode(Node(id: 'a', type: 'Node', label: 'A'));
        graph.addNode(Node(id: 'b', type: 'Node', label: 'B'));
        graph.addNode(Node(id: 'c', type: 'Node', label: 'C'));
        graph.addNode(Node(id: 'd', type: 'Node', label: 'D'));

        graph.addEdge('a', 'CONNECTS', 'b');
        graph.addEdge('b', 'CONNECTS', 'd');
        graph.addEdge('a', 'CONNECTS', 'c');
        graph.addEdge('c', 'CONNECTS', 'd');

        final result = algorithms.shortestPath('a', 'd');

        expect(result.found, isTrue);
        expect(result.path, equals(['a', 'b', 'd'])); // BFS with alphabetical ordering chooses 'b' first
        expect(result.distance, equals(2));
      });

      test('handles no path between nodes', () {
        // a -> b    c -> d (disconnected)
        graph.addNode(Node(id: 'a', type: 'Node', label: 'A'));
        graph.addNode(Node(id: 'b', type: 'Node', label: 'B'));
        graph.addNode(Node(id: 'c', type: 'Node', label: 'C'));
        graph.addNode(Node(id: 'd', type: 'Node', label: 'D'));

        graph.addEdge('a', 'CONNECTS', 'b');
        graph.addEdge('c', 'CONNECTS', 'd');

        final result = algorithms.shortestPath('a', 'd');

        expect(result.found, isFalse);
        expect(result.path, isEmpty);
        expect(result.distance, equals(double.infinity));
      });

      test('handles same source and destination', () {
        graph.addNode(Node(id: 'a', type: 'Node', label: 'A'));

        final result = algorithms.shortestPath('a', 'a');

        expect(result.found, isTrue);
        expect(result.path, equals(['a']));
        expect(result.distance, equals(0));
      });

      test('respects edge type filter', () {
        // a -[FRIEND]-> b -[WORK]-> c
        // a -[WORK]-> c (direct work connection)
        graph.addNode(Node(id: 'a', type: 'Person', label: 'A'));
        graph.addNode(Node(id: 'b', type: 'Person', label: 'B'));
        graph.addNode(Node(id: 'c', type: 'Person', label: 'C'));

        graph.addEdge('a', 'FRIEND', 'b');
        graph.addEdge('b', 'WORK', 'c');
        graph.addEdge('a', 'WORK', 'c');

        final workOnlyResult = algorithms.shortestPath('a', 'c', edgeType: 'WORK');
        expect(workOnlyResult.path, equals(['a', 'c']));

        final friendOnlyResult = algorithms.shortestPath('a', 'c', edgeType: 'FRIEND');
        expect(friendOnlyResult.found, isFalse);
      });

    });

    group('Connected Components', () {
      test('finds single component in connected graph', () {
        // a -> b -> c
        graph.addNode(Node(id: 'a', type: 'Node', label: 'A'));
        graph.addNode(Node(id: 'b', type: 'Node', label: 'B'));
        graph.addNode(Node(id: 'c', type: 'Node', label: 'C'));

        graph.addEdge('a', 'CONNECTS', 'b');
        graph.addEdge('b', 'CONNECTS', 'c');

        final components = algorithms.connectedComponents();

        expect(components, hasLength(1));
        expect(components.first, containsAll(['a', 'b', 'c']));
      });

      test('finds multiple components in disconnected graph', () {
        // a -> b    c -> d    e (isolated)
        graph.addNode(Node(id: 'a', type: 'Node', label: 'A'));
        graph.addNode(Node(id: 'b', type: 'Node', label: 'B'));
        graph.addNode(Node(id: 'c', type: 'Node', label: 'C'));
        graph.addNode(Node(id: 'd', type: 'Node', label: 'D'));
        graph.addNode(Node(id: 'e', type: 'Node', label: 'E'));

        graph.addEdge('a', 'CONNECTS', 'b');
        graph.addEdge('c', 'CONNECTS', 'd');

        final components = algorithms.connectedComponents();

        expect(components, hasLength(3));
        expect(components.map((c) => c.toList()..sort()),
               containsAll([['a', 'b'], ['c', 'd'], ['e']]));
      });

      test('treats bidirectional edges as same component', () {
        // a <-> b    c -> d
        graph.addNode(Node(id: 'a', type: 'Node', label: 'A'));
        graph.addNode(Node(id: 'b', type: 'Node', label: 'B'));
        graph.addNode(Node(id: 'c', type: 'Node', label: 'C'));
        graph.addNode(Node(id: 'd', type: 'Node', label: 'D'));

        graph.addEdge('a', 'CONNECTS', 'b');
        graph.addEdge('b', 'CONNECTS', 'a');
        graph.addEdge('c', 'CONNECTS', 'd');

        final components = algorithms.connectedComponents();

        expect(components, hasLength(2));
        expect(components.map((c) => c.toList()..sort()),
               containsAll([['a', 'b'], ['c', 'd']]));
      });

      test('handles empty graph', () {
        final components = algorithms.connectedComponents();
        expect(components, isEmpty);
      });

      test('respects edge type filter', () {
        // a -[FRIEND]-> b    a -[WORK]-> c
        graph.addNode(Node(id: 'a', type: 'Person', label: 'A'));
        graph.addNode(Node(id: 'b', type: 'Person', label: 'B'));
        graph.addNode(Node(id: 'c', type: 'Person', label: 'C'));

        graph.addEdge('a', 'FRIEND', 'b');
        graph.addEdge('a', 'WORK', 'c');

        final friendComponents = algorithms.connectedComponents(edgeType: 'FRIEND');
        expect(friendComponents, hasLength(2));

        final workComponents = algorithms.connectedComponents(edgeType: 'WORK');
        expect(workComponents, hasLength(2));
      });
    });

    group('Reachable From', () {
      test('finds all reachable nodes in simple graph', () {
        // a -> b -> c -> d
        graph.addNode(Node(id: 'a', type: 'Node', label: 'A'));
        graph.addNode(Node(id: 'b', type: 'Node', label: 'B'));
        graph.addNode(Node(id: 'c', type: 'Node', label: 'C'));
        graph.addNode(Node(id: 'd', type: 'Node', label: 'D'));

        graph.addEdge('a', 'CONNECTS', 'b');
        graph.addEdge('b', 'CONNECTS', 'c');
        graph.addEdge('c', 'CONNECTS', 'd');

        final reachable = algorithms.reachableFrom('a');

        expect(reachable, containsAll(['a', 'b', 'c', 'd']));
        expect(reachable, hasLength(4));
      });

      test('finds reachable nodes in branching graph', () {
        // a -> b -> d
        // a -> c -> e
        graph.addNode(Node(id: 'a', type: 'Node', label: 'A'));
        graph.addNode(Node(id: 'b', type: 'Node', label: 'B'));
        graph.addNode(Node(id: 'c', type: 'Node', label: 'C'));
        graph.addNode(Node(id: 'd', type: 'Node', label: 'D'));
        graph.addNode(Node(id: 'e', type: 'Node', label: 'E'));

        graph.addEdge('a', 'CONNECTS', 'b');
        graph.addEdge('a', 'CONNECTS', 'c');
        graph.addEdge('b', 'CONNECTS', 'd');
        graph.addEdge('c', 'CONNECTS', 'e');

        final reachable = algorithms.reachableFrom('a');

        expect(reachable, containsAll(['a', 'b', 'c', 'd', 'e']));
        expect(reachable, hasLength(5));
      });

      test('handles cycles correctly', () {
        // a -> b -> c -> a (cycle)
        graph.addNode(Node(id: 'a', type: 'Node', label: 'A'));
        graph.addNode(Node(id: 'b', type: 'Node', label: 'B'));
        graph.addNode(Node(id: 'c', type: 'Node', label: 'C'));

        graph.addEdge('a', 'CONNECTS', 'b');
        graph.addEdge('b', 'CONNECTS', 'c');
        graph.addEdge('c', 'CONNECTS', 'a');

        final reachable = algorithms.reachableFrom('a');

        expect(reachable, containsAll(['a', 'b', 'c']));
        expect(reachable, hasLength(3));
      });

      test('handles disconnected nodes', () {
        // a -> b    c -> d (c,d not reachable from a)
        graph.addNode(Node(id: 'a', type: 'Node', label: 'A'));
        graph.addNode(Node(id: 'b', type: 'Node', label: 'B'));
        graph.addNode(Node(id: 'c', type: 'Node', label: 'C'));
        graph.addNode(Node(id: 'd', type: 'Node', label: 'D'));

        graph.addEdge('a', 'CONNECTS', 'b');
        graph.addEdge('c', 'CONNECTS', 'd');

        final reachable = algorithms.reachableFrom('a');

        expect(reachable, containsAll(['a', 'b']));
        expect(reachable, hasLength(2));
        expect(reachable, isNot(contains('c')));
        expect(reachable, isNot(contains('d')));
      });

      test('respects edge type filter', () {
        // a -[FRIEND]-> b -[WORK]-> c
        graph.addNode(Node(id: 'a', type: 'Person', label: 'A'));
        graph.addNode(Node(id: 'b', type: 'Person', label: 'B'));
        graph.addNode(Node(id: 'c', type: 'Person', label: 'C'));

        graph.addEdge('a', 'FRIEND', 'b');
        graph.addEdge('b', 'WORK', 'c');

        final friendReachable = algorithms.reachableFrom('a', edgeType: 'FRIEND');
        expect(friendReachable, containsAll(['a', 'b']));
        expect(friendReachable, hasLength(2));

        final workReachable = algorithms.reachableFrom('a', edgeType: 'WORK');
        expect(workReachable, equals({'a'}));
      });
    });

    group('Reachable By', () {
      test('finds all nodes that can reach a target', () {
        // a -> b -> c
        // d -> b
        graph.addNode(Node(id: 'a', type: 'Person', label: 'A'));
        graph.addNode(Node(id: 'b', type: 'Person', label: 'B'));
        graph.addNode(Node(id: 'c', type: 'Person', label: 'C'));
        graph.addNode(Node(id: 'd', type: 'Person', label: 'D'));

        graph.addEdge('a', 'FRIEND', 'b');
        graph.addEdge('b', 'FRIEND', 'c');
        graph.addEdge('d', 'FRIEND', 'b');

        final reachableBy = algorithms.reachableBy('b');
        expect(reachableBy, containsAll(['a', 'b', 'd']));
        expect(reachableBy, hasLength(3));
      });

      test('handles disconnected components', () {
        graph.addNode(Node(id: 'a', type: 'Person', label: 'A'));
        graph.addNode(Node(id: 'b', type: 'Person', label: 'B'));
        graph.addNode(Node(id: 'c', type: 'Person', label: 'C'));

        graph.addEdge('a', 'FRIEND', 'b');
        // c is isolated

        final reachableBy = algorithms.reachableBy('c');
        expect(reachableBy, equals({'c'}));
      });

      test('handles single node', () {
        graph.addNode(Node(id: 'a', type: 'Person', label: 'A'));

        final reachableBy = algorithms.reachableBy('a');
        expect(reachableBy, equals({'a'}));
      });

      test('returns empty for non-existent node', () {
        final reachableBy = algorithms.reachableBy('nonexistent');
        expect(reachableBy, isEmpty);
      });

      test('respects edge type filter', () {
        graph.addNode(Node(id: 'a', type: 'Person', label: 'A'));
        graph.addNode(Node(id: 'b', type: 'Person', label: 'B'));
        graph.addNode(Node(id: 'c', type: 'Person', label: 'C'));

        graph.addEdge('a', 'FRIEND', 'b');
        graph.addEdge('b', 'WORK', 'c');

        final friendReachableBy = algorithms.reachableBy('b', edgeType: 'FRIEND');
        expect(friendReachableBy, containsAll(['a', 'b']));
        expect(friendReachableBy, hasLength(2));

        final workReachableBy = algorithms.reachableBy('c', edgeType: 'WORK');
        expect(workReachableBy, containsAll(['b', 'c']));
        expect(workReachableBy, hasLength(2));
      });
    });

    group('Reachable All', () {
      test('finds all bidirectionally connected nodes', () {
        // a -> b -> c
        // d -> b
        graph.addNode(Node(id: 'a', type: 'Person', label: 'A'));
        graph.addNode(Node(id: 'b', type: 'Person', label: 'B'));
        graph.addNode(Node(id: 'c', type: 'Person', label: 'C'));
        graph.addNode(Node(id: 'd', type: 'Person', label: 'D'));

        graph.addEdge('a', 'FRIEND', 'b');
        graph.addEdge('b', 'FRIEND', 'c');
        graph.addEdge('d', 'FRIEND', 'b');

        final reachableAll = algorithms.reachableAll('b');
        expect(reachableAll, containsAll(['a', 'b', 'c', 'd']));
        expect(reachableAll, hasLength(4));
      });

      test('handles disconnected components', () {
        graph.addNode(Node(id: 'a', type: 'Person', label: 'A'));
        graph.addNode(Node(id: 'b', type: 'Person', label: 'B'));
        graph.addNode(Node(id: 'c', type: 'Person', label: 'C'));

        graph.addEdge('a', 'FRIEND', 'b');
        // c is isolated

        final reachableAll = algorithms.reachableAll('c');
        expect(reachableAll, equals({'c'}));
      });

      test('handles single node', () {
        graph.addNode(Node(id: 'a', type: 'Person', label: 'A'));

        final reachableAll = algorithms.reachableAll('a');
        expect(reachableAll, equals({'a'}));
      });

      test('returns empty for non-existent node', () {
        final reachableAll = algorithms.reachableAll('nonexistent');
        expect(reachableAll, isEmpty);
      });

      test('respects edge type filter', () {
        graph.addNode(Node(id: 'a', type: 'Person', label: 'A'));
        graph.addNode(Node(id: 'b', type: 'Person', label: 'B'));
        graph.addNode(Node(id: 'c', type: 'Person', label: 'C'));

        graph.addEdge('a', 'FRIEND', 'b');
        graph.addEdge('b', 'WORK', 'c');

        final friendReachableAll = algorithms.reachableAll('b', edgeType: 'FRIEND');
        expect(friendReachableAll, containsAll(['a', 'b']));
        expect(friendReachableAll, hasLength(2));

        final workReachableAll = algorithms.reachableAll('b', edgeType: 'WORK');
        expect(workReachableAll, containsAll(['b', 'c']));
        expect(workReachableAll, hasLength(2));
      });
    });

    group('Topological Sort', () {
      test('sorts simple DAG correctly', () {
        // a -> b -> c
        // a -> c
        graph.addNode(Node(id: 'a', type: 'Task', label: 'Task A'));
        graph.addNode(Node(id: 'b', type: 'Task', label: 'Task B'));
        graph.addNode(Node(id: 'c', type: 'Task', label: 'Task C'));

        graph.addEdge('a', 'DEPENDS_ON', 'b');
        graph.addEdge('b', 'DEPENDS_ON', 'c');
        graph.addEdge('a', 'DEPENDS_ON', 'c');

        final sorted = algorithms.topologicalSort();

        expect(sorted, hasLength(3));
        expect(sorted.indexOf('c'), lessThan(sorted.indexOf('b')));
        expect(sorted.indexOf('b'), lessThan(sorted.indexOf('a')));
      });

      test('sorts complex dependency graph', () {
        // Dependencies: a->b, a->c, b->d, c->d, c->e
        graph.addNode(Node(id: 'a', type: 'Task', label: 'A'));
        graph.addNode(Node(id: 'b', type: 'Task', label: 'B'));
        graph.addNode(Node(id: 'c', type: 'Task', label: 'C'));
        graph.addNode(Node(id: 'd', type: 'Task', label: 'D'));
        graph.addNode(Node(id: 'e', type: 'Task', label: 'E'));

        graph.addEdge('a', 'DEPENDS_ON', 'b');
        graph.addEdge('a', 'DEPENDS_ON', 'c');
        graph.addEdge('b', 'DEPENDS_ON', 'd');
        graph.addEdge('c', 'DEPENDS_ON', 'd');
        graph.addEdge('c', 'DEPENDS_ON', 'e');

        final sorted = algorithms.topologicalSort();

        expect(sorted, hasLength(5));
        // Verify all dependency constraints
        expect(sorted.indexOf('b'), lessThan(sorted.indexOf('a')));
        expect(sorted.indexOf('c'), lessThan(sorted.indexOf('a')));
        expect(sorted.indexOf('d'), lessThan(sorted.indexOf('b')));
        expect(sorted.indexOf('d'), lessThan(sorted.indexOf('c')));
        expect(sorted.indexOf('e'), lessThan(sorted.indexOf('c')));
      });

      test('throws exception for cyclic graph', () {
        // a -> b -> c -> a (cycle)
        graph.addNode(Node(id: 'a', type: 'Task', label: 'A'));
        graph.addNode(Node(id: 'b', type: 'Task', label: 'B'));
        graph.addNode(Node(id: 'c', type: 'Task', label: 'C'));

        graph.addEdge('a', 'DEPENDS_ON', 'b');
        graph.addEdge('b', 'DEPENDS_ON', 'c');
        graph.addEdge('c', 'DEPENDS_ON', 'a');

        expect(() => algorithms.topologicalSort(),
               throwsA(isA<ArgumentError>()));
      });

      test('handles disconnected components', () {
        // a -> b    c -> d (two separate DAGs)
        graph.addNode(Node(id: 'a', type: 'Task', label: 'A'));
        graph.addNode(Node(id: 'b', type: 'Task', label: 'B'));
        graph.addNode(Node(id: 'c', type: 'Task', label: 'C'));
        graph.addNode(Node(id: 'd', type: 'Task', label: 'D'));

        graph.addEdge('a', 'DEPENDS_ON', 'b');
        graph.addEdge('c', 'DEPENDS_ON', 'd');

        final sorted = algorithms.topologicalSort();

        expect(sorted, hasLength(4));
        expect(sorted.indexOf('b'), lessThan(sorted.indexOf('a')));
        expect(sorted.indexOf('d'), lessThan(sorted.indexOf('c')));
      });

      test('handles isolated nodes', () {
        graph.addNode(Node(id: 'a', type: 'Task', label: 'A'));
        graph.addNode(Node(id: 'b', type: 'Task', label: 'B'));

        // No edges - both nodes are isolated

        final sorted = algorithms.topologicalSort();

        expect(sorted, hasLength(2));
        expect(sorted, containsAll(['a', 'b']));
      });

      test('respects edge type filter', () {
        // a -[DEPENDS]-> b -[BLOCKS]-> c
        graph.addNode(Node(id: 'a', type: 'Task', label: 'A'));
        graph.addNode(Node(id: 'b', type: 'Task', label: 'B'));
        graph.addNode(Node(id: 'c', type: 'Task', label: 'C'));

        graph.addEdge('a', 'DEPENDS_ON', 'b');
        graph.addEdge('b', 'BLOCKS', 'c');

        final dependsSort = algorithms.topologicalSort(edgeType: 'DEPENDS_ON');
        expect(dependsSort.indexOf('b'), lessThan(dependsSort.indexOf('a')));

        final blocksSort = algorithms.topologicalSort(edgeType: 'BLOCKS');
        expect(blocksSort.indexOf('c'), lessThan(blocksSort.indexOf('b')));
      });
    });

    group('Betweenness Centrality', () {
      test('calculates centrality for simple path', () {
        // a -> b -> c (b is the bridge)
        graph.addNode(Node(id: 'a', type: 'Node', label: 'A'));
        graph.addNode(Node(id: 'b', type: 'Node', label: 'B'));
        graph.addNode(Node(id: 'c', type: 'Node', label: 'C'));

        graph.addEdge('a', 'CONNECTS', 'b');
        graph.addEdge('b', 'CONNECTS', 'c');

        final centrality = algorithms.betweennessCentrality();

        expect(centrality['a'], equals(0.0)); // not a bridge
        expect(centrality['b'], equals(1.0)); // perfect bridge
        expect(centrality['c'], equals(0.0)); // not a bridge
      });

      test('calculates centrality for star pattern', () {
        // a -> center <- b
        //      |
        //      v
        //      c
        graph.addNode(Node(id: 'center', type: 'Node', label: 'Center'));
        graph.addNode(Node(id: 'a', type: 'Node', label: 'A'));
        graph.addNode(Node(id: 'b', type: 'Node', label: 'B'));
        graph.addNode(Node(id: 'c', type: 'Node', label: 'C'));

        graph.addEdge('a', 'CONNECTS', 'center');
        graph.addEdge('b', 'CONNECTS', 'center');
        graph.addEdge('center', 'CONNECTS', 'c');

        final centrality = algorithms.betweennessCentrality();

        expect(centrality['center'], greaterThan(0.5)); // high centrality
        expect(centrality['a'], equals(0.0));
        expect(centrality['b'], equals(0.0));
        expect(centrality['c'], equals(0.0));
      });

      test('handles disconnected graph', () {
        graph.addNode(Node(id: 'a', type: 'Node', label: 'A'));
        graph.addNode(Node(id: 'b', type: 'Node', label: 'B'));

        final centrality = algorithms.betweennessCentrality();

        expect(centrality['a'], equals(0.0));
        expect(centrality['b'], equals(0.0));
      });

      test('respects edge type filter', () {
        graph.addNode(Node(id: 'a', type: 'Node', label: 'A'));
        graph.addNode(Node(id: 'b', type: 'Node', label: 'B'));
        graph.addNode(Node(id: 'c', type: 'Node', label: 'C'));

        graph.addEdge('a', 'TYPE1', 'b');
        graph.addEdge('b', 'TYPE2', 'c');

        final type1Centrality = algorithms.betweennessCentrality(edgeType: 'TYPE1');
        final type2Centrality = algorithms.betweennessCentrality(edgeType: 'TYPE2');

        expect(type1Centrality['b'], equals(0.0)); // no bridge for TYPE1 only
        expect(type2Centrality['b'], equals(0.0)); // no bridge for TYPE2 only
      });
    });

    group('Closeness Centrality', () {
      test('calculates centrality for simple path', () {
        // a -> b -> c (b is closest to all)
        graph.addNode(Node(id: 'a', type: 'Node', label: 'A'));
        graph.addNode(Node(id: 'b', type: 'Node', label: 'B'));
        graph.addNode(Node(id: 'c', type: 'Node', label: 'C'));

        graph.addEdge('a', 'CONNECTS', 'b');
        graph.addEdge('b', 'CONNECTS', 'c');

        final centrality = algorithms.closenessCentrality();

        expect(centrality['b'], equals(1.0)); // most central
        expect(centrality['a'], lessThan(1.0));
        expect(centrality['c'], lessThan(1.0));
      });

      test('calculates centrality for star pattern', () {
        // a -> center <- b
        //      |
        //      v
        //      c
        graph.addNode(Node(id: 'center', type: 'Node', label: 'Center'));
        graph.addNode(Node(id: 'a', type: 'Node', label: 'A'));
        graph.addNode(Node(id: 'b', type: 'Node', label: 'B'));
        graph.addNode(Node(id: 'c', type: 'Node', label: 'C'));

        graph.addEdge('a', 'CONNECTS', 'center');
        graph.addEdge('b', 'CONNECTS', 'center');
        graph.addEdge('center', 'CONNECTS', 'c');

        final centrality = algorithms.closenessCentrality();

        expect(centrality['center'], equals(1.0)); // most central
        expect(centrality['a'], lessThan(1.0));
        expect(centrality['b'], lessThan(1.0));
        expect(centrality['c'], lessThan(1.0));
      });

      test('handles disconnected graph', () {
        graph.addNode(Node(id: 'a', type: 'Node', label: 'A'));
        graph.addNode(Node(id: 'b', type: 'Node', label: 'B'));

        final centrality = algorithms.closenessCentrality();

        expect(centrality['a'], equals(0.0));
        expect(centrality['b'], equals(0.0));
      });

      test('respects edge type filter', () {
        graph.addNode(Node(id: 'a', type: 'Node', label: 'A'));
        graph.addNode(Node(id: 'b', type: 'Node', label: 'B'));
        graph.addNode(Node(id: 'c', type: 'Node', label: 'C'));

        graph.addEdge('a', 'TYPE1', 'b');
        graph.addEdge('b', 'TYPE1', 'c');
        graph.addEdge('a', 'TYPE2', 'c');

        final type1Centrality = algorithms.closenessCentrality(edgeType: 'TYPE1');
        final type2Centrality = algorithms.closenessCentrality(edgeType: 'TYPE2');

        expect(type1Centrality['b'], equals(1.0)); // b is central for TYPE1
        expect(type2Centrality['a'], greaterThan(0.0)); // a can reach c directly
        expect(type2Centrality['b'], equals(0.0)); // b is isolated for TYPE2
      });
    });
  });
}

