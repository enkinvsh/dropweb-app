/// Generates glass tap/click WAV files for Dropweb UI.
/// Run: dart run tool/gen_glass_sounds.dart
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

void main() {
  final dir = 'assets/sounds';
  Directory(dir).createSync(recursive: true);

  // Glass tap — light, quick (tab switch, card tap)
  _writeWav(
      '$dir/glass_tap.wav',
      _synth(
        duration: 0.08,
        freqs: [3200, 5400, 7800],
        amps: [1.0, 0.4, 0.15],
        decay: 40,
      ));

  // Glass click — slightly deeper (connect button)
  _writeWav(
      '$dir/glass_click.wav',
      _synth(
        duration: 0.12,
        freqs: [2200, 3800, 6000],
        amps: [1.0, 0.5, 0.2],
        decay: 30,
      ));

  // Glass ring — resonant, longer (connect success)
  _writeWav(
      '$dir/glass_ring.wav',
      _synth(
        duration: 0.25,
        freqs: [1800, 2700, 4500, 6300],
        amps: [0.6, 1.0, 0.4, 0.15],
        decay: 15,
      ));

  print('Generated 3 glass sounds in $dir/');
}

/// Synthesize glass-like sound: sum of sine waves with exponential decay.
List<double> _synth({
  required double duration,
  required List<double> freqs,
  required List<double> amps,
  required double decay,
  int sampleRate = 44100,
}) {
  final n = (sampleRate * duration).toInt();
  final samples = List.filled(n, 0.0);
  for (var i = 0; i < n; i++) {
    final t = i / sampleRate;
    final env = exp(-decay * t);
    var s = 0.0;
    for (var j = 0; j < freqs.length; j++) {
      s += amps[j] * sin(2 * pi * freqs[j] * t);
    }
    samples[i] = s * env * 0.7; // master volume
  }
  return samples;
}

/// Write 16-bit mono PCM WAV.
void _writeWav(String path, List<double> samples) {
  final n = samples.length;
  const sampleRate = 44100;
  const bitsPerSample = 16;
  const numChannels = 1;
  final byteRate = sampleRate * numChannels * bitsPerSample ~/ 8;
  final blockAlign = numChannels * bitsPerSample ~/ 8;
  final dataSize = n * blockAlign;
  final fileSize = 36 + dataSize;

  final buf = ByteData(44 + dataSize);
  var o = 0;

  // RIFF header
  buf.setUint8(o++, 0x52);
  buf.setUint8(o++, 0x49);
  buf.setUint8(o++, 0x46);
  buf.setUint8(o++, 0x46); // "RIFF"
  buf.setUint32(o, fileSize, Endian.little);
  o += 4;
  buf.setUint8(o++, 0x57);
  buf.setUint8(o++, 0x41);
  buf.setUint8(o++, 0x56);
  buf.setUint8(o++, 0x45); // "WAVE"

  // fmt chunk
  buf.setUint8(o++, 0x66);
  buf.setUint8(o++, 0x6D);
  buf.setUint8(o++, 0x74);
  buf.setUint8(o++, 0x20); // "fmt "
  buf.setUint32(o, 16, Endian.little);
  o += 4;
  buf.setUint16(o, 1, Endian.little);
  o += 2; // PCM
  buf.setUint16(o, numChannels, Endian.little);
  o += 2;
  buf.setUint32(o, sampleRate, Endian.little);
  o += 4;
  buf.setUint32(o, byteRate, Endian.little);
  o += 4;
  buf.setUint16(o, blockAlign, Endian.little);
  o += 2;
  buf.setUint16(o, bitsPerSample, Endian.little);
  o += 2;

  // data chunk
  buf.setUint8(o++, 0x64);
  buf.setUint8(o++, 0x61);
  buf.setUint8(o++, 0x74);
  buf.setUint8(o++, 0x61); // "data"
  buf.setUint32(o, dataSize, Endian.little);
  o += 4;

  for (final s in samples) {
    final clamped = s.clamp(-1.0, 1.0);
    final i16 = (clamped * 32767).toInt().clamp(-32768, 32767);
    buf.setInt16(o, i16, Endian.little);
    o += 2;
  }

  File(path).writeAsBytesSync(buf.buffer.asUint8List());
}
