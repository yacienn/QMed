import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:quiz/core/model/leaderboard_entry.dart';
import 'package:quiz/core/theme/app_theme.dart';
import 'package:quiz/feature/leaderboard/controller/leaderboard_vm.dart';

class LeaderboardPage extends StatelessWidget {
  const LeaderboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => LeaderboardVm()..load(),
      child: const _LeaderboardView(),
    );
  }
}

class _LeaderboardView extends StatelessWidget {
  const _LeaderboardView();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<LeaderboardVm>();

    return Scaffold(
      backgroundColor: AppTheme.paperBeige,
      appBar: AppBar(
        backgroundColor: AppTheme.paperBeige,
        elevation: 0,
        title: const Text(
          "LEADERBOARD",
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            letterSpacing: 2,
            color: AppTheme.neoBlack,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.refresh,
              color: AppTheme.neoBlack,
              size: 28,
            ),
            tooltip: 'Refresh',
            onPressed: vm.isLoading ? null : () => vm.load(),
          ),
        ],
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back,
            color: AppTheme.neoBlack,
            size: 28,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: vm.load,
        color: AppTheme.neoBlack,
        backgroundColor: AppTheme.paperBeige,
        child: _buildBody(context, vm),
      ),
    );
  }

  Widget _buildBody(BuildContext context, LeaderboardVm vm) {
    if (vm.isLoading && vm.entries.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(
          strokeWidth: 3,
          color: AppTheme.neoBlack,
        ),
      );
    }

    if (vm.errorMessage != null && vm.entries.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: AppTheme.errorRed.withOpacity(0.6),
              ),
              const SizedBox(height: 16),
              Text(
                vm.errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.neoBlack,
                ),
              ),
              const SizedBox(height: 24),
              GestureDetector(
                onTap: () => vm.load(),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.accentTeal,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppTheme.neoBlack,
                      width: AppTheme.borderWidth,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: AppTheme.neoBlack,
                        offset: Offset(3, 3),
                        blurRadius: 0,
                      ),
                    ],
                  ),
                  child: const Text(
                    "RETRY",
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                      color: AppTheme.neoBlack,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (vm.entries.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.emoji_events_outlined,
              size: 64,
              color: AppTheme.mediumGrey,
            ),
            const SizedBox(height: 16),
            const Text(
              "NO GAMES PLAYED YET",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
                color: AppTheme.neoBlack,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              "Be the first to claim the top spot!",
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppTheme.darkGrey,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: vm.entries.length,
      separatorBuilder: (_, __) => const Divider(
        color: AppTheme.lightGrey,
        thickness: 1.5,
        height: 1,
      ),
      itemBuilder: (context, index) {
        final entry = vm.entries[index];
        return _LeaderboardTile(rank: index + 1, entry: entry);
      },
    );
  }
}

class _LeaderboardTile extends StatelessWidget {
  final int rank;
  final LeaderboardEntry entry;

  const _LeaderboardTile({required this.rank, required this.entry});

  Color? _medalColor() {
    switch (rank) {
      case 1:
        return const Color(0xFFFFD700); // Gold
      case 2:
        return const Color(0xFFC0C0C0); // Silver
      case 3:
        return const Color(0xFFCD7F32); // Bronze
      default:
        return null;
    }
  }

  Color? _medalBackgroundColor() {
    switch (rank) {
      case 1:
        return Colors.amber.shade100;
      case 2:
        return Colors.grey.shade200;
      case 3:
        return Colors.brown.shade100;
      default:
        return AppTheme.lightGrey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final medalColor = _medalColor();
    final isTopThree = rank <= 3;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: isTopThree ? _medalBackgroundColor()?.withOpacity(0.3) : null,
      ),
      child: Row(
        children: [
          // Rank / Medal
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: medalColor ?? AppTheme.lightGrey,
              border: Border.all(
                color: AppTheme.neoBlack,
                width: isTopThree ? 2.5 : 1.5,
              ),
              boxShadow: isTopThree
                  ? [
                      BoxShadow(
                        color: AppTheme.neoBlack.withOpacity(0.2),
                        offset: const Offset(2, 2),
                        blurRadius: 0,
                      ),
                    ]
                  : null,
            ),
            child: Center(
              child: isTopThree
                  ? Icon(
                      rank == 1
                          ? Icons.emoji_events
                          : rank == 2
                              ? Icons.emoji_events
                              : Icons.emoji_events,
                      color: rank == 1
                          ? Colors.amber.shade700
                          : rank == 2
                              ? Colors.grey.shade600
                              : Colors.brown.shade600,
                      size: 24,
                    )
                  : Text(
                      '$rank',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                        color: AppTheme.neoBlack,
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 16),

          // Username and games played
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.userName,
                  style: TextStyle(
                    fontWeight: isTopThree ? FontWeight.w900 : FontWeight.w600,
                    fontSize: 16,
                    color: AppTheme.neoBlack,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${entry.gamesPlayed} game${entry.gamesPlayed == 1 ? '' : 's'} played',
                  style: TextStyle(
                    color: AppTheme.darkGrey,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          // Score
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${entry.totalScore}',
                style: TextStyle(
                  fontWeight: isTopThree ? FontWeight.w900 : FontWeight.bold,
                  fontSize: isTopThree ? 20 : 18,
                  color: AppTheme.neoBlack,
                ),
              ),
              Text(
                'pts',
                style: TextStyle(
                  color: AppTheme.darkGrey,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (entry.bestScore > 0) ...[
                const SizedBox(height: 2),
                Text(
                  'best: ${entry.bestScore}',
                  style: TextStyle(
                    color: AppTheme.accentTeal,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}