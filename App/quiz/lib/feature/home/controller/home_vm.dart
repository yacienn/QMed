import 'package:flutter/material.dart';
import 'package:quiz/feature/home/controller/webSocket_vm.dart';

class HomeVm extends ChangeNotifier {
  final TextEditingController joinRoomController = TextEditingController();

  bool _isCreating = false;
  bool _isJoining = false;
  String? errorMessage;

  bool get isCreating => _isCreating;
  bool get isJoining => _isJoining;
  bool get isLoading => _isCreating || _isJoining;

  void clearError() {
    errorMessage = null;
    notifyListeners();
  }

  Future<String?> createRoom(WebsocketVm websocket) async {
    _isCreating = true;
    errorMessage = null;
    notifyListeners();

    try {
      final roomId = await websocket.createRoom();
      return roomId;
    } catch (e) {
      errorMessage = 'Failed to create room. Please try again.';
      debugPrint('Failed to create room: $e');
      return null;
    } finally {
      _isCreating = false;
      notifyListeners();
    }
  }

  Future<String?> joinRoom(WebsocketVm websocket) async {
    final roomId = joinRoomController.text.trim().toUpperCase();
    if (roomId.isEmpty) {
      errorMessage = 'Please enter a room ID.';
      notifyListeners();
      return null;
    }

    _isJoining = true;
    errorMessage = null;
    notifyListeners();

    try {
      final joinedRoomId = await websocket.joinRoom(roomId);
      return joinedRoomId;
    } catch (e) {
      errorMessage = 'Failed to join room. Check the room ID and try again.';
      debugPrint('Failed to join room: $e');
      return null;
    } finally {
      _isJoining = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    joinRoomController.dispose();
    super.dispose();
  }
}
