import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:graph_kit/graph_kit.dart';
import 'package:graph_kit/graph_kit.dart' as petit;
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
      home: const DemoSelector(),
    );
  }
}

enum DemoMode {
  patternQueries('Pattern Queries', 'Query graphs with Cypher-like patterns'),
  algorithms('Graph Algorithms', 'Visualize shortest paths, components, and more');

  const DemoMode(this.title, this.description);
  final String title;
  final String description;
}

class DemoSelector extends StatefulWidget {
  const DemoSelector({super.key});

  @override
  State<DemoSelector> createState() => _DemoSelectorState();
}

class _DemoSelectorState extends State<DemoSelector> {
  DemoMode currentMode = DemoMode.patternQueries;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Graph Kit Demo'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: DemoMode.values.map((mode) {
                final isSelected = currentMode == mode;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: ElevatedButton(
                      onPressed: () => setState(() => currentMode = mode),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isSelected
                            ? Theme.of(context).primaryColor
                            : Colors.grey.shade200,
                        foregroundColor: isSelected
                            ? Colors.white
                            : Colors.grey.shade700,
                        elevation: isSelected ? 4 : 1,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            mode.title,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            mode.description,
                            style: const TextStyle(fontSize: 10),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ),
      body: switch (currentMode) {
        DemoMode.patternQueries => const GraphVisualization(),
        DemoMode.algorithms => const AlgorithmsVisualization(),
      },
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
  late PatternQuery query;
  final TextEditingController _queryController = TextEditingController();
  Map<String, Set<String>>? queryResults;
  List<Map<String, String>>? queryRows;
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

enum AlgorithmMode {
  shortestPath('Shortest Path', 'Find optimal routes between nodes'),
  connectedComponents('Connected Components', 'Group related nodes'),
  reachability('Reachable From', 'See what nodes can be reached from a source'),
  reachableBy('Reachable By', 'See what nodes can reach a target'),
  reachableAll('Bidirectional Reach', 'See all nodes connected in either direction'),
  topologicalSort('Topological Sort', 'Order nodes by dependencies'),
  betweennessCentrality('Betweenness Centrality', 'Find critical bridge nodes'),
  closenessCentrality('Closeness Centrality', 'Find nodes closest to all others');

  const AlgorithmMode(this.title, this.description);
  final String title;
  final String description;
}

class AlgorithmsVisualization extends StatefulWidget {
  const AlgorithmsVisualization({super.key});

  @override
  State<AlgorithmsVisualization> createState() => _AlgorithmsVisualizationState();
}

class _AlgorithmsVisualizationState extends State<AlgorithmsVisualization> {
  late Graph<Node> graph;
  late GraphAlgorithms<Node> algorithms;
  AlgorithmMode currentAlgorithm = AlgorithmMode.shortestPath;

  // Shortest path state
  String? sourceNode;
  String? destinationNode;
  ShortestPathResult? pathResult;

  // Connected components state
  List<Set<String>>? components;

  // Reachability state
  String? reachabilitySource;
  Set<String>? reachableNodes;

  // ReachableBy state
  String? reachableByTarget;
  Set<String>? reachableByNodes;

  // ReachableAll state
  String? reachableAllCenter;
  Set<String>? reachableAllNodes;

  // Topological sort state
  List<String>? sortedNodes;

  // Centrality state
  Map<String, double>? betweennessCentrality;
  Map<String, double>? closenessCentrality;

  @override
  void initState() {
    super.initState();
    _setupDemoGraph();
  }

