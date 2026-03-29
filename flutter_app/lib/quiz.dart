import 'package:flutter/material.dart';
import 'package:flutter_highlight/flutter_highlight.dart';
import 'package:flutter_highlight/themes/shades-of-purple.dart';
import 'package:codecrafter/api_service.dart';
import 'package:codecrafter/models.dart';

enum QuizPhase { loading, difficulty, quiz, results, mapping }

class SubjectQuiz extends StatefulWidget {
  final String subjectId;
  final String subjectName;
  final VoidCallback onComplete;

  const SubjectQuiz({
    super.key,
    required this.subjectId,
    required this.subjectName,
    required this.onComplete,
  });

  @override
  State<SubjectQuiz> createState() => _SubjectQuizState();
}

class _SubjectQuizState extends State<SubjectQuiz> {
  final ApiService _apiService = ApiService();
  final TextEditingController _textController = TextEditingController();

  QuizData? _fullQuizData;
  List<Question> _filteredQuestions = [];
  QuizPhase _phase = QuizPhase.loading;
  String? _selectedDifficulty;

  // Mapping fallback
  List<Map<String, dynamic>> _availableSubjects = [];
  String? _actualSubjectId;

  int currentIndex = 0;
  int score = 0;
  bool isAnswered = false;
  int? selectedIndex;
  String? _textFeedback;
  
  List<Map<String, dynamic>> _userAnswersLog = [];

  @override
  void initState() {
    super.initState();
    _actualSubjectId = widget.subjectId;
    _loadServerData();
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _loadServerData() async {
    setState(() => _phase = QuizPhase.loading);
    try {
      final data = await _apiService.fetchQuizData(_actualSubjectId!);
      setState(() {
        _fullQuizData = data;
        _phase = QuizPhase.difficulty;
      });
    } catch (e) {
      if (e.toString().contains("404")) {
        await _handleMappingFallback();
      } else if (mounted) {
        setState(() => _phase = QuizPhase.results);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: Could not reach Node.js server")),
        );
      }
    }
  }

  Future<void> _handleMappingFallback() async {
    final subjects = await _apiService.fetchAllQuizSubjects();
    if (subjects.isEmpty) {
      if (mounted) setState(() => _phase = QuizPhase.results);
      return;
    }

    // Try fuzzy match
    String targetName = widget.subjectName.toLowerCase();
    Map<String, dynamic>? match;

    for (var s in subjects) {
      String name = (s['name'] ?? "").toString().toLowerCase();
      String shortName = (s['shortName'] ?? "").toString().toLowerCase();
      if (targetName.contains(name) || name.contains(targetName) || 
          targetName.contains(shortName) || shortName.contains(targetName)) {
        match = s;
        break;
      }
    }

    if (match != null) {
      _actualSubjectId = match['id'];
      await _loadServerData(); 
    } else {
      if (mounted) {
        setState(() {
          _availableSubjects = subjects;
          _phase = QuizPhase.mapping;
        });
      }
    }
  }

