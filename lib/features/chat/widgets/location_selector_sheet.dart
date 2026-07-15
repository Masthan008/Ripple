import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';

class LocationSelectorSheet extends StatefulWidget {
  final Function(double lat, double lng, {bool isLive}) onLocationSelected;

  const LocationSelectorSheet({super.key, required this.onLocationSelected});

  @override
  State<LocationSelectorSheet> createState() => _LocationSelectorSheetState();
}

class _LocationSelectorSheetState extends State<LocationSelectorSheet> {
  bool _isLoading = false;
  String? _error;

  Future<void> _getLocation(bool isLive) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final status = await Permission.location.request();
      if (!status.isGranted) {
        setState(() {
          _error = 'Location permission is required';
          _isLoading = false;
        });
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      if (mounted) {
        Navigator.pop(context);
        widget.onLocationSelected(
          position.latitude,
          position.longitude,
          isLive: isLive,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to get location: $e';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
            'Share Location',
            style: AppTextStyles.heading.copyWith(fontSize: 18),
          ),
          const SizedBox(height: 16),
          if (_error != null) ...[
            Text(_error!, style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
            const SizedBox(height: 12),
          ],
          if (_isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: CircularProgressIndicator(color: AppColors.aquaCore),
              ),
            )
          else ...[
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.aquaCore.withOpacity(0.1),
                ),
                child: const Icon(Icons.my_location_rounded, color: AppColors.aquaCore),
              ),
              title: const Text('Send Your Current Location',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              subtitle: const Text('Send static map coordinates',
                  style: TextStyle(color: Colors.white54, fontSize: 12)),
              onTap: () => _getLocation(false),
            ),
            const Divider(color: Colors.white12),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.green.withOpacity(0.1),
                ),
                child: const Icon(Icons.share_location_rounded, color: Colors.green),
              ),
              title: const Text('Share Live Location',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              subtitle: const Text('Updates your position in real-time',
                  style: TextStyle(color: Colors.white54, fontSize: 12)),
              onTap: () => _getLocation(true),
            ),
          ],
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
