import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';

List<int> createPng(int size) {
  // IHDR
  final ihdr = ByteData(13);
  ihdr.setUint32(0, size);
  ihdr.setUint32(4, size);
  ihdr.setUint8(8, 8);  // bit depth
  ihdr.setUint8(9, 2);  // color type RGB
  ihdr.setUint8(10, 0);
  ihdr.setUint8(11, 0);
  ihdr.setUint8(12, 0);

  // Raw image data
  final raw = <int>[];
  final half = size ~/ 2;
  final r = (half - 2) * (half - 2);
  for (var y = 0; y < size; y++) {
    raw.add(0); // filter byte
    for (var x = 0; x < size; x++) {
      final dx = x - half, dy = y - half;
      if (dx * dx + dy * dy <= r) {
        raw.addAll([76, 175, 80]); // green
      } else {
        raw.addAll([255, 255, 255]); // white
      }
    }
  }

  final compressed = zlib.encode(raw);

  List<int> chunk(List<int> name, List<int> data) {
    final len = ByteData(4)..setUint32(0, data.length);
    final crcData = [...name, ...data];
    final crc = ByteData(4)..setUint32(0, _crc32(crcData));
    return [...len.buffer.asUint8List(), ...name, ...data, ...crc.buffer.asUint8List()];
  }

  return [
    0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, // PNG signature
    ...chunk([73,72,68,82], ihdr.buffer.asUint8List().toList()),
    ...chunk([73,68,65,84], compressed),
    ...chunk([73,69,78,68], []),
  ];
}

int _crc32(List<int> data) {
  var crc = 0xFFFFFFFF;
  for (final b in data) {
    crc ^= b;
    for (var i = 0; i < 8; i++) {
      crc = (crc & 1) != 0 ? (crc >> 1) ^ 0xEDB88320 : crc >> 1;
    }
  }
  return (~crc) & 0xFFFFFFFF;
}

void main() {
  final base = 'android/app/src/main/res';
  final sizes = {'mipmap-mdpi': 48, 'mipmap-hdpi': 72, 'mipmap-xhdpi': 96, 'mipmap-xxhdpi': 144, 'mipmap-xxxhdpi': 192};
  for (final e in sizes.entries) {
    File('$base/${e.key}/ic_launcher.png').writeAsBytesSync(createPng(e.value));
    print('Created ${e.key}/ic_launcher.png');
  }
}
