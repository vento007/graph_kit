import 'package:graph_kit/graph_kit.dart';
import 'package:test/test.dart';

void main() {
  group('Ordering and Pagination Tests', () {
    late Graph<Node> graph;
    late PatternQuery query;

    setUp(() {
      graph = Graph<Node>();

      // Add people with varying ages and salaries for sorting
      graph.addNode(
        Node(
          id: 'alice',
          type: 'Person',
          label: 'Alice',
          properties: {
            'name': 'Alice',
            'age': 30,
            'salary': 100000,
            'dept': 'Eng',
          },
        ),
      );
      graph.addNode(
        Node(
          id: 'bob',
          type: 'Person',
          label: 'Bob',
          properties: {
            'name': 'Bob',
            'age': 25,
            'salary': 90000,
            'dept': 'Eng',
          },
        ),
      );
      graph.addNode(
        Node(
          id: 'charlie',
          type: 'Person',
          label: 'Charlie',
          properties: {
            'name': 'Charlie',
            'age': 35,
            'salary': 120000,
            'dept': 'Sales',
          },
        ),
      );
      graph.addNode(
        Node(
          id: 'dave',
          type: 'Person',
          label: 'Dave',
          properties: {
            'name': 'Dave',
            'age': 28,
            'salary': 110000,
            'dept': 'Eng',
          },
        ),
      );
      graph.addNode(
        Node(
          id: 'eve',
          type: 'Person',
          label: 'Eve',
          properties: {
            'name': 'Eve',
            'age': 40,
            'salary': 130000,
            'dept': 'Sales',
          },
        ),
      );
      graph.addNode(
        Node(
          id: 'frank',
          type: 'Person',
          label: 'Frank',
          properties: {'name': 'Frank', 'age': 22, 'salary': 80000}, // No dept
        ),
      );

      query = PatternQuery(graph);
    });

    group('ORDER BY Clause', () {
      test('sort by property ASC (default)', () {
        final result = query.matchRows(
          'MATCH p:Person RETURN p.name, p.age ORDER BY p.age',
        );

        expect(result.length, 6);
        expect(result[0]['p.name'], 'Frank'); // 22
        expect(result[1]['p.name'], 'Bob'); // 25
        expect(result[2]['p.name'], 'Dave'); // 28
        expect(result[3]['p.name'], 'Alice'); // 30
        expect(result[4]['p.name'], 'Charlie'); // 35
        expect(result[5]['p.name'], 'Eve'); // 40
      });

      test('sort by property DESC', () {
        final result = query.matchRows(
          'MATCH p:Person RETURN p.name, p.salary ORDER BY p.salary DESC',
        );

        expect(result.length, 6);
        expect(result[0]['p.name'], 'Eve'); // 130000
        expect(result[1]['p.name'], 'Charlie'); // 120000
        expect(result[2]['p.name'], 'Dave'); // 110000
        expect(result[3]['p.name'], 'Alice'); // 100000
        expect(result[4]['p.name'], 'Bob'); // 90000
        expect(result[5]['p.name'], 'Frank'); // 80000
      });

      test('sort by alias', () {
        final result = query.matchRows(
          'MATCH p:Person RETURN p.name AS name, p.age AS age ORDER BY age DESC',
        );

        expect(result.length, 6);
        expect(result[0]['name'], 'Eve');
        expect(result[1]['name'], 'Charlie');
      });

      test('sort by multiple keys', () {
        // Same dept, sort by age DESC
        final result = query.matchRows(
          'MATCH p:Person WHERE p.dept != null RETURN p.name, p.dept, p.age ORDER BY p.dept ASC, p.age DESC',
        );

        // Eng: Alice(30), Dave(28), Bob(25)
        // Sales: Eve(40), Charlie(35)

        expect(result[0]['p.name'], 'Alice');
        expect(result[1]['p.name'], 'Dave');
        expect(result[2]['p.name'], 'Bob');
        expect(result[3]['p.name'], 'Eve');
        expect(result[4]['p.name'], 'Charlie');
      });

      test('sort with null values (nulls first)', () {
        // Frank has null dept
        final result = query.matchRows(
          'MATCH p:Person RETURN p.name, p.dept ORDER BY p.dept',
        );

        expect(result[0]['p.name'], 'Frank'); // Null dept
        expect(result[0]['p.dept'], null);
      });
    });

    group('SKIP and LIMIT', () {
      test('LIMIT only', () {
        final result = query.matchRows(
          'MATCH p:Person RETURN p.name ORDER BY p.age LIMIT 3',
        );

        expect(result.length, 3);
        expect(result[0]['p.name'], 'Frank');
        expect(result[1]['p.name'], 'Bob');
        expect(result[2]['p.name'], 'Dave');
      });

      test('SKIP only', () {
        final result = query.matchRows(
          'MATCH p:Person RETURN p.name ORDER BY p.age SKIP 3',
        );

        expect(result.length, 3); // Total 6 - 3 skipped
        expect(result[0]['p.name'], 'Alice');
        expect(result[1]['p.name'], 'Charlie');
        expect(result[2]['p.name'], 'Eve');
      });

      test('SKIP and LIMIT combined', () {
        final result = query.matchRows(
          'MATCH p:Person RETURN p.name ORDER BY p.age SKIP 2 LIMIT 2',
        );

        expect(result.length, 2);
        // Sorted: Frank, Bob, Dave, Alice, Charlie, Eve
        // Skip 2: Dave, Alice...
        // Limit 2: Dave, Alice
        expect(result[0]['p.name'], 'Dave');
        expect(result[1]['p.name'], 'Alice');
      });

      test('SKIP greater than result size', () {
        final result = query.matchRows('MATCH p:Person RETURN p.name SKIP 100');
        expect(result, isEmpty);
      });
    });

    group('Combined Features', () {
      test('Complex query with WHERE, RETURN, ORDER BY, LIMIT', () {
        final result = query.matchRows('''MATCH p:Person 
             WHERE p.age > 25 
             RETURN p.name AS name, p.salary AS salary 
             ORDER BY salary DESC 
             LIMIT 2''');

        // Matches: Alice(30), Charlie(35), Dave(28), Eve(40)
        // Salaries: Eve(130k), Charlie(120k), Dave(110k), Alice(100k)
        // Top 2: Eve, Charlie

        expect(result.length, 2);
        expect(result[0]['name'], 'Eve');
        expect(result[1]['name'], 'Charlie');
      });

      test('matchPaths with RETURN and ORDER BY (Consistency Check)', () {
        // This checks if the rows used for path construction align with sorted rows
        final paths = query.matchPaths(
          'MATCH p:Person RETURN p.name AS name ORDER BY p.age',
        );

        // Expected order by age: Frank(22), Bob(25), Dave(28), Alice(30), Charlie(35), Eve(40)

        expect(paths.length, 6);

        // With RETURN clause, PathMatch.nodes contains the projected values (aliases)
        // paths[0].nodes['name'] should be 'Frank'

        expect(paths[0].nodes['name'], 'Frank');
        expect(paths[5].nodes['name'], 'Eve');
      });
    });
  });
}
