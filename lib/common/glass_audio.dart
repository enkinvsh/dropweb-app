import 'package:audioplayers/audioplayers.dart';

/// Minimal audio service for glass UI sounds.
///
/// Three sounds, pre-loaded as AudioPlayer pools:
/// - [tap] — light glass tap (tab switch, card press) — 80ms
/// - [click] — deeper glass click (connect button) — 120ms
/// - [ring] — resonant glass ring (VPN connected) — 250ms
class GlassAudio {
  GlassAudio._();
  static final instance = GlassAudio._();

  final _tap = AudioPlayer()..setPlayerMode(PlayerMode.lowLatency);
  final _click = AudioPlayer()..setPlayerMode(PlayerMode.lowLatency);
  final _ring = AudioPlayer()..setPlayerMode(PlayerMode.lowLatency);

  bool _ready = false;

  /// Call once at app startup.
  Future<void> init() async {
    if (_ready) return;
    // Set low volume — these are subtle UI accents, not alerts
    await _tap.setVolume(0.3);
    await _click.setVolume(0.4);
    await _ring.setVolume(0.35);
    await _tap.setSource(AssetSource('sounds/glass_tap.wav'));
    await _click.setSource(AssetSource('sounds/glass_click.wav'));
    await _ring.setSource(AssetSource('sounds/glass_ring.wav'));
    _ready = true;
  }

  /// Light glass tap — tab switch, card press.
  void tap() {
    if (!_ready) return;
    _tap.stop();
    _tap.resume();
  }

  /// Deeper glass click — connect/disconnect button.
  void click() {
    if (!_ready) return;
    _click.stop();
    _click.resume();
  }

  /// Resonant glass ring — VPN connected confirmation.
  void ring() {
    if (!_ready) return;
    _ring.stop();
    _ring.resume();
  }

  void dispose() {
    _tap.dispose();
    _click.dispose();
    _ring.dispose();
  }
}
