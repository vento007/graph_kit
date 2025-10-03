import 'package:flutter/material.dart';
import 'package:graph_kit/graph_kit.dart';

class ReturnClauseDemoApp extends StatelessWidget {
  const ReturnClauseDemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const ReturnClauseDemo();
  }
}

class ReturnClauseDemo extends StatefulWidget {
  const ReturnClauseDemo({super.key});

  @override
  State<ReturnClauseDemo> createState() => _ReturnClauseDemoState();
}

class _ReturnClauseDemoState extends State<ReturnClauseDemo> {
  late Graph<Node> graph;
  late PatternQuery<Node> query;
  final TextEditingController _queryController = TextEditingController();
  List<Map<String, dynamic>> _results = [];
  String? _error;
  bool _isLoading = false;
  bool _showComparison = false;

  // Predefined sample queries showcasing RETURN features
  final List<QuerySample> _sampleQueries = [
    QuerySample(
      'Employee Directory',
      'MATCH person:Person-[:WORKS_FOR]->team:Team RETURN person.name AS Employee, person.role AS Title, person.salary AS Salary, team.name AS Department',
      'Clean employee listing with aliased columns',
    ),
    QuerySample(
      'Simple Property Access',
      'MATCH person:Person RETURN person.name, person.age',
      'Return specific properties only',
    ),
    QuerySample(
      'Variable Projection',
      'MATCH person:Person-[:WORKS_FOR]->team RETURN person, team',
      'Return node IDs (for hydration pattern)',
    ),
    QuerySample(
      'Aliasing Example',
      'MATCH person:Person WHERE person.salary > 90000 RETURN person.name AS EmployeeName, person.salary AS AnnualSalary',
      'Custom column names with aliases',
    ),
    QuerySample(
      'Multi-hop with Properties',
      'MATCH person:Person-[:WORKS_FOR]->team-[:WORKS_ON]->project RETURN person.name, team.name AS Department, project.name AS Project',
      'Properties across relationships',
    ),
    QuerySample(
      'Mixed Variables & Properties',
      'MATCH person:Person-[:WORKS_FOR]->team RETURN person, person.name, team.name AS dept',
      'Combine IDs and properties',
    ),
    QuerySample(
      'High Earners Report',
      'MATCH person:Person WHERE person.salary >= 95000 RETURN person.name AS Name, person.department AS Dept, person.salary AS Compensation',
      'Filtered + projected results',
    ),
    QuerySample(
      'Team Overview',
      'MATCH team:Team RETURN team.name AS Team, team.size AS Members, team.budget AS Budget',
      'Team information projection',
    ),
    QuerySample(
      'Engineer Skills',
      'MATCH person:Person WHERE person.department = "Engineering" RETURN person.name AS Engineer, person.salary AS Pay, person.age AS Age',
      'Department-specific projection',
    ),
    QuerySample(
      'Project Status',
      'MATCH team-[:WORKS_ON]->project:Project RETURN team AS TeamID, project.name AS ProjectName, project.status AS Status, project.budget',
      'Mix of aliased and non-aliased',
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

    _addPeople();
    _addTeams();
    _addProjects();
    _addRelationships();
  }

  void _addPeople() {
    final people = [
      ('alice', 'Alice Cooper', 28, 'Engineering', 85000, 'Senior Engineer'),
      ('bob', 'Bob Wilson', 35, 'Engineering', 95000, 'Staff Engineer'),
      ('carol', 'Carol Davis', 22, 'Marketing', 60000, 'Marketing Coordinator'),
      ('david', 'David Smith', 45, 'Engineering', 120000, 'Principal Engineer'),
      ('emma', 'Emma Johnson', 27, 'Design', 70000, 'UX Designer'),
      ('frank', 'Frank Brown', 52, 'Management', 150000, 'Engineering Manager'),
      ('grace', 'Grace Lee', 24, 'Marketing', 55000, 'Content Writer'),
      ('henry', 'Henry Zhang', 31, 'Engineering', 98000, 'Senior Engineer'),
      ('ivy', 'Ivy Martinez', 29, 'Design', 75000, 'Product Designer'),
      ('jack', 'Jack Thompson', 26, 'Engineering', 82000, 'Software Engineer'),
    ];

    for (final (id, name, age, dept, salary, role) in people) {
      graph.addNode(Node(
        id: id,
        type: 'Person',
        label: name,
        properties: {
          'name': name,
          'age': age,
          'department': dept,
          'salary': salary,
          'role': role,
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
          'name': name,
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
          'name': name,
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
  }

  Future<void> _executeQuery() async {
    if (_queryController.text.trim().isEmpty) return;

    setState(() {
      _isLoading = true;
      _error = null;
      _results = [];
    });

    try {
      await Future.delayed(const Duration(milliseconds: 100));

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
            Row(
              children: [
                const Icon(Icons.edit_note, color: Colors.blue),
                const SizedBox(width: 8),
                const Text(
                  'Query Input',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                Tooltip(
                  message: 'Show Before/After comparison',
                  child: Row(
                    children: [
                      const Text('Compare', style: TextStyle(fontSize: 12)),
                      Switch(
                        value: _showComparison,
                        onChanged: (value) {
                          setState(() {
                            _showComparison = value;
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _queryController,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Enter your RETURN query here...',
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
            const Row(
              children: [
                Icon(Icons.code, color: Colors.green),
                SizedBox(width: 8),
                Text(
                  'Sample Queries',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _sampleQueries.map((sample) {
                return ActionChip(
                  label: Text(sample.name),
                  tooltip: sample.description,
                  onPressed: () {
                    _queryController.text = sample.query;
                    _executeQuery();
                  },
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
              const Row(
                children: [
                  Icon(Icons.error, color: Colors.red),
                  SizedBox(width: 8),
                  Text(
                    'Error',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(fontFamily: 'monospace')),
            ],
          ),
        ),
      );
    }

    if (_results.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Center(
            child: Column(
              children: [
                Icon(Icons.search_off, size: 48, color: Colors.grey.shade400),
                const SizedBox(height: 16),
                Text(
                  'No results yet',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
                ),
                const SizedBox(height: 8),
                Text(
                  'Try executing a query or click a sample above',
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_showComparison) {
      return _buildComparisonView();
    }

    return _buildFormattedResults();
  }

  Widget _buildFormattedResults() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.table_chart, color: Colors.blue),
                const SizedBox(width: 8),
                Text(
                  'Results (${_results.length} rows)',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildResultsTable(),
          ],
        ),
      ),
    );
  }

  Widget _buildResultsTable() {
    if (_results.isEmpty) return const SizedBox();

    final columns = _results.first.keys.toList();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowColor: WidgetStateProperty.all(Colors.blue.shade50),
        columns: columns.map((col) {
          return DataColumn(
            label: Text(
              col,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          );
        }).toList(),
        rows: _results.map((row) {
          return DataRow(
            cells: columns.map((col) {
              final value = row[col];
              return DataCell(Text(_formatValue(value)));
            }).toList(),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildComparisonView() {
    // Get query without RETURN clause
    String queryWithoutReturn = _queryController.text.trim();
    if (queryWithoutReturn.toUpperCase().contains('RETURN')) {
      queryWithoutReturn = queryWithoutReturn
          .substring(0, queryWithoutReturn.toUpperCase().indexOf('RETURN'))
          .trim();
    }

    List<Map<String, dynamic>> rawResults = [];
    try {
      rawResults = query.matchRows(queryWithoutReturn);
    } catch (e) {
      // If fails, just show current results
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Before & After Comparison',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        color: Colors.red.shade50,
                        child: const Row(
                          children: [
                            Icon(Icons.close, color: Colors.red, size: 16),
                            SizedBox(width: 4),
                            Text(
                              'Without RETURN (Raw IDs)',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (rawResults.isNotEmpty)
                        Container(
                          constraints: const BoxConstraints(maxHeight: 300),
                          child: SingleChildScrollView(
                            child: Text(
                              rawResults.take(3).map((r) => r.toString()).join('\n\n'),
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 11,
                              ),
                            ),
                          ),
                        )
                      else
                        const Text('No data', style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        color: Colors.green.shade50,
                        child: const Row(
                          children: [
                            Icon(Icons.check, color: Colors.green, size: 16),
                            SizedBox(width: 4),
                            Text(
                              'With RETURN (Clean Data)',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        constraints: const BoxConstraints(maxHeight: 300),
                        child: SingleChildScrollView(
                          child: _buildResultsTable(),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatValue(dynamic value) {
    if (value == null) return 'null';
    if (value is num) {
      if (value > 10000) {
        return '\$${value.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},')}';
      }
      return value.toString();
    }
    return value.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('RETURN Clause Demo'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.blue.shade50,
              Colors.blue.shade100,
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildInfoCard(),
                const SizedBox(height: 16),
                _buildSampleQueries(),
                const SizedBox(height: 16),
                _buildQueryInput(),
                const SizedBox(height: 16),
                _buildResults(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard() {
    return Card(
      color: Colors.blue.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.info, color: Colors.blue),
                SizedBox(width: 8),
                Text(
                  'RETURN Clause Features',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text('• Variable projection: RETURN person, team'),
            const Text('• Property access: RETURN person.name, team.size'),
            const Text('• AS aliasing: RETURN person.name AS Employee'),
            const Text('• Works with WHERE, variable-length paths, and more'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'Tip: Toggle "Compare" to see before/after difference!',
                style: TextStyle(
                  fontStyle: FontStyle.italic,
                  fontSize: 12,
                ),
              ),
            ),
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

  QuerySample(this.name, this.query, this.description);
}
