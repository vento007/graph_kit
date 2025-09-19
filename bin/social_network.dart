import 'package:graph_kit/graph_kit.dart';

void main() {
  print('📊 SOCIAL NETWORK ANALYSIS');
  print('==========================\n');

  final graph = Graph<Node>();
  final query = PatternQuery(graph);

  // Build social network
  print('📋 Building social network graph...\n');

  // People
  final people = [
    ('alice', 'Alice Johnson', {'role': 'Developer', 'team': 'Frontend'}),
    ('bob', 'Bob Smith', {'role': 'Designer', 'team': 'UX'}),
    ('charlie', 'Charlie Brown', {'role': 'Manager', 'team': 'Frontend'}),
    ('diana', 'Diana Prince', {'role': 'Developer', 'team': 'Backend'}),
    ('eve', 'Eve Wilson', {'role': 'DevOps', 'team': 'Infrastructure'}),
    ('frank', 'Frank Miller', {'role': 'Developer', 'team': 'Backend'}),
    ('grace', 'Grace Lee', {'role': 'Product Manager', 'team': 'Product'}),
  ];

  for (final (id, name, props) in people) {
    graph.addNode(Node(id: id, type: 'Person', label: name, properties: props));
  }

  // Professional relationships
  graph.addEdge('alice', 'WORKS_WITH', 'bob');
  graph.addEdge('alice', 'REPORTS_TO', 'charlie');
  graph.addEdge('bob', 'WORKS_WITH', 'grace');
  graph.addEdge('diana', 'WORKS_WITH', 'frank');
  graph.addEdge('diana', 'REPORTS_TO', 'charlie');
  graph.addEdge('eve', 'SUPPORTS', 'diana');
  graph.addEdge('eve', 'SUPPORTS', 'frank');
  graph.addEdge('grace', 'COLLABORATES_WITH', 'charlie');

  // Social connections
  graph.addEdge('alice', 'FRIENDS_WITH', 'diana');
  graph.addEdge('bob', 'FRIENDS_WITH', 'alice');
  graph.addEdge('charlie', 'MENTORS', 'alice');
  graph.addEdge('diana', 'MENTORS', 'frank');
  graph.addEdge('grace', 'FRIENDS_WITH', 'eve');

  // Knowledge sharing
  graph.addEdge('alice', 'LEARNS_FROM', 'charlie');
  graph.addEdge('frank', 'LEARNS_FROM', 'diana');
  graph.addEdge('bob', 'LEARNS_FROM', 'grace');

  print('🔍 SOCIAL NETWORK ANALYSIS');
  print('===========================\n');

  // 1. Alice's professional network
  print('1️⃣  Alice\'s professional network:');
  final aliceNetwork = query.matchMany([
    'alice-[:WORKS_WITH]->colleague',
    'alice-[:REPORTS_TO]->manager',
    'alice-[:LEARNS_FROM]->mentor',
  ], startId: 'alice');

  _printNetworkConnections('Alice', aliceNetwork, graph);

  // 2. Who does Charlie manage (directly and indirectly)?
  print('2️⃣  Charlie\'s management scope:');
  final charlieTeam = expandSubgraph(
    graph,
    seeds: {'charlie'},
    edgeTypesRightward: {'REPORTS_TO'},
    backwardHops: 3, // Look for people who report to Charlie
  );

  final directReports = query.inTo('charlie', 'REPORTS_TO');
  print('   👨‍💼 Charlie manages:');
  print('      Direct reports: ${directReports.length}');
  print(
    '      Total team scope: ${charlieTeam.nodes.length - 1} people\n',
  ); // -1 for Charlie himself

  for (final reportId in directReports) {
    final person = graph.nodesById[reportId];
    final props = person?.properties ?? {};
    print('      • ${person?.label} (${props['role']}, ${props['team']} team)');
  }

  // 3. Find potential collaborators for Alice
  print('\n3️⃣  Potential collaborators for Alice (2-hop connections):');
  final aliceCollaborators = expandSubgraph(
    graph,
    seeds: {'alice'},
    edgeTypesRightward: {'WORKS_WITH', 'FRIENDS_WITH', 'LEARNS_FROM'},
    forwardHops: 2,
  );

  final directConnections = query.matchMany([
    'alice-[:WORKS_WITH]->person',
    'alice-[:FRIENDS_WITH]->person',
    'alice-[:LEARNS_FROM]->person',
  ], startId: 'alice');

  final allDirectIds = <String>{};
  for (final ids in directConnections.values) {
    allDirectIds.addAll(ids);
  }

  print('   🤝 People Alice could be introduced to:');
  for (final personId in aliceCollaborators.nodes) {
    if (personId != 'alice' && !allDirectIds.contains(personId)) {
      final person = graph.nodesById[personId];
      final props = person?.properties ?? {};
      final distance = aliceCollaborators.forwardDist[personId] ?? 0;
      print(
        '      • ${person?.label} (${props['role']}) - $distance hops away',
      );
    }
  }

  // 4. Team interaction analysis
  print('\n4️⃣  Cross-team interactions:');
  final teams = <String, Set<String>>{};

  // Group people by team
  for (final person in graph.nodesById.values) {
    final team = person.properties?['team'] as String?;
    if (team != null) {
      teams.putIfAbsent(team, () => {}).add(person.id);
    }
  }

  for (final teamName in teams.keys) {
    print('   🏢 $teamName team interactions:');
    final teamMembers = teams[teamName]!;

    for (final memberId in teamMembers) {
      final member = graph.nodesById[memberId];
      final connections = query.matchMany([
        'person-[:WORKS_WITH]->colleague',
        'person-[:COLLABORATES_WITH]->colleague',
      ], startId: memberId);

      final colleagues = connections['colleague'] ?? {};
      final crossTeamConnections = <String>[];

      for (final colleagueId in colleagues) {
        final colleague = graph.nodesById[colleagueId];
        final colleagueTeam = colleague?.properties?['team'] as String?;
        if (colleagueTeam != null && colleagueTeam != teamName) {
          crossTeamConnections.add('${colleague?.label} ($colleagueTeam)');
        }
      }

      if (crossTeamConnections.isNotEmpty) {
        print('      • ${member?.label} → ${crossTeamConnections.join(', ')}');
      }
    }
  }

  // 5. Knowledge flow analysis
  print('\n5️⃣  Knowledge sharing network:');
  final mentors = query.findByType('Person').where((personId) {
    return query.outFrom(personId, 'MENTORS').isNotEmpty ||
        query.inTo(personId, 'LEARNS_FROM').isNotEmpty;
  });

  for (final mentorId in mentors) {
    final mentor = graph.nodesById[mentorId];
    final mentees = query.outFrom(mentorId, 'MENTORS');
    final students = query.inTo(mentorId, 'LEARNS_FROM');
    final allLearners = {...mentees, ...students};

    if (allLearners.isNotEmpty) {
      print('   🎓 ${mentor?.label} shares knowledge with:');
      for (final learnerId in allLearners) {
        final learner = graph.nodesById[learnerId];
        final relationship = mentees.contains(learnerId)
            ? 'mentors'
            : 'teaches';
        print('      • $relationship ${learner?.label}');
      }
    }
  }

  // 6. Influence analysis
  print('\n6️⃣  Influence network analysis:');
  final influenceScores = <String, int>{};

  for (final personId in graph.nodesById.keys) {
    // Count incoming connections (people influenced by this person)
    final influenced = expandSubgraph(
      graph,
      seeds: {personId},
      edgeTypesRightward: {'MENTORS', 'REPORTS_TO', 'LEARNS_FROM'},
      backwardHops: 2,
    );

    influenceScores[personId] = influenced.nodes.length - 1; // -1 for self
  }

  final sortedInfluence = influenceScores.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));

  print('   📈 People ranked by influence (connections):');
  for (var i = 0; i < sortedInfluence.length && i < 5; i++) {
    final entry = sortedInfluence[i];
    final person = graph.nodesById[entry.key];
    final props = person?.properties ?? {};
    print(
      '      ${i + 1}. ${person?.label} (${props['role']}) - ${entry.value} connections',
    );
  }

  // 7. Shortest path between two people
  print('\n7️⃣  Connection paths:');
  _findShortestPath('alice', 'frank', graph, query);
  _findShortestPath('bob', 'eve', graph, query);
}

