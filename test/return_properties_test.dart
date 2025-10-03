import 'package:graph_kit/graph_kit.dart';
import 'package:test/test.dart';

/// Test suite for RETURN clause - Phase 2: Property access and projection
///
/// Tests RETURN with property access (e.g., RETURN person.name, team.size)
/// Validates property projection, type handling, and null safety.
void main() {
  group('RETURN Property Access', () {
    late Graph<Node> graph;
    late PatternQuery query;

    setUp(() {
      graph = Graph<Node>();

      // Create rich graph with diverse property types
      graph.addNode(Node(
        id: 'alice',
        type: 'Person',
        label: 'Alice Cooper',
        properties: {
          'name': 'Alice Cooper',
          'age': 28,
          'salary': 85000.50,
          'department': 'Engineering',
          'active': true,
          'startDate': '2020-01-15',
        },
      ));

      graph.addNode(Node(
        id: 'bob',
        type: 'Person',
        label: 'Bob Wilson',
        properties: {
          'name': 'Bob Wilson',
          'age': 35,
          'salary': 95000.75,
          'department': 'Engineering',
          'active': true,
          // missing startDate
        },
      ));

      graph.addNode(Node(
        id: 'charlie',
        type: 'Person',
        label: 'Charlie Davis',
        properties: {
          'name': 'Charlie Davis',
          'age': 42,
          'department': 'Management',
          'active': false,
          'startDate': '2015-03-20',
        },
      ));

      graph.addNode(Node(
        id: 'engineering',
        type: 'Team',
        label: 'Engineering',
        properties: {
          'name': 'Engineering',
          'size': 12,
          'budget': 500000.00,
          'active': true,
        },
      ));

      graph.addNode(Node(
        id: 'design',
        type: 'Team',
        label: 'Design',
        properties: {
          'name': 'Design',
          'size': 8,
          'budget': 300000.00,
        },
      ));

      graph.addNode(Node(
        id: 'webapp',
        type: 'Project',
        label: 'Web Application',
        properties: {
          'name': 'Web Application',
          'status': 'active',
          'priority': 1,
        },
      ));

      // Node with no properties
      graph.addNode(Node(
        id: 'emptynode',
        type: 'TestNode',
        label: 'Empty Node',
      ));

      // Edges
      graph.addEdge('alice', 'WORKS_FOR', 'engineering');
      graph.addEdge('bob', 'WORKS_FOR', 'engineering');
      graph.addEdge('charlie', 'MANAGES', 'engineering');
      graph.addEdge('engineering', 'WORKS_ON', 'webapp');

      query = PatternQuery(graph);
    });

    group('Single Property Access', () {
      test('should return single string property', () {
        final result = query.matchRows(
          'MATCH person:Person RETURN person.name',
        );

        expect(result.length, 3);
        for (final row in result) {
          expect(row.keys, contains('person.name'));
          expect(row['person.name'], isA<String>());
          expect(row['person.name'], isNotEmpty);
        }
      });

      test('should return single integer property', () {
        final result = query.matchRows(
          'MATCH person:Person RETURN person.age',
        );

        expect(result.length, 3);
        for (final row in result) {
          expect(row.keys, contains('person.age'));
          expect(row['person.age'], isA<int>());
        }
      });

      test('should return single double property', () {
        final result = query.matchRows(
          'MATCH person:Person RETURN person.salary',
        );

        expect(result.length, greaterThanOrEqualTo(2)); // alice and bob
        for (final row in result) {
          expect(row.keys, contains('person.salary'));
          if (row['person.salary'] != null) {
            expect(row['person.salary'], isA<num>());
          }
        }
      });

      test('should return single boolean property', () {
        final result = query.matchRows(
          'MATCH person:Person RETURN person.active',
        );

        expect(result.length, 3);
        for (final row in result) {
          expect(row.keys, contains('person.active'));
          expect(row['person.active'], isA<bool>());
        }
      });
    });

    group('Multiple Properties from Same Variable', () {
      test('should return two properties from same node', () {
        final result = query.matchRows(
          'MATCH person:Person RETURN person.name, person.age',
        );

        expect(result.length, 3);
        for (final row in result) {
          expect(row.keys, containsAll(['person.name', 'person.age']));
          expect(row['person.name'], isA<String>());
          expect(row['person.age'], isA<int>());
        }
      });

      test('should return three properties from same node', () {
        final result = query.matchRows(
          'MATCH person:Person RETURN person.name, person.age, person.department',
        );

        expect(result.length, 3);
        for (final row in result) {
          expect(row.keys, containsAll(['person.name', 'person.age', 'person.department']));
        }
      });

      test('should return all specified properties even with different types', () {
        final result = query.matchRows(
          'MATCH person:Person RETURN person.name, person.age, person.salary, person.active',
        );

        for (final row in result) {
          expect(row.keys.length, 4);
          expect(row['person.name'], isA<String>());
          expect(row['person.age'], isA<int>());
          if (row['person.salary'] != null) {
            expect(row['person.salary'], isA<num>());
          }
          expect(row['person.active'], isA<bool>());
        }
      });
    });

    group('Properties from Different Variables', () {
      test('should return properties from two different nodes', () {
        final result = query.matchRows(
          'MATCH person:Person-[:WORKS_FOR]->team:Team RETURN person.name, team.name',
        );

        expect(result.length, 2); // alice and bob
        for (final row in result) {
          expect(row.keys, containsAll(['person.name', 'team.name']));
          expect(row['person.name'], isNotNull);
          expect(row['team.name'], equals('Engineering'));
        }
      });

      test('should return multiple properties from multiple nodes', () {
        final result = query.matchRows(
          'MATCH person:Person-[:WORKS_FOR]->team:Team RETURN person.name, person.age, team.name, team.size',
        );

        expect(result.length, 2);
        for (final row in result) {
          expect(row.keys.length, 4);
          expect(row.keys, containsAll(['person.name', 'person.age', 'team.name', 'team.size']));
        }
      });

      test('should return properties from 3-hop pattern', () {
        final result = query.matchRows(
          'MATCH person:Person-[:WORKS_FOR]->team:Team-[:WORKS_ON]->project:Project RETURN person.name, team.size, project.status',
        );

        for (final row in result) {
          expect(row.keys, containsAll(['person.name', 'team.size', 'project.status']));
          expect(row['person.name'], isNotNull);
          expect(row['team.size'], equals(12));
          expect(row['project.status'], equals('active'));
        }
      });
    });

    group('Mix of IDs and Properties', () {
      test('should return both variable ID and its property', () {
        final result = query.matchRows(
          'MATCH person:Person RETURN person, person.name',
        );

        expect(result.length, 3);
        for (final row in result) {
          expect(row.keys, containsAll(['person', 'person.name']));
          expect(row['person'], isA<String>()); // ID
          expect(row['person.name'], isA<String>()); // property
        }
      });

      test('should mix IDs and properties from different variables', () {
        final result = query.matchRows(
          'MATCH person:Person-[:WORKS_FOR]->team:Team RETURN person, team.name',
        );

        expect(result.length, 2);
        for (final row in result) {
          expect(row.keys, containsAll(['person', 'team.name']));
          expect(row['person'], isIn(['alice', 'bob']));
          expect(row['team.name'], equals('Engineering'));
        }
      });

      test('should allow complex mixing of IDs and properties', () {
        final result = query.matchRows(
          'MATCH person:Person-[:WORKS_FOR]->team:Team RETURN person, person.age, team, team.size',
        );

        for (final row in result) {
          expect(row.keys.length, 4);
          expect(row.keys, containsAll(['person', 'person.age', 'team', 'team.size']));
        }
      });
    });

    group('Null Handling - Missing Properties', () {
      test('should return null for missing property', () {
        final result = query.matchRows(
          'MATCH person:Person RETURN person.startDate',
        );

        // Bob doesn't have startDate
        final bobRow = result.where((row) => row['person.startDate'] == null).toList();
        expect(bobRow, isNotEmpty);
      });

      test('should handle mix of present and missing properties', () {
        final result = query.matchRows(
          'MATCH person:Person RETURN person.name, person.startDate',
        );

        expect(result.length, 3);
        for (final row in result) {
          expect(row['person.name'], isNotNull); // All have name
          // startDate may be null for some
        }
      });

      test('should return null for non-existent property', () {
        final result = query.matchRows(
          'MATCH person:Person RETURN person.nonexistent',
        );

        for (final row in result) {
          expect(row['person.nonexistent'], isNull);
        }
      });

      test('should handle properties from node without properties object', () {
        final result = query.matchRows(
          'MATCH node:TestNode RETURN node.anyProperty',
        );

        expect(result.length, 1);
        expect(result[0]['node.anyProperty'], isNull);
      });
    });

    group('Property Access with WHERE Clause', () {
      test('should filter by property then return different property', () {
        final result = query.matchRows(
          'MATCH person:Person WHERE person.age > 30 RETURN person.name',
        );

        expect(result.length, 2); // bob and charlie
        final names = result.map((r) => r['person.name']).toSet();
        expect(names, containsAll(['Bob Wilson', 'Charlie Davis']));
      });

      test('should filter and return same property', () {
        final result = query.matchRows(
          'MATCH person:Person WHERE person.department = "Engineering" RETURN person.name, person.department',
        );

        expect(result.length, 2);
        for (final row in result) {
          expect(row['person.department'], equals('Engineering'));
        }
      });

      test('should combine WHERE with multi-hop property access', () {
        final result = query.matchRows(
          'MATCH person:Person-[:WORKS_FOR]->team:Team WHERE person.active = true RETURN team.name, team.budget',
        );

        expect(result.length, 2); // alice and bob
        for (final row in result) {
          expect(row['team.name'], equals('Engineering'));
          expect(row['team.budget'], equals(500000.00));
        }
      });
    });

    group('Property Access with startId', () {
      test('should return properties when using startId', () {
        final result = query.matchRows(
          'MATCH person-[:WORKS_FOR]->team RETURN person.name, team.size',
          startId: 'alice',
        );

        expect(result.length, 1);
        expect(result[0]['person.name'], equals('Alice Cooper'));
        expect(result[0]['team.size'], equals(12));
      });

      test('should access deep properties from startId', () {
        final result = query.matchRows(
          'MATCH person-[:WORKS_FOR]->team-[:WORKS_ON]->project RETURN project.name, project.priority',
          startId: 'bob',
        );

        expect(result.length, 1);
        expect(result[0]['project.name'], equals('Web Application'));
        expect(result[0]['project.priority'], equals(1));
      });
    });

    group('Property Access with Mixed Directions', () {
      test('should access properties in backward relationship', () {
        final result = query.matchRows(
          'MATCH team:Team<-[:WORKS_FOR]-person:Person RETURN person.name, team.name',
        );

        expect(result.length, 2);
        for (final row in result) {
          expect(row['team.name'], equals('Engineering'));
          expect(row['person.name'], isNotNull);
        }
      });

      test('should handle properties in mixed direction pattern', () {
        final result = query.matchRows(
          'MATCH person1-[:WORKS_FOR]->team<-[:MANAGES]-manager RETURN person1.name, manager.name',
        );

        expect(result.length, 2);
        for (final row in result) {
          expect(row['manager.name'], equals('Charlie Davis'));
          expect(row['person1.name'], isIn(['Alice Cooper', 'Bob Wilson']));
        }
      });
    });

    group('Property Type Diversity', () {
      test('should handle all common data types', () {
        final result = query.matchRows(
          'MATCH person:Person RETURN person.name, person.age, person.salary, person.active',
        );

        for (final row in result) {
          expect(row['person.name'], isA<String>());
          expect(row['person.age'], isA<int>());
          if (row['person.salary'] != null) {
            expect(row['person.salary'], isA<num>());
          }
          expect(row['person.active'], isA<bool>());
        }
      });

      test('should preserve numeric precision', () {
        final result = query.matchRows(
          'MATCH person:Person WHERE person.name = "Alice Cooper" RETURN person.salary',
        );

        expect(result.length, 1);
        expect(result[0]['person.salary'], equals(85000.50));
      });

      test('should handle string properties with special characters', () {
        final result = query.matchRows(
          'MATCH person:Person RETURN person.startDate',
        );

        final withDate = result.where((r) => r['person.startDate'] != null).toList();
        for (final row in withDate) {
          expect(row['person.startDate'], matches(RegExp(r'\d{4}-\d{2}-\d{2}')));
        }
      });
    });

    group('Integration with match() method', () {
      test('match() should handle property projection differently than matchRows()', () {
        // match() returns Sets, so properties might need different handling
        // Define expected behavior
        final result = query.match(
          'MATCH person:Person RETURN person.name',
        );

        // Should still group by column name
        expect(result.keys, contains('person.name'));
        expect(result['person.name'], isA<Set>());
      });
    });

    group('Edge Cases', () {
      test('should handle empty result set with properties', () {
        final result = query.matchRows(
          'MATCH person:Person WHERE person.age > 100 RETURN person.name',
        );

        expect(result, isEmpty);
      });

      test('should handle property access on filtered out variable', () {
        // If only returning one variable, property access on other should error or be ignored
        expect(
          () => query.matchRows('MATCH person:Person-[:WORKS_FOR]->team RETURN person, team.name'),
          returnsNormally, // Should work - both variables are in RETURN
        );
      });

      test('should handle very long property paths', () {
        final result = query.matchRows(
          'MATCH a:Person-[:WORKS_FOR]->b:Team-[:WORKS_ON]->c:Project RETURN a.name, b.size, c.priority',
        );

        for (final row in result) {
          expect(row.keys, containsAll(['a.name', 'b.size', 'c.priority']));
        }
      });

      test('should handle duplicate property requests', () {
        final result = query.matchRows(
          'MATCH person:Person RETURN person.name, person.name',
        );

        // Should either deduplicate or include both - define behavior
        for (final row in result) {
          expect(row.keys, contains('person.name'));
        }
      });
    });

    group('Performance Considerations', () {
      test('should efficiently access multiple properties from same node', () {
        // Access node properties object once, not per property
        final result = query.matchRows(
          'MATCH person:Person RETURN person.name, person.age, person.department, person.active, person.startDate',
        );

        expect(result.length, 3);
        // Test should complete quickly even with many properties
      });

      test('should handle patterns with many property accesses', () {
        final result = query.matchRows(
          'MATCH p:Person-[:WORKS_FOR]->t:Team RETURN p.name, p.age, p.department, p.active, t.name, t.size, t.budget',
        );

        for (final row in result) {
          expect(row.keys.length, 7);
        }
      });
    });
  });
}
