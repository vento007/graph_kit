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

  group('Variable-length relationship property filters', () {
    late Graph<Node> graph;
    late PatternQuery<Node> query;

    setUp(() {
      graph = Graph<Node>();
      query = PatternQuery(graph);

      for (final id in [
        'ceo',
        'directorHigh',
        'directorLow',
        'engineer1',
        'engineer2',
        'analyst',
        'partner',
        'advocate',
        'vendor',
      ]) {
        graph.addNode(Node(id: id, type: 'Person', label: id));
      }

      graph
        ..addEdge(
          'ceo',
          'MANAGES',
          'directorHigh',
          properties: {'priority': 'high'},
        )
        ..addEdge(
          'directorHigh',
          'MANAGES',
          'engineer1',
          properties: {'priority': 'high'},
        )
        ..addEdge(
          'directorHigh',
          'MANAGES',
          'engineer2',
          properties: {'priority': 'low'},
        )
        ..addEdge(
          'ceo',
          'MANAGES',
          'directorLow',
          properties: {'priority': 'low'},
        )
        ..addEdge(
          'directorLow',
          'MANAGES',
          'analyst',
          properties: {'priority': 'high'},
        )
        ..addEdge(
          'directorHigh',
          'REPORTS_TO',
          'ceo',
          properties: {'priority': 'high'},
        )
        ..addEdge(
          'engineer1',
          'REPORTS_TO',
          'directorHigh',
          properties: {'priority': 'high'},
        )
        ..addEdge(
          'engineer2',
          'REPORTS_TO',
          'directorHigh',
          properties: {'priority': 'low'},
        )
        ..addEdge(
          'analyst',
          'REPORTS_TO',
          'directorLow',
          properties: {'priority': 'high'},
        )
        ..addEdge(
          'directorLow',
          'REPORTS_TO',
          'ceo',
          properties: {'priority': 'low'},
        )
        ..addEdge(
          'ceo',
          'CONNECTS',
          'partner',
          properties: {'tag': 'vip'},
        )
        ..addEdge(
          'partner',
          'SUPPORTS',
          'advocate',
          properties: {'tag': 'vip'},
        )
        ..addEdge(
          'ceo',
          'CONNECTS',
          'vendor',
          properties: {'tag': 'standard'},
        );
    });

    test('forward variable-length filters apply to every hop', () {
      final rows = query.matchRows(
        'MATCH ceo:Person{id:"ceo"}-[:MANAGES*1..2 {priority:"high"}]->target:Person',
      );

      final targets = rows.map((row) => row['target']).toSet();
      expect(targets, containsAll({'directorHigh', 'engineer1'}));
      expect(targets, isNot(contains('engineer2')));
      expect(targets, isNot(contains('analyst')));
    });

    test('backward variable-length filters work with incoming edges', () {
      final rows = query.matchRows(
        'MATCH ceo:Person{id:"ceo"}<-[:REPORTS_TO*1..2 {priority:"high"}]-report:Person',
      );

      final reporters = rows.map((row) => row['report']).toSet();
      expect(reporters, containsAll({'directorHigh', 'engineer1'}));
      expect(reporters, isNot(contains('engineer2')));
      expect(reporters, isNot(contains('analyst')));
    });

    test('wildcard variable-length filters respect properties across types',
        () {
      final rows = query.matchRows(
        'MATCH ceo:Person{id:"ceo"}-[*1..2 {tag:"vip"}]->contact:Person',
      );

      final contacts = rows.map((row) => row['contact']).toSet();
      expect(contacts, containsAll({'partner', 'advocate'}));
      expect(contacts, isNot(contains('vendor')));
    });
  });
}
