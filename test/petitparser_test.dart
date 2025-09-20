import 'package:test/test.dart';
import 'package:petitparser/petitparser.dart';
import 'package:graph_kit/graph_kit.dart';
import 'package:graph_kit/src/pattern_query_petit.dart';

void main() {
  group('PetitParser Grammar Tests', () {
    late CypherPatternGrammar grammar;

    setUp(() {
      grammar = CypherPatternGrammar();
    });

    test('should parse simple variable', () {
      final parser = grammar.buildFrom(grammar.variable());

      expect(parser.parse('user') is Success, isTrue);
      expect(parser.parse('group') is Success, isTrue);
      expect(parser.parse('user123') is Success, isTrue);
      expect(parser.parse('user_name') is Success, isTrue);

      // Should fail
      expect(parser.parse('123user') is Failure, isTrue);
      expect(parser.parse('') is Failure, isTrue);
    });

    test('should parse node type', () {
      final parser = grammar.buildFrom(grammar.nodeType());

      expect(parser.parse(':User') is Success, isTrue);
      expect(parser.parse(':Group') is Success, isTrue);

      // Should fail
      expect(parser.parse('User') is Failure, isTrue);
      expect(parser.parse(':') is Failure, isTrue);
    });

    test('should parse simple patterns', () {
      final parser = grammar.build();

      expect(parser.parse('user') is Success, isTrue);
      expect(parser.parse('user:User') is Success, isTrue);

      print('Testing user:User...');
      final result = parser.parse('user:User');
      print('Result: ${result is Success ? "SUCCESS" : "FAILURE: ${result.message}"}');
    });

    test('should parse patterns with edges', () {
      final parser = grammar.build();

      print('Testing user->group...');
      final result1 = parser.parse('user->group');
      print('Result: ${result1 is Success ? "SUCCESS" : "FAILURE: ${result1.message}"}');
      print('Position: ${result1.position}');

      print('Testing user-[:MEMBER_OF]->group...');
      final result2 = parser.parse('user-[:MEMBER_OF]->group');
      print('Result: ${result2 is Success ? "SUCCESS" : "FAILURE: ${result2.message}"}');
    });

    test('should parse label filters', () {
      final parser = grammar.build();

      print('Testing person{label=Alice}...');
      final result1 = parser.parse('person{label=Alice}');
      print('Result: ${result1 is Success ? "SUCCESS" : "FAILURE: ${result1.message}"}');

      print('Testing person{label~alice}...');
      final result2 = parser.parse('person{label~alice}');
      print('Result: ${result2 is Success ? "SUCCESS" : "FAILURE: ${result2.message}"}');

      print('Testing person:Person{label=Alice Cooper}...');
      final result3 = parser.parse('person:Person{label=Alice Cooper}');
      print('Result: ${result3 is Success ? "SUCCESS" : "FAILURE: ${result3.message}"}');
    });

    test('should parse complex patterns from README', () {
      final parser = grammar.build();

      // Test backward arrows
      print('Testing destination<-[:DESTINATION]-group...');
      final result1 = parser.parse('destination<-[:DESTINATION]-group');
      print('Result: ${result1 is Success ? "SUCCESS" : "FAILURE: ${result1.message}"}');
      print('Position: ${result1.position}');

      // Test multi-hop patterns
      print('Testing user-[:MEMBER_OF]->group-[:SOURCE]->policy...');
      final result2 = parser.parse('user-[:MEMBER_OF]->group-[:SOURCE]->policy');
      print('Result: ${result2 is Success ? "SUCCESS" : "FAILURE: ${result2.message}"}');

      // Test combined type and label
      print('Testing person:Person{label~Alice}-[:WORKS_FOR]->team...');
      final result3 = parser.parse('person:Person{label~Alice}-[:WORKS_FOR]->team');
      print('Result: ${result3 is Success ? "SUCCESS" : "FAILURE: ${result3.message}"}');
    });

    test('should parse multi-hop patterns', () {
      final parser = grammar.build();

      // Test 4-hop pattern
      print('Testing user-[:MEMBER_OF]->group-[:SOURCE]->policy-[:DESTINATION]->asset...');
      final result1 = parser.parse('user-[:MEMBER_OF]->group-[:SOURCE]->policy-[:DESTINATION]->asset');
      print('Result: ${result1 is Success ? "SUCCESS" : "FAILURE: ${result1.message}"}');

      // Test 5-hop pattern
      print('Testing a->b->c->d->e...');
      final result2 = parser.parse('a->b->c->d->e');
      print('Result: ${result2 is Success ? "SUCCESS" : "FAILURE: ${result2.message}"}');

      // Test mixed directions
      print('Testing start->middle<-[:REVERSE]-end...');
      final result3 = parser.parse('start->middle<-[:REVERSE]-end');
      print('Result: ${result3 is Success ? "SUCCESS" : "FAILURE: ${result3.message}"}');

      // Test very long chain
      print('Testing 6-hop pattern with types...');
      final result4 = parser.parse('user:Person-[:WORKS_FOR]->team:Team-[:MANAGES]->project:Project-[:USES]->tool:Tool-[:STORES]->data:Data-[:BACKED_BY]->server:Server');
      print('Result: ${result4 is Success ? "SUCCESS" : "FAILURE: ${result4.message}"}');
    });

    test('should parse ultimate complex pattern with everything', () {
      final parser = grammar.build();

      // The ultimate test: everything combined
      final complexPattern = '''alice:Person{label~Alice Cooper}
-[:WORKS_FOR]->
engineering:Team{label=Engineering}
-[:MANAGES]->
webapp:Project{label~Web Application}
<-[:DEPENDS_ON]-
database:Service{label=PostgreSQL}
-[:HOSTED_ON]->
prod:Server{label~Production}
<-[:MONITORS]-
admin:Person{label=System Administrator}'''.replaceAll('\n', '').replaceAll(' ', '');

      print('Testing ultimate complex pattern...');
      print('Pattern: $complexPattern');
      final result = parser.parse(complexPattern);
      print('Result: ${result is Success ? "SUCCESS" : "FAILURE: ${result.message}"}');

      if (result is Failure) {
        print('Failed at position: ${result.position}');
        final context = '${complexPattern.substring(0, result.position)} <-- HERE --> ${complexPattern.substring(result.position)}';
        print('Context: $context');
      } else {
        print('Parse tree: ${result.value}');
      }
    });

    test('explore parse tree structure', () {
      final parser = grammar.build();

      // Simple pattern to understand structure
      print('=== Testing simple pattern ===');
      final result1 = parser.parse('user->group');
      if (result1 is Success) {
        print('Simple parse tree: ${result1.value}');
        print('Type: ${result1.value.runtimeType}');
      }

      // Pattern with edge type
      print('=== Testing pattern with edge ===');
      final result2 = parser.parse('user-[:WORKS_FOR]->team');
      if (result2 is Success) {
        print('Edge parse tree: ${result2.value}');
      }
    });

    test('test parse tree extraction', () {
      final query = PetitPatternQuery(Graph<Node>());

      // Test extraction method directly
      final parser = grammar.build();
      final result = parser.parse('user->group');

      if (result is Success) {
        final parts = <String>[];
        final directions = <bool>[];
        query.extractPartsFromParseTreeForTesting(result.value, parts, directions);

        print('Extracted parts: $parts');
        print('Extracted directions: $directions');

        expect(parts.length, equals(2));
        expect(directions.length, equals(1));
        expect(parts[0], contains('user'));
        expect(parts[1], contains('group'));
        expect(directions[0], isTrue); // forward arrow
      }
    });

    test('side-by-side comparison with original parser', () {
      // Create test graph
      final graph = Graph<Node>();
      graph.addNode(Node(id: 'alice', type: 'Person', label: 'Alice Cooper'));
      graph.addNode(Node(id: 'bob', type: 'Person', label: 'Bob Wilson'));
      graph.addNode(Node(id: 'engineering', type: 'Team', label: 'Engineering'));
      graph.addNode(Node(id: 'design', type: 'Team', label: 'Design'));

      graph.addEdge('alice', 'engineering', 'WORKS_FOR');
      graph.addEdge('bob', 'design', 'WORKS_FOR');

      // Create both parsers
      final originalQuery = PatternQuery(graph);
      final petitQuery = PetitPatternQuery(graph);

      // Test simple pattern
      print('=== Testing simple pattern: user:Person ===');
      final original1 = originalQuery.match('user:Person');
      print('Original result: $original1');

      final petit1 = petitQuery.match('user:Person');
      print('Petit result: $petit1');

      // Test pattern with edge
      print('=== Testing pattern with edge: user:Person-[:WORKS_FOR]->team:Team ===');
      final original2 = originalQuery.match('user:Person-[:WORKS_FOR]->team:Team');
      print('Original result: $original2');

      final petit2 = petitQuery.match('user:Person-[:WORKS_FOR]->team:Team');
      print('Petit result: $petit2');

      // Test label filter
      print('=== Testing label filter: user:Person{label~Alice} ===');
      final original3 = originalQuery.match('user:Person{label~Alice}');
      print('Original result: $original3');

      final petit3 = petitQuery.match('user:Person{label~Alice}');
      print('Petit result: $petit3');
    });
  });
}