
## 0.6.7

### Added
- **New reachability methods** in GraphAlgorithms:
  - `reachableBy()` - finds all nodes that can reach a target node (follows incoming edges)
  - `reachableAll()` - finds all nodes connected bidirectionally (follows both incoming and outgoing edges)
 
## 0.6.6

### Added
- **PetitParser implementation** - New experimental pattern query parser using PetitParser
- Side-by-side coexistence with original parser - both implementations available
- Comprehensive test suite ensuring 100% parity between parsers
- Demo app integration with PetitParser for testing

### Technical Details
- New `PetitPatternQuery` class in `src/pattern_query_petit.dart`
- Full support for all existing pattern syntax:
  - Node types and label filters
  - Forward and backward arrows
  - Multi-hop patterns
  - Complex nested queries
- Identical API to original `PatternQuery` for drop-in compatibility

### Notes
- Original `PatternQuery` remains the default implementation
- PetitParser implementation is experimental and subject to testing
- Future versions will transition to PetitParser as primary implementation
- No breaking changes to existing code

## 0.6.5

• Graph algorithms module with shortest path, connected components, reachability, and topological sort
• Interactive Flutter demo and command-line demo for graph algorithms

## 0.6.4

• Fix: bracket-aware pattern parsing and relaxed edge-type handling for special characters in `PatternQuery`.

## 0.6.3_+1

• Fix: changed topics for package SEO

## 0.6.2+1

• Fix: code formatting to meet pub.dev static analysis requirements

## 0.6.2

• Docs: rewrote README.md for clearer presentation and updated examples to use published package

## 0.6.1

• Fix: match() method now returns only connected nodes instead of all nodes of matching type

## 0.6.0

• Added PathMatch and PathEdge classes for complete path results with Neo4j-style edge information
• New matchPaths() and matchPathsMany() methods for full path traversal details

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
