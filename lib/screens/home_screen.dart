import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/prayer_time_provider.dart';
import 'settings_screen.dart';

/// Main screen — live clock header + prayer time chart matching the reference UI.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PrayerTimeProvider>();

    // Show loading / error states.
    if (provider.locationStatus != LocationStatus.fetched) {
      return Scaffold(
        backgroundColor: const Color(0xFF1a1a2e),
        body: SafeArea(child: _buildStateView(provider)),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFe8e8e8),
      body: SafeArea(
        child: Column(
          children: [
            _ClockHeader(provider: provider),
            _TableHeader(provider: provider),
            Expanded(
              child: ListView.builder(
                padding: EdgeInsets.zero,
                itemCount: provider.prayers.length,
                itemBuilder: (ctx, i) {
                  final prayer = provider.prayers[i];
                  final isNext =
                      provider.nextIqamaPrayer?.name == prayer.name;
                  return _PrayerRow(
                    prayer: prayer,
                    isNext: isNext,
                    provider: provider,
                  );
                },
              ),
            ),
            const _CopyrightFooter(),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Loading / Error / Permission views
  // ---------------------------------------------------------------------------

  Widget _buildStateView(PrayerTimeProvider provider) {
    switch (provider.locationStatus) {
      case LocationStatus.loading:
        return const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: Colors.tealAccent),
              SizedBox(height: 16),
              Text(
                'Fetching your location…',
                style: TextStyle(color: Colors.white70, fontSize: 16),
              ),
            ],
          ),
        );

      case LocationStatus.permissionDenied:
      case LocationStatus.serviceDisabled:
      case LocationStatus.error:
        return Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.location_off_rounded,
                    color: Colors.redAccent, size: 64),
                const SizedBox(height: 20),
                Text(
                  provider.errorMessage,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: Colors.white70, fontSize: 16, height: 1.5),
                ),
                const SizedBox(height: 28),
                ElevatedButton.icon(
                  onPressed: () => provider.retry(),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.tealAccent.shade700,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 28, vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          ),
        );

      default:
        return const SizedBox.shrink();
    }
  }
}

// =============================================================================
// Clock Header (dark top section)
// =============================================================================

class _ClockHeader extends StatelessWidget {
  final PrayerTimeProvider provider;
  const _ClockHeader({required this.provider});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1a1a2e), Color(0xFF2d3a4a)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Column(
        children: [
          // ---- Large clock ----
          Text(
            provider.formattedClock,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 44,
              fontWeight: FontWeight.bold,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),

          const SizedBox(height: 2),
          Text(provider.masjidName.isEmpty ? 'Your Masjid Name' : provider.masjidName,
              style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                  fontStyle: FontStyle.italic)),

          // ---- Hijri date ----
          Text(
            provider.hijriDateString,
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),

          const SizedBox(height: 4),

          // ---- Next iqama message ----
          if (provider.nextIqamaMessage.isNotEmpty)
            Text(
              provider.nextIqamaMessage,
              style: TextStyle(
                color: Colors.greenAccent.shade400,
                fontSize: 14,
                fontStyle: FontStyle.italic,
              ),
            ),

          const SizedBox(height: 8),

          // ---- City name + refresh + settings ----
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: () => provider.refreshLocation(),
                child:
                    const Icon(Icons.sync, color: Colors.white70, size: 22),
              ),
              const SizedBox(width: 10),
              Text(
                provider.cityName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const SettingsScreen()),
                ),
                child: const Icon(Icons.settings,
                    color: Colors.white70, size: 22),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Table Header Bar
// =============================================================================

