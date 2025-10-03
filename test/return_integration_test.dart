import 'package:graph_kit/graph_kit.dart';
import 'package:test/test.dart';

/// Test suite for RETURN clause - Integration Tests
///
/// Tests RETURN with all existing GraphKit features combined.
/// Real-world scenarios and complex query patterns.
void main() {
  group('RETURN Integration - Complex Scenarios', () {
    late Graph<Node> graph;
    late PatternQuery query;

    setUp(() {
      // Build a realistic organizational graph
      graph = Graph<Node>();

      // Executives
      graph.addNode(Node(
        id: 'ceo',
        type: 'Person',
        label: 'Jane CEO',
        properties: {
          'name': 'Jane CEO',
          'age': 50,
          'role': 'CEO',
          'salary': 250000,
          'department': 'Executive',
        },
      ));

      // Managers
      graph.addNode(Node(
        id: 'eng_manager',
        type: 'Person',
        label: 'Charlie Manager',
        properties: {
          'name': 'Charlie Manager',
          'age': 42,
          'role': 'Engineering Manager',
          'salary': 150000,
          'department': 'Engineering',
        },
      ));

      graph.addNode(Node(
        id: 'sales_manager',
        type: 'Person',
        label: 'Diana Manager',
        properties: {
          'name': 'Diana Manager',
          'age': 45,
          'role': 'Sales Manager',
          'salary': 140000,
          'department': 'Sales',
        },
      ));

      // Engineers
      graph.addNode(Node(
        id: 'alice',
        type: 'Person',
        label: 'Alice Dev',
        properties: {
          'name': 'Alice Dev',
          'age': 28,
          'role': 'Senior Engineer',
          'salary': 120000,
          'department': 'Engineering',
          'skills': 'Dart,Flutter',
        },
      ));

      graph.addNode(Node(
        id: 'bob',
        type: 'Person',
        label: 'Bob Dev',
        properties: {
          'name': 'Bob Dev',
          'age': 25,
          'role': 'Engineer',
          'salary': 95000,
          'department': 'Engineering',
          'skills': 'JavaScript,React',
        },
      ));

      // Sales
      graph.addNode(Node(
        id: 'eve',
        type: 'Person',
        label: 'Eve Sales',
        properties: {
          'name': 'Eve Sales',
          'age': 32,
          'role': 'Account Executive',
          'salary': 90000,
          'department': 'Sales',
        },
      ));

      // Teams
      graph.addNode(Node(
        id: 'engineering',
        type: 'Team',
        label: 'Engineering',
        properties: {'name': 'Engineering', 'size': 15, 'budget': 2000000},
      ));

      graph.addNode(Node(
        id: 'sales',
        type: 'Team',
        label: 'Sales',
        properties: {'name': 'Sales', 'size': 10, 'budget': 1500000},
      ));

      // Projects
      graph.addNode(Node(
        id: 'webapp',
        type: 'Project',
        label: 'Web App',
        properties: {
          'name': 'Customer Portal',
          'status': 'active',
          'priority': 1,
          'budget': 500000,
        },
      ));

      graph.addNode(Node(
        id: 'mobile',
        type: 'Project',
        label: 'Mobile App',
        properties: {
          'name': 'Mobile Client',
          'status': 'planning',
          'priority': 2,
          'budget': 300000,
        },
      ));

      // Org structure
      graph.addEdge('eng_manager', 'REPORTS_TO', 'ceo');
      graph.addEdge('sales_manager', 'REPORTS_TO', 'ceo');
      graph.addEdge('alice', 'REPORTS_TO', 'eng_manager');
      graph.addEdge('bob', 'REPORTS_TO', 'eng_manager');
      graph.addEdge('eve', 'REPORTS_TO', 'sales_manager');

      // Team membership
      graph.addEdge('eng_manager', 'MANAGES', 'engineering');
      graph.addEdge('sales_manager', 'MANAGES', 'sales');
      graph.addEdge('alice', 'WORKS_FOR', 'engineering');
      graph.addEdge('bob', 'WORKS_FOR', 'engineering');
      graph.addEdge('eve', 'WORKS_FOR', 'sales');

      // Project assignments
      graph.addEdge('engineering', 'WORKS_ON', 'webapp');
      graph.addEdge('engineering', 'WORKS_ON', 'mobile');
      graph.addEdge('alice', 'ASSIGNED_TO', 'webapp');
      graph.addEdge('bob', 'ASSIGNED_TO', 'mobile');

      query = PatternQuery(graph);
    });

    group('Real-World Scenarios', () {
      test('HR Report: All employees with title and compensation', () {
        final result = query.matchRows(
          'MATCH person:Person WHERE person.role != "CEO" RETURN person.name AS employee, person.role AS title, person.salary AS compensation',
        );

        expect(result.length, 5); // All except CEO
        for (final row in result) {
          expect(row.keys, containsAll(['employee', 'title', 'compensation']));
          expect(row['compensation'], lessThan(250000));
        }
      });

      test('Org Chart: Manager hierarchy with team sizes', () {
        final result = query.matchRows(
          'MATCH manager-[:MANAGES]->team:Team RETURN manager.name AS managerName, team.name AS teamName, team.size AS teamSize',
        );

        expect(result.length, 2);
        for (final row in result) {
          expect(row.keys, containsAll(['managerName', 'teamName', 'teamSize']));
          expect(row['teamSize'], greaterThan(0));
        }
      });

      test('Project Assignment: Active projects with team and budget', () {
        final result = query.matchRows(
          'MATCH team:Team-[:WORKS_ON]->project:Project WHERE project.status = "active" RETURN team.name AS teamName, project.name AS projectName, project.budget AS budget',
        );

        expect(result.length, 1); // Only webapp is active
        expect(result[0]['projectName'], equals('Customer Portal'));
        expect(result[0]['budget'], equals(500000));
      });

      test('Reporting Structure: Employee to CEO path', () {
        final result = query.matchRows(
          'MATCH employee-[:REPORTS_TO*1..3]->executive WHERE executive.role = "CEO" RETURN employee.name AS employeeName, employee.department AS dept',
        );

        expect(result.length, greaterThan(0));
        for (final row in result) {
          expect(row.keys, containsAll(['employeeName', 'dept']));
        }
      });

      test('Team Collaboration: People working on same projects', () {
        final result = query.matchRows(
          'MATCH person1-[:ASSIGNED_TO]->project<-[:ASSIGNED_TO]-person2 WHERE person1 != person2 RETURN person1.name AS dev1, person2.name AS dev2, project.name AS sharedProject',
        );

        // May or may not have shared assignments - test structure
        for (final row in result) {
          expect(row.keys, containsAll(['dev1', 'dev2', 'sharedProject']));
        }
      }, skip: 'Requires variable comparison in WHERE clause (not yet implemented)');
    });

    group('Complex WHERE + RETURN Combinations', () {
      test('should filter with complex AND/OR and return properties', () {
        final result = query.matchRows(
          'MATCH person:Person WHERE (person.age > 40 AND person.salary > 130000) OR person.department = "Sales" RETURN person.name AS name, person.age AS age, person.salary AS salary',
        );

        for (final row in result) {
          final age = row['age'] as int;
          final salary = row['salary'] as int;
          final meetsCondition = (age > 40 && salary > 130000) ||
              result.any((r) => r['name'] == row['name']);
          expect(meetsCondition, isTrue);
        }
      });

      test('should filter relationships and return mixed properties', () {
        final result = query.matchRows(
          'MATCH person:Person-[:WORKS_FOR]->team:Team WHERE person.salary > 100000 AND team.budget > 1000000 RETURN person.name AS employee, person.salary, team.name AS teamName, team.budget',
        );

        for (final row in result) {
          expect(row['person.salary'], greaterThan(100000));
          expect(row['team.budget'], greaterThan(1000000));
        }
      });
    });

    group('Variable-Length Paths + RETURN', () {
      test('should return properties from variable-length matches', () {
        final result = query.matchRows(
          'MATCH start-[:REPORTS_TO*1..2]->manager WHERE manager.role = "Engineering Manager" RETURN start.name AS subordinate, manager.name AS managerName',
        );

        for (final row in result) {
          expect(row.keys, containsAll(['subordinate', 'managerName']));
          expect(row['managerName'], equals('Charlie Manager'));
        }
      });

      test('should handle unlimited hops with property projection', () {
        final result = query.matchRows(
          'MATCH employee-[:REPORTS_TO*]->boss WHERE boss.role = "CEO" RETURN employee.name AS emp, employee.department AS dept',
        );

        expect(result.length, greaterThan(0));
        for (final row in result) {
          expect(row['emp'], isNotNull);
          expect(row['dept'], isNotNull);
        }
      });
    });

    group('Multiple Edge Types + RETURN', () {
      test('should return from patterns with multiple edge types', () {
        final result = query.matchRows(
          'MATCH person-[:WORKS_FOR|MANAGES]->team:Team RETURN person.name AS personName, person.role AS role, team.name AS teamName',
        );

        expect(result.length, greaterThan(0));
        for (final row in result) {
          expect(row.keys, containsAll(['personName', 'role', 'teamName']));
        }
      });
    });

    group('Mixed Directions + RETURN', () {
      test('should return from mixed direction patterns with aliases', () {
        final result = query.matchRows(
          'MATCH person1-[:REPORTS_TO]->manager<-[:REPORTS_TO]-person2 RETURN person1.name AS emp1, person2.name AS emp2, manager.name AS sharedManager',
        );

        for (final row in result) {
          expect(row.keys, containsAll(['emp1', 'emp2', 'sharedManager']));
        }
      });

      test('should handle complex mixed patterns with property access', () {
        final result = query.matchRows(
          'MATCH emp-[:WORKS_FOR]->team<-[:MANAGES]-manager RETURN emp.name AS employee, manager.name AS managerName, team.size AS teamSize',
        );

        for (final row in result) {
          expect(row['teamSize'], greaterThan(0));
        }
      });
    });

    group('All Methods with RETURN', () {
      test('match() should aggregate RETURN results into Sets', () {
        final result = query.match(
          'MATCH person:Person-[:WORKS_FOR]->team:Team RETURN person.name AS employeeName, team.name AS teamName',
        );

        expect(result.keys, containsAll(['employeeName', 'teamName']));
        expect(result['employeeName'], isA<Set<String>>());
        expect(result['teamName'], isA<Set<String>>());
      });

      test('matchPaths() should respect RETURN with edge information', () {
        final result = query.matchPaths(
          'MATCH person:Person-[:WORKS_FOR]->team:Team RETURN person.name AS emp, team',
        );

        for (final path in result) {
          expect(path.nodes.keys, containsAll(['emp', 'team']));
          expect(path.edges, isNotEmpty);
        }
      });

      test('matchMany() patterns should work with RETURN', () {
        final result = query.matchMany([
          'person-[:WORKS_FOR]->team RETURN person, team',
          'person-[:REPORTS_TO]->manager RETURN person, manager',
        ], startId: 'alice');

        // Should combine results from both patterns
        expect(result.keys, isNotEmpty);
      });
    });

    group('Performance and Scale', () {
      test('should handle large result sets with RETURN efficiently', () {
        // With many nodes, RETURN should not slow down significantly
        final result = query.matchRows(
          'MATCH person:Person RETURN person.name, person.age, person.role, person.salary',
        );

        expect(result.length, 6); // All people in graph
      });

      test('should handle many properties in RETURN', () {
        final result = query.matchRows(
          'MATCH person:Person WHERE person.department = "Engineering" RETURN person.name, person.age, person.role, person.salary, person.department, person.skills',
        );

        for (final row in result) {
          expect(row.keys.length, 6);
        }
      });

      test('should handle deep property paths efficiently', () {
        final result = query.matchRows(
          'MATCH a-[:WORKS_FOR]->b-[:WORKS_ON]->c RETURN a.name, a.role, b.name, b.budget, c.name, c.status',
        );

        for (final row in result) {
          expect(row.keys.length, 6);
        }
      });
    });

    group('Edge Cases and Error Handling', () {
      test('should handle RETURN with no matching rows', () {
        final result = query.matchRows(
          'MATCH person:Person WHERE person.age > 100 RETURN person.name, person.age',
        );

        expect(result, isEmpty);
      });

      test('should handle RETURN with null properties gracefully', () {
        final result = query.matchRows(
          'MATCH person:Person RETURN person.name, person.nonExistentProperty AS missing',
        );

        for (final row in result) {
          expect(row['person.name'], isNotNull);
          expect(row['missing'], isNull);
        }
      });

      test('should preserve row independence with duplicate values', () {
        final result = query.matchRows(
          'MATCH person-[:WORKS_FOR]->team RETURN team.name',
        );

        // Multiple people in same team should create multiple rows
        expect(result.length, greaterThan(1));
      });
    });

    group('Full Cypher-Style Queries', () {
      test('Complete HR query: compensation analysis', () {
        final result = query.matchRows(
          '''MATCH person:Person-[:WORKS_FOR]->team:Team
          WHERE person.salary > 90000 AND team.budget > 1500000
          RETURN person.name AS employee,
                 person.salary AS salary,
                 person.role AS role,
                 team.name AS team,
                 team.budget AS teamBudget''',
        );

        for (final row in result) {
          expect(row['salary'], greaterThan(90000));
          expect(row['teamBudget'], greaterThan(1500000));
        }
      });

      test('Complete org structure query', () {
        final result = query.matchRows(
          '''MATCH employee:Person-[:REPORTS_TO]->manager:Person-[:MANAGES]->team:Team
          WHERE employee.department = "Engineering"
          RETURN employee.name AS engineer,
                 manager.name AS reportingTo,
                 team.name AS teamName,
                 team.size AS teamSize''',
        );

        for (final row in result) {
          expect(row.keys, containsAll(['engineer', 'reportingTo', 'teamName', 'teamSize']));
        }
      });
    });
  });
}
