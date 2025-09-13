import 'package:graph_kit/graph_kit.dart';  

void main() {
  print('🏗️  PROJECT DEPENDENCY ANALYSIS');
  print('===============================\n');

  final graph = Graph<Node>();
  final query = PatternQuery(graph);

  // Build project dependency graph
  print('📋 Building project dependency graph...\n');
  
  // Frontend services
  graph.addNode(Node(id: 'web_app', type: 'Frontend', label: 'Web Application'));
  graph.addNode(Node(id: 'mobile_app', type: 'Frontend', label: 'Mobile App'));
  
  // Backend services
  graph.addNode(Node(id: 'api_gateway', type: 'Service', label: 'API Gateway'));
  graph.addNode(Node(id: 'auth_service', type: 'Service', label: 'Authentication Service'));
  graph.addNode(Node(id: 'user_service', type: 'Service', label: 'User Management'));
  graph.addNode(Node(id: 'order_service', type: 'Service', label: 'Order Processing'));
  graph.addNode(Node(id: 'payment_service', type: 'Service', label: 'Payment Gateway'));
  graph.addNode(Node(id: 'notification_service', type: 'Service', label: 'Notifications'));
  
  // Databases
  graph.addNode(Node(id: 'user_db', type: 'Database', label: 'User Database'));
  graph.addNode(Node(id: 'order_db', type: 'Database', label: 'Order Database'));
  graph.addNode(Node(id: 'analytics_db', type: 'Database', label: 'Analytics Database'));
  
  // External services
  graph.addNode(Node(id: 'stripe', type: 'External', label: 'Stripe Payment API'));
  graph.addNode(Node(id: 'sendgrid', type: 'External', label: 'SendGrid Email API'));
  graph.addNode(Node(id: 'redis', type: 'Cache', label: 'Redis Cache'));

  // Frontend dependencies
  graph.addEdge('web_app', 'DEPENDS_ON', 'api_gateway');
  graph.addEdge('mobile_app', 'DEPENDS_ON', 'api_gateway');
  
  // API Gateway dependencies
  graph.addEdge('api_gateway', 'DEPENDS_ON', 'auth_service');
  graph.addEdge('api_gateway', 'DEPENDS_ON', 'user_service');
  graph.addEdge('api_gateway', 'DEPENDS_ON', 'order_service');
  
  // Service-to-service dependencies
  graph.addEdge('order_service', 'DEPENDS_ON', 'payment_service');
  graph.addEdge('order_service', 'DEPENDS_ON', 'user_service');
  graph.addEdge('order_service', 'DEPENDS_ON', 'notification_service');
  
  graph.addEdge('user_service', 'DEPENDS_ON', 'auth_service');
  graph.addEdge('payment_service', 'DEPENDS_ON', 'auth_service');
  
  // Database dependencies
  graph.addEdge('auth_service', 'DEPENDS_ON', 'user_db');
  graph.addEdge('user_service', 'DEPENDS_ON', 'user_db');
  graph.addEdge('order_service', 'DEPENDS_ON', 'order_db');
  graph.addEdge('order_service', 'DEPENDS_ON', 'analytics_db');
  
  // External dependencies
  graph.addEdge('payment_service', 'DEPENDS_ON', 'stripe');
  graph.addEdge('notification_service', 'DEPENDS_ON', 'sendgrid');
  
  // Cache dependencies
  graph.addEdge('user_service', 'DEPENDS_ON', 'redis');
  graph.addEdge('auth_service', 'DEPENDS_ON', 'redis');

  print('🔍 DEPENDENCY ANALYSIS');
  print('======================\n');

  // 1. What does the web app depend on (all levels)?
  print('1️⃣  Complete dependency tree for Web Application:');
  final webDeps = expandSubgraph(
    graph,
    seeds: {'web_app'},
    edgeTypesRightward: {'DEPENDS_ON'},
    forwardHops: 5, // Deep traversal
  );
  _printDependencyTree('web_app', webDeps, graph, 0);

  // 2. What services depend on the user database?
  print('\n2️⃣  What services depend on User Database (directly or indirectly)?');
  final userDbDependents = expandSubgraph(
    graph,
    seeds: {'user_db'},
    edgeTypesRightward: {'DEPENDS_ON'},
    backwardHops: 5, // Look backwards to find dependents
  );
  _printDependents('user_db', userDbDependents, graph);

  // 3. Critical path analysis - what happens if auth_service fails?
  print('\n3️⃣  Impact analysis: What breaks if Authentication Service fails?');
  final authDependents = expandSubgraph(
    graph,
    seeds: {'auth_service'},
    edgeTypesRightward: {'DEPENDS_ON'},
    backwardHops: 5,
  );
  _printImpactAnalysis('auth_service', authDependents, graph);

  // 4. Find all external dependencies
  print('\n4️⃣  All external dependencies in the system:');
  final externalServices = query.findByType('External');
  final allExternalDeps = <String, Set<String>>{};
  
  for (final extService in externalServices) {
    final dependents = expandSubgraph(
      graph,
      seeds: {extService},
      edgeTypesRightward: {'DEPENDS_ON'},
      backwardHops: 5,
    );
    allExternalDeps[extService] = dependents.nodes..remove(extService);
  }
  
  for (final entry in allExternalDeps.entries) {
    final extNode = graph.nodesById[entry.key];
    print('   📡 ${extNode?.label}:');
    for (final depId in entry.value) {
      final depNode = graph.nodesById[depId];
      print('      • ${depNode?.label} (${depNode?.type})');
    }
  }

  // 5. Database usage analysis
  print('\n5️⃣  Database usage analysis:');
  final databases = query.findByType('Database');
  for (final dbId in databases) {
    final dbNode = graph.nodesById[dbId];
    final dbUsers = expandSubgraph(
      graph,
      seeds: {dbId},
      edgeTypesRightward: {'DEPENDS_ON'},
      backwardHops: 3,
    );
    final directUsers = query.inTo(dbId, 'DEPENDS_ON');
    
    print('   🗄️  ${dbNode?.label}:');
    print('      Direct consumers: ${directUsers.length}');
    print('      Total impact: ${dbUsers.nodes.length - 1} services'); // -1 to exclude the DB itself
    
    for (final userId in directUsers) {
      final userNode = graph.nodesById[userId];
      print('      • ${userNode?.label}');
    }
  }

  // 6. Service layer analysis
  print('\n6️⃣  Service dependency layers:');
  final layers = _analyzeLayers(graph, query);
  for (var i = 0; i < layers.length; i++) {
    print('   Layer $i: ${layers[i].map((id) => graph.nodesById[id]?.label).join(', ')}');
  }
}

