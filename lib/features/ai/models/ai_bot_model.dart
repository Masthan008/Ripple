import 'package:uuid/uuid.dart';

class AiBotModel {
  final String id;
  final String name;
  final String emoji;
  final String description;
  final String systemPrompt;
  final String colorHex;

  const AiBotModel({
    required this.id,
    required this.name,
    required this.emoji,
    required this.description,
    required this.systemPrompt,
    required this.colorHex,
  });

  factory AiBotModel.create({
    required String name,
    required String emoji,
    required String description,
    required String systemPrompt,
    String? colorHex,
  }) {
    return AiBotModel(
      id: const Uuid().v4(),
      name: name,
      emoji: emoji,
      description: description,
      systemPrompt: systemPrompt,
      colorHex: colorHex ?? '0xFF0EA5E9',
    );
  }
}
