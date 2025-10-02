import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:graph_kit/graph_kit.dart';
import 'package:graph_kit/graph_kit.dart' as petit;
import 'dart:math' as math;

class GraphKitDemo extends StatelessWidget {
  const GraphKitDemo({super.key});

  @override
  Widget build(BuildContext context) {
    return const GraphVisualization();
  }
}

class GraphVisualization extends StatefulWidget {
  const GraphVisualization({super.key});

  @override
  State<GraphVisualization> createState() => _GraphVisualizationState();
}

class _GraphVisualizationState extends State<GraphVisualization> {
  late Graph<Node> graph;
  late PatternQuery query;
  final TextEditingController _queryController = TextEditingController();
  Map<String, Set<String>>? queryResults;
  List<Map<String, dynamic>>? queryRows;
  List<petit.PathMatch>? queryPaths;
  String? selectedNodeId;
  bool _showCode = true;
  late String _graphSetupCode;
  String? lastPattern;
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
    graph.addNode(
      Node(
        id: 'alice',
        type: 'Person',
        label: 'Alice Cooper',
        properties: {'role': 'Developer', 'level': 'Senior'},
      ),
    );
    graph.addNode(
      Node(
        id: 'bob',
        type: 'Person',
        label: 'Bob Wilson',
        properties: {'role': 'Developer', 'level': 'Junior'},
      ),
    );
    graph.addNode(
      Node(
        id: 'charlie',
        type: 'Person',
        label: 'Charlie Davis',
        properties: {'role': 'Manager', 'level': 'Director'},
      ),
    );

    // Add teams
    graph.addNode(
      Node(
        id: 'engineering',
        type: 'Team',
        label: 'Engineering',
        properties: {'size': 15, 'budget': 150000},
      ),
    );
    graph.addNode(
      Node(
        id: 'design',
        type: 'Team',
        label: 'Design Team',
        properties: {'size': 5, 'budget': 80000},
      ),
    );
    graph.addNode(
      Node(
        id: 'marketing',
        type: 'Team',
        label: 'Marketing',
        properties: {'size': 8, 'budget': 120000},
      ),
    );

