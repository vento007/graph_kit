import 'package:test/test.dart';
import 'package:petitparser/petitparser.dart';
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
        final context = complexPattern.substring(0, result.position) + ' <-- HERE --> ' + complexPattern.substring(result.position);
        print('Context: $context');
      }
    });
  });
}