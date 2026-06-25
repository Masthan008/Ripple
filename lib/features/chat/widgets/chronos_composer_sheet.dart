import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/services/chronos_unlock_service.dart';
import '../../../core/utils/haptic_feedback.dart';

/// Chronos Composer Sheet — Contextual Time-Capsules™
///
/// A premium bottom sheet that lets the sender pick an unlock
/// condition for their message before sending. Supports:
/// - Battery threshold (slider)
/// - Scheduled time (date/time picker)
/// - Location arrival (manual lat/lng or placeholder for map)
/// - Shake to unlock
class ChronosComposerSheet extends StatefulWidget {
  final void Function(String type, String value) onConditionSet;

  const ChronosComposerSheet({super.key, required this.onConditionSet});

  @override
  State<ChronosComposerSheet> createState() => _ChronosComposerSheetState();
}

class _ChronosComposerSheetState extends State<ChronosComposerSheet> {
  String? _selectedType;
  double _batteryThreshold = 20;
  DateTime _scheduledTime = DateTime.now().add(const Duration(hours: 1));

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0A1628),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(top: 12),
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Title
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFF6366F1).withOpacity(0.3),
                        const Color(0xFF0EA5E9).withOpacity(0.3),
                      ],
                    ),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.hourglass_bottom_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Chronos Message',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Set an unlock condition',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.5),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Condition type selector
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _buildConditionChip('battery', Icons.battery_alert_rounded, 'Battery Level'),
                _buildConditionChip('time', Icons.access_time_rounded, 'Scheduled Time'),
                _buildConditionChip('location', Icons.location_on_rounded, 'Location'),
                _buildConditionChip('shake', Icons.vibration_rounded, 'Shake to Open'),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Condition configurator
          if (_selectedType != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _buildConfigurator(),
            ),

          const SizedBox(height: 16),

          // Confirm button
          if (_selectedType != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _confirm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.lock_rounded, color: Colors.white, size: 16),
                      const SizedBox(width: 8),
                      const Text(
                        'Lock Message',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
        ],
      ),
    );
  }

  Widget _buildConditionChip(String type, IconData icon, String label) {
    final isSelected = _selectedType == type;
    final color = _getColor(type);

    return GestureDetector(
      onTap: () {
        AppHaptics.lightTap();
        setState(() => _selectedType = type);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.15) : Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? color.withOpacity(0.5) : Colors.white12,
            width: isSelected ? 1.5 : 0.5,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: color.withOpacity(0.15),
                    blurRadius: 10,
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? color : Colors.white60,
              size: 18,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? color : Colors.white60,
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConfigurator() {
    switch (_selectedType) {
      case 'battery':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Unlock when battery ≤ ${_batteryThreshold.round()}%',
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 8),
            SliderTheme(
              data: SliderThemeData(
                activeTrackColor: Colors.amber,
                thumbColor: Colors.amber,
                inactiveTrackColor: Colors.amber.withOpacity(0.2),
                overlayColor: Colors.amber.withOpacity(0.1),
              ),
              child: Slider(
                value: _batteryThreshold,
                min: 5,
                max: 95,
                divisions: 18,
                onChanged: (v) => setState(() => _batteryThreshold = v),
              ),
            ),
          ],
        );

      case 'time':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Unlock at: ${_formatDateTime(_scheduledTime)}',
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickDate,
                    icon: const Icon(Icons.calendar_today_rounded, size: 16),
                    label: const Text('Date'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF6366F1),
                      side: BorderSide(color: const Color(0xFF6366F1).withOpacity(0.3)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickTime,
                    icon: const Icon(Icons.access_time_rounded, size: 16),
                    label: const Text('Time'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF6366F1),
                      side: BorderSide(color: const Color(0xFF6366F1).withOpacity(0.3)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        );

      case 'location':
        return const Text(
          'Message will unlock when the recipient arrives at your\n'
          'shared location (within 200 meters).',
          style: TextStyle(color: Colors.white54, fontSize: 12, height: 1.5),
        );

      case 'shake':
        return const Text(
          'Recipient must shake their phone 3 times to open this message.\n'
          'Perfect for fun reveals and surprises!',
          style: TextStyle(color: Colors.white54, fontSize: 12, height: 1.5),
        );

      default:
        return const SizedBox.shrink();
    }
  }

  void _confirm() {
    if (_selectedType == null) return;

    String value;
    switch (_selectedType) {
      case 'battery':
        value = _batteryThreshold.round().toString();
        break;
      case 'time':
        value = _scheduledTime.toIso8601String();
        break;
      case 'location':
        value = '0,0'; // Placeholder — real app would use map picker
        break;
      case 'shake':
        value = '3'; // 3 shakes required
        break;
      default:
        return;
    }

    widget.onConditionSet(_selectedType!, value);
    Navigator.pop(context);
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _scheduledTime,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
            primary: Color(0xFF6366F1),
            surface: Color(0xFF0A1628),
          ),
        ),
        child: child!,
      ),
    );
    if (date != null) {
      setState(() {
        _scheduledTime = DateTime(
          date.year, date.month, date.day,
          _scheduledTime.hour, _scheduledTime.minute,
        );
      });
    }
  }

  Future<void> _pickTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_scheduledTime),
      builder: (context, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
            primary: Color(0xFF6366F1),
            surface: Color(0xFF0A1628),
          ),
        ),
        child: child!,
      ),
    );
    if (time != null) {
      setState(() {
        _scheduledTime = DateTime(
          _scheduledTime.year, _scheduledTime.month, _scheduledTime.day,
          time.hour, time.minute,
        );
      });
    }
  }

  String _formatDateTime(DateTime dt) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '${months[dt.month - 1]} ${dt.day}, $h:$m';
  }

  Color _getColor(String type) {
    switch (type) {
      case 'battery':
        return Colors.amber;
      case 'time':
        return const Color(0xFF6366F1);
      case 'location':
        return const Color(0xFF10B981);
      case 'shake':
        return const Color(0xFFF43F5E);
      default:
        return AppColors.aquaCore;
    }
  }
}
