import 'package:graph_kit/graph_kit.dart';

void main() {
  print('=== Path Enumeration Demo ===\n');

  // Create a sample network graph
  final graph = Graph<Node>();

  // Add network nodes
  graph.addNode(Node(id: 'client', type: 'Device', label: 'Client'));
  graph.addNode(Node(id: 'router1', type: 'Device', label: 'Router 1'));
  graph.addNode(Node(id: 'router2', type: 'Device', label: 'Router 2'));
  graph.addNode(Node(id: 'switch', type: 'Device', label: 'Switch'));
  graph.addNode(Node(id: 'server', type: 'Device', label: 'Server'));

  // Add connections (multiple paths available)
  graph.addEdge('client', 'CONNECTS', 'router1');
  graph.addEdge('client', 'CONNECTS', 'router2');
  graph.addEdge('router1', 'CONNECTS', 'switch');
  graph.addEdge('router2', 'CONNECTS', 'switch');
  graph.addEdge('switch', 'CONNECTS', 'server');

  // Add direct backup connection
  graph.addEdge('router1', 'BACKUP', 'server');

  print('Network topology:');
  print('client -> router1 -> switch -> server');
  print('client -> router2 -> switch -> server');
  print('client -> router1 -> server (backup)');
  print('');

  // Demo 1: Find all paths within 4 hops
  print('🔍 Finding all paths from client to server (max 4 hops):');
  final result1 = enumeratePaths(graph, 'client', 'server', maxHops: 4);

  if (result1.hasPaths) {
    print('Found ${result1.paths.length} different routes:');
    for (int i = 0; i < result1.paths.length; i++) {
      final path = result1.paths[i];
      print('  Route ${i + 1}: ${path.join(' -> ')} (${path.length - 1} hops)');
    }
    print('Shortest: ${result1.shortestPath?.join(' -> ')}');
  } else {
    print('No paths found!');
  }
  print('');

  // Demo 2: Edge type filtering
  print('🔍 Finding paths using only CONNECTS edges:');
  final result2 = enumeratePaths(
    graph,
    'client',
    'server',
    maxHops: 4,
    edgeTypes: {'CONNECTS'}
  );

  print('Found ${result2.paths.length} routes using CONNECTS:');
  for (final path in result2.paths) {
    print('  ${path.join(' -> ')}');
  }
  print('');

  // Demo 3: Performance metrics
  print('📊 Performance metrics:');
  print('  Nodes explored: ${result1.nodesExplored}');
  print('  Paths truncated: ${result1.truncatedPaths}');
  print('');

  // Demo 4: Complex routing scenario
  print('🚧 Adding more complex routing...');
  graph.addNode(Node(id: 'gateway', type: 'Device', label: 'Gateway'));
  graph.addEdge('client', 'CONNECTS', 'gateway');
  graph.addEdge('gateway', 'CONNECTS', 'server');

  final result3 = enumeratePaths(graph, 'client', 'server', maxHops: 4);
  print('After adding gateway, found ${result3.paths.length} total routes:');
  for (int i = 0; i < result3.paths.length; i++) {
    final path = result3.paths[i];
    print('  Route ${i + 1}: ${path.join(' -> ')} (${path.length - 1} hops)');
  }

  print('\n✅ Demo complete! Path enumeration found multiple route options.');
}