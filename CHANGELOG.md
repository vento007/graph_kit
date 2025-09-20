
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