  void _setupDemoGraph() {
    graph = Graph<Node>();

    // Create a dependency graph that makes sense for topological sort
    graph.addNode(Node(id: 'core', type: 'Package', label: 'Core'));
    graph.addNode(Node(id: 'utils', type: 'Package', label: 'Utils'));
    graph.addNode(Node(id: 'db', type: 'Package', label: 'Database'));
    graph.addNode(Node(id: 'api', type: 'Package', label: 'API'));
    graph.addNode(Node(id: 'ui', type: 'Package', label: 'UI'));
    graph.addNode(Node(id: 'app', type: 'Package', label: 'App'));
    graph.addNode(Node(id: 'tests', type: 'Package', label: 'Tests'));
    graph.addNode(Node(id: 'isolated', type: 'Package', label: 'Legacy'));

    // Add bridge nodes to showcase betweenness centrality
    graph.addNode(Node(id: 'auth', type: 'Service', label: 'Auth'));
    graph.addNode(Node(id: 'teamA', type: 'Team', label: 'Team A'));
    graph.addNode(Node(id: 'teamB', type: 'Team', label: 'Team B'));
    graph.addNode(Node(id: 'teamC', type: 'Team', label: 'Team C'));

    // Add dependency edges (A DEPENDS_ON B means A needs B to be built first)
    graph.addEdge('utils', 'DEPENDS_ON', 'core');    // utils needs core
    graph.addEdge('db', 'DEPENDS_ON', 'core');       // database needs core
    graph.addEdge('api', 'DEPENDS_ON', 'utils');     // api needs utils
    graph.addEdge('api', 'DEPENDS_ON', 'db');        // api needs database
    graph.addEdge('ui', 'DEPENDS_ON', 'utils');      // ui needs utils
    graph.addEdge('app', 'DEPENDS_ON', 'api');       // app needs api
    graph.addEdge('app', 'DEPENDS_ON', 'ui');        // app needs ui
    graph.addEdge('tests', 'DEPENDS_ON', 'app');     // tests need app
    // isolated has no dependencies (separate component)

    // Create simple CONNECTS edges to form clear bridge patterns
    // Auth acts as bridge between teams and core infrastructure
    graph.addEdge('teamA', 'CONNECTS', 'auth');      // teamA <-> auth
    graph.addEdge('auth', 'CONNECTS', 'teamA');
    graph.addEdge('teamB', 'CONNECTS', 'auth');      // teamB <-> auth
    graph.addEdge('auth', 'CONNECTS', 'teamB');
    graph.addEdge('teamC', 'CONNECTS', 'auth');      // teamC <-> auth
    graph.addEdge('auth', 'CONNECTS', 'teamC');
    graph.addEdge('auth', 'CONNECTS', 'core');       // auth <-> core
    graph.addEdge('core', 'CONNECTS', 'auth');

    // Utils acts as bridge between teams and packages
    graph.addEdge('auth', 'CONNECTS', 'utils');      // auth <-> utils
    graph.addEdge('utils', 'CONNECTS', 'auth');
    graph.addEdge('utils', 'CONNECTS', 'api');       // utils <-> api
    graph.addEdge('api', 'CONNECTS', 'utils');
    graph.addEdge('utils', 'CONNECTS', 'ui');        // utils <-> ui
    graph.addEdge('ui', 'CONNECTS', 'utils');

    algorithms = GraphAlgorithms(graph);
    _updateResults();
  }