  void _startQuiz(String difficulty) {
    if (_fullQuizData == null) return;

    final allQuestions = _fullQuizData!.questions;
    if (allQuestions.isEmpty) {
       ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("No questions available for this subject yet.")),
       );
       return;
    }

    List<Question> filtered;
    if (difficulty == 'mixed') {
      filtered = List.from(allQuestions)..shuffle();
    } else {
      filtered = allQuestions.where((q) => q.difficulty?.toLowerCase() == difficulty).toList();
      if (filtered.length < 3) {
        filtered = List.from(allQuestions)..shuffle();
      }
    }

    if (filtered.length > 10) {
      filtered = filtered.take(10).toList();
    }

    setState(() {
      _selectedDifficulty = difficulty;
      _filteredQuestions = filtered;
      _phase = QuizPhase.quiz;
      currentIndex = 0;
      score = 0;
      _userAnswersLog = [];
    });
  }

  void _submitMCQAnswer(int index, Question question) {
    if (isAnswered) return;

    final isCorrect = index == question.answerIndex;
    final selectedOptionText = question.options[index];

    setState(() {
      selectedIndex = index;
      isAnswered = true;
      if (isCorrect) score++;
      
      _userAnswersLog.add({
        'questionId': question.id,
        'selectedAnswer': selectedOptionText,
        'isCorrect': isCorrect,
      });
    });
  }

  void _submitTextAnswer(Question question) {
    if (_textController.text.trim().isEmpty) return;

    final userAnswer = _textController.text.trim();
    final isCorrect = userAnswer.toLowerCase() == question.correctAnswer.toLowerCase();

    setState(() {
      isAnswered = true;
      if (isCorrect) {
        score++;
        _textFeedback = "Correct!";
      } else {
        _textFeedback = "Incorrect. Expected: ${question.correctAnswer}";
      }

      _userAnswersLog.add({
        'questionId': question.id,
        'selectedAnswer': userAnswer,
        'isCorrect': isCorrect,
      });
    });
  }

  void _nextQuestion() {
    if (currentIndex < _filteredQuestions.length - 1) {
      setState(() {
        currentIndex++;
        selectedIndex = null;
        isAnswered = false;
        _textController.clear();
        _textFeedback = null;
      });
    } else {
      _finishQuiz();
    }
  }

  Future<void> _finishQuiz() async {
    final userId = _apiService.userId;
    if (userId != null && _actualSubjectId != null) {
      await _apiService.saveQuizHistory(
        userId: userId,
        subjectId: _actualSubjectId!,
        score: score,
        totalQuestions: _filteredQuestions.length,
        answers: _userAnswersLog,
        difficulty: _selectedDifficulty,
      );
    }

    final threshold = (_filteredQuestions.length * 0.7).ceil();
    bool passed = score >= threshold;

    if (passed) {
      widget.onComplete();
    }

    _showResults(passed);
  }

  void _showResults(bool passed) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(passed ? "Quiz Passed! 🎉" : "Quiz Failed ❌"),
        content: Text("You scored $score out of ${_filteredQuestions.length}."),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child: const Text("Return to Roadmap"),
          ),
          if (!passed)
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                setState(() {
                  _phase = QuizPhase.difficulty;
                  selectedIndex = null;
                  isAnswered = false;
                  _textController.clear();
                });
              },
              child: const Text("Try Again"),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    switch (_phase) {
      case QuizPhase.loading:
        return Scaffold(
          appBar: AppBar(title: Text(widget.subjectName)),
          body: const Center(child: CircularProgressIndicator()),
        );
      case QuizPhase.mapping:
        return _buildMappingSelector();
      case QuizPhase.difficulty:
        return _buildDifficultySelection();
      case QuizPhase.quiz:
        return _buildQuizContent();
      case QuizPhase.results:
        return Scaffold(
          appBar: AppBar(title: Text(widget.subjectName)),
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text("Unable to load quiz data."),
                const SizedBox(height: 20),
                ElevatedButton(onPressed: _loadServerData, child: const Text("Retry")),
              ],
            ),
          ),
        );
    }
  }

  Widget _buildMappingSelector() {
    return Scaffold(
      appBar: AppBar(title: const Text("Select Subject")),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Text(
              "We couldn't find a direct quiz for '${widget.subjectName}'.\nPlease select the most relevant subject from our database:",
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: ListView.separated(
              itemCount: _availableSubjects.length,
              separatorBuilder: (context, index) => const Divider(),
              itemBuilder: (context, index) {
                final s = _availableSubjects[index];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.purple.shade50,
                    child: Text(s['icon'] ?? '📚', style: const TextStyle(fontSize: 20)),
                  ),
                  title: Text(s['name'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(s['shortName'] ?? ''),
                  onTap: () {
                    setState(() {
                      _actualSubjectId = s['id'];
                      _loadServerData();
                    });
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDifficultySelection() {
    return Scaffold(
      appBar: AppBar(title: Text("Difficulty - ${widget.subjectName}")),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _difficultyButton("Easy", "🟢", Colors.green, "easy"),
            const SizedBox(height: 16),
            _difficultyButton("Medium", "🟡", Colors.orange, "medium"),
            const SizedBox(height: 16),
            _difficultyButton("Hard", "🔴", Colors.red, "hard"),
            const SizedBox(height: 16),
            _difficultyButton("Mixed", "🎨", Colors.blue, "mixed"),
          ],
        ),
      ),
    );
  }

  Widget _difficultyButton(String label, String icon, Color color, String value) {
    return SizedBox(
      width: double.infinity,
      height: 70,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: color.withOpacity(0.1),
          foregroundColor: color,
          side: BorderSide(color: color.withOpacity(0.5), width: 2),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        onPressed: () => _startQuiz(value),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(icon, style: const TextStyle(fontSize: 24)),
            const SizedBox(width: 12),
            Text(label, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildQuizContent() {
    final theme = Theme.of(context);
    final currentQuestion = _filteredQuestions[currentIndex];

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.subjectName),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(6),
          child: LinearProgressIndicator(
            value: (currentIndex + 1) / _filteredQuestions.length,
            backgroundColor: Colors.grey.withOpacity(0.2),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (currentQuestion.concept != null) _conceptBadge(currentQuestion.concept!),
                const Spacer(),
                _difficultyBadge(currentQuestion.difficulty ?? "Medium"),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              currentQuestion.questionText,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            if (currentQuestion.code != null) _buildCodeView(currentQuestion.code!, currentQuestion.language),
            const SizedBox(height: 25),
            if (currentQuestion.type == QuestionType.text)
              _buildTextInputField(currentQuestion)
            else
              ...List.generate(
                currentQuestion.options.length,
                (index) => _buildOptionTile(index, currentQuestion),
              ),
            const SizedBox(height: 30),
            if (isAnswered) _buildExplanationAndNext(currentQuestion, theme),
          ],
        ),
      ),
    );
  }

  Widget _conceptBadge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: Colors.purple.shade50, borderRadius: BorderRadius.circular(20)),
      child: Text(text, style: TextStyle(color: Colors.purple.shade700, fontSize: 12, fontWeight: FontWeight.bold)),
    );
  }

  Widget _difficultyBadge(String diff) {
    Color c = Colors.orange;
    if (diff.toLowerCase() == 'easy') c = Colors.green;
    if (diff.toLowerCase() == 'hard') c = Colors.red;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: c.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
      child: Text(diff.toUpperCase(), style: TextStyle(color: c, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildCodeView(String code, String? language) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: HighlightView(
        code,
        language: language,
        theme: shadesOfPurpleTheme,
        padding: const EdgeInsets.all(16),
        textStyle: const TextStyle(fontFamily: 'monospace', fontSize: 14),
      ),
    );
  }

  Widget _buildOptionTile(int index, Question question) {
    bool isCorrect = index == question.answerIndex;
    bool isSelected = index == selectedIndex;
    final theme = Theme.of(context);

    Color borderColor = Colors.grey.shade300;
    Color bgColor = Colors.white;
    
    if (isAnswered) {
      if (isCorrect) {
        borderColor = Colors.green;
        bgColor = Colors.green.shade50;
      } else if (isSelected) {
        borderColor = Colors.red;
        bgColor = Colors.red.shade50;
      }
    } else if (isSelected) {
      borderColor = theme.colorScheme.primary;
      bgColor = theme.colorScheme.primary.withOpacity(0.05);
    }

    return GestureDetector(
      onTap: isAnswered ? null : () => _submitMCQAnswer(index, question),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: bgColor,
          border: Border.all(color: borderColor, width: 2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Text(String.fromCharCode(65 + index), style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(width: 12),
            Expanded(child: Text(question.options[index])),
            if (isAnswered && isCorrect) const Icon(Icons.check_circle, color: Colors.green),
            if (isAnswered && isSelected && !isCorrect) const Icon(Icons.cancel, color: Colors.red),
          ],
        ),
      ),
    );
  }

  Widget _buildTextInputField(Question question) {
    return Column(
      children: [
        TextField(
          controller: _textController,
          enabled: !isAnswered,
          decoration: const InputDecoration(border: OutlineInputBorder(), hintText: "Enter your answer"),
        ),
        if (!isAnswered) ...[
          const SizedBox(height: 12),
          ElevatedButton(onPressed: () => _submitTextAnswer(question), child: const Text("Submit")),
        ],
        if (isAnswered && _textFeedback != null) ...[
          const SizedBox(height: 12),
          Text(_textFeedback!, style: TextStyle(fontWeight: FontWeight.bold, color: _textFeedback!.startsWith("Correct") ? Colors.green : Colors.red)),
        ]
      ],
    );
  }

  Widget _buildExplanationAndNext(Question question, ThemeData theme) {
    return Column(
      children: [
        if (question.explanation != null)
          Container(
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(12)),
            child: Text("💡 Explanation: ${question.explanation}"),
          ),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(onPressed: _nextQuestion, child: const Text("Next Question")),
        ),
      ],
    );
  }
}
