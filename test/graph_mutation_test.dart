import 'package:graph_kit/graph_kit.dart';
import 'package:test/test.dart';

void main() {
  group('Graph mutations', () {
    test('removeEdge updates adjacency maps and stored edge metadata', () {
      final graph = Graph<Node>();
      final query = PatternQuery(graph);

      graph.addNode(Node(id: 'alice', type: 'Person', label: 'Alice'));
      graph.addNode(
        Node(id: 'engineering', type: 'Team', label: 'Engineering'),
      );
      graph.addEdge(
        'alice',
        'WORKS_FOR',
        'engineering',
        properties: {'since': 2020},
      );

      expect(graph.removeEdge('alice', 'WORKS_FOR', 'engineering'), isTrue);
      expect(graph.hasEdge('alice', 'WORKS_FOR', 'engineering'), isFalse);
      expect(graph.outNeighbors('alice', 'WORKS_FOR'), isEmpty);
      expect(graph.inNeighbors('engineering', 'WORKS_FOR'), isEmpty);
      expect(graph.getEdge('alice', 'WORKS_FOR', 'engineering'), isNull);
      expect(query.matchRows('MATCH person-[:WORKS_FOR]->team'), isEmpty);
    });

    test('removeEdge keeps other edge types between the same nodes', () {
      final graph = Graph<Node>();

      graph.addEdge('alice', 'WORKS_FOR', 'engineering');
      graph.addEdge('alice', 'MANAGES', 'engineering');

      expect(graph.removeEdge('alice', 'WORKS_FOR', 'engineering'), isTrue);
      expect(graph.hasEdge('alice', 'WORKS_FOR', 'engineering'), isFalse);
      expect(graph.hasEdge('alice', 'MANAGES', 'engineering'), isTrue);
      expect(graph.edges.map((edge) => edge.type), equals(['MANAGES']));
    });

    test('moveEdge can change the destination of a relationship', () {
      final graph = Graph<Node>();
      final query = PatternQuery(graph);

      graph.addNode(Node(id: 'alice', type: 'Person', label: 'Alice'));
      graph.addNode(
        Node(id: 'engineering', type: 'Team', label: 'Engineering'),
      );
      graph.addNode(Node(id: 'design', type: 'Team', label: 'Design'));
      graph.addEdge(
        'alice',
        'WORKS_FOR',
        'engineering',
        properties: {'since': 2020},
      );

      final moved = graph.moveEdge(
        oldSrc: 'alice',
        edgeType: 'WORKS_FOR',
        oldDst: 'engineering',
        newDst: 'design',
      );

      expect(moved, isTrue);
      expect(graph.hasEdge('alice', 'WORKS_FOR', 'engineering'), isFalse);
      expect(graph.hasEdge('alice', 'WORKS_FOR', 'design'), isTrue);
      expect(graph.inNeighbors('engineering', 'WORKS_FOR'), isEmpty);
      expect(graph.inNeighbors('design', 'WORKS_FOR'), equals({'alice'}));
      expect(graph.edgeProperties('alice', 'WORKS_FOR', 'design'), {
        'since': 2020,
      });

      final rows = query.matchRows(
        'MATCH person:Person-[:WORKS_FOR]->team:Team RETURN person, team',
      );
      expect(
        rows,
        equals([
          {'person': 'alice', 'team': 'design'},
        ]),
      );
    });

    test('moveEdge can change the source of a relationship', () {
      final graph = Graph<Node>();

      graph.addNode(Node(id: 'cell1', type: 'Cell', label: 'Cell 1'));
      graph.addNode(Node(id: 'cell2', type: 'Cell', label: 'Cell 2'));
      graph.addNode(Node(id: 'piece1', type: 'Piece', label: 'Piece 1'));
      graph.addEdge('cell1', 'CONTAINS', 'piece1');

      final moved = graph.moveEdge(
        oldSrc: 'cell1',
        edgeType: 'CONTAINS',
        oldDst: 'piece1',
        newSrc: 'cell2',
      );

      expect(moved, isTrue);
      expect(graph.hasEdge('cell1', 'CONTAINS', 'piece1'), isFalse);
      expect(graph.hasEdge('cell2', 'CONTAINS', 'piece1'), isTrue);
      expect(graph.outNeighbors('cell1', 'CONTAINS'), isEmpty);
      expect(graph.outNeighbors('cell2', 'CONTAINS'), equals({'piece1'}));
      expect(graph.inNeighbors('piece1', 'CONTAINS'), equals({'cell2'}));
    });

    test('setOutgoingEdge replaces destinations for a source relationship', () {
      final graph = Graph<Node>();

      graph.addNode(Node(id: 'alice', type: 'Person', label: 'Alice'));
      graph.addNode(
        Node(id: 'engineering', type: 'Team', label: 'Engineering'),
      );
      graph.addNode(Node(id: 'design', type: 'Team', label: 'Design'));
      graph.addNode(Node(id: 'webapp', type: 'Project', label: 'Web App'));
      graph.addEdge('alice', 'WORKS_FOR', 'engineering');
      graph.addEdge('alice', 'LEADS', 'webapp');

      final removed = graph.setOutgoingEdge(
        'alice',
        'WORKS_FOR',
        'design',
        properties: {'since': 2024},
      );

      expect(removed, 1);
      expect(graph.hasEdge('alice', 'WORKS_FOR', 'engineering'), isFalse);
      expect(graph.hasEdge('alice', 'WORKS_FOR', 'design'), isTrue);
      expect(graph.hasEdge('alice', 'LEADS', 'webapp'), isTrue);
      expect(graph.inNeighbors('engineering', 'WORKS_FOR'), isEmpty);
      expect(graph.inNeighbors('design', 'WORKS_FOR'), equals({'alice'}));
      expect(graph.edgeProperties('alice', 'WORKS_FOR', 'design'), {
        'since': 2024,
      });
    });

    test('setIncomingEdge replaces sources for a destination relationship', () {
      final graph = Graph<Node>();

      graph.addNode(Node(id: 'cell1', type: 'Cell', label: 'Cell 1'));
      graph.addNode(Node(id: 'cell2', type: 'Cell', label: 'Cell 2'));
      graph.addNode(Node(id: 'piece1', type: 'Piece', label: 'Piece 1'));
      graph.addNode(Node(id: 'player1', type: 'Player', label: 'Player 1'));
      graph.addEdge('cell1', 'CONTAINS', 'piece1');
      graph.addEdge('player1', 'OWNS', 'piece1');

      final removed = graph.setIncomingEdge(
        'piece1',
        'CONTAINS',
        'cell2',
        properties: {'turn': 12},
      );

      expect(removed, 1);
      expect(graph.hasEdge('cell1', 'CONTAINS', 'piece1'), isFalse);
      expect(graph.hasEdge('cell2', 'CONTAINS', 'piece1'), isTrue);
      expect(graph.hasEdge('player1', 'OWNS', 'piece1'), isTrue);
      expect(graph.outNeighbors('cell1', 'CONTAINS'), isEmpty);
      expect(graph.outNeighbors('cell2', 'CONTAINS'), equals({'piece1'}));
      expect(graph.inNeighbors('piece1', 'CONTAINS'), equals({'cell2'}));
      expect(graph.edgeProperties('cell2', 'CONTAINS', 'piece1'), {'turn': 12});
    });

    test('replaceNode updates node data while preserving edges', () {
      final graph = Graph<Node>();

      final original = Node(
        id: 'piece1',
        type: 'Piece',
        label: 'Piece 1',
        properties: {'mode': 'idle'},
      );
      graph.addNode(original);
      graph.addNode(Node(id: 'cell1', type: 'Cell', label: 'Cell 1'));
      graph.addEdge('cell1', 'CONTAINS', 'piece1');

      final previous = graph.replaceNode(
        Node(
          id: 'piece1',
          type: 'Piece',
          label: 'Piece 1',
          properties: {'mode': 'dragging'},
        ),
      );

      expect(previous, same(original));
      expect(graph.nodesById['piece1']?.properties?['mode'], 'dragging');
      expect(graph.hasEdge('cell1', 'CONTAINS', 'piece1'), isTrue);
    });

    test('removeNode removes incoming, outgoing, and self-loop edges', () {
      final graph = Graph<Node>();

      graph.addNode(Node(id: 'a', type: 'Node', label: 'A'));
      graph.addNode(Node(id: 'b', type: 'Node', label: 'B'));
      graph.addNode(Node(id: 'c', type: 'Node', label: 'C'));
      graph.addEdge('a', 'LINK', 'b');
      graph.addEdge('b', 'LINK', 'c');
      graph.addEdge('b', 'SELF', 'b');

      expect(graph.removeNode('b'), isTrue);
      expect(graph.nodesById.containsKey('b'), isFalse);
      expect(graph.hasEdge('a', 'LINK', 'b'), isFalse);
      expect(graph.hasEdge('b', 'LINK', 'c'), isFalse);
      expect(graph.hasEdge('b', 'SELF', 'b'), isFalse);
      expect(graph.outNeighbors('a', 'LINK'), isEmpty);
      expect(graph.inNeighbors('c', 'LINK'), isEmpty);
      expect(graph.edges, isEmpty);
    });

    test('clearEdgesFrom and clearEdgesTo can filter by edge type', () {
      final graph = Graph<Node>();

      graph.addEdge('a', 'X', 'b');
      graph.addEdge('a', 'Y', 'c');
      graph.addEdge('d', 'X', 'b');

      expect(graph.clearEdgesFrom('a', edgeType: 'X'), 1);
      expect(graph.hasEdge('a', 'X', 'b'), isFalse);
      expect(graph.hasEdge('a', 'Y', 'c'), isTrue);
      expect(graph.hasEdge('d', 'X', 'b'), isTrue);

      expect(graph.clearEdgesTo('b', edgeType: 'X'), 1);
      expect(graph.hasEdge('d', 'X', 'b'), isFalse);
      expect(graph.hasEdge('a', 'Y', 'c'), isTrue);
    });

    test('clear removes all graph data', () {
      final graph = Graph<Node>();

      graph.addNode(Node(id: 'a', type: 'Node', label: 'A'));
      graph.addNode(Node(id: 'b', type: 'Node', label: 'B'));
      graph.addEdge('a', 'LINK', 'b');

      graph.clear();

      expect(graph.nodesById, isEmpty);
      expect(graph.out, isEmpty);
      expect(graph.inn, isEmpty);
      expect(graph.edges, isEmpty);
    });
  });
}
