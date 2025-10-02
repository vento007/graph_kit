import 'package:graph_kit/graph_kit.dart';

/// 🔥🔥🔥 THE ULTIMATE MEGA QUERY 🔥🔥🔥
/// 
/// This demonstrates the MOST COMPLEX single query possible in graph_kit as per version 0.7.2
/// packing ALL available features into ONE monster query string!
///
/// Features demonstrated:
/// ✓ Label filtering with substring match {label~pattern}
/// ✓ Variable-length paths *1..2
/// ✓ Multiple edge types |TYPE1|TYPE2|TYPE3
/// ✓ Mixed directions ->...<-...<-
/// ✓ Complex WHERE with nested parentheses
/// ✓ Multiple property comparisons (>, <, =, !=)
/// ✓ Multiple node types
/// ✓ 10-hop chain (11 nodes total)!
void main() {
  // Create a realistic tech company organizational graph
  final graph = Graph<Node>();

  // --- Employees ---
  graph.addNode(Node(id: 'alice', type: 'Person', label: 'Alice Chen',
      properties: {'age': 35, 'salary': 120000, 'level': 'Senior', 'department': 'Engineering'}));
  graph.addNode(Node(id: 'bob', type: 'Person', label: 'Bob Smith',
      properties: {'age': 28, 'salary': 85000, 'level': 'Mid', 'department': 'Engineering'}));
  graph.addNode(Node(id: 'charlie', type: 'Person', label: 'Charlie Davis',
      properties: {'age': 42, 'salary': 150000, 'level': 'Staff', 'department': 'Engineering'}));
  graph.addNode(Node(id: 'diana', type: 'Person', label: 'Diana Lee',
      properties: {'age': 31, 'salary': 95000, 'level': 'Senior', 'department': 'Design'}));
  graph.addNode(Node(id: 'eve', type: 'Person', label: 'Eve Martinez',
      properties: {'age': 45, 'salary': 180000, 'level': 'Principal', 'department': 'Engineering'}));
  graph.addNode(Node(id: 'frank', type: 'Person', label: 'Frank Wilson',
      properties: {'age': 26, 'salary': 75000, 'level': 'Junior', 'department': 'Marketing'}));

  // --- Teams ---
  graph.addNode(Node(id: 'backend', type: 'Team', label: 'Backend Team',
      properties: {'budget': 500000, 'headcount': 8}));
  graph.addNode(Node(id: 'frontend', type: 'Team', label: 'Frontend Team',
      properties: {'budget': 400000, 'headcount': 6}));
  graph.addNode(Node(id: 'design', type: 'Team', label: 'Design Team',
      properties: {'budget': 300000, 'headcount': 4}));
  graph.addNode(Node(id: 'marketing', type: 'Team', label: 'Marketing Team',
      properties: {'budget': 250000, 'headcount': 3}));

  // --- Projects ---
  graph.addNode(Node(id: 'api', type: 'Project', label: 'REST API',
      properties: {'status': 'active', 'priority': 'high', 'budget': 200000}));
  graph.addNode(Node(id: 'mobile', type: 'Project', label: 'Mobile App',
      properties: {'status': 'active', 'priority': 'critical', 'budget': 300000}));
  graph.addNode(Node(id: 'web', type: 'Project', label: 'Web Dashboard',
      properties: {'status': 'planning', 'priority': 'medium', 'budget': 150000}));
  graph.addNode(Node(id: 'analytics', type: 'Project', label: 'Analytics Platform',
      properties: {'status': 'active', 'priority': 'high', 'budget': 250000}));

  // --- Infrastructure ---
  graph.addNode(Node(id: 'db_service', type: 'Service', label: 'Database Service'));
  graph.addNode(Node(id: 'auth_service', type: 'Service', label: 'Auth Service'));
  graph.addNode(Node(id: 'cache_service', type: 'Service', label: 'Cache Service'));

  // --- Relationships ---
  // Management hierarchy (variable-length paths)
  graph.addEdge('eve', 'MANAGES', 'charlie');
  graph.addEdge('charlie', 'MANAGES', 'alice');
  graph.addEdge('alice', 'MANAGES', 'bob');
  graph.addEdge('charlie', 'MANAGES', 'diana');

  // Team memberships (mixed directions will be useful here)
  graph.addEdge('alice', 'MEMBER_OF', 'backend');
  graph.addEdge('bob', 'MEMBER_OF', 'backend');
  graph.addEdge('charlie', 'MEMBER_OF', 'backend');
  graph.addEdge('diana', 'MEMBER_OF', 'design');
  graph.addEdge('eve', 'MEMBER_OF', 'backend');
  graph.addEdge('frank', 'MEMBER_OF', 'marketing');

  // Team leadership
  graph.addEdge('alice', 'LEADS', 'backend');
  graph.addEdge('diana', 'LEADS', 'design');

  // Project assignments (multiple edge types)
  graph.addEdge('backend', 'WORKS_ON', 'api');
  graph.addEdge('backend', 'ASSIGNED_TO', 'mobile');
  graph.addEdge('frontend', 'WORKS_ON', 'web');
  graph.addEdge('frontend', 'ASSIGNED_TO', 'mobile');
  graph.addEdge('design', 'WORKS_ON', 'web');
  graph.addEdge('design', 'CONTRIBUTES_TO', 'mobile');
  graph.addEdge('marketing', 'SUPPORTS', 'mobile');

  // Individual contributions
  graph.addEdge('alice', 'OWNS', 'api');
  graph.addEdge('bob', 'CONTRIBUTES_TO', 'api');
  graph.addEdge('charlie', 'REVIEWS', 'api');
  graph.addEdge('diana', 'DESIGNS', 'mobile');

  // Dependencies (for long chains)
  graph.addEdge('api', 'DEPENDS_ON', 'db_service');
  graph.addEdge('api', 'DEPENDS_ON', 'auth_service');
  graph.addEdge('mobile', 'DEPENDS_ON', 'api');
  graph.addEdge('web', 'DEPENDS_ON', 'api');
  graph.addEdge('auth_service', 'DEPENDS_ON', 'db_service');
  graph.addEdge('api', 'USES', 'cache_service');
  graph.addEdge('mobile', 'USES', 'cache_service');

  // Mentorship (creates interesting cycles)
  graph.addEdge('alice', 'MENTORS', 'bob');
  graph.addEdge('charlie', 'MENTORS', 'alice');
  graph.addEdge('eve', 'MENTORS', 'charlie');

  final query = PatternQuery(graph);

  print('═' * 80);
  print('🔥🔥🔥 THE ULTIMATE MEGA QUERY - ALL FEATURES IN ONE! 🔥🔥🔥');
  print('═' * 80);
  print('');
  print('This single query demonstrates MAXIMUM complexity:');
  print('  ✓ Label filtering with substring match {label~pattern}');
  print('  ✓ Variable-length paths *1..2');
  print('  ✓ Multiple edge types |TYPE1|TYPE2|TYPE3');
  print('  ✓ Mixed directions ->...<-...<-');
  print('  ✓ Complex WHERE with nested parentheses');
  print('  ✓ Multiple property comparisons (>, <, =, !=)');
  print('  ✓ Multiple node types (Person, Team, Project, Service)');
  print('  ✓ 10-hop chain (11 nodes)!');
  print('');
  
  final megaQuery = '''
MATCH 
  exec:Person{label~e}-[:MANAGES*1..2]->manager:Person-[:MANAGES|MENTORS]->engineer:Person-[:MEMBER_OF]->engineeringTeam:Team<-[:MEMBER_OF]-peer:Person-[:LEADS]->sameTeam:Team-[:WORKS_ON|ASSIGNED_TO|CONTRIBUTES_TO]->criticalProject:Project-[:DEPENDS_ON|USES]->infrastructure:Service<-[:DEPENDS_ON]-dependentProject:Project<-[:OWNS|CONTRIBUTES_TO|REVIEWS]-contributor:Person
WHERE 
  (exec.level = "Principal" OR exec.level = "Staff") 
  AND exec.salary > 150000 
  AND manager.age > 30 
  AND manager.salary > 100000
  AND (engineer.department = "Engineering" OR engineer.department = "Design")
  AND engineer.salary > 70000
  AND engineeringTeam.budget > 250000
  AND (criticalProject.status = "active" AND criticalProject.priority != "low")
  AND (criticalProject.budget > 150000 OR dependentProject.budget > 100000)
  AND contributor.age < 50
'''.trim();

  print('─' * 80);
  print('QUERY BREAKDOWN:');
  print('─' * 80);
  print('');
  print('Pattern Chain (10 hops, 11 nodes):');
  print('  1. exec:Person{label~e}        → Starts with someone with "e" in name');
  print('  2. -[:MANAGES*1..2]->          → Variable-length: 1-2 management hops');
  print('  3. manager:Person              → Middle manager');
  print('  4. -[:MANAGES|MENTORS]->       → Multiple edge types: manages OR mentors');
  print('  5. engineer:Person             → Engineer being managed/mentored');
  print('  6. -[:MEMBER_OF]->             → Forward: engineer in team');
  print('  7. engineeringTeam:Team        → The team');
  print('  8. <-[:MEMBER_OF]-             → BACKWARD: peer also in same team');
  print('  9. peer:Person                 → Another team member');
  print(' 10. -[:LEADS]->                 → Peer leads a team');
  print(' 11. sameTeam:Team               → Team being led');
  print(' 12. -[:WORKS_ON|ASSIGNED_TO|CONTRIBUTES_TO]-> → 3 edge types!');
  print(' 13. criticalProject:Project     → Project the team works on');
  print(' 14. -[:DEPENDS_ON|USES]->       → Multiple dependency types');
  print(' 15. infrastructure:Service      → Infrastructure service');
  print(' 16. <-[:DEPENDS_ON]-            → BACKWARD: project depends on this');
  print(' 17. dependentProject:Project    → Another dependent project');
  print(' 18. <-[:OWNS|CONTRIBUTES_TO|REVIEWS]- → BACKWARD: 3 edge types');
  print(' 19. contributor:Person          → Person working on dependent project');
  print('');
  print('WHERE Clause (9 conditions with nested logic):');
  print('  1. (exec.level = "Principal" OR exec.level = "Staff")');
  print('  2. exec.salary > 150000');
  print('  3. manager.age > 30');
  print('  4. manager.salary > 100000');
  print('  5. (engineer.department = "Engineering" OR engineer.department = "Design")');
  print('  6. engineer.salary > 70000');
  print('  7. engineeringTeam.budget > 250000');
  print('  8. (criticalProject.status = "active" AND criticalProject.priority != "low")');
  print('  9. (criticalProject.budget > 150000 OR dependentProject.budget > 100000)');
  print(' 10. contributor.age < 50');
  print('');
  
  print('─' * 80);
  print('EXECUTING QUERY...');
  print('─' * 80);
  print('');
  
  final startTime = DateTime.now();
  final megaResults = query.matchRows(megaQuery);
  final duration = DateTime.now().difference(startTime);
  
  print('✅ Results: ${megaResults.length} complete paths found in ${duration.inMilliseconds}ms');
  print('');
  
  if (megaResults.isNotEmpty) {
    print('─' * 80);
    print('SAMPLE PATHS (showing first 3):');
    print('─' * 80);
    print('');
    
    for (final row in megaResults.take(3)) {
      print('  ╔═══════════════════════════════════════════════════════════════╗');
      print('  ║                      COMPLETE PATH TRACE                      ║');
      print('  ╚═══════════════════════════════════════════════════════════════╝');
      print('');
      print('  1️⃣  Executive: ${graph.nodesById[row['exec']]?.label}');
      print('      Level: ${graph.nodesById[row['exec']]?.properties?['level']}');
      print('      Salary: \$${graph.nodesById[row['exec']]?.properties?['salary']}');
      print('      ↓ manages (variable-length)');
      print('');
      print('  2️⃣  Manager: ${graph.nodesById[row['manager']]?.label}');
      print('      Age: ${graph.nodesById[row['manager']]?.properties?['age']}');
      print('      Salary: \$${graph.nodesById[row['manager']]?.properties?['salary']}');
      print('      ↓ manages/mentors');
      print('');
      print('  3️⃣  Engineer: ${graph.nodesById[row['engineer']]?.label}');
      print('      Department: ${graph.nodesById[row['engineer']]?.properties?['department']}');
      print('      Salary: \$${graph.nodesById[row['engineer']]?.properties?['salary']}');
      print('      → member of');
      print('');
      print('  4️⃣  Engineering Team: ${graph.nodesById[row['engineeringTeam']]?.label}');
      print('      Budget: \$${graph.nodesById[row['engineeringTeam']]?.properties?['budget']}');
      print('      ← has member (MIXED DIRECTION)');
      print('');
      print('  5️⃣  Peer: ${graph.nodesById[row['peer']]?.label}');
      print('      → leads');
      print('');
      print('  6️⃣  Same Team: ${graph.nodesById[row['sameTeam']]?.label}');
      print('      → works on');
      print('');
      print('  7️⃣  Critical Project: ${graph.nodesById[row['criticalProject']]?.label}');
      print('      Status: ${graph.nodesById[row['criticalProject']]?.properties?['status']}');
      print('      Priority: ${graph.nodesById[row['criticalProject']]?.properties?['priority']}');
      print('      Budget: \$${graph.nodesById[row['criticalProject']]?.properties?['budget']}');
      print('      → depends on');
      print('');
      print('  8️⃣  Infrastructure: ${graph.nodesById[row['infrastructure']]?.label}');
      print('      ← depended on by (MIXED DIRECTION)');
      print('');
      print('  9️⃣  Dependent Project: ${graph.nodesById[row['dependentProject']]?.label}');
      print('      Budget: \$${graph.nodesById[row['dependentProject']]?.properties?['budget']}');
      print('      ← contributed by (MIXED DIRECTION)');
      print('');
      print('  🔟 Contributor: ${graph.nodesById[row['contributor']]?.label}');
      print('      Age: ${graph.nodesById[row['contributor']]?.properties?['age']}');
      print('');
      print('');
    }
    
    if (megaResults.length > 3) {
      print('  ... and ${megaResults.length - 3} more complete paths');
      print('');
    }
  } else {
    print('No paths found matching all criteria.');
    print('(This is expected - the query is extremely restrictive!)');
    print('');
  }
  
  print('═' * 80);
  print('COMPLEXITY ANALYSIS');
  print('═' * 80);
  print('');
  print('Pattern Complexity:');
  print('  • Total hops: 10 (11 nodes in chain)');
  print('  • Variable-length segments: 1 (allows 1-2 hops)');
  print('  • Direction changes: 3 (forward → backward ← forward → backward ←)');
  print('  • Total possible edge combinations: 3 × 2 × 3 × 2 = 36');
  print('');
  print('Node Filtering:');
  print('  • Node type filters: 4 (Person, Team, Project, Service)');
  print('  • Label substring filters: 1 ({label~e} - finds names containing "e")');
  print('');
  print('Edge Complexity:');
  print('  • Single edge types: 5 segments');
  print('  • Multi-edge segments: 4 (with 2-3 types each)');
  print('  • Total edge types used: 11 distinct types');
  print('');
  print('WHERE Clause Complexity:');
  print('  • Total conditions: 10');
  print('  • Comparison operators: > (5x), < (1x), = (3x), != (1x)');
  print('  • Logical AND operators: 8');
  print('  • Logical OR operators: 4');
  print('  • Nested parentheses: 3 levels');
  print('');
  // Calculate edge count from adjacency structure
  var edgeCount = 0;
  for (final srcMap in graph.out.values) {
    for (final dstSet in srcMap.values) {
      edgeCount += dstSet.length;
    }
  }
  
  print('Performance:');
  print('  • Execution time: ${duration.inMilliseconds}ms');
  print('  • Results found: ${megaResults.length}');
  print('  • Graph size: ${graph.nodesById.length} nodes, $edgeCount edges');
  print('');
  print('═' * 80);
  print('✅ This is probably the most complex single query possible in graph_kit!');
  print('═' * 80);
}
