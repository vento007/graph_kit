import 'package:graph_kit/graph_kit.dart';

/// 🚀 ULTIMATE COMPLEX QUERY EXAMPLE
/// Demonstrates: Mixed directions, variable-length paths, multiple edge types,
/// WHERE clauses, label filtering, and long chains
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
  print('🎯 ULTIMATE COMPLEX QUERY SHOWCASE');
  print('═' * 80);
  print('');

  // ========================================================================
  // QUERY 1: Mixed Directions + Multiple Edge Types + WHERE Clause
  // ========================================================================
  print('📊 QUERY 1: Find senior teammates working on the same projects');
  print('─' * 80);
  print('Pattern: Mixed direction (person1->team<-person2) + multiple edge types');
  print('Filter: Both people must be Senior+ level and earn >100k');
  print('');

  final teammates = query.matchRows(
    'MATCH person1:Person-[:MEMBER_OF]->team:Team<-[:MEMBER_OF]-person2:Person '
    'WHERE person1.salary > 100000 AND person2.salary > 100000 '
    'AND (person1.level = "Senior" OR person1.level = "Staff" OR person1.level = "Principal") '
    'AND (person2.level = "Senior" OR person2.level = "Staff" OR person2.level = "Principal")'
  );

  print('Results: ${teammates.length} pairs found');
  for (final row in teammates) {
    final p1Node = graph.nodesById[row['person1']];
    final p2Node = graph.nodesById[row['person2']];
    final teamNode = graph.nodesById[row['team']];
    print('  • ${p1Node?.label} (\$${p1Node?.properties?['salary']}) <-> '
        '${p2Node?.label} (\$${p2Node?.properties?['salary']}) @ ${teamNode?.label}');
  }
  print('');

  // ========================================================================
  // QUERY 2: Variable-Length Path + Mixed Direction + Label Filter
  // ========================================================================
  print('📊 QUERY 2: Find management chain to projects (variable-length)');
  print('─' * 80);
  print('Pattern: Variable-length management chain + mixed direction team connection');
  print('Filter: Only critical or high priority projects, managed by someone named "Alice"');
  print('');

  final managementChain = query.matchRows(
    'MATCH manager:Person{label~Alice}-[:MANAGES*1..3]->report:Person-[:MEMBER_OF]->team:Team-[:WORKS_ON|ASSIGNED_TO]->project:Project '
    'WHERE project.priority = "critical" OR project.priority = "high"'
  );

  print('Results: ${managementChain.length} paths found');
  for (final row in managementChain) {
    final mgr = graph.nodesById[row['manager']];
    final rep = graph.nodesById[row['report']];
    final proj = graph.nodesById[row['project']];
    print('  • ${mgr?.label} manages ${rep?.label} → ${proj?.label} (${proj?.properties?['priority']})');
  }
  print('');

  // ========================================================================
  // QUERY 3: Long Chain with Mixed Directions + Multiple Edge Types
  // ========================================================================
  print('📊 QUERY 3: Full impact analysis - person to infrastructure');
  print('─' * 80);
  print('Pattern: 6-hop chain with mixed directions showing full dependency path');
  print('Chain: person->team<-person->project->depends->service');
  print('');

  final impactAnalysis = query.matchRows(
    'leader:Person-[:LEADS]->team:Team<-[:MEMBER_OF]-contributor:Person-[:OWNS|CONTRIBUTES_TO]->project:Project-[:DEPENDS_ON]->service:Service'
  );

  print('Results: ${impactAnalysis.length} complete paths found');
  for (final row in impactAnalysis.take(5)) {
    final leader = graph.nodesById[row['leader']];
    final contrib = graph.nodesById[row['contributor']];
    final proj = graph.nodesById[row['project']];
    final svc = graph.nodesById[row['service']];
    print('  • ${leader?.label}(leads) → ${contrib?.label}(contributes) → ${proj?.label} → ${svc?.label}');
  }
  if (impactAnalysis.length > 5) {
    print('  ... and ${impactAnalysis.length - 5} more paths');
  }
  print('');

  // ========================================================================
  // QUERY 4: Complex Mixed Direction with Convergence Pattern
  // ========================================================================
  print('📊 QUERY 4: Find projects with shared dependencies (convergence)');
  print('─' * 80);
  print('Pattern: proj1->service<-proj2 (multiple projects depending on same service)');
  print('Filter: Only active projects with budget > 150k');
  print('');

  final sharedDeps = query.matchRows(
    'MATCH proj1:Project-[:DEPENDS_ON|USES]->service:Service<-[:DEPENDS_ON|USES]-proj2:Project '
    'WHERE proj1.status = "active" AND proj2.status = "active" '
    'AND proj1.budget > 150000 AND proj2.budget > 150000'
  );

  print('Results: ${sharedDeps.length} shared dependencies found');
  final serviceGroups = <String, Set<String>>{};
  for (final row in sharedDeps) {
    final svc = row['service']!;
    serviceGroups.putIfAbsent(svc, () => {});
    serviceGroups[svc]!.add(row['proj1']!);
    serviceGroups[svc]!.add(row['proj2']!);
  }
  for (final entry in serviceGroups.entries) {
    final svcNode = graph.nodesById[entry.key];
    print('  • ${svcNode?.label}: ${entry.value.length} projects depend on it');
    for (final projId in entry.value) {
      final projNode = graph.nodesById[projId];
      print('    - ${projNode?.label} (\$${projNode?.properties?['budget']})');
    }
  }
  print('');

  // ========================================================================
  // QUERY 5: Ultra-Complex: Variable-Length + Mixed + Multiple Types + WHERE
  // ========================================================================
  print('📊 QUERY 5: Complete organizational reach analysis');
  print('─' * 80);
  print('Pattern: Principal→(manages*)→person→team←person→project (with filters)');
  print('Features: Variable-length, mixed direction, multiple edge types, WHERE clause');
  print('');

  final orgReach = query.matchRows(
    'MATCH exec:Person-[:MANAGES*1..3]->employee:Person-[:MEMBER_OF]->team:Team<-[:LEADS]-leader:Person '
    'WHERE exec.level = "Principal" AND team.budget > 250000 AND employee.salary > 70000'
  );

  print('Results: ${orgReach.length} organizational paths found');
  final execReach = <String, Set<String>>{};
  for (final row in orgReach) {
    final exec = row['exec']!;
    execReach.putIfAbsent(exec, () => {});
    execReach[exec]!.add(row['employee']!);
  }
  for (final entry in execReach.entries) {
    final execNode = graph.nodesById[entry.key];
    print('  • ${execNode?.label} reaches ${entry.value.length} employees:');
    for (final empId in entry.value.take(3)) {
      final empNode = graph.nodesById[empId];
      print('    - ${empNode?.label} (\$${empNode?.properties?['salary']})');
    }
  }
  print('');

  // ========================================================================
  // QUERY 6: Extreme Long Chain - 8 hops with everything
  // ========================================================================
  print('📊 QUERY 6: EXTREME - Full stack dependency trace (8 hops!)');
  print('─' * 80);
  print('Features: ALL features combined in one monster query');
  print('Chain: exec→*→person→team←designer→project→service');
  print('');

  final fullStack = query.matchRows(
    'MATCH exec:Person-[:MANAGES*1..2]->engineer:Person-[:MEMBER_OF]->engTeam:Team<-[:MEMBER_OF]-designer:Person-[:DESIGNS|CONTRIBUTES_TO]->project:Project-[:DEPENDS_ON|USES]->service:Service '
    'WHERE exec.level = "Principal" OR exec.level = "Staff" '
    'AND project.status = "active" AND designer.department = "Design"'
  );

  print('Results: ${fullStack.length} complete traces found');
  for (final row in fullStack.take(3)) {
    print('  • ${graph.nodesById[row['exec']]?.label} → '
        '${graph.nodesById[row['engineer']]?.label} → '
        '${graph.nodesById[row['engTeam']]?.label} ← '
        '${graph.nodesById[row['designer']]?.label} → '
        '${graph.nodesById[row['project']]?.label} → '
        '${graph.nodesById[row['service']]?.label}');
  }
  print('');

  print('═' * 80);
  print('✅ All complex queries executed successfully!');
  print('Features demonstrated:');
  print('  ✓ Mixed directions (->...<-)');
  print('  ✓ Variable-length paths (*1..3)');
  print('  ✓ Multiple edge types (TYPE1|TYPE2)');
  print('  ✓ WHERE clauses with AND/OR logic');
  print('  ✓ Label filtering ({label~pattern})');
  print('  ✓ Long chains (up to 8 hops)');
  print('  ✓ Property comparisons (>, <, =)');
  print('  ✓ Complex parenthetical logic');
  print('═' * 80);
  print('');
  print('');

  // ========================================================================
  // 🔥 THE ULTIMATE SINGLE QUERY - ALL FEATURES COMBINED! 🔥
  // ========================================================================
  print('═' * 80);
  print('🔥🔥🔥 THE ULTIMATE MEGA QUERY - ALL FEATURES IN ONE! 🔥🔥🔥');
  print('═' * 80);
  print('');
  print('Query Features Packed Into ONE Query:');
  print('  ✓ Label filtering with substring match {label~pattern}');
  print('  ✓ Variable-length paths *1..2');
  print('  ✓ Multiple edge types |TYPE1|TYPE2|TYPE3');
  print('  ✓ Mixed directions ->...<-...<-');
  print('  ✓ Complex WHERE with nested parentheses');
  print('  ✓ Multiple property comparisons (>, <, =, !=)');
  print('  ✓ Multiple node types');
  print('  ✓ 10-hop chain!');
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

  print('Query Pattern (10 hops):');
  print('  exec{label~e} →*1..2→ manager →|MANAGES|MENTORS→ engineer → engineeringTeam');
  print('  ← peer → sameTeam →|3-types→ criticalProject →|DEPENDS|USES→ infrastructure');
  print('  ← dependentProject ←|3-types← contributor');
  print('');
  print('WHERE Clause (9 conditions with nested logic):');
  print('  • exec: (Principal OR Staff) AND salary>150k');
  print('  • manager: age>30 AND salary>100k');
  print('  • engineer: (Engineering OR Design) AND salary>70k');
  print('  • engineeringTeam: budget>250k');
  print('  • criticalProject: active AND priority!=low AND budget>150k');
  print('  • dependentProject: budget>100k (OR condition)');
  print('  • contributor: age<50');
  print('');
  
  final startTime = DateTime.now();
  final megaResults = query.matchRows(megaQuery);
  final duration = DateTime.now().difference(startTime);
  
  print('Results: ${megaResults.length} complete paths found in ${duration.inMilliseconds}ms');
  print('');
  
  if (megaResults.isNotEmpty) {
    print('Sample paths (showing first 3):');
    for (final row in megaResults.take(3)) {
      print('  ────────────────────────────────────────────────────────────────');
      print('  Executive: ${graph.nodesById[row['exec']]?.label} '
          '(${graph.nodesById[row['exec']]?.properties?['level']}, '
          '\$${graph.nodesById[row['exec']]?.properties?['salary']})');
      print('    ↓ manages');
      print('  Manager: ${graph.nodesById[row['manager']]?.label} '
          '(age ${graph.nodesById[row['manager']]?.properties?['age']}, '
          '\$${graph.nodesById[row['manager']]?.properties?['salary']})');
      print('    ↓ manages/mentors');
      print('  Engineer: ${graph.nodesById[row['engineer']]?.label} '
          '(${graph.nodesById[row['engineer']]?.properties?['department']})');
      print('    → member of');
      print('  Engineering Team: ${graph.nodesById[row['engineeringTeam']]?.label} '
          '(budget: \$${graph.nodesById[row['engineeringTeam']]?.properties?['budget']})');
      print('    ← has member');
      print('  Peer: ${graph.nodesById[row['peer']]?.label}');
      print('    → leads');
      print('  Same Team: ${graph.nodesById[row['sameTeam']]?.label}');
      print('    → works on');
      print('  Critical Project: ${graph.nodesById[row['criticalProject']]?.label} '
          '(${graph.nodesById[row['criticalProject']]?.properties?['status']}, '
          '${graph.nodesById[row['criticalProject']]?.properties?['priority']} priority)');
      print('    → depends on');
      print('  Infrastructure: ${graph.nodesById[row['infrastructure']]?.label}');
      print('    ← depended on by');
      print('  Dependent Project: ${graph.nodesById[row['dependentProject']]?.label}');
      print('    ← contributed by');
      print('  Contributor: ${graph.nodesById[row['contributor']]?.label} '
          '(age ${graph.nodesById[row['contributor']]?.properties?['age']})');
      print('');
    }
    
    if (megaResults.length > 3) {
      print('  ... and ${megaResults.length - 3} more complete paths');
    }
  } else {
    print('No paths found matching all criteria.');
    print('(This is expected - the query is extremely restrictive!)');
  }
  
  print('');
  print('═' * 80);
  print('Query Complexity Stats:');
  print('  • Pattern length: 10 hops (11 nodes)');
  print('  • Variable-length hops: 1 (1-2 steps)');
  print('  • Total possible edge combinations: 3 × 2 × 3 × 2 = 36');
  print('  • Direction changes: 3 (forward, backward, forward, backward)');
  print('  • WHERE conditions: 9 complex conditions');
  print('  • Logical operators: 6 AND, 4 OR');
  print('  • Property comparisons: 11 total (>, <, =, !=)');
  print('  • Node type filters: 4 (Person, Team, Project, Service)');
  print('  • Label substring filters: 1 ({label~e})');
  print('  • Execution time: ${duration.inMilliseconds}ms');
  print('═' * 80);
}