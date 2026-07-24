
class ApiConfig {
  ApiConfig._();

  static const String host = "192.168.100.30"; 
  static const int port = 3000;

  static String get httpBase => "http://$host:$port";
  static String get wsBase => "ws://$host:$port";
}