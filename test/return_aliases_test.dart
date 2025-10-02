import 'package:graph_kit/graph_kit.dart';
import 'package:test/test.dart';

/// Test suite for RETURN clause - Phase 3: AS aliasing
///
/// Tests RETURN with AS keyword for column aliasing and renaming.
/// Validates alias resolution, name conflicts, and output customization.
void main() {
  group('RETURN Aliases (AS keyword)', () {
    late Graph<Node> graph;
    late PatternQuery query;

    setUp(() {
      graph = Graph<Node>();

      graph.addNode(Node(
        id: 'alice',
        type: 'Person',
        label: 'Alice Cooper',
        properties: {
          'name': 'Alice Cooper',
          'age': 28,
          'email': 'alice@example.com',
          'department': 'Engineering',
        },
      ));

      graph.addNode(Node(
        id: 'bob',
        type: 'Person',
        label: 'Bob Wilson',
        properties: {
          'name': 'Bob Wilson',
          'age': 35,
          'email': 'bob@example.com',
          'department': 'Engineering',
        },
      ));

      graph.addNode(Node(
        id: 'engineering',
        type: 'Team',
        label: 'Engineering',
        properties: {
          'name': 'Engineering',
          'size': 12,
          'location': 'Building A',
        },
      ));

      graph.addNode(Node(
        id: 'webapp',
        type: 'Project',
        label: 'Web App',
        properties: {
          'name': 'Web Application',
          'status': 'active',
        },
      ));

      graph.addEdge('alice', 'WORKS_FOR', 'engineering');
      graph.addEdge('bob', 'WORKS_FOR', 'engineering');
      graph.addEdge('engineering', 'WORKS_ON', 'webapp');

      query = PatternQuery(graph);
    });

    group('Simple Aliases', () {
      test('should alias variable ID', () {
        final result = query.matchRows(
          'MATCH person:Person RETURN person AS userId',
        );

        expect(result.length, 2);
        for (final row in result) {
          expect(row.keys, contains('userId'));
          expect(row.keys, isNot(contains('person')));
          expect(row['userId'], isIn(['alice', 'bob']));
        }
      });

      test('should alias property access', () {
        final result = query.matchRows(
          'MATCH person:Person RETURN person.name AS displayName',
        );

        expect(result.length, 2);
        for (final row in result) {
          expect(row.keys, contains('displayName'));
          expect(row.keys, isNot(contains('person.name')));
          expect(row['displayName'], isNotNull);
        }
      });

      test('should alias integer property', () {
        final result = query.matchRows(
          'MATCH person:Person RETURN person.age AS yearsOld',
        );

        for (final row in result) {
          expect(row.keys, contains('yearsOld'));
          expect(row['yearsOld'], isA<int>());
        }
      });

      test('should preserve case in aliases', () {
        final result = query.matchRows(
          'MATCH person:Person RETURN person.name AS DisplayName',
        );

        for (final row in result) {
          expect(row.keys, contains('DisplayName'));
          expect(row['DisplayName'], isNotNull);
        }
      });
    });

    group('Multiple Aliases', () {
      test('should alias two properties', () {
        final result = query.matchRows(
          'MATCH person:Person RETURN person.name AS fullName, person.age AS yearsOld',
        );

        expect(result.length, 2);
        for (final row in result) {
          expect(row.keys, containsAll(['fullName', 'yearsOld']));
          expect(row.keys, isNot(contains('person.name')));
          expect(row.keys, isNot(contains('person.age')));
        }
      });

      test('should alias variables from different nodes', () {
        final result = query.matchRows(
          'MATCH person:Person-[:WORKS_FOR]->team:Team RETURN person AS employee, team AS organization',
        );

        expect(result.length, 2);
        for (final row in result) {
          expect(row.keys, containsAll(['employee', 'organization']));
          expect(row.keys, isNot(contains('person')));
          expect(row.keys, isNot(contains('team')));
        }
      });

      test('should alias properties from multiple nodes', () {
        final result = query.matchRows(
          'MATCH person:Person-[:WORKS_FOR]->team:Team RETURN person.name AS employeeName, team.name AS teamName',
        );

        for (final row in result) {
          expect(row.keys, containsAll(['employeeName', 'teamName']));
          expect(row['employeeName'], isNotNull);
          expect(row['teamName'], equals('Engineering'));
        }
      });

      test('should handle many aliases', () {
        final result = query.matchRows(
          'MATCH person:Person RETURN person.name AS n1, person.age AS n2, person.email AS n3, person.department AS n4',
        );

        for (final row in result) {
          expect(row.keys.length, 4);
          expect(row.keys, containsAll(['n1', 'n2', 'n3', 'n4']));
        }
      });
    });

    group('Mixed Aliased and Non-Aliased', () {
      test('should mix aliased and non-aliased columns', () {
        final result = query.matchRows(
          'MATCH person:Person RETURN person, person.name AS displayName',
        );

        for (final row in result) {
          expect(row.keys, containsAll(['person', 'displayName']));
          expect(row['person'], isIn(['alice', 'bob']));
          expect(row['displayName'], isNotNull);
        }
      });

      test('should handle some aliased, some not in multi-column', () {
        final result = query.matchRows(
          'MATCH person:Person RETURN person.name AS displayName, person.age, person.email AS contact',
        );

        for (final row in result) {
          expect(row.keys, containsAll(['displayName', 'person.age', 'contact']));
          expect(row.keys, isNot(contains('person.name')));
          expect(row.keys, isNot(contains('person.email')));
        }
      });

      test('should mix variable IDs and aliased properties', () {
        final result = query.matchRows(
          'MATCH person:Person-[:WORKS_FOR]->team:Team RETURN person, team.name AS teamName',
        );

        for (final row in result) {
          expect(row.keys, containsAll(['person', 'teamName']));
          expect(row['teamName'], equals('Engineering'));
        }
      });
    });

    group('Alias Edge Cases', () {
      test('should handle alias with underscores', () {
        final result = query.matchRows(
          'MATCH person:Person RETURN person.name AS full_name',
        );

        for (final row in result) {
          expect(row.keys, contains('full_name'));
        }
      });

      test('should handle alias with numbers', () {
        final result = query.matchRows(
          'MATCH person:Person RETURN person.age AS age2023',
        );

        for (final row in result) {
          expect(row.keys, contains('age2023'));
        }
      });

      test('should handle short alias', () {
        final result = query.matchRows(
          'MATCH person:Person RETURN person.name AS n',
        );

        for (final row in result) {
          expect(row.keys, contains('n'));
          expect(row['n'], isNotNull);
        }
      });

      test('should handle long alias', () {
        final result = query.matchRows(
          'MATCH person:Person RETURN person.name AS thisIsAVeryLongAliasName',
        );

        for (final row in result) {
          expect(row.keys, contains('thisIsAVeryLongAliasName'));
        }
      });

      test('should handle alias collision - same alias for different values', () {
        // Two different properties aliased to same name
        // Define expected behavior: error or last one wins
        expect(
          () => query.matchRows('MATCH person:Person RETURN person.name AS value, person.age AS value'),
          throwsA(anything), // Or define specific behavior
        );
      });

      test('should handle alias same as original variable name', () {
        final result = query.matchRows(
          'MATCH person:Person RETURN person.name AS person',
        );

        // Should work - alias overrides original
        for (final row in result) {
          expect(row.keys, contains('person'));
          expect(row['person'], isA<String>()); // Should be the name, not ID
        }
      });
    });

    group('Aliases with WHERE', () {
      test('should filter then return with alias', () {
        final result = query.matchRows(
          'MATCH person:Person WHERE person.age > 30 RETURN person.name AS seniorEmployee',
        );

        expect(result.length, 1); // only bob
        expect(result[0].keys, contains('seniorEmployee'));
        expect(result[0]['seniorEmployee'], equals('Bob Wilson'));
      });

      test('should use original name in WHERE, alias in RETURN', () {
        final result = query.matchRows(
          'MATCH person:Person-[:WORKS_FOR]->team:Team WHERE team.size > 10 RETURN person.name AS employee, team.name AS department',
        );

        for (final row in result) {
          expect(row.keys, containsAll(['employee', 'department']));
          expect(row['department'], equals('Engineering'));
        }
      });
    });

    group('Aliases with startId', () {
      test('should work with startId parameter', () {
        final result = query.matchRows(
          'MATCH person-[:WORKS_FOR]->team RETURN person.name AS employee, team.name AS teamName',
          startId: 'alice',
        );

        expect(result.length, 1);
        expect(result[0].keys, containsAll(['employee', 'teamName']));
        expect(result[0]['employee'], equals('Alice Cooper'));
        expect(result[0]['teamName'], equals('Engineering'));
      });
    });

    group('Aliases with Complex Patterns', () {
      test('should alias in 3-hop pattern', () {
        final result = query.matchRows(
          'MATCH a:Person-[:WORKS_FOR]->b:Team-[:WORKS_ON]->c:Project RETURN a.name AS person, b.name AS team, c.name AS project',
        );

        for (final row in result) {
          expect(row.keys, containsAll(['person', 'team', 'project']));
          expect(row.keys.length, 3);
        }
      });

      test('should alias with mixed directions', () {
        final result = query.matchRows(
          'MATCH person1-[:WORKS_FOR]->team<-[:WORKS_FOR]-person2 RETURN person1.name AS employee1, person2.name AS employee2',
        );

        for (final row in result) {
          expect(row.keys, containsAll(['employee1', 'employee2']));
        }
      });
    });

    group('Integration with match() method', () {
      test('match() should use aliases for Set keys', () {
        final result = query.match(
          'MATCH person:Person RETURN person.name AS displayName',
        );

        expect(result.keys, contains('displayName'));
        expect(result.keys, isNot(contains('person.name')));
        expect(result['displayName'], isA<Set<String>>());
      });
    });

    group('Whitespace and Parsing', () {
      test('should handle extra whitespace around AS', () {
        final result = query.matchRows(
          'MATCH person:Person RETURN person.name    AS    displayName',
        );

        for (final row in result) {
          expect(row.keys, contains('displayName'));
        }
      });

      test('should handle newlines around AS', () {
        final result = query.matchRows(
          '''MATCH person:Person
          RETURN person.name
          AS displayName''',
        );

        for (final row in result) {
          expect(row.keys, contains('displayName'));
        }
      });

      test('should handle case insensitivity of AS keyword', () {
        // Define if AS should be case-sensitive
        final result = query.matchRows(
          'MATCH person:Person RETURN person.name as displayName',
        );

        // Should work regardless of 'AS' or 'as'
        for (final row in result) {
          expect(row.keys, contains('displayName'));
        }
      });
    });

    group('Error Handling', () {
      test('should handle missing alias after AS', () {
        expect(
          () => query.matchRows('MATCH person:Person RETURN person.name AS'),
          throwsA(anything),
        );
      });

      test('should handle AS without value before it', () {
        expect(
          () => query.matchRows('MATCH person:Person RETURN AS displayName'),
          throwsA(anything),
        );
      });
    });
  });
}
