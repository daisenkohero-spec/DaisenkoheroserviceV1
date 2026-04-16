import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiClient {
  static const String baseUrl = "http://your-backend-url.com/api";

  String? _token;

  // -------------------
  // SET TOKEN
  // -------------------
  void setToken(String token) {
    _token = token;
  }

  // -------------------
  // GET
  // -------------------
  Future<dynamic> get(String endpoint) async {
    final response = await http.get(
      Uri.parse("$baseUrl/$endpoint"),
      headers: _headers(),
    );

    return _handleResponse(response);
  }

  // -------------------
  // POST
  // -------------------
  Future<dynamic> post(
    String endpoint,
    Map<String, dynamic> body,
  ) async {
    final response = await http.post(
      Uri.parse("$baseUrl/$endpoint"),
      headers: _headers(),
      body: jsonEncode(body),
    );

    return _handleResponse(response);
  }

  // -------------------
  // HEADERS
  // -------------------
  Map<String, String> _headers() {
    return {
      "Content-Type": "application/json",
      if (_token != null) "Authorization": "Bearer $_token",
    };
  }

  // -------------------
  // RESPONSE HANDLER
  // -------------------
  dynamic _handleResponse(http.Response response) {
    if (response.statusCode >= 200 &&
        response.statusCode < 300) {
      return jsonDecode(response.body);
    } else if (response.statusCode == 401) {
      throw Exception("Unauthorized");
    } else {
      throw Exception(
          "API Error: ${response.statusCode}");
    }
  }
}