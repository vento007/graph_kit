# Relationship Property TODO

GraphKit now supports storing relationship properties, inline `{...}` filters on concrete hops, `WHERE r.prop` filters, `RETURN r.prop` projections, and path-edge metadata. Remaining gaps before feature parity with Neo4j-like Cypher:

1. **Variable-Length Segments**
   - Inline `{...}` filters currently throw when attached to `[:TYPE*...]`.
   - `WHERE r.prop` must either forbid variable-length edge variables or support a collection semantics (`ALL(r IN rels(path) WHERE ...)` equivalent).
   - `_executeVariableLengthSegment` needs to carry edge objects per hop and enforce constraints during DFS/BFS.
   - `matchPaths` should emit each hop’s `properties` for variable-length expansions.

2. **OPTIONAL/MULTI MATCH**
   - Still using `matchMany` as a stand-in.
   - Once we support real `OPTIONAL MATCH`, ensure relationship-property projections survive null-padding rows.

3. **Cypher Mutations**
   - No `CREATE`/`MERGE`/`SET` commands for relationship properties (must call `graph.addEdge`).
   - Document how to update properties programmatically (`graph.addEdge` with new map overwrites the existing edge’s metadata).

4. **Docs + Examples**
   - README/Cypher guide must show:
     - How to add relationship properties (`graph.addEdge(... properties: {...})`).
     - Inline filter examples: `MATCH a-[r:KNOWS {strength: 80}]->b`.
     - `WHERE r.prop` / `RETURN r.prop`.
     - Path results showing edge metadata.
   - Call out the current limitation: relationship properties are ignored for variable-length segments.

5. **Future Considerations**
   - Aggregations on relationship properties (`RETURN avg(r.weight)` once aggregations exist).
   - Bulk update helpers (e.g., `graph.updateEdgeProperties`).
   - Schema validation/hooks if we introduce typed edge property definitions.
