import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:quiz/core/api/api_config.dart';
import 'package:quiz/core/storage/secure_storage_service.dart';

class AuthVm extends ChangeNotifier {
  String? token;
  String? userName;
  bool? isLoggedIn;
  String? signUpError; // Add this to store signup error message

  AuthVm() {
    checkToken();
  }

  final SecureStorageService storage = SecureStorageService();

  Future<bool> login(String userName, String password) async {
    try {
      final result = await http.post(
        Uri.parse("${ApiConfig.httpBase}/sign_in"),
        headers: {
          "content-Type": "application/json",
        },
        body: jsonEncode({
          "userName": userName,
          "password": password,
        }),
      );

      if (result.statusCode == 200) {
        final data = jsonDecode(result.body);
        token = data["token"];
        isLoggedIn = true;
        userName = data["user"]["userName"];
        await storage.saveToken(token!);
        notifyListeners();
        return true;
      }
      
      if (result.statusCode == 401) {
        signUpError = "Incorrect password";
        notifyListeners();
        return false;
      }
      
      if (result.statusCode == 404) {
        signUpError = "User not found";
        notifyListeners();
        return false;
      }

      signUpError = "Login failed. Please try again.";
      notifyListeners();
      return false;
    } catch (e) {
      signUpError = "Network error: ${e.toString()}";
      notifyListeners();
      return false;
    }
  }

  Future<bool> signUp(String userName, String password) async {
    try {
      final result = await http.post(
        Uri.parse("${ApiConfig.httpBase}/sign_up"),
        headers: {"content-Type": "application/json"},
        body: jsonEncode({
          "userName": userName,
          "password": password,
        }),
      );

      // Handle different status codes
      if (result.statusCode == 201) {
        signUpError = null; // Clear any previous errors
        notifyListeners();
        return true;
      } else if (result.statusCode == 409) {
        // Conflict - username already exists
        final data = jsonDecode(result.body);
        signUpError = data["message"] ?? "Username already taken";
        notifyListeners();
        return false;
      } else {
        // Other errors (500, etc.)
        try {
          final data = jsonDecode(result.body);
          signUpError = data["message"] ?? "Sign up failed. Please try again.";
        } catch (e) {
          signUpError = "Server error. Please try again later.";
        }
        notifyListeners();
        return false;
      }
    } catch (e) {
      signUpError = "Network error: ${e.toString()}";
      notifyListeners();
      return false;
    }
  }

  // Method to clear signup error
  void clearSignUpError() {
    signUpError = null;
    notifyListeners();
  }

  Future<void> logOut() async {
    await storage.deleteToken();
    token = null;
    isLoggedIn = false;
    userName = null;
    signUpError = null;
    notifyListeners();
  }

  Future<void> checkToken() async {
    final storedToken = await storage.getToken();

    if (storedToken != null && JwtDecoder.isExpired(storedToken)) {
      await storage.deleteToken();
      token = null;
      isLoggedIn = false;
      userName = null;
      notifyListeners();
      return;
    }

    token = storedToken;
    isLoggedIn = storedToken != null;
    notifyListeners();
  }
}