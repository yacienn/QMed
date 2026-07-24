import 'package:flutter/material.dart';
import 'package:jwt_decoder/jwt_decoder.dart';

class HostVm extends ChangeNotifier {
  String? _myUserName;

  String? get myUserName => _myUserName;

  void initUserName(String? token) {
    if (token == null) return;
    try {
      final decoded = JwtDecoder.decode(token);
      _myUserName = decoded['userName'] as String?;
      notifyListeners();
    } catch (_) {}
  }
}
