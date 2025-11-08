import 'package:graph_kit/graph_kit.dart';

void main() {
  final graph = Graph<Node>();
  final query = PatternQuery(graph);

  graph.addNode(Node(id: 'n1', type: 'Node', label: 'N1'));
  graph.addNode(Node(id: 'n2', type: 'Node', label: 'N2'));
  graph.addNode(Node(id: 'n3', type: 'Node', label: 'N3'));

  graph.addEdge('n1', 'TYPE_A', 'n2');
  graph.addEdge('n2', 'TYPE_A', 'n3');

  // Test: type(r2) = type(r)
  final result1 = query.match(
    'a-[r]->b-[r2]->c WHERE type(r2) = type(r)',
    startId: 'n1',
  );
  print('type(r2) = type(r): ${result1['c']}');

  // Test: type(r) = type(r2) (reverse order)
  final result2 = query.match(
    'a-[r]->b-[r2]->c WHERE type(r) = type(r2)',
    startId: 'n1',
  );
  print('type(r) = type(r2): ${result2['c']}');

  print('\nBoth should return [n3]: ${result1['c'] == result2['c'] ? "✅ Works both ways!" : "❌ Asymmetric"}');
}
