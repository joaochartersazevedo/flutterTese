import 'package:flutter/foundation.dart';

import 'app_preferences.dart';

class ChecklistItem {
  const ChecklistItem(this.id, this.label, this.category);
  final String id;
  final String label;
  final String category;
}

/// Tracks progress through the manual QA checklist.
///
/// Enabled via Settings ("Modo de teste"). Items are marked done by calling
/// [mark] from the action they represent; progress persists across restarts.
class TestingChecklist extends ChangeNotifier {
  TestingChecklist._() : _done = AppPreferences.testingChecklistProgress;

  static final TestingChecklist instance = TestingChecklist._();

  static const List<ChecklistItem> items = [
    // Editor
    ChecklistItem('create_area', 'Criar uma área', 'Editor'),
    ChecklistItem('edit_area', 'Editar uma área', 'Editor'),
    ChecklistItem('set_starting_area', 'Definir a área inicial', 'Editor'),
    ChecklistItem('create_connection', 'Criar uma ligação entre áreas', 'Editor'),
    ChecklistItem('create_character', 'Criar uma personagem', 'Editor'),
    ChecklistItem('edit_character', 'Editar uma personagem', 'Editor'),
    ChecklistItem('set_relationship', 'Definir uma relação entre personagens', 'Editor'),
    ChecklistItem('create_gamestate', 'Criar uma state flag', 'Editor'),
    ChecklistItem('create_dialogue', 'Criar um diálogo', 'Editor'),
    ChecklistItem('edit_dialogue', 'Editar um diálogo', 'Editor'),
    ChecklistItem('ai_generate_dialogue', 'Gerar uma linha de diálogo com IA', 'Editor'),
    ChecklistItem('create_dialogue_group', 'Criar um grupo de diálogos', 'Editor'),
    ChecklistItem('create_event', 'Criar um evento', 'Editor'),
    ChecklistItem('edit_event', 'Editar um evento', 'Editor'),
    ChecklistItem('delete_entity', 'Eliminar uma entidade (área/personagem/diálogo/evento)', 'Editor'),
    ChecklistItem('save_world', 'Guardar o mundo', 'Editor'),
    // Jogo
    ChecklistItem('select_save', 'Escolher um save', 'Jogo'),
    ChecklistItem('play_game', 'Lançar o jogo (Play)', 'Jogo'),
    ChecklistItem('travel_connection', 'Viajar entre áreas', 'Jogo'),
    ChecklistItem('complete_dialogue', 'Completar um diálogo', 'Jogo'),
    ChecklistItem('select_emotion', 'Escolher uma emoção numa conversa', 'Jogo'),
    ChecklistItem('trigger_event', 'Acionar um evento (bloquear/desbloquear)', 'Jogo'),
    ChecklistItem('save_game', 'Guardar o jogo', 'Jogo'),
    ChecklistItem('return_to_editor', 'Voltar ao editor', 'Jogo'),
  ];

  Set<String> _done;

  bool get enabled => AppPreferences.testingChecklistEnabled;
  set enabled(bool v) {
    AppPreferences.setTestingChecklistEnabled(v);
    notifyListeners();
  }

  bool isDone(String id) => _done.contains(id);

  int get doneCount => _done.length;
  int get totalCount => items.length;

  void mark(String id) {
    if (_done.contains(id)) return;
    _done = {..._done, id};
    AppPreferences.setTestingChecklistProgress(_done);
    notifyListeners();
  }

  void reset() {
    _done = {};
    AppPreferences.setTestingChecklistProgress(_done);
    notifyListeners();
  }
}
