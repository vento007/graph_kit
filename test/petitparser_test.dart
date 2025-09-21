import 'package:test/test.dart';
import 'package:petitparser/petitparser.dart';
import 'package:graph_kit/graph_kit.dart';

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
    //   final query = PatternQuery(Graph<Node>());
    //   ...
    // });

    // TODO: Re-enable when PatternQuery.match is properly implemented
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
        expect(spec4.maxHops, equals(4));
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

    group('WHERE clause tests', () {
      late Graph<Node> graph;
      late PatternQuery<Node> query;

      setUp(() {
        graph = Graph<Node>();
        query = PatternQuery(graph);

        // Create test data with properties
        graph.addNode(Node(
          id: 'alice',
          type: 'Person',
          label: 'Alice Cooper',
          properties: {'age': 28, 'department': 'Engineering', 'salary': 85000},
        ));
        graph.addNode(Node(
          id: 'bob',
          type: 'Person',
          label: 'Bob Wilson',
          properties: {'age': 35, 'department': 'Engineering', 'salary': 95000},
        ));
        graph.addNode(Node(
          id: 'carol',
          type: 'Person',
          label: 'Carol Davis',
          properties: {'age': 22, 'department': 'Marketing', 'salary': 60000},
        ));
        graph.addNode(Node(
          id: 'engineering',
          type: 'Team',
          label: 'Engineering',
          properties: {'size': 15, 'budget': 150000},
        ));
        graph.addNode(Node(
          id: 'marketing',
          type: 'Team',
          label: 'Marketing',
          properties: {'size': 8, 'budget': 80000},
        ));

        // Add relationships
        graph.addEdge('alice', 'WORKS_FOR', 'engineering');
        graph.addEdge('bob', 'WORKS_FOR', 'engineering');
        graph.addEdge('carol', 'WORKS_FOR', 'marketing');
      });

      test('should parse WHERE clause with property comparison', () {
        final grammar = CypherPatternGrammar();
        final parser = grammar.build();

        final result = parser.parse('MATCH person:Person WHERE person.age > 25');
        expect(result is Success, isTrue);
      });

      test('should filter by numeric property (greater than)', () {
        final results = query.matchRows('MATCH person:Person WHERE person.age > 25');

        expect(results.length, 2); // Alice (28) and Bob (35)
        final personIds = results.map((r) => r['person']).toSet();
        expect(personIds, containsAll(['alice', 'bob']));
        expect(personIds, isNot(contains('carol'))); // Carol is 22
      });

      test('should filter by string property (exact match)', () {
        final results = query.matchRows('MATCH person:Person WHERE person.department = "Engineering"');

        expect(results.length, 2); // Alice and Bob
        final personIds = results.map((r) => r['person']).toSet();
        expect(personIds, containsAll(['alice', 'bob']));
        expect(personIds, isNot(contains('carol'))); // Carol is in Marketing
      });

      test('should filter by numeric property (less than or equal)', () {
        final results = query.matchRows('MATCH person:Person WHERE person.salary <= 85000');

        expect(results.length, 2); // Alice (85000) and Carol (60000)
        final personIds = results.map((r) => r['person']).toSet();
        expect(personIds, containsAll(['alice', 'carol']));
        expect(personIds, isNot(contains('bob'))); // Bob has 95000
      });

      test('should handle AND logical operator', () {
        final results = query.matchRows(
          'MATCH person:Person WHERE person.age > 25 AND person.department = "Engineering"'
        );

        expect(results.length, 2); // Alice and Bob meet both criteria
        final personIds = results.map((r) => r['person']).toSet();
        expect(personIds, containsAll(['alice', 'bob']));
      });

      test('should handle OR logical operator', () {
        final results = query.matchRows(
          'MATCH person:Person WHERE person.age < 25 OR person.salary > 90000'
        );

        expect(results.length, 2); // Carol (age < 25) and Bob (salary > 90000)
        final personIds = results.map((r) => r['person']).toSet();
        expect(personIds, containsAll(['carol', 'bob']));
      });

      test('should work with relationship patterns and WHERE', () {
        final results = query.matchRows(
          'MATCH person:Person-[:WORKS_FOR]->team:Team WHERE person.age > 30'
        );

        expect(results.length, 1); // Only Bob (35) > 30
        expect(results[0]['person'], 'bob');
        expect(results[0]['team'], 'engineering');
      });

      test('should handle complex WHERE with multiple conditions', () {
        final results = query.matchRows(
          'MATCH person:Person WHERE person.age >= 25 AND person.age <= 30 AND person.department = "Engineering"'
        );

        expect(results.length, 1); // Only Alice (28) meets all criteria
        expect(results[0]['person'], 'alice');
      });

      test('should handle != (not equal) operator', () {
        final results = query.matchRows('MATCH person:Person WHERE person.department != "Marketing"');

        expect(results.length, 2); // Alice and Bob
        final personIds = results.map((r) => r['person']).toSet();
        expect(personIds, containsAll(['alice', 'bob']));
        expect(personIds, isNot(contains('carol')));
      });

      test('should return empty result when no matches', () {
        final results = query.matchRows('MATCH person:Person WHERE person.age > 100');
        expect(results, isEmpty);
      });

      test('should handle queries without WHERE clause (backward compatibility)', () {
        final results = query.matchRows('MATCH person:Person');
        expect(results.length, 3); // All three people
      });

      test('should handle missing properties gracefully', () {
        // Add node without age property
        graph.addNode(Node(
          id: 'david',
          type: 'Person',
          label: 'David Smith',
          properties: {'department': 'Sales'}, // No age property
        ));

        final results = query.matchRows('MATCH person:Person WHERE person.age > 25');

        // Should only return alice and bob (david has no age property)
        expect(results.length, 2);
        final personIds = results.map((r) => r['person']).toSet();
        expect(personIds, containsAll(['alice', 'bob']));
        expect(personIds, isNot(contains('david')));
      });

      test('should handle parentheses in WHERE clauses', () {
        // Add person who meets complex criteria
        graph.addNode(Node(
          id: 'senior',
          type: 'Person',
          label: 'Senior Manager',
          properties: {'age': 45, 'department': 'Management', 'salary': 150000},
        ));

        // Test parentheses parsing first
        final grammar = CypherPatternGrammar();
        final parser = grammar.build();
        final parseResult = parser.parse('MATCH person:Person WHERE (person.age > 40 AND person.salary > 100000) OR person.department = "Engineering"');
        expect(parseResult is! Failure, isTrue, reason: 'Parentheses should parse successfully');

        // Test the actual parentheses evaluation
        final results = query.matchRows('MATCH person:Person WHERE (person.age > 40 AND person.salary > 100000) OR person.department = "Engineering"');

        // Should return:
        // - 'senior' (age 45 > 40 AND salary 150000 > 100000)
        // - 'alice' (department = "Engineering")
        // - 'bob' (department = "Engineering")
        expect(results, hasLength(3));
        final personIds = results.map((r) => r['person']).toSet();
        expect(personIds, containsAll(['senior', 'alice', 'bob']));
      });

      test('should return empty result for invalid variable names in WHERE clause', () {
        // Test the bug fix: undefined variables should cause WHERE to fail
        final results = query.matchRows('MATCH paa:Person WHERE pwerwer.age > 70 AND person.department = "Management"');

        // Should return empty because:
        // 1. 'pwerwer' variable doesn't exist (should be 'paa')
        // 2. 'person' variable doesn't exist (should be 'paa')
        expect(results, isEmpty, reason: 'Invalid variable names should cause WHERE clause to fail');
      });

      test('should return empty result for non-existent variables', () {
        // Test individual cases of undefined variables
        final results1 = query.matchRows('MATCH person:Person WHERE nonexistent.age > 25');
        expect(results1, isEmpty, reason: 'Non-existent variable should cause WHERE to fail');

        final results2 = query.matchRows('MATCH person:Person WHERE person.nonexistent > 25');
        expect(results2, isEmpty, reason: 'Non-existent property should cause WHERE to fail');
      });

      test('should return empty result for malformed property syntax', () {
        // Test malformed property expressions
        final results1 = query.matchRows('MATCH person:Person WHERE invalidproperty > 25');
        expect(results1, isEmpty, reason: 'Property without dot should fail');

        final results2 = query.matchRows('MATCH person:Person WHERE .age > 25');
        expect(results2, isEmpty, reason: 'Property starting with dot should fail');

        final results3 = query.matchRows('MATCH person:Person WHERE person. > 25');
        expect(results3, isEmpty, reason: 'Property ending with dot should fail');
      });

      test('should properly validate variable names match pattern variables', () {
        // Test that WHERE variables must match pattern variables
        final results1 = query.matchRows('MATCH p:Person WHERE person.age > 25');
        expect(results1, isEmpty, reason: 'WHERE variable must match pattern variable (p vs person)');

        // Test correct usage
        final results2 = query.matchRows('MATCH p:Person WHERE p.age > 25');
        expect(results2.length, 2, reason: 'Correct variable matching should work');
        final personIds = results2.map((r) => r['p']).toSet();
        expect(personIds, containsAll(['alice', 'bob']));
      });

    });

  });
}