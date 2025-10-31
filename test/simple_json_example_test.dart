import 'package:test/test.dart';
import 'package:graph_kit/graph_kit.dart';

/// Minimal example showing the exact JSON format for backend integration.
/// This demonstrates: 2 users, 1 edge, serialization, and deserialization.
void main() {
  test('minimal example: 2 users, 1 edge - JSON format for backend', () {
    print('\n${'=' * 70}');
    print('MINIMAL EXAMPLE: 2 Users, 1 Edge - JSON Format for Backend');
    print('=' * 70);

    // =========================================================================
    // STEP 1: Create minimal graph
    // =========================================================================
    final graph = Graph<Node>();

    // Add 2 users
    graph.addNode(Node(
      id: 'alice',
      type: 'User',
      label: 'Alice Johnson',
      properties: {
        'email': 'alice@company.com',
        'role': 'Engineer',
      },
    ));

    graph.addNode(Node(
      id: 'bob',
      type: 'User',
      label: 'Bob Smith',
      properties: {
        'email': 'bob@company.com',
        'role': 'Manager',
      },
    ));

    // Add 1 edge: alice reports to bob
    graph.addEdge('alice', 'REPORTS_TO', 'bob');

    print('\n✓ Created graph: 2 users, 1 edge (alice REPORTS_TO bob)\n');

    // =========================================================================
    // STEP 2: Serialize to JSON
    // =========================================================================
    final jsonString = graph.toJsonString(pretty: true);

    print('JSON TO SEND TO BACKEND:');
    print('─' * 70);
    print(jsonString);
    print('─' * 70);

    // =========================================================================
    // STEP 3: Backend receives this JSON and deserializes
    // =========================================================================
    print('\nBackend receives this JSON and deserializes it:\n');

    final restoredGraph = GraphSerializer.fromJsonString(
      jsonString,
      Node.fromJson,
    );

    // Verify it worked
    expect(restoredGraph.nodesById.length, equals(2));
    expect(restoredGraph.nodesById['alice']?.label, equals('Alice Johnson'));
    expect(restoredGraph.nodesById['bob']?.label, equals('Bob Smith'));
    expect(
      restoredGraph.nodesById['alice']?.properties?['email'],
      equals('alice@company.com'),
    );
    expect(
      restoredGraph.nodesById['bob']?.properties?['role'],
      equals('Manager'),
    );
    expect(restoredGraph.outNeighbors('alice', 'REPORTS_TO'), contains('bob'));

    print('✓ Deserialization successful!');
    print('✓ Retrieved ${restoredGraph.nodesById.length} users');
    print('✓ Alice reports to: ${restoredGraph.outNeighbors('alice', 'REPORTS_TO').first}');
    print("✓ Bob's email: ${restoredGraph.nodesById['bob']?.properties?['email']}");

    // =========================================================================
    // STEP 4: Key points for backend team
    // =========================================================================
    print('\n${'=' * 70}');
    print('KEY POINTS FOR BACKEND TEAM:');
    print('=' * 70);
    print('1. JSON has 4 top-level fields: version, nodes, edges, metadata');
    print('2. Each node has: id (required), type (required), label (required)');
    print('3. Node properties are optional: any Map<String, dynamic>');
    print('4. Each edge has: src (required), type (required), dst (required)');
    print('5. Metadata is auto-generated: nodeCount, edgeCount, serializedAt');
    print('\n✓ This format is bidirectional: serialization ↔ deserialization');
    print('${'=' * 70}\n');
  });

  test('show compact JSON format (no pretty print)', () {
    print('\n${'=' * 70}');
    print('COMPACT JSON (for network transmission)');
    print('=' * 70);

    final graph = Graph<Node>();
    graph.addNode(Node(
      id: 'alice',
      type: 'User',
      label: 'Alice Johnson',
      properties: {'email': 'alice@company.com'},
    ));
    graph.addNode(Node(
      id: 'bob',
      type: 'User',
      label: 'Bob Smith',
      properties: {'email': 'bob@company.com'},
    ));
    graph.addEdge('alice', 'REPORTS_TO', 'bob');

    // Compact format (no pretty printing)
    final compactJson = graph.toJsonString(pretty: false);

    print('\nCompact JSON (single line, smaller size):');
    print('─' * 70);
    print(compactJson);
    print('─' * 70);

    print('\nSize comparison:');
    final prettyJson = graph.toJsonString(pretty: true);
    print('  Pretty format: ${prettyJson.length} bytes');
    print('  Compact format: ${compactJson.length} bytes');
    print('  Savings: ${prettyJson.length - compactJson.length} bytes (${((prettyJson.length - compactJson.length) / prettyJson.length * 100).toStringAsFixed(1)}%)');
    print('${'=' * 70}\n');
  });
}
