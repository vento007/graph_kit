import 'package:petitparser/petitparser.dart';

/// Grammar definition for Cypher-like patterns
class CypherPatternGrammar extends GrammarDefinition {
  @override
  Parser start() => (string('MATCH') & whitespace().plus()).optional() & ref0(patternWithWhere).end();

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

  Parser backwardArrow() => string('<-') & ref0(edgeType).optional() & char('-');

  Parser edgeType() => char('[') & char(':') & ref0(variable) & ref0(variableLengthModifier).optional() & char(']');

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

  Parser comparisonOperator() => string('>=') | string('<=') | string('!=') | char('>') | char('<') | char('=');

  Parser value() => ref0(stringLiteral) | ref0(numberLiteral);

  Parser stringLiteral() => char('"') & (char('"').neg()).star() & char('"');

  Parser numberLiteral() => digit().plus();

  // Helper for optional whitespace
  Parser optionalWhitespace() => whitespace().star();
}