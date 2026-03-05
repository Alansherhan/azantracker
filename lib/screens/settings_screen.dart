import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/prayer_time_provider.dart';

/// Dedicated screen for editing all prayer time settings:
/// global offset, per-prayer azan & iqama offsets, masjid name,
/// hijri adjustment, and alert toggles.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PrayerTimeProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      appBar: AppBar(
        title: const Text('Edit Prayer Times'),
        backgroundColor: const Color(0xFF1a1a2e),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 12),
        children: [
          // ---- General Settings ----
          _SectionHeader(title: 'General'),
          _SettingsTile(
            icon: Icons.mosque_rounded,
            title: 'Masjid Name',
            subtitle:
                provider.masjidName.isEmpty ? 'Not set' : provider.masjidName,
            onTap: () => _showMasjidDialog(context, provider),
          ),
          _SettingsTile(
            icon: Icons.calendar_month_rounded,
            title: 'Hijri Day Adjustment',
            subtitle:
                '${provider.hijriAdjustment >= 0 ? "+" : ""}${provider.hijriAdjustment} day(s)',
            onTap: () => _showHijriDialog(context, provider),
          ),
          _SettingsTile(
            icon: Icons.tune_rounded,
            title: 'Global Azan Offset',
            subtitle:
                '${provider.globalOffset >= 0 ? "+" : ""}${provider.globalOffset} min',
            onTap: () => _showGlobalOffsetDialog(context, provider),
          ),

          const SizedBox(height: 8),

          // ---- Per-prayer settings ----
          _SectionHeader(title: 'Prayer Time Adjustments'),
          ...provider.prayers.map((prayer) => _PrayerSettingsTile(
                prayer: prayer,
                provider: provider,
              )),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Masjid name dialog
  // ---------------------------------------------------------------------------

  void _showMasjidDialog(BuildContext context, PrayerTimeProvider provider) {
    final controller = TextEditingController(text: provider.masjidName);
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
              provider.updateMasjidName(controller.text.trim());
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Hijri adjustment dialog
  // ---------------------------------------------------------------------------

  void _showHijriDialog(BuildContext context, PrayerTimeProvider provider) {
    int tempAdj = provider.hijriAdjustment;
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
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
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
                child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                provider.updateHijriAdjustment(tempAdj);
                Navigator.pop(ctx);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Global offset dialog
  // ---------------------------------------------------------------------------

  void _showGlobalOffsetDialog(
      BuildContext context, PrayerTimeProvider provider) {
    int temp = provider.globalOffset;
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
                style:
                    const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
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
                provider.updateGlobalOffset(temp);
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
// Section Header
// =============================================================================

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Colors.grey.shade600,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

// =============================================================================
// Generic settings tile
// =============================================================================

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
      ),
      child: ListTile(
        leading: Icon(icon, color: const Color(0xFF1a1a2e)),
        title: Text(title,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
        subtitle: Text(subtitle,
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
        trailing:
            Icon(Icons.chevron_right, color: Colors.grey.shade400, size: 22),
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}

// =============================================================================
// Per-prayer settings tile (azan offset, iqama offset, alerts)
// =============================================================================

class _PrayerSettingsTile extends StatelessWidget {
  final PrayerEntry prayer;
  final PrayerTimeProvider provider;

  const _PrayerSettingsTile({
    required this.prayer,
    required this.provider,
  });

  /// Prayers whose azan time is derived from another prayer —
  /// they don't have an independent azan offset.
  static const _hiddenAzanPrayers = {
    'Jumua',
    'Taraveeh',
    'Tahajjud',
    'Imsak',
    'Eid',
  };

  @override
  Widget build(BuildContext context) {
    final hideAzan = _hiddenAzanPrayers.contains(prayer.name);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16),
        childrenPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        collapsedShape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        leading: Icon(
          Icons.access_time_rounded,
          color: const Color(0xFF1a1a2e).withValues(alpha: 0.7),
        ),
        title: Text(prayer.name,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
        subtitle: Text(
          hideAzan
              ? 'Iqama: ${prayer.formattedIqamaTime}'
              : 'Azan: ${prayer.formattedAzanTime}  •  Iqama: ${prayer.formattedIqamaTime}',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
        children: [
          // ---- Azan offset (only for core prayers + Sunrise) ----
          if (!hideAzan) ...[
            _OffsetRow(
              label: 'Azan Offset',
              value: prayer.azanOffsetMinutes,
              onChanged: (v) => provider.updateAzanOffset(prayer.name, v),
            ),
            const Divider(height: 1),
          ],

          // ---- Iqama offset / fixed time ----
          if (prayer.useFixedIqama)
            _FixedTimeRow(
              label: 'Iqama Time',
              hour: prayer.fixedIqamaHour,
              minute: prayer.fixedIqamaMinute,
              onTap: () => _pickFixedIqamaTime(context),
            )
          else
            _OffsetRow(
              label: 'Iqama Offset',
              value: prayer.iqamaOffsetMinutes,
              onChanged: (v) => provider.updateIqamaOffset(prayer.name, v),
            ),

          const Divider(height: 1),

          // ---- Alert toggles ----
          _ToggleRow(
            label: 'Azan Alert',
            value: prayer.azanAlert,
            onChanged: () => provider.toggleAzanAlert(prayer.name),
          ),
          _ToggleRow(
            label: 'Iqama Alert',
            value: prayer.iqamaAlert,
            onChanged: () => provider.toggleIqamaAlert(prayer.name),
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  void _pickFixedIqamaTime(BuildContext context) {
    showTimePicker(
      context: context,
      initialTime:
          TimeOfDay(hour: prayer.fixedIqamaHour, minute: prayer.fixedIqamaMinute),
    ).then((picked) {
      if (picked != null) {
        provider.updateFixedIqamaTime(
            prayer.name, picked.hour, picked.minute);
      }
    });
  }
}

// =============================================================================
// Offset stepper row (inline + / −)
// =============================================================================

class _OffsetRow extends StatelessWidget {
  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  const _OffsetRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(label,
                style: const TextStyle(fontSize: 14, color: Colors.black87)),
          ),
          IconButton(
            icon: const Icon(Icons.remove_circle_outline, size: 22),
            onPressed: () => onChanged(value - 1),
            visualDensity: VisualDensity.compact,
          ),
          SizedBox(
            width: 48,
            child: Text(
              '${value >= 0 ? "+" : ""}$value',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.add_circle_outline, size: 22),
            onPressed: () => onChanged(value + 1),
            visualDensity: VisualDensity.compact,
          ),
          const Text(' min',
              style: TextStyle(fontSize: 12, color: Colors.grey)),
        ],
      ),
    );
  }
}

// =============================================================================
// Fixed-time display row (tappable to open time picker)
// =============================================================================

class _FixedTimeRow extends StatelessWidget {
  final String label;
  final int hour;
  final int minute;
  final VoidCallback onTap;

  const _FixedTimeRow({
    required this.label,
    required this.hour,
    required this.minute,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final display = TimeOfDay(hour: hour, minute: minute).format(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: InkWell(
        onTap: onTap,
        child: Row(
          children: [
            Expanded(
              child: Text(label,
                  style:
                      const TextStyle(fontSize: 14, color: Colors.black87)),
            ),
            Text(display,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(width: 4),
            Icon(Icons.edit, size: 16, color: Colors.grey.shade500),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Toggle row (switch)
// =============================================================================

class _ToggleRow extends StatelessWidget {
  final String label;
  final bool value;
  final VoidCallback onChanged;

  const _ToggleRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(label,
                style: const TextStyle(fontSize: 14, color: Colors.black87)),
          ),
          Switch.adaptive(
            value: value,
            onChanged: (_) => onChanged(),
            activeTrackColor: const Color(0xFF28a745),
          ),
        ],
      ),
    );
  }
}
