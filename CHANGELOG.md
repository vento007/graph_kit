## 0.7.6

- **GraphLayout API**: Automatic layer/column computation for graph visualizations
  - Eliminates hardcoded column positioning (`computeLayout()` on path results)
  - Provides `nodeDepths` (structural positioning) and `variableDepths` (grouped positioning)
  - Three strategies: `pattern`, `longestPath`, `topological`
  - Handles cycles, orphan nodes, disconnected components automatically
  - 13 comprehensive tests including diamonds, cycles, and mixed directions

## 0.7.5

- **startId middle element support**: `startId` now matches ANY position in patterns (e.g., `matchPaths('a->b->c', startId: 'b')` now works)
- Added optional `startType` parameter to optimize performance when starting from middle elements
- Fixed PathMatch edge tracking bug in complex mixed-direction patterns
- 12 comprehensive tests including 8-hop chains and mixed directions with middle-start
- Backward compatible - no breaking API changes
- Added backend integration tests for JSON serialization round-trip and format documentation

## 0.7.4

### Added
- **RETURN clause support**: Project specific variables and properties from query results
  - Variable projection: `RETURN person, team`
  - Property access: `RETURN person.name, team.size`
  - AS aliasing: `RETURN person.name AS displayName, person.age AS years`
  - Works with WHERE filtering, variable-length paths, multiple edge types, and mixed directions

## 0.7.3

### Fixed
- **Parser whitespace handling**: Added support for optional whitespace within edge type brackets (e.g., `[ : TYPE ]`, `[ :TYPE ]`)

## 0.7.2

### Documentation
- **Mixed direction patterns**: Documented support for combining forward/backward relationships (e.g., `person1->team<-manager`)
- Added comprehensive test suite (24 tests) and examples to CYPHER_GUIDE.md
- Added demo queries to Flutter example app

## 0.7.1

### Added
- **Multiple edge types support**: Use `[:TYPE1|TYPE2|TYPE3]` syntax to match ANY of the specified relationship types
- OR semantics for edge type matching - matches if any edge type exists
- Works seamlessly with variable-length paths: `-[:TYPE1|TYPE2*1..3]->`
- Works with forward, backward, and multi-hop patterns
- Comprehensive test suite with 15 test cases covering all integration scenarios
- Updated documentation with examples in README and complete guide in CYPHER_GUIDE.md

### Features
- Cypher-compliant syntax using `|` separator for multiple types
- Efficient execution using set unions for neighbor collection
- Proper edge type detection in PathMatch results
- Full integration with existing WHERE clauses, variable-length paths, and label filtering

### Documentation
- Added "Multiple Edge Types" section to CYPHER_GUIDE.md
- Updated Cypher comparison table in README.md
- Added pattern query examples demonstrating OR syntax

## 0.7.0

### Breaking Changes
- **Unified parser implementation**: PatternQuery now uses PetitParser implementation by default
- **All advanced features now available**: WHERE clauses, variable-length paths, and parentheses support are now part of the main PatternQuery class
- **Enhanced functionality**: The main PatternQuery class now includes all features previously available only in PetitPatternQuery

### Major Improvements
- **Single parser implementation**: Removed duplicate parser implementations for better maintainability
- **Full Cypher feature set**: All Cypher-like features (WHERE, variable-length, parentheses) are now unified
- **Better performance**: Grammar-based parsing with proper parse tree evaluation
- **Future-ready architecture**: Solid foundation for additional Cypher features

### Migration Notes
- **API compatibility**: All existing PatternQuery usage remains the same - no code changes needed
- **Enhanced capabilities**: Your existing code now automatically gets WHERE clause and variable-length path support
- **Import changes**: Remove any direct imports of `pattern_query_petit.dart` - use main library export instead

### Technical Details
- Replaced string-based parsing with proper PetitParser grammar
- Unified PathEdge and PathMatch classes
- Complete test suite validation with 149+ passing tests
- All utility methods preserved and enhanced

