import 'package:graph_kit/graph_kit.dart';
import 'package:test/test.dart';

void main() {
  group('Inline property filters', () {
    late Graph<Node> graph;
    late PatternQuery<Node> query;

    setUp(() {
      graph = Graph<Node>();
      query = PatternQuery(graph);

      graph.addNode(
        Node(
          id: 'root-user',
          type: 'Source',
          label: 'User Root',
          properties: {'sourceKind': 'user'},
        ),
      );
      graph.addNode(
        Node(
          id: 'root-asset',
          type: 'Source',
          label: 'Asset Root',
          properties: {'sourceKind': 'asset'},
        ),
      );

      graph.addNode(
        Node(
          id: 'policy-high',
          type: 'Policy',
          label: 'High Policy',
          properties: {'priority': 'high'},
        ),
      );
      graph.addNode(
        Node(
          id: 'policy-low',
          type: 'Policy',
          label: 'Low Policy',
          properties: {'priority': 'low'},
        ),
      );

      graph.addNode(
        Node(
          id: 'asset-west',
          type: 'Asset',
          label: 'West Asset',
          properties: {'region': 'us-west'},
        ),
      );
      graph.addNode(
        Node(
          id: 'asset-eu',
          type: 'Asset',
          label: 'EU Asset',
          properties: {'region': 'eu-central'},
        ),
      );
      graph.addNode(
        Node(
          id: 'segment-west',
          type: 'AssetSegment',
          label: 'West Segment',
          properties: {'region': 'us-west', 'hop': 1},
        ),
      );

      graph
        ..addEdge('root-user', 'HAS_POLICY', 'policy-high')
        ..addEdge('root-user', 'HAS_POLICY', 'policy-low')
        ..addEdge('root-asset', 'HAS_POLICY', 'policy-high')
        ..addEdge('policy-high', 'GRANTS_ACCESS', 'segment-west')
        ..addEdge('segment-west', 'GRANTS_ACCESS', 'asset-west')
        ..addEdge('policy-high', 'GRANTS_ACCESS', 'asset-west')
        ..addEdge('policy-low', 'GRANTS_ACCESS', 'asset-eu');
    });

    test('filters starting node via property equality', () {
      final paths = query.matchPaths(
        'root:Source{sourceKind:"user"}-[:HAS_POLICY]->policy:Policy',
      );

      expect(paths, hasLength(2));
      for (final path in paths) {
        expect(path.nodes['root'], equals('root-user'));
      }
    });

    test('filters inner nodes via property value', () {
      final paths = query.matchPaths(
        'root:Source-[:HAS_POLICY]->policy:Policy{priority:"high"}',
      );

      expect(paths, hasLength(2));
      for (final path in paths) {
        expect(path.nodes['policy'], equals('policy-high'));
      }
    });

    test('supports contains operator on custom properties', () {
      final paths = query.matchPaths(
        'root:Source{sourceKind~"ASSET"}-[:HAS_POLICY]->policy:Policy-[:GRANTS_ACCESS]->asset:Asset',
      );

      expect(paths, hasLength(1));
      final path = paths.single;
      expect(path.nodes['root'], equals('root-asset'));
      expect(path.nodes['asset'], equals('asset-west'));
    });

    test('respects property filters after variable-length traversal', () {
      final paths = query.matchPaths(
        'policy:Policy{priority:"high"}-[:GRANTS_ACCESS*1..2]->asset:Asset{region:"us-west"}',
      );

      expect(paths, isNotEmpty);
      for (final path in paths) {
        expect(path.nodes['asset'], equals('asset-west'));
      }
    });

    test('applies filters in mixed-direction patterns', () {
      final rows = query.matchRows(
        'asset:Asset{region:"eu-central"}<-[:GRANTS_ACCESS]-policy:Policy{priority:"low"}<-[:HAS_POLICY]-root:Source{sourceKind:"user"}',
      );

      expect(rows, hasLength(1));
      final row = rows.single;
      expect(row['asset'], equals('asset-eu'));
      expect(row['policy'], equals('policy-low'));
      expect(row['root'], equals('root-user'));
    });

    test('startId seeding still honors inline constraints', () {
      final paths = query.matchPaths(
        'policy:Policy{priority:"low"}-[:GRANTS_ACCESS]->asset:Asset{region:"eu-central"}',
        startId: 'policy-low',
        startType: 'Policy',
      );

      expect(paths, hasLength(1));
      final path = paths.single;
      expect(path.nodes['policy'], equals('policy-low'));
      expect(path.nodes['asset'], equals('asset-eu'));
    });

    test('planner captures inline filters on variable-length segments', () {
      final constraintMaps = query.extractEdgeConstraintMapsForTesting(
        'policy-[:GRANTS_ACCESS*1..2 {since:2020}]->asset',
      );

      expect(constraintMaps, hasLength(1));
      final firstEdgeConstraints = constraintMaps.first;
      expect(firstEdgeConstraints, hasLength(1));
      final constraint = firstEdgeConstraints.single;
      expect(constraint['key'], equals('since'));
      expect(constraint['operator'], equals('='));
      expect(constraint['value'], equals(2020));
    });

    test('planner keeps filters when spacing varies on variable-length edges',
        () {
      final constraintMaps = query.extractEdgeConstraintMapsForTesting(
        'asset<-[:GRANTS_ACCESS*{region:"us-west"}]-segment',
      );

      expect(constraintMaps, hasLength(1));
      final constraint = constraintMaps.first.single;
      expect(constraint['key'], equals('region'));
      expect(constraint['operator'], equals('='));
      expect(constraint['value'], equals('us-west'));
    });
  });
}
