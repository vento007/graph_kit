import 'package:flutter/material.dart';
import 'package:graph_kit/graph_kit.dart';

void main() {
  runApp(const WhereClauseDemoApp());
}

class WhereClauseDemoApp extends StatelessWidget {
  const WhereClauseDemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'WHERE Clause Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const WhereClauseDemo(),
    );
  }
}

class WhereClauseDemo extends StatefulWidget {
  const WhereClauseDemo({super.key});

  @override
  State<WhereClauseDemo> createState() => _WhereClauseDemoState();
}

class _WhereClauseDemoState extends State<WhereClauseDemo> {
  late Graph<Node> graph;
  late PatternQuery<Node> query;
  final TextEditingController _queryController = TextEditingController();
  List<Map<String, String>> _results = [];
  String? _error;
  bool _isLoading = false;

  // Predefined sample queries
  final List<QuerySample> _sampleQueries = [
    QuerySample(
      'People over 25',
      'MATCH person:Person WHERE person.age > 25',
      'Find all people older than 25',
    ),
    QuerySample(
      'Engineering Team',
      'MATCH person:Person WHERE person.department = "Engineering"',
      'Find people in Engineering department',
    ),
    QuerySample(
      'High Earners',
      'MATCH person:Person WHERE person.salary >= 90000',
      'Find people with salary >= 90k',
    ),
    QuerySample(
      'AND Example',
      'MATCH person:Person WHERE person.age > 25 AND person.department = "Engineering"',
      'People over 25 AND in Engineering',
    ),
    QuerySample(
      'OR Example - Young or Rich',
      'MATCH person:Person WHERE person.age < 30 OR person.salary > 95000',
      'People under 30 OR earning > 95k',
    ),
    QuerySample(
      'OR Example - Departments',
      'MATCH person:Person WHERE person.department = "Engineering" OR person.department = "Design"',
      'People in Engineering OR Design',
    ),
    QuerySample(
      'Parentheses Example 1',
      'MATCH person:Person WHERE (person.age > 40 AND person.salary > 100000) OR person.department = "Management"',
      'High earners over 40 OR management',
    ),
    QuerySample(
      'Parentheses Example 2',
      'MATCH person:Person WHERE person.department = "Engineering" AND (person.age < 30 OR person.salary > 90000)',
      'Engineers who are young OR well-paid',
    ),
    QuerySample(
      'Multiple Parentheses',
      'MATCH person:Person WHERE (person.age > 40 AND person.salary > 100000) OR (person.age < 30 AND person.department = "Engineering")',
      'High earners over 40 OR young engineers',
    ),
    QuerySample(
      'Complex Precedence',
      'MATCH person:Person WHERE person.age > 40 OR person.department = "Management"',
      'Age over 40 OR management (no parentheses)',
    ),
    QuerySample(
      'Team Relationships',
      'MATCH person:Person-[:WORKS_FOR]->team:Team WHERE person.age > 30',
      'People over 30 and their teams',
    ),
    QuerySample(
      'Large Teams OR High Budget',
      'MATCH team:Team WHERE team.size > 10 OR team.budget > 150000',
      'Large teams OR high budget teams',
    ),
    QuerySample(
      'Active or High Budget Projects',
      'MATCH project:Project WHERE project.status = "active" OR project.budget > 100000',
      'Active projects OR expensive projects',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _initializeGraph();
    _queryController.text = _sampleQueries.first.query;
  }

  void _initializeGraph() {
    graph = Graph<Node>();
    query = PatternQuery(graph);

    // Create comprehensive test data
    _addPeople();
    _addTeams();
    _addProjects();
    _addRelationships();
  }

  void _addPeople() {
    final people = [
      ('alice', 'Alice Cooper', 28, 'Engineering', 85000),
      ('bob', 'Bob Wilson', 35, 'Engineering', 95000),
      ('carol', 'Carol Davis', 22, 'Marketing', 60000),
      ('david', 'David Smith', 45, 'Engineering', 120000),
      ('emma', 'Emma Johnson', 27, 'Design', 70000),
      ('frank', 'Frank Brown', 52, 'Management', 150000),
      ('grace', 'Grace Lee', 24, 'Marketing', 55000),
      ('henry', 'Henry Zhang', 31, 'Engineering', 98000),
      ('ivy', 'Ivy Martinez', 29, 'Design', 75000),
      ('jack', 'Jack Thompson', 26, 'Engineering', 82000),
    ];

    for (final (id, name, age, dept, salary) in people) {
      graph.addNode(Node(
        id: id,
        type: 'Person',
        label: name,
        properties: {
          'age': age,
          'department': dept,
          'salary': salary,
          'active': true,
        },
      ));
    }
  }

  void _addTeams() {
    final teams = [
      ('engineering', 'Engineering', 15, 180000),
      ('marketing', 'Marketing', 8, 80000),
      ('design', 'Design', 5, 60000),
      ('management', 'Management', 3, 200000),
    ];

    for (final (id, name, size, budget) in teams) {
      graph.addNode(Node(
        id: id,
        type: 'Team',
        label: name,
        properties: {
          'size': size,
          'budget': budget,
          'established': 2020 + (size % 4),
        },
      ));
    }
  }

  void _addProjects() {
    final projects = [
      ('web_app', 'Web Application', 'active', 150000),
      ('mobile_app', 'Mobile App', 'planning', 120000),
      ('api_service', 'API Service', 'active', 80000),
      ('ml_platform', 'ML Platform', 'research', 200000),
      ('marketing_site', 'Marketing Site', 'completed', 45000),
    ];

    for (final (id, name, status, budget) in projects) {
      graph.addNode(Node(
        id: id,
        type: 'Project',
        label: name,
        properties: {
          'status': status,
          'budget': budget,
          'priority': budget > 100000 ? 'high' : 'medium',
        },
      ));
    }
  }

  void _addRelationships() {
    // People -> Teams
    final workRelations = [
      ('alice', 'engineering'),
      ('bob', 'engineering'),
      ('david', 'engineering'),
      ('henry', 'engineering'),
      ('jack', 'engineering'),
      ('carol', 'marketing'),
      ('grace', 'marketing'),
      ('emma', 'design'),
      ('ivy', 'design'),
      ('frank', 'management'),
    ];

    for (final (person, team) in workRelations) {
      graph.addEdge(person, 'WORKS_FOR', team);
    }

    // Teams -> Projects
    final projectRelations = [
      ('engineering', 'web_app'),
      ('engineering', 'mobile_app'),
      ('engineering', 'api_service'),
      ('engineering', 'ml_platform'),
      ('marketing', 'marketing_site'),
      ('design', 'web_app'),
      ('design', 'mobile_app'),
    ];

    for (final (team, project) in projectRelations) {
      graph.addEdge(team, 'WORKS_ON', project);
    }

    // Management relationships
    graph.addEdge('frank', 'MANAGES', 'engineering');
    graph.addEdge('bob', 'LEADS', 'web_app');
    graph.addEdge('david', 'LEADS', 'ml_platform');
  }

  Future<void> _executeQuery() async {
    if (_queryController.text.trim().isEmpty) return;

    setState(() {
      _isLoading = true;
      _error = null;
      _results = [];
    });

    try {
      await Future.delayed(const Duration(milliseconds: 100)); // Show loading

      final results = query.matchRows(_queryController.text.trim());

      setState(() {
        _results = results;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Widget _buildQueryInput() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Query Input',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _queryController,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Enter your WHERE clause query here...',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: _isLoading ? null : _executeQuery,
                  icon: _isLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.play_arrow),
                  label: Text(_isLoading ? 'Executing...' : 'Execute Query'),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: () {
                    _queryController.clear();
                    setState(() {
                      _results = [];
                      _error = null;
                    });
                  },
                  icon: const Icon(Icons.clear),
                  label: const Text('Clear'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSampleQueries() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Sample Queries',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _sampleQueries.map((sample) {
                return ActionChip(
                  label: Text(sample.name),
                  onPressed: () {
                    _queryController.text = sample.query;
                  },
                  tooltip: sample.description,
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResults() {
    if (_error != null) {
      return Card(
        color: Colors.red.shade50,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.error, color: Colors.red.shade700),
                  const SizedBox(width: 8),
                  Text(
                    'Query Error',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.red.shade700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(_error!, style: TextStyle(color: Colors.red.shade800)),
            ],
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'Query Results',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                Text(
                  '${_results.length} result${_results.length == 1 ? '' : 's'}',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_results.isEmpty)
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Center(
                  child: Text(
                    'No results found.\nTry executing a query to see results here.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              )
            else
              _buildResultsTable(),
          ],
        ),
      ),
    );
  }

  Widget _buildResultsTable() {
    if (_results.isEmpty) return const SizedBox.shrink();

    // Get all column names from all results
    final allColumns = <String>{};
    for (final row in _results) {
      allColumns.addAll(row.keys);
    }
    final columns = allColumns.toList()..sort();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: columns.map((col) => DataColumn(
          label: Text(
            col,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        )).toList(),
        rows: _results.map((row) => DataRow(
          cells: columns.map((col) {
            final nodeId = row[col];
            if (nodeId != null) {
              final node = graph.nodesById[nodeId];
              return DataCell(
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      node?.label ?? nodeId,
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    if (node?.properties != null && node!.properties!.isNotEmpty)
                      Text(
                        _formatProperties(node.properties!),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                  ],
                ),
              );
            }
            return const DataCell(Text('-'));
          }).toList(),
        )).toList(),
      ),
    );
  }

  String _formatProperties(Map<String, dynamic> properties) {
    final formatted = properties.entries
        .map((e) => '${e.key}: ${e.value}')
        .take(3)
        .join(', ');
    return properties.length > 3 ? '$formatted...' : formatted;
  }

  Widget _buildDataOverview() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Data Overview',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildDataStat('People', '10', Icons.person),
                const SizedBox(width: 24),
                _buildDataStat('Teams', '4', Icons.group),
                const SizedBox(width: 24),
                _buildDataStat('Projects', '5', Icons.work),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Available Properties:',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                _buildPropertyChip('person.age', 'number'),
                _buildPropertyChip('person.department', 'string'),
                _buildPropertyChip('person.salary', 'number'),
                _buildPropertyChip('team.size', 'number'),
                _buildPropertyChip('team.budget', 'number'),
                _buildPropertyChip('project.status', 'string'),
                _buildPropertyChip('project.budget', 'number'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDataStat(String label, String value, IconData icon) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 20, color: Colors.blue.shade600),
        const SizedBox(width: 4),
        Text(
          '$value $label',
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Widget _buildPropertyChip(String property, String type) {
    return Chip(
      label: Text(
        property,
        style: const TextStyle(fontSize: 12),
      ),
      backgroundColor: type == 'number'
        ? Colors.blue.shade50
        : Colors.green.shade50,
      side: BorderSide(
        color: type == 'number'
          ? Colors.blue.shade200
          : Colors.green.shade200,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('WHERE Clause Demo'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.info),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('About WHERE Clauses'),
                  content: const Text(
                    'This demo shows GraphKit\'s new WHERE clause support. '
                    'You can filter nodes by their properties using comparison '
                    'operators (>, <, =, !=, >=, <=) and logical operators (AND, OR).\n\n'
                    'Try the sample queries or create your own!',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Got it'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildDataOverview(),
            const SizedBox(height: 16),
            _buildSampleQueries(),
            const SizedBox(height: 16),
            _buildQueryInput(),
            const SizedBox(height: 16),
            _buildResults(),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }
}

class QuerySample {
  final String name;
  final String query;
  final String description;

  const QuerySample(this.name, this.query, this.description);
}