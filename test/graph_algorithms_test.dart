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
  });
}

