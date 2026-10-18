import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../models/waterfall_settings.dart';

class SpectrumWaterfall extends StatefulWidget {
  final Stream<Float32List> spectrumStream;
  final WaterfallSettings settings;
  final int centerHz;
  final int sampleRateHz;
  final ValueChanged<int>? onTune;

  const SpectrumWaterfall({
    super.key,
    required this.spectrumStream,
    required this.settings,
    required this.centerHz,
    required this.sampleRateHz,
    this.onTune,
  });

  @override
  State<SpectrumWaterfall> createState() => _SpectrumWaterfallState();
}

class _SpectrumWaterfallState extends State<SpectrumWaterfall> {
  final List<Float32List> _rows = [];
  Float32List? _spectrum;
  StreamSubscription<Float32List>? _sub;

  ui.Image? _wfImage;
  bool _imageBuilding = false;
  int _lastImageMs = 0;
  static const _imageIntervalMs = 40;

  final _specNotifier = ValueNotifier<int>(0);
  final _wfNotifier = ValueNotifier<int>(0);

  double _dragStartFreq = 0;
  double _dragStartX = 0;
  DateTime _lastTune = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void initState() {
    super.initState();
    _subscribe();
  }

  void _subscribe() {
    _sub?.cancel();
    _sub = widget.spectrumStream.listen(_onFrame);
  }

  @override
  void didUpdateWidget(SpectrumWaterfall old) {
    super.didUpdateWidget(old);
    if (old.spectrumStream != widget.spectrumStream) _subscribe();
    if (old.settings.waterfallRows != widget.settings.waterfallRows) {
      while (_rows.length > widget.settings.waterfallRows) {
        _rows.removeLast();
      }
    }
    _specNotifier.value++;
    _wfNotifier.value++;
  }

  void _onFrame(Float32List frame) {
    if (!mounted || frame.isEmpty) return;
    _spectrum = frame;
    if (_rows.isNotEmpty && _rows.first.length != frame.length) _rows.clear();
    _rows.insert(0, frame);
    final maxRows = widget.settings.waterfallRows;
    while (_rows.length > maxRows) {
      _rows.removeLast();
    }
    _specNotifier.value++;

    final now = DateTime.now().millisecondsSinceEpoch;
    if (!_imageBuilding && now - _lastImageMs >= _imageIntervalMs) {
      _lastImageMs = now;
      _buildImage();
    }
  }

  Future<void> _buildImage() async {
    if (_rows.isEmpty) return;
    _imageBuilding = true;
    final rows = List<Float32List>.from(_rows);
    final settings = widget.settings;
    final width = 1024;
    final height = rows.length.clamp(1, settings.waterfallRows);
    final lut = _buildLut(settings.colorScheme);
    final range = (settings.maxDb - settings.minDb).clamp(1.0, 400.0);
    final pixels = Uint8List(width * height * 4);

    for (int r = 0; r < height; r++) {
      final row = rows[r];
      final base = r * width * 4;
      for (int x = 0; x < width; x++) {
        final idx = (x * row.length / width).toInt().clamp(0, row.length - 1);
        final v = ((row[idx] - settings.minDb) / range).clamp(0.0, 1.0);
        final c = lut[(v * 255).round()];
        final p = base + x * 4;
        pixels[p] = (c >> 16) & 0xff;
        pixels[p + 1] = (c >> 8) & 0xff;
        pixels[p + 2] = c & 0xff;
        pixels[p + 3] = 255;
      }
    }

    final completer = Completer<ui.Image>();
    ui.decodeImageFromPixels(
        pixels, width, height, ui.PixelFormat.rgba8888, completer.complete);
    final img = await completer.future;
    if (!mounted) {
      img.dispose();
      _imageBuilding = false;
      return;
    }
    _wfImage?.dispose();
    _wfImage = img;
    _imageBuilding = false;
    _wfNotifier.value++;
  }

  @override
  void dispose() {
    _sub?.cancel();
    _wfImage?.dispose();
    _specNotifier.dispose();
    _wfNotifier.dispose();
    super.dispose();
  }