void _printNetworkConnections(
  String personName,
  Map<String, Set<String>> network,
  Graph<Node> graph,
) {
  for (final entry in network.entries) {
    if (entry.value.isNotEmpty) {
      print('   ${_getRelationshipIcon(entry.key)} ${entry.key}:');
      for (final personId in entry.value) {
        final person = graph.nodesById[personId];
        final props = person?.properties ?? {};
        print('      • ${person?.label} (${props['role']})');
      }
    }
  }
  print('');
}

String _getRelationshipIcon(String relationship) {
  switch (relationship) {
    case 'colleague':
      return '👥';
    case 'manager':
      return '👨‍💼';
    case 'mentor':
      return '🎓';
    case 'friend':
      return '👋';
    default:
      return '🔗';
  }
}

void _findShortestPath(
  String fromId,
  String toId,
  Graph<Node> graph,
  PatternQuery<Node> query,
) {
  final from = graph.nodesById[fromId];
  final to = graph.nodesById[toId];

  // Use BFS-style expansion to find shortest path
  final expansion = expandSubgraph(
    graph,
    seeds: {fromId},
    edgeTypesRightward: {
      'WORKS_WITH',
      'FRIENDS_WITH',
      'REPORTS_TO',
      'MENTORS',
      'LEARNS_FROM',
      'COLLABORATES_WITH',
      'SUPPORTS',
    },
    forwardHops: 5,
  );

  if (expansion.nodes.contains(toId)) {
    final distance = expansion.forwardDist[toId] ?? 0;
    print('   🗺️  ${from?.label} → ${to?.label}: $distance hops');
  } else {
    print('   🗺️  ${from?.label} → ${to?.label}: No connection found');
  }
}
