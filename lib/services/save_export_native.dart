import 'dart:io';
import 'dart:typed_data';

Future<void> finishExport(String path, Uint8List bytes) async {
  // Mobile saveFile writes the selected document; desktop returns a destination.
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    await File(path).writeAsBytes(bytes, flush: true);
  }
}
