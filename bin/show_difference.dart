import 'package:graph_kit/graph_kit.dart';

/// This demonstrates the DIFFERENCE between:
/// 1. type(r2) STARTS WITH "DIRECT_" (allows different DIRECT_* types)
/// 2. type(r2) = type(r) (enforces SAME type)

void main() {
  final graph = Graph<Node>();
  final query = PatternQuery(graph);

  // Setup mimicking your real scenario
  graph.addNode(Node(id: 'mike_uk', type: 'Policy', label: 'Mike UK'));
  graph.addNode(Node(id: 'node3', type: 'Relay', label: 'Node3'));
  graph.addNode(Node(id: 'correct_dest', type: 'Dest', label: 'Correct'));
  graph.addNode(Node(id: 'wrong_dest1', type: 'Dest', label: 'Wrong1'));
  graph.addNode(Node(id: 'wrong_dest2', type: 'Dest', label: 'Wrong2'));

  // Mike UK uses DIRECT_42714bbf
  graph.addEdge('mike_uk', 'DIRECT_42714bbf', 'node3');

  // Node3 has DIRECT edges from MULTIPLE policies
  graph.addEdge('node3', 'DIRECT_42714bbf', 'correct_dest'); // Mike UK's edge
  graph.addEdge('node3', 'DIRECT_36bd621e', 'wrong_dest1');  // Other policy
  graph.addEdge('node3', 'DIRECT_9bf008c1', 'wrong_dest2');  // Other policy

  print('═══════════════════════════════════════════════════════════');
  print('WRONG QUERY (What you currently have):');
  print('═══════════════════════════════════════════════════════════\n');

  final wrong = query.matchPaths(
    'policy-[r]->relay-[r2]->destination WHERE type(r) STARTS WITH "DIRECT_" AND type(r2) STARTS WITH "DIRECT_"',
    startId: 'mike_uk',
  );

  print('Query: WHERE type(r) STARTS WITH "DIRECT_" AND type(r2) STARTS WITH "DIRECT_"');
  print('Result: ${wrong.length} paths found\n');

  for (var i = 0; i < wrong.length; i++) {
    final p = wrong[i];
    print('Path ${i + 1}:');
    print('  ${p.nodes['policy']} -[${p.edges[0].type}]-> ${p.nodes['relay']} -[${p.edges[1].type}]-> ${p.nodes['destination']}');
  }

  print('\n❌ PROBLEM: Returns ALL 3 paths because r2 can be ANY DIRECT_* type!\n');

  print('═══════════════════════════════════════════════════════════');
  print('CORRECT QUERY (What you should use):');
  print('═══════════════════════════════════════════════════════════\n');

  final correct = query.matchPaths(
    'policy-[r]->relay-[r2]->destination WHERE type(r) STARTS WITH "DIRECT_" AND type(r2) = type(r)',
    startId: 'mike_uk',
  );

  print('Query: WHERE type(r) STARTS WITH "DIRECT_" AND type(r2) = type(r)');
  print('Result: ${correct.length} path found\n');

  for (var i = 0; i < correct.length; i++) {
    final p = correct[i];
    print('Path ${i + 1}:');
    print('  ${p.nodes['policy']} -[${p.edges[0].type}]-> ${p.nodes['relay']} -[${p.edges[1].type}]-> ${p.nodes['destination']}');
  }

  print('\n✅ SOLUTION: Returns ONLY 1 path because type(r2) = type(r) enforces SAME type!');
  print('   Both edges must be DIRECT_42714bbf\n');

  print('═══════════════════════════════════════════════════════════');
  print('TO FIX YOUR APP:');
  print('═══════════════════════════════════════════════════════════');
  print('Replace:   AND type(r2) STARTS WITH "DIRECT_"');
  print('With:      AND type(r2) = type(r)');
  print('═══════════════════════════════════════════════════════════');
}
