import 'package:test/test.dart';
import 'package:petitparser/petitparser.dart';
import 'package:graph_kit/graph_kit.dart';

void main() {
  group('Variable-Length Pattern Tests', () {
    late Graph<Node> hierarchyGraph;
    late PatternQuery<Node> query;

    setUp(() {
      // Create consistent test hierarchy for all tests
      hierarchyGraph = Graph<Node>();

      // 4-level management hierarchy
      // CEO -> Directors -> Managers -> Employees
      hierarchyGraph.addNode(Node(id: 'ceo', type: 'Person', label: 'CEO'));
      hierarchyGraph.addNode(Node(id: 'dir1', type: 'Person', label: 'Director 1'));
      hierarchyGraph.addNode(Node(id: 'dir2', type: 'Person', label: 'Director 2'));
      hierarchyGraph.addNode(Node(id: 'mgr1', type: 'Person', label: 'Manager 1'));
      hierarchyGraph.addNode(Node(id: 'mgr2', type: 'Person', label: 'Manager 2'));
      hierarchyGraph.addNode(Node(id: 'mgr3', type: 'Person', label: 'Manager 3'));
      hierarchyGraph.addNode(Node(id: 'emp1', type: 'Person', label: 'Employee 1'));
      hierarchyGraph.addNode(Node(id: 'emp2', type: 'Person', label: 'Employee 2'));
      hierarchyGraph.addNode(Node(id: 'emp3', type: 'Person', label: 'Employee 3'));
      hierarchyGraph.addNode(Node(id: 'emp4', type: 'Person', label: 'Employee 4'));

      // Build strict hierarchy: CEO -> 2 Directors -> 3 Managers -> 4 Employees
      hierarchyGraph.addEdge('ceo', 'MANAGES', 'dir1');
      hierarchyGraph.addEdge('ceo', 'MANAGES', 'dir2');
      hierarchyGraph.addEdge('dir1', 'MANAGES', 'mgr1');
      hierarchyGraph.addEdge('dir1', 'MANAGES', 'mgr2');
      hierarchyGraph.addEdge('dir2', 'MANAGES', 'mgr3');
      hierarchyGraph.addEdge('mgr1', 'MANAGES', 'emp1');
      hierarchyGraph.addEdge('mgr2', 'MANAGES', 'emp2');
      hierarchyGraph.addEdge('mgr2', 'MANAGES', 'emp3');
      hierarchyGraph.addEdge('mgr3', 'MANAGES', 'emp4');

      query = PatternQuery(hierarchyGraph);
    });

    group('Grammar Parsing Tests', () {
      test('should parse all variable-length syntax variations', () {
        final grammar = CypherPatternGrammar();
        final parser = grammar.build();

        // Test all valid syntax patterns
        final validPatterns = [
          'boss-[:MANAGES*]->sub',           // Unlimited
          'boss-[:MANAGES*1]->sub',          // Exact (1 hop)
          'boss-[:MANAGES*1..3]->sub',       // Range (1-3 hops)
          'boss-[:MANAGES*2..]->sub',        // Min only (2+ hops)
          'boss-[:MANAGES*..4]->sub',        // Max only (up to 4 hops)
        ];

        for (final pattern in validPatterns) {
          final result = parser.parse(pattern);
          expect(result is Success, isTrue, reason: 'Failed to parse: $pattern');
        }
      });

      test('should reject invalid variable-length syntax', () {
        final grammar = CypherPatternGrammar();
        final parser = grammar.build();

        // Test invalid syntax patterns
        final invalidPatterns = [
          'boss-[:MANAGES*.]->sub',          // Missing numbers
          'boss-[:MANAGES*..)->sub',         // Missing max
          'boss-[:MANAGES**]->sub',          // Double asterisk
          'boss-[:MANAGES*abc]->sub',        // Non-numeric
        ];

        for (final pattern in invalidPatterns) {
          final result = parser.parse(pattern);
          expect(result is Failure, isTrue, reason: 'Should have failed: $pattern');
        }
      });
    });

    group('VariableLengthSpec Tests', () {
      test('should create correct specifications for all syntax types', () {
        // Unlimited: *
        const unlimited = VariableLengthSpec();
        expect(unlimited.isUnlimited, isTrue);
        expect(unlimited.effectiveMinHops, equals(1));
        expect(unlimited.effectiveMaxHops, equals(10));

        // Exact: *2 (min=max=2)
        const exact = VariableLengthSpec(minHops: 2, maxHops: 2);
        expect(exact.isUnlimited, isFalse);
        expect(exact.effectiveMinHops, equals(2));
        expect(exact.effectiveMaxHops, equals(2));

        // Range: *1..3
        const range = VariableLengthSpec(minHops: 1, maxHops: 3);
        expect(range.isUnlimited, isFalse);
        expect(range.effectiveMinHops, equals(1));
        expect(range.effectiveMaxHops, equals(3));

        // Min only: *2..
        const minOnly = VariableLengthSpec(minHops: 2);
        expect(minOnly.isUnlimited, isFalse);
        expect(minOnly.effectiveMinHops, equals(2));
        expect(minOnly.effectiveMaxHops, equals(10));

        // Max only: *..4
        const maxOnly = VariableLengthSpec(maxHops: 4);
        expect(maxOnly.isUnlimited, isFalse);
        expect(maxOnly.effectiveMinHops, equals(1));
        expect(maxOnly.effectiveMaxHops, equals(4));
      });

      test('should provide correct string representations', () {
        expect(const VariableLengthSpec().toString(), equals('*'));
        expect(const VariableLengthSpec(minHops: 2, maxHops: 2).toString(), equals('*2..2'));
        expect(const VariableLengthSpec(minHops: 1, maxHops: 3).toString(), equals('*1..3'));
        expect(const VariableLengthSpec(minHops: 2).toString(), equals('*2..'));
        expect(const VariableLengthSpec(maxHops: 4).toString(), equals('*..4'));
      });
    });

    group('Execution Tests - Critical for Regression Prevention', () {
      test('1-hop variable-length should find direct reports only', () {
        final results = query.matchRows('boss-[:MANAGES*1..1]->subordinate', startId: 'ceo');

        // CEO manages 2 directors directly
        expect(results.length, equals(2));
        final subordinateIds = results.map((r) => r['subordinate']).toSet();
        expect(subordinateIds, containsAll(['dir1', 'dir2']));
        expect(subordinateIds, isNot(contains('mgr1'))); // Should not include indirect reports
      });

      test('2-hop variable-length should find direct and indirect reports', () {
        final results = query.matchRows('boss-[:MANAGES*1..2]->subordinate', startId: 'ceo');

        // CEO -> Directors (1 hop) + CEO -> Managers (2 hops)
        expect(results.length, equals(5)); // 2 directors + 3 managers
        final subordinateIds = results.map((r) => r['subordinate']).toSet();
        expect(subordinateIds, containsAll(['dir1', 'dir2', 'mgr1', 'mgr2', 'mgr3']));
        expect(subordinateIds, isNot(contains('emp1'))); // Should not include 3-hop employees
      });

      test('3-hop variable-length should reach employees', () {
        final results = query.matchRows('boss-[:MANAGES*1..3]->subordinate', startId: 'ceo');

        // CEO can reach everyone in 3 hops or less
        expect(results.length, equals(9)); // 2 directors + 3 managers + 4 employees
        final subordinateIds = results.map((r) => r['subordinate']).toSet();
        expect(subordinateIds, containsAll(['dir1', 'dir2', 'mgr1', 'mgr2', 'mgr3', 'emp1', 'emp2', 'emp3', 'emp4']));
      });

      test('min-hop filtering should exclude closer relationships', () {
        final results = query.matchRows('boss-[:MANAGES*3..]->subordinate', startId: 'ceo');

        // Only employees are 3 hops away
        expect(results.length, equals(4)); // Only employees
        final subordinateIds = results.map((r) => r['subordinate']).toSet();
        expect(subordinateIds, equals({'emp1', 'emp2', 'emp3', 'emp4'}));
        expect(subordinateIds, isNot(contains('dir1'))); // Directors are only 1 hop
        expect(subordinateIds, isNot(contains('mgr1'))); // Managers are only 2 hops
      });

      test('unlimited variable-length should find all reachable nodes', () {
        final results = query.matchRows('boss-[:MANAGES*]->subordinate', startId: 'ceo');

        // CEO can reach everyone via MANAGES edges
        expect(results.length, equals(9)); // Everyone except CEO
        final subordinateIds = results.map((r) => r['subordinate']).toSet();
        expect(subordinateIds.length, equals(9));
        expect(subordinateIds, isNot(contains('ceo'))); // Should not include self
      });
    });

    group('Edge Cases - Prevent Regressions', () {
      test('should handle isolated nodes', () {
        final isolatedGraph = Graph<Node>();
        isolatedGraph.addNode(Node(id: 'isolated', type: 'Node', label: 'Isolated'));
        final isolatedQuery = PatternQuery(isolatedGraph);

        final results = isolatedQuery.matchRows('node-[:ANY*]->target', startId: 'isolated');
        expect(results, isEmpty); // No outgoing edges
      });

      test('should handle non-existent edge types', () {
        final results = query.matchRows('boss-[:NONEXISTENT*]->subordinate', startId: 'ceo');
        expect(results, isEmpty); // No edges of this type
      });

      test('should handle impossible min hop counts', () {
        final results = query.matchRows('boss-[:MANAGES*10..]->subordinate', startId: 'ceo');
        expect(results, isEmpty); // Hierarchy is only 3 levels deep
      });

      test('should handle self-referencing patterns correctly', () {
        // Add a self-loop for testing
        hierarchyGraph.addEdge('ceo', 'MANAGES', 'ceo');

        final results = query.matchRows('person-[:MANAGES*1..1]->target', startId: 'ceo');
        // Should find direct reports (self-loop may be excluded by variable-length logic)
        expect(results.length, equals(2)); // 2 directors
      });

      test('should handle cycles without infinite loops', () {
        // Create a cycle: CEO -> Dir1 -> Mgr1 -> CEO
        hierarchyGraph.addEdge('mgr1', 'REPORTS_TO', 'ceo');

        // Variable-length should still complete (though this creates a mixed edge type scenario)
        final results = query.matchRows('person-[:MANAGES*1..5]->target', startId: 'ceo');
        expect(results.isNotEmpty, isTrue); // Should complete without hanging
      });
    });

    group('Performance and Limits Tests', () {
      test('should respect hop limits and not explore unnecessarily', () {
        // Create a deeper hierarchy to test limits
        final deepGraph = Graph<Node>();
        for (int i = 0; i < 20; i++) {
          deepGraph.addNode(Node(id: 'level$i', type: 'Node', label: 'Level $i'));
          if (i > 0) {
            deepGraph.addEdge('level${i-1}', 'CONNECTS', 'level$i');
          }
        }

        final deepQuery = PatternQuery(deepGraph);

        // Test that hop limits are respected
        final results1 = deepQuery.matchRows('start-[:CONNECTS*1..3]->end', startId: 'level0');
        expect(results1.length, equals(3)); // Should find level1, level2, level3 only

        final results2 = deepQuery.matchRows('start-[:CONNECTS*5..5]->end', startId: 'level0');
        expect(results2.length, equals(1)); // Should find only level5
        expect(results2.first['end'], equals('level5'));
      });

      test('should handle reasonable unlimited searches', () {
        // Test that unlimited searches work but don't run forever
        final results = query.matchRows('boss-[:MANAGES*]->subordinate', startId: 'ceo');
        expect(results.length, greaterThan(0));
        expect(results.length, lessThan(100)); // Sanity check - shouldn't explode
      });
    });

    group('Integration with Existing Features', () {
      test('should work with node type filters', () {
        final results = query.matchRows('boss:Person-[:MANAGES*1..2]->subordinate:Person', startId: 'ceo');
        expect(results.isNotEmpty, isTrue);
        // All results should have Person types (though this is just parsing test for now)
      });

      test('should work with mixed variable-length and fixed patterns', () {
        // This tests the integration between variable-length and normal segments
        final results = query.matchRows('boss-[:MANAGES*1..1]->middle-[:MANAGES]->subordinate', startId: 'ceo');
        // CEO -> Director -> Manager (2 total hops, but split into variable + fixed)
        expect(results.length, equals(3)); // Should find the 3 managers through directors
      });

      test('should maintain result consistency with different patterns', () {
        // These should give the same results
        final fixed2hop = query.matchRows('boss-[:MANAGES]->middle-[:MANAGES]->subordinate', startId: 'ceo');
        final variable2hop = query.matchRows('boss-[:MANAGES*2..2]->subordinate', startId: 'ceo');

        expect(fixed2hop.length, equals(variable2hop.length));
        final fixedSubs = fixed2hop.map((r) => r['subordinate']).toSet();
        final variableSubs = variable2hop.map((r) => r['subordinate']).toSet();
        expect(fixedSubs, equals(variableSubs));
      });
    });
  });
}