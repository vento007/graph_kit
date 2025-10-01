import 'package:flutter/material.dart';
import 'main_demo.dart';
import 'algorithms_demo.dart';
import 'where_demo.dart';

void main() {
  runApp(const GraphKitDemoLauncher());
}

class GraphKitDemoLauncher extends StatelessWidget {
  const GraphKitDemoLauncher({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Graph Kit Demos',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const DemoMenuPage(),
    );
  }
}

class DemoMenuPage extends StatelessWidget {
  const DemoMenuPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo/Title
                  Icon(
                    Icons.account_tree,
                    size: 80,
                    color: Colors.blue.shade700,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Graph Kit',
                    style: Theme.of(context).textTheme.displayMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade900,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Interactive Demos',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Colors.blue.shade700,
                        ),
                  ),
                  const SizedBox(height: 48),

                  // Demo Cards
                  _buildDemoCard(
                    context,
                    title: 'Pattern Queries',
                    description:
                        'Visual graph with Cypher-like patterns and multiple edge types [:TYPE1|TYPE2]',
                    icon: Icons.hub,
                    color: Colors.blue,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const GraphKitDemo(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                  _buildDemoCard(
                    context,
                    title: 'Graph Algorithms',
                    description:
                        'Shortest path, centrality, components, topological sort, and reachability',
                    icon: Icons.device_hub,
                    color: Colors.green,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const GraphAlgorithmsDemo(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                  _buildDemoCard(
                    context,
                    title: 'WHERE Clause Filtering',
                    description:
                        'Advanced property filtering with WHERE clauses, logical operators, and parentheses',
                    icon: Icons.filter_alt,
                    color: Colors.purple,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const WhereClauseDemoApp(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 48),

                  // Footer
                  Text(
                    'Choose a demo to explore graph_kit features',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.blue.shade600,
                        ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDemoCard(
    BuildContext context, {
    required String title,
    required String description,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500),
          padding: const EdgeInsets.all(24),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  size: 40,
                  color: color,
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: color,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      description,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.grey.shade700,
                          ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                color: color,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
