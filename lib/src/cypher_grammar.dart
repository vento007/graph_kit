import 'package:petitparser/petitparser.dart';

/// Grammar definition for Cypher-like patterns
class CypherPatternGrammar extends GrammarDefinition {
  @override
  Parser start() => ((string('MATCH') & whitespace().plus()).optional() & ref0(patternWithWhere) & ref0(returnClause).optional()).end().trim();

  Parser patternWithWhere() => ref0(pattern) & (whitespace().plus() & ref0(whereClause)).optional();

  Parser pattern() => ref0(segment) & (ref0(connection) & ref0(segment)).star();

  Parser segment() => ref0(variable) & ref0(nodeType).optional() & ref0(labelFilter).optional();

  Parser variable() => letter() & (letter() | digit() | char('_')).star();

  Parser nodeType() => char(':') & ref0(variable);

  Parser labelFilter() =>
    char('{') &
    string('label') &
    (char('=') | char('~')) &
    ref0(labelValue) &
    char('}');

  Parser labelValue() =>
    (letter() | digit() | char('_') | char(' ')).plus();

  Parser connection() => ref0(forwardArrow) | ref0(backwardArrow);

  Parser forwardArrow() => (string('->') | (char('-') & ref0(edgeType) & string('->')));

  Parser backwardArrow() => ((string('<-') & ref0(edgeType) & char('-')) | string('<-'));

  Parser edgeType() => char('[') & whitespace().star() & char(':') & whitespace().star() & ref0(edgeTypeList) & whitespace().star() & ref0(variableLengthModifier).optional() & whitespace().star() & char(']');

  Parser edgeTypeList() => ref0(variable) & (char('|') & ref0(variable)).star();

  Parser variableLengthModifier() =>
    char('*') &
    (
      (digit().plus().flatten() & string('..') & digit().plus().flatten()) | // *min..max
      (digit().plus().flatten() & string('..')) |                           // *min..
      (string('..') & digit().plus().flatten()) |                           // *..max
      digit().plus().flatten() |                                            // *n (exact)
      epsilon()                                                             // just *
    ).optional();

  // WHERE clause support
  Parser whereClause() => string('WHERE') & whitespace().plus() & ref0(whereExpression);

  Parser whereExpression() => ref0(orExpression);

  Parser orExpression() => ref0(andExpression) & (whitespace().star() & string('OR') & whitespace().star() & ref0(andExpression)).star();

  Parser andExpression() => ref0(primaryExpression) & (whitespace().star() & string('AND') & whitespace().star() & ref0(primaryExpression)).star();

  Parser primaryExpression() => ref0(parenthesizedExpression) | ref0(comparisonExpression);

  Parser parenthesizedExpression() =>
    char('(') &
    whitespace().star() &
    ref0(whereExpression) &
    whitespace().star() &
    char(')');

  Parser comparisonExpression() =>
    ref0(propertyExpression) &
    whitespace().star() &
    ref0(comparisonOperator) &
    whitespace().star() &
    ref0(value);

  Parser propertyExpression() => ref0(variable) & char('.') & ref0(variable);

  Parser comparisonOperator() => string('CONTAINS') | string('>=') | string('<=') | string('!=') | char('>') | char('<') | char('=');

  Parser value() => ref0(stringLiteral) | ref0(numberLiteral) | ref0(booleanLiteral);

  Parser stringLiteral() => char('"') & (char('"').neg()).star() & char('"');

  Parser numberLiteral() => digit().plus();

  Parser booleanLiteral() => string('true') | string('false');

  // RETURN clause support
  Parser returnClause() => whitespace().plus() & string('RETURN') & whitespace().plus() & ref0(returnItems);

  Parser returnItems() => ref0(returnItem) & (whitespace().star() & char(',') & whitespace().star() & ref0(returnItem)).star();

  // RETURN item: variable, property access, or either with AS alias
  Parser returnItem() => (ref0(returnPropertyAccess) | ref0(variable)) & ref0(asAlias).optional();

  // Property access: variable.property
  Parser returnPropertyAccess() => ref0(variable) & char('.') & ref0(propertyName);
  
  Parser propertyName() => ref0(variable);

  // AS aliasing: AS alias_name (case insensitive)
  Parser asAlias() => 
    whitespace().plus() & 
    (string('AS') | string('as') | string('As') | string('aS')) & 
    whitespace().plus() & 
    ref0(variable);

  // Helper for optional whitespace
  Parser optionalWhitespace() => whitespace().star();
}