import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/analyze_response.dart';
import '../models/portfolio_response.dart';
import 'clover_api_service.dart';

class CloverHttpService implements CloverApiService {
  final String baseUrl;
  final http.Client _client;

  CloverHttpService({
    this.baseUrl = 'http://localhost:8000',
    http.Client? client,
  }) : _client = client ?? http.Client();

  @override
  List<String> getAvailableProfileIds() {
    // When live backend is wired up, can fetch from /api/profiles or keep known sample list
    return const [
      'lakshmi_vendor_001',
      'thin_file_002',
      'dormancy_gap_003',
      'ramesh_carpentry_004',
    ];
  }

  @override
  Future<AnalyzeResponse> analyzeProfile(String profileId) async {
    final uri = Uri.parse('$baseUrl/api/profiles/$profileId');
    final response = await _client.get(
      uri,
      headers: {'Accept': 'application/json'},
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return AnalyzeResponse.fromJson(data);
    } else {
      throw Exception(
        'Failed to analyze profile ($profileId): HTTP ${response.statusCode} - ${response.body}',
      );
    }
  }

  @override
  Future<PortfolioResponse> getPortfolio() async {
    final uri = Uri.parse('$baseUrl/api/portfolio');
    final response = await _client.get(uri);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return PortfolioResponse.fromJson(data);
    } else {
      throw Exception(
        'Failed to load portfolio metrics: HTTP ${response.statusCode} - ${response.body}',
      );
    }
  }
}
