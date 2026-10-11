import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../data/models.dart';

const _palettes = [
  ['#3b2412', '#c08a3e', '#f2d9a6'],
  ['#1c2433', '#4f6a8f', '#e7c58a'],
  ['#2a1408', '#a0522d', '#f2c27b'],
  ['#14231d', '#3f7a5c', '#e9d49a'],
  ['#2b1630', '#8a4f7d', '#f0c48a'],
  ['#1d140c', '#8a5a2b', '#e0a95a'],
  ['#0d1420', '#3b5a85', '#f0c98a'],
];

Color _hex(String s) {
  final h = s.replaceAll('#', '');
  return Color(int.tryParse(h.length == 6 ? 'FF$h' : h, radix: 16) ?? 0xFF3B2412);
}

List<Color> paletteFor(List<String> palette, int seed) {
  final p = palette.length >= 3 ? palette : _palettes[seed.abs() % _palettes.length];
  return p.take(3).map(_hex).toList();
}

String defaultShape(EntryKind kind) => switch (kind) {
      EntryKind.museum => 'columns',
      EntryKind.city => 'ruins',
      EntryKind.castle => 'fort',
      _ => 'dome',
    };

/// A cover image: the real photo when there is one (cached for offline use),
/// otherwise painted art in the site's style: a sunset sky and a silhouette.
class Cover extends StatelessWidget {
  const Cover({
    super.key,
    required this.image,
    required this.palette,
    required this.shape,
    this.seed = 0,
    this.label,
  });

  factory Cover.entry(Entry e, {Key? key}) => Cover(
        key: key,
        image: e.image,
        palette: e.palette,
        shape: e.shape.isNotEmpty ? e.shape : defaultShape(e.kind),
        seed: e.id,
      );

  factory Cover.term(Term t, {String fallbackShape = 'dome', Key? key}) => Cover(
        key: key,
        image: t.image,
        palette: t.palette,
        shape: t.shape.isNotEmpty ? t.shape : fallbackShape,
        seed: t.id,
      );

  final String image;
  final List<String> palette;
  final String shape;
  final int seed;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final painted = CustomPaint(
      painter: CoverPainter(paletteFor(palette, seed), shape, seed),
      child: const SizedBox.expand(),
    );
    if (image.isEmpty) return painted;
    return CachedNetworkImage(
      imageUrl: image,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      fadeInDuration: const Duration(milliseconds: 250),
      placeholder: (_, _) => painted,
      errorWidget: (_, _, _) => painted,
    );
  }
}

class CoverPainter extends CustomPainter {
  CoverPainter(this.colors, this.shape, this.seed);

  final List<Color> colors;
  final String shape;
  final int seed;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final dark = colors[0], mid = colors[1], light = colors[2];

