import 'package:test/test.dart';
import 'package:graph_kit/graph_kit.dart';

/// Tests for multiple edge types feature: person-[:TYPE1|TYPE2|TYPE3]->node
///
/// This test file ONLY tests the new multiple edge types feature.
/// Existing features (single edge types, WHERE clauses, variable-length, etc.)
/// are already tested in other files.
void main() {
  group('Multiple Edge Types', () {
    late Graph<Node> graph;
    late PatternQuery<Node> query;

    setUp(() {
      graph = Graph<Node>();
      query = PatternQuery(graph);

      // Create a mixed relationship graph
      // alice: WORKS_FOR engineering
      // bob: VOLUNTEERS_AT engineering
      // charlie: MANAGES engineering
      // diana: INTERN_AT engineering
      // engineering: ASSIGNED_TO projectA
      // engineering: COLLABORATES_WITH design
      // design: ASSIGNED_TO projectB

      graph.addNode(Node(id: 'alice', type: 'Person', label: 'Alice'));
      graph.addNode(Node(id: 'bob', type: 'Person', label: 'Bob'));
      graph.addNode(Node(id: 'charlie', type: 'Person', label: 'Charlie'));
      graph.addNode(Node(id: 'diana', type: 'Person', label: 'Diana'));
      graph.addNode(Node(id: 'engineering', type: 'Team', label: 'Engineering'));
      graph.addNode(Node(id: 'design', type: 'Team', label: 'Design'));
      graph.addNode(Node(id: 'projectA', type: 'Project', label: 'Project A'));
      graph.addNode(Node(id: 'projectB', type: 'Project', label: 'Project B'));

      // Different edge types between people and teams
      graph.addEdge('alice', 'WORKS_FOR', 'engineering');
      graph.addEdge('bob', 'VOLUNTEERS_AT', 'engineering');
      graph.addEdge('charlie', 'MANAGES', 'engineering');
      graph.addEdge('diana', 'INTERN_AT', 'engineering');

      // Different edge types between teams and projects
      graph.addEdge('engineering', 'ASSIGNED_TO', 'projectA');
      graph.addEdge('engineering', 'COLLABORATES_WITH', 'design');
      graph.addEdge('design', 'ASSIGNED_TO', 'projectB');
    });

    test('basic OR with 2 edge types - should match EITHER type', () {
      // Query for people who WORKS_FOR or VOLUNTEERS_AT a team
      // Should match: alice (WORKS_FOR), bob (VOLUNTEERS_AT)
      // Should NOT match: charlie (MANAGES), diana (INTERN_AT)
      final result = query.match('person-[:WORKS_FOR|VOLUNTEERS_AT]->team');

      expect(result['person'], containsAll(['alice', 'bob']));
      expect(result['person'], isNot(contains('charlie')));
      expect(result['person'], isNot(contains('diana')));
      expect(result['team'], equals({'engineering'}));
    });

    test('OR with 3 edge types - should match ANY of the types', () {
      // Query for WORKS_FOR or VOLUNTEERS_AT or INTERN_AT
      // Should match: alice, bob, diana
      // Should NOT match: charlie (only MANAGES)
      final result = query.match('person-[:WORKS_FOR|VOLUNTEERS_AT|INTERN_AT]->team');

      expect(result['person'], containsAll(['alice', 'bob', 'diana']));
      expect(result['person'], isNot(contains('charlie')));
      expect(result['team'], equals({'engineering'}));
    });

    test('OR with 4 edge types - should match all when all types present', () {
      // Query for all 4 relationship types
      // Should match: alice, bob, charlie, diana
      final result = query.match('person-[:WORKS_FOR|VOLUNTEERS_AT|MANAGES|INTERN_AT]->team');

      expect(result['person'], containsAll(['alice', 'bob', 'charlie', 'diana']));
      expect(result['team'], equals({'engineering'}));
    });

    test('OR with non-existent type - should only match existing types', () {
      // Query includes NONEXISTENT type
      // Should match: alice (WORKS_FOR), bob (VOLUNTEERS_AT)
      // Should NOT match edges that don't exist
      final result = query.match('person-[:WORKS_FOR|VOLUNTEERS_AT|NONEXISTENT]->team');

      expect(result['person'], containsAll(['alice', 'bob']));
      expect(result['person'], hasLength(2));
      expect(result['team'], equals({'engineering'}));
    });

    test('single type in OR syntax - should work like regular single type', () {
      // Using | syntax with single type should work identically to regular syntax
      final result = query.match('person-[:WORKS_FOR]->team');

      expect(result['person'], equals({'alice'}));
      expect(result['team'], equals({'engineering'}));
    });

    test('matchRows with multiple edge types - preserves path relationships', () {
      // Using matchRows should preserve which person connects to which team
      final rows = query.matchRows('person-[:WORKS_FOR|VOLUNTEERS_AT]->team');

      expect(rows, hasLength(2));

      // Find alice's row
      final aliceRow = rows.firstWhere((r) => r['person'] == 'alice');
      expect(aliceRow['team'], equals('engineering'));

      // Find bob's row
      final bobRow = rows.firstWhere((r) => r['person'] == 'bob');
      expect(bobRow['team'], equals('engineering'));
    });

    test('matchPaths with multiple edge types - edge info shows correct type', () {
      // Using matchPaths should show which specific edge type was matched
      final paths = query.matchPaths('person-[:WORKS_FOR|VOLUNTEERS_AT]->team');

      expect(paths, hasLength(2));

      // Find alice's path - should show WORKS_FOR
      final alicePath = paths.firstWhere((p) => p.nodes['person'] == 'alice');
      expect(alicePath.edges, hasLength(1));
      expect(alicePath.edges.first.type, equals('WORKS_FOR'));
      expect(alicePath.edges.first.from, equals('alice'));
      expect(alicePath.edges.first.to, equals('engineering'));

      // Find bob's path - should show VOLUNTEERS_AT
      final bobPath = paths.firstWhere((p) => p.nodes['person'] == 'bob');
      expect(bobPath.edges, hasLength(1));
      expect(bobPath.edges.first.type, equals('VOLUNTEERS_AT'));
      expect(bobPath.edges.first.from, equals('bob'));
      expect(bobPath.edges.first.to, equals('engineering'));
    });

    test('multi-hop with multiple edge types - should work in chains', () {
      // Two-hop pattern with different OR clauses
      // person -[:WORKS_FOR|VOLUNTEERS_AT]-> team -[:ASSIGNED_TO|COLLABORATES_WITH]-> target
      final result = query.match(
        'person-[:WORKS_FOR|VOLUNTEERS_AT]->team-[:ASSIGNED_TO|COLLABORATES_WITH]->target'
      );

      // alice and bob can reach engineering
      // engineering can reach projectA (ASSIGNED_TO) and design (COLLABORATES_WITH)
      expect(result['person'], containsAll(['alice', 'bob']));
      expect(result['team'], equals({'engineering'}));
      expect(result['target'], containsAll(['projectA', 'design']));
    });

    test('backwards pattern with multiple edge types', () {
      // Backwards pattern: team<-[:WORKS_FOR|VOLUNTEERS_AT]-person
      final result = query.match('team<-[:WORKS_FOR|VOLUNTEERS_AT]-person');

      expect(result['team'], equals({'engineering'}));
      expect(result['person'], containsAll(['alice', 'bob']));
      expect(result['person'], isNot(contains('charlie')));
      expect(result['person'], isNot(contains('diana')));
    });

    test('with startId - multiple edge types from specific node', () {
      // From alice, follow WORKS_FOR or MANAGES edges
      // alice only has WORKS_FOR, so should only match that
      final result = query.match(
        'person-[:WORKS_FOR|MANAGES]->team',
        startId: 'alice'
      );

      expect(result['person'], equals({'alice'}));
      expect(result['team'], equals({'engineering'}));
    });

    test('empty result - no edges match any of the types', () {
      // Query for edge types that don't exist between person and team
      final result = query.match('person-[:SPONSORS|FUNDS]->team');

      // When no paths match, the result map is empty (doesn't contain the keys)
      expect(result, isEmpty);
      expect(result.containsKey('person'), isFalse);
      expect(result.containsKey('team'), isFalse);
    });

    test('multiple edge types with variable-length paths', () {
      // Create a chain: alice -WORKS_FOR-> eng -ASSIGNED_TO-> projectA
      // Test variable-length with multiple types
      // person -[:WORKS_FOR|ASSIGNED_TO*1..2]-> target
      final result = query.match('person-[:WORKS_FOR|ASSIGNED_TO*1..2]->target');

      // alice can reach engineering (1 hop via WORKS_FOR)
      // alice can reach projectA (2 hops: WORKS_FOR -> ASSIGNED_TO)
      expect(result['person'], contains('alice'));
      expect(result['target'], containsAll(['engineering', 'projectA']));
    });

    test('multiple edge types with WHERE clause filtering', () {
      // Add properties to test WHERE clause integration
      final graphWithProps = Graph<Node>();
      graphWithProps.addNode(Node(
        id: 'alice',
        type: 'Person',
        label: 'Alice',
        properties: {'age': 28, 'department': 'Engineering'}
      ));
      graphWithProps.addNode(Node(
        id: 'bob',
        type: 'Person',
        label: 'Bob',
        properties: {'age': 35, 'department': 'Marketing'}
      ));
      graphWithProps.addNode(Node(
        id: 'charlie',
        type: 'Person',
        label: 'Charlie',
        properties: {'age': 42, 'department': 'Management'}
      ));
      graphWithProps.addNode(Node(id: 'engineering', type: 'Team', label: 'Engineering'));

      graphWithProps.addEdge('alice', 'WORKS_FOR', 'engineering');
      graphWithProps.addEdge('bob', 'VOLUNTEERS_AT', 'engineering');
      graphWithProps.addEdge('charlie', 'MANAGES', 'engineering');

      final queryWithProps = PatternQuery(graphWithProps);

      // Query for people over 30 who WORKS_FOR or VOLUNTEERS_AT
      // Should match: bob (35, VOLUNTEERS_AT)
      // Should NOT match: alice (28, too young), charlie (42, but uses MANAGES)
      final result = queryWithProps.matchRows(
        'MATCH person:Person-[:WORKS_FOR|VOLUNTEERS_AT]->team WHERE person.age > 30'
      );

      expect(result, hasLength(1));
      expect(result.first['person'], equals('bob'));
      expect(result.first['team'], equals('engineering'));

      // Verify alice and charlie are NOT in results
      expect(result.any((r) => r['person'] == 'alice'), isFalse);
      expect(result.any((r) => r['person'] == 'charlie'), isFalse);
    });

    test('multiple edge types with label filtering', () {
      // Query with label filter and multiple edge types
      // person with label containing 'Ali' who WORKS_FOR or VOLUNTEERS_AT
      // Should match: alice (label='Alice', WORKS_FOR)
      // Should NOT match: bob (label='Bob', even though VOLUNTEERS_AT)
      final result = query.match('person:Person{label~Ali}-[:WORKS_FOR|VOLUNTEERS_AT]->team');

      expect(result['person'], equals({'alice'}));
      expect(result['person'], isNot(contains('bob')));
      expect(result['team'], equals({'engineering'}));

      // Try exact label match
      final exactResult = query.match('person:Person{label=Bob}-[:WORKS_FOR|VOLUNTEERS_AT]->team');

      expect(exactResult['person'], equals({'bob'}));
      expect(exactResult['person'], isNot(contains('alice')));
      expect(exactResult['team'], equals({'engineering'}));
    });

    test('multiple edge types with WHERE and label filtering combined', () {
      // Complex test: multiple edge types + label filter + WHERE clause
      final graphComplex = Graph<Node>();
      graphComplex.addNode(Node(
        id: 'alice',
        type: 'Person',
        label: 'Alice Cooper',
        properties: {'age': 28, 'salary': 85000}
      ));
      graphComplex.addNode(Node(
        id: 'alicia',
        type: 'Person',
        label: 'Alicia Smith',
        properties: {'age': 32, 'salary': 95000}
      ));
      graphComplex.addNode(Node(
        id: 'bob',
        type: 'Person',
        label: 'Bob Wilson',
        properties: {'age': 35, 'salary': 90000}
      ));
      graphComplex.addNode(Node(id: 'engineering', type: 'Team', label: 'Engineering'));

      graphComplex.addEdge('alice', 'WORKS_FOR', 'engineering');
      graphComplex.addEdge('alicia', 'VOLUNTEERS_AT', 'engineering');
      graphComplex.addEdge('bob', 'VOLUNTEERS_AT', 'engineering');

      final queryComplex = PatternQuery(graphComplex);

      // Query: person with 'Ali' in label, age > 30, who WORKS_FOR or VOLUNTEERS_AT
      // Should match: alicia (label='Alicia Smith', age=32, VOLUNTEERS_AT)
      // Should NOT match: alice (has 'Ali' but age=28), bob (age=35 but no 'Ali')
      final result = queryComplex.matchRows(
        'MATCH person:Person{label~Ali}-[:WORKS_FOR|VOLUNTEERS_AT]->team WHERE person.age > 30'
      );

      expect(result, hasLength(1));
      expect(result.first['person'], equals('alicia'));
      expect(result.first['team'], equals('engineering'));

      // Verify others are NOT in results
      expect(result.any((r) => r['person'] == 'alice'), isFalse);
      expect(result.any((r) => r['person'] == 'bob'), isFalse);
    });
  });
}
