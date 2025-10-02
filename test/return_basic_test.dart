import 'package:graph_kit/graph_kit.dart';
import 'package:test/test.dart';

/// Test suite for RETURN clause - Phase 1: Basic variable filtering (ID-only)
///
/// Tests basic RETURN functionality without property access.
/// Validates that RETURN clause correctly filters which variables appear in results.
void main() {
  group('RETURN Basic Variable Filtering', () {
    late Graph<Node> graph;
    late PatternQuery query;

    setUp(() {
      graph = Graph<Node>();

      // Create sample organizational graph
      // People
      graph.addNode(Node(
        id: 'alice',
        type: 'Person',
        label: 'Alice Cooper',
        properties: {'name': 'Alice Cooper', 'age': 28, 'department': 'Engineering'},
      ));
      graph.addNode(Node(
        id: 'bob',
        type: 'Person',
        label: 'Bob Wilson',
        properties: {'name': 'Bob Wilson', 'age': 35, 'department': 'Engineering'},
      ));
      graph.addNode(Node(
        id: 'charlie',
        type: 'Person',
        label: 'Charlie Davis',
        properties: {'name': 'Charlie Davis', 'age': 42, 'department': 'Management'},
      ));

      // Teams
      graph.addNode(Node(
        id: 'engineering',
        type: 'Team',
        label: 'Engineering',
        properties: {'name': 'Engineering', 'size': 12},
      ));
      graph.addNode(Node(
        id: 'design',
        type: 'Team',
        label: 'Design',
        properties: {'name': 'Design', 'size': 8},
      ));

      // Projects
      graph.addNode(Node(
        id: 'webapp',
        type: 'Project',
        label: 'Web App',
        properties: {'name': 'Web Application', 'status': 'active'},
      ));
      graph.addNode(Node(
        id: 'mobile',
        type: 'Project',
        label: 'Mobile App',
        properties: {'name': 'Mobile App', 'status': 'planning'},
      ));

      // Relationships
      graph.addEdge('alice', 'WORKS_FOR', 'engineering');
      graph.addEdge('bob', 'WORKS_FOR', 'engineering');
      graph.addEdge('charlie', 'MANAGES', 'engineering');
      graph.addEdge('charlie', 'MANAGES', 'design');
      graph.addEdge('engineering', 'WORKS_ON', 'webapp');
      graph.addEdge('engineering', 'WORKS_ON', 'mobile');
      graph.addEdge('design', 'WORKS_ON', 'mobile');

      query = PatternQuery(graph);
    });

    group('Single Variable RETURN', () {
      test('should return only specified variable from simple pattern', () {
        final result = query.matchRows(
          'MATCH person:Person RETURN person',
        );

        expect(result.length, 3); // alice, bob, charlie
        for (final row in result) {
          expect(row.keys.length, 1);
          expect(row.keys, contains('person'));
          expect(row['person'], isNotNull);
        }
      });

      test('should return only first variable in multi-hop pattern', () {
        final result = query.matchRows(
          'MATCH person:Person-[:WORKS_FOR]->team:Team RETURN person',
        );

        expect(result.length, 2); // alice, bob
        for (final row in result) {
          expect(row.keys.length, 1);
          expect(row.keys, contains('person'));
          expect(row.keys, isNot(contains('team')));
        }
      });

      test('should return only last variable in multi-hop pattern', () {
        final result = query.matchRows(
          'MATCH person:Person-[:WORKS_FOR]->team:Team RETURN team',
        );

        expect(result.length, 2); // both rows, same team
        for (final row in result) {
          expect(row.keys.length, 1);
          expect(row.keys, contains('team'));
          expect(row.keys, isNot(contains('person')));
          expect(row['team'], equals('engineering'));
        }
      });

      test('should return middle variable in 3-hop pattern', () {
        final result = query.matchRows(
          'MATCH person:Person-[:WORKS_FOR]->team:Team-[:WORKS_ON]->project:Project RETURN team',
        );

        for (final row in result) {
          expect(row.keys.length, 1);
          expect(row.keys, contains('team'));
          expect(row.keys, isNot(contains('person')));
          expect(row.keys, isNot(contains('project')));
        }
      });
    });

    group('Multiple Variable RETURN', () {
      test('should return two specified variables', () {
        final result = query.matchRows(
          'MATCH person:Person-[:WORKS_FOR]->team:Team RETURN person, team',
        );

        expect(result.length, 2);
        for (final row in result) {
          expect(row.keys.length, 2);
          expect(row.keys, containsAll(['person', 'team']));
        }
      });

      test('should return all three variables in 3-hop pattern', () {
        final result = query.matchRows(
          'MATCH person:Person-[:WORKS_FOR]->team:Team-[:WORKS_ON]->project:Project RETURN person, team, project',
        );

        for (final row in result) {
          expect(row.keys.length, 3);
          expect(row.keys, containsAll(['person', 'team', 'project']));
        }
      });

      test('should handle variables in different order than pattern', () {
        final result = query.matchRows(
          'MATCH person:Person-[:WORKS_FOR]->team:Team RETURN team, person',
        );

        expect(result.length, 2);
        for (final row in result) {
          expect(row.keys, containsAll(['person', 'team']));
        }
      });

      test('should return subset of variables from complex pattern', () {
        final result = query.matchRows(
          'MATCH person:Person-[:WORKS_FOR]->team:Team-[:WORKS_ON]->project:Project RETURN person, project',
        );

        for (final row in result) {
          expect(row.keys.length, 2);
          expect(row.keys, containsAll(['person', 'project']));
          expect(row.keys, isNot(contains('team'))); // team filtered out
        }
      });
    });

    group('Backward Compatibility', () {
      test('pattern without RETURN should return all variables', () {
        final result = query.matchRows(
          'MATCH person:Person-[:WORKS_FOR]->team:Team',
        );

        expect(result.length, 2);
        for (final row in result) {
          expect(row.keys, containsAll(['person', 'team']));
        }
      });

      test('existing match() method should still work', () {
        final result = query.match(
          'person:Person-[:WORKS_FOR]->team:Team',
        );

        expect(result.keys, containsAll(['person', 'team']));
        expect(result['person'], isNotNull);
        expect(result['team'], isNotNull);
      });
    });

    group('RETURN with WHERE Clause', () {
      test('should filter then return specified variables', () {
        final result = query.matchRows(
          'MATCH person:Person WHERE person.age > 30 RETURN person',
        );

        expect(result.length, 2); // bob and charlie
        for (final row in result) {
          expect(row.keys.length, 1);
          expect(row.keys, contains('person'));
        }
      });

      test('should work with relationship patterns and WHERE', () {
        final result = query.matchRows(
          'MATCH person:Person-[:WORKS_FOR]->team:Team WHERE person.age < 30 RETURN team',
        );

        expect(result.length, 1); // only alice is < 30
        expect(result[0].keys.length, 1);
        expect(result[0]['team'], equals('engineering'));
      });

      test('should combine WHERE filtering with multi-variable RETURN', () {
        final result = query.matchRows(
          'MATCH person:Person-[:MANAGES]->team:Team WHERE person.age > 40 RETURN person, team',
        );

        expect(result.length, 2); // charlie manages 2 teams
        for (final row in result) {
          expect(row.keys, containsAll(['person', 'team']));
          expect(row['person'], equals('charlie'));
        }
      });
    });

    group('RETURN with startId', () {
      test('should return specified variable when using startId', () {
        final result = query.matchRows(
          'MATCH person-[:WORKS_FOR]->team RETURN team',
          startId: 'alice',
        );

        expect(result.length, 1);
        expect(result[0].keys.length, 1);
        expect(result[0].keys, contains('team'));
        expect(result[0]['team'], equals('engineering'));
      });

      test('should work with multi-hop from startId', () {
        final result = query.matchRows(
          'MATCH person-[:WORKS_FOR]->team-[:WORKS_ON]->project RETURN project',
          startId: 'bob',
        );

        expect(result.length, 2); // webapp and mobile
        for (final row in result) {
          expect(row.keys.length, 1);
          expect(row.keys, contains('project'));
        }
      });
    });

    group('RETURN with Mixed Directions', () {
      test('should handle backward relationships', () {
        final result = query.matchRows(
          'MATCH team:Team<-[:WORKS_FOR]-person:Person RETURN person',
        );

        expect(result.length, 2); // alice, bob
        for (final row in result) {
          expect(row.keys.length, 1);
          expect(row.keys, contains('person'));
        }
      });

      test('should handle mixed direction patterns', () {
        final result = query.matchRows(
          'MATCH person1-[:WORKS_FOR]->team<-[:MANAGES]-manager RETURN person1, manager',
        );

        expect(result.length, 2); // alice and bob with charlie as manager
        for (final row in result) {
          expect(row.keys.length, 2);
          expect(row.keys, containsAll(['person1', 'manager']));
          expect(row.keys, isNot(contains('team')));
          expect(row['manager'], equals('charlie'));
        }
      });
    });

    group('RETURN with Multiple Edge Types', () {
      test('should work with OR edge types', () {
        final result = query.matchRows(
          'MATCH person-[:WORKS_FOR|MANAGES]->team RETURN person',
        );

        expect(result.length, greaterThan(0));
        for (final row in result) {
          expect(row.keys.length, 1);
          expect(row.keys, contains('person'));
        }
      });

      test('should filter variables with multiple edge types', () {
        final result = query.matchRows(
          'MATCH person-[:WORKS_FOR|MANAGES]->team RETURN team',
        );

        for (final row in result) {
          expect(row.keys.length, 1);
          expect(row.keys, contains('team'));
          expect(row.keys, isNot(contains('person')));
        }
      });
    });

    group('Edge Cases', () {
      test('should handle empty result set', () {
        final result = query.matchRows(
          'MATCH person:Person WHERE person.age > 100 RETURN person',
        );

        expect(result, isEmpty);
      });

      test('should handle RETURN with non-existent variable gracefully', () {
        // This should either error or return empty - define expected behavior
        expect(
          () => query.matchRows('MATCH person:Person RETURN nonexistent'),
          throwsA(anything), // Or returns empty, depending on implementation choice
        );
      });

      test('should handle duplicate variable names in RETURN', () {
        final result = query.matchRows(
          'MATCH person:Person RETURN person, person',
        );

        // Should deduplicate or error - define expected behavior
        for (final row in result) {
          expect(row.keys, contains('person'));
        }
      });

      test('should preserve row structure with single column', () {
        final result = query.matchRows(
          'MATCH person:Person-[:WORKS_FOR]->team:Team-[:WORKS_ON]->project:Project RETURN project',
        );

        // Each row should still be independent even if same project appears multiple times
        expect(result.length, greaterThan(1));
      });
    });

    group('Integration with match() method', () {
      test('match() should support RETURN and convert to Set structure', () {
        final result = query.match(
          'MATCH person:Person-[:WORKS_FOR]->team:Team RETURN person',
        );

        expect(result.keys.length, 1);
        expect(result.keys, contains('person'));
        expect(result['person'], isA<Set<String>>());
        expect(result['person']!.length, 2); // alice, bob
      });

      test('match() with multiple RETURN variables should create multiple sets', () {
        final result = query.match(
          'MATCH person:Person-[:WORKS_FOR]->team:Team RETURN person, team',
        );

        expect(result.keys, containsAll(['person', 'team']));
        expect(result['person']!.length, 2);
        expect(result['team']!.length, 1); // only engineering
      });
    });

    group('Integration with matchPaths() method', () {
      test('matchPaths() should respect RETURN filtering', () {
        final result = query.matchPaths(
          'MATCH person:Person-[:WORKS_FOR]->team:Team RETURN person',
        );

        expect(result.length, 2);
        for (final path in result) {
          expect(path.nodes.keys.length, 1);
          expect(path.nodes.keys, contains('person'));
        }
      });

      test('matchPaths() should preserve edge information even with filtered variables', () {
        final result = query.matchPaths(
          'MATCH person:Person-[:WORKS_FOR]->team:Team RETURN person',
        );

        for (final path in result) {
          // Even though team is not in nodes, edges should still be present
          expect(path.edges, isNotEmpty);
        }
      });
    });
  });
}