    // Sky.
    final sky = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [dark, Color.lerp(dark, mid, .7)!, Color.lerp(mid, light, .55)!],
        stops: const [0, .55, .82],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, sky);

    // Sun with a soft glow.
    final sun = Offset(w * (0.62 + (seed % 5) * 0.03), h * 0.62);
    final r = math.min(w, h) * 0.2;
    canvas.drawCircle(
        sun,
        r * 2.2,
        Paint()
          ..shader = RadialGradient(colors: [
            light.withValues(alpha: .45),
            light.withValues(alpha: 0),
          ]).createShader(Rect.fromCircle(center: sun, radius: r * 2.2)));
    canvas.drawCircle(sun, r, Paint()..color = Color.lerp(light, Colors.white, .35)!);

    final ink = Paint()..color = Color.lerp(dark, Colors.black, .55)!;
    final base = h * 0.84;

    final kind = _kind(shape);
    final cx = w * 0.5;
    final unit = math.min(w / 10, h / 6);
    switch (kind) {
      case 'mosque':
        _mosque(canvas, ink, cx, base, unit);
      case 'temple':
        _temple(canvas, ink, cx, base, unit);
      case 'ruins':
        _ruins(canvas, ink, cx, base, unit);
      case 'fort':
        _fort(canvas, ink, cx, base, unit);
      case 'pyramid':
        _pyramid(canvas, ink, cx, base, unit, w);
      case 'pagoda':
        _pagoda(canvas, ink, cx, base, unit);
      case 'stupa':
        _stupa(canvas, ink, cx, base, unit);
      case 'mountain':
        _mountain(canvas, ink, base, w, unit);
      case 'lighthouse':
        _lighthouse(canvas, ink, cx, base, unit);
      default:
        _palace(canvas, ink, cx, base, unit);
    }

    // Ground.
    canvas.drawRect(Rect.fromLTRB(0, base, w, h), ink);
    // Bottom shade for text legibility.
    canvas.drawRect(
      Rect.fromLTRB(0, h * .55, w, h),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.black.withValues(alpha: 0), Colors.black.withValues(alpha: .25)],
        ).createShader(Rect.fromLTRB(0, h * .55, w, h)),
    );
  }

  static String _kind(String s) {
    const map = {
      'mosque': ['dome', 'mosque', 'mughal', 'hagia', 'umayyad', 'registan', 'cairo', 'sanjar', 'shrine', 'minaret', 'alhambra', 'tombs'],
      'temple': ['columns', 'acropolis', 'pylon', 'hall'],
      'ruins': ['ruins', 'arch', 'gate', 'citadel', 'rockcut'],
      'fort': ['fort', 'keep', 'gatehouse', 'crusader', 'castillo', 'fairytale', 'round', 'castle'],
      'pyramid': ['pyramid', 'pyramids', 'ziggurat', 'mound', 'adobe', 'angkor'],
      'pagoda': ['pagoda', 'japanese'],
      'stupa': ['stupa'],
      'mountain': ['mountain', 'volcano'],
      'lighthouse': ['lighthouse', 'harbour', 'ship'],
    };
    for (final e in map.entries) {
      if (e.value.contains(s)) return e.key;
    }
    return 'palace';
  }

  void _rect(Canvas c, Paint p, double l, double t, double r, double b) =>
      c.drawRect(Rect.fromLTRB(l, t, r, b), p);

  void _mosque(Canvas c, Paint p, double cx, double base, double u) {
    _rect(c, p, cx - 2.6 * u, base - 1.6 * u, cx + 2.6 * u, base);
    c.drawOval(Rect.fromCenter(center: Offset(cx, base - 1.6 * u), width: 3 * u, height: 3.2 * u), p);
    _rect(c, p, cx - .05 * u, base - 3.9 * u, cx + .05 * u, base - 3 * u);
    for (final dx in [-3.6, 3.6, -1.9, 1.9]) {
      final big = dx.abs() > 3;
      final mw = big ? .28 * u : .2 * u;
      final mh = big ? 3.8 * u : 2.4 * u;
      _rect(c, p, cx + dx * u - mw, base - mh, cx + dx * u + mw, base);
      c.drawOval(Rect.fromCenter(center: Offset(cx + dx * u, base - mh), width: mw * 2.6, height: mw * 2.6), p);
    }
    _rect(c, p, cx - 4.5 * u, base - .7 * u, cx + 4.5 * u, base);
  }

  void _temple(Canvas c, Paint p, double cx, double base, double u) {
    final l = cx - 3.4 * u, r = cx + 3.4 * u;
    _rect(c, p, l - .3 * u, base - .5 * u, r + .3 * u, base);
    final top = base - 3 * u;
    for (var i = 0; i < 8; i++) {
      final x = l + i * (r - l) / 7;
      _rect(c, p, x - .17 * u, top, x + .17 * u, base - .5 * u);
    }
    _rect(c, p, l - .2 * u, top - .5 * u, r + .2 * u, top);
    c.drawPath(
        Path()
          ..moveTo(l - .3 * u, top - .5 * u)
          ..lineTo(cx, top - 1.6 * u)
          ..lineTo(r + .3 * u, top - .5 * u)
          ..close(),
        p);
  }

  void _ruins(Canvas c, Paint p, double cx, double base, double u) {
    final heights = [2.6, 1.4, 3.0, .9, 2.2, 1.7];
    for (var i = 0; i < heights.length; i++) {
      final x = cx - 3.5 * u + i * 1.4 * u;
      _rect(c, p, x, base - heights[i] * u, x + .45 * u, base);
    }
    // An arch.
    final a = Path()
      ..moveTo(cx - 1.4 * u, base)
      ..lineTo(cx - 1.4 * u, base - 2.2 * u)
      ..arcToPoint(Offset(cx + 1.4 * u, base - 2.2 * u), radius: Radius.circular(1.4 * u))
      ..lineTo(cx + 1.4 * u, base)
      ..lineTo(cx + .8 * u, base)
      ..lineTo(cx + .8 * u, base - 2.2 * u)
      ..arcToPoint(Offset(cx - .8 * u, base - 2.2 * u), radius: Radius.circular(.8 * u), clockwise: false)
      ..lineTo(cx - .8 * u, base)
      ..close();
    c.drawPath(a, p);
  }

  void _fort(Canvas c, Paint p, double cx, double base, double u) {
    _rect(c, p, cx - 4.4 * u, base - 1.8 * u, cx + 4.4 * u, base);
    for (var x = cx - 4.4 * u; x < cx + 4.4 * u; x += .5 * u) {
      _rect(c, p, x, base - 2.1 * u, x + .28 * u, base - 1.8 * u);
    }
    for (final dx in [-3.6, 3.6, -1.1, 1.1]) {
      final big = dx.abs() < 2;
      final th = big ? 3.6 * u : 2.8 * u;
      final tw = big ? .75 * u : .6 * u;
      _rect(c, p, cx + dx * u - tw, base - th, cx + dx * u + tw, base);
      for (var k = -1; k <= 1; k++) {
        final x = cx + dx * u + k * tw * .75;
        _rect(c, p, x - tw * .18, base - th - .3 * u, x + tw * .18, base - th);
      }
    }
    // Gate opening drawn in sky colour is skipped; keep a solid silhouette.
  }

  void _pyramid(Canvas c, Paint p, double cx, double base, double u, double w) {
    c.drawPath(
        Path()
          ..moveTo(cx - 3.2 * u, base)
          ..lineTo(cx - .4 * u, base - 3.6 * u)
          ..lineTo(cx + 2.4 * u, base)
          ..close(),
        p);
    c.drawPath(
        Path()
          ..moveTo(cx + 1.2 * u, base)
          ..lineTo(cx + 2.9 * u, base - 2.1 * u)
          ..lineTo(cx + 4.6 * u, base)
          ..close(),
        p);
  }

  void _pagoda(Canvas c, Paint p, double cx, double base, double u) {
    var y = base;
    var half = 2.2 * u;
    for (var i = 0; i < 4; i++) {
      _rect(c, p, cx - half * .6, y - .9 * u, cx + half * .6, y);
      c.drawPath(
          Path()
            ..moveTo(cx - half - .3 * u, y - .75 * u)
            ..quadraticBezierTo(cx, y - 1.5 * u, cx + half + .3 * u, y - .75 * u)
            ..lineTo(cx + half * .6, y - 1.15 * u)
            ..lineTo(cx - half * .6, y - 1.15 * u)
            ..close(),
          p);
      y -= 1.1 * u;
      half *= .8;
    }
    _rect(c, p, cx - .06 * u, y - 1 * u, cx + .06 * u, y);
  }

  void _stupa(Canvas c, Paint p, double cx, double base, double u) {
    _rect(c, p, cx - 3.4 * u, base - .5 * u, cx + 3.4 * u, base);
    c.drawArc(Rect.fromCenter(center: Offset(cx, base - .5 * u), width: 5.4 * u, height: 5 * u),
        math.pi, math.pi, true, p);
    _rect(c, p, cx - .45 * u, base - 3.4 * u, cx + .45 * u, base - 2.8 * u);
    _rect(c, p, cx - .08 * u, base - 4.6 * u, cx + .08 * u, base - 3.4 * u);
    for (var i = 0; i < 3; i++) {
      _rect(c, p, cx - (.5 - i * .12) * u, base - (3.7 + i * .3) * u, cx + (.5 - i * .12) * u, base - (3.62 + i * .3) * u);
    }
  }

  void _mountain(Canvas c, Paint p, double base, double w, double u) {
    c.drawPath(
        Path()
          ..moveTo(0, base)
          ..lineTo(w * .28, base - 3.4 * u)
          ..lineTo(w * .42, base - 2.2 * u)
          ..lineTo(w * .6, base - 4 * u)
          ..lineTo(w, base - 1 * u)
          ..lineTo(w, base)
          ..close(),
        p);
  }

  void _lighthouse(Canvas c, Paint p, double cx, double base, double u) {
    c.drawPath(
        Path()
          ..moveTo(cx - .9 * u, base)
          ..lineTo(cx - .5 * u, base - 4 * u)
          ..lineTo(cx + .5 * u, base - 4 * u)
          ..lineTo(cx + .9 * u, base)
          ..close(),
        p);
    _rect(c, p, cx - .7 * u, base - 4.9 * u, cx + .7 * u, base - 4 * u);
    c.drawPath(
        Path()
          ..moveTo(cx - .8 * u, base - 4.9 * u)
          ..lineTo(cx, base - 5.6 * u)
          ..lineTo(cx + .8 * u, base - 4.9 * u)
          ..close(),
        p);
    _rect(c, p, cx - 4.5 * u, base - .6 * u, cx + 4.5 * u, base);
  }

  void _palace(Canvas c, Paint p, double cx, double base, double u) {
    _rect(c, p, cx - 4 * u, base - 2 * u, cx + 4 * u, base);
    _rect(c, p, cx - 1.6 * u, base - 3 * u, cx + 1.6 * u, base);
    c.drawOval(Rect.fromCenter(center: Offset(cx, base - 3 * u), width: 2.2 * u, height: 2 * u), p);
    for (final dx in [-3.0, 3.0]) {
      c.drawOval(Rect.fromCenter(center: Offset(cx + dx * u, base - 2 * u), width: 1.2 * u, height: 1.1 * u), p);
    }
  }

  @override
  bool shouldRepaint(CoverPainter old) =>
      old.shape != shape || old.seed != seed || old.colors != colors;
}
