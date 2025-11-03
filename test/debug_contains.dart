import 'package:graph_kit/graph_kit.dart';

void main() {
  final graph = Graph<Node>();
  final query = PatternQuery(graph);

  // Create test nodes
  graph.addNode(Node(
    id: 'asset1',
    type: 'Asset',
    label: 'web-server-gw-01',
    properties: {'ip': '10.0.1.100'},
  ));

  graph.addNode(Node(
    id: 'asset2',
    type: 'Asset',
    label: 'db-server-prod',
    properties: {'ip': '10.0.2.50'},
  ));

  graph.addNode(Node(
    id: 'asset3',
    type: 'Asset',
    label: 'test-gateway',
    properties: {'ip': '192.168.1.1'},
  ));

  print('Testing CONTAINS with multiple matches...\n');

  // Test 1: Should find asset1 and asset3 (both have "gw")
  print('Test: asset.label CONTAINS "gw"');
  final results = query.match('asset:Asset WHERE asset.label CONTAINS "gw"');
  print('  Results: $results');
  print('  asset set: ${results["asset"]}');
  print('  Count: ${results["asset"]?.length ?? 0}\n');

  // Let me check each asset manually
  print('Manual check:');
  for (final id in ['asset1', 'asset2', 'asset3']) {
    final node = graph.nodesById[id];
    final label = node?.label ?? '';
    final contains = label.toLowerCase().contains('gw');
    print('  $id: label="$label", contains("gw")=$contains');
  }
}
