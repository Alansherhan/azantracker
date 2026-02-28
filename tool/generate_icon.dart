// ignore_for_file: depend_on_referenced_packages
/// Generates the app icon PNGs for AzanTracker.
/// Run with: dart run tool/generate_icon.dart
library;

import 'dart:io';
import 'dart:math';
import 'package:image/image.dart' as img;

void main() {
  print('Generating AzanTracker app icons…');

  final icon = _generateIcon(1024);
  final foreground = _generateForeground(1024);

  // Ensure output directory exists.
  Directory('assets/icon').createSync(recursive: true);

  // Write full icon (used for iOS and legacy Android).
  File('assets/icon/app_icon.png')
      .writeAsBytesSync(img.encodePng(icon));
  print('  ✓ assets/icon/app_icon.png');

  // Write foreground-only for Android adaptive icon.
  File('assets/icon/app_icon_foreground.png')
      .writeAsBytesSync(img.encodePng(foreground));
  print('  ✓ assets/icon/app_icon_foreground.png');

  print('Done!');
}

// =============================================================================
// Full icon (with background gradient + crescent + mosque dome + star)
// =============================================================================

img.Image _generateIcon(int size) {
  final image = img.Image(width: size, height: size);
  final cx = size / 2;
  final cy = size / 2;

  // 1. Dark gradient background.
  for (int y = 0; y < size; y++) {
    final t = y / size;
    final r = _lerp(26, 45, t).round();   // 0x1a -> 0x2d
    final g = _lerp(26, 58, t).round();   // 0x1a -> 0x3a
    final b = _lerp(46, 74, t).round();   // 0x2e -> 0x4a
    for (int x = 0; x < size; x++) {
      image.setPixelRgba(x, y, r, g, b, 255);
    }
  }

  // 2. Crescent moon.
  _drawCrescent(image, cx, cy * 0.48, size * 0.28, size * 0.22,
      img.ColorFloat32.rgba(0.33, 0.87, 0.75, 1.0)); // tealAccent-ish

  // 3. Star next to crescent.
  _drawStar(image, cx + size * 0.22, cy * 0.38, size * 0.06, 5,
      img.ColorFloat32.rgba(0.33, 0.87, 0.75, 1.0));

  // 4. Mosque dome silhouette at bottom.
  _drawMosqueDome(image, cx, size * 0.72, size * 0.35, size * 0.20,
      img.ColorFloat32.rgba(0.18, 0.32, 0.24, 1.0)); // dark green

  // 5. Minaret towers.
  _drawMinaret(image, (cx - size * 0.30).round(), size * 0.50, size * 0.04,
      size * 0.42, img.ColorFloat32.rgba(0.18, 0.32, 0.24, 1.0));
  _drawMinaret(image, (cx + size * 0.30).round(), size * 0.50, size * 0.04,
      size * 0.42, img.ColorFloat32.rgba(0.18, 0.32, 0.24, 1.0));

  return image;
}

// =============================================================================
// Foreground only (transparent bg — for Android adaptive icons)
// =============================================================================

img.Image _generateForeground(int size) {
  final image = img.Image(width: size, height: size);
  // Start with fully transparent.
  img.fill(image, color: img.ColorFloat32.rgba(0, 0, 0, 0));

  final cx = size / 2;
  final cy = size / 2;

  // Safe zone for adaptive icons is the inner 66%.
  final inset = size * 0.17;
  final safeSize = size - 2 * inset;
  final safeCx = cx;
  final safeCy = cy;

  // Crescent in safe zone.
  _drawCrescent(image, safeCx, safeCy * 0.58, safeSize * 0.26, safeSize * 0.20,
      img.ColorFloat32.rgba(0.33, 0.87, 0.75, 1.0));

  // Star.
  _drawStar(image, safeCx + safeSize * 0.20, safeCy * 0.48, safeSize * 0.055, 5,
      img.ColorFloat32.rgba(0.33, 0.87, 0.75, 1.0));

  // Mosque dome.
  _drawMosqueDome(image, safeCx, safeCy + safeSize * 0.22, safeSize * 0.30,
      safeSize * 0.18, img.ColorFloat32.rgba(0.33, 0.87, 0.75, 1.0));

  // Minarets.
  _drawMinaret(image, (safeCx - safeSize * 0.28).round(),
      safeCy + safeSize * 0.01, safeSize * 0.035, safeSize * 0.38,
      img.ColorFloat32.rgba(0.33, 0.87, 0.75, 1.0));
  _drawMinaret(image, (safeCx + safeSize * 0.28).round(),
      safeCy + safeSize * 0.01, safeSize * 0.035, safeSize * 0.38,
      img.ColorFloat32.rgba(0.33, 0.87, 0.75, 1.0));

  return image;
}

// =============================================================================
// Drawing helpers
// =============================================================================

double _lerp(double a, double b, double t) => a + (b - a) * t;

