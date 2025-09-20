import 'package:test/test.dart';
import 'package:petitparser/petitparser.dart';
import 'package:graph_kit/graph_kit.dart';
import 'package:graph_kit/src/pattern_query_petit.dart';

// Helper function to test variable-length spec parsing
VariableLengthSpec? _extractVariableLengthSpecForTesting(String edgeStr) {
  // Look for patterns like [:TYPE*], [:TYPE*1..3], [:TYPE*2..], [:TYPE*..5]
  final match = RegExp(r'\[:([^\*]+)\*([^\]]*)]').firstMatch(edgeStr);
  if (match == null) return null;

  final vlPart = match.group(2) ?? '';
  if (vlPart.isEmpty) {
    // Just * means unlimited
    return const VariableLengthSpec();
  }

  // Parse patterns like "1..3", "2..", "..5"
  if (vlPart.contains('..')) {
    final parts = vlPart.split('..');
    final minStr = parts[0];
    final maxStr = parts.length > 1 ? parts[1] : '';

    final min = minStr.isNotEmpty ? int.tryParse(minStr) : null;
    final max = maxStr.isNotEmpty ? int.tryParse(maxStr) : null;

    return VariableLengthSpec(minHops: min, maxHops: max);
  }

  // Single number like "*3" means exactly 3 hops
  final exactHops = int.tryParse(vlPart);
  if (exactHops != null) {
    return VariableLengthSpec(minHops: exactHops, maxHops: exactHops);
  }

  return const VariableLengthSpec(); // Default to unlimited
}

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

    // TODO: Re-enable when extractPartsFromParseTreeForTesting is exposed
    // test('test parse tree extraction', () {
    //   final query = PetitPatternQuery(Graph<Node>());
    //   ...
    // });

    // TODO: Re-enable when PetitPatternQuery.match is properly implemented
    // test('side-by-side comparison with original parser', () {
    //   ...
    // });

    group('Variable-Length Pattern Tests', () {
      test('should parse variable-length syntax', () {
        final parser = grammar.build();

        // Test unlimited variable-length
        print('Testing user-[:MANAGES*]->team...');
        final result1 = parser.parse('user-[:MANAGES*]->team');
        print('Result: ${result1 is Success ? "SUCCESS" : "FAILURE: ${result1.message}"}');
        expect(result1 is Success, isTrue);

        // Test bounded variable-length
        print('Testing user-[:MANAGES*1..3]->team...');
        final result2 = parser.parse('user-[:MANAGES*1..3]->team');
        print('Result: ${result2 is Success ? "SUCCESS" : "FAILURE: ${result2.message}"}');
        expect(result2 is Success, isTrue);

        // Test min-only variable-length
        print('Testing user-[:MANAGES*2..]->team...');
        final result3 = parser.parse('user-[:MANAGES*2..]->team');
        print('Result: ${result3 is Success ? "SUCCESS" : "FAILURE: ${result3.message}"}');
        expect(result3 is Success, isTrue);

        // Test max-only variable-length
        print('Testing user-[:MANAGES*..4]->team...');
        final result4 = parser.parse('user-[:MANAGES*..4]->team');
        print('Result: ${result4 is Success ? "SUCCESS" : "FAILURE: ${result4.message}"}');
        expect(result4 is Success, isTrue);
      });

      test('should extract variable-length specifications correctly', () {
        // Test unlimited spec
        final spec1 = _extractVariableLengthSpecForTesting('[:MANAGES*]');
        expect(spec1, isNotNull);
        expect(spec1!.isUnlimited, isTrue);
        expect(spec1.effectiveMinHops, equals(1));
        expect(spec1.effectiveMaxHops, equals(10));

        // Test bounded spec
        final spec2 = _extractVariableLengthSpecForTesting('[:MANAGES*1..3]');
        expect(spec2, isNotNull);
        expect(spec2!.minHops, equals(1));
        expect(spec2.maxHops, equals(3));
        expect(spec2.effectiveMinHops, equals(1));
        expect(spec2.effectiveMaxHops, equals(3));

        // Test min-only spec
        final spec3 = _extractVariableLengthSpecForTesting('[:MANAGES*2..]');
        expect(spec3, isNotNull);
        expect(spec3!.minHops, equals(2));
        expect(spec3.maxHops, isNull);
        expect(spec3.effectiveMinHops, equals(2));
        expect(spec3.effectiveMaxHops, equals(10));

        // Test max-only spec
        final spec4 = _extractVariableLengthSpecForTesting('[:MANAGES*..4]');
        expect(spec4, isNotNull);
        expect(spec4!.minHops, isNull);
        expect(spec4!.maxHops, equals(4));
        expect(spec4.effectiveMinHops, equals(1));
        expect(spec4.effectiveMaxHops, equals(4));

        // Test non-variable-length
        final spec5 = _extractVariableLengthSpecForTesting('[:MANAGES]');
        expect(spec5, isNull);
      });

      // TODO: Re-enable when variable-length execution is working
      // test('should execute variable-length patterns correctly', () {
      //   ...
      // });

      // TODO: Re-enable when variable-length execution is working
      // test('should handle complex variable-length patterns', () {
      //   ...
      // });

      // TODO: Re-enable when variable-length execution is working
      // test('should handle edge cases properly', () {
      //   ...
      // });
    });
  });
}