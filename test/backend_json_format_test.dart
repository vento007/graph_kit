import 'package:test/test.dart';
import 'package:graph_kit/graph_kit.dart';

/// THIS IS THE EXACT JSON FORMAT FOR THE BACKEND TEAM
///
/// Backend devs: Send us JSON in this exact format.
/// This test verifies that the JSON format works correctly.
void main() {
  test('backend sends this exact JSON format - 2 users, 1 edge', () {
    print('\n${'=' * 70}');
    print('BACKEND TEAM: USE THIS EXACT JSON FORMAT');
    print('=' * 70);
    print('\nThis is the JSON your backend should send:\n');

    // =========================================================================
    // THIS IS THE JSON STRING THE BACKEND TEAM SHOULD SEND
    // =========================================================================
    const backendJsonString = '''
{
  "version": "1.0",
  "nodes": [
    {
      "id": "alice",
      "type": "User",
      "label": "Alice Johnson",
      "properties": {
        "email": "alice@company.com",
        "role": "Engineer"
      }
    },
    {
      "id": "bob",
      "type": "User",
      "label": "Bob Smith",
      "properties": {
        "email": "bob@company.com",
        "role": "Manager"
      }
    }
  ],
  "edges": [
    {
      "src": "alice",
      "type": "REPORTS_TO",
      "dst": "bob"
    }
  ],
  "metadata": {
    "nodeCount": 2,
    "edgeCount": 1,
    "serializedAt": "2025-10-27T20:00:00.000000"
  }
}
''';

    print('─' * 70);
    print(backendJsonString);
    print('─' * 70);

    // =========================================================================
    // NOW WE TEST THAT THIS JSON WORKS
    // =========================================================================
    print('\nTesting that this JSON deserializes correctly...\n');

    // Backend sends this JSON string, we receive it and parse it
    final graph = GraphSerializer.fromJsonString(
      backendJsonString,
      Node.fromJson,
    );

    // Verify we got the data correctly
    expect(graph.nodesById.length, equals(2), reason: 'Should have 2 users');

    expect(
      graph.nodesById['alice']?.id,
      equals('alice'),
      reason: 'Alice node should exist with correct id',
    );
    expect(
      graph.nodesById['alice']?.type,
      equals('User'),
      reason: 'Alice should be type User',
    );
    expect(
      graph.nodesById['alice']?.label,
      equals('Alice Johnson'),
      reason: 'Alice should have correct label',
    );
    expect(
      graph.nodesById['alice']?.properties?['email'],
      equals('alice@company.com'),
      reason: 'Alice email property should be preserved',
    );
    expect(
      graph.nodesById['alice']?.properties?['role'],
      equals('Engineer'),
      reason: 'Alice role property should be preserved',
    );

    expect(
      graph.nodesById['bob']?.id,
      equals('bob'),
      reason: 'Bob node should exist with correct id',
    );
    expect(
      graph.nodesById['bob']?.type,
      equals('User'),
      reason: 'Bob should be type User',
    );
    expect(
      graph.nodesById['bob']?.label,
      equals('Bob Smith'),
      reason: 'Bob should have correct label',
    );
    expect(
      graph.nodesById['bob']?.properties?['email'],
      equals('bob@company.com'),
      reason: 'Bob email property should be preserved',
    );
    expect(
      graph.nodesById['bob']?.properties?['role'],
      equals('Manager'),
      reason: 'Bob role property should be preserved',
    );

    // Verify the edge
    expect(
      graph.outNeighbors('alice', 'REPORTS_TO'),
      contains('bob'),
      reason: 'Alice should have REPORTS_TO edge to Bob',
    );

    print('✓ JSON successfully deserialized');
    print('✓ Found 2 users: alice, bob');
    print('✓ All properties preserved (email, role)');
    print('✓ Edge verified: alice REPORTS_TO bob');

    print('\n${'=' * 70}');
    print('REQUIRED FIELDS FOR BACKEND:');
    print('=' * 70);
    print('Top Level:');
    print('  - version: "1.0" (required string)');
    print('  - nodes: [...] (required array)');
    print('  - edges: [...] (required array)');
    print('  - metadata: {...} (required object)');
    print('\nEach Node:');
    print('  - id: "unique_id" (required string)');
    print('  - type: "User" (required string)');
    print('  - label: "Display Name" (required string)');
    print('  - properties: {...} (optional object, any key-value pairs)');
    print('\nEach Edge:');
    print('  - src: "source_node_id" (required string)');
    print('  - type: "EDGE_TYPE" (required string)');
    print('  - dst: "destination_node_id" (required string)');
    print('\nMetadata:');
    print('  - nodeCount: 2 (required integer)');
    print('  - edgeCount: 1 (required integer)');
    print('  - serializedAt: "2025-10-27T..." (required ISO8601 string)');
    print('${'=' * 70}\n');
  });

  test('minimal JSON - just the essentials', () {
    print('\n${'=' * 70}');
    print('MINIMAL JSON EXAMPLE (no properties)');
    print('=' * 70);
    print('\nIf you dont need properties, you can send this simpler format:\n');

    const minimalJson = '''
{
  "version": "1.0",
  "nodes": [
    {
      "id": "alice",
      "type": "User",
      "label": "Alice Johnson"
    },
    {
      "id": "bob",
      "type": "User",
      "label": "Bob Smith"
    }
  ],
  "edges": [
    {
      "src": "alice",
      "type": "REPORTS_TO",
      "dst": "bob"
    }
  ],
  "metadata": {
    "nodeCount": 2,
    "edgeCount": 1,
    "serializedAt": "2025-10-27T20:00:00.000000"
  }
}
''';

    print('─' * 70);
    print(minimalJson);
    print('─' * 70);

    print('\nTesting minimal JSON...\n');

    final graph = GraphSerializer.fromJsonString(minimalJson, Node.fromJson);

    expect(graph.nodesById.length, equals(2));
    expect(graph.nodesById['alice']?.label, equals('Alice Johnson'));
    expect(graph.nodesById['bob']?.label, equals('Bob Smith'));
    expect(graph.outNeighbors('alice', 'REPORTS_TO'), contains('bob'));

    print('✓ Minimal JSON works perfectly!');
    print('✓ Properties field is optional\n');
    print('${'=' * 70}\n');
  });

  test('compact JSON - single line format', () {
    print('\n${'=' * 70}');
    print('COMPACT JSON (for network efficiency)');
    print('=' * 70);
    print('\nSame data, but compact (no whitespace):\n');

    const compactJson = '{"version":"1.0","nodes":[{"id":"alice","type":"User","label":"Alice Johnson","properties":{"email":"alice@company.com","role":"Engineer"}},{"id":"bob","type":"User","label":"Bob Smith","properties":{"email":"bob@company.com","role":"Manager"}}],"edges":[{"src":"alice","type":"REPORTS_TO","dst":"bob"}],"metadata":{"nodeCount":2,"edgeCount":1,"serializedAt":"2025-10-27T20:00:00.000000"}}';

    print('─' * 70);
    print(compactJson);
    print('─' * 70);

    print('\nTesting compact JSON...\n');

    final graph = GraphSerializer.fromJsonString(compactJson, Node.fromJson);

    expect(graph.nodesById.length, equals(2));
    expect(graph.nodesById['alice']?.properties?['email'], equals('alice@company.com'));
    expect(graph.nodesById['bob']?.properties?['role'], equals('Manager'));
    expect(graph.outNeighbors('alice', 'REPORTS_TO'), contains('bob'));

    print('✓ Compact JSON works! (saves bandwidth)');
    print('✓ Both pretty and compact formats are valid\n');
    print('${'=' * 70}\n');
  });
}
