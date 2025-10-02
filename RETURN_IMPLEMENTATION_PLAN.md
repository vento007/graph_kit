# RETURN Clause Implementation Plan

## Current Status
- ✅ **77 tests passing** (grammar parsing basics)
- ❌ **87 tests failing** (implementation not done)
- ✅ Branch: `feature/return-clause`
- ✅ Tests committed

## Failing Test Categories

### 1. **Basic Variable Filtering** (31 failures)
**File**: `test/return_basic_test.dart`
**Cause**: Grammar can parse RETURN, but `matchRows()` doesn't filter results

**Example Failure**:
```dart
// Query: MATCH person-[:WORKS_FOR]->team RETURN person
// Expected: {person: 'alice'}, {person: 'bob'}  (only person column)
// Actual: {person: 'alice', team: 'engineering'}, {person: 'bob', team: 'engineering'}  (all columns)
```

**What's Needed**:
- Extract RETURN variables from parse tree
- Filter `currentRows` to only include requested variables
- Handle backward compatibility (no RETURN = return all)

---

### 2. **Property Access** (47 failures)
**File**: `test/return_properties_test.dart`
**Cause**: Grammar doesn't parse `person.name` syntax

**Example Failure**:
```dart
// Query: MATCH person:Person RETURN person.name
// Expected: Parse fails or parses incorrectly
// Need: Parse person.name as property access
```

**What's Needed**:
- Update grammar: `returnItem() => ref0(propertyAccess) | ref0(variable)`
- Add `propertyAccess()` parser: `variable . property`
- Implement property resolution in results
- Return structure: `{'person.name': 'Alice'}` (dotted key with value)

---

### 3. **AS Aliases** (9 failures)
**File**: `test/return_aliases_test.dart`
**Cause**: Grammar doesn't parse `AS aliasName` syntax

**Example Failure**:
```dart
// Query: RETURN person.name AS displayName
// Expected: {'displayName': 'Alice'}  (renamed column)
// Need: Parse AS keyword and apply aliasing
```

**What's Needed**:
- Update grammar: `returnItem() => (propertyAccess | variable) & asAlias().optional()`
- Add `asAlias()` parser: `AS identifier`
- Apply aliasing when building results

---

## Implementation Steps

### **Step 1: Make Basic Tests Pass** (Phase 1)
**Goal**: 31 basic filtering tests pass
**Time**: 1-2 hours

#### Changes Needed:

**File**: `lib/src/pattern_query.dart`

1. **Extract RETURN clause from parse tree**
```dart
// In matchRows() after parsing
List<String>? returnVariables;  // null = return all (backward compat)

if (parseResult has RETURN section) {
  returnVariables = _extractReturnVariables(parseTree);
}
```

2. **Filter results before returning**
```dart
// At end of matchRows(), before returning currentRows
if (returnVariables != null) {
  currentRows = _filterReturnColumns(currentRows, returnVariables);
}
```

3. **Implement filtering logic**
```dart
List<Map<String, String>> _filterReturnColumns(
  List<Map<String, String>> rows,
  List<String> returnVars,
) {
  return rows.map((row) {
    final filtered = <String, String>{};
    for (final varName in returnVars) {
      if (row.containsKey(varName)) {
        filtered[varName] = row[varName]!;
      }
    }
    return filtered;
  }).toList();
}
```

**Test Command**:
```bash
dart test test/return_basic_test.dart
# Target: All 31 tests pass
```

---

### **Step 2: Make Property Tests Pass** (Phase 2)
**Goal**: 47 property access tests pass
**Time**: 3-4 hours

#### Changes Needed:

**File**: `lib/src/cypher_grammar.dart`

1. **Update returnItem grammar**
```dart
Parser returnItem() => ref0(propertyAccess) | ref0(variable);

Parser propertyAccess() => 
  ref0(variable) & 
  char('.') & 
  ref0(variable);
```

**File**: `lib/src/pattern_query.dart`

2. **Extract property access from parse tree**
```dart
class ReturnItem {
  final String? variable;      // For: RETURN person
  final String? propertyVar;   // For: RETURN person.name
  final String? propertyName;  // For: RETURN person.name
  
  bool get isProperty => propertyVar != null;
}

List<ReturnItem> _extractReturnItems(dynamic returnSection) {
  // Parse tree structure and extract ReturnItems
}
```

3. **Resolve properties when building results**
```dart
List<Map<String, dynamic>> _buildReturnResults(
  List<Map<String, String>> rows,
  List<ReturnItem> returnItems,
) {
  return rows.map((row) {
    final result = <String, dynamic>{};
    
    for (final item in returnItems) {
      if (item.isProperty) {
        // Property access: person.name
        final nodeId = row[item.propertyVar];
        if (nodeId != null) {
          final node = graph.nodesById[nodeId];
          final value = node?.properties?[item.propertyName];
          result['${item.propertyVar}.${item.propertyName}'] = value;
        }
      } else {
        // Simple variable: person
        result[item.variable!] = row[item.variable!];
      }
    }
    
    return result;
  }).toList();
}
```

4. **Update return types**
```dart
// matchRows() now returns List<Map<String, dynamic>> instead of List<Map<String, String>>
// to support property values (int, double, bool, String, etc.)
List<Map<String, dynamic>> matchRows(String pattern, {String? startId}) {
  // ... existing logic ...
  
  // At end:
  if (returnItems != null) {
    return _buildReturnResults(currentRows, returnItems);
  }
  return currentRows;  // backward compat
}
```

