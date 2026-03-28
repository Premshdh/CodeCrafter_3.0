import 'package:flutter/material.dart';

// Roadmap / Graph Models
class Subject {
  final String id;
  final String name;
  final String type;
  final String desc;

  Subject({
    required this.id,
    required this.name,
    required this.type,
    required this.desc,
  });

  factory Subject.fromJson(Map<String, dynamic> json) {
    return Subject(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? 'Unknown',
      type: json['type'] ?? 'core',
      desc: json['desc'] ?? '',
    );
  }
}

class Dependency {
  final String from;
  final String to;

  Dependency({
    required this.from,
    required this.to,
  });

  factory Dependency.fromJson(Map<String, dynamic> json) {
    return Dependency(
      from: json['from']?.toString() ?? '',
      to: json['to']?.toString() ?? '',
    );
  }
}

class SubjectData {
  final List<Subject> subjects;
  final List<Dependency> dependencies;

  SubjectData({
    required this.subjects,
    required this.dependencies,
  });

  factory SubjectData.fromJson(Map<String, dynamic> json) {
    // debugPrint('JSON Received in SubjectData: $json');
    return SubjectData(
      subjects: (json['subjects'] as List?)?.map((i) => Subject.fromJson(i)).toList() ?? [],
      dependencies: (json['dependencies'] as List?)?.map((i) => Dependency.fromJson(i)).toList() ?? [],
    );
  }
}

// Quiz Models (aligned with web API: /api/quiz/subjects/:id)
class Question {
  final String questionText;
  final String? code;
  final String? language;
  final List<String> options;
  final int answerIndex;
  /// When false, the app shows a single continue control (short-answer style on web).
  final bool isMultipleChoice;

  Question({
    required this.questionText,
    this.code,
    this.language,
    required this.options,
    required this.answerIndex,
    this.isMultipleChoice = true,
  });

  factory Question.fromJson(Map<String, dynamic> json) {
    final rawOptions = json['options'];
    final options = rawOptions is List
        ? rawOptions.map((e) => e.toString()).toList()
        : <String>[];

    final ans = json['answer'];
    int answerIndex = 0;
    if (ans is int) {
      answerIndex = ans;
    } else if (ans is String && options.isNotEmpty) {
      final a = ans.toLowerCase().trim();
      final idx = options.indexWhere((o) => o.toLowerCase().trim() == a);
      answerIndex = idx >= 0 ? idx : 0;
    }

    final isMcq = options.isNotEmpty;

    return Question(
      questionText: json['question']?.toString() ?? 'No Question',
      code: json['code']?.toString(),
      language: json['language']?.toString(),
      options: isMcq
          ? options
          : ['Continue'],
      answerIndex: isMcq ? answerIndex : 0,
      isMultipleChoice: isMcq,
    );
  }
}

class QuizData {
  final String section;
  final List<Question> questions;

  QuizData({
    required this.section,
    required this.questions,
  });

  factory QuizData.fromJson(Map<String, dynamic> json) {
    return QuizData(
      section: json['section'] ?? '',
      questions: (json['questions'] as List?)?.map((i) => Question.fromJson(i)).toList() ?? [],
    );
  }
}
