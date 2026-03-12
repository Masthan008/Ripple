import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/services/privacy_service.dart';

/// Set up a decoy passcode that opens a fake account when entered.
class FakePasscodeScreen extends StatefulWidget {
  const FakePasscodeScreen({super.key});

  @override
  State<FakePasscodeScreen> createState() => _FakePasscodeScreenState();
}

class _FakePasscodeScreenState extends State<FakePasscodeScreen> {
  final _passcodeController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _isEnabled = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkEnabled();
  }

  Future<void> _checkEnabled() async {
    final enabled = await PrivacyService.isFakePasscodeEnabled();
    if (mounted) {
      setState(() {
        _isEnabled = enabled;
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _passcodeController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF060D1A),
        body: Center(
            child: CircularProgressIndicator(color: Color(0xFF0EA5E9))),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF060D1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A1628),
        title: const Text('🎭 Fake Passcode'),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Warning card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border:
                    Border.all(color: Colors.orange.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Text('⚠️', style: TextStyle(fontSize: 18)),
                      SizedBox(width: 8),
                      Text('How It Works',
                          style: TextStyle(
                              color: Colors.orange,
                              fontWeight: FontWeight.bold,
                              fontSize: 15)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '• Set a DIFFERENT passcode from your real one\n'
                    '• When someone enters the fake passcode '
                    'they see a clean decoy account\n'
                    '• Your real account stays hidden\n'
                    '• Make sure your fake passcode is memorable '
                    'but different from real',
                    style: TextStyle(
                        color: Colors.orange.shade200,
                        fontSize: 13,
                        height: 1.5),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            if (_isEnabled)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF22C55E).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: const Color(0xFF22C55E).withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle,
                        color: Color(0xFF22C55E)),
                    const SizedBox(width: 8),
                    const Text('Fake passcode is SET',
                        style: TextStyle(
                            color: Color(0xFF22C55E),
                            fontWeight: FontWeight.bold)),
                    const Spacer(),
                    TextButton(
                      onPressed: () async {
                        final prefs =
                            await SharedPreferences.getInstance();
                        await prefs.remove('fake_passcode');
                        await prefs.setBool(
                            'fake_passcode_enabled', false);
                        setState(() => _isEnabled = false);
                      },
                      child: const Text('Remove',
                          style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 20),

            Text(_isEnabled ? 'Update Fake Passcode' : 'Set Fake Passcode',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),

            TextField(
              controller: _passcodeController,
              obscureText: true,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Enter fake passcode',
                hintStyle: const TextStyle(color: Colors.white38),
                filled: true,
                fillColor: Colors.white10,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none),
                prefixIcon:
                    const Icon(Icons.lock_rounded, color: Colors.white38),
              ),
            ),
            const SizedBox(height: 12),

            TextField(
              controller: _confirmController,
              obscureText: true,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Confirm fake passcode',
                hintStyle: const TextStyle(color: Colors.white38),
                filled: true,
                fillColor: Colors.white10,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none),
                prefixIcon: const Icon(Icons.lock_outlined,
                    color: Colors.white38),
              ),
            ),
            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: () async {
                  final p1 = _passcodeController.text.trim();
                  final p2 = _confirmController.text.trim();

                  if (p1.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Enter a passcode')));
                    return;
                  }
                  if (p1 != p2) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text('Passcodes do not match'),
                        backgroundColor: Colors.red));
                    return;
                  }
                  if (p1.length < 4) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text('Use at least 4 digits'),
                        backgroundColor: Colors.red));
                    return;
                  }

                  await PrivacyService.setFakePasscode(p1);
                  setState(() => _isEnabled = true);
                  _passcodeController.clear();
                  _confirmController.clear();

                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text('🎭 Fake passcode set!'),
                        backgroundColor: Color(0xFF22C55E)));
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0EA5E9),
                ),
                child: Text(
                    _isEnabled ? 'Update Passcode' : 'Set Fake Passcode',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 15)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
