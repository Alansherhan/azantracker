import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:adhan/adhan.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart' as geo;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/hijri_date.dart';

// =============================================================================
// Enums & Models
// =============================================================================

/// Current state of location fetching.
enum LocationStatus {
  loading,
  fetched,
  error,
  permissionDenied,
  serviceDisabled,
}

/// A single prayer with computed azan time and configurable iqama time.
class PrayerEntry {
  final String name;
  final DateTime azanTime;

  /// Minutes added (or subtracted if negative) to azan time for iqama.
  int iqamaOffsetMinutes;

  /// If true, [fixedIqamaHour]/[fixedIqamaMinute] are used instead of offset.
  bool useFixedIqama;
  int fixedIqamaHour;
  int fixedIqamaMinute;

  /// Notification toggles (visual only for this MVP).
  bool azanAlert;
  bool iqamaAlert;

  PrayerEntry({
    required this.name,
    required this.azanTime,
    this.iqamaOffsetMinutes = 0,
    this.useFixedIqama = false,
    this.fixedIqamaHour = 0,
    this.fixedIqamaMinute = 0,
    this.azanAlert = true,
    this.iqamaAlert = true,
  });

  /// Computed iqama time.
  DateTime get iqamaTime {
    if (useFixedIqama) {
      return DateTime(
        azanTime.year,
        azanTime.month,
        azanTime.day,
        fixedIqamaHour,
        fixedIqamaMinute,
      );
    }
    return azanTime.add(Duration(minutes: iqamaOffsetMinutes));
  }

  /// 12-hour time without AM/PM (compact table style: "05:30").
  String get formattedAzanTime => DateFormat('hh:mm').format(azanTime);

  /// 12-hour iqama time without AM/PM.
  String get formattedIqamaTime => DateFormat('hh:mm').format(iqamaTime);

  /// Display string for the offset column.
  String get offsetDisplay {
    if (useFixedIqama) {
      return DateFormat('hh:mm a').format(iqamaTime);
    }
    return iqamaOffsetMinutes.toString();
  }
}

// =============================================================================
// Provider
// =============================================================================

class PrayerTimeProvider extends ChangeNotifier {
  // ---------------------------------------------------------------------------
  // State
  // ---------------------------------------------------------------------------

  LocationStatus _locationStatus = LocationStatus.loading;
  LocationStatus get locationStatus => _locationStatus;

  String _errorMessage = '';
  String get errorMessage => _errorMessage;

  Position? _position;
  Position? get position => _position;

  String _cityName = 'Loading…';
  String get cityName => _cityName;

  DateTime _currentTime = DateTime.now();
  DateTime get currentTime => _currentTime;

  int _hijriAdjustment = 0;
  int get hijriAdjustment => _hijriAdjustment;

  String _masjidName = '';
  String get masjidName => _masjidName;

  int _globalOffset = 0;
  int get globalOffset => _globalOffset;

  List<PrayerEntry> _prayers = [];
  List<PrayerEntry> get prayers => _prayers;

  Timer? _timer;
  SharedPreferences? _prefs;

  // ---------------------------------------------------------------------------
  // Derived getters
  // ---------------------------------------------------------------------------

  /// Current time formatted as "12:56:23 PM".
  String get formattedClock => DateFormat('hh:mm:ss a').format(_currentTime);

  /// Hijri date string with user adjustment applied.
  String get hijriDateString {
    final adjusted = _currentTime.add(Duration(days: _hijriAdjustment));
    final hijri = HijriDate.fromGregorian(adjusted);
    return hijri.toString();
  }

  /// The 5 core prayers used for "next iqama" logic.
  static const _corePrayers = {'Fajr', 'Dhuhr', 'Asr', 'Maghrib', 'Isha'};

  /// The next core prayer whose iqama hasn't passed yet.
  PrayerEntry? get nextIqamaPrayer {
    for (final p in _prayers) {
      if (_corePrayers.contains(p.name) && p.iqamaTime.isAfter(_currentTime)) {
        return p;
      }
    }
    return null;
  }
  // Void iqmaAfter(PrayerEntry prayer) {
  //   final next = nextIqamaPrayer;
  //   if (next == null) return;
  //   final mins = next.iqamaTime.difference(_currentTime).inMinutes;
  // }

