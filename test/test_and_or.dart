import 'package:graph_kit/graph_kit.dart';

void main() {
  final graph = Graph<Node>();
  final query = PatternQuery(graph);

  // Setup: Multiple policies
  graph.addNode(Node(id: 'group1', type: 'UserGroup', label: 'Group1'));
  graph.addNode(Node(id: 'policyA', type: 'Policy', label: 'PolicyA'));
  graph.addNode(Node(id: 'policyB', type: 'Policy', label: 'PolicyB'));
  graph.addNode(Node(id: 'policyC', type: 'Policy', label: 'PolicyC'));
  graph.addNode(Node(id: 'destA1', type: 'Dest', label: 'DestA1'));
  graph.addNode(Node(id: 'destA2', type: 'Dest', label: 'DestA2'));
  graph.addNode(Node(id: 'destB1', type: 'Dest', label: 'DestB1'));
  graph.addNode(Node(id: 'destC1', type: 'Dest', label: 'DestC1'));

  // Connect group to policies
  graph.addEdge('group1', 'HAS_POLICY', 'policyA');
  graph.addEdge('group1', 'HAS_POLICY', 'policyB');
  graph.addEdge('group1', 'HAS_POLICY', 'policyC');

  // Policy edges to destinations
  graph.addEdge('policyA', 'DIRECT_policyA', 'destA1');
  graph.addEdge('policyA', 'DIRECT_policyA', 'destA2');
  graph.addEdge('policyB', 'DIRECT_policyB', 'destB1');
  graph.addEdge('policyC', 'DIRECT_policyC', 'destC1');

  print('═══════════════════════════════════════════════════════════');
  print('Test 1: Simple OR with literals');
  print('═══════════════════════════════════════════════════════════\n');

  final test1 = query.match(
    'group-[:HAS_POLICY]->policy-[r]->dest WHERE type(r) = "DIRECT_policyA" OR type(r) = "DIRECT_policyB"',
    startId: 'group1',
  );

  print('Query: WHERE type(r) = "DIRECT_policyA" OR type(r) = "DIRECT_policyB"');
  print('Result: ${test1['dest']}');
  print('Expected: {destA1, destA2, destB1}');
  print(test1['dest']?.containsAll(['destA1', 'destA2', 'destB1']) == true ? '✅ Works!' : '❌ Failed');

  print('\n═══════════════════════════════════════════════════════════');
  print('Test 2: OR with STARTS WITH');
  print('═══════════════════════════════════════════════════════════\n');

  final test2 = query.match(
    'group-[:HAS_POLICY]->policy-[r]->dest WHERE type(r) STARTS WITH "DIRECT_policyA" OR type(r) STARTS WITH "DIRECT_policyB"',
    startId: 'group1',
  );

  print('Query: WHERE type(r) STARTS WITH "DIRECT_policyA" OR type(r) STARTS WITH "DIRECT_policyB"');
  print('Result: ${test2['dest']}');
  print(test2['dest']?.containsAll(['destA1', 'destA2', 'destB1']) == true ? '✅ Works!' : '❌ Failed');

  print('\n═══════════════════════════════════════════════════════════');
  print('Test 3: Parenthesized OR with AND');
  print('═══════════════════════════════════════════════════════════\n');

  // Add a relay scenario
  graph.addNode(Node(id: 'relay', type: 'Relay', label: 'Relay1'));
  graph.addEdge('policyA', 'DIRECT_policyA', 'relay');
  graph.addEdge('policyB', 'DIRECT_policyB', 'relay');
  graph.addNode(Node(id: 'finalA', type: 'Final', label: 'FinalA'));
  graph.addNode(Node(id: 'finalB', type: 'Final', label: 'FinalB'));
  graph.addEdge('relay', 'DIRECT_policyA', 'finalA');
  graph.addEdge('relay', 'DIRECT_policyB', 'finalB');

  final test3 = query.match(
    'group-[:HAS_POLICY]->policy-[r]->relay-[r2]->final WHERE (type(r) = "DIRECT_policyA" OR type(r) = "DIRECT_policyB") AND type(r2) = type(r)',
    startId: 'group1',
  );

  print('Query: WHERE (type(r) = "DIRECT_policyA" OR type(r) = "DIRECT_policyB") AND type(r2) = type(r)');
  print('Result: ${test3['final']}');
  print('Expected: {finalA, finalB}');
  print(test3['final']?.containsAll(['finalA', 'finalB']) == true ? '✅ Works!' : '❌ Failed');
}
