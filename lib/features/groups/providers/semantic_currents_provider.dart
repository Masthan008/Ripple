import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/semantic_currents_service.dart';
import '../../chat/models/message_model.dart';
import '../providers/group_provider.dart';

/// Provides the semantic classification for all messages in a group chat.
/// Returns a map of messageId → topicKey (e.g. 'plans', 'food', 'tech').
final semanticClassificationProvider =
    Provider.family<Map<String, String>, List<MessageModel>>((ref, messages) {
  final service = SemanticCurrentsService.instance;

  final entries = messages
      .where((m) => m.text != null && m.text!.isNotEmpty && m.type == 'text')
      .map((m) => MessageEntry(id: m.id, text: m.text!))
      .toList();

  return service.classifyBatch(entries);
});

/// Provides the list of active topics in a group chat, sorted by frequency.
final activeTopicsProvider =
    Provider.family<List<String>, List<MessageModel>>((ref, messages) {
  final classifications = ref.watch(semanticClassificationProvider(messages));
  return SemanticCurrentsService.instance.getActiveTopics(classifications);
});

/// The currently selected topic filter.
/// null means "show all messages" (no filter active).
final selectedTopicProvider = StateProvider<String?>((ref) => null);

/// Filtered messages based on the selected topic.
/// If no topic is selected, returns all messages.
final filteredMessagesByTopicProvider = Provider.family<List<MessageModel>,
    List<MessageModel>>((ref, messages) {
  final selectedTopic = ref.watch(selectedTopicProvider);
  if (selectedTopic == null) return messages;

  final classifications = ref.watch(semanticClassificationProvider(messages));

  return messages.where((m) {
    final topic = classifications[m.id];
    return topic == selectedTopic;
  }).toList();
});
