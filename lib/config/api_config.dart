class ApiConfig {
  // Replace with your actual VPS URL
  static const String baseUrl = 'https://api.your-vps-domain.com';
  
  static const String uploadAudioEndpoint = '$baseUrl/upload/audio';
  static const String uploadImageEndpoint = '$baseUrl/upload/image';
  static const String uploadVideoEndpoint = '$baseUrl/upload/video';
}
