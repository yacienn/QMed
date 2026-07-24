import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:quiz/core/theme/app_theme.dart';
import 'package:quiz/feature/Host/view/host_page.dart';
import 'package:quiz/feature/auth/controller/auth_vm.dart';
import 'package:quiz/feature/home/controller/home_vm.dart';
import 'package:quiz/feature/home/controller/webSocket_vm.dart';
import 'package:quiz/feature/leaderboard/view/leaderboard_page.dart';
import 'package:quiz/feature/lobby/view/lobby_page.dart';
import 'package:quiz/widgets/text_field.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthVm>();
      final websocket = context.read<WebsocketVm>();

      if (auth.token != null) {
        websocket.connect(auth.token!);
      }
    });
  }

  @override
  void dispose() {
    // Clean up is handled by HomeVm
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthVm>();
    final websocket = context.watch<WebsocketVm>();
    final homeVm = context.watch<HomeVm>();

    return Scaffold(
      backgroundColor: AppTheme.paperBeige,
      appBar: AppBar(
        backgroundColor: AppTheme.paperBeige,
        elevation: 0,
        title: const Text(
          "QUIZ",
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            letterSpacing: 2,
            color: AppTheme.neoBlack,
          ),
        ),
        actions: [
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const LeaderboardPage()),
              );
            },
            icon: const Icon(
              Icons.leaderboard,
              color: AppTheme.neoBlack,
              size: 28,
            ),
            tooltip: 'Leaderboard',
          ),
          IconButton(
            onPressed: () {
              websocket.disconnectSocket();
              auth.logOut();
              Navigator.pushReplacementNamed(context, "/log_in");
            },
            icon: const Icon(
              Icons.logout,
              color: AppTheme.neoBlack,
              size: 28,
            ),
            tooltip: 'Logout',
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: SizedBox(
              width: 400,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Welcome Section
                  const Text(
                    "WELCOME",
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                      color: AppTheme.neoBlack,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Hello, ${'Player'}!",
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.neoBlack,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "Ready to challenge your friends?",
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.darkGrey,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 48),

                  // Error Message Display
                  if (homeVm.errorMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.red.shade300,
                          width: 2,
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.error_outline,
                            color: Colors.red,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              homeVm.errorMessage!,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.red,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          GestureDetector(
                            onTap: () => homeVm.clearError(),
                            child: const Icon(
                              Icons.close,
                              color: Colors.red,
                              size: 20,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Create Room Button
                  GestureDetector(
                    onTap: homeVm.isLoading
                        ? null
                        : () async {
                            final roomId = await homeVm.createRoom(websocket);
                            if (roomId != null && mounted) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => HostPage(roomId: roomId),
                                ),
                              );
                            }
                          },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      decoration: BoxDecoration(
                        color: homeVm.isLoading
                            ? AppTheme.mediumGrey
                            : AppTheme.accentTeal,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppTheme.neoBlack,
                          width: AppTheme.borderWidth,
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: AppTheme.neoBlack,
                            offset: Offset(4, 4),
                            blurRadius: 0,
                          ),
                        ],
                      ),
                      child: Center(
                        child: homeVm.isCreating
                            ? const SizedBox(
                                height: 24,
                                width: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 3,
                                  color: AppTheme.neoBlack,
                                ),
                              )
                            : const Text(
                                "CREATE ROOM",
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.2,
                                  color: AppTheme.neoBlack,
                                ),
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // OR Divider
                  const Row(
                    children: [
                      Expanded(
                        child: Divider(
                          color: AppTheme.neoBlack,
                          thickness: 2,
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          "OR",
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            color: AppTheme.darkGrey,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Divider(
                          color: AppTheme.neoBlack,
                          thickness: 2,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Join Room Field using NeoTextField
                  NeoTextField(
                    controller: homeVm.joinRoomController,
                    label: "ENTER ROOM ID",
                    prefixIcon: Icons.meeting_room_outlined,
                    onChanged: (_) => homeVm.clearError(),
                  ),
                  const SizedBox(height: 12),

                  // Join Room Button
                  GestureDetector(
                    onTap: homeVm.isLoading
                        ? null
                        : () async {
                            final roomId = await homeVm.joinRoom(websocket);
                            if (roomId != null && mounted) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => LobbyPage(roomId: roomId),
                                ),
                              );
                            }
                          },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        color: homeVm.isLoading
                            ? AppTheme.mediumGrey
                            : AppTheme.accentMagenta,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppTheme.neoBlack,
                          width: AppTheme.borderWidth,
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: AppTheme.neoBlack,
                            offset: Offset(4, 4),
                            blurRadius: 0,
                          ),
                        ],
                      ),
                      child: Center(
                        child: homeVm.isJoining
                            ? const SizedBox(
                                height: 24,
                                width: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 3,
                                  color: AppTheme.neoBlack,
                                ),
                              )
                            : const Text(
                                "JOIN ROOM",
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.2,
                                  color: AppTheme.neoBlack,
                                ),
                              ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Leaderboard Quick Link (stylized like signup page)
                  Center(
                    child: GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const LeaderboardPage(),
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppTheme.neoBlack,
                            width: 2.5,
                          ),
                          boxShadow: const [
                            BoxShadow(
                              color: AppTheme.neoBlack,
                              offset: Offset(3, 3),
                              blurRadius: 0,
                            ),
                          ],
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.leaderboard,
                              color: AppTheme.neoBlack,
                              size: 20,
                            ),
                            SizedBox(width: 8),
                            Text(
                              "VIEW LEADERBOARD",
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.neoBlack,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}