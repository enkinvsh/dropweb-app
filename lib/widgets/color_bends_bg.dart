import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// Animated color-bends background driven by a GLSL fragment shader.
///
/// Port of reactbits.dev/backgrounds/color-bends for Flutter.
///
/// **Impeller note (2026-04-08):** the Dropweb manifest has
/// `io.flutter.embedding.android.EnableImpeller="true"` (set in the 2025-09-11
/// "update mihomo core" commit by pluralplay). Impeller's GLES backend
/// silently fails to load custom FragmentProgram shaders — the loader throws,
/// [_shaderFailed] is set, [build] returns [SizedBox.shrink]. App does not
/// crash; user sees the static container background underneath.
///
/// Performance: the [Ticker] is created **only after** the shader loads
/// successfully. If the shader fails (e.g. Impeller backend), no Ticker
/// runs → zero per-frame cost. When active, the [ValueNotifier] drives
/// repaint via `super(repaint:)` — zero widget rebuilds. Throttled to
/// [targetFps] (default 15).
class ColorBendsBg extends StatefulWidget {
  const ColorBendsBg({
    super.key,
    this.speed = 0.2,
    this.rotation = 45,
    this.scale = 1.0,
    this.frequency = 1.0,
    this.warpStrength = 1.0,
    this.noise = 0.05,
    this.opacity = 1.0,
    this.targetFps = 15,
  });

  final double speed;
  final double rotation;
  final double scale;
  final double frequency;
  final double warpStrength;
  final double noise;
  final double opacity;
  final int targetFps;

  @override
  State<ColorBendsBg> createState() => _ColorBendsBgState();
}

class _ColorBendsBgState extends State<ColorBendsBg>
    with SingleTickerProviderStateMixin {
  ui.FragmentProgram? _program;
  bool _shaderFailed = false;
  // Created only after the shader successfully loads. If the shader fails
  // (e.g. Impeller backend), this stays null and no per-frame work runs.
  Ticker? _ticker;
  final _timeNotifier = ValueNotifier<double>(0);
  double _time = 0;
  Duration _lastTick = Duration.zero;
  int _frameSkip = 0;

  @override
  void initState() {
    super.initState();
    _loadShader();
  }

  Future<void> _loadShader() async {
    try {
      final program =
          await ui.FragmentProgram.fromAsset('shaders/color_bends.frag');
      if (!mounted) return;
      setState(() => _program = program);
      // Shader loaded — start the animation ticker.
      _ticker = createTicker(_onTick)..start();
    } catch (e, st) {
      FlutterError.reportError(FlutterErrorDetails(
          exception: e, stack: st, library: 'ColorBendsBg'));
      if (mounted) setState(() => _shaderFailed = true);
    }
  }

  void _onTick(Duration elapsed) {
    if (_lastTick == Duration.zero) {
      _lastTick = elapsed;
      return;
    }
    _time += (elapsed - _lastTick).inMicroseconds / 1e6;
    _lastTick = elapsed;

    if (_program == null) return;

    _frameSkip++;
    final skip = widget.targetFps > 0 ? (60 ~/ widget.targetFps) : 1;
    if (_frameSkip < skip) return;
    _frameSkip = 0;

    _timeNotifier.value = _time;
  }

  @override
  void dispose() {
    _ticker?.dispose();
    _timeNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (Theme.of(context).brightness == Brightness.light) {
      return const SizedBox.shrink();
    }
    if (_shaderFailed || _program == null) return const SizedBox.shrink();

    return RepaintBoundary(
      child: CustomPaint(
        painter: _ColorBendsPainter(
          program: _program!,
          timeNotifier: _timeNotifier,
          speed: widget.speed,
          rotation: widget.rotation,
          scale: widget.scale,
          frequency: widget.frequency,
          warpStrength: widget.warpStrength,
          noise: widget.noise,
          opacity: widget.opacity,
        ),
      ),
    );
  }
}

class _ColorBendsPainter extends CustomPainter {
  _ColorBendsPainter({
    required this.program,
    required ValueNotifier<double> timeNotifier,
    required this.speed,
    required this.rotation,
    required this.scale,
    required this.frequency,
    required this.warpStrength,
    required this.noise,
    required this.opacity,
  })  : _timeNotifier = timeNotifier,
        _rotCos = math.cos(rotation * math.pi / 180),
        _rotSin = math.sin(rotation * math.pi / 180),
        super(repaint: timeNotifier);

  final ui.FragmentProgram program;
  final ValueNotifier<double> _timeNotifier;
  final double speed, rotation, scale, frequency, warpStrength, noise, opacity;
  final double _rotCos, _rotSin;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    final shader = program.fragmentShader()
      ..setFloat(0, size.width)
      ..setFloat(1, size.height)
      ..setFloat(2, _timeNotifier.value)
      ..setFloat(3, speed)
      ..setFloat(4, _rotCos)
      ..setFloat(5, _rotSin)
      ..setFloat(6, scale)
      ..setFloat(7, frequency)
      ..setFloat(8, warpStrength)
      ..setFloat(9, noise);

    final paint = Paint()
      ..shader = shader
      ..blendMode = BlendMode.screen;

    if (opacity < 1.0) {
      paint.color = Color.fromRGBO(255, 255, 255, opacity);
    }

    canvas.drawRect(Offset.zero & size, paint);
  }

  @override
  bool shouldRepaint(_ColorBendsPainter old) =>
      old.speed != speed ||
      old.rotation != rotation ||
      old.scale != scale ||
      old.frequency != frequency ||
      old.warpStrength != warpStrength ||
      old.noise != noise ||
      old.opacity != opacity;
}
