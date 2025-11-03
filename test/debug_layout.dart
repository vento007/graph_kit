import 'package:graph_kit/graph_kit.dart';

void main() {
  // Same graph that's failing:
  //   a -> b -> c -> d
  //   a --------> d  (shortcut)

  final graph = Graph<Node>();
  graph.addNode(Node(id: 'a', type: 'N', label: 'A'));
  graph.addNode(Node(id: 'b', type: 'N', label: 'B'));
  graph.addNode(Node(id: 'c', type: 'N', label: 'C'));
  graph.addNode(Node(id: 'd', type: 'N', label: 'D'));

  graph.addEdge('a', 'X', 'b');
  graph.addEdge('b', 'X', 'c');
  graph.addEdge('c', 'X', 'd');
  graph.addEdge('a', 'X', 'd'); // Shortcut

  final query = PatternQuery(graph);
  final paths = query.matchPaths('a-[:X*1..3]->d', startId: 'a');

  print('Number of paths found: ${paths.length}');
  print('');

  for (var i = 0; i < paths.length; i++) {
    final path = paths[i];
    print('Path $i:');
    print('  nodes: ${path.nodes}');
    print('  edges:');
    for (final edge in path.edges) {
      print('    ${edge.fromVariable}(${edge.from}) -[${edge.type}]-> ${edge.toVariable}(${edge.to})');
    }
    print('');
  }

  print('Computing layout with longestPath strategy...');
  final layout = paths.computeLayout(strategy: LayerStrategy.longestPath);

  print('Node depths:');
  for (final entry in layout.nodeDepths.entries) {
    print('  ${entry.key}: ${entry.value}');
  }

  print('');
  print('All edges in layout:');
  for (final edge in layout.allEdges) {
    print('  ${edge.src} -> ${edge.dst}');
  }
}
