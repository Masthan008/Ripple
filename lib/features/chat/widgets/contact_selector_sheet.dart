import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../friends/providers/friends_provider.dart';

class ContactSelectorSheet extends ConsumerWidget {
  final Function(String name, String uid) onContactSelected;

  const ContactSelectorSheet({super.key, required this.onContactSelected});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final friendsAsync = ref.watch(friendsListProvider);

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0A1628),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Share Contact',
            style: AppTextStyles.heading.copyWith(fontSize: 18),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: friendsAsync.when(
              loading: () => const Center(
                child: CircularProgressIndicator(color: AppColors.aquaCore),
              ),
              error: (e, _) => Center(
                child: Text('Error loading friends: $e',
                    style: const TextStyle(color: Colors.white54)),
              ),
              data: (friends) {
                if (friends.isEmpty) {
                  return const Center(
                    child: Text('No friends to share',
                        style: TextStyle(color: Colors.white54)),
                  );
                }

                return ListView.builder(
                  shrinkWrap: true,
                  itemCount: friends.length,
                  itemBuilder: (context, i) {
                    final friend = friends[i];
                    final name = friend.name;

                    return ListTile(
                      leading: CircleAvatar(
                        radius: 20,
                        backgroundColor: AppColors.aquaCore.withOpacity(0.2),
                        backgroundImage: friend.photoUrl.isNotEmpty
                            ? NetworkImage(friend.photoUrl)
                            : null,
                        child: friend.photoUrl.isEmpty
                            ? Text(
                                name.isNotEmpty ? name[0].toUpperCase() : '?',
                                style: const TextStyle(
                                    color: AppColors.aquaCore,
                                    fontWeight: FontWeight.bold),
                              )
                            : null,
                      ),
                      title: Text(name,
                          style: const TextStyle(color: Colors.white)),
                      onTap: () {
                        Navigator.pop(context);
                        onContactSelected(name, friend.uid);
                      },
                    );
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