  void _updateResults() {
    switch (currentAlgorithm) {
      case AlgorithmMode.shortestPath:
        if (sourceNode != null && destinationNode != null) {
          pathResult = algorithms.shortestPath(sourceNode!, destinationNode!);
        }
      case AlgorithmMode.connectedComponents:
        components = algorithms.connectedComponents();
      case AlgorithmMode.reachability:
        if (reachabilitySource != null) {
          reachableNodes = algorithms.reachableFrom(reachabilitySource!);
        }
      case AlgorithmMode.reachableBy:
        if (reachableByTarget != null) {
          reachableByNodes = algorithms.reachableBy(reachableByTarget!);
        }
      case AlgorithmMode.reachableAll:
        if (reachableAllCenter != null) {
          reachableAllNodes = algorithms.reachableAll(reachableAllCenter!);
        }
      case AlgorithmMode.topologicalSort:
        try {
          sortedNodes = algorithms.topologicalSort();
        } catch (e) {
          sortedNodes = null; // Graph has cycles
        }
      case AlgorithmMode.betweennessCentrality:
        betweennessCentrality = algorithms.betweennessCentrality();
      case AlgorithmMode.closenessCentrality:
        closenessCentrality = algorithms.closenessCentrality();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Algorithm selector
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
          ),
          child: Row(
            children: AlgorithmMode.values.map((mode) {
              final isSelected = currentAlgorithm == mode;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: ElevatedButton(
                    onPressed: () {
                      setState(() {
                        currentAlgorithm = mode;
                        _updateResults();
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isSelected
                          ? Theme.of(context).primaryColor
                          : Colors.white,
                      foregroundColor: isSelected
                          ? Colors.white
                          : Colors.grey.shade800,
                      elevation: isSelected ? 3 : 1,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          mode.title,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          mode.description,
                          style: const TextStyle(fontSize: 9),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),

        // Main content
        Expanded(
          child: Row(
            children: [
              // Left panel - Controls and results
              Container(
                width: 300,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border(right: BorderSide(color: Colors.grey.shade300)),
                ),
                child: _buildControlPanel(),
              ),

              // Right panel - Graph visualization
              Expanded(
                child: InteractiveViewer(
                  boundaryMargin: const EdgeInsets.all(20),
                  minScale: 0.5,
                  maxScale: 3.0,
                  child: GestureDetector(
                    onTapDown: (details) {
                      _handleTapOnGraph(details.localPosition);
                    },
                    child: CustomPaint(
                      painter: AlgorithmGraphPainter(
                        graph: graph,
                        algorithmMode: currentAlgorithm,
                        pathResult: pathResult,
                        components: components,
                        reachableNodes: reachableNodes,
                        reachableByNodes: reachableByNodes,
                        reachableAllNodes: reachableAllNodes,
                        sortedNodes: sortedNodes,
                        betweennessCentrality: betweennessCentrality,
                        closenessCentrality: closenessCentrality,
                        sourceNode: sourceNode,
                        destinationNode: destinationNode,
                        reachabilitySource: reachabilitySource,
                        reachableByTarget: reachableByTarget,
                        reachableAllCenter: reachableAllCenter,
                        onNodeTap: _handleNodeTap,
                      ),
                      size: Size.infinite,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildControlPanel() {
    switch (currentAlgorithm) {
      case AlgorithmMode.shortestPath:
        return _buildShortestPathControls();
      case AlgorithmMode.connectedComponents:
        return _buildConnectedComponentsControls();
      case AlgorithmMode.reachability:
        return _buildReachabilityControls();
      case AlgorithmMode.reachableBy:
        return _buildReachableByControls();
      case AlgorithmMode.reachableAll:
        return _buildReachableAllControls();
      case AlgorithmMode.topologicalSort:
        return _buildTopologicalSortControls();
      case AlgorithmMode.betweennessCentrality:
        return _buildBetweennessCentralityControls();
      case AlgorithmMode.closenessCentrality:
        return _buildClosenessCentralityControls();
    }
  }

  Widget _buildShortestPathControls() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Shortest Path',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          sourceNode == null
              ? '1. Click a node to select SOURCE (green)'
              : destinationNode == null
                  ? '2. Click another node to select DESTINATION (red)'
                  : 'Path calculated! Click any node to start over.',
          style: const TextStyle(fontStyle: FontStyle.italic, color: Colors.grey),
        ),
        const SizedBox(height: 16),

        if (sourceNode != null) ...[
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              border: Border.all(color: Colors.green.shade300),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              'Source: $sourceNode',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green.shade800),
            ),
          ),
          const SizedBox(height: 8),
        ],
        if (destinationNode != null) ...[
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              border: Border.all(color: Colors.red.shade300),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              'Destination: $destinationNode',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red.shade800),
            ),
          ),
          const SizedBox(height: 8),
        ],

        if (pathResult != null) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: pathResult!.found ? Colors.green.shade50 : Colors.red.shade50,
              border: Border.all(
                color: pathResult!.found ? Colors.green.shade300 : Colors.red.shade300,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  pathResult!.found ? 'Path Found!' : 'No Path',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: pathResult!.found ? Colors.green.shade800 : Colors.red.shade800,
                  ),
                ),
                if (pathResult!.found) ...[
                  const SizedBox(height: 8),
                  Text('Route: ${pathResult!.path.join(' → ')}'),
                  Text('Distance: ${pathResult!.distance}'),
                ],
              ],
            ),
          ),
        ],

        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: () {
            setState(() {
              sourceNode = null;
              destinationNode = null;
              pathResult = null;
            });
          },
          child: const Text('Clear'),
        ),
      ],
    );
  }

  Widget _buildConnectedComponentsControls() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Connected Components',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Text('Groups of nodes that are connected to each other.'),
        const SizedBox(height: 16),

        if (components != null) ...[
          Text('Found ${components!.length} components:'),
          const SizedBox(height: 8),
          ...components!.asMap().entries.map((entry) {
            final index = entry.key;
            final component = entry.value;
            final color = _getComponentColor(index);
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                border: Border.all(color: color),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Component ${index + 1}',
                    style: TextStyle(fontWeight: FontWeight.bold, color: color),
                  ),
                  Text('Nodes: {${component.join(', ')}}'),
                  Text('Size: ${component.length} nodes'),
                ],
              ),
            );
          }),
        ],
      ],
    );
  }

  Widget _buildReachabilityControls() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Reachability Analysis',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Text('Click a node to see all nodes reachable from it.'),
        const SizedBox(height: 16),

        if (reachabilitySource != null) ...[
          Text('Source: $reachabilitySource', style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),

          if (reachableNodes != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                border: Border.all(color: Colors.blue.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Reachable Nodes:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(reachableNodes!.join(', ')),
                  const SizedBox(height: 8),
                  Text('Total: ${reachableNodes!.length} nodes'),
                ],
              ),
            ),
          ],
        ],

        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: () {
            setState(() {
              reachabilitySource = null;
              reachableNodes = null;
            });
          },
          child: const Text('Clear'),
        ),
      ],
    );
  }

  Widget _buildReachableByControls() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Reachable By Analysis',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Text('Click a node to see all nodes that can reach it.'),
        const SizedBox(height: 16),

        if (reachableByTarget != null) ...[
          Text('Target: $reachableByTarget', style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),

          if (reachableByNodes != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                border: Border.all(color: Colors.green.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Nodes that can reach target:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(reachableByNodes!.join(', ')),
                  const SizedBox(height: 8),
                  Text('Total: ${reachableByNodes!.length} nodes'),
                ],
              ),
            ),
          ],
        ],

        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: () {
            setState(() {
              reachableByTarget = null;
              reachableByNodes = null;
            });
          },
          child: const Text('Clear'),
        ),
      ],
    );
  }

  Widget _buildReachableAllControls() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Bidirectional Reachability',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Text('Click a node to see all nodes connected in either direction.'),
        const SizedBox(height: 16),

        if (reachableAllCenter != null) ...[
          Text('Center: $reachableAllCenter', style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),

          if (reachableAllNodes != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.purple.shade50,
                border: Border.all(color: Colors.purple.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Connected nodes (all directions):',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(reachableAllNodes!.join(', ')),
                  const SizedBox(height: 8),
                  Text('Total: ${reachableAllNodes!.length} nodes'),
                ],
              ),
            ),
          ],
        ],

        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: () {
            setState(() {
              reachableAllCenter = null;
              reachableAllNodes = null;
            });
          },
          child: const Text('Clear'),
        ),
      ],
    );
  }

  Widget _buildTopologicalSortControls() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Topological Sort',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Text('Shows build order - dependencies arranged in levels that can be built in parallel.'),
        const SizedBox(height: 16),

        if (sortedNodes != null) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              border: Border.all(color: Colors.blue.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '📊 Build Levels Layout:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                Text('• Nodes arranged in columns by build level'),
                Text('• Each column can be built in parallel'),
                Text('• Dependencies flow left → right'),
                Text('• No cycles = valid build order ✓'),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              border: Border.all(color: Colors.green.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Sequential Build Order:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ...sortedNodes!.asMap().entries.map((entry) {
                  final index = entry.key;
                  final node = entry.value;
                  return Text('${index + 1}. $node');
                }),
              ],
            ),
          ),
        ] else ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              border: Border.all(color: Colors.orange.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Cycle Detected!',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 4),
                Text('This graph contains cycles, so topological sorting is not possible.'),
                SizedBox(height: 8),
                Text('Example: A depends on B, B depends on C, C depends on A'),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildBetweennessCentralityControls() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Betweenness Centrality',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Text('Finds nodes that act as bridges - critical connection points in the network.'),
        const SizedBox(height: 16),

        if (betweennessCentrality != null) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              border: Border.all(color: Colors.red.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Bridge Nodes (sorted by importance):',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ...betweennessCentrality!.entries
                    .where((e) => e.value > 0.0)
                    .toList()
                    .asMap()
                    .entries
                    .map((indexedEntry) {
                      final entry = indexedEntry.value;
                      return Text('${entry.key}: ${(entry.value * 100).toStringAsFixed(1)}%');
                    }),
                if (betweennessCentrality!.values.every((v) => v == 0.0))
                  const Text('No bridge nodes found - all nodes are peripheral.'),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildClosenessCentralityControls() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Closeness Centrality',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Text('Finds nodes that are closest to all others - communication hubs.'),
        const SizedBox(height: 16),

        if (closenessCentrality != null) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              border: Border.all(color: Colors.green.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Most Central Nodes (sorted by closeness):',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ...closenessCentrality!.entries
                    .toList()
                    .asMap()
                    .entries
                    .map((indexedEntry) {
                      final entry = indexedEntry.value;
                      return Text('${entry.key}: ${(entry.value * 100).toStringAsFixed(1)}%');
                    }),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Color _getComponentColor(int index) {
    final colors = [
      Colors.red,
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.teal,
      Colors.indigo,
      Colors.pink,
    ];
    return colors[index % colors.length];
  }

  void _handleTapOnGraph(Offset position) {
    // Get node positions from painter
    final nodePositions = _getNodePositions();

    // Check if tap hit any node
    for (final entry in nodePositions.entries) {
      final nodeId = entry.key;
      final nodePos = entry.value;
      final distance = (position - nodePos).distance;
      if (distance <= 35) {
        _handleNodeTap(nodeId);
        return;
      }
    }
  }

  Map<String, Offset> _getNodePositions() {
    // Use same logic as painter
    if (currentAlgorithm == AlgorithmMode.topologicalSort && sortedNodes != null) {
      return _getTopologicalLayoutForWidget();
    } else {
      return _getGridLayoutForWidget();
    }
  }

  Map<String, Offset> _getGridLayoutForWidget() {
    final positions = <String, Offset>{};
    final nodeIds = graph.nodesById.keys.toList()..sort();

    // Same layout logic as in painter
    const double spacing = 120.0;
    const double startX = 100.0;
    const double startY = 100.0;
    final int columns = (nodeIds.length <= 4) ? 2 : 3;

    for (int i = 0; i < nodeIds.length; i++) {
      final row = i ~/ columns;
      final col = i % columns;
      positions[nodeIds[i]] = Offset(
        startX + col * spacing,
        startY + row * spacing,
      );
    }

    return positions;
  }

  Map<String, Offset> _getTopologicalLayoutForWidget() {
    final positions = <String, Offset>{};
    if (sortedNodes == null) return _getGridLayoutForWidget();

    // Calculate build levels - same logic as painter
    final levels = _calculateBuildLevelsForWidget();

    const double levelSpacing = 150.0;
    const double nodeSpacing = 80.0;
    const double startX = 80.0;
    const double startY = 60.0;

    for (int levelIndex = 0; levelIndex < levels.length; levelIndex++) {
      final nodesInLevel = levels[levelIndex];
      final levelX = startX + levelIndex * levelSpacing;

      final totalHeight = (nodesInLevel.length - 1) * nodeSpacing;
      final levelStartY = startY + (400 - totalHeight) / 2;

      for (int nodeIndex = 0; nodeIndex < nodesInLevel.length; nodeIndex++) {
        final nodeId = nodesInLevel[nodeIndex];
        positions[nodeId] = Offset(
          levelX,
          levelStartY + nodeIndex * nodeSpacing,
        );
      }
    }

    return positions;
  }

  List<List<String>> _calculateBuildLevelsForWidget() {
    if (sortedNodes == null) return [];

    final levels = <List<String>>[];
    final nodeLevel = <String, int>{};

    for (final nodeId in sortedNodes!) {
      int maxDepLevel = -1;

      final incoming = graph.inn[nodeId];
      if (incoming != null) {
        for (final edgeType in incoming.keys) {
          for (final depNode in incoming[edgeType]!) {
            final depLevel = nodeLevel[depNode] ?? 0;
            maxDepLevel = math.max(maxDepLevel, depLevel);
          }
        }
      }

      final thisLevel = maxDepLevel + 1;
      nodeLevel[nodeId] = thisLevel;

      while (levels.length <= thisLevel) {
        levels.add(<String>[]);
      }

      levels[thisLevel].add(nodeId);
    }

    return levels;
  }

  void _handleNodeTap(String nodeId) {
    setState(() {
      switch (currentAlgorithm) {
        case AlgorithmMode.shortestPath:
          if (sourceNode == null) {
            sourceNode = nodeId;
          } else if (destinationNode == null && nodeId != sourceNode) {
            destinationNode = nodeId;
          } else {
            sourceNode = nodeId;
            destinationNode = null;
            pathResult = null;
          }
        case AlgorithmMode.reachability:
          reachabilitySource = nodeId;
        case AlgorithmMode.reachableBy:
          reachableByTarget = nodeId;
        case AlgorithmMode.reachableAll:
          reachableAllCenter = nodeId;
        case AlgorithmMode.connectedComponents:
        case AlgorithmMode.topologicalSort:
        case AlgorithmMode.betweennessCentrality:
        case AlgorithmMode.closenessCentrality:
          // No interaction needed
          break;
      }
      _updateResults();
    });
  }
}

class AlgorithmGraphPainter extends CustomPainter {
  final Graph<Node> graph;
  final AlgorithmMode algorithmMode;
  final ShortestPathResult? pathResult;
  final List<Set<String>>? components;
  final Set<String>? reachableNodes;
  final Set<String>? reachableByNodes;
  final Set<String>? reachableAllNodes;
  final List<String>? sortedNodes;
  final Map<String, double>? betweennessCentrality;
  final Map<String, double>? closenessCentrality;
  final String? sourceNode;
  final String? destinationNode;
  final String? reachabilitySource;
  final String? reachableByTarget;
  final String? reachableAllCenter;
  final Function(String) onNodeTap;

  AlgorithmGraphPainter({
    required this.graph,
    required this.algorithmMode,
    this.pathResult,
    this.components,
    this.reachableNodes,
    this.reachableByNodes,
    this.reachableAllNodes,
    this.sortedNodes,
    this.betweennessCentrality,
    this.closenessCentrality,
    this.sourceNode,
    this.destinationNode,
    this.reachabilitySource,
    this.reachableByTarget,
    this.reachableAllCenter,
    required this.onNodeTap,
  });

  // Layout nodes based on algorithm mode
  Map<String, Offset> get nodePositions {
    if (algorithmMode == AlgorithmMode.topologicalSort && sortedNodes != null) {
      return _getTopologicalLayout();
    } else {
      return _getGridLayout();
    }
  }

  Map<String, Offset> _getGridLayout() {
    final positions = <String, Offset>{};
    final nodeIds = graph.nodesById.keys.toList()..sort();

    // Arrange in a grid
    const double spacing = 120.0;
    const double startX = 100.0;
    const double startY = 100.0;
    final int columns = (nodeIds.length <= 4) ? 2 : 3;

    for (int i = 0; i < nodeIds.length; i++) {
      final row = i ~/ columns;
      final col = i % columns;
      positions[nodeIds[i]] = Offset(
        startX + col * spacing,
        startY + row * spacing,
      );
    }

    return positions;
  }

  Map<String, Offset> _getTopologicalLayout() {
    final positions = <String, Offset>{};
    if (sortedNodes == null) return _getGridLayout();

    // Calculate build levels - nodes that can be built in parallel
    final levels = _calculateBuildLevels();

    const double levelSpacing = 150.0;  // Horizontal spacing between levels
    const double nodeSpacing = 80.0;   // Vertical spacing between nodes in same level
    const double startX = 80.0;
    const double startY = 60.0;

    for (int levelIndex = 0; levelIndex < levels.length; levelIndex++) {
      final nodesInLevel = levels[levelIndex];
      final levelX = startX + levelIndex * levelSpacing;

      // Center nodes vertically in their level
      final totalHeight = (nodesInLevel.length - 1) * nodeSpacing;
      final levelStartY = startY + (400 - totalHeight) / 2; // Center in available space

      for (int nodeIndex = 0; nodeIndex < nodesInLevel.length; nodeIndex++) {
        final nodeId = nodesInLevel[nodeIndex];
        positions[nodeId] = Offset(
          levelX,
          levelStartY + nodeIndex * nodeSpacing,
        );
      }
    }

    return positions;
  }

  List<List<String>> _calculateBuildLevels() {
    if (sortedNodes == null) return [];

    final levels = <List<String>>[];
    final nodeLevel = <String, int>{};

    // Calculate the level of each node based on its dependencies
    for (final nodeId in sortedNodes!) {
      int maxDepLevel = -1;

      // Check incoming dependencies (nodes this one depends on)
      final incoming = graph.inn[nodeId];
      if (incoming != null) {
        for (final edgeType in incoming.keys) {
          for (final depNode in incoming[edgeType]!) {
            final depLevel = nodeLevel[depNode] ?? 0;
            maxDepLevel = math.max(maxDepLevel, depLevel);
          }
        }
      }

      final thisLevel = maxDepLevel + 1;
      nodeLevel[nodeId] = thisLevel;

      // Ensure we have enough levels
      while (levels.length <= thisLevel) {
        levels.add(<String>[]);
      }

      levels[thisLevel].add(nodeId);
    }

    return levels;
  }

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

          // Color edges based on algorithm mode
          paint.color = _getEdgeColor(srcId, dstId);
          paint.strokeWidth = _getEdgeWidth(srcId, dstId);

          _drawArrow(canvas, srcPos, dstPos, paint);
        }
      }
    }
  }

  void _drawNodes(Canvas canvas) {
    for (final node in graph.nodesById.values) {
      final pos = nodePositions[node.id];
      if (pos == null) continue;

      final paint = Paint()..style = PaintingStyle.fill;
      final borderPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3;

      // Color nodes based on algorithm mode and state
      final nodeColor = _getNodeColor(node.id);
      final borderColor = _getNodeBorderColor(node.id);
      final radius = _getNodeRadius(node.id);

      paint.color = nodeColor;
      borderPaint.color = borderColor;

      // Draw node
      canvas.drawCircle(pos, radius, paint);
      canvas.drawCircle(pos, radius, borderPaint);

      // Draw node label
      _drawText(canvas, node.id, pos, Colors.white);
    }
  }

  Color _getEdgeColor(String srcId, String dstId) {
    switch (algorithmMode) {
      case AlgorithmMode.shortestPath:
        if (pathResult?.found == true) {
          final path = pathResult!.path;
          for (int i = 0; i < path.length - 1; i++) {
            if (path[i] == srcId && path[i + 1] == dstId) {
              return Colors.red.shade600; // Path edge
            }
          }
        }
        return Colors.grey.shade400;

      case AlgorithmMode.connectedComponents:
        if (components != null) {
          for (int i = 0; i < components!.length; i++) {
            final component = components![i];
            if (component.contains(srcId) && component.contains(dstId)) {
              return _getComponentColor(i);
            }
          }
        }
        return Colors.grey.shade400;

      case AlgorithmMode.reachability:
        if (reachableNodes != null &&
            reachableNodes!.contains(srcId) &&
            reachableNodes!.contains(dstId)) {
          return Colors.blue.shade600;
        }
        return Colors.grey.shade400;

      case AlgorithmMode.reachableBy:
        if (reachableByNodes != null &&
            reachableByNodes!.contains(srcId) &&
            reachableByNodes!.contains(dstId)) {
          return Colors.green.shade600;
        }
        return Colors.grey.shade400;

      case AlgorithmMode.reachableAll:
        if (reachableAllNodes != null &&
            reachableAllNodes!.contains(srcId) &&
            reachableAllNodes!.contains(dstId)) {
          return Colors.purple.shade600;
        }
        return Colors.grey.shade400;

      case AlgorithmMode.topologicalSort:
        return Colors.grey.shade400;

      case AlgorithmMode.betweennessCentrality:
      case AlgorithmMode.closenessCentrality:
        return Colors.grey.shade400;
    }
  }

  double _getEdgeWidth(String srcId, String dstId) {
    switch (algorithmMode) {
      case AlgorithmMode.shortestPath:
        if (pathResult?.found == true) {
          final path = pathResult!.path;
          for (int i = 0; i < path.length - 1; i++) {
            if (path[i] == srcId && path[i + 1] == dstId) {
              return 4.0; // Thick path edge
            }
          }
        }
        return 2.0;

      case AlgorithmMode.reachability:
        if (reachableNodes != null &&
            reachableNodes!.contains(srcId) &&
            reachableNodes!.contains(dstId)) {
          return 3.0;
        }
        return 1.0;

      case AlgorithmMode.reachableBy:
        if (reachableByNodes != null &&
            reachableByNodes!.contains(srcId) &&
            reachableByNodes!.contains(dstId)) {
          return 3.0;
        }
        return 1.0;

      case AlgorithmMode.reachableAll:
        if (reachableAllNodes != null &&
            reachableAllNodes!.contains(srcId) &&
            reachableAllNodes!.contains(dstId)) {
          return 3.0;
        }
        return 1.0;

      case AlgorithmMode.betweennessCentrality:
      case AlgorithmMode.closenessCentrality:
        return 2.0;

      default:
        return 2.0;
    }
  }

  Color _getNodeColor(String nodeId) {
    switch (algorithmMode) {
      case AlgorithmMode.shortestPath:
        if (nodeId == sourceNode) return Colors.green.shade600;
        if (nodeId == destinationNode) return Colors.red.shade600;
        if (pathResult?.found == true && pathResult!.path.contains(nodeId)) {
          return Colors.orange.shade600;
        }
        return Colors.blue.shade300;

      case AlgorithmMode.connectedComponents:
        if (components != null) {
          for (int i = 0; i < components!.length; i++) {
            if (components![i].contains(nodeId)) {
              return _getComponentColor(i);
            }
          }
        }
        return Colors.grey.shade300;

      case AlgorithmMode.reachability:
        if (nodeId == reachabilitySource) return Colors.green.shade600;
        if (reachableNodes?.contains(nodeId) == true) {
          return Colors.blue.shade400;
        }
        return Colors.grey.shade300;

      case AlgorithmMode.reachableBy:
        if (nodeId == reachableByTarget) return Colors.red.shade600;
        if (reachableByNodes?.contains(nodeId) == true) {
          return Colors.green.shade400;
        }
        return Colors.grey.shade300;

      case AlgorithmMode.reachableAll:
        if (nodeId == reachableAllCenter) return Colors.orange.shade600;
        if (reachableAllNodes?.contains(nodeId) == true) {
          return Colors.purple.shade400;
        }
        return Colors.grey.shade300;

      case AlgorithmMode.topologicalSort:
        if (sortedNodes != null) {
          final index = sortedNodes!.indexOf(nodeId);
          if (index >= 0) {
            // Color gradient based on position in sort order
            final ratio = index / (sortedNodes!.length - 1);
            return Color.lerp(Colors.green.shade600, Colors.red.shade600, ratio)!;
          }
        }
        return Colors.grey.shade300;

      case AlgorithmMode.betweennessCentrality:
        if (betweennessCentrality != null) {
          final centrality = betweennessCentrality![nodeId] ?? 0.0;
          if (centrality > 0.0) {
            // Red gradient based on betweenness score
            return Color.lerp(Colors.orange.shade300, Colors.red.shade700, centrality)!;
          }
        }
        return Colors.grey.shade300;

      case AlgorithmMode.closenessCentrality:
        if (closenessCentrality != null) {
          final centrality = closenessCentrality![nodeId] ?? 0.0;
          if (centrality > 0.0) {
            // Green gradient based on closeness score
            return Color.lerp(Colors.blue.shade300, Colors.green.shade700, centrality)!;
          }
        }
        return Colors.grey.shade300;
    }
  }

  Color _getNodeBorderColor(String nodeId) {
    switch (algorithmMode) {
      case AlgorithmMode.shortestPath:
        if (nodeId == sourceNode) return Colors.green.shade800;
        if (nodeId == destinationNode) return Colors.red.shade800;
        return Colors.blue.shade600;

      case AlgorithmMode.reachability:
        if (nodeId == reachabilitySource) return Colors.green.shade800;
        return Colors.blue.shade600;

      case AlgorithmMode.reachableBy:
        if (nodeId == reachableByTarget) return Colors.red.shade800;
        return Colors.green.shade600;

      case AlgorithmMode.reachableAll:
        if (nodeId == reachableAllCenter) return Colors.orange.shade800;
        return Colors.purple.shade600;

      case AlgorithmMode.betweennessCentrality:
        return Colors.red.shade800;

      case AlgorithmMode.closenessCentrality:
        return Colors.green.shade800;

      default:
        return Colors.grey.shade600;
    }
  }

  double _getNodeRadius(String nodeId) {
    switch (algorithmMode) {
      case AlgorithmMode.shortestPath:
        if (nodeId == sourceNode || nodeId == destinationNode) return 35.0;
        return 30.0;

      case AlgorithmMode.reachability:
        if (nodeId == reachabilitySource) return 35.0;
        return 30.0;

      case AlgorithmMode.reachableBy:
        if (nodeId == reachableByTarget) return 35.0;
        return 30.0;

      case AlgorithmMode.reachableAll:
        if (nodeId == reachableAllCenter) return 35.0;
        return 30.0;

      case AlgorithmMode.betweennessCentrality:
        if (betweennessCentrality != null) {
          final centrality = betweennessCentrality![nodeId] ?? 0.0;
          // Scale radius from 25 to 40 based on centrality
          return 25.0 + (centrality * 15.0);
        }
        return 30.0;

      case AlgorithmMode.closenessCentrality:
        if (closenessCentrality != null) {
          final centrality = closenessCentrality![nodeId] ?? 0.0;
          // Scale radius from 25 to 40 based on centrality
          return 25.0 + (centrality * 15.0);
        }
        return 30.0;

      default:
        return 30.0;
    }
  }

  Color _getComponentColor(int index) {
    final colors = [
      Colors.red.shade400,
      Colors.blue.shade400,
      Colors.green.shade400,
      Colors.orange.shade400,
      Colors.purple.shade400,
      Colors.teal.shade400,
      Colors.indigo.shade400,
      Colors.pink.shade400,
    ];
    return colors[index % colors.length];
  }

  void _drawArrow(Canvas canvas, Offset start, Offset end, Paint paint) {
    // Adjust start and end points to node edges
    final direction = (end - start).normalized();
    final adjustedStart = start + direction * 30;
    final adjustedEnd = end - direction * 30;

    // Draw line
    canvas.drawLine(adjustedStart, adjustedEnd, paint);

    // Draw arrowhead
    final arrowLength = 12.0;
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
          fontSize: 14,
          fontWeight: FontWeight.bold,
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

  @override
  bool shouldRepaint(AlgorithmGraphPainter oldDelegate) {
    return oldDelegate.algorithmMode != algorithmMode ||
        oldDelegate.pathResult != pathResult ||
        oldDelegate.components != components ||
        oldDelegate.reachableNodes != reachableNodes ||
        oldDelegate.reachableByNodes != reachableByNodes ||
        oldDelegate.reachableAllNodes != reachableAllNodes ||
        oldDelegate.sortedNodes != sortedNodes ||
        oldDelegate.betweennessCentrality != betweennessCentrality ||
        oldDelegate.closenessCentrality != closenessCentrality ||
        oldDelegate.sourceNode != sourceNode ||
        oldDelegate.destinationNode != destinationNode ||
        oldDelegate.reachabilitySource != reachabilitySource ||
        oldDelegate.reachableByTarget != reachableByTarget ||
        oldDelegate.reachableAllCenter != reachableAllCenter;
  }

  @override
  bool hitTest(Offset position) => true;
}
