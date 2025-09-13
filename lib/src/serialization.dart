import 'dart:convert';
import 'graph.dart';
import 'node.dart';

/// Serialization support for Graph data structures
///
/// Provides JSON import/export functionality for graphs, enabling:
/// - Saving/loading graph data to files
/// - Network transmission of graph structures
/// - Data exchange with other systems
/// - Test fixture management
class GraphSerializer {
  /// Converts a Graph to JSON-serializable format
  ///
  /// Returns a Map that can be encoded to JSON with standard dart:convert
  ///
  /// Example:
  /// ```dart
  /// final json = GraphSerializer.toJson(myGraph);
  /// final jsonString = jsonEncode(json);
  /// ```
  static Map<String, dynamic> toJson<N extends Node>(Graph<N> graph) {
    final nodes = <Map<String, dynamic>>[];
    final edges = <Map<String, dynamic>>[];

    // Serialize nodes
    for (final node in graph.nodesById.values) {
      final nodeJson = <String, dynamic>{
        'id': node.id,
        'type': node.type,
        'label': node.label,
      };

      // Include properties if present
      if (node.properties != null && node.properties!.isNotEmpty) {
        nodeJson['properties'] = node.properties;
      }

      nodes.add(nodeJson);
    }

    // Serialize edges by traversing the adjacency structure
    final seenEdges = <String>{};
    for (final srcId in graph.out.keys) {
      final edgesByType = graph.out[srcId]!;
      for (final edgeType in edgesByType.keys) {
        final dstIds = edgesByType[edgeType]!;
        for (final dstId in dstIds) {
          // Create unique edge identifier to avoid duplicates
          final edgeKey = '$srcId->$edgeType->$dstId';
          if (!seenEdges.contains(edgeKey)) {
            seenEdges.add(edgeKey);
            edges.add({
              'src': srcId,
              'type': edgeType,
              'dst': dstId,
            });
          }
        }
      }
    }

    return {
      'version': '1.0',
      'nodes': nodes,
      'edges': edges,
      'metadata': {
        'nodeCount': graph.nodesById.length,
        'edgeCount': edges.length,
        'serializedAt': DateTime.now().toIso8601String(),
      }
    };
  }

  /// Creates a Graph from JSON data
  ///
  /// Expects JSON in the format produced by [toJson]
  ///
  /// Example:
  /// ```dart
  /// final jsonString = await File('graph.json').readAsString();
  /// final json = jsonDecode(jsonString);
  /// final graph = GraphSerializer.fromJson<Node>(json, Node.fromJson);
  /// ```
  static Graph<N> fromJson<N extends Node>(
    Map<String, dynamic> json,
    N Function(Map<String, dynamic>) nodeFactory,
  ) {
    final graph = Graph<N>();

    // Validate version compatibility
    final version = json['version'] as String?;
    if (version != '1.0') {
      throw FormatException('Unsupported graph format version: $version');
    }

    // Deserialize nodes
    final nodes = json['nodes'] as List<dynamic>?;
    if (nodes != null) {
      for (final nodeData in nodes) {
        final nodeMap = nodeData as Map<String, dynamic>;
        final node = nodeFactory(nodeMap);
        graph.addNode(node);
      }
    }

    // Deserialize edges
    final edges = json['edges'] as List<dynamic>?;
    if (edges != null) {
      for (final edgeData in edges) {
        final edgeMap = edgeData as Map<String, dynamic>;
        final src = edgeMap['src'] as String;
        final type = edgeMap['type'] as String;
        final dst = edgeMap['dst'] as String;

        // Validate that referenced nodes exist
        if (!graph.nodesById.containsKey(src)) {
          throw FormatException('Edge references non-existent source node: $src');
        }
        if (!graph.nodesById.containsKey(dst)) {
          throw FormatException('Edge references non-existent destination node: $dst');
        }

        graph.addEdge(src, type, dst);
      }
    }

    return graph;
  }

  /// Convenience method to serialize graph directly to JSON string
  static String toJsonString<N extends Node>(Graph<N> graph, {bool pretty = false}) {
    final json = toJson(graph);
    if (pretty) {
      const encoder = JsonEncoder.withIndent('  ');
      return encoder.convert(json);
    }
    return jsonEncode(json);
  }

  /// Convenience method to deserialize graph directly from JSON string
  static Graph<N> fromJsonString<N extends Node>(
    String jsonString,
    N Function(Map<String, dynamic>) nodeFactory,
  ) {
    final json = jsonDecode(jsonString) as Map<String, dynamic>;
    return fromJson(json, nodeFactory);
  }

  /// Validates that JSON data represents a valid graph structure
  ///
  /// Returns true if the JSON can be successfully deserialized
  /// Throws [FormatException] with details if invalid
  static bool validateJson(Map<String, dynamic> json) {
    // Check required fields
    if (!json.containsKey('version')) {
      throw const FormatException('Missing required field: version');
    }
    if (!json.containsKey('nodes')) {
      throw const FormatException('Missing required field: nodes');
    }
    if (!json.containsKey('edges')) {
      throw const FormatException('Missing required field: edges');
    }

    final nodes = json['nodes'];
    if (nodes is! List) {
      throw const FormatException('Field "nodes" must be a list');
    }

    final edges = json['edges'];
    if (edges is! List) {
      throw const FormatException('Field "edges" must be a list');
    }

    // Validate node structure
    final nodeIds = <String>{};
    for (final nodeData in nodes) {
      if (nodeData is! Map<String, dynamic>) {
        throw const FormatException('Each node must be a map');
      }

      final id = nodeData['id'];
      if (id is! String || id.isEmpty) {
        throw const FormatException('Node "id" must be a non-empty string');
      }

      if (nodeIds.contains(id)) {
        throw FormatException('Duplicate node ID: $id');
      }
      nodeIds.add(id);

      if (!nodeData.containsKey('type') || nodeData['type'] is! String) {
        throw FormatException('Node $id missing or invalid "type" field');
      }

      if (!nodeData.containsKey('label') || nodeData['label'] is! String) {
        throw FormatException('Node $id missing or invalid "label" field');
      }
    }

    // Validate edge structure and references
    for (final edgeData in edges) {
      if (edgeData is! Map<String, dynamic>) {
        throw const FormatException('Each edge must be a map');
      }

      final src = edgeData['src'];
      final type = edgeData['type'];
      final dst = edgeData['dst'];

      if (src is! String || src.isEmpty) {
        throw const FormatException('Edge "src" must be a non-empty string');
      }
      if (type is! String || type.isEmpty) {
        throw const FormatException('Edge "type" must be a non-empty string');
      }
      if (dst is! String || dst.isEmpty) {
        throw const FormatException('Edge "dst" must be a non-empty string');
      }

      if (!nodeIds.contains(src)) {
        throw FormatException('Edge references non-existent source node: $src');
      }
      if (!nodeIds.contains(dst)) {
        throw FormatException('Edge references non-existent destination node: $dst');
      }
    }

    return true;
  }
}

/// Extension methods to add serialization directly to Graph class
extension GraphSerialization<N extends Node> on Graph<N> {
  /// Serialize this graph to JSON
  Map<String, dynamic> toJson() => GraphSerializer.toJson(this);

  /// Serialize this graph to a JSON string
  String toJsonString({bool pretty = false}) =>
    GraphSerializer.toJsonString(this, pretty: pretty);
}