# Relationship Property TODO

Relationship properties now support inline `{...}` filters, `WHERE r.prop`, `type(r)`, and `RETURN r.prop` for both fixed-length and variable-length segments (including `matchPaths`). The remaining gap is narrowly scoped:

1. **matchPaths + RETURN edge omissions**
   - Today, `matchPaths()` rebuilds `PathMatch.nodes` from the variables returned by the query. If a `RETURN` clause omits edge variables entirely, those variables—and their associated metadata—are not surfaced even though the underlying trace exists.
   - Explore a strategy to expose path-edge metadata (perhaps via a dedicated field on `PathMatch`) even when the user’s `RETURN` clause filters out the edge aliases. This would let callers keep their minimal node projections while still receiving the full edge list for visualization/layout tooling.

Everything else (parsing, planner metadata, execution, WHERE/RETURN behavior, matchPaths without RETURN filters, documentation, and tests) is complete. This TODO should shrink to zero once we decide how (or whether) to override the current “respect RETURN projection” rule for edge variables.
