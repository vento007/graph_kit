import 'package:graph_kit/graph_kit.dart';

void main() {
  // Same graph:
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

  print('=== Testing matchRows (what existing tests use) ===');
  final rows = query.matchRows('start-[:X*1..3]->end', startId: 'a');
  print('matchRows returned ${rows.length} rows:');
  for (var i = 0; i < rows.length; i++) {
    print('  Row $i: ${rows[i]}');
  }

  print('\n=== Testing matchPaths (what my tests use) ===');
  final paths = query.matchPaths('start-[:X*1..3]->end', startId: 'a');
  print('matchPaths returned ${paths.length} paths:');
  for (var i = 0; i < paths.length; i++) {
    final path = paths[i];
    print('  Path $i:');
    print('    nodes: ${path.nodes}');
    print('    edges: ${path.edges.length} edges');
    for (final edge in path.edges) {
      print('      ${edge.from} -[${edge.type}]-> ${edge.to}');
    }
  }

  print('\n=== Verdict ===');
  print('matchRows works: ${rows.isNotEmpty && rows.every((r) => r["end"] != null)}');
  print('matchPaths works: ${paths.isNotEmpty && paths.every((p) => p.nodes["end"] != null)}');
}
