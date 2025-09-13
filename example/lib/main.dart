import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:graph_kit/graph_kit.dart';
import 'dart:math' as math;

void main() {
  runApp(const GraphKitDemo());
}

class GraphKitDemo extends StatelessWidget {
  const GraphKitDemo({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Graph Kit Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const GraphVisualization(),
    );
  }
}

class GraphVisualization extends StatefulWidget {
  const GraphVisualization({super.key});

  @override
  State<GraphVisualization> createState() => _GraphVisualizationState();
}

class _GraphVisualizationState extends State<GraphVisualization> {
  late Graph<Node> graph;
  late PatternQuery<Node> query;
  final TextEditingController _queryController = TextEditingController();
  Map<String, Set<String>>? queryResults;
  List<Map<String, String>>? queryRows;
  String? selectedNodeId;
  bool _showCode = true;
  late String _graphSetupCode;
  String? _lastPattern;
  Set<String> _highlightEdgeTypes = const {};
  Set<String> _highlightNodeIds = const {};

  @override
  void initState() {
    super.initState();
    _setupDemoGraph();
  }

  void _setupDemoGraph() {
    graph = Graph<Node>();

    // Add people
    graph.addNode(Node(id: 'alice', type: 'Person', label: 'Alice Cooper',
        properties: {'role': 'Developer', 'level': 'Senior'}));
    graph.addNode(Node(id: 'bob', type: 'Person', label: 'Bob Wilson',
        properties: {'role': 'Developer', 'level': 'Junior'}));
    graph.addNode(Node(id: 'charlie', type: 'Person', label: 'Charlie Davis',
        properties: {'role': 'Manager', 'level': 'Director'}));

    // Add teams
    graph.addNode(Node(id: 'engineering', type: 'Team', label: 'Engineering',
        properties: {'size': 15, 'budget': 150000}));
    graph.addNode(Node(id: 'design', type: 'Team', label: 'Design Team',
        properties: {'size': 5, 'budget': 80000}));
    graph.addNode(Node(id: 'marketing', type: 'Team', label: 'Marketing',
        properties: {'size': 8, 'budget': 120000}));

    // Add projects
    graph.addNode(Node(id: 'web_app', type: 'Project', label: 'Web Application',
        properties: {'status': 'active', 'priority': 'high'}));
    graph.addNode(Node(id: 'mobile_app', type: 'Project', label: 'Mobile App',
        properties: {'status': 'planning', 'priority': 'medium'}));
    graph.addNode(Node(id: 'campaign', type: 'Project', label: 'Ad Campaign',
        properties: {'status': 'active', 'priority': 'high'}));

    // Add relationships
    graph.addEdge('alice', 'WORKS_FOR', 'engineering');
    graph.addEdge('bob', 'WORKS_FOR', 'engineering');
    graph.addEdge('charlie', 'MANAGES', 'engineering');
    graph.addEdge('charlie', 'MANAGES', 'design');
    graph.addEdge('charlie', 'MANAGES', 'marketing');
    graph.addEdge('engineering', 'ASSIGNED_TO', 'web_app');
    graph.addEdge('engineering', 'ASSIGNED_TO', 'mobile_app');
    graph.addEdge('design', 'ASSIGNED_TO', 'mobile_app');
    graph.addEdge('marketing', 'ASSIGNED_TO', 'campaign');
    graph.addEdge('alice', 'LEADS', 'web_app');

    query = PatternQuery(graph);
    _graphSetupCode = _buildGraphSetupCode();
  }

