import 'package:graph_kit/graph_kit.dart';
import 'package:test/test.dart';

void main() {
  group('Edge storage', () {
    test('stores edge metadata even without properties', () {
      final graph = Graph<Node>();

      graph.addNode(Node(id: 'a', type: 'User', label: 'Alice'));
      graph.addNode(Node(id: 'b', type: 'User', label: 'Bob'));
      graph.addEdge('a', 'KNOWS', 'b');

      final edge = graph.getEdge('a', 'KNOWS', 'b');
      expect(edge, isNotNull);
      expect(edge!.src, equals('a'));
      expect(edge.dst, equals('b'));
      expect(edge.type, equals('KNOWS'));
      expect(edge.properties, isNull);
    });

    test('allows storing and overriding relationship properties', () {
      final graph = Graph<Node>();

      graph.addNode(Node(id: 'a', type: 'User', label: 'Alice'));
      graph.addNode(Node(id: 'b', type: 'User', label: 'Bob'));

      graph.addEdge(
        'a',
        'KNOWS',
        'b',
        properties: {'since': 2020, 'strength': 0.8},
      );
      var edge = graph.getEdge('a', 'KNOWS', 'b');
      expect(edge?.properties?['since'], equals(2020));
      expect(edge?.properties?['strength'], equals(0.8));

      // Re-adding with properties should override existing metadata
      graph.addEdge('a', 'KNOWS', 'b', properties: {'since': 2018});
      edge = graph.getEdge('a', 'KNOWS', 'b');
      expect(edge?.properties?['since'], equals(2018));
      expect(edge?.properties?['strength'], isNull);
    });
  });
}
