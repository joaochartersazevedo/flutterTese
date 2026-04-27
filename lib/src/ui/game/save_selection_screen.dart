import 'package:flutter/material.dart';

import '../../data/save_file_service.dart';
import '../../models/save_data.dart';

class SaveSelectionScreen extends StatefulWidget {
  const SaveSelectionScreen({
    super.key,
    required this.onSaveSelected,
  });

  final Future<void> Function(SaveData saveData) onSaveSelected;

  @override
  State<SaveSelectionScreen> createState() => _SaveSelectionScreenState();
}

class _SaveSelectionScreenState extends State<SaveSelectionScreen> {
  late Future<List<SaveData>> _savesFuture;
  final _newSaveController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _savesFuture = SaveFileService.listSaves();
  }

  @override
  void dispose() {
    _newSaveController.dispose();
    super.dispose();
  }

  Future<void> _createNewSave() async {
    final name = _newSaveController.text.trim();
    if (name.isEmpty) {
      _showError('Save name cannot be empty');
      return;
    }

    if (await SaveFileService.saveExists(name)) {
      _showError('Save "$name" already exists');
      return;
    }

    final newSave = SaveData(
      saveName: name,
      timestamp: DateTime.now(),
      currentAreaId: 1,
      elapsedMinutes: 0,
      minutesSincePopulate: 0,
      log: [],
      gameFlags: {},
      characterPositions: {},
    );

    await SaveFileService.saveSave(newSave);
    if (mounted) {
      _newSaveController.clear();
      setState(() {});
      _savesFuture = SaveFileService.listSaves();
    }
  }

  Future<void> _loadExistingSave(SaveData save) async {
    await widget.onSaveSelected(save);
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Save'),
        centerTitle: true,
      ),
      body: FutureBuilder<List<SaveData>>(
        future: _savesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text('Error loading saves: ${snapshot.error}'),
            );
          }

          final saves = snapshot.data ?? [];

          return Column(
            children: [
              Expanded(
                child: saves.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.save_alt,
                                size: 64, color: Colors.grey),
                            const SizedBox(height: 16),
                            const Text('No saves yet'),
                            const SizedBox(height: 8),
                            const Text('Create a new save to get started',
                                style: TextStyle(color: Colors.grey)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: saves.length,
                        itemBuilder: (context, i) {
                          final save = saves[i];
                          return Card(
                            child: ListTile(
                              title: Text(save.displayName),
                              subtitle: Text(save.displayTime),
                              trailing: const Icon(Icons.play_arrow),
                              onTap: () => _loadExistingSave(save),
                            ),
                          );
                        },
                      ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: _newSaveController,
                      decoration: InputDecoration(
                        hintText: 'New save name...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onSubmitted: (_) => _createNewSave(),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                      onPressed: _createNewSave,
                      icon: const Icon(Icons.add),
                      label: const Text('Create New Save'),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
