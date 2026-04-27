import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/services/trial_service.dart';
import '../../core/services/license_service.dart';
import '../../theme/app_theme.dart';

class TrialCountdown extends StatefulWidget {
  const TrialCountdown({super.key});

  @override
  State<TrialCountdown> createState() => _TrialCountdownState();
}

class _TrialCountdownState extends State<TrialCountdown> {
  Duration? _remaining;
  Timer? _timer;
  bool _isVisible = false;
  bool _hasRealLicense = false;

  @override
  void initState() {
    super.initState();
    _checkStatus();
    // Refresh every 1 minute
    _timer = Timer.periodic(const Duration(minutes: 1), (_) => _checkStatus());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _checkStatus() async {
    final licenseService = LicenseService();
    final hasRealLicense = await licenseService.checkLicenseLocally();

    if (mounted) {
      setState(() {
        _hasRealLicense = hasRealLicense;
      });
    }

    if (hasRealLicense) {
      if (mounted) setState(() => _isVisible = false);
      return;
    }

    final remaining = await TrialService.getRemainingTime();

    if (mounted) {
      setState(() {
        _remaining = remaining;
        _isVisible = remaining != null && remaining > Duration.zero;
      });
    }
  }

  // Alias pour éviter les crashs lors du hot-reload si l'ancien timer tourne encore
  Future<void> _updateRemaining() => _checkStatus();

  String _formatDuration(Duration duration) {
    if (duration.inDays > 0) {
      return '${duration.inDays}j ${duration.inHours.remainder(24)}h';
    } else if (duration.inHours > 0) {
      return '${duration.inHours}h ${duration.inMinutes.remainder(60)}m';
    } else {
      return '${duration.inMinutes}m';
    }
  }

  @override
  Widget build(BuildContext context) {
    // On cache s'il y a une vraie licence
    if (_hasRealLicense) return const SizedBox.shrink();

    final remaining = _remaining;
    final isTrialActive =
        _isVisible && remaining != null && remaining > Duration.zero;

    // Si l'essai n'est pas encore démarré ou n'existe pas, on cache tout
    if (!isTrialActive) return const SizedBox.shrink();

    final displayTime = _formatDuration(remaining);
    final isCritical = remaining.inDays < 1;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isCritical
            ? AppTheme.errorColor.withValues(alpha: 0.1)
            : Colors.orange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isCritical
              ? AppTheme.errorColor.withValues(alpha: 0.3)
              : Colors.orange.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.timer_outlined,
            size: 14,
            color: isCritical ? AppTheme.errorColor : Colors.orange,
          ),
          const SizedBox(width: 6),
          Text(
            isTrialActive ? "Essai : $displayTime" : displayTime,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: isCritical ? AppTheme.errorColor : Colors.orange,
            ),
          ),
        ],
      ),
    );
  }
}
