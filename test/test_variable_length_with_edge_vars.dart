import 'package:graph_kit/graph_kit.dart';

/// Test: Can we use variable-length paths with edge variables + WHERE?
///
/// Goal: Replace this:
///   policy-[r]->relay-[r2]->destination WHERE type(r) = type(r2)
/// With this:
///   policy-[r*1..2]->destination WHERE type(r) STARTS WITH "DIRECT_"

void main() {
  final graph = Graph<Node>();
  final query = PatternQuery(graph);

  // Setup: Policy -> Relay -> Destination (2 hops)
  graph.addNode(Node(id: 'policy1', type: 'Policy', label: 'Policy1'));
  graph.addNode(Node(id: 'relay1', type: 'Relay', label: 'Relay1'));
  graph.addNode(Node(id: 'dest1', type: 'Dest', label: 'Dest1'));
  graph.addNode(Node(id: 'dest2', type: 'Dest', label: 'Dest2')); // Direct

  // Policy uses DIRECT_p1
  graph.addEdge('policy1', 'DIRECT_p1', 'relay1');
  graph.addEdge('policy1', 'DIRECT_p1', 'dest2'); // 1-hop direct path

  // Relay has edges with SAME and DIFFERENT types
  graph.addEdge('relay1', 'DIRECT_p1', 'dest1');    // Same type (good)

  print('═══════════════════════════════════════════════════════════');
  print('Test 1: Current approach (explicit hops with edge variables)');
  print('═══════════════════════════════════════════════════════════\n');

  final current = query.match(
    'policy-[r]->relay-[r2]->destination WHERE type(r) STARTS WITH "DIRECT_" AND type(r2) = type(r)',
    startId: 'policy1',
  );

  print('Query: policy-[r]->relay-[r2]->destination WHERE type(r) STARTS WITH "DIRECT_" AND type(r2) = type(r)');
  print('Result: ${current['destination']}');
  print('Expected: {dest1} (2-hop path through relay)\n');

  print('═══════════════════════════════════════════════════════════');
  print('Test 2: Variable-length with edge variable + WHERE');
  print('═══════════════════════════════════════════════════════════\n');

  try {
    final varLength = query.match(
      'policy-[r*1..2]->destination WHERE type(r) STARTS WITH "DIRECT_"',
      startId: 'policy1',
    );

    print('Query: policy-[r*1..2]->destination WHERE type(r) STARTS WITH "DIRECT_"');
    print('Result: ${varLength['destination']}');
    print('Expected: {dest1, dest2} (1-hop and 2-hop paths)\n');

    if (varLength['destination']?.containsAll(['dest1', 'dest2']) == true) {
      print('✅ Variable-length with edge variables WORKS!');
    } else {
      print('⚠️  Partial results - may need edge type consistency check');
    }
  } catch (e) {
    print('❌ Error: $e\n');
    print('Variable-length with edge variables is NOT supported yet.');
  }

  print('\n═══════════════════════════════════════════════════════════');
  print('Test 3: Can variable-length enforce type consistency?');
  print('═══════════════════════════════════════════════════════════\n');

  // Add a relay with DIFFERENT edge type (wrong policy)
  graph.addNode(Node(id: 'relay2', type: 'Relay', label: 'Relay2'));
  graph.addNode(Node(id: 'dest3', type: 'Dest', label: 'Dest3'));
  graph.addEdge('policy1', 'DIRECT_p1', 'relay2');
  graph.addEdge('relay2', 'DIRECT_OTHER', 'dest3'); // Different type!

  try {
    final varLength2 = query.match(
      'policy-[r*1..2]->destination WHERE type(r) STARTS WITH "DIRECT_"',
      startId: 'policy1',
    );

    print('Query: policy-[r*1..2]->destination WHERE type(r) STARTS WITH "DIRECT_"');
    print('Added: relay2 with DIRECT_p1 to relay, but DIRECT_OTHER to dest3');
    print('Result: ${varLength2['destination']}');

    if (varLength2['destination']?.contains('dest3') == true) {
      print('\n⚠️  PROBLEM: dest3 is included but uses DIFFERENT edge type!');
      print('   Variable-length paths do NOT enforce type consistency across hops.');
      print('   You still need: type(r) STARTS WITH "DIRECT_" AND type(r2) = type(r)');
    } else {
      print('\n✅ Type consistency enforced!');
    }
  } catch (e) {
    print('❌ Error: $e');
  }

  print('\n═══════════════════════════════════════════════════════════');
  print('Conclusion:');
  print('═══════════════════════════════════════════════════════════');
  print('Variable-length syntax: -[r*1..2]->');
  print('With edge variable WHERE: WHERE type(r) STARTS WITH "DIRECT_"');
  print('');
  print('This would be a SHORTHAND for explicit multi-hop queries, but:');
  print('- Need to check if edge variable binding works with variable-length');
  print('- Need to verify if type consistency is enforced across hops');
  print('- May need additional syntax like WHERE all(x IN r WHERE type(x) = type(r[0]))');
}
