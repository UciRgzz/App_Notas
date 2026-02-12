import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../models/audio_note.dart';

class StorageService {
  static const _fileName = 'audio_notes.json';

  Future<File> _getFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_fileName');
  }

  Future<List<AudioNote>> loadNotes() async {
    try {
      final file = await _getFile();
      if (!await file.exists()) return [];
      final content = await file.readAsString();
      final List<dynamic> jsonList = json.decode(content);
      return jsonList.map((e) => AudioNote.fromJson(e)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveNotes(List<AudioNote> notes) async {
    final file = await _getFile();
    final jsonList = notes.map((e) => e.toJson()).toList();
    await file.writeAsString(json.encode(jsonList));
  }
}