void _printDependencyTree(String rootId, SubgraphResult deps, Graph<Node> graph, int level) {
  final root = graph.nodesById[rootId];
  final indent = '   ${'  ' * level}';
  
  if (level == 0) {
    print('$indent📱 ${root?.label}');
  }
  
  // Get direct dependencies
  final directDeps = graph.outNeighbors(rootId, 'DEPENDS_ON');
  
  for (final depId in directDeps) {
    final depNode = graph.nodesById[depId];
    final icon = _getServiceIcon(depNode?.type ?? '');
    print('$indent├─ $icon ${depNode?.label}');
    
    if (level < 3) { // Prevent infinite recursion
      _printDependencyTree(depId, deps, graph, level + 1);
    }
  }
}

void _printDependents(String rootId, SubgraphResult dependents, Graph<Node> graph) {
  final root = graph.nodesById[rootId];
  print('   🗄️  ${root?.label} is used by:');
  
  for (final nodeId in dependents.nodes) {
    if (nodeId != rootId) {
      final node = graph.nodesById[nodeId];
      final distance = dependents.backwardDist[nodeId] ?? 0;
      final icon = _getServiceIcon(node?.type ?? '');
      print('   ${distance == 1 ? '├─' : '└─'} $icon ${node?.label} ${distance > 1 ? '(indirect)' : '(direct)'}');
    }
  }
}

void _printImpactAnalysis(String serviceId, SubgraphResult impact, Graph<Node> graph) {
  final service = graph.nodesById[serviceId];
  print('   ⚠️  If ${service?.label} fails, these services are affected:');
  
  final affected = impact.nodes.where((id) => id != serviceId).toList()
    ..sort((a, b) => (impact.backwardDist[a] ?? 0).compareTo(impact.backwardDist[b] ?? 0));
  
  for (final affectedId in affected) {
    final node = graph.nodesById[affectedId];
    final distance = impact.backwardDist[affectedId] ?? 0;
    final severity = distance == 1 ? 'CRITICAL' : distance == 2 ? 'HIGH' : 'MEDIUM';
    final icon = _getServiceIcon(node?.type ?? '');
    print('   • $icon ${node?.label} [$severity impact]');
  }
}

String _getServiceIcon(String type) {
  switch (type) {
    case 'Frontend': return '📱';
    case 'Service': return '⚙️';
    case 'Database': return '🗄️';
    case 'External': return '📡';
    case 'Cache': return '⚡';
    default: return '📦';
  }
}

List<List<String>> _analyzeLayers(Graph<Node> graph, PatternQuery<Node> query) {
  final layers = <List<String>>[];
  final processed = <String>{};
  final allNodes = graph.nodesById.keys.toSet();
  
  while (processed.length < allNodes.length) {
    final currentLayer = <String>[];
    
    for (final nodeId in allNodes) {
      if (processed.contains(nodeId)) continue;
      
      // Check if all dependencies are already processed
      final deps = graph.outNeighbors(nodeId, 'DEPENDS_ON');
      if (deps.every((dep) => processed.contains(dep))) {
        currentLayer.add(nodeId);
      }
    }
    
    if (currentLayer.isEmpty) break; // Circular dependency or error
    
    processed.addAll(currentLayer);
    layers.add(currentLayer);
  }
  
  return layers;
}