## 0.6.11

### Added
- **Complete WHERE clause support with parentheses** in PetitParser implementation
- Full Cypher-style property filtering: `WHERE person.age > 30 AND person.salary >= 90000`
- Logical operators with proper precedence: `AND`, `OR`
- **Parentheses support for complex expressions**: `WHERE (A AND B) OR (C AND D)`
- **Multiple parentheses groups**: `WHERE (condition1 AND condition2) OR (condition3 AND condition4)`
- Property comparisons with all operators: `>`, `<`, `>=`, `<=`, `=`, `!=`
- String and numeric value support in WHERE conditions
- Comprehensive test suite with 13 WHERE clause test cases including parentheses
- **Enhanced Flutter demo** with parentheses examples and real-world query scenarios

### Features
- **Backward compatibility**: MATCH keyword is optional for existing patterns
- **Type safety**: Proper property value parsing and comparison
- **Error handling**: Graceful handling of missing properties and parse failures
- **Performance**: Efficient parse tree evaluation for complex nested expressions

### Documentation
- **Complete Cypher Guide** (`CYPHER_GUIDE.md`) documenting all supported features

### Note
- WHERE clause features are only available in PetitParser implementation
- All existing functionality remains unchanged and fully backward compatible

## 0.6.10

### Added
- Variable-length path support in PetitParser implementation
- Support for Cypher-style variable-length relationships: `[:TYPE*]`, `[:TYPE*1..3]`, `[:TYPE*2..]`, `[:TYPE*..4]`
- Comprehensive grammar parsing for all variable-length syntax variations
- Integration with existing `enumeratePaths` function for efficient variable-length execution

### Note
- Variable-length paths are only supported in PetitParser, not the original PatternQuery
- The PetitParser will become the default parser in a future release 

## 0.6.9

### Added
- Path enumeration utility to find all routes between nodes within hop limits

## 0.6.8

### Added
- Betweenness centrality algorithm to identify critical bridge nodes
- Closeness centrality algorithm to find communication hubs

## 0.6.7

### Added
- New reachability methods in GraphAlgorithms
- reachableBy() method finds all nodes that can reach a target node
- reachableAll() method finds all nodes connected bidirectionally

## 0.6.6

### Added
- PetitParser implementation as experimental alternative to original parser
- 100% parity testing between parser implementations

## 0.6.5

### Added
- Graph algorithms module with shortest path, connected components, reachability, and topological sort
- Interactive Flutter demo and command-line demo for graph algorithms

## 0.6.4

### Fixed
- Bracket-aware pattern parsing and relaxed edge-type handling for special characters in PatternQuery

## 0.6.3+1

### Fixed
- Changed topics for package SEO

## 0.6.2+1

### Fixed
- Code formatting to meet pub.dev static analysis requirements

## 0.6.2

### Changed
- Rewrote README.md for clearer presentation and updated examples to use published package

## 0.6.1

### Fixed
- match() method now returns only connected nodes instead of all nodes of matching type

## 0.6.0

### Added
- PathMatch and PathEdge classes for complete path results with Neo4j-style edge information
- matchPaths() and matchPathsMany() methods for full path traversal details

## 0.5.2

• Example: improved graph demo with better edge routing, layout, and UX

## 0.5.1

• Docs: README images switched to raw.githubusercontent URLs so they render on GitHub and pub.dev
• Example: lint tidy-ups and minor UI polish (debugPrint, interpolation, withValues)

## 0.5.0

* Initial release of graph_kit (formerly graph_traverse)
* Lightweight in-memory graph with typed nodes and edges
* Cypher-inspired pattern query engine for graph traversal
* Support for directional edges and complex pattern matching
* Row-wise pattern results for preserving path bindings
* Generic traversal utilities with BFS-style expansions
* Pure Dart implementation with no external dependencies
