// lib/api_service.dart
import 'package:dio/dio.dart';
import 'package:codecrafter/models.dart';
import 'package:flutter/foundation.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  final Dio _dio = Dio();
  String? _token;
  String? _userId;

  // Node.js Express API (Quiz & Auth)
  final String _expressBase = "http://10.0.2.2:5000/api";

  // Python FastAPI (Knowledge Graph & Chat)
  final String _fastApiBase = "http://10.0.2.2:8000";

  String? get userId => _userId;

  void setToken(String token, String? userId) {
    _token = token;
    _userId = userId;
    _dio.options.headers['x-auth-token'] = token;
  }

  /// AUTH: Login
  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      final response = await _dio.post('$_expressBase/auth/login', data: {
        'email': email,
        'password': password,
      });
      if (response.data['token'] != null) {
        setToken(response.data['token'], response.data['user']['id']);
      }
      return response.data;
    } catch (e) {
      debugPrint('Login error: $e');
      throw Exception('Login failed: $e');
    }
  }

  /// AUTH: Register
  Future<Map<String, dynamic>> register(String name, String email, String password) async {
    try {
      final response = await _dio.post('$_expressBase/auth/register', data: {
        'name': name,
        'email': email,
        'password': password,
      });
      if (response.data['token'] != null) {
        setToken(response.data['token'], response.data['user']['id']);
      }
      return response.data;
    } catch (e) {
      debugPrint('Registration error: $e');
      throw Exception('Registration failed: $e');
    }
  }

  /// NODE.JS: Fetches all available quiz subjects (for mapping)
  Future<List<Map<String, dynamic>>> fetchAllQuizSubjects() async {
    try {
      final response = await _dio.get('$_expressBase/quiz/subjects');
      if (response.statusCode == 200) {
        final List subjects = response.data['subjects'] ?? [];
        return subjects.map((s) => s as Map<String, dynamic>).toList();
      }
      return [];
    } catch (e) {
      debugPrint('Error fetching all subjects: $e');
      return [];
    }
  }

  /// NODE.JS: Fetches Quiz Data for a specific ID
  Future<QuizData> fetchQuizData(String subjectId) async {
    try {
      final response = await _dio.get('$_expressBase/quiz/subjects/$subjectId');
      if (response.statusCode == 200) {
        return QuizData.fromJson(response.data);
      } else {
        throw Exception('Failed to load quiz data');
      }
    } catch (e) {
      if (e is DioException && e.response?.statusCode == 404) {
        throw Exception('404'); // Special case for mapping fallback
      }
      debugPrint('Error (fetchQuizData): $e');
      throw Exception('Failed to connect to Node server: $e');
    }
  }

  /// NODE.JS: Save Quiz History
  Future<void> saveQuizHistory({
    required String userId,
    required String subjectId,
    required int score,
    required int totalQuestions,
    required List<Map<String, dynamic>> answers,
    String? difficulty,
  }) async {
    try {
      await _dio.post('$_expressBase/history', data: {
        'userId': userId,
        'subjectId': subjectId,
        'score': score,
        'totalQuestions': totalQuestions,
        'answers': answers,
        'difficulty': difficulty,
      });
    } catch (e) {
      debugPrint('Error saving history: $e');
    }
  }

  /// FASTAPI: Fetches Prerequisite Graph
  Future<SubjectData> fetchSubjectData(String subject) async {
    try {
      final response = await _dio.post(
        '$_fastApiBase/json',
        data: {'subject': subject},
      );
      if (response.statusCode == 200) {
        final graphData = response.data['prerequisite_data'];
        return SubjectData.fromJson(graphData ?? response.data);
      }
      throw Exception('Failed to load graph');
    } catch (e) {
      throw Exception('Failed to connect to FastAPI: $e');
    }
  }

  /// FASTAPI: Chat Agent
  Future<dynamic> chat(String? message, String? subject) async {
    try {
      final response = await _dio.post(
        '$_fastApiBase/chat',
        data: {'message': message, 'subject': subject},
      );
      return response.data;
    } catch (e) {
      throw Exception('Chat connection failed: $e');
    }
  }
}
