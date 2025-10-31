import 'package:test/test.dart';
import 'package:graph_kit/graph_kit.dart';

/// Test to verify that metadata is OPTIONAL for backend teams
void main() {
  test('metadata is NOT required - backend can omit it', () {
    print('\n${'=' * 70}');
    print('BACKEND TEAM: METADATA IS OPTIONAL!');
    print('=' * 70);
    print('\nYou can send JSON WITHOUT metadata:\n');

    // =========================================================================
    // JSON WITHOUT METADATA - This should work!
    // =========================================================================
    const jsonWithoutMetadata = '''
{
  "version": "1.0",
  "nodes": [
    {
      "id": "alice",
      "type": "User",
      "label": "Alice Johnson",
      "properties": {
        "email": "alice@company.com"
      }
    },
    {
      "id": "bob",
      "type": "User",
      "label": "Bob Smith",
      "properties": {
        "email": "bob@company.com"
      }
    }
  ],
  "edges": [
    {
      "src": "alice",
      "type": "REPORTS_TO",
      "dst": "bob"
    }
  ]
}
''';

    print('─' * 70);
    print(jsonWithoutMetadata);
    print('─' * 70);

    print('\nTesting JSON without metadata...\n');

    // This should work fine - metadata is not required!
    final graph = GraphSerializer.fromJsonString(
      jsonWithoutMetadata,
      Node.fromJson,
    );

    expect(graph.nodesById.length, equals(2));
    expect(graph.nodesById['alice']?.label, equals('Alice Johnson'));
    expect(graph.nodesById['bob']?.label, equals('Bob Smith'));
    expect(graph.outNeighbors('alice', 'REPORTS_TO'), contains('bob'));

    print('✓ JSON without metadata works perfectly!');
    print('✓ Backend does NOT need to send metadata');
    print('✓ All data loaded correctly\n');

    print('${'=' * 70}');
    print('REQUIRED FIELDS (updated):');
    print('=' * 70);
    print('REQUIRED:');
    print('  - version: "1.0"');
    print('  - nodes: [...]');
    print('  - edges: [...]');
    print('\nOPTIONAL (backend can skip):');
    print('  - metadata: {...}  ← NOT NEEDED!');
    print('${'=' * 70}\n');
  });

  test('absolute minimum JSON - just version, nodes, edges', () {
    print('\n${'=' * 70}');
    print('ABSOLUTE MINIMUM JSON FOR BACKEND');
    print('=' * 70);
    print('\nThis is the smallest valid JSON:\n');

    const minimalJson = '''
{
  "version": "1.0",
  "nodes": [
    {"id": "alice", "type": "User", "label": "Alice"},
    {"id": "bob", "type": "User", "label": "Bob"}
  ],
  "edges": [
    {"src": "alice", "type": "REPORTS_TO", "dst": "bob"}
  ]
}
''';

    print('─' * 70);
    print(minimalJson);
    print('─' * 70);

    print('\nTesting minimal JSON...\n');

    final graph = GraphSerializer.fromJsonString(minimalJson, Node.fromJson);

    expect(graph.nodesById.length, equals(2));
    expect(graph.nodesById['alice']?.label, equals('Alice'));
    expect(graph.outNeighbors('alice', 'REPORTS_TO'), contains('bob'));

    print('✓ Absolute minimum JSON works!');
    print('✓ No metadata needed');
    print('✓ No properties needed (if not used)\n');
    print('${'=' * 70}\n');
  });

  test('JSON with metadata still works (but not required)', () {
    print('\n${'=' * 70}');
    print('METADATA IS IGNORED (but harmless if included)');
    print('=' * 70);
    print('\nIf backend sends metadata, it will be ignored:\n');

    const jsonWithMetadata = '''
{
  "version": "1.0",
  "nodes": [
    {"id": "alice", "type": "User", "label": "Alice"}
  ],
  "edges": [],
  "metadata": {
    "nodeCount": 999,
    "edgeCount": 999,
    "serializedAt": "invalid-date",
    "extraField": "ignored"
  }
}
''';

    print('─' * 70);
    print(jsonWithMetadata);
    print('─' * 70);

    print('\nTesting JSON with incorrect metadata...\n');

    // Even with wrong metadata values, deserialization works
    final graph = GraphSerializer.fromJsonString(
      jsonWithMetadata,
      Node.fromJson,
    );

    expect(graph.nodesById.length, equals(1));
    expect(graph.nodesById['alice']?.label, equals('Alice'));

    print('✓ Metadata is completely ignored during deserialization');
    print('✓ Wrong values in metadata dont matter');
    print('✓ Backend can send metadata or not - both work\n');
    print('${'=' * 70}\n');
  });
}
