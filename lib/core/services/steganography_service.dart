import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';

/// Steganography Service — Acoustic Stealth (Hydro-Acoustic Steganography)
///
/// Hides and recovers E2EE encrypted payloads within standard PCM WAV audio files.
/// Utilizes a Least Significant Bit (LSB) encoding algorithm over the audio data segment,
/// preserving audio fidelity while ensuring clean data extraction.
class SteganographyService {
  static const int wavHeaderSize = 44;
  static const String eomMarker = "##RIPPLE_STEG_EOM##"; // End of Message marker

  /// Generates cover WAV bytes representing pleasant rainfall noise.
  static Uint8List generateRainfallWav(int durationSeconds) {
    const sampleRate = 16000;
    final numSamples = sampleRate * durationSeconds;
    final dataSize = numSamples * 2;
    final fileSize = 36 + dataSize;
    final buffer = Uint8List(44 + dataSize);
    final view = ByteData.view(buffer.buffer);

    // RIFF header
    buffer[0] = 0x52; // R
    buffer[1] = 0x49; // I
    buffer[2] = 0x46; // F
    buffer[3] = 0x46; // F
    view.setUint32(4, fileSize, Endian.little);
    buffer[8] = 0x57; // W
    buffer[9] = 0x41; // A
    buffer[10] = 0x56; // V
    buffer[11] = 0x45; // E

    // fmt chunk
    buffer[12] = 0x66; // f
    buffer[13] = 0x6d; // m
    buffer[14] = 0x74; // t
    buffer[15] = 0x20; //  
    view.setUint32(16, 16, Endian.little); // Chunk size
    view.setUint16(20, 1, Endian.little);  // PCM format
    view.setUint16(22, 1, Endian.little);  // Mono
    view.setUint32(24, sampleRate, Endian.little); // Sample rate
    view.setUint32(28, sampleRate * 2, Endian.little); // Byte rate
    view.setUint16(32, 2, Endian.little);  // Block align
    view.setUint16(34, 16, Endian.little); // Bits per sample

    // data chunk
    buffer[36] = 0x64; // d
    buffer[37] = 0x61; // a
    buffer[38] = 0x74; // t
    buffer[39] = 0x61; // a
    view.setUint32(40, dataSize, Endian.little);

    // Generate pleasant white noise (sounds like rainfall)
    final random = Random();
    for (int i = 0; i < numSamples; i++) {
      // 16-bit sample range is -32768 to 32767
      // Keep amplitude around 3000 for a gentle, calming background hiss
      final sample = (random.nextDouble() * 6000 - 3000).toInt();
      view.setInt16(44 + (i * 2), sample, Endian.little);
    }

    return buffer;
  }

  /// Encodes a payload string into a PCM WAV audio byte array.
  /// Returns a new Uint8List representing the steganographic WAV file.
  static Future<Uint8List> encode({
    required Uint8List coverWavBytes,
    required String payload,
  }) async {
    return compute(_encodeTask, {
      'cover': coverWavBytes,
      'payload': payload,
    });
  }

  /// Decodes a payload string from a steganographic PCM WAV audio byte array.
  /// Returns the decrypted plaintext or null if no valid message is found.
  static Future<String?> decode({
    required Uint8List stegoWavBytes,
  }) async {
    return compute(_decodeTask, stegoWavBytes);
  }

  // ─── Worker Tasks (executed on background isolates) ─────────

  static Uint8List _encodeTask(Map<String, dynamic> args) {
    final Uint8List cover = args['cover'];
    final String payload = args['payload'];

    if (cover.length < wavHeaderSize) {
      throw Exception('Invalid cover WAV: file too small');
    }

    // Append End of Message marker to the payload
    final payloadWithMarker = payload + eomMarker;
    final List<int> payloadBytes = utf8.encode(payloadWithMarker);

    // Convert payload to a bit stream
    final List<int> bits = [];
    for (int byte in payloadBytes) {
      for (int i = 7; i >= 0; i--) {
        bits.add((byte >> i) & 1);
      }
    }

    final int availableSamples = (cover.length - wavHeaderSize) ~/ 2;
    if (bits.length > availableSamples) {
      throw Exception('Cover audio is too short to store this payload size.');
    }

    final Uint8List result = Uint8List.fromList(cover);
    final ByteData view = ByteData.view(result.buffer);

    for (int i = 0; i < bits.length; i++) {
      // Audio samples are 16-bit signed PCM (2 bytes per sample) starting at byte 44
      final int byteOffset = wavHeaderSize + (i * 2);
      
      // Read current sample
      int sample = view.getInt16(byteOffset, Endian.little);

      // Modify the LSB of the sample to hold the payload bit
      if (bits[i] == 1) {
        sample = sample | 1;
      } else {
        sample = sample & ~1;
      }

      // Write modified sample back
      view.setInt16(byteOffset, sample, Endian.little);
    }

    return result;
  }

  static String? _decodeTask(Uint8List stego) {
    if (stego.length < wavHeaderSize) return null;

    final ByteData view = ByteData.view(stego.buffer);
    final int samplesCount = (stego.length - wavHeaderSize) ~/ 2;

    final List<int> decodedBytes = [];
    int currentByte = 0;
    int bitCount = 0;

    for (int i = 0; i < samplesCount; i++) {
      final int byteOffset = wavHeaderSize + (i * 2);
      final int sample = view.getInt16(byteOffset, Endian.little);

      // Extract LSB
      final int bit = sample & 1;
      currentByte = (currentByte << 1) | bit;
      bitCount++;

      if (bitCount == 8) {
        decodedBytes.add(currentByte);
        currentByte = 0;
        bitCount = 0;

        // Check if we hit the End of Message marker to save performance
        if (decodedBytes.length >= eomMarker.length) {
          final String trailingString = utf8.decode(
            decodedBytes.sublist(decodedBytes.length - eomMarker.length),
            allowMalformed: true,
          );
          
          if (trailingString == eomMarker) {
            final String fullMessage = utf8.decode(
              decodedBytes.sublist(0, decodedBytes.length - eomMarker.length),
              allowMalformed: true,
            );
            return fullMessage;
          }
        }
      }
    }

    // Fallback if no marker is found but we read valid ASCII/UTF-8
    try {
      final decodedText = utf8.decode(decodedBytes, allowMalformed: true);
      if (decodedText.contains(eomMarker)) {
        return decodedText.split(eomMarker).first;
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}
