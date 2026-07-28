import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';

class SosButton extends StatelessWidget {
  final bool isSending;
  final bool isAlarmActive;
  final VoidCallback? onLongPress;
  final VoidCallback? onTap;

  const SosButton({
    super.key,
    required this.isSending,
    required this.isAlarmActive,
    this.onLongPress,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: isSending ? null : onLongPress,
      onTap: isAlarmActive ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: 230,
        height: 230,
        decoration: BoxDecoration(
          color: isAlarmActive
              ? Colors.orange[700]
              : (isSending ? Colors.grey[800] : AppTheme.primaryRed),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: (isAlarmActive
                      ? Colors.orange
                      : (isSending ? Colors.grey : Colors.red))
                  .withValues(alpha: 0.5),
              blurRadius: isAlarmActive ? 50 : 30,
              spreadRadius: isAlarmActive ? 15 : 8,
            ),
          ],
          border: Border.all(color: Colors.white24, width: 4),
        ),
        child: Center(
          child: isSending
              ? const CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 4,
                )
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      isAlarmActive ? Icons.volume_off : Icons.touch_app_rounded,
                      color: Colors.white,
                      size: 55,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isAlarmActive ? "APAGAR" : "SOS",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 38,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2,
                      ),
                    ),
                    Text(
                      isAlarmActive ? "TOCA UNA VEZ" : "2 SEGUNDOS",
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}