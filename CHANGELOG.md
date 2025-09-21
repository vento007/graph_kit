
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
