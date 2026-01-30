class ApiConfig {
  // Change this to your backend URL
  static const String baseUrl = 'http://localhost:3000';
  
  // API endpoints
  static const String apiVersion = '/api/v1';
  
  // Full API URL
  static String get apiUrl => baseUrl + apiVersion;
}
