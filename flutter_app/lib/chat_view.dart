import 'package:flutter/material.dart';
import 'package:codecrafter/api_service.dart';
import 'package:codecrafter/graph.dart';
import 'package:codecrafter/quiz.dart';
import 'package:codecrafter/models.dart';

class ChatView extends StatefulWidget {
  final String? initialSubject;
  const ChatView({super.key, this.initialSubject});

  @override
  State<ChatView> createState() => _ChatViewState();
}

class _ChatViewState extends State<ChatView> {
  final ApiService _apiService = ApiService();
  final TextEditingController _controller = TextEditingController();
  final List<Map<String, dynamic>> _messages = [];
  bool _isLoading = false;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _addSystemMessage("Hello! I'm your Learning Assistant. What would you like to learn today?");
  }

  void _addSystemMessage(String text) {
    setState(() {
      _messages.add({"role": "assistant", "content": text});
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    if (_controller.text.trim().isEmpty) return;

    final userMessage = _controller.text;
    setState(() {
      _messages.add({"role": "user", "content": userMessage});
      _isLoading = true;
      _controller.clear();
    });
    _scrollToBottom();

    try {
      final response = await _apiService.chat(userMessage, widget.initialSubject);
      
      String botResponse = response['response'] ?? "I'm not sure how to respond to that.";
      
      setState(() {
        _messages.add({
          "role": "assistant", 
          "content": botResponse,
          "data": response 
        });
        _isLoading = false;
      });

      if (response['prerequisite_data'] != null) {
        _addSystemMessage("I've generated a learning roadmap for you! Click the button below to view it.");
      }

    } catch (e) {
      setState(() {
        _messages.add({"role": "assistant", "content": "Sorry, I'm having trouble connecting to the brain. Please try again."});
        _isLoading = false;
      });
    }
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        title: const Text("CodeCrafter AI"),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: () => setState(() => _messages.clear()), 
            icon: const Icon(Icons.refresh, color: Color(0xFF6B7280))
          )
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                final isUser = msg["role"] == "user";
                return Column(
                  crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                  children: [
                    _buildMessageBubble(msg, isUser, theme),
                    if (!isUser && msg["data"] != null) _buildActionButtons(msg["data"]),
                    const SizedBox(height: 16),
                  ],
                );
              },
            ),
          ),
          if (_isLoading) 
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8.0),
              child: SizedBox(
                height: 2,
                child: LinearProgressIndicator(
                  backgroundColor: Colors.transparent,
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF8B5CF6)),
                ),
              ),
            ),
          _buildInputArea(theme),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> msg, bool isUser, ThemeData theme) {
    return Container(
      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isUser ? const Color(0xFF8B5CF6) : Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(16),
          topRight: const Radius.circular(16),
          bottomLeft: Radius.circular(isUser ? 16 : 4),
          bottomRight: Radius.circular(isUser ? 4 : 16),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04), 
            blurRadius: 10, 
            offset: const Offset(0, 4)
          )
        ],
        border: !isUser ? Border.all(color: const Color(0xFFE5E7EB)) : null,
      ),
      child: Text(
        msg["content"]!,
        style: TextStyle(
          color: isUser ? Colors.white : const Color(0xFF374151),
          fontSize: 16,
          height: 1.4,
        ),
      ),
    );
  }

  Widget _buildActionButtons(Map<String, dynamic> data) {
    List<Widget> buttons = [];

    if (data['prerequisite_data'] != null) {
      final subjectName = data['subject'] ?? "Requested";
      buttons.add(_actionButton("View $subjectName Roadmap", Icons.map_outlined, const Color(0xFF8B5CF6), () {
         final roadmapData = SubjectData.fromJson(data['prerequisite_data']);
         Navigator.push(context, MaterialPageRoute(builder: (context) => SubjectDependencyGraph(
           subjectName: subjectName,
           initialData: roadmapData,
         )));
      }));
    }

    if (data['step'] == 'quiz' || data['intent'] == 'test') {
      final qSubject = data['subject'] ?? 'ds';
      buttons.add(_actionButton("Take $qSubject Quiz", Icons.quiz_outlined, const Color(0xFF10B981), () {
         Navigator.push(context, MaterialPageRoute(builder: (context) => SubjectQuiz(
           subjectId: qSubject, 
           subjectName: qSubject, 
           onComplete: () => _addSystemMessage("Great job completing the quiz! What's next?"),
         )));
      }));
    }

    if (buttons.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 12, left: 4),
      child: Wrap(spacing: 8, runSpacing: 8, children: buttons),
    );
  }

  Widget _actionButton(String label, IconData icon, Color color, VoidCallback onPressed) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: color,
        surfaceTintColor: Colors.white,
        elevation: 0,
        side: BorderSide(color: color.withOpacity(0.3)),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildInputArea(ThemeData theme) {
    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, 16, MediaQuery.of(context).padding.bottom + 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              style: const TextStyle(fontSize: 15),
              decoration: InputDecoration(
                hintText: "What do you want to learn today?",
                hintStyle: const TextStyle(color: Color(0xFF9CA3AF)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                filled: true,
                fillColor: const Color(0xFFF3F4F6),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: const BorderSide(color: Color(0xFF8B5CF6), width: 1),
                ),
              ),
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [Color(0xFF8B5CF6), Color(0xFF7C3AED)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: IconButton(
              onPressed: _sendMessage, 
              icon: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}
