import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/prayer_time_provider.dart';

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

          // ---- Hijri date + day adjustment ----
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                provider.hijriDateString,
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => _showHijriDialog(context),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade700,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${provider.hijriAdjustment >= 0 ? "+" : ""}${provider.hijriAdjustment} Day',
                        style:
                            const TextStyle(color: Colors.white, fontSize: 12),
                      ),
                      const SizedBox(width: 3),
                      const Icon(Icons.edit, color: Colors.white, size: 11),
                    ],
                  ),
                ),
              ),
            ],
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

          // ---- City name + refresh ----
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                provider.cityName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => provider.refreshLocation(),
                child:
                    const Icon(Icons.sync, color: Colors.white70, size: 22),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---- Hijri adjustment dialog ----
  void _showHijriDialog(BuildContext context) {
    final prov = Provider.of<PrayerTimeProvider>(context, listen: false);
    int tempAdj = prov.hijriAdjustment;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Hijri Date Adjustment'),
          content: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.remove_circle_outline),
                onPressed: () => setState(() => tempAdj--),
              ),
              Text(
                '${tempAdj >= 0 ? "+" : ""}$tempAdj day(s)',
                style: const TextStyle(
                    fontSize: 20, fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: const Icon(Icons.add_circle_outline),
                onPressed: () => setState(() => tempAdj++),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                prov.updateHijriAdjustment(tempAdj);
                Navigator.pop(ctx);
              },
              child: const Text('Save'),
            ),
          ],
        ),
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
      child: Row(
        children: [
          // Left label
          const Expanded(
            flex: 4,
            child: Text(
              'Azan Time Charts',
              style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13),
            ),
          ),

          // Center: global offset button
          Expanded(
            flex: 3,
            child: GestureDetector(
              onTap: () => _showGlobalOffsetDialog(context),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF6c7a8a),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '+${provider.globalOffset} Minute',
                  textAlign: TextAlign.center,
                  style:
                      const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
            ),
          ),

          const SizedBox(width: 8),

          // Right: masjid name
          Expanded(
            flex: 4,
            child: GestureDetector(
              onTap: () => _showMasjidDialog(context),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  const Icon(Icons.edit, size: 14, color: Colors.white70),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      provider.masjidName.isEmpty
                          ? 'Edit Masjid Name'
                          : provider.masjidName,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: Colors.white, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showGlobalOffsetDialog(BuildContext context) {
    final prov = Provider.of<PrayerTimeProvider>(context, listen: false);
    int temp = prov.globalOffset;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Global Azan Offset'),
          content: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.remove_circle_outline),
                onPressed: () => setState(() => temp--),
              ),
              Text(
                '${temp >= 0 ? "+" : ""}$temp min',
                style: const TextStyle(
                    fontSize: 22, fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: const Icon(Icons.add_circle_outline),
                onPressed: () => setState(() => temp++),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                prov.updateGlobalOffset(temp);
                Navigator.pop(ctx);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _showMasjidDialog(BuildContext context) {
    final prov = Provider.of<PrayerTimeProvider>(context, listen: false);
    final controller = TextEditingController(text: prov.masjidName);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Masjid Name'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'Enter masjid name',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              prov.updateMasjidName(controller.text.trim());
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Individual Prayer Row
// =============================================================================

class _PrayerRow extends StatelessWidget {
  final PrayerEntry prayer;
  final bool isNext;
  final PrayerTimeProvider provider;

  const _PrayerRow({
    required this.prayer,
    required this.isNext,
    required this.provider,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final hasPassed = prayer.iqamaTime.isBefore(now);

    // These prayers only show the iqama (right) time, not the azan (left) time.
    const hiddenAzanPrayers = {'Jumua', 'Taraveeh', 'Tahajjud', 'Imsak', 'Eid'};
    final hideAzan = hiddenAzanPrayers.contains(prayer.name);

    // Simplified layout for secondary prayers — name left, adjust center, time right.
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
            // Adjust button (center)
            GestureDetector(
              onTap: () => _showAdjustDialog(context),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                decoration: BoxDecoration(
                  color: isNext
                      ? const Color(0xFF5cb85c)
                      : const Color(0xFF8e9aaf),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'Adjust Time',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 8,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            // Iqama time (right)
            Expanded(
              child: Text(
                prayer.formattedIqamaTime,
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: isNext
                      ? const Color(0xFF28a745)
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

          // 2. Azan time
          SizedBox(
            width: 52,
            child: Text(
              prayer.formattedAzanTime,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: hasPassed && !isNext ? Colors.grey : Colors.black87,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),

          // 3. Azan alert toggle
          GestureDetector(
            onTap: () => provider.toggleAzanAlert(prayer.name),
            child: Icon(
              prayer.azanAlert
                  ? Icons.volume_up_rounded
                  : Icons.volume_off_rounded,
              size: 20,
              color: prayer.azanAlert
                  ? Colors.grey.shade700
                  : Colors.grey.shade400,
            ),
          ),

          const SizedBox(width: 6),

          // 4. Offset box (tappable to adjust)
          Expanded(
            child: Center(
              child: GestureDetector(
                onTap: () => _showAdjustDialog(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isNext
                        ? const Color(0xFF5cb85c)
                        : const Color(0xFF8e9aaf),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    prayer.offsetDisplay,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(width: 6),

          // 5. Iqama time
          SizedBox(
            width: 52,
            child: Text(
              prayer.formattedIqamaTime,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: isNext
                    ? const Color(0xFF28a745)
                    : hasPassed
                        ? Colors.grey
                        : Colors.black87,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),

          const SizedBox(width: 6),

          // 6. Iqama alert toggle
          GestureDetector(
            onTap: () => provider.toggleIqamaAlert(prayer.name),
            child: Icon(
              prayer.iqamaAlert
                  ? Icons.notifications_active_rounded
                  : Icons.notifications_off_rounded,
              size: 20,
              color: prayer.iqamaAlert
                  ? const Color(0xFF28a745)
                  : Colors.grey.shade400,
            ),
          ),
        ],
      ),
    );
  }

  // ---- Adjustment dialog ----
  void _showAdjustDialog(BuildContext context) {
    if (prayer.useFixedIqama) {
      // Time picker for fixed-iqama prayers (Jumua, Taraveeh, Eid).
      showTimePicker(
        context: context,
        initialTime: TimeOfDay(
            hour: prayer.fixedIqamaHour, minute: prayer.fixedIqamaMinute),
      ).then((picked) {
        if (picked != null) {
          provider.updateFixedIqamaTime(
              prayer.name, picked.hour, picked.minute);
        }
      });
    } else {
      // Stepper dialog for minute-offset prayers.
      int temp = prayer.iqamaOffsetMinutes;
      showDialog(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setState) => AlertDialog(
            title: Text('${prayer.name} Iqama Offset'),
            content: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon:
                      const Icon(Icons.remove_circle_outline, size: 32),
                  onPressed: () => setState(() => temp--),
                ),
                const SizedBox(width: 8),
                Text(
                  '$temp',
                  style: const TextStyle(
                      fontSize: 28, fontWeight: FontWeight.bold),
                ),
                const Text(' min',
                    style: TextStyle(fontSize: 16, color: Colors.grey)),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline, size: 32),
                  onPressed: () => setState(() => temp++),
                ),
              ],
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel')),
              FilledButton(
                onPressed: () {
                  provider.updateIqamaOffset(prayer.name, temp);
                  Navigator.pop(ctx);
                },
                child: const Text('Save'),
              ),
            ],
          ),
        ),
      );
    }
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
