import 'package:graph_kit/graph_kit.dart';
import 'package:test/test.dart';

void main() {
  group('Graph storage safety', () {
    test('nodesById is readable but not directly mutable', () {
      final graph = Graph<Node>();
      graph.addNode(Node(id: 'a', type: 'Node', label: 'A'));

      expect(graph.nodesById['a']?.label, 'A');
      expect(graph.nodesById.length, 1);
      expect(
        () => graph.nodesById['b'] = Node(id: 'b', type: 'Node', label: 'B'),
        throwsA(isA<UnsupportedError>()),
      );
      expect(
        () => graph.nodesById.remove('a'),
        throwsA(isA<UnsupportedError>()),
      );
      expect(graph.containsNode('a'), isTrue);
    });

    test('out adjacency view is deeply read-only', () {
      final graph = Graph<Node>();
      graph.addEdge('a', 'LINK', 'b');

      expect(graph.out['a']?['LINK'], equals({'b'}));
      expect(
        () => graph.out['c'] = <String, Set<String>>{},
        throwsA(isA<UnsupportedError>()),
      );
      expect(
        () => graph.out['a']!['OTHER'] = <String>{},
        throwsA(isA<UnsupportedError>()),
      );
      expect(
        () => graph.out['a']!['LINK']!.add('c'),
        throwsA(isA<UnsupportedError>()),
      );
      expect(graph.hasEdge('a', 'LINK', 'b'), isTrue);
      expect(graph.hasEdge('a', 'LINK', 'c'), isFalse);
    });

    test('inn adjacency view is deeply read-only', () {
      final graph = Graph<Node>();
      graph.addEdge('a', 'LINK', 'b');

      expect(graph.inn['b']?['LINK'], equals({'a'}));
      expect(
        () => graph.inn['c'] = <String, Set<String>>{},
        throwsA(isA<UnsupportedError>()),
      );
      expect(
        () => graph.inn['b']!['OTHER'] = <String>{},
        throwsA(isA<UnsupportedError>()),
      );
      expect(
        () => graph.inn['b']!['LINK']!.remove('a'),
        throwsA(isA<UnsupportedError>()),
      );
      expect(graph.hasEdge('a', 'LINK', 'b'), isTrue);
    });

    test('neighbor accessors return read-only sets', () {
      final graph = Graph<Node>();
      graph.addEdge('a', 'LINK', 'b');

      expect(graph.outNeighbors('a', 'LINK'), equals({'b'}));
      expect(
        () => graph.outNeighbors('a', 'LINK').add('c'),
        throwsA(isA<UnsupportedError>()),
      );
      expect(
        () => graph.inNeighbors('b', 'LINK').remove('a'),
        throwsA(isA<UnsupportedError>()),
      );
      expect(
        () => graph.outNeighbors('missing', 'LINK').add('x'),
        throwsA(isA<UnsupportedError>()),
      );
      expect(graph.hasEdge('a', 'LINK', 'b'), isTrue);
    });

    test('read-only adjacency views stay live after graph mutations', () {
      final graph = Graph<Node>();

      final out = graph.out;
      final inn = graph.inn;

      graph.addEdge('a', 'LINK', 'b');

      expect(out['a']?['LINK'], equals({'b'}));
      expect(inn['b']?['LINK'], equals({'a'}));

      graph.removeEdge('a', 'LINK', 'b');

      expect(out['a']?['LINK'], isNull);
      expect(inn['b']?['LINK'], isNull);
    });

    test('read helper APIs expose graph state', () {
      final graph = Graph<Node>();
      graph.addNode(Node(id: 'a', type: 'Node', label: 'A'));
      graph.addNode(Node(id: 'b', type: 'Node', label: 'B'));
      graph.addEdge('a', 'LINK', 'b');

      expect(graph.getNode('a')?.label, 'A');
      expect(graph.getNode('missing'), isNull);
      expect(graph.containsNode('b'), isTrue);
      expect(graph.containsNode('missing'), isFalse);
      expect(graph.nodes.map((node) => node.id), equals(['a', 'b']));
      expect(graph.nodeIds, equals(['a', 'b']));
      expect(graph.nodeCount, 2);
      expect(graph.edgeCount, 1);
    });
  });
}