  void _executeQuery() {
    final pattern = _queryController.text;
    if (pattern.isEmpty) {
      setState(() => queryResults = null);
      return;
    }

    try {
      final results = query.match(pattern);
      _lastPattern = pattern;
      _highlightEdgeTypes = _extractEdgeTypes(pattern);
      // Build highlighted nodes from grouped results
      final hi = <String>{};
      for (final s in results.values) {
        hi.addAll(s);
      }
      _highlightNodeIds = hi;
      setState(() {
        queryRows = null;
        queryResults = results;
      });
    } catch (e) {
      debugPrint('Query error: $e');
      setState(() => queryResults = {'error': {'Query failed: $e'}});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Graph Kit Demo'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Row(
        children: [
          // Left panel - Controls
          Container(
            width: 300,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(right: BorderSide(color: Colors.grey.shade300)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Pattern Query:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                TextField(
                  controller: _queryController,
                  decoration: const InputDecoration(
                    hintText: 'e.g., person:Person-[:WORKS_FOR]->team',
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => _executeQuery(),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _executeQuery,
                        child: const Text('Execute'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () => setState(() {
                        _queryController.clear();
                        queryResults = null;
                        queryRows = null;
                        _lastPattern = null;
                        _highlightEdgeTypes = const {};
                        _highlightNodeIds = const {};
                      }),
                      child: const Text('Clear'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Preset queries
                const Text('Quick Queries:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    _buildQueryChip('All People', 'person:Person'),
                    _buildQueryChip('All Teams', 'team:Team'),
                    _buildQueryChip('All Projects', 'project:Project'),
                    _buildQueryChip('Who Works Where', 'person:Person-[:WORKS_FOR]->team'),
                    _buildQueryChip('Who Leads What', 'person:Person-[:LEADS]->project'),
                    _buildQueryChip('Team Assignments', 'team:Team-[:ASSIGNED_TO]->project'),
                    _buildQueryChip('Management Chain', 'person:Person-[:MANAGES]->team'),
                    _buildQueryChip('Engineering Members', 'team:Team{label=Engineering}<-[:WORKS_FOR]-person'),
                    _buildRowsQueryChip('Alice\'s Access Path', 'person:Person{label~Alice}-[:WORKS_FOR]->team-[:ASSIGNED_TO]->project'),
                  ],
                ),

                const SizedBox(height: 8),
                const Text('Cypher-Style (with MATCH):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    _buildQueryChip('MATCH All People', 'MATCH person:Person'),
                    _buildQueryChip('MATCH Work Relations', 'MATCH person:Person-[:WORKS_FOR]->team'),
                    _buildQueryChip('MATCH Multi-hop', 'MATCH person:Person-[:WORKS_FOR]->team-[:ASSIGNED_TO]->project'),
                  ],
                ),
                const SizedBox(height: 16),

                // Query results
                if (queryResults != null) ...[
                  const Text('Results:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: queryResults!.entries.map((entry) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('${entry.key}:', style: const TextStyle(fontWeight: FontWeight.bold)),
                                  ...entry.value.map((id) => Text('  • $id')),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ),
                ] else if (queryRows != null) ...[
                  const Text('Row Results (chains):', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: queryRows!.map((row) {
                            final pId = row['person'];
                            final tId = row['team'];
                            final prId = row['project'];
                            final p = pId == null ? '' : (graph.nodesById[pId]?.label ?? pId);
                            final t = tId == null ? '' : (graph.nodesById[tId]?.label ?? tId);
                            final pr = prId == null ? '' : (graph.nodesById[prId]?.label ?? prId);
                            final text = (pId != null && tId != null && prId != null)
                                ? '$p → $t → $pr'
                                : row.entries.map((e) => '${e.key}=${e.value}').join('  ');
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Text('• $text'),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 16),

                // Node inspector
                if (selectedNodeId != null) ...[
                  const Text('Selected Node:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      border: Border.all(color: Colors.blue.shade300),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: _buildNodeInfo(selectedNodeId!),
                  ),
                ],
              ],
            ),
          ),

          // Right panel - Graph visualization + code box
          Expanded(
            child: Column(
              children: [
                Expanded(
                  child: InteractiveViewer(
                    boundaryMargin: const EdgeInsets.all(20),
                    minScale: 0.5,
                    maxScale: 3.0,
                    child: CustomPaint(
                      painter: GraphPainter(
                        graph: graph,
                        queryResults: queryResults,
                        selectedNodeId: selectedNodeId,
                        onNodeTap: (nodeId) => setState(() => selectedNodeId = nodeId),
                        highlightEdgeTypes: _highlightEdgeTypes,
                        highlightNodeIds: _highlightNodeIds,
                      ),
                      size: Size.infinite,
                    ),
                  ),
                ),

                // Current query display
                if (_lastPattern != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      children: [
                        const Text('Query: ', style: TextStyle(fontWeight: FontWeight.bold)),
                        Expanded(
                          child: Text(
                            _lastPattern!,
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 14,
                              color: Colors.blue,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Copy query to clipboard',
                          icon: const Icon(Icons.copy, size: 16),
                          onPressed: () async {
                            await Clipboard.setData(ClipboardData(text: _lastPattern!));
                          },
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 8),
                // Toggle + copy actions
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      const Text('Graph Setup Code', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(width: 8),
                      Switch(
                        value: _showCode,
                        onChanged: (v) => setState(() => _showCode = v),
                      ),
                      const Spacer(),
                      IconButton(
                        tooltip: 'Copy to clipboard',
                        icon: const Icon(Icons.copy, size: 18),
                        onPressed: () async {
                          await Clipboard.setData(ClipboardData(text: _graphSetupCode));
                        },
                      ),
                    ],
                  ),
                ),
                if (_showCode)
                  Container(
                    margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    constraints: const BoxConstraints(maxHeight: 220),
                    child: SingleChildScrollView(
                      child: SelectableText(
                        _graphSetupCode,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNodeInfo(String nodeId) {
    final node = graph.nodesById[nodeId];
    if (node == null) return const Text('Node not found');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('ID: ${node.id}'),
        Text('Type: ${node.type}'),
        Text('Label: ${node.label}'),
        if (node.properties != null) ...[
          const SizedBox(height: 4),
          const Text('Properties:', style: TextStyle(fontWeight: FontWeight.bold)),
          ...node.properties!.entries.map((e) => Text('  ${e.key}: ${e.value}')),
        ],
      ],
    );
  }

  Widget _buildQueryChip(String label, String pattern, {String? startId}) {
    return ActionChip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      onPressed: () {
        setState(() {
          _queryController.text = pattern;
        });
        _executeQueryWithStartId(pattern, startId);
      },
      backgroundColor: Colors.blue.shade50,
      side: BorderSide(color: Colors.blue.shade200),
    );
  }

  Widget _buildRowsQueryChip(String label, String pattern, {String? startId}) {
    return ActionChip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      onPressed: () {
        setState(() {
          _queryController.text = pattern;
        });
        _executeRowsQueryWithStartId(pattern, startId);
      },
      backgroundColor: Colors.purple.shade50,
      side: BorderSide(color: Colors.purple.shade200),
    );
  }

  void _executeQueryWithStartId(String pattern, String? startId) {
    if (pattern.isEmpty) {
      setState(() => queryResults = null);
      return;
    }

    try {
      final results = startId != null
          ? query.match(pattern, startId: startId)
          : query.match(pattern);
      debugPrint('Query: $pattern, StartId: $startId, Results: $results');
      _lastPattern = pattern;
      _highlightEdgeTypes = _extractEdgeTypes(pattern);
      setState(() {
        queryRows = null;
        queryResults = results;
      });
    } catch (e) {
       setState(() => queryResults = {'error': {'Query failed: ${e.toString()}'}});
    }
  }

  void _executeRowsQueryWithStartId(String pattern, String? startId) {
    if (pattern.isEmpty) {
      setState(() => queryRows = null);
      return;
    }

    try {
      final rows = startId != null
          ? query.matchRows(pattern, startId: startId)
          : query.matchRows(pattern);
      debugPrint('Rows Query: $pattern, StartId: $startId, Rows: ${rows.length}');
      _lastPattern = pattern;
      _highlightEdgeTypes = _extractEdgeTypes(pattern);
      // Build highlighted nodes from row results
      final hi = <String>{};
      for (final r in rows) {
        for (final v in r.values) {
          hi.add(v);
        }
      }
      _highlightNodeIds = hi;
      setState(() {
        queryResults = null;
        queryRows = rows;
      });
    } catch (e) {
      debugPrint('Rows query error: $e');
      setState(() => queryRows = [
        {'error': 'Query failed: $e'}
      ]);
    }
  }

  // --- Helpers to render a code box reflecting the current graph setup ---
  String _buildGraphSetupCode() {
    final buf = StringBuffer();
    buf.writeln("import 'package:graph_kit/graph_kit.dart';");
    buf.writeln('');
    buf.writeln('final graph = Graph<Node>();');
    buf.writeln('');

    // Nodes (sorted by id for stable output)
    buf.writeln('// Nodes');
    final nodes = graph.nodesById.values.toList()
      ..sort((a, b) => a.id.compareTo(b.id));
    for (final n in nodes) {
      final props = (n.properties != null && n.properties!.isNotEmpty)
          ? ", properties: ${_formatMap(n.properties!)}"
          : '';
      buf.writeln("graph.addNode(Node(id: '${_escapeSingleQuotes(n.id)}', type: '${_escapeSingleQuotes(n.type)}', label: '${_escapeSingleQuotes(n.label)}'$props));");
    }

    buf.writeln('');
    buf.writeln('// Edges');
    // Edges (sorted by src -> type -> dst)
    final srcIds = graph.out.keys.toList()..sort();
    for (final src in srcIds) {
      final types = graph.out[src]!.keys.toList()..sort();
      for (final t in types) {
        final dsts = graph.out[src]![t]!.toList()..sort();
        for (final dst in dsts) {
          buf.writeln("graph.addEdge('${_escapeSingleQuotes(src)}', '${_escapeSingleQuotes(t)}', '${_escapeSingleQuotes(dst)}');");
        }
      }
    }

    return buf.toString();
  }

  String _formatMap(Map<String, dynamic> map) {
    final entries = map.entries.map((e) => "'${_escapeSingleQuotes(e.key)}': ${_formatValue(e.value)}").join(', ');
    return '{$entries}';
  }

  String _formatValue(dynamic v) {
    if (v is String) return "'${_escapeSingleQuotes(v)}'";
    if (v is num || v is bool) return v.toString();
    if (v is List) {
      final items = v.map(_formatValue).join(', ');
      return '[$items]';
    }
    if (v is Map) {
      final converted = <String, dynamic>{
        for (final entry in v.entries) entry.key.toString(): entry.value
      };
      return _formatMap(converted);
    }
    return "'${_escapeSingleQuotes(v.toString())}'";
  }

  String _escapeSingleQuotes(String s) => s.replaceAll("'", r"\'");

  Set<String> _extractEdgeTypes(String pattern) {
    final types = <String>{};
    final re = RegExp(r'\[\s*:\s*([A-Za-z_][A-Za-z0-9_]*)\s*\]');
    for (final m in re.allMatches(pattern)) {
      final t = m.group(1);
      if (t != null && t.isNotEmpty) types.add(t);
    }
    return types;
  }
}

class GraphPainter extends CustomPainter {
  final Graph<Node> graph;
  final Map<String, Set<String>>? queryResults;
  final String? selectedNodeId;
  final Function(String) onNodeTap;
  final Set<String> highlightEdgeTypes;
  final Set<String> highlightNodeIds;

  // Matrix-based layout - calculate positions dynamically
  Map<String, Offset> get nodePositions {
    final positions = <String, Offset>{};

    // Group nodes by type
    final people = <String>[];
    final teams = <String>[];
    final projects = <String>[];

    for (final node in graph.nodesById.values) {
      switch (node.type) {
        case 'Person':
          people.add(node.id);
        case 'Team':
          teams.add(node.id);
        case 'Project':
          projects.add(node.id);
      }
    }

    // Sort for consistent positioning
    people.sort();
    teams.sort();
    projects.sort();

    // Layout parameters
    const double columnWidth = 250.0;
    const double rowHeight = 120.0;
    const double startX = 150.0;
    const double startY = 100.0;

    // Position people in first column
    for (int i = 0; i < people.length; i++) {
      positions[people[i]] = Offset(startX, startY + i * rowHeight);
    }

    // Position teams in second column
    for (int i = 0; i < teams.length; i++) {
      positions[teams[i]] = Offset(startX + columnWidth, startY + i * rowHeight);
    }

    // Position projects in third column
    for (int i = 0; i < projects.length; i++) {
      positions[projects[i]] = Offset(startX + 2 * columnWidth, startY + i * rowHeight);
    }

    return positions;
  }

  GraphPainter({
    required this.graph,
    this.queryResults,
    this.selectedNodeId,
    required this.onNodeTap,
    this.highlightEdgeTypes = const {},
    this.highlightNodeIds = const {},
  });

  @override
  void paint(Canvas canvas, Size size) {
    _drawEdges(canvas);
    _drawNodes(canvas);
  }

  void _drawEdges(Canvas canvas) {
    final paint = Paint()
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    for (final srcId in graph.out.keys) {
      final srcPos = nodePositions[srcId];
      if (srcPos == null) continue;

      final edgesByType = graph.out[srcId]!;
      for (final edgeType in edgesByType.keys) {
        final dstIds = edgesByType[edgeType]!;
        for (final dstId in dstIds) {
          final dstPos = nodePositions[dstId];
          if (dstPos == null) continue;

          // Check if this edge is part of query results
          final isHighlighted = _isEdgeHighlighted(srcId, dstId, edgeType);
          paint.color = isHighlighted ? Colors.red.shade700 : Colors.grey.shade600;
          paint.strokeWidth = isHighlighted ? 4 : 2;

          // Draw arrow
          _drawArrow(canvas, srcPos, dstPos, paint);

          // Draw edge label with better positioning
          final direction = (dstPos - srcPos).normalized();
          final midPoint = Offset(
            (srcPos.dx + dstPos.dx) / 2,
            (srcPos.dy + dstPos.dy) / 2,
          );
          // Simple perpendicular offset for edge labels
          final labelOffset = Offset(-direction.dy * 20, direction.dx * 20);
          final labelPos = midPoint + labelOffset;

          _drawTextWithBackground(canvas, edgeType, labelPos,
              isHighlighted ? Colors.red.shade800 : Colors.grey.shade700);
        }
      }
    }
  }

  void _drawNodes(Canvas canvas) {
    for (final node in graph.nodesById.values) {
      final pos = nodePositions[node.id];
      if (pos == null) continue;

      final isSelected = selectedNodeId == node.id;
      final isHighlighted = _isNodeHighlighted(node.id);

      // Node color based on type
      Color nodeColor = switch (node.type) {
        'Person' => Colors.blue,
        'Team' => Colors.green,
        'Project' => Colors.orange,
        _ => Colors.grey,
      };

      if (isHighlighted) nodeColor = nodeColor.withValues(alpha: 0.8);
      if (isSelected) nodeColor = nodeColor.withValues(alpha: 1.0);

      // Draw node circle
      final paint = Paint()
        ..color = nodeColor
        ..style = PaintingStyle.fill;

      final radius = isSelected ? 35.0 : 30.0;
      canvas.drawCircle(pos, radius, paint);

      // Draw border if selected or highlighted
      if (isSelected || isHighlighted) {
        final borderPaint = Paint()
          ..color = isSelected ? Colors.black : Colors.red.shade700
          ..style = PaintingStyle.stroke
          ..strokeWidth = isSelected ? 4 : 3;
        canvas.drawCircle(pos, radius, borderPaint);
      }

      // Draw node label
      _drawText(canvas, node.label, pos + const Offset(0, 50), Colors.black);
    }
  }

  void _drawArrow(Canvas canvas, Offset start, Offset end, Paint paint) {
    // Calculate direction and shorten line to node edge
    final direction = (end - start).normalized();
    final adjustedStart = start + direction * 30;
    final adjustedEnd = end - direction * 30;

    // Draw line
    canvas.drawLine(adjustedStart, adjustedEnd, paint);

    // Draw arrowhead
    final arrowLength = 15.0;
    final arrowAngle = math.pi / 6;

    final arrowPoint1 = adjustedEnd + Offset(
      -arrowLength * math.cos(-arrowAngle + direction.angle),
      -arrowLength * math.sin(-arrowAngle + direction.angle),
    );

    final arrowPoint2 = adjustedEnd + Offset(
      -arrowLength * math.cos(arrowAngle + direction.angle),
      -arrowLength * math.sin(arrowAngle + direction.angle),
    );

    final arrowPath = Path()
      ..moveTo(adjustedEnd.dx, adjustedEnd.dy)
      ..lineTo(arrowPoint1.dx, arrowPoint1.dy)
      ..lineTo(arrowPoint2.dx, arrowPoint2.dy)
      ..close();

    canvas.drawPath(arrowPath, paint..style = PaintingStyle.fill);
    paint.style = PaintingStyle.stroke;
  }

  void _drawText(Canvas canvas, String text, Offset position, Color color) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w500),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(canvas, position - Offset(textPainter.width / 2, textPainter.height / 2));
  }

  void _drawTextWithBackground(Canvas canvas, String text, Offset position, Color textColor) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: textColor,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();

    final textOffset = position - Offset(textPainter.width / 2, textPainter.height / 2);

    // Draw background rectangle with more padding
    final backgroundRect = Rect.fromLTWH(
      textOffset.dx - 4,
      textOffset.dy - 2,
      textPainter.width + 8,
      textPainter.height + 4,
    );

    final backgroundPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.95)
      ..style = PaintingStyle.fill;

    canvas.drawRRect(
      RRect.fromRectAndRadius(backgroundRect, const Radius.circular(2)),
      backgroundPaint,
    );

    // Draw border
    final borderPaint = Paint()
      ..color = Colors.grey.shade400
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;

    canvas.drawRRect(
      RRect.fromRectAndRadius(backgroundRect, const Radius.circular(2)),
      borderPaint,
    );

    // Draw text
    textPainter.paint(canvas, textOffset);
  }

  bool _isNodeHighlighted(String nodeId) => highlightNodeIds.contains(nodeId);

  bool _isEdgeHighlighted(String srcId, String dstId, String edgeType) {
    // Highlight only if both nodes are in the current highlighted set and
    // the edge type is part of the current pattern (if specified)
    final nodesOk = _isNodeHighlighted(srcId) && _isNodeHighlighted(dstId);
    if (!nodesOk) return false;
    if (highlightEdgeTypes.isEmpty) return nodesOk;
    return highlightEdgeTypes.contains(edgeType);
  }

  @override
  bool shouldRepaint(GraphPainter oldDelegate) {
    return oldDelegate.queryResults != queryResults ||
           oldDelegate.selectedNodeId != selectedNodeId ||
           !_setEqual(oldDelegate.highlightNodeIds, highlightNodeIds) ||
           !_setEqual(oldDelegate.highlightEdgeTypes, highlightEdgeTypes);
  }

  @override
  bool hitTest(Offset position) => true;

  bool _setEqual<T>(Set<T> a, Set<T> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    return a.containsAll(b);
  }
}

extension OffsetExtension on Offset {
  Offset normalized() {
    final magnitude = distance;
    if (magnitude == 0) return const Offset(0, 0);
    return this / magnitude;
  }

  double get angle => math.atan2(dy, dx);
}