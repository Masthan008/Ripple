import 'package:cloud_firestore/cloud_firestore.dart';

/// Model for a user-created chat folder.
class FolderModel {
  final String folderId;
  final String name;
  final String icon;
  final String color;
  final List<String> chatIds;
  final List<String> groupIds;
  final int order;

  const FolderModel({
    required this.folderId,
    required this.name,
    required this.icon,
    required this.color,
    this.chatIds = const [],
    this.groupIds = const [],
    required this.order,
  });

  factory FolderModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return FolderModel(
      folderId: doc.id,
      name: d['name'] as String? ?? '',
      icon: d['icon'] as String? ?? '💬',
      color: d['color'] as String? ?? '0EA5E9',
      chatIds: List<String>.from(d['chatIds'] as List? ?? []),
      groupIds: List<String>.from(d['groupIds'] as List? ?? []),
      order: d['order'] as int? ?? 0,
    );
  }
}
