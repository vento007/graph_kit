
## 0.6.3

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
