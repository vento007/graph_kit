# Relationship Property TODO

GraphKit now supports storing relationship properties, inline `{...}` filters on concrete hops, `WHERE r.prop` filters, `RETURN r.prop` projections, and path-edge metadata. Remaining gaps before feature parity with Neo4j-like Cypher:

1. **Variable-Length Segments**
   - ✅ Inline `{...}` filters now work on `[:TYPE*...]` (including mixed directions and wildcards).
   - `WHERE r.prop` must either forbid variable-length edge variables or support a collection semantics (`ALL(r IN rels(path) WHERE ...)` equivalent).
   - `_executeVariableLengthSegment` still needs to surface concrete edge objects per hop so we can hydrate results (constraints are enforced now).
   - `matchPaths` should emit each hop’s `properties` for variable-length expansions.


note: • Variable-length inline filters now work end-to-end, so you can match [:TYPE*{k:v}] segments (forward/backward/wildcard) with edge-property constraints enforced at every hop. Tests (edge_properties_test.dart suite) pass locally, and the only suite failure left
  is the pre-existing duplicate-variable case.

  Still outstanding before we can call the feature complete:

  - WHERE r.prop on variable-length segments is still unsupported—we don’t collect the per-hop edge objects needed to evaluate something like WHERE r.weight > 5 when r spans multiple relationships.
  - matchPaths doesn’t yet expose edge metadata for variable-length segments; it still returns only node bindings, so users can’t inspect the actual edge properties from a PathMatch.
  - Docs/README haven’t been updated to advertise the new capability or explain the remaining limitations.

  So Stage 3 is done (execution support), but Stage 4 (docs/examples + clarifying the above gaps) remains, and we still owe work if we want WHERE/RETURN to behave like Neo4j for variable-length edge variables.


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
   - Document the remaining limitations (e.g., `WHERE r.prop` on variable-length segments, lack of edge metadata in `matchPaths`).

5. **Future Considerations**
   - Aggregations on relationship properties (`RETURN avg(r.weight)` once aggregations exist).
   - Bulk update helpers (e.g., `graph.updateEdgeProperties`).
   - Schema validation/hooks if we introduce typed edge property definitions.
