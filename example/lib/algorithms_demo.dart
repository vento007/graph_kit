import 'package:example/main_demo.dart';
import 'package:flutter/material.dart';
import 'package:graph_kit/graph_kit.dart';
import 'dart:math' as math;

class GraphAlgorithmsDemo extends StatelessWidget {
  const GraphAlgorithmsDemo({super.key});

  @override
  Widget build(BuildContext context) {
    return const AlgorithmsVisualization();
  }
}

enum AlgorithmMode {
  shortestPath('Shortest Path', 'Find optimal routes between nodes'),
  connectedComponents('Connected Components', 'Group related nodes'),
  reachability('Reachable From', 'See what nodes can be reached from a source'),
  reachableBy('Reachable By', 'See what nodes can reach a target'),
  reachableAll(
    'Bidirectional Reach',
    'See all nodes connected in either direction',
  ),
  topologicalSort('Topological Sort', 'Order nodes by dependencies'),
  betweennessCentrality('Betweenness Centrality', 'Find critical bridge nodes'),
  closenessCentrality(
    'Closeness Centrality',
    'Find nodes closest to all others',
  );

  const AlgorithmMode(this.title, this.description);
  final String title;
  final String description;
}

class AlgorithmsVisualization extends StatefulWidget {
  const AlgorithmsVisualization({super.key});

  @override
  State<AlgorithmsVisualization> createState() =>
      _AlgorithmsVisualizationState();
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
    graph.addEdge('utils', 'DEPENDS_ON', 'core'); // utils needs core
    graph.addEdge('db', 'DEPENDS_ON', 'core'); // database needs core
    graph.addEdge('api', 'DEPENDS_ON', 'utils'); // api needs utils
    graph.addEdge('api', 'DEPENDS_ON', 'db'); // api needs database
    graph.addEdge('ui', 'DEPENDS_ON', 'utils'); // ui needs utils
    graph.addEdge('app', 'DEPENDS_ON', 'api'); // app needs api
    graph.addEdge('app', 'DEPENDS_ON', 'ui'); // app needs ui
    graph.addEdge('tests', 'DEPENDS_ON', 'app'); // tests need app
    // isolated has no dependencies (separate component)

    // Create simple CONNECTS edges to form clear bridge patterns
    // Auth acts as bridge between teams and core infrastructure
    graph.addEdge('teamA', 'CONNECTS', 'auth'); // teamA <-> auth
    graph.addEdge('auth', 'CONNECTS', 'teamA');
    graph.addEdge('teamB', 'CONNECTS', 'auth'); // teamB <-> auth
    graph.addEdge('auth', 'CONNECTS', 'teamB');
    graph.addEdge('teamC', 'CONNECTS', 'auth'); // teamC <-> auth
    graph.addEdge('auth', 'CONNECTS', 'teamC');
    graph.addEdge('auth', 'CONNECTS', 'core'); // auth <-> core
    graph.addEdge('core', 'CONNECTS', 'auth');

