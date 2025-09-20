import 'package:graph_kit/graph_kit.dart';

/// Demonstrates the Graph Algorithms functionality
///
/// Run with: dart run example/algorithms_demo.dart
void main() {
  print('=== Graph Kit Algorithms Demo ===\n');

  // Create a sample graph representing project dependencies
  final graph = Graph<Node>();
  final algorithms = GraphAlgorithms(graph);

  _setupDependencyGraph(graph);
  _runShortestPathDemo(algorithms);
  _runConnectedComponentsDemo(algorithms);
  _runReachabilityDemo(algorithms);
  _runTopologicalSortDemo(algorithms);
}

void _setupDependencyGraph(Graph<Node> graph) {
  print('Setting up dependency graph...\n');

  // Add nodes representing packages/modules
  graph.addNode(Node(id: 'core', type: 'Package', label: 'Core Library'));
  graph.addNode(Node(id: 'utils', type: 'Package', label: 'Utilities'));
  graph.addNode(Node(id: 'api', type: 'Package', label: 'API Client'));
  graph.addNode(Node(id: 'database', type: 'Package', label: 'Database'));
  graph.addNode(Node(id: 'ui', type: 'Package', label: 'UI Components'));
  graph.addNode(Node(id: 'auth', type: 'Package', label: 'Authentication'));
  graph.addNode(Node(id: 'app', type: 'Package', label: 'Main App'));

  // Add isolated node for testing
  graph.addNode(Node(id: 'legacy', type: 'Package', label: 'Legacy Module'));

  // Add dependency relationships (A DEPENDS_ON B means A needs B)
  graph.addEdge('utils', 'DEPENDS_ON', 'core');
  graph.addEdge('api', 'DEPENDS_ON', 'core');
  graph.addEdge('api', 'DEPENDS_ON', 'utils');
  graph.addEdge('database', 'DEPENDS_ON', 'core');
  graph.addEdge('auth', 'DEPENDS_ON', 'api');
  graph.addEdge('auth', 'DEPENDS_ON', 'database');
  graph.addEdge('ui', 'DEPENDS_ON', 'core');
  graph.addEdge('ui', 'DEPENDS_ON', 'utils');
  graph.addEdge('app', 'DEPENDS_ON', 'ui');
  graph.addEdge('app', 'DEPENDS_ON', 'auth');

  print('Added ${graph.nodesById.length} packages with dependency relationships:');
  print('• app → auth, ui');
  print('• auth → api, database');
  print('• api → core, utils');
  print('• database → core');
  print('• ui → core, utils');
  print('• utils → core');
  print('• legacy (isolated)\n');
}

void _runShortestPathDemo(GraphAlgorithms<Node> algorithms) {
  print('🛤️  Shortest Path Analysis\n');

  // Find shortest path between packages
  final result1 = algorithms.shortestPath('app', 'core');
  print('Path from app to core:');
  if (result1.found) {
    print('  Route: ${result1.path.join(' → ')}');
    print('  Distance: ${result1.distance} steps\n');
  } else {
    print('  No path found\n');
  }

  // Test another path
  final result2 = algorithms.shortestPath('auth', 'core');
  print('Path from auth to core:');
  if (result2.found) {
    print('  Route: ${result2.path.join(' → ')}');
    print('  Distance: ${result2.distance} steps\n');
  }

  // Test path to isolated node
  final result3 = algorithms.shortestPath('app', 'legacy');
  print('Path from app to legacy:');
  if (result3.found) {
    print('  Route: ${result3.path.join(' → ')}');
  } else {
    print('  No path found (isolated node)\n');
  }
}

void _runConnectedComponentsDemo(GraphAlgorithms<Node> algorithms) {
  print('🔗 Connected Components Analysis\n');

  final components = algorithms.connectedComponents();
  print('Found ${components.length} connected components:');

  for (int i = 0; i < components.length; i++) {
    final component = components[i];
    print('  Component ${i + 1}: {${component.join(', ')}}');

    if (component.length == 1) {
      print('    → Isolated module');
    } else {
      print('    → ${component.length} interconnected packages');
    }
  }
  print('');
}

void _runReachabilityDemo(GraphAlgorithms<Node> algorithms) {
  print('🎯 Reachability Analysis\n');

  // Find all packages that depend on core (directly or indirectly)
  final reachableFromCore = algorithms.reachableFrom('core');
  print('Packages reachable from core:');
  print('  ${reachableFromCore.join(', ')}');
  print('  → ${reachableFromCore.length} packages can be reached from core\n');

  // Find all dependencies of app
  final reachableFromApp = algorithms.reachableFrom('app');
  print('All dependencies of app (transitive):');
  print('  ${reachableFromApp.join(', ')}');
  print('  → app depends on ${reachableFromApp.length - 1} other packages\n');

  // Check legacy isolation
  final reachableFromLegacy = algorithms.reachableFrom('legacy');
  print('Packages reachable from legacy:');
  print('  ${reachableFromLegacy.join(', ')}');
  print('  → legacy is truly isolated\n');
}

void _runTopologicalSortDemo(GraphAlgorithms<Node> algorithms) {
  print('📋 Topological Sort (Build Order)\n');

  try {
    final buildOrder = algorithms.topologicalSort();
    print('Recommended build order (dependencies first):');
    for (int i = 0; i < buildOrder.length; i++) {
      final package = buildOrder[i];
      print('  ${i + 1}. $package');
    }
    print('\n  → This order ensures all dependencies are built before dependents');
  } catch (e) {
    print('Error: $e');
  }

  // Demonstrate cycle detection by creating a cycle
  print('\n🔄 Testing cycle detection...');
  final cyclicGraph = Graph<Node>();
  final cyclicAlgorithms = GraphAlgorithms(cyclicGraph);

  // Create nodes
  cyclicGraph.addNode(Node(id: 'a', type: 'Package', label: 'Package A'));
  cyclicGraph.addNode(Node(id: 'b', type: 'Package', label: 'Package B'));
  cyclicGraph.addNode(Node(id: 'c', type: 'Package', label: 'Package C'));

  // Create cycle: a → b → c → a
  cyclicGraph.addEdge('a', 'DEPENDS_ON', 'b');
  cyclicGraph.addEdge('b', 'DEPENDS_ON', 'c');
  cyclicGraph.addEdge('c', 'DEPENDS_ON', 'a');

  try {
    final cyclicOrder = cyclicAlgorithms.topologicalSort();
    print('Unexpected: got order $cyclicOrder');
  } catch (e) {
    print('✓ Correctly detected cycle: $e');
  }

  print('\n=== Demo Complete ===');
}