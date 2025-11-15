import 'package:graph_kit/graph_kit.dart';
import 'package:test/test.dart';

void main() {
  group('Relationship property support', () {
    late Graph<Node> graph;
    late PatternQuery<Node> query;

    setUp(() {
      graph = Graph<Node>();
      query = PatternQuery(graph);

      graph.addNode(Node(id: 'alice', type: 'Person', label: 'Alice'));
      graph.addNode(Node(id: 'bob', type: 'Person', label: 'Bob'));
      graph.addNode(Node(id: 'carol', type: 'Person', label: 'Carol'));
      graph.addNode(Node(id: 'dave', type: 'Person', label: 'Dave'));

      graph.addEdge(
        'alice',
        'KNOWS',
        'bob',
        properties: {'since': 2020, 'strength': 90},
      );
      graph.addEdge(
        'alice',
        'KNOWS',
        'carol',
        properties: {'since': 2018, 'strength': 50},
      );
      graph.addEdge('dave', 'MENTORS', 'alice', properties: {'since': 2021});
    });

    test(
      'inline property filter matches only edges with matching metadata',
      () {
        final rows = query.matchRows(
          'MATCH person-[r:KNOWS {since: 2020}]->friend',
        );

        expect(rows, hasLength(1));
        expect(rows.first['friend'], equals('bob'));
        expect(rows.first['person'], equals('alice'));
      },
    );

    test('inline property filter works for backward edges', () {
      final rows = query.matchRows(
        'MATCH mentee<-[:MENTORS {since: 2021}]-mentor',
      );

      expect(rows, hasLength(1));
      expect(rows.first['mentee'], equals('alice'));
      expect(rows.first['mentor'], equals('dave'));
    });

    test('WHERE clause can reference edge properties', () {
      final rows = query.matchRows(
        'MATCH person-[r:KNOWS]->friend WHERE r.strength >= 80',
      );

      expect(rows, hasLength(1));
      expect(rows.first['friend'], equals('bob'));

      final backwardRows = query.matchRows(
        'MATCH friend<-[r:KNOWS]-person WHERE r.since < 2019',
      );
      expect(backwardRows, hasLength(1));
      expect(backwardRows.first['friend'], equals('carol'));
    });

    test('RETURN clause projects edge properties', () {
      final rows = query.matchRows(
        'MATCH person-[r:KNOWS]->friend '
        'RETURN person, friend, r.since AS since, r.strength',
      );

      final lookup = {for (final row in rows) row['friend']!: row};

      expect(lookup['bob']?['r.strength'], equals(90));
      expect(lookup['bob']?['since'], equals(2020));
      expect(lookup['carol']?['r.strength'], equals(50));
    });

    test('matchPaths exposes edge properties in PathEdge objects', () {
      final paths = query.matchPaths('person-[r:KNOWS]->friend');
      expect(paths, isNotEmpty);

      final edge = paths.first.edges.first;
      expect(edge.type, equals('KNOWS'));
      expect(edge.properties?['since'], equals(2020));
      expect(edge.properties?['strength'], equals(90));
    });
  });
}