  void _onDragStart(DragStartDetails d) {
    _dragStartFreq = widget.centerHz.toDouble();
    _dragStartX = d.localPosition.dx;
  }

  void _onDragUpdate(DragUpdateDetails d, double width) {
    final now = DateTime.now();
    if (now.difference(_lastTune).inMilliseconds < 80) return;
    _lastTune = now;
    if (width <= 0) return;
    final dx = d.localPosition.dx - _dragStartX;
    final hzPerPixel = widget.sampleRateHz / width;
    final hz = (_dragStartFreq - dx * hzPerPixel).round();
    widget.onTune?.call(hz);
  }

  void _onTapUp(TapUpDetails d, double width) {
    if (width <= 0) return;
    final step = widget.sampleRateHz / 20;
    final hz = d.localPosition.dx < width / 2
        ? widget.centerHz - step
        : widget.centerHz + step;
    widget.onTune?.call(hz.round());
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: Row(
              children: [
                Text('SPECTRUM / WATERFALL',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Colors.grey,
                          letterSpacing: 1.4,
                          fontWeight: FontWeight.w700,
                        )),
                const Spacer(),
                Text(
                  '${(_centerLabel(widget.centerHz))}  ·  '
                  '${WaterfallSettings.formatRate(widget.sampleRateHz)}',
                  style: const TextStyle(
                      fontSize: 11,
                      fontFamily: 'monospace',
                      color: Colors.white70),
                ),
              ],
            ),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                return GestureDetector(
                  onHorizontalDragStart: _onDragStart,
                  onHorizontalDragUpdate: (d) => _onDragUpdate(d, width),
                  onTapUp: (d) => _onTapUp(d, width),
                  child: ClipRect(
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        ValueListenableBuilder<int>(
                          valueListenable: _wfNotifier,
                          builder: (context, _, __) => CustomPaint(
                            painter: _WaterfallPainter(
                              image: _wfImage,
                              settings: widget.settings,
                              centerHz: widget.centerHz,
                              sampleRateHz: widget.sampleRateHz,
                            ),
                          ),
                        ),
                        ValueListenableBuilder<int>(
                          valueListenable: _specNotifier,
                          builder: (context, _, __) => CustomPaint(
                            painter: _SpectrumPainter(
                              spectrum: _spectrum,
                              settings: widget.settings,
                              centerHz: widget.centerHz,
                              sampleRateHz: widget.sampleRateHz,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  static String _centerLabel(int hz) =>
      '${(hz / 1e6).toStringAsFixed(5)} MHz';
}

class _SpectrumPainter extends CustomPainter {
  final Float32List? spectrum;
  final WaterfallSettings settings;
  final int centerHz;
  final int sampleRateHz;

  _SpectrumPainter({
    required this.spectrum,
    required this.settings,
    required this.centerHz,
    required this.sampleRateHz,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final specH = size.height * 0.38;
    final grid = Paint()
      ..color = const Color(0x26323240)
      ..strokeWidth = 0.6;

    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, specH),
        Paint()..color = const Color(0xff0f0f14));

    const vDivs = 6;
    for (int i = 0; i <= vDivs; i++) {
      final x = size.width * i / vDivs;
      canvas.drawLine(Offset(x, 0), Offset(x, specH), grid);
      final hz = centerHz - sampleRateHz / 2 +
          sampleRateHz * i / vDivs;
      _text(canvas, '${(hz / 1e6).toStringAsFixed(3)}',
          Offset(x + 2, specH - 12), 9, const Color(0xff9a9aa8));
    }

    const hDivs = 4;
    for (int i = 0; i <= hDivs; i++) {
      final y = specH * i / hDivs;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
      final db = settings.maxDb -
          (settings.maxDb - settings.minDb) * i / hDivs;
      _text(canvas, db.toStringAsFixed(0), Offset(3, y + 1), 8,
          const Color(0xff82828f));
    }

    final data = spectrum;
    if (data == null || data.isEmpty) return;

    final range = (settings.maxDb - settings.minDb).clamp(1.0, 400.0);
    final path = Path();
    final fill = Path();
    for (int i = 0; i < data.length; i++) {
      final x = size.width * i / (data.length - 1);
      final v = data[i].clamp(settings.minDb, settings.maxDb);
      final y = specH * (1 - (v - settings.minDb) / range);
      if (i == 0) {
        path.moveTo(x, y);
        fill.moveTo(x, specH);
        fill.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fill.lineTo(x, y);
      }
    }
    fill
      ..lineTo(size.width, specH)
      ..close();

    canvas.drawPath(fill, Paint()..color = const Color(0x55145050));
    canvas.drawPath(
        path,
        Paint()
          ..color = const Color(0xff00d2c8)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.1);
  }

  void _text(Canvas canvas, String text, Offset at, double size, Color color) {
    final tp = TextPainter(
      text: TextSpan(
          text: text,
          style: TextStyle(
              color: color, fontSize: size, fontFamily: 'monospace')),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, at);
  }

  @override
  bool shouldRepaint(_SpectrumPainter old) =>
      old.spectrum != spectrum ||
      old.settings.minDb != settings.minDb ||
      old.settings.maxDb != settings.maxDb ||
      old.centerHz != centerHz ||
      old.sampleRateHz != sampleRateHz;
}

class _WaterfallPainter extends CustomPainter {
  final ui.Image? image;
  final WaterfallSettings settings;
  final int centerHz;
  final int sampleRateHz;

  _WaterfallPainter({
    required this.image,
    required this.settings,
    required this.centerHz,
    required this.sampleRateHz,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final specH = size.height * 0.38;
    final rect = Rect.fromLTWH(0, specH + 4, size.width, size.height - specH - 4);
    canvas.drawRect(rect, Paint()..color = const Color(0xff05050f));
    final img = image;
    if (img == null) return;
    canvas.drawImageRect(
      img,
      Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
      rect,
      Paint()..filterQuality = FilterQuality.low,
    );

    const vDivs = 6;
    final grid = Paint()
      ..color = const Color(0x50505060)
      ..strokeWidth = 0.5;
    for (int i = 0; i <= vDivs; i++) {
      final x = size.width * i / vDivs;
      canvas.drawLine(Offset(x, rect.top), Offset(x, rect.bottom), grid);
      final hz = centerHz - sampleRateHz / 2 + sampleRateHz * i / vDivs;
      final tp = TextPainter(
        text: TextSpan(
            text: '${(hz / 1e6).toStringAsFixed(3)}',
            style: const TextStyle(
                color: Color(0xdcc8c8c8),
                fontSize: 9,
                fontFamily: 'monospace')),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(x + 2, rect.bottom - 13));
    }
  }

  @override
  bool shouldRepaint(_WaterfallPainter old) =>
      old.image != image ||
      old.centerHz != centerHz ||
      old.sampleRateHz != sampleRateHz;
}

List<int> _buildLut(WaterfallColorScheme scheme) {
  return List<int>.generate(256, (i) {
    final t = i / 255.0;
    switch (scheme) {
      case WaterfallColorScheme.viridis:
        final r = (0.267 + 1.619 * t - 2.190 * t * t + 0.851 * t * t * t)
            .clamp(0.0, 1.0);
        final g = (0.004 + 1.363 * t - 0.554 * t * t - 0.340 * t * t * t)
            .clamp(0.0, 1.0);
        final b = (0.329 + 1.496 * t - 3.166 * t * t + 1.823 * t * t * t)
            .clamp(0.0, 1.0);
        return (_f(r) << 16) | (_f(g) << 8) | _f(b);
      case WaterfallColorScheme.turbo:
        final r = (0.139 + 4.189 * t - 8.540 * t * t + 5.106 * t * t * t)
            .clamp(0.0, 1.0);
        final g = (0.097 + 3.671 * t - 3.956 * t * t + 0.218 * t * t * t)
            .clamp(0.0, 1.0);
        final b = (0.453 + 3.107 * t - 8.010 * t * t + 5.293 * t * t * t)
            .clamp(0.0, 1.0);
        return (_f(r) << 16) | (_f(g) << 8) | _f(b);
      case WaterfallColorScheme.grayscale:
        final v = (t * 255).round();
        return (v << 16) | (v << 8) | v;
    }
  });
}

int _f(double v) => (v * 255).round().clamp(0, 255);
