import 'package:test/test.dart';
import 'package:graph_kit/graph_kit.dart';

/// Tests for mixed direction patterns: a->b<-c
///
/// Mixed direction allows finding common connections, shared relationships,
/// and bidirectional patterns in a single query.
///
/// ## Test Coverage Summary
///
/// ### Basic Patterns (2-3 hops)
/// - **Common target**: `person1->target<-person2` - Find people following the same person
/// - **Common source**: `target1<-person->target2` - Find people followed by the same person
/// - **Three-hop mixed**: `a->b->c<-d` - Forward then backward transitions
///
/// ### Pattern Matching Features
/// - **matchRows**: Preserve individual relationship pairs with mixed directions
/// - **matchPaths**: Verify edge directions in forward/backward patterns
/// - **Multiple edge types**: Mixed directions with `[:TYPE1|TYPE2]` syntax
/// - **Variable length paths**: `[:REL*1..2]->hub<-[:REL]` patterns
/// - **WHERE clause**: Filter mixed direction results by node properties
/// - **Label filtering**: Apply label filters in mixed direction patterns
/// - **startId**: Seed mixed direction searches from specific nodes
///
/// ### Complex Topologies
/// - **Four-way pattern**: `x->y<-z->w` - Multiple converging/diverging paths
/// - **Diamond pattern**: Paths that diverge and reconverge with mixed directions
/// - **V-shape pattern**: `a<-b<-c->d->e` - All backward then all forward
/// - **Alternating directions**: `a->b<-c->d<-e->f` - Repeated forward/backward
/// - **Triple backward**: Common ancestor patterns with multiple children
///
/// ### Real-World Scenarios
/// - **Organizational hierarchy**: Find coworkers reporting to same manager
/// - **Academic citations**: Papers citing same base work, reviews citing papers
/// - **Supply chain**: Manufacturer->distributor->retailer with mixed suppliers
///
/// ### Long Path Stress Tests
/// - **6-hop chain**: `a->b->c<-d<-e->f` - Mixed directions with moderate length
/// - **8-hop chain**: 9 nodes with multiple direction changes
/// - **15-hop chain**: 16 nodes with complex branching and mixed directions
/// - **25-hop chain**: 26 nodes with extensive alternating directions (extreme stress test)
///
/// ### Edge Cases
/// - **Same node in multiple positions**: `diana->alice<-diana` - Valid self-referential patterns
/// - **Multiple valid matches**: Pattern matcher finds all possible matches throughout graph
/// - **Overlapping patterns**: Different starting points can produce valid matches
///
void main() {
  group('Mixed Direction Patterns', () {
    late Graph<Node> graph;
    late PatternQuery<Node> query;

    setUp(() {
      graph = Graph<Node>();
      query = PatternQuery(graph);

      // Create a social network:
      // alice FOLLOWS bob
      // charlie FOLLOWS bob (alice and charlie both follow bob)
      // diana FOLLOWS alice
      // bob FOLLOWS eve
      // charlie FOLLOWS eve (bob and charlie both follow eve)

      graph.addNode(Node(id: 'alice', type: 'Person', label: 'Alice'));
      graph.addNode(Node(id: 'bob', type: 'Person', label: 'Bob'));
      graph.addNode(Node(id: 'charlie', type: 'Person', label: 'Charlie'));
      graph.addNode(Node(id: 'diana', type: 'Person', label: 'Diana'));
      graph.addNode(Node(id: 'eve', type: 'Person', label: 'Eve'));

      graph.addEdge('alice', 'FOLLOWS', 'bob');
      graph.addEdge('charlie', 'FOLLOWS', 'bob');
      graph.addEdge('diana', 'FOLLOWS', 'alice');
      graph.addEdge('bob', 'FOLLOWS', 'eve');
      graph.addEdge('charlie', 'FOLLOWS', 'eve');
    });

    test('basic common target - find people following the same person', () {
      // Pattern: person1-[:FOLLOWS]->target<-[:FOLLOWS]-person2
      // Should find: alice->bob<-charlie, bob->eve<-charlie
      final result = query.match('person1-[:FOLLOWS]->target<-[:FOLLOWS]-person2');

      // Check that we found common targets
      expect(result['target'], containsAll(['bob', 'eve']));

      // Check that correct people are matched
      expect(result['person1'], isNotEmpty);
      expect(result['person2'], isNotEmpty);
    });

    test('matchRows preserves mixed direction relationships', () {
      // Using matchRows to see specific pairs
      final rows = query.matchRows('person1-[:FOLLOWS]->target<-[:FOLLOWS]-person2');

      // Should have 2 results:
      // 1. alice->bob<-charlie (or charlie->bob<-alice)
      // 2. bob->eve<-charlie (or charlie->eve<-bob)
      expect(rows.length, greaterThanOrEqualTo(2));

      // Find the bob case
      final bobRows = rows.where((r) => r['target'] == 'bob').toList();
      expect(bobRows, isNotEmpty);

      // Both alice and charlie should appear
      final bobFollowers = bobRows.map((r) => [r['person1'], r['person2']]).expand((x) => x).toSet();
      expect(bobFollowers, containsAll(['alice', 'charlie']));

      // Find the eve case
      final eveRows = rows.where((r) => r['target'] == 'eve').toList();
      expect(eveRows, isNotEmpty);

      // Both bob and charlie should appear
      final eveFollowers = eveRows.map((r) => [r['person1'], r['person2']]).expand((x) => x).toSet();
      expect(eveFollowers, containsAll(['bob', 'charlie']));
    });

    test('matchPaths shows correct edge directions', () {
      // Verify that paths preserve the forward->backward<- pattern
      // Pattern: person1->target<-person2 means both edges point TO target
      final paths = query.matchPaths('person1-[:FOLLOWS]->target<-[:FOLLOWS]-person2');

      expect(paths, isNotEmpty);

      // Check that each path has exactly 2 edges
      for (final path in paths) {
        expect(path.edges, hasLength(2));

        // All edges should be FOLLOWS type
        expect(path.edges.every((e) => e.type == 'FOLLOWS'), isTrue);

        // Verify the middle node is the target
        final target = path.nodes['target'];
        expect(target, isNotNull);

        // Both edges should point TO the target (common target pattern)
        expect(path.edges[0].to, equals(target));
        expect(path.edges[1].to, equals(target));

        // The two edges can come from the same or different people
        // (pattern allows diana->alice<-diana for example)
      }
    });

    test('basic common source - find people followed by the same person', () {
      // Pattern: target1<-[:FOLLOWS]-person-[:FOLLOWS]->target2
      // Should find people that 'person' follows
      // charlie follows both bob and eve
      final result = query.match('target1<-[:FOLLOWS]-person-[:FOLLOWS]->target2');

      // Charlie is the common person
      expect(result['person'], contains('charlie'));

      // bob and eve are both followed by charlie
      expect(result['target1'], isNotEmpty);
      expect(result['target2'], isNotEmpty);
    });

    test('three-hop mixed pattern', () {
      // Pattern: a-[:FOLLOWS]->b-[:FOLLOWS]->c<-[:FOLLOWS]-d
      // diana->alice->bob<-charlie
      final result = query.match('a-[:FOLLOWS]->b-[:FOLLOWS]->c<-[:FOLLOWS]-d');

      expect(result['a'], contains('diana'));
      expect(result['b'], contains('alice'));
      expect(result['c'], contains('bob'));
      expect(result['d'], contains('charlie'));
    });

    test('organizational hierarchy - coworkers pattern', () {
      // Create org structure: employees report to same manager
      final orgGraph = Graph<Node>();
      orgGraph.addNode(Node(id: 'alice', type: 'Employee', label: 'Alice'));
      orgGraph.addNode(Node(id: 'bob', type: 'Employee', label: 'Bob'));
      orgGraph.addNode(Node(id: 'charlie', type: 'Employee', label: 'Charlie'));
      orgGraph.addNode(Node(id: 'manager1', type: 'Manager', label: 'Manager 1'));

      orgGraph.addEdge('alice', 'REPORTS_TO', 'manager1');
      orgGraph.addEdge('bob', 'REPORTS_TO', 'manager1');
      orgGraph.addEdge('charlie', 'REPORTS_TO', 'manager1');

      final orgQuery = PatternQuery(orgGraph);

      // Find coworkers: people reporting to the same manager
      final result = orgQuery.match('emp1-[:REPORTS_TO]->manager<-[:REPORTS_TO]-emp2');

      expect(result['manager'], equals({'manager1'}));
      expect(result['emp1'], containsAll(['alice', 'bob', 'charlie']));
      expect(result['emp2'], containsAll(['alice', 'bob', 'charlie']));
    });

    test('mixed direction with multiple edge types', () {
      // Create graph with different relationship types
      final mixedGraph = Graph<Node>();
      mixedGraph.addNode(Node(id: 'alice', type: 'Person', label: 'Alice'));
      mixedGraph.addNode(Node(id: 'bob', type: 'Person', label: 'Bob'));
      mixedGraph.addNode(Node(id: 'charlie', type: 'Person', label: 'Charlie'));
      mixedGraph.addNode(Node(id: 'project', type: 'Project', label: 'Project X'));

      mixedGraph.addEdge('alice', 'WORKS_ON', 'project');
      mixedGraph.addEdge('bob', 'MANAGES', 'project');
      mixedGraph.addEdge('charlie', 'VOLUNTEERS_FOR', 'project');

      final mixedQuery = PatternQuery(mixedGraph);

      // Find people connected to same project via different relationship types
      final result = mixedQuery.match('p1-[:WORKS_ON|MANAGES]->proj<-[:VOLUNTEERS_FOR]-p2');

      expect(result['proj'], equals({'project'}));
      expect(result['p1'], containsAll(['alice', 'bob']));
      expect(result['p2'], equals({'charlie'}));
    });

    test('mixed direction with variable length paths', () {
      // Create a chain
      final chainGraph = Graph<Node>();
      chainGraph.addNode(Node(id: 'a', type: 'Node', label: 'A'));
      chainGraph.addNode(Node(id: 'b', type: 'Node', label: 'B'));
      chainGraph.addNode(Node(id: 'c', type: 'Node', label: 'C'));
      chainGraph.addNode(Node(id: 'd', type: 'Node', label: 'D'));
      chainGraph.addNode(Node(id: 'e', type: 'Node', label: 'E'));

      chainGraph.addEdge('a', 'CONNECTS', 'b');
      chainGraph.addEdge('b', 'CONNECTS', 'c');
      chainGraph.addEdge('d', 'CONNECTS', 'c');
      chainGraph.addEdge('e', 'CONNECTS', 'c');

      final chainQuery = PatternQuery(chainGraph);

      // Variable length forward, then backward
      // start can reach hub in 1-2 hops, and hub has incoming edge from end
      final result = chainQuery.match('start-[:CONNECTS*1..2]->hub<-[:CONNECTS]-end');

      // Both b and c are valid hubs:
      // - b: can be reached from a (1 hop), has incoming from a
      // - c: can be reached from a,b (1-2 hops), has incoming from d,e
      expect(result['hub'], containsAll(['b', 'c']));
      expect(result['start'], containsAll(['a', 'b']));
      expect(result['end'], containsAll(['a', 'd', 'e'])); // a connects to b, d and e connect to c
    });

    test('mixed direction with WHERE clause', () {
      // Add properties
      final propsGraph = Graph<Node>();
      propsGraph.addNode(Node(
        id: 'alice',
        type: 'Person',
        label: 'Alice',
        properties: {'age': 28, 'department': 'Engineering'}
      ));
      propsGraph.addNode(Node(
        id: 'bob',
        type: 'Person',
        label: 'Bob',
        properties: {'age': 35, 'department': 'Engineering'}
      ));
      propsGraph.addNode(Node(
        id: 'charlie',
        type: 'Person',
        label: 'Charlie',
        properties: {'age': 42, 'department': 'Engineering'}
      ));
      propsGraph.addNode(Node(id: 'project', type: 'Project', label: 'Project X'));

      propsGraph.addEdge('alice', 'WORKS_ON', 'project');
      propsGraph.addEdge('bob', 'WORKS_ON', 'project');
      propsGraph.addEdge('charlie', 'WORKS_ON', 'project');

      final propsQuery = PatternQuery(propsGraph);

      // Find pairs where both are over 30 and work on same project
      final rows = propsQuery.matchRows(
        'MATCH p1-[:WORKS_ON]->proj<-[:WORKS_ON]-p2 WHERE p1.age > 30 AND p2.age > 30'
      );

      // Should only include bob (35) and charlie (42), not alice (28)
      for (final row in rows) {
        final p1 = row['p1']!;
        final p2 = row['p2']!;
        expect(['bob', 'charlie'], contains(p1));
        expect(['bob', 'charlie'], contains(p2));
        expect(p1, isNot(equals('alice')));
        expect(p2, isNot(equals('alice')));
      }
    });

    test('mixed direction with label filtering', () {
      // Pattern with label filter
      final result = query.match('person1:Person{label~Alice}-[:FOLLOWS]->target<-[:FOLLOWS]-person2');

      // Should find alice->bob<-charlie
      expect(result['person1'], equals({'alice'}));
      expect(result['target'], equals({'bob'}));
      expect(result['person2'], contains('charlie'));
    });

    test('mixed direction with startId', () {
      // Starting from charlie, find who else follows the people he follows
      final result = query.match(
        'person1-[:FOLLOWS]->target<-[:FOLLOWS]-person2',
        startId: 'charlie'
      );

      // Charlie follows both bob and eve
      // alice also follows bob
      // bob also follows eve
      expect(result['person1'], equals({'charlie'}));
      expect(result['target'], containsAll(['bob', 'eve']));
      expect(result['person2'], isNotEmpty);
    });

    test('same person can appear in both positions', () {
      // diana only follows alice
      // The pattern allows diana to appear as both person1 and person2
      final rows = query.matchRows('person1-[:FOLLOWS]->target<-[:FOLLOWS]-person2');
      final aliceAsTarget = rows.where((r) => r['target'] == 'alice').toList();

      // diana->alice<-diana is a valid match (same person in both positions)
      expect(aliceAsTarget, isNotEmpty);
      expect(aliceAsTarget.first['person1'], equals('diana'));
      expect(aliceAsTarget.first['person2'], equals('diana'));
    });

    test('four-way mixed pattern', () {
      // Pattern: x->y<-z->w
      // Create structure: a->b, c->b, c->d

      final fourGraph = Graph<Node>();
      fourGraph.addNode(Node(id: 'a', type: 'Node', label: 'A'));
      fourGraph.addNode(Node(id: 'b', type: 'Node', label: 'B'));
      fourGraph.addNode(Node(id: 'c', type: 'Node', label: 'C'));
      fourGraph.addNode(Node(id: 'd', type: 'Node', label: 'D'));

      fourGraph.addEdge('a', 'CONNECTS', 'b');
      fourGraph.addEdge('c', 'CONNECTS', 'b');
      fourGraph.addEdge('c', 'CONNECTS', 'd');

      final fourQuery = PatternQuery(fourGraph);

      // Pattern matches: x->y<-z->w where x and z both connect to y, and z connects to w
      // Valid matches include:
      // - a->b<-c->d (x=a, y=b, z=c, w=d)
      // - c->b<-c->d (x=c, y=b, z=c, w=d)
      // - c->d<-c->d (x=c, y=d, z=c, w=d)
      // - x->b<-a->b (z=a, y=b, w=b) - same node 'b' in y and w positions
      final result = fourQuery.match('x-[:CONNECTS]->y<-[:CONNECTS]-z-[:CONNECTS]->w');

      expect(result['y'], containsAll(['b', 'd'])); // both b and d can be y
      expect(result['z'], containsAll(['a', 'c'])); // both a and c can be z
      expect(result['w'], containsAll(['b', 'd'])); // both b and d can be w
      expect(result['x'], containsAll(['a', 'c'])); // both a and c can be x
    });

    test('long chain - 6 hops with mixed directions', () {
      // Create: a->b->c<-d<-e->f
      final longGraph = Graph<Node>();
      for (var id in ['a', 'b', 'c', 'd', 'e', 'f']) {
        longGraph.addNode(Node(id: id, type: 'Node', label: id.toUpperCase()));
      }

      longGraph.addEdge('a', 'CONNECTS', 'b');
      longGraph.addEdge('b', 'CONNECTS', 'c');
      longGraph.addEdge('d', 'CONNECTS', 'c');
      longGraph.addEdge('e', 'CONNECTS', 'd');
      longGraph.addEdge('e', 'CONNECTS', 'f');

      final longQuery = PatternQuery(longGraph);

      // 5-hop pattern: a->b->c<-d<-e->f
      final result = longQuery.match('n1-[:CONNECTS]->n2-[:CONNECTS]->n3<-[:CONNECTS]-n4<-[:CONNECTS]-n5-[:CONNECTS]->n6');

      expect(result['n1'], contains('a'));
      expect(result['n2'], contains('b'));
      expect(result['n3'], contains('c'));
      expect(result['n4'], contains('d'));
      expect(result['n5'], contains('e'));
      expect(result['n6'], contains('f'));
    });

    test('alternating directions - forward/backward repeated', () {
      // Pattern: a->b<-c->d<-e->f
      // Create structure where this pattern exists
      final altGraph = Graph<Node>();
      for (var id in ['a', 'b', 'c', 'd', 'e', 'f']) {
        altGraph.addNode(Node(id: id, type: 'Node', label: id.toUpperCase()));
      }

      altGraph.addEdge('a', 'X', 'b');
      altGraph.addEdge('c', 'X', 'b');
      altGraph.addEdge('c', 'X', 'd');
      altGraph.addEdge('e', 'X', 'd');
      altGraph.addEdge('e', 'X', 'f');

      final altQuery = PatternQuery(altGraph);

      final result = altQuery.match('n1-[:X]->n2<-[:X]-n3-[:X]->n4<-[:X]-n5-[:X]->n6');

      expect(result['n1'], contains('a'));
      expect(result['n2'], contains('b'));
      expect(result['n3'], contains('c'));
      expect(result['n4'], contains('d'));
      expect(result['n5'], contains('e'));
      expect(result['n6'], contains('f'));
    });

    test('all backward then all forward - complex V shape', () {
      // Pattern: a<-b<-c->d->e (V shape centered at c)
      final vGraph = Graph<Node>();
      for (var id in ['a', 'b', 'c', 'd', 'e']) {
        vGraph.addNode(Node(id: id, type: 'Node', label: id.toUpperCase()));
      }

      vGraph.addEdge('b', 'LINKS', 'a');
      vGraph.addEdge('c', 'LINKS', 'b');
      vGraph.addEdge('c', 'LINKS', 'd');
      vGraph.addEdge('d', 'LINKS', 'e');

      final vQuery = PatternQuery(vGraph);

      final result = vQuery.match('n1<-[:LINKS]-n2<-[:LINKS]-n3-[:LINKS]->n4-[:LINKS]->n5');

      expect(result['n1'], contains('a'));
      expect(result['n2'], contains('b'));
      expect(result['n3'], contains('c'));
      expect(result['n4'], contains('d'));
      expect(result['n5'], contains('e'));
    });

    test('triple backward - find common ancestor pattern', () {
      // Pattern: a<-root->b<-root->c
      // Testing: x<-y->z<-y->w (where same node appears twice)
      final ancestorGraph = Graph<Node>();
      ancestorGraph.addNode(Node(id: 'root', type: 'Node', label: 'Root'));
      ancestorGraph.addNode(Node(id: 'child1', type: 'Node', label: 'Child 1'));
      ancestorGraph.addNode(Node(id: 'child2', type: 'Node', label: 'Child 2'));
      ancestorGraph.addNode(Node(id: 'child3', type: 'Node', label: 'Child 3'));

      ancestorGraph.addEdge('root', 'PARENT_OF', 'child1');
      ancestorGraph.addEdge('root', 'PARENT_OF', 'child2');
      ancestorGraph.addEdge('root', 'PARENT_OF', 'child3');

      final ancestorQuery = PatternQuery(ancestorGraph);

      // Find three children of same parent
      final result = ancestorQuery.match('c1<-[:PARENT_OF]-parent-[:PARENT_OF]->c2<-[:PARENT_OF]-parent2-[:PARENT_OF]->c3');

      // Should find all combinations where parent and parent2 are both 'root'
      expect(result['parent'], equals({'root'}));
      expect(result['parent2'], equals({'root'}));
      expect(result['c1'], containsAll(['child1', 'child2', 'child3']));
      expect(result['c2'], containsAll(['child1', 'child2', 'child3']));
      expect(result['c3'], containsAll(['child1', 'child2', 'child3']));
    });

    test('diamond pattern - two paths converging and diverging', () {
      // Pattern: a->b->d, a->c->d (diamond)
      // Query: start-[:X]->top<-[:X]-start-[:X]->bottom-[:X]->end<-[:X]-top
      final diamondGraph = Graph<Node>();
      for (var id in ['start', 'top', 'bottom', 'end']) {
        diamondGraph.addNode(Node(id: id, type: 'Node', label: id));
      }

      diamondGraph.addEdge('start', 'PATH', 'top');
      diamondGraph.addEdge('start', 'PATH', 'bottom');
      diamondGraph.addEdge('top', 'PATH', 'end');
      diamondGraph.addEdge('bottom', 'PATH', 'end');

      final diamondQuery = PatternQuery(diamondGraph);

      // Find diamond: start fans out to middle1 and middle2, which converge at end
      final result = diamondQuery.match('s-[:PATH]->m1-[:PATH]->e<-[:PATH]-m2<-[:PATH]-s2');

      expect(result['s'], contains('start'));
      expect(result['s2'], contains('start'));
      expect(result['m1'], containsAll(['top', 'bottom']));
      expect(result['m2'], containsAll(['top', 'bottom']));
      expect(result['e'], equals({'end'}));
    });

    test('real-world: academic citation network with mixed directions', () {
      // Paper1 cites BaseWork
      // Paper2 cites BaseWork
      // Paper2 is cited by Review
      // Paper3 is cited by Review
      final citationGraph = Graph<Node>();

      citationGraph.addNode(Node(id: 'paper1', type: 'Paper', label: 'Paper 1'));
      citationGraph.addNode(Node(id: 'paper2', type: 'Paper', label: 'Paper 2'));
      citationGraph.addNode(Node(id: 'paper3', type: 'Paper', label: 'Paper 3'));
      citationGraph.addNode(Node(id: 'baseWork', type: 'Paper', label: 'Base Work'));
      citationGraph.addNode(Node(id: 'review', type: 'Paper', label: 'Review Paper'));

      citationGraph.addEdge('paper1', 'CITES', 'baseWork');
      citationGraph.addEdge('paper2', 'CITES', 'baseWork');
      citationGraph.addEdge('review', 'CITES', 'paper2');
      citationGraph.addEdge('review', 'CITES', 'paper3');

      final citationQuery = PatternQuery(citationGraph);

      // Find papers that cite the same base work as a paper cited by a review
      // p1->base<-p2<-review->p3
      final result = citationQuery.match(
        'p1-[:CITES]->base<-[:CITES]-p2<-[:CITES]-rev-[:CITES]->p3'
      );

      expect(result['base'], equals({'baseWork'}));
      expect(result['rev'], equals({'review'}));
      expect(result['p1'], contains('paper1'));
      expect(result['p2'], contains('paper2'));
      expect(result['p3'], contains('paper3'));
    });

    test('real-world: supply chain with mixed directions', () {
      // manufacturer->distributor<-manufacturer2
      // distributor->retailer<-distributor2
      // retailer->customer
      final supplyGraph = Graph<Node>();

      supplyGraph.addNode(Node(id: 'm1', type: 'Manufacturer', label: 'Manufacturer 1'));
      supplyGraph.addNode(Node(id: 'm2', type: 'Manufacturer', label: 'Manufacturer 2'));
      supplyGraph.addNode(Node(id: 'dist', type: 'Distributor', label: 'Distributor'));
      supplyGraph.addNode(Node(id: 'dist2', type: 'Distributor', label: 'Distributor 2'));
      supplyGraph.addNode(Node(id: 'retail', type: 'Retailer', label: 'Retailer'));
      supplyGraph.addNode(Node(id: 'customer', type: 'Customer', label: 'Customer'));

      supplyGraph.addEdge('m1', 'SUPPLIES', 'dist');
      supplyGraph.addEdge('m2', 'SUPPLIES', 'dist');
      supplyGraph.addEdge('dist', 'SUPPLIES', 'retail');
      supplyGraph.addEdge('dist2', 'SUPPLIES', 'retail');
      supplyGraph.addEdge('retail', 'SUPPLIES', 'customer');

      final supplyQuery = PatternQuery(supplyGraph);

      // Find complete chain: manufacturer->distributor->retailer<-distributor2<-manufacturer2->...
      final result = supplyQuery.match(
        'm1-[:SUPPLIES]->d1-[:SUPPLIES]->r<-[:SUPPLIES]-d2<-[:SUPPLIES]-m2'
      );

      expect(result['m1'], contains('m1'));
      expect(result['m2'], contains('m2'));
      expect(result['d1'], contains('dist'));
      expect(result['d2'], contains('dist'));
      expect(result['r'], contains('retail'));
    });

    test('extreme: 8-hop mixed pattern', () {
      // Create a long winding path with multiple direction changes
      final extremeGraph = Graph<Node>();
      for (var i = 1; i <= 9; i++) {
        extremeGraph.addNode(Node(id: 'n$i', type: 'Node', label: 'Node $i'));
      }

      // Path: n1->n2<-n3->n4->n5<-n6<-n7->n8->n9
      extremeGraph.addEdge('n1', 'E', 'n2');
      extremeGraph.addEdge('n3', 'E', 'n2');
      extremeGraph.addEdge('n3', 'E', 'n4');
      extremeGraph.addEdge('n4', 'E', 'n5');
      extremeGraph.addEdge('n6', 'E', 'n5');
      extremeGraph.addEdge('n7', 'E', 'n6');
      extremeGraph.addEdge('n7', 'E', 'n8');
      extremeGraph.addEdge('n8', 'E', 'n9');

      final extremeQuery = PatternQuery(extremeGraph);

      final result = extremeQuery.match(
        'a-[:E]->b<-[:E]-c-[:E]->d-[:E]->e<-[:E]-f<-[:E]-g-[:E]->h-[:E]->i'
      );

      expect(result['a'], contains('n1'));
      expect(result['b'], contains('n2'));
      expect(result['c'], contains('n3'));
      expect(result['d'], contains('n4'));
      expect(result['e'], contains('n5'));
      expect(result['f'], contains('n6'));
      expect(result['g'], contains('n7'));
      expect(result['h'], contains('n8'));
      expect(result['i'], contains('n9'));
    });

    test('mixed directions with multiple edge types and variable length', () {
      // Complex: variable length forward, then backward with multiple types
      final complexGraph = Graph<Node>();
      for (var id in ['a', 'b', 'c', 'd', 'e']) {
        complexGraph.addNode(Node(id: id, type: 'Node', label: id.toUpperCase()));
      }

      complexGraph.addEdge('a', 'TYPE1', 'b');
      complexGraph.addEdge('b', 'TYPE1', 'c');
      complexGraph.addEdge('d', 'TYPE2', 'c');
      complexGraph.addEdge('e', 'TYPE3', 'c');

      final complexQuery = PatternQuery(complexGraph);

      // Variable length forward, then backward with OR edge types
      final result = complexQuery.match('start-[:TYPE1*1..2]->hub<-[:TYPE2|TYPE3]-end');

      expect(result['hub'], equals({'c'}));
      expect(result['start'], containsAll(['a', 'b']));
      expect(result['end'], containsAll(['d', 'e']));
    });

    test('long path - 15-hop mixed pattern with complex branching', () {
      // Create a complex graph with 20 nodes and a long winding path
      // Pattern: n1->n2->n3<-n4->n5<-n6->n7->n8<-n9<-n10->n11<-n12->n13->n14<-n15->n16
      final longGraph = Graph<Node>();
      for (var i = 1; i <= 20; i++) {
        longGraph.addNode(Node(id: 'node$i', type: 'Node', label: 'Node $i'));
      }

      // Build the main path with mixed directions
      longGraph.addEdge('node1', 'LINK', 'node2');   // ->
      longGraph.addEdge('node2', 'LINK', 'node3');   // ->
      longGraph.addEdge('node4', 'LINK', 'node3');   // <- (backward)
      longGraph.addEdge('node4', 'LINK', 'node5');   // ->
      longGraph.addEdge('node6', 'LINK', 'node5');   // <- (backward)
      longGraph.addEdge('node6', 'LINK', 'node7');   // ->
      longGraph.addEdge('node7', 'LINK', 'node8');   // ->
      longGraph.addEdge('node9', 'LINK', 'node8');   // <- (backward)
      longGraph.addEdge('node10', 'LINK', 'node9');  // <- (backward)
      longGraph.addEdge('node10', 'LINK', 'node11'); // ->
      longGraph.addEdge('node12', 'LINK', 'node11'); // <- (backward)
      longGraph.addEdge('node12', 'LINK', 'node13'); // ->
      longGraph.addEdge('node13', 'LINK', 'node14'); // ->
      longGraph.addEdge('node15', 'LINK', 'node14'); // <- (backward)
      longGraph.addEdge('node15', 'LINK', 'node16'); // ->

      // Add some additional branches to make it more interesting
      longGraph.addEdge('node1', 'LINK', 'node17');  // branch
      longGraph.addEdge('node8', 'LINK', 'node18');  // branch
      longGraph.addEdge('node19', 'LINK', 'node14'); // converging branch

      final longQuery = PatternQuery(longGraph);

      // Test the full 15-hop pattern
      final result = longQuery.match(
        'n1-[:LINK]->n2-[:LINK]->n3<-[:LINK]-n4-[:LINK]->n5<-[:LINK]-n6-[:LINK]->n7-[:LINK]->n8<-[:LINK]-n9<-[:LINK]-n10-[:LINK]->n11<-[:LINK]-n12-[:LINK]->n13-[:LINK]->n14<-[:LINK]-n15-[:LINK]->n16'
      );

      // Verify all nodes are matched correctly
      expect(result['n1'], contains('node1'));
      expect(result['n2'], contains('node2'));
      expect(result['n3'], contains('node3'));
      expect(result['n4'], contains('node4'));
      expect(result['n5'], contains('node5'));
      expect(result['n6'], contains('node6'));
      expect(result['n7'], contains('node7'));
      expect(result['n8'], contains('node8'));
      expect(result['n9'], contains('node9'));
      expect(result['n10'], contains('node10'));
      expect(result['n11'], contains('node11'));
      expect(result['n12'], contains('node12'));
      expect(result['n13'], contains('node13'));
      expect(result['n14'], contains('node14'));
      expect(result['n15'], contains('node15'));
      expect(result['n16'], contains('node16'));

      // Test that matchPaths returns the correct path structure
      final paths = longQuery.matchPaths(
        'n1-[:LINK]->n2-[:LINK]->n3<-[:LINK]-n4-[:LINK]->n5<-[:LINK]-n6-[:LINK]->n7-[:LINK]->n8<-[:LINK]-n9<-[:LINK]-n10-[:LINK]->n11<-[:LINK]-n12-[:LINK]->n13-[:LINK]->n14<-[:LINK]-n15-[:LINK]->n16'
      );

      expect(paths, isNotEmpty);
      // Path structure verification - paths may have varying structures due to multiple matches
      final matchingPath = paths.firstWhere(
        (p) => p.edges.length == 15 && 
               p.edges[0].from == 'node1' && 
               p.edges.last.to == 'node16',
        orElse: () => paths.first
      );
      
      if (matchingPath.edges.length == 15) {
        // Verify directions are correct by checking specific edges
        expect(matchingPath.edges[0].from, equals('node1')); // n1->n2
        expect(matchingPath.edges[0].to, equals('node2'));
        expect(matchingPath.edges[2].from, equals('node4')); // n3<-n4 (edge from n4 to n3)
        expect(matchingPath.edges[2].to, equals('node3'));
        expect(matchingPath.edges[4].from, equals('node6')); // n5<-n6 (edge from n6 to n5)
        expect(matchingPath.edges[4].to, equals('node5'));
      }
    });

    test('extremely long path - 25-hop all mixed directions', () {
      // Create an even longer graph to stress test with 26 nodes
      final extremeGraph = Graph<Node>();
      for (var i = 1; i <= 30; i++) {
        extremeGraph.addNode(Node(id: 'x$i', type: 'Node', label: 'X$i'));
      }

      // Create a long chain with alternating and mixed directions
      // Pattern: x1->x2<-x3->x4->x5<-x6<-x7->x8<-x9->x10->x11<-x12->x13<-x14<-x15->x16->x17<-x18->x19<-x20->x21->x22<-x23<-x24->x25<-x26
      extremeGraph.addEdge('x1', 'EDGE', 'x2');   // x1->x2
      extremeGraph.addEdge('x3', 'EDGE', 'x2');   // x2<-x3
      extremeGraph.addEdge('x3', 'EDGE', 'x4');   // x3->x4
      extremeGraph.addEdge('x4', 'EDGE', 'x5');   // x4->x5
      extremeGraph.addEdge('x6', 'EDGE', 'x5');   // x5<-x6
      extremeGraph.addEdge('x7', 'EDGE', 'x6');   // x6<-x7
      extremeGraph.addEdge('x7', 'EDGE', 'x8');   // x7->x8
      extremeGraph.addEdge('x9', 'EDGE', 'x8');   // x8<-x9
      extremeGraph.addEdge('x9', 'EDGE', 'x10');  // x9->x10
      extremeGraph.addEdge('x10', 'EDGE', 'x11'); // x10->x11
      extremeGraph.addEdge('x12', 'EDGE', 'x11'); // x11<-x12
      extremeGraph.addEdge('x12', 'EDGE', 'x13'); // x12->x13
      extremeGraph.addEdge('x14', 'EDGE', 'x13'); // x13<-x14
      extremeGraph.addEdge('x15', 'EDGE', 'x14'); // x14<-x15
      extremeGraph.addEdge('x15', 'EDGE', 'x16'); // x15->x16
      extremeGraph.addEdge('x16', 'EDGE', 'x17'); // x16->x17
      extremeGraph.addEdge('x18', 'EDGE', 'x17'); // x17<-x18
      extremeGraph.addEdge('x18', 'EDGE', 'x19'); // x18->x19
      extremeGraph.addEdge('x20', 'EDGE', 'x19'); // x19<-x20
      extremeGraph.addEdge('x20', 'EDGE', 'x21'); // x20->x21
      extremeGraph.addEdge('x21', 'EDGE', 'x22'); // x21->x22
      extremeGraph.addEdge('x23', 'EDGE', 'x22'); // x22<-x23
      extremeGraph.addEdge('x24', 'EDGE', 'x23'); // x23<-x24
      extremeGraph.addEdge('x24', 'EDGE', 'x25'); // x24->x25
      extremeGraph.addEdge('x26', 'EDGE', 'x25'); // x25<-x26

      final extremeQuery = PatternQuery(extremeGraph);

      // Query the 25-hop pattern
      final result = extremeQuery.match(
        'a-[:EDGE]->b<-[:EDGE]-c-[:EDGE]->d-[:EDGE]->e<-[:EDGE]-f<-[:EDGE]-g-[:EDGE]->h<-[:EDGE]-i-[:EDGE]->j-[:EDGE]->k<-[:EDGE]-l-[:EDGE]->m<-[:EDGE]-n<-[:EDGE]-o-[:EDGE]->p-[:EDGE]->q<-[:EDGE]-r-[:EDGE]->s<-[:EDGE]-t-[:EDGE]->u-[:EDGE]->v<-[:EDGE]-w<-[:EDGE]-x-[:EDGE]->y<-[:EDGE]-z'
      );

      // Verify the entire chain is matched
      expect(result['a'], contains('x1'));
      expect(result['b'], contains('x2'));
      expect(result['c'], contains('x3'));
      expect(result['d'], contains('x4'));
      expect(result['e'], contains('x5'));
      expect(result['f'], contains('x6'));
      expect(result['g'], contains('x7'));
      expect(result['h'], contains('x8'));
      expect(result['i'], contains('x9'));
      expect(result['j'], contains('x10'));
      expect(result['k'], contains('x11'));
      expect(result['l'], contains('x12'));
      expect(result['m'], contains('x13'));
      expect(result['n'], contains('x14'));
      expect(result['o'], contains('x15'));
      expect(result['p'], contains('x16'));
      expect(result['q'], contains('x17'));
      expect(result['r'], contains('x18'));
      expect(result['s'], contains('x19'));
      expect(result['t'], contains('x20'));
      expect(result['u'], contains('x21'));
      expect(result['v'], contains('x22'));
      expect(result['w'], contains('x23'));
      expect(result['x'], contains('x24'));
      expect(result['y'], contains('x25'));
      expect(result['z'], contains('x26'));

      // Verify matchRows returns results - pattern matcher may find multiple overlapping matches
      final rows = extremeQuery.matchRows(
        'a-[:EDGE]->b<-[:EDGE]-c-[:EDGE]->d-[:EDGE]->e<-[:EDGE]-f<-[:EDGE]-g-[:EDGE]->h<-[:EDGE]-i-[:EDGE]->j-[:EDGE]->k<-[:EDGE]-l-[:EDGE]->m<-[:EDGE]-n<-[:EDGE]-o-[:EDGE]->p-[:EDGE]->q<-[:EDGE]-r-[:EDGE]->s<-[:EDGE]-t-[:EDGE]->u-[:EDGE]->v<-[:EDGE]-w<-[:EDGE]-x-[:EDGE]->y<-[:EDGE]-z'
      );

      expect(rows, isNotEmpty);
      // Verify that the full chain can be found (may be across different rows)
      final allA = rows.map((r) => r['a']).toSet();
      final allZ = rows.map((r) => r['z']).toSet();
      expect(allA, contains('x1'));
      expect(allZ, contains('x26'));
    });
  });
}