/// Draws a crescent moon shape (outer circle minus inner circle offset).
void _drawCrescent(
    img.Image image, double cx, double cy, double outerR, double innerR,
    img.Color color) {
  final offsetX = outerR * 0.35; // How far the inner circle is shifted right.
  final x0 = (cx - outerR - 2).floor();
  final x1 = (cx + outerR + 2).ceil();
  final y0 = (cy - outerR - 2).floor();
  final y1 = (cy + outerR + 2).ceil();

  for (int y = y0; y <= y1; y++) {
    for (int x = x0; x <= x1; x++) {
      if (x < 0 || x >= image.width || y < 0 || y >= image.height) continue;
      final dx1 = x - cx;
      final dy1 = y - cy;
      final inOuter = dx1 * dx1 + dy1 * dy1 <= outerR * outerR;

      final dx2 = x - (cx + offsetX);
      final dy2 = y - cy;
      final inInner = dx2 * dx2 + dy2 * dy2 <= innerR * innerR;

      if (inOuter && !inInner) {
        image.setPixel(x, y, color);
      }
    }
  }
}

/// Draws a simple 5-pointed star.
void _drawStar(
    img.Image image, double cx, double cy, double r, int points,
    img.Color color) {
  final innerR = r * 0.4;

  // Build polygon vertices.
  final vertices = <Point>[];
  for (int i = 0; i < points * 2; i++) {
    final angle = (i * pi / points) - pi / 2;
    final radius = i.isEven ? r : innerR;
    vertices.add(Point(cx + radius * cos(angle), cy + radius * sin(angle)));
  }

  // Fill using scanline.
  _fillPolygon(image, vertices, color);
}

/// Draws a dome (half ellipse).
void _drawMosqueDome(
    img.Image image, double cx, double cy, double rx, double ry,
    img.Color color) {
  // Dome (upper half ellipse).
  for (int y = (cy - ry).floor(); y <= cy.ceil(); y++) {
    if (y < 0 || y >= image.height) continue;
    final dy = (y - cy) / ry;
    if (dy.abs() > 1) continue;
    final halfWidth = rx * sqrt(1 - dy * dy);
    for (int x = (cx - halfWidth).floor(); x <= (cx + halfWidth).ceil(); x++) {
      if (x < 0 || x >= image.width) continue;
      image.setPixel(x, y, color);
    }
  }

  // Base rectangle under dome.
  final baseTop = cy.ceil();
  final baseBottom = (cy + ry * 0.5).ceil();
  for (int y = baseTop; y <= baseBottom; y++) {
    if (y < 0 || y >= image.height) continue;
    for (int x = (cx - rx * 0.6).floor(); x <= (cx + rx * 0.6).ceil(); x++) {
      if (x < 0 || x >= image.width) continue;
      image.setPixel(x, y, color);
    }
  }

  // Small finial on top of dome.
  _drawFilledCircle(image, cx.round(), (cy - ry - r(ry * 0.12)).round(),
      (ry * 0.06).round(), color);
}

int r(double v) => v.round();

/// Draws a minaret (tall rectangle + small dome cap).
void _drawMinaret(
    img.Image image, int cx, double topY, double halfWidth, double height,
    img.Color color) {
  final top = topY.round();
  final bottom = (topY + height).round();
  final left = (cx - halfWidth).round();
  final right = (cx + halfWidth).round();

  // Cap (small semicircle).
  final capR = halfWidth * 1.3;
  for (int y = (top - capR).round(); y <= top; y++) {
    if (y < 0 || y >= image.height) continue;
    final dy = (y - top) / capR;
    if (dy.abs() > 1) continue;
    final hw = capR * sqrt(1 - dy * dy);
    for (int x = (cx - hw).round(); x <= (cx + hw).round(); x++) {
      if (x < 0 || x >= image.width) continue;
      image.setPixel(x, y, color);
    }
  }

  // Tower body.
  for (int y = top; y <= bottom; y++) {
    if (y < 0 || y >= image.height) continue;
    for (int x = left; x <= right; x++) {
      if (x < 0 || x >= image.width) continue;
      image.setPixel(x, y, color);
    }
  }
}

void _drawFilledCircle(img.Image image, int cx, int cy, int r, img.Color color) {
  for (int y = cy - r; y <= cy + r; y++) {
    if (y < 0 || y >= image.height) continue;
    for (int x = cx - r; x <= cx + r; x++) {
      if (x < 0 || x >= image.width) continue;
      if ((x - cx) * (x - cx) + (y - cy) * (y - cy) <= r * r) {
        image.setPixel(x, y, color);
      }
    }
  }
}

class Point {
  final double x, y;
  Point(this.x, this.y);
}

/// Simple scanline polygon fill.
void _fillPolygon(img.Image image, List<Point> vertices, img.Color color) {
  if (vertices.isEmpty) return;

  double minY = vertices[0].y, maxY = vertices[0].y;
  for (final v in vertices) {
    if (v.y < minY) minY = v.y;
    if (v.y > maxY) maxY = v.y;
  }

  for (int y = minY.floor(); y <= maxY.ceil(); y++) {
    if (y < 0 || y >= image.height) continue;
    final intersections = <double>[];
    for (int i = 0; i < vertices.length; i++) {
      final j = (i + 1) % vertices.length;
      final v1 = vertices[i];
      final v2 = vertices[j];
      if ((v1.y <= y && v2.y > y) || (v2.y <= y && v1.y > y)) {
        final t = (y - v1.y) / (v2.y - v1.y);
        intersections.add(v1.x + t * (v2.x - v1.x));
      }
    }
    intersections.sort();
    for (int i = 0; i + 1 < intersections.length; i += 2) {
      for (int x = intersections[i].floor(); x <= intersections[i + 1].ceil(); x++) {
        if (x >= 0 && x < image.width) {
          image.setPixel(x, y, color);
        }
      }
    }
  }
}
