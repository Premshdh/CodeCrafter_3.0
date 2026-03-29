import 'package:flutter/material.dart';
import 'package:graphview/graphview.dart';
import 'package:codecrafter/quiz.dart';
import 'package:codecrafter/api_service.dart';
import 'package:codecrafter/models.dart';
import 'package:codecrafter/chat_view.dart';

class SubjectDependencyGraph extends StatefulWidget {
  final String subjectName;
  final SubjectData? initialData;

  const SubjectDependencyGraph({
    super.key, 
    this.subjectName = "Machine Learning",
    this.initialData,
  });

  @override
  State<SubjectDependencyGraph> createState() => _SubjectDependencyGraphState();
}

class _SubjectDependencyGraphState extends State<SubjectDependencyGraph> {
  final TransformationController _transformationController =
      TransformationController();
  
  final ApiService _apiService = ApiService();
  SubjectData? _subjectData;
  String? _errorMessage;

  Graph? graph;
  SugiyamaAlgorithm? algorithm;
  bool isReady = false;
  Set<String> completedIds = {};

  @override
  void initState() {
    super.initState();
    if (widget.initialData != null) {
      _subjectData = widget.initialData;
      _setupGraph();
      isReady = true;
    } else {
      _fetchGraphData();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _resetView());
  }

  Future<void> _fetchGraphData() async {
    setState(() {
      isReady = false;
      _errorMessage = null;
    });
    try {
      final data = await _apiService.fetchSubjectData(widget.subjectName);
      if (data.subjects.isEmpty) {
        setState(() {
          _errorMessage = "No subjects found for '${widget.subjectName}'.";
          isReady = true;
        });
        return;
      }

      setState(() {
        _subjectData = data;
        _setupGraph();
        isReady = true;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          isReady = true;
        });
      }
    }
  }

  void _setupGraph() {
    if (_subjectData == null || _subjectData!.subjects.isEmpty) return;

    final newGraph = Graph();
    final Map<String, Node> nodeMap = {};

    for (var subject in _subjectData!.subjects) {
      var node = Node.Id(subject.id);
      nodeMap[subject.id] = node;
      newGraph.addNode(node);
    }

    for (var dep in _subjectData!.dependencies) {
      final fromNode = nodeMap[dep.from];
      final toNode = nodeMap[dep.to];
      if (fromNode != null && toNode != null) {
        newGraph.addEdge(fromNode, toNode);
      }
    }

    final config = SugiyamaConfiguration()
      ..nodeSeparation = 80
      ..levelSeparation = 100
      ..orientation = SugiyamaConfiguration.ORIENTATION_TOP_BOTTOM;

    setState(() {
      graph = newGraph;
      algorithm = SugiyamaAlgorithm(config);
    });
  }

  void _resetView() {
    _transformationController.value = Matrix4.identity();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text("${widget.subjectName} Roadmap"),
        actions: [
          IconButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const ChatView()),
            ),
            icon: const Icon(Icons.chat_bubble_outline),
          ),
          IconButton(
            onPressed: _fetchGraphData,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            onPressed: _resetView,
            icon: const Icon(Icons.center_focus_strong),
          )
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _resetView,
        child: const Icon(Icons.fullscreen_exit),
      ),
      body: _buildBody(theme),
    );
  }

  Widget _buildBody(ThemeData theme) {
    if (!isReady) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 60, color: Colors.red),
              const SizedBox(height: 16),
              Text("Error", style: theme.textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(_errorMessage!, textAlign: TextAlign.center),
              const SizedBox(height: 24),
              ElevatedButton(onPressed: _fetchGraphData, child: const Text("Retry"))
            ],
          ),
        ),
      );
    }

    if (graph == null || graph!.nodes.isEmpty) {
      return const Center(child: Text("No subjects available."));
    }

    return InteractiveViewer(
      transformationController: _transformationController,
      constrained: false,
      boundaryMargin: const EdgeInsets.all(500),
      minScale: 0.05,
      maxScale: 2.0,
      child: Padding(
        padding: const EdgeInsets.all(100.0),
        child: GraphView(
          graph: graph!,
          algorithm: algorithm!,
          paint: Paint()
            ..color = theme.colorScheme.primary
            ..strokeWidth = 2.0
            ..style = PaintingStyle.stroke,
          builder: (Node node) {
            var id = node.key!.value as String;
            var subject = _subjectData!.subjects.firstWhere((s) => s.id == id);
            return GestureDetector(
              onTap: () => _showDetails(subject),
              child: _buildNodeBox(subject),
            );
          },
        ),
      ),
    );
  }

  void _showDetails(Subject subject) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.5,
          minChildSize: 0.3,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            final theme = Theme.of(context);
            return Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  Container(width: 50, height: 5, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10))),
                  Expanded(
                    child: ListView(
                      controller: scrollController,
                      padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                      children: [
                        Text(subject.name, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 10),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Chip(
                            label: Text(subject.type.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold)),
                            backgroundColor: theme.colorScheme.primaryContainer,
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Text("Overview", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                        const SizedBox(height: 8),
                        Text(subject.desc, style: const TextStyle(fontSize: 16, height: 1.5)),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => SubjectQuiz(
                                subjectId: subject.id,
                                subjectName: subject.name,
                                onComplete: () => setState(() => completedIds.add(subject.id)),
                              ),
                            ),
                          );
                        },
                        child: const Text("Start Quiz", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildNodeBox(Subject subject) {
    bool isDone = completedIds.contains(subject.id);
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDone ? Colors.green[50] : theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isDone ? Colors.green : theme.colorScheme.primary, width: 2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(subject.name, style: const TextStyle(fontWeight: FontWeight.bold)),
          if (isDone) ...[
            const SizedBox(width: 8),
            const Icon(Icons.check_circle, color: Colors.green, size: 18),
          ],
        ],
      ),
    );
  }
}
