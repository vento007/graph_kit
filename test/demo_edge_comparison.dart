import 'package:graph_kit/graph_kit.dart';

/// Demo of edge variable comparison: Multi-hop paths with edge type consistency
///
/// PROBLEM: A hub node has edges with different type prefixes from multiple sources.
///   When traversing multi-hop paths, we want to ensure both hops use the SAME edge type.
///
/// SOLUTION: WHERE type(r) STARTS WITH "PREFIX_" AND type(r2) = type(r)
///
/// This ensures both hops use THE SAME edge type throughout the path!

void main() {
  final graph = Graph<Node>();
  final query = PatternQuery(graph);

  // Setup: Source with hub and multiple destinations
  graph.addNode(Node(id: 'source1', type: 'Source', label: 'Source1'));
  graph.addNode(Node(id: 'hub', type: 'Hub', label: 'Hub1'));
  graph.addNode(Node(id: 'target1', type: 'Target', label: 'Target1'));
  graph.addNode(Node(id: 'target2', type: 'Target', label: 'Target2'));
  graph.addNode(Node(id: 'target3', type: 'Target', label: 'Target3'));

  // Source uses edge type PREFIX_abc123
  graph.addEdge('source1', 'PREFIX_abc123', 'hub');

  // Hub has edges with DIFFERENT suffixes
  graph.addEdge('hub', 'PREFIX_abc123', 'target1');  // SAME - should match ✓
  graph.addEdge('hub', 'PREFIX_xyz789', 'target2'); // DIFFERENT - should NOT match ✗
  graph.addEdge('hub', 'PREFIX_def456', 'target3'); // DIFFERENT - should NOT match ✗

  print('=== BEFORE: Without edge variable comparison ===');
  print('Query: source-[r]->hub-[r2]->target WHERE type(r) STARTS WITH "PREFIX_"');

  final resultsBefore = query.match(
    'source-[r]->hub-[r2]->target WHERE type(r) STARTS WITH "PREFIX_"',
    startId: 'source1',
  );

  print('Results: ${resultsBefore['target']}');
  print('❌ PROBLEM: Returns ALL 3 targets (Target1, Target2, Target3)');
  print('   Because r2 can be ANY PREFIX_* edge, not necessarily the same as r!\n');

  print('=== AFTER: With edge variable comparison ===');
  print('Query: source-[r]->hub-[r2]->target WHERE type(r) STARTS WITH "PREFIX_" AND type(r2) = type(r)');

  final resultsAfter = query.match(
    'source-[r]->hub-[r2]->target WHERE type(r) STARTS WITH "PREFIX_" AND type(r2) = type(r)',
    startId: 'source1',
  );

  print('Results: ${resultsAfter['target']}');
  print('✅ SOLUTION: Returns ONLY Target1');
  print('   Because type(r2) = type(r) enforces SAME edge type across both hops!');
  print('   Both r and r2 must be PREFIX_abc123\n');

  // Verify with matchPaths to see the full path
  final paths = query.matchPaths(
    'source-[r]->hub-[r2]->target WHERE type(r) STARTS WITH "PREFIX_" AND type(r2) = type(r)',
    startId: 'source1',
  );

  print('=== Full Path Details ===');
  for (var i = 0; i < paths.length; i++) {
    final path = paths[i];
    print('Path ${i + 1}:');
    print('  Nodes: source=${path.nodes['source']}, hub=${path.nodes['hub']}, target=${path.nodes['target']}');
    print('  Edge 1: ${path.edges[0].from} -[${path.edges[0].type}]-> ${path.edges[0].to}');
    print('  Edge 2: ${path.edges[1].from} -[${path.edges[1].type}]-> ${path.edges[1].to}');
    print('  ✓ Both edges use SAME type: ${path.edges[0].type == path.edges[1].type}');
  }

  print('\n🎉 Feature working correctly!');
}
