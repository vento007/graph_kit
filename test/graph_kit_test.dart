import 'package:test/test.dart';
import 'package:graph_kit/graph_kit.dart';

void main() {
  test('basic graph operations', () {
    final graph = Graph<Node>();
    final query = PatternQuery(graph);

    // Add nodes
    graph.addNode(Node(id: 'alice', type: 'User', label: 'Alice'));
    graph.addNode(Node(id: 'admins', type: 'Group', label: 'Administrators'));
    
    // Add edge
    graph.addEdge('alice', 'MEMBER_OF', 'admins');
    
    // Test basic operations
    expect(graph.nodesById.length, 2);
    expect(graph.hasEdge('alice', 'MEMBER_OF', 'admins'), isTrue);
    expect(graph.outNeighbors('alice', 'MEMBER_OF'), contains('admins'));
    
    // Test pattern query
    final results = query.match('user-[:MEMBER_OF]->group', startId: 'alice');
    expect(results['user'], contains('alice'));
    expect(results['group'], contains('admins'));
  });
}
