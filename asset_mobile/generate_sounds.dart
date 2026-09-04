import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

void main() async {
  final dir = Directory('assets/sounds');
  if (!await dir.exists()) {
    await dir.create(recursive: true);
  }

  // Generate Success Sound (High Pitch Beep)
  await File('assets/sounds/success.wav').writeAsBytes(generateTone(
    frequency: 1000.0,
    durationMs: 150,
    sampleRate: 44100,
  ));
  print('Generated success.wav');

  // Generate Error Sound (Low Pitch Sawtooth/Square)
  await File('assets/sounds/error.wav').writeAsBytes(generateTone(
    frequency: 150.0,
    durationMs: 400,
    sampleRate: 44100,
    waveType: 'square',
  ));
  print('Generated error.wav');
  
  // Generate Duplicate Sound (Two Beeps)
  await File('assets/sounds/duplicate.wav').writeAsBytes(generateDuplicateTone(
    frequency: 800.0,
    durationMs: 100,
    gapMs: 100,
    sampleRate: 44100,
  ));
  print('Generated duplicate.wav');
}

Uint8List generateTone({
  required double frequency,
  required int durationMs,
  required int sampleRate,
  String waveType = 'sine',
}) {
  final numSamples = (durationMs / 1000 * sampleRate).toInt();
  final dataSize = numSamples * 2; // 16-bit
  final totalSize = 36 + dataSize;

  final ByteData buffer = ByteData(totalSize + 8);

  // RIFF Header
  writeString(buffer, 0, 'RIFF');
  buffer.setUint32(4, totalSize, Endian.little);
  writeString(buffer, 8, 'WAVE');

  // fmt Chunk
  writeString(buffer, 12, 'fmt ');
  buffer.setUint32(16, 16, Endian.little); // chunk size
  buffer.setUint16(20, 1, Endian.little); // PCM
  buffer.setUint16(22, 1, Endian.little); // 1 Channel
  buffer.setUint32(24, sampleRate, Endian.little);
  buffer.setUint32(28, sampleRate * 2, Endian.little); // Byte rate
  buffer.setUint16(32, 2, Endian.little); // Block align
  buffer.setUint16(34, 16, Endian.little); // Bits per sample

  // data Chunk
  writeString(buffer, 36, 'data');
  buffer.setUint32(40, dataSize, Endian.little);

  for (int i = 0; i < numSamples; i++) {
    double t = i / sampleRate;
    double sampleValue = 0.0;

    if (waveType == 'sine') {
      sampleValue = sin(2 * pi * frequency * t);
    } else if (waveType == 'square') {
      sampleValue = (sin(2 * pi * frequency * t) > 0) ? 0.8 : -0.8;
    }

    // Convert to 16-bit integer
    int sampleInt = (sampleValue * 32767).toInt();
    buffer.setInt16(44 + i * 2, sampleInt, Endian.little);
  }

  return buffer.buffer.asUint8List();
}

Uint8List generateDuplicateTone({
  required double frequency,
  required int durationMs,
  required int gapMs,
  required int sampleRate,
}) {
  final beepSamples = (durationMs / 1000 * sampleRate).toInt();
  final gapSamples = (gapMs / 1000 * sampleRate).toInt();
  final numSamples = (beepSamples * 2) + gapSamples; // Beep + Gap + Beep
  
  final dataSize = numSamples * 2; // 16-bit
  final totalSize = 36 + dataSize;

  final ByteData buffer = ByteData(totalSize + 8);

  // Headers
  writeString(buffer, 0, 'RIFF');
  buffer.setUint32(4, totalSize, Endian.little);
  writeString(buffer, 8, 'WAVE');
  writeString(buffer, 12, 'fmt ');
  buffer.setUint32(16, 16, Endian.little);
  buffer.setUint16(20, 1, Endian.little);
  buffer.setUint16(22, 1, Endian.little);
  buffer.setUint32(24, sampleRate, Endian.little);
  buffer.setUint32(28, sampleRate * 2, Endian.little);
  buffer.setUint16(32, 2, Endian.little);
  buffer.setUint16(34, 16, Endian.little);
  writeString(buffer, 36, 'data');
  buffer.setUint32(40, dataSize, Endian.little);

  int offset = 44;
  
  // First Beep
  for (int i = 0; i < beepSamples; i++) {
    double t = i / sampleRate;
    int sampleInt = (sin(2 * pi * frequency * t) * 32767).toInt();
    buffer.setInt16(offset, sampleInt, Endian.little);
    offset += 2;
  }
  
  // Gap (Silence)
  for (int i = 0; i < gapSamples; i++) {
    buffer.setInt16(offset, 0, Endian.little);
    offset += 2;
  }
  
  // Second Beep
  for (int i = 0; i < beepSamples; i++) {
    double t = i / sampleRate;
    int sampleInt = (sin(2 * pi * frequency * t) * 32767).toInt();
    buffer.setInt16(offset, sampleInt, Endian.little);
    offset += 2;
  }

  return buffer.buffer.asUint8List();
}

void writeString(ByteData buffer, int offset, String s) {
  for (int i = 0; i < s.length; i++) {
    buffer.setUint8(offset + i, s.codeUnitAt(i));
  }
}
