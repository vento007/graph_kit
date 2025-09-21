# GraphKit Cypher Query Language Guide

GraphKit now includes full WHERE clause support as part of the unified PatternQuery implementation. All features in this guide are available by default.

GraphKit implements a powerful subset of the Cypher query language for graph pattern matching and filtering. This guide covers all supported features with practical examples.

## Table of Contents
- [Basic Pattern Matching](#basic-pattern-matching)
- [Node Types and Labels](#node-types-and-labels)
- [Relationships and Edges](#relationships-and-edges)
- [Variable-Length Paths](#variable-length-paths)
- [WHERE Clause Filtering](#where-clause-filtering)
- [Logical Operators](#logical-operators)
- [Parentheses and Precedence](#parentheses-and-precedence)
- [Property Comparisons](#property-comparisons)
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

# Find nodes by ID (when used with startId parameter)
MATCH person:Person
```

## Node Types and Labels

### Node Types
Specify the type of nodes to match using the `:Type` syntax:

```cypher
MATCH person:Person        # Find Person nodes
MATCH team:Team           # Find Team nodes
MATCH project:Project     # Find Project nodes
```

### Label Filtering
Filter nodes by their label property using `{label=value}` or `{label~value}` syntax:

```cypher
# Exact label match
MATCH person:Person{label=Alice}

# Partial label match (contains)
MATCH person:Person{label~Cooper}

# Complex label with spaces
MATCH person:Person{label=Alice Cooper}
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
```

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
# ❌ Missing quotes for strings
WHERE person.department = Engineering

# ✅ Correct string syntax
WHERE person.department = "Engineering"

# ❌ Invalid operator
WHERE person.age === 30

# ✅ Correct equality operator
WHERE person.age = 30

# ❌ Unmatched parentheses
WHERE (person.age > 30 AND person.salary > 80000

# ✅ Properly closed parentheses
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