class _TableHeader extends StatelessWidget {
  final PrayerTimeProvider provider;
  const _TableHeader({required this.provider});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      color: const Color(0xFF8e9aaf),
      child: const Row(
        children: [
          // Left label
          Expanded(
            child: Text(
              'Azan Time Charts',
              style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Individual Prayer Row
// =============================================================================

class _PrayerRow extends StatefulWidget {
  final PrayerEntry prayer;
  final bool isNext;
  final PrayerTimeProvider provider;

  const _PrayerRow({
    required this.prayer,
    required this.isNext,
    required this.provider,
  });

  @override
  State<_PrayerRow> createState() => _PrayerRowState();
}

class _PrayerRowState extends State<_PrayerRow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _blinkController;
  late final Animation<double> _blinkAnimation;

  @override
  void initState() {
    super.initState();
    _blinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _blinkAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _blinkController, curve: Curves.easeInOut),
    );
    if (widget.isNext) {
      _blinkController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(_PrayerRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isNext && !_blinkController.isAnimating) {
      _blinkController.repeat(reverse: true);
    } else if (!widget.isNext && _blinkController.isAnimating) {
      _blinkController.stop();
      _blinkController.value = 1.0;
    }
  }

  @override
  void dispose() {
    _blinkController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final prayer = widget.prayer;
    final isNext = widget.isNext;

    final now = DateTime.now();
    final hasPassed = prayer.iqamaTime.isBefore(now);
    final azanPassed = prayer.azanTime.isBefore(now);

    // Before azan → blink azan time. After azan (before iqama) → blink iqama time.
    final blinkAzan = isNext && !azanPassed;
    final blinkIqama = isNext && azanPassed;

    // These prayers only show the iqama (right) time, not the azan (left) time.
    const hiddenAzanPrayers = {'Jumua', 'Taraveeh', 'Tahajjud', 'Imsak', 'Eid'};
    final hideAzan = hiddenAzanPrayers.contains(prayer.name);

    // Simplified layout for secondary prayers — name left, time right.
    if (hideAzan) {
      return Container(
        decoration: BoxDecoration(
          color: isNext ? const Color(0xFFd4edda) : Colors.white,
          border: Border(
            bottom: BorderSide(color: Colors.grey.shade300, width: 0.5),
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        child: Row(
          children: [
            // Prayer name (left)
            Expanded(
              child: Text(
                prayer.name,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: hasPassed && !isNext ? Colors.grey : Colors.black87,
                ),
              ),
            ),
            // Iqama time (right)
            AnimatedBuilder(
              animation: _blinkAnimation,
              builder: (_, _) => Text(
                prayer.formattedIqamaTime,
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: isNext
                      ? Color.lerp(const Color(0xFF28a745), Colors.white,
                          _blinkAnimation.value)
                      : hasPassed
                          ? Colors.grey
                          : Colors.black87,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: isNext ? const Color(0xFFd4edda) : Colors.white,
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade300, width: 0.5),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      child: Row(
        children: [
          // 1. Prayer name
          SizedBox(
            width: 82,
            child: Text(
              prayer.name,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: hasPassed && !isNext ? Colors.grey : Colors.black87,
              ),
            ),
          ),

          // 2. Azan time — blinks before azan (centered)
          Expanded(
            child: AnimatedBuilder(
              animation: _blinkAnimation,
              builder: (_, _) => Text(
                prayer.formattedAzanTime,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: blinkAzan
                      ? Color.lerp(Colors.deepOrange, Colors.black87,
                          _blinkAnimation.value)
                      : hasPassed && !isNext
                          ? Colors.grey
                          : Colors.black87,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ),

          // 5. Iqama time — blinks after azan
          SizedBox(
            width: 52,
            child: AnimatedBuilder(
              animation: _blinkAnimation,
              builder: (_, _) => Text(
                prayer.formattedIqamaTime,
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: blinkIqama
                      ? Color.lerp(const Color(0xFF28a745), Colors.white,
                          _blinkAnimation.value)
                      : isNext
                          ? const Color(0xFF28a745)
                          : hasPassed
                              ? Colors.grey
                              : Colors.black87,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Copyright Footer
// =============================================================================

class _CopyrightFooter extends StatelessWidget {
  const _CopyrightFooter();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1a1a2e), Color(0xFF2d3a4a)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Developed by Alan Sherhan K P',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
          ),
          SizedBox(height: 2),
          Text(
            'alansherhan10@gmail.com',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.tealAccent,
              fontSize: 11,
              letterSpacing: 0.2,
            ),
          ),
          SizedBox(height: 4),
          Text(
            '© 2026 AzanTracker. All rights reserved.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white38,
              fontSize: 10,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}
