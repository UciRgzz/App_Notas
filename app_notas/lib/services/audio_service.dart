import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';

class AudioService {
  final AudioRecorder _recorder = AudioRecorder();
  final AudioPlayer _player = AudioPlayer();

  // --- Grabación ---
  Future<void> startRecording(String path) async {
    final hasPermission = await _recorder.hasPermission();
    if (hasPermission) {
      await _recorder.start(const RecordConfig(), path: path);
    }
  }

  Future<String?> stopRecording() async {
    return await _recorder.stop();
  }

  // --- Reproducción ---
  Future<void> play(String path) async {
    await _player.play(DeviceFileSource(path));
  }

  Future<void> pause() async {
    await _player.pause();
  }

  Future<void> resume() async {
    await _player.resume();
  }

  Future<void> stop() async {
    await _player.stop();
  }

  Future<void> seek(Duration position) async {
    await _player.seek(position);
  }

  Stream<Duration> get onPositionChanged => _player.onPositionChanged;

  Stream<Duration> get onDurationChanged => _player.onDurationChanged;

  Stream<PlayerState> get onPlayerStateChanged => _player.onPlayerStateChanged;

  void dispose() {
    _player.dispose();
    _recorder.dispose();
  }
}
