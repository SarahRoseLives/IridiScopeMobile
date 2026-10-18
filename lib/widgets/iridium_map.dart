import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/decoded_models.dart';

class IridiumMap extends StatefulWidget {
  final List<SatelliteInfo> satellites;
  final List<GroundBeamInfo> beams;

  const IridiumMap({
    super.key,
    required this.satellites,
    required this.beams,
  });

  @override
  State<IridiumMap> createState() => _IridiumMapState();
}

class _IridiumMapState extends State<IridiumMap> {
  ui.Image? _world;

  @override
  void initState() {
    super.initState();
    _loadWorld();
  }

  Future<void> _loadWorld() async {
    try {
      final data = await rootBundle.load('assets/worldmap.jpg');
      final codec =
          await ui.instantiateImageCodec(data.buffer.asUint8List());
      final frame = await codec.getNextFrame();
      if (!mounted) {
        frame.image.dispose();
        return;
      }
      setState(() => _world = frame.image);
    } catch (e) {
      debugPrint('worldmap load: $e');
    }
  }

  @override
  void dispose() {
    _world?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sats = widget.satellites.where((s) => s.hasPos).toList();
    final beams = widget.beams.where((b) => b.hasPos).toList();
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: Row(
              children: [
                Text('IRIDIUM MAP',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Colors.grey,
                          letterSpacing: 1.4,
                          fontWeight: FontWeight.w700,
                        )),
                const Spacer(),
                Text('${sats.length} sats  ·  ${beams.length} beams',
                    style: const TextStyle(
                        fontSize: 11,
                        color: Colors.white54,
                        fontFamily: 'monospace')),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: AspectRatio(
                  aspectRatio: 2,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CustomPaint(
                        painter: _MapPainter(
                          world: _world,
                          satellites: sats,
                          beams: beams,
                        ),
                      ),
                      if (sats.isEmpty && beams.isEmpty)
                        const Center(
                          child: Text(
                            'Waiting for IRA ring alerts with positions...',
                            style:
                                TextStyle(color: Colors.white54, fontSize: 12),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MapPainter extends CustomPainter {
  final ui.Image? world;
  final List<SatelliteInfo> satellites;
  final List<GroundBeamInfo> beams;

  _MapPainter({
    required this.world,
    required this.satellites,
    required this.beams,
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xff05070c));
    final img = world;
    if (img != null) {
      canvas.drawImageRect(
        img,
        Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
        Offset.zero & size,
        Paint()..filterQuality = FilterQuality.medium,
      );
    }

    final grid = Paint()
      ..color = const Color(0x3050ffd0)
      ..strokeWidth = 0.5;
    for (int lon = -180; lon <= 180; lon += 30) {
      final x = _x(lon.toDouble(), size);
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    }
    for (int lat = -60; lat <= 60; lat += 30) {
      final y = _y(lat.toDouble(), size);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    final beamPaint = Paint()..color = const Color(0x88ffb74d);
    for (final b in beams) {
      final p = _project(b.lat, b.lon, size);
      final r = (2.0 + b.pages.clamp(0, 20) * 0.35).clamp(2.0, 8.0);
      canvas.drawCircle(p, r, beamPaint);
    }

    final satPaint = Paint()..color = const Color(0xff00e5ff);
    final glow = Paint()
      ..color = const Color(0x4400e5ff)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    for (final s in satellites) {
      final p = _project(s.lat, s.lon, size);
      canvas.drawCircle(p, 5, glow);
      canvas.drawCircle(p, 3, satPaint);
      final tp = TextPainter(
        text: TextSpan(
          text: ' ${s.id}',
          style: const TextStyle(
              color: Colors.white,
              fontSize: 9,
              fontFamily: 'monospace',
              shadows: [Shadow(color: Colors.black, blurRadius: 3)]),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, p + const Offset(4, -6));
    }
  }

  double _x(double lon, Size size) => (lon + 180.0) / 360.0 * size.width;
  double _y(double lat, Size size) => (90.0 - lat) / 180.0 * size.height;
  Offset _project(double lat, double lon, Size size) =>
      Offset(_x(lon, size), _y(lat, size));

  @override
  bool shouldRepaint(_MapPainter old) =>
      old.world != world ||
      old.satellites != satellites ||
      old.beams != beams;
}
