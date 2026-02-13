import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:audioplayers/audioplayers.dart';

import '../services/audio_service.dart';
import '../services/location_service.dart';
import '../services/storage_service.dart';
import '../models/audio_note.dart';

class RecordingsScreen extends StatefulWidget {
  const RecordingsScreen({super.key});

  @override
  State<RecordingsScreen> createState() => _RecordingsScreenState();
}

class _RecordingsScreenState extends State<RecordingsScreen> {
  final AudioService _audioService = AudioService();
  final LocationService _locationService = LocationService();
  final StorageService _storageService = StorageService();

  final List<AudioNote> _notes = [];

  // Grabación
  bool _isRecording = false;
  int _recordSeconds = 0;
  Timer? _recordTimer;
  String _currentTitle = '';

  // Waveform animado
  Timer? _waveTimer;
  final List<double> _waveformBars = [];

  // Reproducción
  int? _expandedIndex;
  bool _isPlaying = false;
  Duration _currentPosition = Duration.zero;
  Duration _totalDuration = Duration.zero;
  StreamSubscription? _positionSub;
  StreamSubscription? _durationSub;
  StreamSubscription? _stateSub;

  @override
  void initState() {
    super.initState();
    _loadNotes();
    _positionSub = _audioService.onPositionChanged.listen((pos) {
      setState(() => _currentPosition = pos);
    });
    _durationSub = _audioService.onDurationChanged.listen((dur) {
      setState(() => _totalDuration = dur);
    });
    _stateSub = _audioService.onPlayerStateChanged.listen((state) {
      setState(() => _isPlaying = state == PlayerState.playing);
      if (state == PlayerState.completed) {
        setState(() {
          _isPlaying = false;
          _currentPosition = Duration.zero;
        });
      }
    });
  }

  Future<void> _loadNotes() async {
    final saved = await _storageService.loadNotes();
    setState(() => _notes.addAll(saved));
  }

  Future<void> _saveNotes() async {
    await _storageService.saveNotes(_notes);
  }

  @override
  void dispose() {
    _recordTimer?.cancel();
    _waveTimer?.cancel();
    _positionSub?.cancel();
    _durationSub?.cancel();
    _stateSub?.cancel();
    _audioService.dispose();
    super.dispose();
  }

  Future<String> _newPath() async {
    final dir = await getApplicationDocumentsDirectory();
    return '${dir.path}/audio_${DateTime.now().millisecondsSinceEpoch}.m4a';
  }