    // Add projects
    graph.addNode(
      Node(
        id: 'web_app',
        type: 'Project',
        label: 'Web Application',
        properties: {'status': 'active', 'priority': 'high'},
      ),
    );
    graph.addNode(
      Node(
        id: 'mobile_app',
        type: 'Project',
        label: 'Mobile App',
        properties: {'status': 'planning', 'priority': 'medium'},
      ),
    );
    graph.addNode(
      Node(
        id: 'campaign',
        type: 'Project',
        label: 'Ad Campaign',
        properties: {'status': 'active', 'priority': 'high'},
      ),
    );

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
      setState(() {
        queryResults = null;
        queryRows = null;
        queryPaths = null;
        _highlightEdgeTypes = const {};
        _highlightNodeIds = const {};
      });
      return;
    }

    try {
      final results = query.match(pattern);
      final paths = query.matchPaths(pattern);
      lastPattern = pattern;
      _highlightEdgeTypes = _extractEdgeTypes(paths);
      // Build highlighted nodes from grouped results
      final hi = <String>{};
      for (final s in results.values) {
        hi.addAll(s);
      }
      _highlightNodeIds = hi;
      setState(() {
        queryRows = null;
        queryResults = results;
        queryPaths = paths;
      });
    } catch (e) {
      debugPrint('Query error: $e');
      setState(() {
        queryResults = {
          'error': {'Query failed: $e'},
        };
        queryRows = null;
        queryPaths = null;
        _highlightEdgeTypes = const {};
        _highlightNodeIds = const {};
      });
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
                // Preset queries
                const Text(
                  'Quick Queries:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    // Basic queries
                    _buildQueryChip('All People', 'person:Person'),
                    _buildQueryChip('All Teams', 'team:Team'),
                    _buildQueryChip('All Projects', 'project:Project'),

                    // Full chain examples - these show complete paths!
                    _buildQueryChip(
                      '🛤️ Work Chain',
                      'person:Person-[:WORKS_FOR]->team-[:ASSIGNED_TO]->project',
                    ),
                    _buildQueryChip(
                      '🛤️ Management Chain',
                      'person:Person-[:MANAGES]->team-[:ASSIGNED_TO]->project',
                    ),

                    // Multiple edge types - NEW! Show OR semantics
                    _buildQueryChip(
                      '🔀 Works OR Manages',
                      'person:Person-[:WORKS_FOR|MANAGES]->team',
                    ),
                    _buildQueryChip(
                      '🔀 Multi-Type Chain',
                      'person-[:WORKS_FOR|MANAGES]->team-[:ASSIGNED_TO]->project',
                    ),

                    // Mixed direction patterns - NEW! Find common connections
                    _buildQueryChip(
                      '🔄 Coworkers',
                      'person1-[:WORKS_FOR]->team<-[:MANAGES]-manager',
                    ),
                    _buildQueryChip(
                      '🔄 Common Team',
                      'person1-[:WORKS_FOR]->team<-[:WORKS_FOR]-person2',
                    ),
                    _buildQueryChip(
                      '🔄 Team & Project',
                      'person-[:WORKS_FOR]->team-[:ASSIGNED_TO]->project<-[:LEADS]-leader',
                    ),

                    // Simple 2-hop chains
                    _buildQueryChip(
                      'Who Works Where',
                      'person:Person-[:WORKS_FOR]->team',
                    ),
                    _buildQueryChip(
                      'Team Projects',
                      'team:Team-[:ASSIGNED_TO]->project',
                    ),
                    _buildQueryChip(
                      'Project Leaders',
                      'project:Project<-[:LEADS]-person',
                    ),

                    // Filtered examples
                    _buildQueryChip(
                      'Engineering Team',
                      'team:Team{label=Engineering}<-[:WORKS_FOR]-person',
                    ),

                    // StartId examples - specific starting points
                    const SizedBox(width: 16), // spacer
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Specific Starting Points:',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange.shade800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _buildStartIdQueryChip(
                      '🎯 Alice\'s Path',
                      'person-[:WORKS_FOR]->team-[:ASSIGNED_TO]->project',
                      'alice',
                    ),
                    _buildStartIdQueryChip(
                      '🎯 Bob\'s Work Path',
                      'person-[:WORKS_FOR]->team-[:ASSIGNED_TO]->project',
                      'bob',
                    ),
                    _buildStartIdQueryChip(
                      '🎯 Charlie\'s Management',
                      'person-[:MANAGES]->team-[:ASSIGNED_TO]->project',
                      'charlie',
                    ),
                    _buildStartIdQueryChip(
                      '🎯 Web App Team',
                      'project<-[:ASSIGNED_TO]-team<-[:WORKS_FOR]-person',
                      'web_app',
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Query results
                if (queryResults != null) ...[
                  const Text(
                    'Results:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
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
                          children: _getSortedResultEntries(queryResults!).map((
                            entry,
                          ) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${entry.key}:',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
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
                  const Text(
                    'Row Results (chains):',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
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
                            final p = pId == null
                                ? ''
                                : (graph.nodesById[pId]?.label ?? pId);
                            final t = tId == null
                                ? ''
                                : (graph.nodesById[tId]?.label ?? tId);
                            final pr = prId == null
                                ? ''
                                : (graph.nodesById[prId]?.label ?? prId);
                            final text =
                                (pId != null && tId != null && prId != null)
                                ? '$p → $t → $pr'
                                : row.entries
                                      .map((e) => '${e.key}=${e.value}')
                                      .join('  ');
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
                  const Text(
                    'Selected Node:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
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
                // Query input field - moved from left panel
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _queryController,
                          maxLines: 2,
                          minLines: 1,
                          style: const TextStyle(
                            fontSize: 12,
                            fontFamily: 'monospace',
                          ),
                          decoration: const InputDecoration(
                            hintText:
                                'e.g., person:Person-[:WORKS_FOR]->team-[:ASSIGNED_TO]->project',
                            hintStyle: TextStyle(fontSize: 11),
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 8,
                            ),
                            isDense: true,
                          ),
                          onSubmitted: (_) => _executeQuery(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: _executeQuery,
                        child: const Text('Execute'),
                      ),
                      const SizedBox(width: 4),
                      ElevatedButton(
                        onPressed: () => setState(() {
                          _queryController.clear();
                          queryResults = null;
                          queryRows = null;
                          queryPaths = null;
                          lastPattern = null;
                          _highlightEdgeTypes = const {};
                          _highlightNodeIds = const {};
                        }),
                        child: const Text('Clear'),
                      ),
                    ],
                  ),
                ),

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
                        onNodeTap: (nodeId) =>
                            setState(() => selectedNodeId = nodeId),
                        highlightEdgeTypes: _highlightEdgeTypes,
                        highlightNodeIds: _highlightNodeIds,
                      ),
                      size: Size.infinite,
                    ),
                  ),
                ),

                const SizedBox(height: 8),
                // Toggle + copy actions
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      const Text(
                        'Graph Setup Code',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
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
                          await Clipboard.setData(
                            ClipboardData(text: _graphSetupCode),
                          );
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

                // Path Results (routes) - Full width below graph
                if (queryPaths != null && queryPaths!.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text(
                              '🛤️ Complete Paths',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade100,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '${queryPaths!.length}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.blue.shade800,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            border: Border.all(color: Colors.blue.shade200),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: queryPaths!.asMap().entries.map((entry) {
                              final index = entry.key;
                              final path = entry.value;
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 28,
                                      height: 28,
                                      decoration: BoxDecoration(
                                        color: Colors.blue.shade600,
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      child: Center(
                                        child: Text(
                                          '${index + 1}',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        _buildSimplePathDescription(path),
                                        style: const TextStyle(
                                          fontSize: 15,
                                          fontFamily: 'monospace',
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
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
          const Text(
            'Properties:',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          ...node.properties!.entries.map(
            (e) => Text('  ${e.key}: ${e.value}'),
          ),
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

  Widget _buildStartIdQueryChip(String label, String pattern, String startId) {
    return ActionChip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      onPressed: () {
        setState(() {
          _queryController.text = pattern;
        });
        _executeQueryWithStartId(pattern, startId);
      },
      backgroundColor: Colors.orange.shade50,
      side: BorderSide(color: Colors.orange.shade300),
    );
  }

  Widget buildRowsQueryChip(String label, String pattern, {String? startId}) {
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
      setState(() {
        queryResults = null;
        queryRows = null;
        queryPaths = null;
        _highlightEdgeTypes = const {};
        _highlightNodeIds = const {};
      });
      return;
    }

    try {
      final results = startId != null
          ? query.match(pattern, startId: startId)
          : query.match(pattern);
      final paths = startId != null
          ? query.matchPaths(pattern, startId: startId)
          : query.matchPaths(pattern);
      debugPrint('Query: $pattern, StartId: $startId, Results: $results');
      lastPattern = pattern;
      _highlightEdgeTypes = _extractEdgeTypes(paths);
      // Build highlighted nodes from grouped results
      final hi = <String>{};
      for (final s in results.values) {
        hi.addAll(s);
      }
      _highlightNodeIds = hi;
      debugPrint('Highlight Edge Types: $_highlightEdgeTypes');
      debugPrint('Highlight Node IDs: $_highlightNodeIds');
      setState(() {
        queryRows = null;
        queryResults = results;
        queryPaths = paths;
      });
    } catch (e) {
      setState(() {
        queryResults = {
          'error': {'Query failed: ${e.toString()}'},
        };
        queryRows = null;
        queryPaths = null;
        _highlightEdgeTypes = const {};
        _highlightNodeIds = const {};
      });
    }
  }

  void _executeRowsQueryWithStartId(String pattern, String? startId) {
    if (pattern.isEmpty) {
      setState(() {
        queryRows = null;
        _highlightEdgeTypes = const {};
        _highlightNodeIds = const {};
      });
      return;
    }

    try {
      final rows = startId != null
          ? query.matchRows(pattern, startId: startId)
          : query.matchRows(pattern);
      final paths = startId != null
          ? query.matchPaths(pattern, startId: startId)
          : query.matchPaths(pattern);
      debugPrint(
        'Rows Query: $pattern, StartId: $startId, Rows: ${rows.length}',
      );
      lastPattern = pattern;
      _highlightEdgeTypes = _extractEdgeTypes(paths);
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
      setState(() {
        queryRows = [
          {'error': 'Query failed: $e'},
        ];
        _highlightEdgeTypes = const {};
        _highlightNodeIds = const {};
      });
    }
  }

  // --- Helper to build simple, readable path description ---
  String _buildSimplePathDescription(petit.PathMatch path) {
    final orderedVars = _orderPathVariables(path.nodes.keys.toList(), path);
    final parts = <String>[];

    for (final variable in orderedVars) {
      final nodeId = path.nodes[variable];
      final node = nodeId != null ? graph.nodesById[nodeId] : null;
      final label = node?.label ?? nodeId ?? variable;
      parts.add(label);
    }

    return parts.join(' → ');
  }

  // --- Helper to build detailed path description ---
  String buildPathDescription(petit.PathMatch path) {
    final parts = <String>[];

    // Get the variables in a logical order for path display
    final variables = path.nodes.keys.toList();
    variables.sort(); // Sort alphabetically as fallback

    // Try to order by common patterns (person -> team -> project, etc.)
    final orderedVars = _orderPathVariables(variables, path);

    for (var i = 0; i < orderedVars.length; i++) {
      final variable = orderedVars[i];
      final nodeId = path.nodes[variable];
      final node = nodeId != null ? graph.nodesById[nodeId] : null;
      final label = node?.label ?? nodeId ?? variable;

      if (i == 0) {
        parts.add(label);
      } else {
        // Try to find the edge type between previous and current variable
        final prevVar = orderedVars[i - 1];
        final edgeType = _findEdgeTypeBetween(path, prevVar, variable);
        parts.add(' -[:${edgeType ?? "?"}]-> $label');
      }
    }

    return parts.join('');
  }

  List<String> _orderPathVariables(List<String> variables, petit.PathMatch path) {
    // Common ordering patterns
    final priority = {
      'person': 0,
      'user': 0,
      'employee': 0,
      'member': 0,
      'team': 10,
      'group': 10,
      'department': 10,
      'project': 20,
      'task': 20,
      'initiative': 20,
      'resource': 30,
      'asset': 30,
      'database': 30,
    };

    variables.sort((a, b) {
      final aScore = priority[a.toLowerCase()] ?? 50;
      final bScore = priority[b.toLowerCase()] ?? 50;
      if (aScore != bScore) return aScore.compareTo(bScore);
      return a.compareTo(b);
    });

    return variables;
  }

  String? _findEdgeTypeBetween(petit.PathMatch path, String fromVar, String toVar) {
    final fromId = path.nodes[fromVar];
    final toId = path.nodes[toVar];

    if (fromId == null || toId == null) return null;

    // Find edge between these two nodes
    for (final edge in path.edges) {
      if ((edge.fromVariable == fromVar && edge.toVariable == toVar) ||
          (edge.fromVariable == toVar && edge.toVariable == fromVar)) {
        return edge.type;
      }
    }

    return null;
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
      buf.writeln(
        "graph.addNode(Node(id: '${_escapeSingleQuotes(n.id)}', type: '${_escapeSingleQuotes(n.type)}', label: '${_escapeSingleQuotes(n.label)}'$props));",
      );
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
          buf.writeln(
            "graph.addEdge('${_escapeSingleQuotes(src)}', '${_escapeSingleQuotes(t)}', '${_escapeSingleQuotes(dst)}');",
          );
        }
      }
    }

    return buf.toString();
  }

  String _formatMap(Map<String, dynamic> map) {
    final entries = map.entries
        .map((e) => "'${_escapeSingleQuotes(e.key)}': ${_formatValue(e.value)}")
        .join(', ');
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
        for (final entry in v.entries) entry.key.toString(): entry.value,
      };
      return _formatMap(converted);
    }
    return "'${_escapeSingleQuotes(v.toString())}'";
  }

  String _escapeSingleQuotes(String s) => s.replaceAll("'", r"\'");

  Set<String> _extractEdgeTypes(List<petit.PathMatch>? paths) {
    final types = <String>{};
    if (paths == null) return types;

    // Extract actual edge types from query results
    for (final path in paths) {
      for (final edge in path.edges) {
        types.add(edge.type);
      }
    }
    return types;
  }

  List<MapEntry<String, Set<String>>> _getSortedResultEntries(
    Map<String, Set<String>> results,
  ) {
    // Define the desired order based on visual layout: Person -> Team -> Project
    final typeOrder = ['person', 'team', 'project'];

    final sortedEntries = results.entries.toList();
    sortedEntries.sort((a, b) {
      final aIndex = typeOrder.indexWhere(
        (type) => a.key.toLowerCase().contains(type),
      );
      final bIndex = typeOrder.indexWhere(
        (type) => b.key.toLowerCase().contains(type),
      );

      // If both found in typeOrder, sort by their index
      if (aIndex != -1 && bIndex != -1) {
        return aIndex.compareTo(bIndex);
      }

      // If only one found, put found one first
      if (aIndex != -1) return -1;
      if (bIndex != -1) return 1;

      // If neither found, sort alphabetically
      return a.key.compareTo(b.key);
    });

    return sortedEntries;
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

    // Improved layout parameters for better spacing
    const double startX = 120.0;
    const double startY = 80.0;

    // Use a fan-out layout to minimize edge crossings
    // People on the left in a vertical column
    for (int i = 0; i < people.length; i++) {
      positions[people[i]] = Offset(startX, startY + i * 140.0);
    }

    // Teams in the middle, spread out vertically to align with connections
    for (int i = 0; i < teams.length; i++) {
      // Spread teams more to reduce crossing - space them further apart
      positions[teams[i]] = Offset(startX + 320.0, startY + i * 160.0);
    }

    // Projects on the right, positioned to align with their team connections
    if (projects.isNotEmpty) {
      // Sort projects to match expected connections: web_app, mobile_app, campaign
      final sortedProjects = [...projects];
      sortedProjects.sort((a, b) {
        // Custom sort to put web_app first, mobile_app second, campaign last
        final order = {'web_app': 0, 'mobile_app': 1, 'campaign': 2};
        return (order[a] ?? 99).compareTo(order[b] ?? 99);
      });

      for (int i = 0; i < sortedProjects.length; i++) {
        // Position projects to minimize crossings
        if (sortedProjects[i] == 'web_app') {
          // Align with engineering team
          positions[sortedProjects[i]] = Offset(startX + 640.0, startY + 80.0);
        } else if (sortedProjects[i] == 'mobile_app') {
          // Position between engineering and design
          positions[sortedProjects[i]] = Offset(startX + 640.0, startY + 200.0);
        } else if (sortedProjects[i] == 'campaign') {
          // Align with marketing team
          positions[sortedProjects[i]] = Offset(startX + 640.0, startY + 320.0);
        } else {
          // Fallback for other projects
          positions[sortedProjects[i]] = Offset(
            startX + 640.0,
            startY + i * 140.0,
          );
        }
      }
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
          paint.color = isHighlighted
              ? Colors.red.shade700
              : Colors.grey.shade600;
          paint.strokeWidth = isHighlighted ? 4 : 2;

          // Draw arrow with smart routing
          final labelPos = _drawSmartArrow(canvas, srcPos, dstPos, paint);

          // Draw edge label at the calculated position
          _drawTextWithBackground(
            canvas,
            edgeType,
            labelPos,
            isHighlighted ? Colors.red.shade800 : Colors.grey.shade700,
          );
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

      // Draw node shape by type: Team = square, Project = diamond, others = circle
      final paint = Paint()
        ..color = nodeColor
        ..style = PaintingStyle.fill;

      final radius = isSelected ? 35.0 : 30.0;
      final typeLc = node.type.toLowerCase();
      String glyph = 'P';
      if (typeLc == 'team') {
        // Square (sharp corners)
        final size = radius * 2;
        final rect = Rect.fromCenter(center: pos, width: size, height: size);
        canvas.drawRect(rect, paint);
        if (isSelected || isHighlighted) {
          final borderPaint = Paint()
            ..color = isSelected ? Colors.black : Colors.red.shade700
            ..style = PaintingStyle.stroke
            ..strokeWidth = isSelected ? 4 : 3;
          canvas.drawRect(rect, borderPaint);
        }
        glyph = 'T';
      } else if (typeLc == 'project') {
        // Diamond (rotated square)
        final size = radius * 2;
        final half = size / 2;
        final path = Path()
          ..moveTo(pos.dx, pos.dy - half)
          ..lineTo(pos.dx + half, pos.dy)
          ..lineTo(pos.dx, pos.dy + half)
          ..lineTo(pos.dx - half, pos.dy)
          ..close();
        canvas.drawPath(path, paint);
        if (isSelected || isHighlighted) {
          final borderPaint = Paint()
            ..color = isSelected ? Colors.black : Colors.red.shade700
            ..style = PaintingStyle.stroke
            ..strokeWidth = isSelected ? 4 : 3;
          canvas.drawPath(path, borderPaint);
        }
        glyph = 'PR';
      } else {
        // Circle (e.g., Person)
        canvas.drawCircle(pos, radius, paint);
        if (isSelected || isHighlighted) {
          final borderPaint = Paint()
            ..color = isSelected ? Colors.black : Colors.red.shade700
            ..style = PaintingStyle.stroke
            ..strokeWidth = isSelected ? 4 : 3;
          canvas.drawCircle(pos, radius, borderPaint);
        }
        glyph = 'P';
      }

      // Center glyph for quick visual verification of shape/type
      _drawText(canvas, glyph, pos, Colors.white);

      // Draw node label
      _drawText(canvas, node.label, pos + const Offset(0, 50), Colors.black);
    }
  }

  Offset _drawSmartArrow(Canvas canvas, Offset start, Offset end, Paint paint) {
    // Calculate direction and shorten line to node edge
    final direction = (end - start).normalized();
    final adjustedStart = start + direction * 30;
    final adjustedEnd = end - direction * 30;

    // Check if this connection would overlap any nodes (regardless of being diagonal)
    if (_wouldOverlapNode(adjustedStart, adjustedEnd)) {
      // Use curved path to avoid node overlaps
      return _drawCurvedArrow(canvas, adjustedStart, adjustedEnd, paint);
    } else {
      // Use straight line
      return _drawStraightArrow(canvas, adjustedStart, adjustedEnd, paint);
    }
  }

  bool _wouldOverlapNode(Offset start, Offset end) {
    // For cross-column connections (like person->project), always use curves
    final deltaX = (end.dx - start.dx).abs();
    if (deltaX > 300) {
      // This is a cross-column connection, always curve it
      return true;
    }

    // Check if the straight line path would pass too close to any node
    const nodeRadius = 60.0;

    for (final pos in nodePositions.values) {
      // Skip if this is the start or end node
      if ((pos - start).distance < 70 || (pos - end).distance < 70) continue;

      // Calculate distance from line to node center
      final distance = _distancePointToLine(pos, start, end);
      if (distance < nodeRadius) {
        // Check if the node is actually between start and end
        final projectionT = _projectionParameter(pos, start, end);
        if (projectionT > 0.1 && projectionT < 0.9) {
          return true;
        }
      }
    }
    return false;
  }

  double _distancePointToLine(Offset point, Offset lineStart, Offset lineEnd) {
    final lineLength = (lineEnd - lineStart).distance;
    if (lineLength == 0) return (point - lineStart).distance;

    final t =
        ((point.dx - lineStart.dx) * (lineEnd.dx - lineStart.dx) +
            (point.dy - lineStart.dy) * (lineEnd.dy - lineStart.dy)) /
        (lineLength * lineLength);

    final projection = lineStart + (lineEnd - lineStart) * t.clamp(0.0, 1.0);
    return (point - projection).distance;
  }

  double _projectionParameter(Offset point, Offset lineStart, Offset lineEnd) {
    final lineLength = (lineEnd - lineStart).distance;
    if (lineLength == 0) return 0.0;

    return ((point.dx - lineStart.dx) * (lineEnd.dx - lineStart.dx) +
            (point.dy - lineStart.dy) * (lineEnd.dy - lineStart.dy)) /
        (lineLength * lineLength);
  }

  Offset _drawCurvedArrow(
    Canvas canvas,
    Offset start,
    Offset end,
    Paint paint,
  ) {
    // Create a bezier curve that arcs around potential node overlaps
    final midX = (start.dx + end.dx) / 2;
    final midY = (start.dy + end.dy) / 2;

    // Determine curve direction based on positions
    final deltaX = end.dx - start.dx;
    final deltaY = end.dy - start.dy;

    // Simplified curve logic: use high arcs for cross-column connections
    double curveOffset;
    bool useSidewardCurve = false;

    // For cross-column connections (like alice->web_app), always use high arc
    if (deltaX.abs() > 300) {
      // High upward arc to go well above all nodes
      curveOffset = -120.0;
    } else if (deltaY.abs() < 30) {
      // Horizontal connection: arc upward to avoid middle nodes
      curveOffset = -60.0;
    } else if (deltaX.abs() < 100) {
      // Vertical connection: arc sideways
      curveOffset = -80.0;
      useSidewardCurve = true;
    } else {
      // Other diagonal connections
      curveOffset = deltaY > 0 ? -60.0 : 60.0;
    }

    final Offset controlPoint1, controlPoint2;

    if (useSidewardCurve) {
      // For vertical connections, curve sideways instead of up/down
      controlPoint1 = Offset(midX + curveOffset, start.dy + deltaY * 0.3);
      controlPoint2 = Offset(midX + curveOffset, end.dy - deltaY * 0.3);
    } else {
      // For horizontal/diagonal connections, curve up/down
      controlPoint1 = Offset(start.dx + deltaX * 0.3, midY + curveOffset);
      controlPoint2 = Offset(end.dx - deltaX * 0.3, midY + curveOffset);
    }

    final path = Path()
      ..moveTo(start.dx, start.dy)
      ..cubicTo(
        controlPoint1.dx,
        controlPoint1.dy,
        controlPoint2.dx,
        controlPoint2.dy,
        end.dx,
        end.dy,
      );

    canvas.drawPath(path, paint);

    // Draw arrowhead at the end
    final endDirection = (controlPoint2 - end).normalized();
    _drawArrowhead(canvas, end, endDirection, paint);

    // Return label position at the curve peak
    final Offset labelPos;
    if (useSidewardCurve) {
      // For sideways curves, place label to the side of the curve
      labelPos = Offset(midX + curveOffset - 15, midY);
    } else {
      // For up/down curves, place label above/below the curve
      labelPos = Offset(midX, midY + curveOffset + 15);
    }
    return labelPos;
  }

  Offset _drawStraightArrow(
    Canvas canvas,
    Offset start,
    Offset end,
    Paint paint,
  ) {
    // Draw straight line
    canvas.drawLine(start, end, paint);

    // Draw arrowhead
    final direction = (end - start).normalized();
    _drawArrowhead(canvas, end, direction, paint);

    // Return label position with perpendicular offset from midpoint
    final midPoint = Offset((start.dx + end.dx) / 2, (start.dy + end.dy) / 2);
    final labelOffset = Offset(-direction.dy * 20, direction.dx * 20);
    return midPoint + labelOffset;
  }

  void _drawArrowhead(
    Canvas canvas,
    Offset position,
    Offset direction,
    Paint paint,
  ) {
    final arrowLength = 15.0;
    final arrowAngle = math.pi / 6;

    final arrowPoint1 =
        position +
        Offset(
          -arrowLength * math.cos(-arrowAngle + direction.angle),
          -arrowLength * math.sin(-arrowAngle + direction.angle),
        );

    final arrowPoint2 =
        position +
        Offset(
          -arrowLength * math.cos(arrowAngle + direction.angle),
          -arrowLength * math.sin(arrowAngle + direction.angle),
        );

    final arrowPath = Path()
      ..moveTo(position.dx, position.dy)
      ..lineTo(arrowPoint1.dx, arrowPoint1.dy)
      ..lineTo(arrowPoint2.dx, arrowPoint2.dy)
      ..close();

    final oldStyle = paint.style;
    paint.style = PaintingStyle.fill;
    canvas.drawPath(arrowPath, paint);
    paint.style = oldStyle;
  }

  void _drawText(Canvas canvas, String text, Offset position, Color color) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      position - Offset(textPainter.width / 2, textPainter.height / 2),
    );
  }

  void _drawTextWithBackground(
    Canvas canvas,
    String text,
    Offset position,
    Color textColor,
  ) {
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

    final textOffset =
        position - Offset(textPainter.width / 2, textPainter.height / 2);

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