    // Utils acts as bridge between teams and packages
    graph.addEdge('auth', 'CONNECTS', 'utils'); // auth <-> utils
    graph.addEdge('utils', 'CONNECTS', 'auth');
    graph.addEdge('utils', 'CONNECTS', 'api'); // utils <-> api
    graph.addEdge('api', 'CONNECTS', 'utils');
    graph.addEdge('utils', 'CONNECTS', 'ui'); // utils <-> ui
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Graph Algorithms'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Column(
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
                    padding: const EdgeInsets.symmetric(horizontal: 3),
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
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
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
                    border: Border(
                      right: BorderSide(color: Colors.grey.shade300),
                    ),
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
      ),
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
          style: const TextStyle(
            fontStyle: FontStyle.italic,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 16),

        if (sourceNode != null) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              border: Border.all(color: Colors.green.shade300),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              'Source: $sourceNode',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.green.shade800,
              ),
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
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.red.shade800,
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],

        if (pathResult != null) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: pathResult!.found
                  ? Colors.green.shade50
                  : Colors.red.shade50,
              border: Border.all(
                color: pathResult!.found
                    ? Colors.green.shade300
                    : Colors.red.shade300,
              ),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  pathResult!.found ? 'Path Found!' : 'No Path',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: pathResult!.found
                        ? Colors.green.shade800
                        : Colors.red.shade800,
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
          Text(
            'Source: $reachabilitySource',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),

          if (reachableNodes != null) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                border: Border.all(color: Colors.blue.shade300),
                borderRadius: BorderRadius.circular(4),
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
          Text(
            'Target: $reachableByTarget',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),

          if (reachableByNodes != null) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                border: Border.all(color: Colors.green.shade300),
                borderRadius: BorderRadius.circular(4),
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
        const Text(
          'Click a node to see all nodes connected in either direction.',
        ),
        const SizedBox(height: 16),

        if (reachableAllCenter != null) ...[
          Text(
            'Center: $reachableAllCenter',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),

          if (reachableAllNodes != null) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.purple.shade50,
                border: Border.all(color: Colors.purple.shade300),
                borderRadius: BorderRadius.circular(4),
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
        const Text(
          'Shows build order - dependencies arranged in levels that can be built in parallel.',
        ),
        const SizedBox(height: 16),

        if (sortedNodes != null) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              border: Border.all(color: Colors.blue.shade300),
              borderRadius: BorderRadius.circular(4),
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
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              border: Border.all(color: Colors.green.shade300),
              borderRadius: BorderRadius.circular(4),
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
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              border: Border.all(color: Colors.orange.shade300),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Cycle Detected!',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 4),
                Text(
                  'This graph contains cycles, so topological sorting is not possible.',
                ),
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
        const Text(
          'Finds nodes that act as bridges - critical connection points in the network.',
        ),
        const SizedBox(height: 16),

        if (betweennessCentrality != null) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              border: Border.all(color: Colors.red.shade300),
              borderRadius: BorderRadius.circular(4),
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
                      return Text(
                        '${entry.key}: ${(entry.value * 100).toStringAsFixed(1)}%',
                      );
                    }),
                if (betweennessCentrality!.values.every((v) => v == 0.0))
                  const Text(
                    'No bridge nodes found - all nodes are peripheral.',
                  ),
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
        const Text(
          'Finds nodes that are closest to all others - communication hubs.',
        ),
        const SizedBox(height: 16),

        if (closenessCentrality != null) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              border: Border.all(color: Colors.green.shade300),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Most Central Nodes (sorted by closeness):',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ...closenessCentrality!.entries.toList().asMap().entries.map((
                  indexedEntry,
                ) {
                  final entry = indexedEntry.value;
                  return Text(
                    '${entry.key}: ${(entry.value * 100).toStringAsFixed(1)}%',
                  );
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
    if (currentAlgorithm == AlgorithmMode.topologicalSort &&
        sortedNodes != null) {
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

    const double levelSpacing = 150.0; // Horizontal spacing between levels
    const double nodeSpacing =
        80.0; // Vertical spacing between nodes in same level
    const double startX = 80.0;
    const double startY = 60.0;

    for (int levelIndex = 0; levelIndex < levels.length; levelIndex++) {
      final nodesInLevel = levels[levelIndex];
      final levelX = startX + levelIndex * levelSpacing;

      // Center nodes vertically in their level
      final totalHeight = (nodesInLevel.length - 1) * nodeSpacing;
      final levelStartY =
          startY + (400 - totalHeight) / 2; // Center in available space

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
            return Color.lerp(
              Colors.green.shade600,
              Colors.red.shade600,
              ratio,
            )!;
          }
        }
        return Colors.grey.shade300;

      case AlgorithmMode.betweennessCentrality:
        if (betweennessCentrality != null) {
          final centrality = betweennessCentrality![nodeId] ?? 0.0;
          if (centrality > 0.0) {
            // Red gradient based on betweenness score
            return Color.lerp(
              Colors.orange.shade300,
              Colors.red.shade700,
              centrality,
            )!;
          }
        }
        return Colors.grey.shade300;

      case AlgorithmMode.closenessCentrality:
        if (closenessCentrality != null) {
          final centrality = closenessCentrality![nodeId] ?? 0.0;
          if (centrality > 0.0) {
            // Green gradient based on closeness score
            return Color.lerp(
              Colors.blue.shade300,
              Colors.green.shade700,
              centrality,
            )!;
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

    final arrowPoint1 =
        adjustedEnd +
        Offset(
          -arrowLength * math.cos(-arrowAngle + direction.angle),
          -arrowLength * math.sin(-arrowAngle + direction.angle),
        );

    final arrowPoint2 =
        adjustedEnd +
        Offset(
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