  /// Human-readable message: "Dhuhr Iqama after 4 minutes".
  String get nextIqamaMessage {
    final next = nextIqamaPrayer;
    if (next == null) return '';
    final mins = next.iqamaTime.difference(_currentTime).inMinutes;
    if (mins <= 0) return '${next.name} Iqama starting now';
    return '${next.name} Iqama after $mins minutes';
  }

  // ---------------------------------------------------------------------------
  // Default iqama configuration
  // ---------------------------------------------------------------------------

  static const _defaultOffsets = <String, int>{
    'Fajr': 20,
    'Dhuhr': 15,
    'Asr': 15,
    'Maghrib': 5,
    'Isha': 15,
    'Sunrise': 15,
    'Imsak': -15,
  };

  static const _fixedDefaults = <String, List<int>>{
    'Jumua': [13, 0],
    'Taraveeh': [20, 45],
    'Tahajjud': [3, 30],
    'Eid': [7, 30],
  };

  // ---------------------------------------------------------------------------
  // Initialization
  // ---------------------------------------------------------------------------

  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
    _loadSettings();

    await _fetchLocation();
    if (_locationStatus == LocationStatus.fetched) {
      _fetchCityName(); // fire-and-forget
      _calculatePrayerTimes();
      _startTimer();
    }
  }

  void _loadSettings() {
    _hijriAdjustment = _prefs?.getInt('hijri_adjustment') ?? 0;
    _masjidName = _prefs?.getString('masjid_name') ?? '';
    _globalOffset = _prefs?.getInt('global_offset') ?? 0;
  }

  // ---------------------------------------------------------------------------
  // Location
  // ---------------------------------------------------------------------------

  Future<void> _fetchLocation() async {
    _locationStatus = LocationStatus.loading;
    notifyListeners();

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _locationStatus = LocationStatus.serviceDisabled;
        _errorMessage =
            'Location services are disabled. Please enable them in Settings.';
        notifyListeners();
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _locationStatus = LocationStatus.permissionDenied;
          _errorMessage =
              'Location permission was denied. Grant permission to use this app.';
          notifyListeners();
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _locationStatus = LocationStatus.permissionDenied;
        _errorMessage =
            'Location permission is permanently denied. Enable it from device settings.';
        notifyListeners();
        return;
      }

      _position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
      _locationStatus = LocationStatus.fetched;
      notifyListeners();
    } catch (e) {
      _locationStatus = LocationStatus.error;
      _errorMessage = 'Failed to get location: $e';
      notifyListeners();
    }
  }

  /// Reverse-geocode the position to get a city name.
  Future<void> _fetchCityName() async {
    if (_position == null) return;
    try {
      final placemarks = await geo.placemarkFromCoordinates(
        _position!.latitude,
        _position!.longitude,
      );
      _cityName = placemarks.first.locality ??
          placemarks.first.subAdministrativeArea ??
          'Unknown';
    } catch (_) {
      _cityName =
          '${_position!.latitude.toStringAsFixed(2)}, ${_position!.longitude.toStringAsFixed(2)}';
    }
    notifyListeners();
  }

  /// Public: lets the UI trigger a full location refresh.
  Future<void> refreshLocation() async {
    _cityName = 'Loading…';
    notifyListeners();
    await _fetchLocation();
    if (_locationStatus == LocationStatus.fetched) {
      _fetchCityName();
      _calculatePrayerTimes();
    }
  }

  /// Public: retry after permission/error.
  Future<void> retry() async => initialize();

  // ---------------------------------------------------------------------------
  // Prayer time calculation
  // ---------------------------------------------------------------------------

  void _calculatePrayerTimes() {
    if (_position == null) return;

    final coords = Coordinates(_position!.latitude, _position!.longitude);
    final params = CalculationMethod.karachi.getParameters();
    params.madhab = Madhab.shafi;

    final now = DateTime.now();
    final dc = DateComponents.from(now);
    final pt = PrayerTimes(coords, dc, params);

    // Apply global minute offset to azan times (but NOT Sunrise — it's fixed astronomical).
    DateTime adj(DateTime t) => t.add(Duration(minutes: _globalOffset));

    final fajr = adj(pt.fajr);
    final sunrise = pt.sunrise; // Sunrise is constant — never shifted by global offset
    final dhuhr = adj(pt.dhuhr);
    final asr = adj(pt.asr);
    final maghrib = adj(pt.maghrib);
    final isha = adj(pt.isha);

    // Build the full prayer list in screenshot order.
    _prayers = [
      _buildEntry('Fajr', fajr),
      _buildEntry('Dhuhr', dhuhr),
      _buildEntry('Asr', asr),
      _buildEntry('Maghrib', maghrib),
      _buildEntry('Isha', isha),
      _buildEntry('Sunrise', sunrise),
      _buildEntry('Jumua', dhuhr),
      _buildEntry('Taraveeh', isha),
      _buildEntry('Tahajjud', fajr),
      // _buildEntry('Imsak', fajr),
      _buildEntry('Eid', sunrise),
    ];

    notifyListeners();
  }

  PrayerEntry _buildEntry(String name, DateTime azanTime) {
    final isFixed = _prefs?.getBool('iqama_fixed_$name') ??
        _fixedDefaults.containsKey(name);
    final offset =
        _prefs?.getInt('iqama_offset_$name') ?? _defaultOffsets[name] ?? 15;
    final fixedH = _prefs?.getInt('iqama_fixed_hour_$name') ??
        (_fixedDefaults[name]?[0] ?? 0);
    final fixedM = _prefs?.getInt('iqama_fixed_minute_$name') ??
        (_fixedDefaults[name]?[1] ?? 0);
    final azanAlert = _prefs?.getBool('azan_alert_$name') ?? true;
    final iqamaAlert = _prefs?.getBool('iqama_alert_$name') ?? true;

    return PrayerEntry(
      name: name,
      azanTime: azanTime,
      iqamaOffsetMinutes: offset,
      useFixedIqama: isFixed,
      fixedIqamaHour: fixedH,
      fixedIqamaMinute: fixedM,
      azanAlert: azanAlert,
      iqamaAlert: iqamaAlert,
    );
  }

  // ---------------------------------------------------------------------------
  // Timer — ticks every second to refresh the clock
  // ---------------------------------------------------------------------------

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _currentTime = DateTime.now();

      // Recalculate if the day rolled over.
      if (_prayers.isNotEmpty &&
          _currentTime.day != _prayers.first.azanTime.day) {
        _calculatePrayerTimes();
      }

      notifyListeners();
    });
  }

  // ---------------------------------------------------------------------------
  // User actions — called from the UI
  // ---------------------------------------------------------------------------

  void updateIqamaOffset(String name, int newOffset) {
    final idx = _prayers.indexWhere((p) => p.name == name);
    if (idx == -1) return;
    _prayers[idx].iqamaOffsetMinutes = newOffset;
    _prefs?.setInt('iqama_offset_$name', newOffset);
    notifyListeners();
  }

  void updateFixedIqamaTime(String name, int hour, int minute) {
    final idx = _prayers.indexWhere((p) => p.name == name);
    if (idx == -1) return;
    _prayers[idx].fixedIqamaHour = hour;
    _prayers[idx].fixedIqamaMinute = minute;
    _prefs?.setInt('iqama_fixed_hour_$name', hour);
    _prefs?.setInt('iqama_fixed_minute_$name', minute);
    notifyListeners();
  }

  void toggleAzanAlert(String name) {
    final idx = _prayers.indexWhere((p) => p.name == name);
    if (idx == -1) return;
    _prayers[idx].azanAlert = !_prayers[idx].azanAlert;
    _prefs?.setBool('azan_alert_$name', _prayers[idx].azanAlert);
    notifyListeners();
  }

  void toggleIqamaAlert(String name) {
    final idx = _prayers.indexWhere((p) => p.name == name);
    if (idx == -1) return;
    _prayers[idx].iqamaAlert = !_prayers[idx].iqamaAlert;
    _prefs?.setBool('iqama_alert_$name', _prayers[idx].iqamaAlert);
    notifyListeners();
  }

  void updateHijriAdjustment(int adj) {
    _hijriAdjustment = adj;
    _prefs?.setInt('hijri_adjustment', adj);
    notifyListeners();
  }

  void updateMasjidName(String name) {
    _masjidName = name;
    _prefs?.setString('masjid_name', name);
    notifyListeners();
  }

  void updateGlobalOffset(int offset) {
    _globalOffset = offset;
    _prefs?.setInt('global_offset', offset);
    _calculatePrayerTimes();
  }

  // ---------------------------------------------------------------------------
  // Cleanup
  // ---------------------------------------------------------------------------

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
