import 'package:flutter/material.dart';
import 'package:quiz/core/model/player.dart';
import 'package:quiz/core/theme/app_theme.dart';

class PlayerTile extends StatelessWidget {
  final PlayerModel player;
  final bool isMe;
  final VoidCallback? onKick;

  const PlayerTile({
    super.key,
    required this.player,
    required this.isMe,
    this.onKick,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: isMe ? AppTheme.accentTeal.withOpacity(0.08) : null,
      ),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isMe ? AppTheme.accentTeal : AppTheme.lightGrey,
              border: Border.all(
                color: AppTheme.neoBlack,
                width: isMe ? 3 : 2,
              ),
              boxShadow: const [
                BoxShadow(
                  color: AppTheme.neoBlack,
                  offset: Offset(2, 2),
                  blurRadius: 0,
                ),
              ],
            ),
            child: Center(
              child: Text(
                (player.userName?.isNotEmpty ?? false)
                    ? player.userName![0].toUpperCase()
                    : "?",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: isMe ? AppTheme.neoBlack : AppTheme.darkGrey,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Username and badges
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(
                      player.userName ?? "Unknown",
                      style: TextStyle(
                        fontWeight: isMe ? FontWeight.w900 : FontWeight.w600,
                        fontSize: 15,
                        color: AppTheme.neoBlack,
                      ),
                    ),
                    if (isMe) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.accentTeal.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: AppTheme.accentTeal,
                            width: 1.5,
                          ),
                        ),
                        child: const Text(
                          'YOU',
                          style: TextStyle(
                            fontSize: 8,
                            fontWeight: FontWeight.w900,
                            color: AppTheme.neoBlack,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                    if (player.isHost) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.amber.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: Colors.amber,
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.star,
                              color: Colors.amber.shade700,
                              size: 10,
                            ),
                            const SizedBox(width: 2),
                            const Text(
                              'HOST',
                              style: TextStyle(
                                fontSize: 8,
                                fontWeight: FontWeight.w900,
                                color: AppTheme.neoBlack,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: player.isReady
                            ? AppTheme.successGreen
                            : AppTheme.mediumGrey,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      player.isReady ? 'Ready' : 'Not ready',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: player.isReady
                            ? AppTheme.successGreen
                            : AppTheme.mediumGrey,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Action buttons
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (onKick != null) ...[
                GestureDetector(
                  onTap: () => _confirmKick(context),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.red,
                        width: 2,
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: AppTheme.neoBlack,
                          offset: Offset(2, 2),
                          blurRadius: 0,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.person_remove,
                      color: Colors.red,
                      size: 18,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  void _confirmKick(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppTheme.paperBeige,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: AppTheme.neoBlack,
            width: AppTheme.borderWidth,
          ),
        ),
        title: Row(
          children: [
            Icon(
              Icons.warning_amber_rounded,
              color: Colors.red,
              size: 28,
            ),
            const SizedBox(width: 12),
            const Text(
              'Remove Player?',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                color: AppTheme.neoBlack,
              ),
            ),
          ],
        ),
        content: Text(
          'Remove ${player.userName ?? "this player"} from the room?\n\nThis action cannot be undone.',
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: AppTheme.neoBlack,
          ),
        ),
        actions: [
          // Cancel Button
          GestureDetector(
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 10,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppTheme.neoBlack,
                  width: 2,
                ),
                boxShadow: const [
                  BoxShadow(
                    color: AppTheme.neoBlack,
                    offset: Offset(2, 2),
                    blurRadius: 0,
                  ),
                ],
              ),
              child: const Text(
                'CANCEL',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                  color: AppTheme.neoBlack,
                  letterSpacing: 0.8,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Remove Button
          GestureDetector(
           
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 10,
              ),
              decoration: BoxDecoration(
                color: AppTheme.errorRed,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppTheme.neoBlack,
                  width: 2,
                ),
                boxShadow: const [
                  BoxShadow(
                    color: AppTheme.neoBlack,
                    offset: Offset(2, 2),
                    blurRadius: 0,
                  ),
                ],
              ),
              child: const Text(
                'REMOVE',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                  color: Colors.white,
                  letterSpacing: 0.8,
                ),
              ),
            ),
          ),
        ],
        actionsPadding: const EdgeInsets.all(16),
      ),
    );
  }
}