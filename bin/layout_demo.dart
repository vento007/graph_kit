import 'package:graph_kit/graph_kit.dart';

void main() {
  print('=' * 70);
  print('GraphLayout Demo: Eliminating Hardcoded Column Positioning');
  print('=' * 70);
  print('');

  // Create a realistic access control graph
  final graph = Graph<Node>();

  // Groups
  graph.addNode(Node(id: 'eng', type: 'Group', label: 'Engineering'));
  graph.addNode(Node(id: 'ops', type: 'Group', label: 'Operations'));

  // Policies
  graph.addNode(Node(id: 'pol1', type: 'Policy', label: 'SSH Access'));
  graph.addNode(Node(id: 'pol2', type: 'Policy', label: 'HTTP Access'));
  graph.addNode(Node(id: 'pol_orphan', type: 'Policy', label: 'Legacy Policy'));

  // Assets
  graph.addNode(Node(id: 'web1', type: 'Asset', label: 'Web Server 1'));
  graph.addNode(Node(id: 'web2', type: 'Asset', label: 'Web Server 2'));
  graph.addNode(Node(id: 'db1', type: 'Asset', label: 'Database Server'));

  // Virtual Assets
  graph.addNode(Node(id: 'port22', type: 'Virtual', label: 'SSH Port'));
  graph.addNode(Node(id: 'port80', type: 'Virtual', label: 'HTTP Port'));

  // Edges: group -> policy -> asset -> virtual
  graph.addEdge('eng', 'CONTAINS', 'pol1');
  graph.addEdge('ops', 'CONTAINS', 'pol2');
  graph.addEdge('pol1', 'APPLIES_TO', 'web1');
  graph.addEdge('pol1', 'APPLIES_TO', 'db1');
  graph.addEdge('pol2', 'APPLIES_TO', 'web2');
  graph.addEdge('pol_orphan', 'APPLIES_TO', 'web1'); // Orphan!
  graph.addEdge('web1', 'CONNECTS_TO', 'port22');
  graph.addEdge('web2', 'CONNECTS_TO', 'port80');
  graph.addEdge('db1', 'CONNECTS_TO', 'port22');

  final query = PatternQuery(graph);
  final paths = query.matchPaths(
    'group-[:CONTAINS]->policy-[:APPLIES_TO]->asset-[:CONNECTS_TO]->virtual',
  );
  final pathsOrphan = query.matchPaths(
    'policy-[:APPLIES_TO]->asset-[:CONNECTS_TO]->virtual',
    startId: 'pol_orphan',
  );

  final allPaths = [...paths, ...pathsOrphan];

  print('Graph structure:');
  print('  ${graph.nodesById.length} nodes');
  print('  ${allPaths.length} paths found');
  print('');

  // ============================================================================
  // BEFORE: Hardcoded column positioning (BAD)
  // ============================================================================
  print('-' * 70);
  print('BEFORE: Hardcoded switch statements (rigid, error-prone)');
  print('-' * 70);
  print('');
  print('```dart');
  print('// Manual column assignment - breaks when graph structure changes');
  print('final layer = switch (columnKey) {');
  print('  \'group\' || \'source\' => 0,');
  print('  \'policy\' || \'src\' => 1,');
  print('  \'asset\' || \'dst\' => 2,');
  print('  \'virtualAsset\' || \'subnet\' => 3,');
  print('  _ => 0,  // Fallback');
  print('};');
  print('');
  print('// What if you add a new node type? Update switch everywhere!');
  print('// What if pattern changes? Manually update hardcoded numbers!');
  print('```');
  print('');

  // ============================================================================
  // AFTER: Automatic layout computation (GOOD)
  // ============================================================================
  print('-' * 70);
  print('AFTER: Automatic layout computation (flexible, correct)');
  print('-' * 70);
  print('');
  print('```dart');
  print('final paths = query.matchPaths(...);');
  print('final layout = paths.computeLayout();');
  print('');
  print('// Column positions computed automatically!');
  print('final groupColumn = layout.variableLayer(\'group\');');
  print('final policyColumn = layout.variableLayer(\'policy\');');
  print('final assetColumn = layout.variableLayer(\'asset\');');
  print('final virtualColumn = layout.variableLayer(\'virtual\');');
  print('```');
  print('');

  final layout = allPaths.computeLayout();

  print('Results:');
  print('  group    → layer ${layout.variableLayer('group')}');
  print('  policy   → layer ${layout.variableLayer('policy')}');
  print('  asset    → layer ${layout.variableLayer('asset')}');
  print('  virtual  → layer ${layout.variableLayer('virtual')}');
  print('');

  // ============================================================================
  // Show detailed layout information
  // ============================================================================
  print('-' * 70);
  print('Detailed Layout Information');
  print('-' * 70);
  print('');

  for (var layer = 0; layer <= layout.maxDepth; layer++) {
    final nodesInLayer = layout.nodesInLayer(layer);
    if (nodesInLayer.isNotEmpty) {
      print('Layer $layer (${nodesInLayer.length} nodes):');
      for (final nodeId in nodesInLayer) {
        final node = graph.nodesById[nodeId];
        print('  - $nodeId: ${node?.label} (${node?.type})');
      }
      print('');
    }
  }

  // ============================================================================
  // Show orphan node handling
  // ============================================================================
  print('-' * 70);
  print('Orphan Node Handling (Advanced Feature)');
  print('-' * 70);
  print('');
  print('Notice that "pol_orphan" is at layer ${layout.layerFor('pol_orphan')}');
  print('But the typical policy layer is ${layout.variableLayer('policy')}');
  print('');
  print('GraphLayout provides BOTH:');
  print('  - nodeDepths: exact structural position for each node');
  print('  - variableDepths: typical position for grouping by variable');
  print('');
  print('For visualization:');
  print('  - Use variableDepths for clean column grouping');
  print('  - Use nodeDepths when structural accuracy matters');
  print('');

  // ============================================================================
  // Show edge information
  // ============================================================================
  print('-' * 70);
  print('Complete Graph Structure');
  print('-' * 70);
  print('');
  print('Roots (entry points): ${layout.roots}');
  print('Max depth: ${layout.maxDepth} layers');
  print('Total edges: ${layout.allEdges.length}');
  print('');

  print('All edges in paths:');
  for (final edge in layout.allEdges) {
    final fromNode = graph.nodesById[edge.src];
    final toNode = graph.nodesById[edge.dst];
    print('  ${fromNode?.label} -[${edge.type}]-> ${toNode?.label}');
  }
  print('');

  // ============================================================================
  // Summary
  // ============================================================================
  print('=' * 70);
  print('SUMMARY: Why GraphLayout is Better');
  print('=' * 70);
  print('');
  print('✓ No hardcoded column positions');
  print('✓ Automatically adapts to graph structure');
  print('✓ Handles orphan nodes gracefully (median strategy)');
  print('✓ Works with any pattern, any node types');
  print('✓ Provides both structural and grouped positioning');
  print('✓ Detects disconnected components and cycles');
  print('');
  print('Use GraphLayout in your visualizations to eliminate brittle,');
  print('hardcoded positioning logic!');
  print('=' * 70);
}
