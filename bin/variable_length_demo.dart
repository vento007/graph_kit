import 'package:graph_kit/graph_kit.dart';
import 'package:graph_kit/src/pattern_query_petit.dart';

void main() {
  print('Graph Kit - Variable-Length Path Demo');
  print('=====================================\n');

  // Create a linear chain to clearly demonstrate hop differences
  final graph = Graph<Node>();

  print('Creating a linear dependency chain...');
  print('A -> B -> C -> D -> E -> F -> G -> H');
  print('(Each arrow represents a DEPENDS_ON relationship)\n');

  // Create a clear linear chain: A depends on B, B depends on C, etc.
  final nodes = ['A', 'B', 'C', 'D', 'E', 'F', 'G', 'H'];
  for (final node in nodes) {
    graph.addNode(Node(id: node, type: 'Component', label: 'Component $node'));
  }

  // Build the dependency chain: A->B->C->D->E->F->G->H
  for (int i = 0; i < nodes.length - 1; i++) {
    graph.addEdge(nodes[i], 'DEPENDS_ON', nodes[i + 1]);
  }

  print('Created dependency chain with ${graph.nodesById.length} components');

  final query = PetitPatternQuery(graph);

  print('\nDemonstrating Variable-Length Hop Differences');
  print('=============================================');
  print('Starting from Component A, what can it reach?\n');

  // Demonstrate clear differences with different hop limits
  final hopPatterns = [
    ('component-[:DEPENDS_ON*1]->dependency', '1 hop only'),
    ('component-[:DEPENDS_ON*1..2]->dependency', '1-2 hops'),
    ('component-[:DEPENDS_ON*1..3]->dependency', '1-3 hops'),
    ('component-[:DEPENDS_ON*3..]->dependency', '3+ hops'),
    ('component-[:DEPENDS_ON*..4]->dependency', 'up to 4 hops'),
    ('component-[:DEPENDS_ON*]->dependency', 'unlimited hops'),
  ];

  for (final (pattern, description) in hopPatterns) {
    print('Pattern: $pattern ($description)');

    try {
      final result = query.matchRows(pattern, startId: 'A');
      print('   Found ${result.length} dependencies:');

      if (result.isNotEmpty) {
        final dependencies = result
            .map((r) => r['dependency']!)
            .toList()
            ..sort();
        print('   ${dependencies.join(', ')}');
      } else {
        print('   (none)');
      }
    } catch (e) {
      print('   Error: $e');
    }
    print('');
  }

  print('Clear Hop Difference Explanation:');
  print('=================================');
  print('* 1 hop: A can directly reach B');
  print('* 1-2 hops: A can reach B (1 hop) and C (2 hops)');
  print('* 1-3 hops: A can reach B, C, D');
  print('* 3+ hops: A can reach D, E, F, G, H (all 3+ hops away)');
  print('* up to 4 hops: A can reach B, C, D, E');
  print('* unlimited: A can reach everything in the chain');

  print('\nAdvanced Example: Finding Dependencies at Specific Distances');
  print('============================================================');

  // Show exact hop patterns
  for (int exactHops = 1; exactHops <= 5; exactHops++) {
    final exactPattern = 'component-[:DEPENDS_ON*$exactHops..$exactHops]->dependency';
    final result = query.matchRows(exactPattern, startId: 'A');

    if (result.isNotEmpty) {
      final deps = result.map((r) => r['dependency']!).join(', ');
      print('Exactly $exactHops hop${exactHops == 1 ? '' : 's'} from A: $deps');
    } else {
      print('Exactly $exactHops hop${exactHops == 1 ? '' : 's'} from A: (none)');
    }
  }

  print('\nVariable-Length Path Features Successfully Demonstrated!');
}