  void _startRecordTimer() {
    _recordSeconds = 0;
    _recordTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _recordSeconds++);
    });
  }

  void _stopRecordTimer() {
    _recordTimer?.cancel();
    _recordTimer = null;
  }

  void _startWaveform() {
    _waveformBars.clear();
    _waveTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      setState(() {
        _waveformBars.add(Random().nextDouble());
      });
    });
  }

  void _stopWaveform() {
    _waveTimer?.cancel();
    _waveTimer = null;
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  String _formatRecordTime(int totalSeconds) {
    final h = totalSeconds ~/ 3600;
    final m = (totalSeconds % 3600) ~/ 60;
    final s = totalSeconds % 60;
    final mm = m.toString().padLeft(2, '0');
    final ss = s.toString().padLeft(2, '0');
    if (h > 0) {
      return '$h:$mm:$ss';
    }
    return '00:$mm.$ss';
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final noteDay = DateTime(date.year, date.month, date.day);

    if (noteDay == today) {
      var hour = date.hour % 12;
      if (hour == 0) hour = 12;
      final ampm = date.hour >= 12 ? 'p.m.' : 'a.m.';
      final min = date.minute.toString().padLeft(2, '0');
      return '$hour:$min $ampm';
    }

    final months = [
      '', 'ene', 'feb', 'mar', 'abr', 'may', 'jun',
      'jul', 'ago', 'sep', 'oct', 'nov', 'dic',
    ];
    return '${date.day} ${months[date.month]} ${date.year}';
  }

  Future<void> _recordButton() async {
    if (_isRecording) {
      final path = await _audioService.stopRecording();
      _stopRecordTimer();
      _stopWaveform();

      if (path != null) {
        final duration = Duration(seconds: _recordSeconds);
        setState(() {
          _notes.insert(
            0,
            AudioNote(
              path: path,
              date: DateTime.now(),
              title: _currentTitle,
              duration: duration,
            ),
          );
          _isRecording = false;
          _expandedIndex = 0;
        });
        _saveNotes();
      } else {
        setState(() => _isRecording = false);
      }
    } else {
      try {
        final path = await _newPath();
        _currentTitle = await _locationService.getLocationName();
        await _audioService.startRecording(path);
        _startRecordTimer();
        _startWaveform();
        setState(() => _isRecording = true);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al iniciar grabación: $e')),
          );
        }
      }
    }
  }

  Future<void> _playNote(int index) async {
    final note = _notes[index];
    if (_isPlaying && _expandedIndex == index) {
      await _audioService.pause();
    } else if (!_isPlaying && _expandedIndex == index && _currentPosition > Duration.zero) {
      await _audioService.resume();
    } else {
      await _audioService.stop();
      setState(() {
        _expandedIndex = index;
        _currentPosition = Duration.zero;
        _totalDuration = note.duration;
      });
      await _audioService.play(note.path);
    }
  }

  void _seekRelative(int seconds) {
    final newPos = _currentPosition + Duration(seconds: seconds);
    final clamped = Duration(
      milliseconds: newPos.inMilliseconds.clamp(0, _totalDuration.inMilliseconds),
    );
    _audioService.seek(clamped);
  }

  Future<void> _deleteNote(int index) async {
    if (_expandedIndex == index) {
      await _audioService.stop();
    }
    setState(() {
      _notes.removeAt(index);
      if (_expandedIndex == index) {
        _expandedIndex = null;
        _isPlaying = false;
        _currentPosition = Duration.zero;
      } else if (_expandedIndex != null && _expandedIndex! > index) {
        _expandedIndex = _expandedIndex! - 1;
      }
    });
    _saveNotes();
  }

  void _renameNote(int index) {
    final controller = TextEditingController(text: _notes[index].title);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2C2C2E),
        title: const Text('Renombrar', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.white38),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.blue),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              setState(() => _notes[index].title = controller.text);
              _saveNotes();
              Navigator.pop(ctx);
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  void _showOptionsMenu(int index) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1C1C1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white38,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            _menuItem(Icons.ios_share, 'Compartir', () => Navigator.pop(ctx)),
            const Divider(color: Colors.white12, height: 1),
            _menuItem(Icons.edit, 'Renombrar', () {
              Navigator.pop(ctx);
              _renameNote(index);
            }),
            _menuItem(Icons.graphic_eq, 'Editar grabacion', () => Navigator.pop(ctx)),
            _menuItem(Icons.tune, 'Opciones', () => Navigator.pop(ctx)),
            const Divider(color: Colors.white12, height: 1),
            _menuItem(Icons.favorite_border, 'Marcar como favorita', () => Navigator.pop(ctx)),
            _menuItem(Icons.copy, 'Duplicar', () {
              Navigator.pop(ctx);
              setState(() {
                final note = _notes[index];
                _notes.insert(index + 1, AudioNote(
                  path: note.path,
                  date: DateTime.now(),
                  title: '${note.title} (copia)',
                  duration: note.duration,
                ));
              });
              _saveNotes();
            }),
            _menuItem(Icons.folder_outlined, 'Mover', () => Navigator.pop(ctx)),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _menuItem(IconData icon, String label, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: Colors.white),
      title: Text(label, style: const TextStyle(color: Colors.white, fontSize: 16)),
      onTap: onTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // Barra superior: flecha, búsqueda, seleccionar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios, color: Colors.blue),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.search, color: Colors.blue),
                    onPressed: () {},
                  ),
                  TextButton(
                    onPressed: () {},
                    child: const Text(
                      'Seleccionar',
                      style: TextStyle(color: Colors.blue, fontSize: 16),
                    ),
                  ),
                ],
              ),
            ),

            // Título grande estilo iOS
            const Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'Todas las grabaciones',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Divider(color: Colors.white12, height: 1),

            // Lista de grabaciones
            Expanded(
              child: _notes.isEmpty && !_isRecording
                  ? const Center(
                      child: Text(
                        'No hay grabaciones',
                        style: TextStyle(color: Colors.white38, fontSize: 16),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _notes.length,
                      itemBuilder: (_, i) => _noteItem(i),
                    ),
            ),

            // Panel inferior: grabación o botón
            _isRecording ? _recordingPanel() : _recordButtonWidget(),
          ],
        ),
      ),
    );
  }

  // --- Cada nota en la lista ---
  Widget _noteItem(int index) {
    final note = _notes[index];
    final isExpanded = _expandedIndex == index;

    return Column(
      children: [
        InkWell(
          onTap: () {
            if (isExpanded) {
              _audioService.stop();
              setState(() {
                _expandedIndex = null;
                _isPlaying = false;
                _currentPosition = Duration.zero;
              });
            } else {
              setState(() {
                _expandedIndex = index;
                _currentPosition = Duration.zero;
                _totalDuration = note.duration;
              });
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        note.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            _formatDate(note.date),
                            style: const TextStyle(color: Colors.white54, fontSize: 13),
                          ),
                          const SizedBox(width: 16),
                          Text(
                            _formatDuration(note.duration),
                            style: const TextStyle(color: Colors.white54, fontSize: 13),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => _showOptionsMenu(index),
                  child: const Icon(Icons.more_horiz, color: Colors.blue, size: 28),
                ),
              ],
            ),
          ),
        ),

        // Panel expandido de reproducción
        if (isExpanded) _playerPanel(index),

        const Divider(color: Colors.white12, height: 1, indent: 16),
      ],
    );
  }

  // --- Panel de reproducción expandido ---
  Widget _playerPanel(int index) {
    final note = _notes[index];
    final total = _totalDuration.inMilliseconds > 0
        ? _totalDuration
        : note.duration;
    final progress = total.inMilliseconds > 0
        ? _currentPosition.inMilliseconds / total.inMilliseconds
        : 0.0;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Column(
        children: [
          // Barra de progreso
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: Colors.white,
              inactiveTrackColor: Colors.white24,
              thumbColor: Colors.white,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              trackHeight: 3,
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
            ),
            child: Slider(
              value: progress.clamp(0.0, 1.0),
              onChanged: (val) {
                final newPos = Duration(
                  milliseconds: (val * total.inMilliseconds).round(),
                );
                _audioService.seek(newPos);
              },
            ),
          ),

          // Tiempos
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _formatDuration(_currentPosition),
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
                Text(
                  '-${_formatDuration(total - _currentPosition)}',
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Controles
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Waveform icon (decorativo)
              const Icon(Icons.graphic_eq, color: Colors.blue, size: 28),

              // Retroceder 15s
              GestureDetector(
                onTap: () => _seekRelative(-15),
                child: const Icon(Icons.replay_10, color: Colors.white, size: 32),
              ),

              // Play / Pause
              GestureDetector(
                onTap: () => _playNote(index),
                child: Container(
                  width: 52,
                  height: 52,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _isPlaying ? Icons.pause : Icons.play_arrow,
                    color: Colors.white,
                    size: 40,
                  ),
                ),
              ),

              // Adelantar 15s
              GestureDetector(
                onTap: () => _seekRelative(15),
                child: const Icon(Icons.forward_10, color: Colors.white, size: 32),
              ),

              // Eliminar
              GestureDetector(
                onTap: () => _deleteNote(index),
                child: const Icon(Icons.delete_outline, color: Colors.blue, size: 28),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- Panel de grabación (parte inferior) ---
  Widget _recordingPanel() {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1C1C1E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white38,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),

          // Título (ubicación)
          Text(
            _currentTitle,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),

          // Tiempo
          Text(
            _formatRecordTime(_recordSeconds),
            style: const TextStyle(color: Colors.white54, fontSize: 14),
          ),
          const SizedBox(height: 16),

          // Waveform animado con líneas rojas
          SizedBox(
            height: 50,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final maxBars = (constraints.maxWidth / 4).floor();
                final bars = _waveformBars.length > maxBars
                    ? _waveformBars.sublist(_waveformBars.length - maxBars)
                    : _waveformBars;

                return Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: List.generate(bars.length, (i) {
                    final height = 4.0 + bars[i] * 40.0;
                    return Container(
                      width: 2,
                      height: height,
                      margin: const EdgeInsets.symmetric(horizontal: 1),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(1),
                      ),
                    );
                  }),
                );
              },
            ),
          ),

          const SizedBox(height: 20),

          // Botón detener (cuadrado rojo dentro de círculo)
          GestureDetector(
            onTap: _recordButton,
            child: Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.red, width: 3),
              ),
              child: Center(
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- Botón de grabar (cuando NO está grabando) ---
  Widget _recordButtonWidget() {
    return Container(
      padding: const EdgeInsets.only(bottom: 32, top: 16),
      child: GestureDetector(
        onTap: _recordButton,
        child: Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white24, width: 3),
          ),
          child: Center(
            child: Container(
              width: 52,
              height: 52,
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
