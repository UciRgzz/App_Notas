import 'package:flutter/material.dart';
import 'recordings_screen.dart';
import '../services/storage_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final StorageService _storageService = StorageService();
  int _recordingsCount = 0;

  @override
  void initState() {
    super.initState();
    _loadCount();
  }

  Future<void> _loadCount() async {
    final notes = await _storageService.loadNotes();
    setState(() => _recordingsCount = notes.length);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: const Text(
          'Notas de voz',
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.folder_open_outlined),
            onPressed: () {},
          ),
          TextButton(
            onPressed: () {},
            child: const Text(
              'Editar',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _item(context, Icons.graphic_eq, 'Todas las grabaciones', _recordingsCount),
            const SizedBox(height: 12),
            _item(context, Icons.delete_outline, 'Eliminadas', 0),
          ],
        ),
      ),
    );
  }

  Widget _item(BuildContext context, IconData icon, String title, int count) {
    return InkWell(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const RecordingsScreen()),
        );
        _loadCount();
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1C1C1E),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.blue),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
            ),
            if (count > 0)
              Text(
                '$count',
                style: const TextStyle(color: Colors.white54, fontSize: 16),
              ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right, color: Colors.white54),
          ],
        ),
      ),
    );
  }
}
