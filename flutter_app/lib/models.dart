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
    return SubjectData(
      subjects: (json['subjects'] as List?)?.map((i) => Subject.fromJson(i)).toList() ?? [],
      dependencies: (json['dependencies'] as List?)?.map((i) => Dependency.fromJson(i)).toList() ?? [],
    );
  }
}

// Quiz Models
enum QuestionType { mcq, text }

class Question {
  final String id;
  final String? concept;
  final String? difficulty;
  final String questionText;
  final String? code;
  final String? language;
  final List<String> options;
  final int answerIndex;
  final String? correctAnswer; 
  final String? explanation;
  final QuestionType type;

  Question({
    required this.id,
    this.concept,
    this.difficulty,
    required this.questionText,
    this.code,
    this.language,
    required this.options,
    required this.answerIndex,
    this.correctAnswer,
    this.explanation,
    required this.type,
  });

  factory Question.fromJson(Map<String, dynamic> json) {
    final rawType = json['type']?.toString().toUpperCase() ?? 'MCQ';
    
    // Map API types to internal enum
    QuestionType type;
    if (rawType == 'MCQ' || rawType == 'TRUEFALSE') {
      type = QuestionType.mcq;
    } else {
      type = QuestionType.text;
    }

    final options = List<String>.from(json['options'] ?? []);
    final rawAnswer = json['answer']?.toString() ?? '';
    
    // Determine answer index if MCQ
    int index = -1;
    if (type == QuestionType.mcq) {
      if (rawType == 'TRUEFALSE') {
        index = (rawAnswer.toLowerCase() == 'true') ? 0 : 1;
      } else {
        index = options.indexOf(rawAnswer);
      }
    }

    return Question(
      id: json['id']?.toString() ?? '',
      concept: json['concept'],
      difficulty: json['difficulty'],
      questionText: json['question'] ?? 'No Question',
      code: json['code'],
      language: json['language'],
      options: rawType == 'TRUEFALSE' ? ['True', 'False'] : options,
      answerIndex: index,
      correctAnswer: rawAnswer,
      explanation: json['explanation'],
      type: type,
    );
  }
}

class QuizData {
  final String subject;
  final String topic;
  final List<Question> questions;

  QuizData({
    required this.subject,
    required this.topic,
    required this.questions,
  });

  factory QuizData.fromJson(Map<String, dynamic> json) {
    return QuizData(
      subject: json['subject'] ?? '',
      topic: json['topic'] ?? '',
      questions: (json['questions'] as List?)?.map((i) => Question.fromJson(i)).toList() ?? [],
    );
  }
}
