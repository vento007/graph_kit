import 'package:test/test.dart';
import 'package:graph_kit/graph_kit.dart';

void main() {
  group('Path Enumeration', () {
    late Graph<Node> graph;

    setUp(() {
      graph = Graph<Node>();
    });

    test('finds single path in linear graph', () {
      // a -> b -> c
      graph.addNode(Node(id: 'a', type: 'Node', label: 'A'));
      graph.addNode(Node(id: 'b', type: 'Node', label: 'B'));
      graph.addNode(Node(id: 'c', type: 'Node', label: 'C'));

      graph.addEdge('a', 'CONNECTS', 'b');
      graph.addEdge('b', 'CONNECTS', 'c');

      final result = enumeratePaths(graph, 'a', 'c', maxHops: 3);

      expect(result.hasPaths, isTrue);
      expect(result.paths.length, equals(1));
      expect(result.paths.first, equals(['a', 'b', 'c']));
      expect(result.shortestPath, equals(['a', 'b', 'c']));
    });

    test('finds multiple paths in branching graph', () {
      // a -> b -> d
      // a -> c -> d
      graph.addNode(Node(id: 'a', type: 'Node', label: 'A'));
      graph.addNode(Node(id: 'b', type: 'Node', label: 'B'));
      graph.addNode(Node(id: 'c', type: 'Node', label: 'C'));
      graph.addNode(Node(id: 'd', type: 'Node', label: 'D'));

      graph.addEdge('a', 'CONNECTS', 'b');
      graph.addEdge('a', 'CONNECTS', 'c');
      graph.addEdge('b', 'CONNECTS', 'd');
      graph.addEdge('c', 'CONNECTS', 'd');

      final result = enumeratePaths(graph, 'a', 'd', maxHops: 3);

      expect(result.hasPaths, isTrue);
      expect(result.paths.length, equals(2));
      expect(result.paths, containsAll([
        ['a', 'b', 'd'],
        ['a', 'c', 'd']
      ]));
    });

    test('respects hop limit', () {
      // a -> b -> c -> d
      graph.addNode(Node(id: 'a', type: 'Node', label: 'A'));
      graph.addNode(Node(id: 'b', type: 'Node', label: 'B'));
      graph.addNode(Node(id: 'c', type: 'Node', label: 'C'));
      graph.addNode(Node(id: 'd', type: 'Node', label: 'D'));

      graph.addEdge('a', 'CONNECTS', 'b');
      graph.addEdge('b', 'CONNECTS', 'c');
      graph.addEdge('c', 'CONNECTS', 'd');

      final result = enumeratePaths(graph, 'a', 'd', maxHops: 2);

      expect(result.hasPaths, isFalse);
      expect(result.paths.isEmpty, isTrue);
    });

    test('prevents cycles', () {
      // a -> b -> c -> a (cycle)
      // a -> d (direct path)
      graph.addNode(Node(id: 'a', type: 'Node', label: 'A'));
      graph.addNode(Node(id: 'b', type: 'Node', label: 'B'));
      graph.addNode(Node(id: 'c', type: 'Node', label: 'C'));
      graph.addNode(Node(id: 'd', type: 'Node', label: 'D'));

      graph.addEdge('a', 'CONNECTS', 'b');
      graph.addEdge('b', 'CONNECTS', 'c');
      graph.addEdge('c', 'CONNECTS', 'a'); // cycle
      graph.addEdge('a', 'CONNECTS', 'd');

      final result = enumeratePaths(graph, 'a', 'd', maxHops: 5);

      expect(result.hasPaths, isTrue);
      expect(result.paths.length, equals(1));
      expect(result.paths.first, equals(['a', 'd']));
    });

    test('respects edge type filter', () {
      graph.addNode(Node(id: 'a', type: 'Node', label: 'A'));
      graph.addNode(Node(id: 'b', type: 'Node', label: 'B'));
      graph.addNode(Node(id: 'c', type: 'Node', label: 'C'));

      graph.addEdge('a', 'TYPE1', 'b');
      graph.addEdge('b', 'TYPE2', 'c');

      final result = enumeratePaths(
        graph,
        'a',
        'c',
        maxHops: 3,
        edgeTypes: {'TYPE1'}
      );

      expect(result.hasPaths, isFalse);
      expect(result.paths.isEmpty, isTrue);
    });

    test('handles same source and target', () {
      graph.addNode(Node(id: 'a', type: 'Node', label: 'A'));

      final result = enumeratePaths(graph, 'a', 'a', maxHops: 3);

      expect(result.hasPaths, isTrue);
      expect(result.paths.length, equals(1));
      expect(result.paths.first, equals(['a']));
    });

    test('returns empty for non-existent nodes', () {
      graph.addNode(Node(id: 'a', type: 'Node', label: 'A'));

      final result = enumeratePaths(graph, 'a', 'nonexistent', maxHops: 3);

      expect(result.hasPaths, isFalse);
      expect(result.paths.isEmpty, isTrue);
    });

    test('provides performance metrics', () {
      graph.addNode(Node(id: 'a', type: 'Node', label: 'A'));
      graph.addNode(Node(id: 'b', type: 'Node', label: 'B'));
      graph.addEdge('a', 'CONNECTS', 'b');

      final result = enumeratePaths(graph, 'a', 'b', maxHops: 3);

      expect(result.nodesExplored, greaterThan(0));
      expect(result.truncatedPaths, equals(0));
    });
  });
}