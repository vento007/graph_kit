import 'package:graph_kit/graph_kit.dart';
import 'package:test/test.dart';

void main() {
  group('Arrow-only wildcard syntax', () {
    test('supports "x->y" without edge spec', () {
      final graph = Graph<Node>();
      final query = PatternQuery(graph);

      graph.addNode(Node(id: 'n1', type: 'Node', label: 'N1'));
      graph.addNode(Node(id: 'n2', type: 'Node', label: 'N2'));

      // Multiple edge types between the same nodes.
      graph.addEdge('n1', 'TYPE_A', 'n2');
      graph.addEdge('n1', 'TYPE_B', 'n2');

      final match = query.match('x->y', startId: 'n1');
      expect(match['x'], contains('n1'));
      expect(match['y'], contains('n2'));

      final rows = query.matchRows('x->y', startId: 'n1');
      expect(rows, hasLength(1));
      expect(rows.first['x'], equals('n1'));
      expect(rows.first['y'], equals('n2'));

      final paths = query.matchPaths('x->y', startId: 'n1');
      expect(paths, hasLength(2));
      expect(paths.map((p) => p.edges.single.type).toSet(), {'TYPE_A', 'TYPE_B'});
    });

    test('supports "x<-y" without edge spec', () {
      final graph = Graph<Node>();
      final query = PatternQuery(graph);

      graph.addNode(Node(id: 'n1', type: 'Node', label: 'N1'));
      graph.addNode(Node(id: 'n2', type: 'Node', label: 'N2'));
      graph.addEdge('n1', 'LINKS', 'n2');

      final paths = query.matchPaths('x<-y', startId: 'n2');
      expect(paths, hasLength(1));

      final path = paths.single;
      expect(path.nodes['x'], equals('n2'));
      expect(path.nodes['y'], equals('n1'));
      expect(path.edges.single.from, equals('n1'));
      expect(path.edges.single.to, equals('n2'));
      expect(path.edges.single.type, equals('LINKS'));
      expect(path.edges.single.fromVariable, equals('y'));
      expect(path.edges.single.toVariable, equals('x'));
    });
  });
}

