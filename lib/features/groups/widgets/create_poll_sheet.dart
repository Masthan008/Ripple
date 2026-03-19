import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

class CreatePollSheet extends StatefulWidget {
  final Function(String question, List<String> options) onPollCreated;

  const CreatePollSheet({super.key, required this.onPollCreated});

  @override
  State<CreatePollSheet> createState() => _CreatePollSheetState();
}

class _CreatePollSheetState extends State<CreatePollSheet> {
  final _questionCtrl = TextEditingController();
  final List<TextEditingController> _optionCtrls = [
    TextEditingController(),
    TextEditingController()
  ];

  @override
  void dispose() {
    _questionCtrl.dispose();
    for (var ctrl in _optionCtrls) {
      ctrl.dispose();
    }
    super.dispose();
  }

  void _addOption() {
    if (_optionCtrls.length < 6) {
      setState(() => _optionCtrls.add(TextEditingController()));
    }
  }

  void _removeOption(int index) {
    if (_optionCtrls.length > 2) {
      setState(() {
        _optionCtrls[index].dispose();
        _optionCtrls.removeAt(index);
      });
    }
  }

  void _submit() {
    final question = _questionCtrl.text.trim();
    if (question.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: const Text('Question is required'),
            backgroundColor: AppColors.errorRed),
      );
      return;
    }

    final options = _optionCtrls
        .map((c) => c.text.trim())
        .where((text) => text.isNotEmpty)
        .toList();

    if (options.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: const Text('At least 2 options are required'),
            backgroundColor: AppColors.errorRed),
      );
      return;
    }

    widget.onPollCreated(question, options);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
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
          const Text('Create Poll',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          TextField(
            controller: _questionCtrl,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Ask a question...',
              hintStyle: const TextStyle(color: Colors.white38),
              filled: true,
              fillColor: Colors.white10,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 16),
          const Text('Options',
              style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          ...List.generate(_optionCtrls.length, (index) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _optionCtrls[index],
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Option ${index + 1}',
                        hintStyle: const TextStyle(color: Colors.white24),
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.05),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                      ),
                    ),
                  ),
                  if (_optionCtrls.length > 2) ...[
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline,
                          color: Colors.white38),
                      onPressed: () => _removeOption(index),
                    )
                  ]
                ],
              ),
            );
          }),
          if (_optionCtrls.length < 6)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _addOption,
                icon: const Icon(Icons.add, color: AppColors.aquaCore),
                label: const Text('Add Option',
                    style: TextStyle(color: AppColors.aquaCore)),
              ),
            ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.aquaCore,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Create Poll',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
