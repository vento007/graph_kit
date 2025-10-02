import 'package:graph_kit/src/cypher_grammar.dart';
import 'package:petitparser/petitparser.dart';
import 'package:test/test.dart';

/// Test suite for RETURN clause - Grammar/Parser Tests
///
/// Tests PetitParser grammar for RETURN clause parsing.
/// Validates syntax recognition, error handling, and parse tree structure.
void main() {
  group('RETURN Grammar Parsing', () {
    late Parser parser;

    setUp(() {
      final grammar = CypherPatternGrammar();
      parser = grammar.build();
    });

    group('Basic RETURN Syntax', () {
      test('should parse simple RETURN with single variable', () {
        final result = parser.parse('MATCH person:Person RETURN person');
        expect(result is Success, isTrue);
      });

      test('should parse RETURN with two variables', () {
        final result = parser.parse('MATCH person-[:WORKS_FOR]->team RETURN person, team');
        expect(result is Success, isTrue);
      });

      test('should parse RETURN with three variables', () {
        final result = parser.parse('MATCH a->b->c RETURN a, b, c');
        expect(result is Success, isTrue);
      });

      test('should parse RETURN without MATCH keyword', () {
        final result = parser.parse('person:Person RETURN person');
        expect(result is Success, isTrue);
      });

      test('should parse RETURN at end of pattern', () {
        final result = parser.parse('person:Person-[:WORKS_FOR]->team:Team RETURN person');
        expect(result is Success, isTrue);
      });
    });

    group('Property Access Syntax', () {
      test('should parse RETURN with single property', () {
        final result = parser.parse('MATCH person:Person RETURN person.name');
        expect(result is Success, isTrue);
      });

      test('should parse RETURN with multiple properties', () {
        final result = parser.parse('MATCH person:Person RETURN person.name, person.age');
        expect(result is Success, isTrue);
      });

      test('should parse RETURN with properties from different variables', () {
        final result = parser.parse('MATCH person-[:WORKS_FOR]->team RETURN person.name, team.size');
        expect(result is Success, isTrue);
      });

      test('should parse mix of variable and property', () {
        final result = parser.parse('MATCH person:Person RETURN person, person.name');
        expect(result is Success, isTrue);
      });

      test('should parse complex property paths', () {
        final result = parser.parse('MATCH a->b->c RETURN a.prop1, b.prop2, c.prop3');
        expect(result is Success, isTrue);
      });
    });

    group('AS Alias Syntax', () {
      test('should parse simple AS alias', () {
        final result = parser.parse('MATCH person:Person RETURN person AS userId');
        expect(result is Success, isTrue);
      });

      test('should parse property with AS alias', () {
        final result = parser.parse('MATCH person:Person RETURN person.name AS displayName');
        expect(result is Success, isTrue);
      });

      test('should parse multiple AS aliases', () {
        final result = parser.parse('MATCH person:Person RETURN person.name AS name, person.age AS years');
        expect(result is Success, isTrue);
      });

      test('should parse mix of aliased and non-aliased', () {
        final result = parser.parse('MATCH person:Person RETURN person, person.name AS displayName');
        expect(result is Success, isTrue);
      });

      test('should handle AS with case variations', () {
        // Test if 'as' (lowercase) works
        final result = parser.parse('MATCH person:Person RETURN person.name as displayName');
        // Define if AS should be case-sensitive
        expect(result is Success, isTrue);
      });
    });

    group('RETURN with WHERE', () {
      test('should parse RETURN after WHERE clause', () {
        final result = parser.parse('MATCH person:Person WHERE person.age > 30 RETURN person');
        expect(result is Success, isTrue);
      });

      test('should parse complex WHERE before RETURN', () {
        final result = parser.parse(
          'MATCH person:Person WHERE person.age > 30 AND person.department = "Engineering" RETURN person.name',
        );
        expect(result is Success, isTrue);
      });

      test('should parse RETURN with properties after WHERE', () {
        final result = parser.parse(
          'MATCH person-[:WORKS_FOR]->team WHERE person.active = true RETURN person.name, team.name',
        );
        expect(result is Success, isTrue);
      });

      test('should parse WHERE with parentheses before RETURN', () {
        final result = parser.parse(
          'MATCH person:Person WHERE (person.age > 40 AND person.salary > 100000) OR person.department = "Management" RETURN person.name',
        );
        expect(result is Success, isTrue);
      });
    });

    group('Whitespace Handling', () {
      test('should handle extra spaces around RETURN', () {
        final result = parser.parse('MATCH person:Person    RETURN    person');
        expect(result is Success, isTrue);
      });

      test('should handle extra spaces around commas', () {
        final result = parser.parse('MATCH person:Person RETURN person.name  ,  person.age');
        expect(result is Success, isTrue);
      });

      test('should handle extra spaces around AS', () {
        final result = parser.parse('MATCH person:Person RETURN person.name    AS    displayName');
        expect(result is Success, isTrue);
      });

      test('should handle newlines in RETURN clause', () {
        final result = parser.parse('''
          MATCH person:Person
          RETURN person.name,
                 person.age
        ''');
        expect(result is Success, isTrue);
      });

      test('should handle tabs', () {
        final result = parser.parse('MATCH\tperson:Person\tRETURN\tperson.name');
        expect(result is Success, isTrue);
      });

      test('should handle minimal spacing', () {
        final result = parser.parse('MATCH person:Person RETURN person.name,person.age');
        expect(result is Success, isTrue);
      });
    });

    group('Complex Pattern Integration', () {
      test('should parse RETURN with variable-length paths', () {
        final result = parser.parse('MATCH person-[:MANAGES*1..3]->subordinate RETURN person, subordinate');
        expect(result is Success, isTrue);
      });

      test('should parse RETURN with multiple edge types', () {
        final result = parser.parse('MATCH person-[:WORKS_FOR|MANAGES]->org RETURN person.name, org.name');
        expect(result is Success, isTrue);
      });

      test('should parse RETURN with mixed directions', () {
        final result = parser.parse('MATCH person1->team<-person2 RETURN person1.name, person2.name');
        expect(result is Success, isTrue);
      });

      test('should parse RETURN with label filtering', () {
        final result = parser.parse('MATCH person:Person{label~Admin} RETURN person.name');
        expect(result is Success, isTrue);
      });

      test('should parse very long pattern with RETURN', () {
        final result = parser.parse(
          'MATCH a->b->c->d->e->f RETURN a.p1, b.p2, c.p3, d.p4, e.p5, f.p6',
        );
        expect(result is Success, isTrue);
      });
    });

    group('Error Cases - Should Fail', () {
      test('should fail on RETURN without items', () {
        final result = parser.parse('MATCH person:Person RETURN');
        expect(result is Failure, isTrue);
      });

      test('should fail on trailing comma in RETURN', () {
        final result = parser.parse('MATCH person:Person RETURN person.name,');
        expect(result is Failure, isTrue);
      });

      test('should fail on double comma', () {
        final result = parser.parse('MATCH person:Person RETURN person.name,, person.age');
        expect(result is Failure, isTrue);
      });

      test('should fail on AS without alias name', () {
        final result = parser.parse('MATCH person:Person RETURN person.name AS');
        expect(result is Failure, isTrue);
      });

      test('should fail on AS without value', () {
        final result = parser.parse('MATCH person:Person RETURN AS displayName');
        expect(result is Failure, isTrue);
      });

      test('should fail on invalid property syntax', () {
        final result = parser.parse('MATCH person:Person RETURN person..name');
        expect(result is Failure, isTrue);
      });

      test('should fail on missing variable before dot', () {
        final result = parser.parse('MATCH person:Person RETURN .name');
        expect(result is Failure, isTrue);
      });
    });

    group('Parse Tree Structure', () {
      test('should produce valid parse tree for simple RETURN', () {
        final result = parser.parse('MATCH person:Person RETURN person');
        expect(result is Success, isTrue);
        expect(result.value, isNotNull);
        // Parse tree should be extractable
      });

      test('should produce parse tree with property access', () {
        final result = parser.parse('MATCH person:Person RETURN person.name');
        expect(result is Success, isTrue);
        // Should contain property access info in tree
      });

      test('should produce parse tree with aliases', () {
        final result = parser.parse('MATCH person:Person RETURN person.name AS displayName');
        expect(result is Success, isTrue);
        // Should contain alias info in tree
      });

      test('should handle multiple RETURN items in parse tree', () {
        final result = parser.parse('MATCH person:Person RETURN person.name, person.age, person.email');
        expect(result is Success, isTrue);
        // Should parse all three items
      });
    });

    group('Edge Cases', () {
      test('should parse RETURN with single character variable', () {
        final result = parser.parse('MATCH a:Person RETURN a');
        expect(result is Success, isTrue);
      });

      test('should parse RETURN with long variable names', () {
        final result = parser.parse(
          'MATCH veryLongVariableName:Person RETURN veryLongVariableName.veryLongPropertyName',
        );
        expect(result is Success, isTrue);
      });

      test('should parse RETURN with underscores in names', () {
        final result = parser.parse('MATCH my_person:Person RETURN my_person.first_name AS full_name');
        expect(result is Success, isTrue);
      });

      test('should parse RETURN with numbers in variable names', () {
        final result = parser.parse('MATCH person1:Person RETURN person1.name AS name1');
        expect(result is Success, isTrue);
      });

      test('should handle complex nested patterns', () {
        final result = parser.parse(
          'MATCH (person1:Person{label~Admin})-[:MANAGES*1..2]->(person2:Person) WHERE person2.age > 25 RETURN person1.name AS manager, person2.name AS employee',
        );
        // May or may not support parentheses - define expected behavior
      });
    });

    group('Backwards Compatibility', () {
      test('should parse patterns without RETURN clause', () {
        final result = parser.parse('MATCH person:Person-[:WORKS_FOR]->team:Team');
        expect(result is Success, isTrue);
      });

      test('should parse bare patterns without MATCH or RETURN', () {
        final result = parser.parse('person:Person-[:WORKS_FOR]->team:Team');
        expect(result is Success, isTrue);
      });

      test('should parse WHERE without RETURN', () {
        final result = parser.parse('MATCH person:Person WHERE person.age > 30');
        expect(result is Success, isTrue);
      });
    });

    group('Real-World Query Patterns', () {
      test('should parse employee query', () {
        final result = parser.parse(
          'MATCH employee:Person-[:WORKS_FOR]->department:Team WHERE employee.active = true RETURN employee.name AS name, employee.email AS email, department.name AS dept',
        );
        expect(result is Success, isTrue);
      });

      test('should parse org hierarchy query', () {
        final result = parser.parse(
          'MATCH manager-[:MANAGES*1..3]->subordinate WHERE manager.department = "Engineering" RETURN manager.name, subordinate.name, subordinate.level',
        );
        expect(result is Success, isTrue);
      });

      test('should parse project assignment query', () {
        final result = parser.parse(
          'MATCH person-[:WORKS_FOR]->team-[:WORKS_ON]->project WHERE project.status = "active" RETURN person.name AS developer, project.name AS projectName',
        );
        expect(result is Success, isTrue);
      });
    });
  });
}
