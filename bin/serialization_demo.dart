#!/usr/bin/env dart

import 'package:graph_kit/graph_kit.dart';

void main() {
  print('=== Graph Kit Serialization Demo ===\n');

  // Create a simple graph
  final graph = Graph<Node>();

  // Add some nodes
  graph.addNode(
    Node(
      id: 'alice',
      type: 'Person',
      label: 'Alice Cooper',
      properties: {'email': 'alice@example.com', 'age': 28},
    ),
  );

  graph.addNode(
    Node(
      id: 'bob',
      type: 'Person',
      label: 'Bob Wilson',
      properties: {'email': 'bob@example.com', 'age': 32},
    ),
  );

  graph.addNode(
    Node(
      id: 'engineering',
      type: 'Team',
      label: 'Engineering Team',
      properties: {'budget': 150000, 'location': 'SF'},
    ),
  );

  graph.addNode(
    Node(
      id: 'web_project',
      type: 'Project',
      label: 'Web Application',
      properties: {'status': 'active', 'priority': 'high'},
    ),
  );

  // Add some edges
  graph.addEdge('alice', 'WORKS_FOR', 'engineering');
  graph.addEdge('bob', 'WORKS_FOR', 'engineering');
  graph.addEdge('engineering', 'ASSIGNED_TO', 'web_project');
  graph.addEdge('alice', 'LEADS', 'web_project');

  print('Original graph:');
  print('- ${graph.nodesById.length} nodes');
  print(
    '- ${graph.out.values.expand((m) => m.values.expand((s) => s)).length} edges\n',
  );

  // Serialize to pretty JSON
  final jsonString = graph.toJsonString(pretty: true);
  print('Serialized to JSON:');
  print(jsonString);

  print('\n=== Testing Round-trip Serialization ===\n');

  // Deserialize back to graph
  final restoredGraph = GraphSerializer.fromJsonString(
    jsonString,
    Node.fromJson,
  );

  // Test that queries still work
  final query = PatternQuery(restoredGraph);

  print('Testing queries on restored graph:');

  // Find all people
  final people = query.match('person:Person');
  print('People: ${people["person:Person"]}');

  // Find team members
  final teamMembers = query.match(
    'team<-[:WORKS_FOR]-person',
    startId: 'engineering',
  );
  print('Team members: ${teamMembers["person"]}');

  // Find project leaders
  final leaders = query.match('person-[:LEADS]->project', startId: 'alice');
  print('Alice leads: ${leaders["project"]}');

  // Show that properties are preserved
  final alice = restoredGraph.nodesById['alice']!;
  print('\nAlice after deserialization:');
  print('- Type: ${alice.type}');
  print('- Label: ${alice.label}');
  print('- Properties: ${alice.properties}');

  print('\n✓ Serialization round-trip successful!');
}
