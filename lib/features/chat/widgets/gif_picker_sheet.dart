import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../../../core/constants/app_colors.dart';

/// GIF picker bottom sheet using Tenor API v2
/// Shows trending GIFs and allows search with debounce
class GifPickerSheet extends StatefulWidget {
  final Function(String gifUrl, String previewUrl) onGifSelected;

  const GifPickerSheet({super.key, required this.onGifSelected});

  @override
  State<GifPickerSheet> createState() => _GifPickerSheetState();
}

class _GifPickerSheetState extends State<GifPickerSheet> {
  final _searchController = TextEditingController();
  List<Map<String, String>> _gifs = [];
  bool _isLoading = false;
  Timer? _debounce;
  String? _errorMsg;

  @override
  void initState() {
    super.initState();
    _loadTrending();
  }

  Future<void> _loadTrending() async {
    setState(() {
      _isLoading = true;
      _errorMsg = null;
    });
    try {
      final apiKey = dotenv.env['TENOR_API_KEY'] ?? '';
      if (apiKey.isEmpty) {
        setState(() {
          _errorMsg = 'TENOR_API_KEY not set in .env';
          _isLoading = false;
        });
        return;
      }

      final response = await Dio().get(
        'https://tenor.googleapis.com/v2/featured',
        queryParameters: {
          'key': apiKey,
          'limit': 30,
          'media_filter': 'gif,tinygif',
        },
      );
      _parseGifs(response.data);
    } catch (e) {
      debugPrint('Tenor error: $e');
      setState(() => _errorMsg = 'Failed to load GIFs');
    }
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _searchGifs(String query) async {
    if (query.trim().isEmpty) {
      _loadTrending();
      return;
    }
    setState(() {
      _isLoading = true;
      _errorMsg = null;
    });
    try {
      final apiKey = dotenv.env['TENOR_API_KEY'] ?? '';
      if (apiKey.isEmpty) return;

      final response = await Dio().get(
        'https://tenor.googleapis.com/v2/search',
        queryParameters: {
          'key': apiKey,
          'q': query,
          'limit': 30,
          'media_filter': 'gif,tinygif',
        },
      );
      _parseGifs(response.data);
    } catch (e) {
      debugPrint('Tenor search error: $e');
    }
    if (mounted) setState(() => _isLoading = false);
  }

  void _parseGifs(Map<String, dynamic> data) {
    final results = data['results'] as List? ?? [];
    setState(() {
      _gifs = results
          .map((item) {
            final media = item['media_formats'] as Map<String, dynamic>? ?? {};
            return <String, String>{
              'url': (media['gif'] as Map?)?['url'] as String? ?? '',
              'preview': (media['tinygif'] as Map?)?['url'] as String? ?? '',
              'id': item['id'] as String? ?? '',
            };
          })
          .where((g) => g['url']!.isNotEmpty)
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.6,
      decoration: const BoxDecoration(
        color: Color(0xFF0A1628),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),

          // Search bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search GIFs...',
                hintStyle: const TextStyle(color: Colors.white38),
                prefixIcon:
                    const Icon(Icons.search, color: AppColors.aquaCore),
                filled: true,
                fillColor: Colors.white10,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onChanged: (query) {
                _debounce?.cancel();
                _debounce = Timer(
                  const Duration(milliseconds: 500),
                  () => _searchGifs(query),
                );
              },
            ),
          ),
          const SizedBox(height: 12),

          // Error or loading or grid
          Expanded(
            child: _errorMsg != null
                ? Center(
                    child: Text(_errorMsg!,
                        style: const TextStyle(color: Colors.white54)),
                  )
                : _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                            color: AppColors.aquaCore),
                      )
                    : GridView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 4,
                          mainAxisSpacing: 4,
                        ),
                        itemCount: _gifs.length,
                        itemBuilder: (_, i) {
                          final gif = _gifs[i];
                          return GestureDetector(
                            onTap: () {
                              widget.onGifSelected(
                                  gif['url']!, gif['preview']!);
                              Navigator.pop(context);
                            },
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: CachedNetworkImage(
                                imageUrl: gif['preview']!,
                                fit: BoxFit.cover,
                                placeholder: (_, __) =>
                                    Container(color: Colors.white10),
                                errorWidget: (_, __, ___) => Container(
                                  color: Colors.white10,
                                  child: const Icon(Icons.broken_image,
                                      color: Colors.white24),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
          ),

          // Tenor attribution
          Padding(
            padding: const EdgeInsets.all(8),
            child: Text(
              'Powered by Tenor',
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.3), fontSize: 10),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }
}
