/// Lightweight Hijri (Islamic) date conversion using the Kuwaiti algorithm.
/// No external package required. Works accurately for modern dates (1900–2099).
class HijriDate {
  final int year;
  final int month;
  final int day;

  HijriDate(this.year, this.month, this.day);

  static const _monthNames = [
    'Muharram',
    'Safar',
    'Rabi al-Awwal',
    'Rabi al-Thani',
    'Jumada al-Ula',
    'Jumada al-Thani',
    'Rajab',
    "Sha'ban",
    'Ramadhan',
    'Shawwal',
    "Dhul Qi'dah",
    'Dhul Hijjah',
  ];

  String get monthName => _monthNames[month - 1];

  /// Convert a Gregorian [DateTime] to a Hijri date.
  factory HijriDate.fromGregorian(DateTime date) {
    int y = date.year;
    int m = date.month;
    int d = date.day;

    // Step 1: Gregorian → Julian Day Number
    if (m <= 2) {
      y -= 1;
      m += 12;
    }
    final a = (y / 100).floor();
    final b = 2 - a + (a / 4).floor();
    final jd = (365.25 * (y + 4716)).floor() +
        (30.6001 * (m + 1)).floor() +
        d +
        b -
        1524;

    // Step 2: Julian Day Number → Hijri (Kuwaiti algorithm)
    int l = jd - 1948440 + 10632;
    final n = ((l - 1) / 10631).floor();
    l = l - 10631 * n + 354;
    final j = ((10985 - l) / 5316).floor() * ((50 * l) / 17719).floor() +
        (l / 5670).floor() * ((43 * l) / 15238).floor();
    l = l -
        ((30 - j) / 15).floor() * ((17719 * j) / 50).floor() -
        (j / 16).floor() * ((15238 * j) / 43).floor() +
        29;
    final hm = ((24 * l) / 709).floor();
    final hd = l - ((709 * hm) / 24).floor();
    final hy = 30 * n + j - 30;

    return HijriDate(hy, hm, hd);
  }

  @override
  String toString() => '$day $monthName $year';
}
