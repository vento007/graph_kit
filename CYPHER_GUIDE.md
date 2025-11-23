# GraphKit Cypher Query Language Guide

GraphKit now includes full WHERE clause support as part of the unified PatternQuery implementation. All features in this guide are available by default.

GraphKit implements a powerful subset of the Cypher query language for graph pattern matching and filtering. This guide covers all supported features with practical examples.

## Table of Contents
- [Basic Pattern Matching](#basic-pattern-matching)
- [Node Types and Labels](#node-types-and-labels)
- [Relationships and Edges](#relationships-and-edges)
- [Relationship Properties](#relationship-properties)
- [Multiple Edge Types](#multiple-edge-types)
- [Mixed Direction Patterns](#mixed-direction-patterns)
- [Variable-Length Paths](#variable-length-paths)
- [WHERE Clause Filtering](#where-clause-filtering)
- [Logical Operators](#logical-operators)
- [Parentheses and Precedence](#parentheses-and-precedence)
- [Property Comparisons](#property-comparisons)
- [Edge Variable Comparison](#edge-variable-comparison)
- [RETURN Clause - Property Projection](#return-clause---property-projection)
- [Advanced Examples](#advanced-examples)

## Basic Pattern Matching

GraphKit supports both bare patterns and full MATCH syntax:

```cypher
# Bare pattern (shorthand)
user:User

# Full MATCH syntax
MATCH user:User
```

### Simple Node Patterns
```cypher
# Find all Person nodes
MATCH person:Person

# Find all nodes with variable name 'user'
MATCH user

# Find nodes by ID (when used with startIds parameter)
MATCH person:Person
```

## Starting from Specific Nodes

### Multiple Starting Nodes (startIds)

The `startIds` parameter lets you start pattern matching from multiple nodes simultaneously, making it perfect for search results or batch queries:

```cypher
# Start from multiple people
query.match('person-[:WORKS_FOR]->team', startIds: ['alice', 'bob', 'charlie'])
# Matches paths from any of the specified people

# Start from multiple teams
query.match('person-[:WORKS_FOR]->team', startIds: ['engineering', 'design'])
# Matches paths where team is engineering OR design

# Search results: query all matches at once
final searchResults = ['user1', 'user2', 'user3'];
query.matchPaths('user->group->project', startIds: searchResults)
# Efficient batch query for all search results
```

**Key Features:**
- Automatically deduplicates when multiple starts find the same path
- More efficient than multiple single queries
- Perfect for search functionality (4 depth levels × 10 results = single query instead of 40 ORs)

### Single Starting Node (startId - Deprecated)

> **Note:** `startId` will be deprecated in 0.9.0 in favor of `startIds` for API consistency. Use `startIds: ['node_id']` for new code.

```cypher
# Old style (will be deprecated)
query.match('person-[:WORKS_FOR]->team', startId: 'alice')

# New style (preferred)
query.match('person-[:WORKS_FOR]->team', startIds: ['alice'])
```

### Starting from Any Position

**Important:** Start parameters can match **any element** in the pattern, not just the first:

```cypher
# Pattern: a->b->c
# startIds can match 'a', 'b', OR 'c'

# Start from first element
query.matchPaths('person->team->project', startIds: ['alice'])
# Matches paths where person = alice

# Start from middle element
query.matchPaths('person->team->project', startIds: ['engineering'])
# Matches paths where team = engineering

# Start from last element
query.matchPaths('person->team->project', startIds: ['web_app'])
# Matches paths where project = web_app

# Multiple starts at different positions
query.matchPaths('person->team->project', startIds: ['alice', 'engineering', 'web_app'])
# Matches paths where ANY variable matches any of these IDs
```

### Performance Optimization with startType

When starting from middle or last elements, use `startType` to tell graph_kit which position to check:

```cypher
# Without startType: checks all positions (slower)
query.matchPaths(
  'person->team->project',
  startIds: ['engineering']
)
# Checks if 'engineering' matches person, team, OR project

# With startType: only checks specified type (faster!)
query.matchPaths(
  'person->team->project',
  startIds: ['engineering'],
  startType: 'Team'
)
# ONLY checks if 'engineering' matches team position
```

### When to Use startType

Use `startType` for better performance when:
- Starting from middle or last elements
- Working with long patterns (4+ elements)
- Running performance-critical queries
- You know the node type of your starting nodes

**Example with long pattern:**

```cypher
# 5-element pattern
query.matchPaths(
  'a->b->c->d->e',
  startIds: ['node_d'],
  startType: 'NodeTypeD'  # Skip checking a, b, c positions
)
```

### Common Patterns

```cypher
# Find all projects for multiple teams (start from middle)
query.matchPaths(
  'person->team->project',
  startIds: ['engineering', 'design'],
  startType: 'Team'
)

# Find all people working on multiple projects (start from end)
query.matchPaths(
  'person->team->project',
  startIds: ['web_app', 'mobile_app'],
  startType: 'Project'
)

# Backward traversal from specific nodes
query.matchPaths(
  'project<-[:ASSIGNED_TO]-team<-[:WORKS_FOR]-person',
  startIds: ['web_app', 'mobile_app']
)
```

## Node Types and Labels

### Node Types
Specify the type of nodes to match using the `:Type` syntax:

```cypher
MATCH person:Person        # Find Person nodes
MATCH team:Team           # Find Team nodes
MATCH project:Project     # Find Project nodes
```

### Inline Property Filtering
Attach a property map to any node using `{property=value}` (or `{property:value}`) for exact matches, or `{property~value}` for case-insensitive substring checks. This works for built-in fields (`label`, `id`, `type`) and any entry inside `Node.properties`.

```cypher
# Exact label match
MATCH person:Person{label=Alice}

# Custom property equality
MATCH source:Source{sourceKind:"user"}

# Partial match on any string property
MATCH person:Person{label~Cooper}

# Property values with spaces (quotes optional for compatibility)
MATCH asset:Asset{region:"us west"}
```

## Relationships and Edges

### Basic Relationships
```cypher
# Forward relationship
MATCH person:Person->team:Team

# Backward relationship
MATCH team:Team<-person:Person

# Bidirectional (either direction)
MATCH person:Person-team:Team
```

### Typed Relationships
Specify relationship types using `[:TYPE]` syntax:

```cypher
# Forward typed relationship
MATCH person:Person-[:WORKS_FOR]->team:Team

# Backward typed relationship
MATCH project:Project<-[:MANAGES]-person:Person

# Mixed directions
MATCH person:Person-[:WORKS_FOR]->team:Team-[:WORKS_ON]->project:Project
```

## Multiple Edge Types

Match relationships that can be any of several types using the `|` (OR) operator:

```cypher
# Match people who WORKS_FOR or VOLUNTEERS_AT an organization
MATCH person:Person-[:WORKS_FOR|VOLUNTEERS_AT]->org:Organization

# Match any of three relationship types
MATCH user:User-[:FOLLOWS|LIKES|SUBSCRIBES_TO]->content:Content

# Works with backwards relationships too
MATCH project:Project<-[:ASSIGNED_TO|COLLABORATES_WITH]-team:Team

# Combine with other features
MATCH person:Person-[:WORKS_FOR|MANAGES|INTERN_AT]->team:Team
WHERE person.age > 25
```

### OR Semantics

Multiple edge types use **OR logic** - a match is found if **ANY** of the specified types exist:

```cypher
# This matches if there's a WORKS_FOR edge OR a VOLUNTEERS_AT edge
person-[:WORKS_FOR|VOLUNTEERS_AT]->org

# Equivalent to SQL's: WHERE edge_type IN ('WORKS_FOR', 'VOLUNTEERS_AT')
```

### Combining with Variable-Length Paths

Multiple edge types work seamlessly with variable-length paths:

```cypher
# Find all nodes reachable within 2 hops via WORKS_FOR or MANAGES
MATCH person:Person-[:WORKS_FOR|MANAGES*1..2]->target

# Follow collaboration paths of mixed types
MATCH team:Team-[:COLLABORATES_WITH|PARTNERS_WITH*]->connected:Team
```

## Mixed Direction Patterns

Combine forward (`->`) and backward (`<-`) relationships in a single pattern to find common connections, hierarchies, and bidirectional patterns.

### Basic Mixed Patterns

```cypher
# Find coworkers: people who work for teams managed by same manager
MATCH person1-[:WORKS_FOR]->team<-[:MANAGES]-manager

# Find people following the same person (common target)
MATCH person1-[:FOLLOWS]->target<-[:FOLLOWS]-person2

# Find people followed by the same person (common source)
MATCH target1<-[:FOLLOWS]-person-[:FOLLOWS]->target2
```

### Real-World Use Cases

**Organizational Hierarchies**
```cypher
# Find coworkers (people reporting to same manager)
MATCH emp1-[:REPORTS_TO]->manager<-[:REPORTS_TO]-emp2

# Find peers in sibling departments
MATCH me-[:REPORTS_TO]->my_manager-[:REPORTS_TO]->director<-[:REPORTS_TO]-other_manager<-[:REPORTS_TO]-peer
```

**Social Networks**
```cypher
# Find mutual connections (friend triangles)
MATCH alice-[:FRIENDS_WITH]->bob-[:FRIENDS_WITH]->charlie<-[:FRIENDS_WITH]-alice

# Discover related research papers
MATCH my_paper-[:CITES]->source<-[:CITES]-related_paper
```

**Supply Chain & E-commerce**
```cypher
# Find companies sharing suppliers
MATCH company_a-[:BUYS_FROM]->supplier<-[:BUYS_FROM]-company_b

# Product recommendations
MATCH user-[:PURCHASED]->product<-[:PURCHASED]-other_user-[:PURCHASED]->recommended
```

### Complex Chains

Mixed directions work in patterns of any length:

```cypher
# 5-hop pattern with multiple direction changes
MATCH a->b->c<-d<-e->f

# Citation network analysis
MATCH p1-[:CITES]->base<-[:CITES]-p2<-[:CITES]-review-[:CITES]->p3
```

### Combining with Other Features

Mixed directions integrate seamlessly with all other features:

```cypher
# With multiple edge types
MATCH p1-[:WORKS_FOR|MANAGES]->team<-[:VOLUNTEERS_FOR]-p2

# With variable-length paths
MATCH start-[:CONNECTS*1..2]->hub<-[:CONNECTS]-end

# With WHERE clauses
MATCH emp1-[:WORKS_FOR]->team<-[:WORKS_FOR]-emp2
WHERE emp1.age > 30 AND emp2.age > 30

# With label filtering
MATCH person1:Person{label~Admin}->team<-[:MANAGES]-manager
```

## Relationship Properties

Relationships can store metadata (weights, timestamps, workflow states) via the optional `properties` argument when you add edges:

```dart
graph.addEdge(
  'alice',
  'KNOWS',
  'bob',
  properties: {'since': 2020, 'strength': 90},
);
```

Use that metadata throughout your Cypher-style queries:

```cypher
# Inline relationship filter (forward or backward)
MATCH person-[r:KNOWS {since: 2020}]->friend

# WHERE clause referencing relationship properties
MATCH person-[r:KNOWS]->friend
WHERE r.strength >= 80

# RETURN clause projecting relationship properties
MATCH person-[r:KNOWS]->friend
RETURN person, friend, r.since AS connectedSince, r.strength

# Backward example
MATCH mentee<-[:MENTORS {since: 2021}]-mentor
```

`matchPaths` and `matchPathsMany` include the same metadata on every `PathEdge`, including variable-length segments. Forward, backward, and wildcard `[:TYPE*{...}]` patterns now expose each hop’s properties and honor inline filters, `WHERE r.prop`, and `RETURN r.prop` (RETURN emits per-hop lists).

## Variable-Length Paths

Find paths of variable length using the `*` modifier:

```cypher
# Any length path
MATCH person:Person-[:MANAGES*]->subordinate:Person

# Specific length
MATCH person:Person-[:MANAGES*3]->subordinate:Person

# Range of lengths
MATCH person:Person-[:MANAGES*1..3]->subordinate:Person

# Minimum length
MATCH person:Person-[:MANAGES*2..]->subordinate:Person

# Maximum length
MATCH person:Person-[:MANAGES*..4]->subordinate:Person
```

## WHERE Clause Filtering

Add powerful filtering capabilities to your patterns:

### Basic WHERE Syntax
```cypher
MATCH person:Person WHERE person.age > 25
```

### Property Comparisons
```cypher
# Numeric comparisons
MATCH person:Person WHERE person.age > 30
MATCH person:Person WHERE person.salary >= 90000
MATCH person:Person WHERE person.experience < 5

# String comparisons
MATCH person:Person WHERE person.department = "Engineering"
MATCH person:Person WHERE person.status != "inactive"

# Multiple data types
MATCH project:Project WHERE project.budget <= 100000
```

## Logical Operators

Combine multiple conditions using AND and OR:

### AND Operator
```cypher
# Both conditions must be true
MATCH person:Person WHERE person.age > 25 AND person.department = "Engineering"

# Multiple AND conditions
MATCH person:Person WHERE person.age > 30 AND person.salary > 80000 AND person.active = true
```

### OR Operator
```cypher
# Either condition can be true
MATCH person:Person WHERE person.age < 30 OR person.salary > 95000

# Multiple OR conditions
MATCH person:Person WHERE person.department = "Engineering" OR person.department = "Design" OR person.department = "Marketing"
```

### Mixed AND/OR
```cypher
# AND has higher precedence than OR
MATCH person:Person WHERE person.age > 40 AND person.salary > 100000 OR person.department = "Management"

# This is equivalent to:
# (person.age > 40 AND person.salary > 100000) OR person.department = "Management"
```

## Parentheses and Precedence

Use parentheses to control evaluation order and create complex logical expressions:

### Single Parentheses Group
```cypher
# Group AND conditions before OR
MATCH person:Person WHERE (person.age > 40 AND person.salary > 100000) OR person.department = "Management"

# Group OR conditions with AND
MATCH person:Person WHERE person.department = "Engineering" AND (person.age < 30 OR person.salary > 90000)
```

### Multiple Parentheses Groups
```cypher
# Two separate condition groups
MATCH person:Person WHERE (person.age > 40 AND person.salary > 100000) OR (person.age < 30 AND person.department = "Engineering")

# Complex multi-group logic
MATCH person:Person WHERE (person.department = "Engineering" AND person.level = "Senior") OR (person.department = "Management" AND person.age > 40)

# Mixed parentheses positions
MATCH person:Person WHERE (person.age < 30 OR person.age > 45) AND (person.salary > 100000 OR person.department = "Management")
```

### Precedence Examples
```cypher
# Without parentheses - AND binds tighter than OR
person.age > 30 AND person.salary > 80000 OR person.department = "Management"
# Evaluates as: (person.age > 30 AND person.salary > 80000) OR person.department = "Management"

# With parentheses - explicit grouping
(person.age > 30 OR person.department = "Management") AND person.salary > 80000
# Different result: checks if person is over 30 OR in management, AND has high salary
```

## Property Comparisons

### Supported Operators
- `>` - Greater than
- `<` - Less than
- `>=` - Greater than or equal
- `<=` - Less than or equal
- `=` - Equal
- `!=` - Not equal
- `CONTAINS` - Substring match (case-insensitive)

### Data Types
```cypher
# Numbers (integers and decimals)
MATCH person:Person WHERE person.age > 30
MATCH project:Project WHERE project.budget >= 50000.50

# Strings (exact match only for >, <)
MATCH person:Person WHERE person.department = "Engineering"
MATCH person:Person WHERE person.status != "inactive"

# Booleans
MATCH person:Person WHERE person.active = true

# Substring matching with CONTAINS (case-insensitive)
MATCH asset:Asset WHERE asset.label CONTAINS "gw"
MATCH asset:Asset WHERE asset.ip CONTAINS "192.168"
MATCH person:Person WHERE person.name CONTAINS "john"  # matches "John", "Johnny", etc.

# CONTAINS works with direct properties (id, type, label) and custom properties
MATCH node:Asset WHERE node.label CONTAINS "server" OR node.hostname CONTAINS "prod"
```

## Edge Variable Comparison

Edge variable comparison allows you to enforce edge type consistency across multi-hop paths by comparing edge variables directly. This is essential for maintaining type integrity in routing patterns, workflow chains, and transaction sequences.

### Basic Syntax

```cypher
# Enforce same edge type across two hops
MATCH a-[r]->b-[r2]->c WHERE type(r2) = type(r)

# Ensure different edge types
MATCH a-[r]->b-[r2]->c WHERE type(r2) != type(r)

# Combine with prefix filtering (most common pattern)
MATCH a-[r]->b-[r2]->c WHERE type(r) STARTS WITH "PREFIX_" AND type(r2) = type(r)

# Three-hop consistency
MATCH a-[r]->b-[r2]->c-[r3]->d
WHERE type(r) STARTS WITH "CATEGORY_"
  AND type(r2) = type(r)
  AND type(r3) = type(r)
```

### Simple Example

```cypher
# Graph has routes with different identifiers
# node1 -[ROUTE_A]-> hub -[ROUTE_A]-> target1
# node1 -[ROUTE_A]-> hub -[ROUTE_B]-> target2

# WITHOUT edge variable comparison - returns all routes
MATCH source-[r]->hub-[r2]->target
WHERE type(r) STARTS WITH "ROUTE_"
# Returns: target1, target2 (both routes, regardless of consistency)

# WITH edge variable comparison - only consistent routes
MATCH source-[r]->hub-[r2]->target
WHERE type(r) STARTS WITH "ROUTE_" AND type(r2) = type(r)
# Returns: target1 (only where r and r2 are both ROUTE_A)
```

### Why Use Edge Variable Comparison?

Without edge variable comparison, multi-hop queries can return **incorrect paths** that mix edge types from different contexts:

```cypher
# PROBLEM: Without type consistency check
MATCH policy-[r]->relay-[r2]->destination
WHERE type(r) STARTS WITH "DIRECT_"

# This matches ALL paths where:
# - r is any DIRECT_* edge (e.g., DIRECT_policy1)
# - r2 is any DIRECT_* edge (e.g., DIRECT_policy2)
# Result: Paths that MIX different policy contexts!
```

With edge variable comparison:

```cypher
# SOLUTION: Enforce type consistency
MATCH policy-[r]->relay-[r2]->destination
WHERE type(r) STARTS WITH "DIRECT_" AND type(r2) = type(r)

# This matches ONLY paths where:
# - r is any DIRECT_* edge (e.g., DIRECT_policy1)
# - r2 is THE SAME edge type (must be DIRECT_policy1)
# Result: Only paths within the same policy context!
```

### Common Use Cases

#### 1. Workflow Approval Chains

Ensure multi-hop approval paths maintain the same approval type:

```cypher
# Request -> Approver -> Final Approver (same approval level throughout)
MATCH request:Request-[r]->approver:Person-[r2]->final:Person
WHERE type(r) STARTS WITH "REQUIRES_APPROVAL_" AND type(r2) = type(r)

# This ensures the entire approval chain uses the same approval level
# preventing mixing of different approval types (e.g., technical vs financial)
```

#### 2. Transaction Chains

Maintain transaction type consistency across hops:

```cypher
# Account -> Intermediate -> Account (same transaction type)
MATCH source:Account-[r]->intermediate-[r2]->target:Account
WHERE type(r) STARTS WITH "TRANSACTION_" AND type(r2) = type(r)

# Ensures transaction chains don't mix different transaction types
```

#### 3. Virtual Network Paths

Enforce VLAN or network segment consistency:

```cypher
# Host -> Switch -> Host (same VLAN)
MATCH host1-[r]->switch-[r2]->host2
WHERE type(r) STARTS WITH "VLAN_" AND type(r2) = type(r)

# Ensures packets stay within the same virtual network
```

#### 4. Access Control Chains

Verify permission inheritance consistency:

```cypher
# User -> Group -> Resource (same permission type)
MATCH user-[r]->group-[r2]->resource
WHERE type(r) STARTS WITH "HAS_PERMISSION_" AND type(r2) = type(r)

# Ensures permission chains maintain the same access level
```

### Three-Hop Consistency

Extend edge type consistency across multiple hops:

```cypher
# All three edges must have the same type
MATCH a-[r]->b-[r2]->c-[r3]->d
WHERE type(r) STARTS WITH "PREFIX_"
  AND type(r2) = type(r)
  AND type(r3) = type(r)

# Example: Policy drill-down with 3 levels
MATCH policy-[r]->relay1-[r2]->relay2-[r3]->destination
WHERE type(r) STARTS WITH "VIRTUAL_"
  AND type(r2) = type(r)
  AND type(r3) = type(r)
```

### Inequality Comparisons

Find paths where edge types differ (useful for detecting transitions):

```cypher
# Find points where edge type changes
MATCH a-[r]->b-[r2]->c WHERE type(r2) != type(r)

# Example: Detect policy transitions
MATCH source-[r]->intermediate-[r2]->target
WHERE type(r) STARTS WITH "DIRECT_"
  AND type(r2) STARTS WITH "DIRECT_"
  AND type(r2) != type(r)
# Returns paths where policy context changes
```

### Combining with OR Conditions

Use edge variable comparison with complex logical expressions:

```cypher
# Multiple allowed policy types, but must be consistent
MATCH policy-[r]->relay-[r2]->destination
WHERE (type(r) = "DIRECT_policy1" OR type(r) = "DIRECT_policy2")
  AND type(r2) = type(r)

# Edge type must match AND one of several start types
MATCH source-[r]->hub-[r2]->target
WHERE type(r) STARTS WITH "ROUTE_"
  AND type(r2) = type(r)
  AND (source.category = "A" OR source.category = "B")
```

### Performance Considerations

Edge variable comparison is efficient because:
- Comparison happens after edge type is already bound during traversal
- No additional graph lookups required
- Simply compares two string values from the current row

```cypher
# Efficient: Filter during traversal
WHERE type(r) STARTS WITH "DIRECT_" AND type(r2) = type(r)

# Less efficient: Post-process after collecting all paths
WHERE type(r) STARTS WITH "DIRECT_"
# Then manually filter results in application code
```

### Edge Variable Comparison with matchPaths()

Works seamlessly with `matchPaths()` to get complete path information:

```cypher
final paths = query.matchPaths(
  'source-[r]->hub-[r2]->destination WHERE type(r2) = type(r)',
  startId: 'source1'
);

for (final path in paths) {
  print('Edge 1: ${path.edges[0].type}');  // e.g., "ROUTE_abc"
  print('Edge 2: ${path.edges[1].type}');  // e.g., "ROUTE_abc" (same!)
  assert(path.edges[0].type == path.edges[1].type);  // Always true
}
```

### Real-World Example

Complete example showing the difference:

```dart
// Setup: Hub with edges from different sources
graph.addNode(Node(id: 'source1', type: 'Source', label: 'Source1'));
graph.addNode(Node(id: 'hub', type: 'Hub', label: 'Hub1'));
graph.addNode(Node(id: 'target1', type: 'Target', label: 'Target1'));
graph.addNode(Node(id: 'target2', type: 'Target', label: 'Target2'));

graph.addEdge('source1', 'PREFIX_abc', 'hub');
graph.addEdge('hub', 'PREFIX_abc', 'target1');  // Same type
graph.addEdge('hub', 'PREFIX_xyz', 'target2');  // Different type

// WITHOUT edge variable comparison - returns both targets
final without = query.match(
  'source-[r]->hub-[r2]->target WHERE type(r) STARTS WITH "PREFIX_"'
);
print(without['target']);  // {target1, target2}

// WITH edge variable comparison - returns only consistent path
final with = query.match(
  'source-[r]->hub-[r2]->target WHERE type(r) STARTS WITH "PREFIX_" AND type(r2) = type(r)'
);
print(with['target']);  // {target1}
```

### Summary

Edge variable comparison is essential for:
- **Multi-hop path consistency** - Enforce same edge type across hops
- **Policy integrity** - Prevent cross-policy path contamination
- **Transaction chains** - Maintain transaction type throughout
- **Access control** - Verify permission inheritance consistency
- **Network segmentation** - Enforce VLAN/segment boundaries

**Syntax:**
- `WHERE type(r2) = type(r)` - Edge types must match
- `WHERE type(r2) != type(r)` - Edge types must differ
- Combine with `STARTS WITH`, `OR`, `AND` for complex filtering

## RETURN Clause - Property Projection

The RETURN clause projects specific variables and properties from query results, giving you clean, production-ready data instead of raw node IDs.

### Basic RETURN Syntax

```cypher
# Return node IDs (variable projection)
MATCH person:Person-[:WORKS_FOR]->team:Team RETURN person, team

# Return properties
MATCH person:Person RETURN person.name, person.age, person.salary

# Return with AS aliases
MATCH person:Person RETURN person.name AS employeeName, person.salary AS pay
```

### Property Access

Access node properties using dot notation:

```cypher
# Single property
MATCH person:Person RETURN person.name

# Multiple properties from same node
MATCH person:Person RETURN person.name, person.age, person.department

# Properties from different nodes
MATCH person:Person-[:WORKS_FOR]->team:Team
RETURN person.name, person.role, team.name, team.budget
```

### AS Aliases - Custom Column Names

Use `AS` to create readable column names (case-insensitive):

```cypher
# Basic aliasing
MATCH person:Person RETURN person.name AS employee

# Multiple aliases
MATCH person:Person-[:WORKS_FOR]->team:Team
RETURN person.name AS employee,
       person.salary AS compensation,
       team.name AS department

# Case variations (all valid)
RETURN person.name AS Name
RETURN person.name as name
RETURN person.name As displayName
```

**Note:** Aliases must be single identifiers (no spaces). Use camelCase or underscores:
- `AS employeeName`
- `AS employee_name`
- `AS "Employee Name"` (not supported)

### Combining WHERE + RETURN

Filter data with WHERE, then project specific columns:

```cypher
# Filter then project
MATCH person:Person
WHERE person.salary > 90000
RETURN person.name AS highEarner, person.salary AS pay

# Multi-hop with filtering and projection
MATCH person:Person-[:WORKS_FOR]->team:Team-[:WORKS_ON]->project:Project
WHERE person.age > 30 AND project.status = "active"
RETURN person.name AS engineer,
       team.name AS department,
       project.name AS activeProject

# Complex filtering with clean output
MATCH person:Person
WHERE (person.age > 40 AND person.salary > 100000) OR person.department = "Management"
RETURN person.name AS name, person.role AS position, person.salary AS compensation
```

### Mixing IDs and Properties

Combine node IDs with property values:

```cypher
# Node ID + properties
MATCH person:Person-[:WORKS_FOR]->team:Team
RETURN person, person.name, team.name AS department

# Useful for hydration patterns
MATCH person:Person WHERE person.salary > 95000
RETURN person AS id, person.name AS name, person.department AS dept
```

### Real-World RETURN Examples

#### Employee Directory
```cypher
MATCH person:Person-[:WORKS_FOR]->team:Team
RETURN person.name AS employee,
       person.role AS title,
       person.salary AS compensation,
       team.name AS department
```

#### Project Team Report
```cypher
MATCH person:Person-[:WORKS_FOR]->team:Team-[:WORKS_ON]->project:Project
WHERE project.status = "active"
RETURN person.name AS teamMember,
       person.role AS role,
       team.name AS team,
       project.name AS project,
       project.budget AS projectBudget
```

#### High Earners Analysis
```cypher
MATCH person:Person
WHERE person.salary >= 100000
RETURN person.name AS name,
       person.department AS dept,
       person.salary AS annualSalary,
       person.age AS yearsOld
```

### RETURN Result Structure

Results are returned as `List<Map<String, dynamic>>`:

```dart
// Without AS aliases - uses property path as key
[{'person.name': 'Alice', 'person.salary': 85000}]

// With AS aliases - uses alias as key
[{'employee': 'Alice', 'pay': 85000}]

// Mixed
[{'person': 'alice', 'name': 'Alice', 'dept': 'Engineering'}]
```

### Dart Destructuring (Recommended)

Use Dart 3 pattern matching for type-safe access:

```dart
final results = query.matchRows(
  'MATCH person:Person WHERE person.salary > 90000 '
  'RETURN person.name AS name, person.salary AS salary'
);

// Destructure in loop
for (var {'name': employeeName, 'salary': pay} in results) {
  print('$employeeName earns \$$pay');
}

// Single result destructuring
var {'name': name, 'salary': salary} = results.first;
```

## Sorting and Pagination

GraphKit supports `ORDER BY`, `SKIP`, and `LIMIT` clauses for controlling result order and pagination. These clauses (if present) must appear in this specific order at the end of your query:

`... RETURN ... ORDER BY ... SKIP ... LIMIT ...`

### ORDER BY Clause

Sort results by any variable or property. Default sort order is ascending (ASC).

```cypher
# Sort by property (ascending by default)
MATCH person:Person RETURN person.name, person.age ORDER BY person.age

# Explicit ASC/DESC
MATCH person:Person RETURN person.name, person.age ORDER BY person.age DESC
MATCH person:Person RETURN person.name, person.age ORDER BY person.name ASC

# Sort by alias from RETURN clause
MATCH person:Person RETURN person.name AS name ORDER BY name

# Sort by multiple keys
MATCH person:Person
RETURN person.department, person.age
ORDER BY person.department ASC, person.age DESC

# Sort using relationship metadata
MATCH employee:Person-[r:REPORTS_TO]->manager:Person
RETURN employee.name, manager.name
ORDER BY r.since DESC

# Sort by relationship type (type() function)
MATCH a-[r]->b
RETURN a, b
ORDER BY type(r)
```

### SKIP and LIMIT (Pagination)

Use `SKIP` to offset results and `LIMIT` to restrict the number of results returned.

```cypher
# Get top 5 results
MATCH person:Person ORDER BY person.salary DESC LIMIT 5

# Skip first 10 and get next 5 (Page 3 of size 5)
MATCH person:Person ORDER BY person.name SKIP 10 LIMIT 5
```

**Note:** `SKIP` and `LIMIT` work best when combined with `ORDER BY` to ensure deterministic results.

**Variable-length semantics:** When sorting on relationship properties or `type(r)` for a variable-length segment, GraphKit compares the *first hop* in each match. This keeps ordering deterministic even when a variable-length alias spans multiple relationships.

## Advanced Examples

### Complex Multi-Hop with WHERE
```cypher
# Find people over 30 and their team information
MATCH person:Person-[:WORKS_FOR]->team:Team WHERE person.age > 30

# Multi-hop with filtering
MATCH person:Person-[:WORKS_FOR]->team:Team-[:WORKS_ON]->project:Project
WHERE person.salary > 80000 AND project.status = "active"
```

### Real-World Query Scenarios

#### Human Resources Queries
```cypher
# Senior engineers eligible for promotion
MATCH person:Person WHERE person.department = "Engineering" AND person.age > 35 AND person.salary < 120000

# High performers across departments
MATCH person:Person WHERE (person.department = "Engineering" AND person.salary > 100000) OR (person.department = "Sales" AND person.salary > 90000)

# Management team analysis
MATCH person:Person WHERE person.department = "Management" OR (person.age > 45 AND person.salary > 110000)
```

#### Project Management Queries
```cypher
# Large or high-budget teams
MATCH team:Team WHERE team.size > 10 OR team.budget > 150000

# Active or expensive projects
MATCH project:Project WHERE project.status = "active" OR project.budget > 100000

# Critical project dependencies
MATCH project:Project-[:DEPENDS_ON*1..3]->service:Service WHERE service.critical = true
```

#### Organizational Analysis
```cypher
# Cross-functional collaboration
MATCH person:Person-[:WORKS_FOR]->team:Team-[:COLLABORATES_WITH*]->other_team:Team
WHERE person.department != other_team.department

# Leadership chains
MATCH person:Person-[:REPORTS_TO*1..4]->manager:Person
WHERE manager.department = "Management"
```

### Complex Multi-Criteria Filtering
```cypher
# Advanced talent search
MATCH person:Person WHERE
(person.department = "Engineering" AND person.experience > 5 AND person.salary < 130000) OR
(person.department = "Design" AND person.age < 35 AND person.portfolio_score > 8.5) OR
(person.age > 50 AND person.leadership_score > 9.0)

# Resource allocation analysis
MATCH team:Team WHERE
(team.size > 15 AND team.budget < 200000) OR
(team.efficiency_score < 7.0 AND team.budget > 150000)
```

## Query Structure Summary

```cypher
[MATCH] pattern [WHERE conditions]

# Where:
# - MATCH is optional for simple patterns
# - pattern: node and relationship specifications
# - WHERE conditions: property-based filtering with logical operators
```

### Pattern Components
- **Nodes**: `variable:Type{label=value}`
- **Relationships**: `->`, `<-`, `-[:TYPE]->`
- **Variable-length**: `-[:TYPE*min..max]->`

### WHERE Components
- **Properties**: `variable.property`
- **Operators**: `>`, `<`, `>=`, `<=`, `=`, `!=`
- **Logic**: `AND`, `OR`, `()`
- **Values**: numbers, strings, booleans

## Performance Tips

1. **Use specific node types** when possible to reduce search space
2. **Filter early** with WHERE clauses rather than post-processing
3. **Limit variable-length paths** with specific ranges
4. **Use label filters** to reduce nodes matched
5. **Order conditions** in WHERE clauses with most selective first

## Error Handling

Common parsing errors and solutions:

```cypher
# Missing quotes for strings
WHERE person.department = Engineering

# Correct string syntax
WHERE person.department = "Engineering"

# Invalid operator
WHERE person.age === 30

# Correct equality operator
WHERE person.age = 30

# Unmatched parentheses
WHERE (person.age > 30 AND person.salary > 80000

# Properly closed parentheses
WHERE (person.age > 30 AND person.salary > 80000)
```

---

## Getting Started

Try these examples in the GraphKit demo to explore the full power of Cypher queries:

1. Start with simple patterns: `person:Person`
2. Add relationships: `person:Person-[:WORKS_FOR]->team:Team`
3. Include filtering: `...WHERE person.age > 30`
4. Experiment with logical operators: `...WHERE A AND B OR C`
5. Master parentheses: `...WHERE (A AND B) OR (C AND D)`

The combination of pattern matching, relationship traversal, and sophisticated filtering makes GraphKit's Cypher implementation a powerful tool for graph analysis and data exploration!