**Test Command**:
```bash
dart test test/return_properties_test.dart
# Target: All 47 tests pass
```

---

### **Step 3: Make Alias Tests Pass** (Phase 3)
**Goal**: 9 alias tests pass
**Time**: 1-2 hours

#### Changes Needed:

**File**: `lib/src/cypher_grammar.dart`

1. **Update returnItem to support AS**
```dart
Parser returnItem() => 
  (ref0(propertyAccess) | ref0(variable)) & 
  ref0(asAlias).optional();

Parser asAlias() => 
  whitespace().plus() & 
  (string('AS') | string('as')) & 
  whitespace().plus() & 
  ref0(variable);
```

**File**: `lib/src/pattern_query.dart`

2. **Add alias to ReturnItem**
```dart
class ReturnItem {
  final String? variable;
  final String? propertyVar;
  final String? propertyName;
  final String? alias;  // NEW: optional alias
  
  String get columnName => alias ?? 
    (isProperty ? '$propertyVar.$propertyName' : variable!);
}
```

3. **Use alias when building results**
```dart
List<Map<String, dynamic>> _buildReturnResults(...) {
  return rows.map((row) {
    final result = <String, dynamic>{};
    
    for (final item in returnItems) {
      final columnName = item.columnName;  // Uses alias if present
      
      if (item.isProperty) {
        final value = /* ... resolve property ... */;
        result[columnName] = value;
      } else {
        result[columnName] = row[item.variable!];
      }
    }
    
    return result;
  }).toList();
}
```

**Test Command**:
```bash
dart test test/return_aliases_test.dart
# Target: All 9 tests pass
```

---

### **Step 4: Integration Tests** (Phase 4)
**Goal**: All remaining tests pass
**Time**: 1 hour

**Test Command**:
```bash
dart test test/return_integration_test.dart
dart test test/return_grammar_test.dart
```

Fix any edge cases and ensure backward compatibility.

---

## Detailed Implementation Order

### **Hour 1-2: Basic Filtering**
1. Add `_extractReturnVariables()` helper
2. Add `_filterReturnColumns()` helper
3. Integrate into `matchRows()`
4. Run: `dart test test/return_basic_test.dart`
5. Commit: "feat: implement basic RETURN variable filtering"

### **Hour 3-6: Property Access**
1. Update grammar for property access
2. Create `ReturnItem` class
3. Add `_extractReturnItems()` parser
4. Add `_buildReturnResults()` resolver
5. Update `matchRows()` return type
6. Run: `dart test test/return_properties_test.dart`
7. Commit: "feat: implement RETURN property access"

### **Hour 7-8: AS Aliasing**
1. Update grammar for AS keyword
2. Add alias field to `ReturnItem`
3. Update `_buildReturnResults()` to use aliases
4. Run: `dart test test/return_aliases_test.dart`
5. Commit: "feat: implement RETURN AS aliasing"

### **Hour 9: Integration & Polish**
1. Run full test suite: `dart test test/return_*.dart`
2. Fix any remaining edge cases
3. Update main test suite: `dart test`
4. Commit: "feat: complete RETURN clause implementation"

---

## Expected Final State

### Test Results
```
✅ 77 existing tests pass (grammar)
✅ 31 basic filtering tests pass
✅ 47 property access tests pass
✅ 9 alias tests pass
✅ ~10 integration tests pass
─────────────────────────────
✅ ~174 total tests pass
```

### Backward Compatibility
- ✅ Queries without RETURN work unchanged
- ✅ `match()` method still returns `Map<String, Set<String>>`
- ✅ `matchPaths()` still returns `List<PathMatch>`
- ✅ No breaking changes to API

### New Capabilities
```dart
// Basic filtering
query.matchRows('MATCH person:Person RETURN person');
// => [{'person': 'alice'}, {'person': 'bob'}]

// Property access
query.matchRows('MATCH person:Person RETURN person.name, person.age');
// => [{'person.name': 'Alice', 'person.age': 28}, ...]

// Aliasing
query.matchRows('RETURN person.name AS displayName, person.age AS years');
// => [{'displayName': 'Alice', 'years': 28}, ...]

// Combined
query.matchRows('''
  MATCH person-[:WORKS_FOR]->team 
  WHERE person.age > 30 
  RETURN person.name AS employee, team.name AS department
''');
// => [{'employee': 'Bob', 'department': 'Engineering'}, ...]
```

---

## Questions to Resolve

### 1. **Return Type Change**
Current: `List<Map<String, String>>` (IDs only)
Proposed: `List<Map<String, dynamic>>` (IDs + property values)

**Impact**: Technically breaking but necessary for properties
**Mitigation**: Document migration, most code won't break

### 2. **Non-existent Variables**
```dart
MATCH person:Person RETURN nonexistent
```
**Options**:
- A) Throw error (strict)
- B) Return empty rows (lenient)
- C) Silently ignore (dangerous)

**Recommendation**: Option A (throw error)

### 3. **Property on Non-existent Node**
```dart
// Node doesn't exist in graph
person.properties?['age']  // => null
```
**Options**:
- A) Return null (SQL-like)
- B) Omit column (sparse)

**Recommendation**: Option A (return null)

---

## Success Criteria

✅ All 87 failing tests pass
✅ No breaking changes to existing tests
✅ Grammar correctly parses all RETURN syntaxes
✅ Properties resolved correctly
✅ Aliases applied correctly
✅ Backward compatibility maintained
✅ Documentation updated
✅ Examples added

## Ready to Implement?

Shall I proceed with **Step 1: Basic Variable Filtering**?
