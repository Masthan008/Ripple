import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/env.dart';

/// GIF picker bottom sheet using Giphy API v1
/// Shows trending GIFs on open, allows search with debounce + infinite scroll
class GifPickerSheet extends StatefulWidget {
  final Function(String gifUrl, String previewUrl) onGifSelected;

  const GifPickerSheet({super.key, required this.onGifSelected});

  @override
  State<GifPickerSheet> createState() => _GifPickerSheetState();
}

class _GifPickerSheetState extends State<GifPickerSheet> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  List<Map<String, String>> _gifs = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  int _offset = 0;
  String _lastQuery = '';
  Timer? _debounce;
  String? _errorMsg;

  @override
  void initState() {
    super.initState();
    _loadTrending();
    _scrollController.addListener(_onScroll);
  }

  /// Infinite scroll — load more when near bottom
  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      if (!_isLoadingMore) _loadMore();
    }
  }

  Future<void> _loadTrending() async {
    setState(() {
      _isLoading = true;
      _errorMsg = null;
      _offset = 0;
      _lastQuery = '';
      _gifs = [];
    });
    try {
      final results = await _fetchGiphy(endpoint: 'trending', offset: 0);
      if (mounted) {
        setState(() {
          _gifs = results;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Giphy trending error: $e');
      if (mounted) {
        setState(() {
          _errorMsg = 'Failed to load GIFs';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _searchGifs(String query) async {
    if (query.trim().isEmpty) {
      _loadTrending();
      return;
    }
    setState(() {
      _isLoading = true;
      _errorMsg = null;
      _offset = 0;
      _lastQuery = query;
      _gifs = [];
    });
    try {
      final results =
          await _fetchGiphy(endpoint: 'search', query: query, offset: 0);
      if (mounted) {
        setState(() {
          _gifs = results;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Giphy search error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore) return;
    setState(() => _isLoadingMore = true);

    _offset += 30;
    try {
      final more = await _fetchGiphy(
        endpoint: _lastQuery.isEmpty ? 'trending' : 'search',
        query: _lastQuery.isEmpty ? null : _lastQuery,
        offset: _offset,
      );
      if (mounted) {
        setState(() {
          _gifs.addAll(more);
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  /// Core Giphy API call — handles both trending + search endpoints
  Future<List<Map<String, String>>> _fetchGiphy({
    required String endpoint,
    String? query,
    int offset = 0,
  }) async {
    final apiKey = Env.giphyApiKey;
    if (apiKey.isEmpty) {
      throw Exception('GIPHY_API_KEY not set in .env');
    }

    final params = <String, String>{
      'api_key': apiKey,
      'limit': '30',
      'offset': offset.toString(),
      'rating': 'pg-13',
      'lang': 'en',
      if (query != null && query.isNotEmpty) 'q': query,
    };

    final uri = Uri.https('api.giphy.com', '/v1/gifs/$endpoint', params);
    final response = await Dio().getUri(uri);
    final data = response.data as Map<String, dynamic>;
    final results = data['data'] as List? ?? [];

    return results.map<Map<String, String>>((item) {
      final images = item['images'] as Map<String, dynamic>? ?? {};
      final original = images['original'] as Map<String, dynamic>? ?? {};
      final display = images['fixed_height'] as Map<String, dynamic>? ?? {};
      final small = images['fixed_height_small'] as Map<String, dynamic>? ?? {};

      return {
        'id': item['id'] as String? ?? '',
        'title': item['title'] as String? ?? '',
        'url': original['url'] as String? ?? '',
        'displayUrl': display['url'] as String? ?? '',
        'previewUrl': small['url'] as String? ?? '',
      };
    }).where((g) => g['url']!.isNotEmpty).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.65,
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

          // Header with Giphy attribution
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              children: [
                const Text(
                  'GIFs',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                // Giphy attribution (required by Terms of Service)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Powered by GIPHY',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Search bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search GIPHY...',
                hintStyle: const TextStyle(color: Colors.white38),
                prefixIcon:
                    const Icon(Icons.search, color: AppColors.aquaCore),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon:
                            const Icon(Icons.clear, color: Colors.white38),
                        onPressed: () {
                          _searchController.clear();
                          _loadTrending();
                        },
                      )
                    : null,
                filled: true,
                fillColor: Colors.white10,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onChanged: (query) {
                setState(() {}); // Update clear button visibility
                _debounce?.cancel();
                _debounce = Timer(
                  const Duration(milliseconds: 500),
                  () => _searchGifs(query),
                );
              },
            ),
          ),
          const SizedBox(height: 8),

          // Error or loading or grid
          Expanded(
            child: _errorMsg != null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('😕', style: TextStyle(fontSize: 48)),
                        const SizedBox(height: 12),
                        Text(
                          _errorMsg!,
                          style: const TextStyle(color: Colors.white54),
                        ),
                      ],
                    ),
                  )
                : _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: AppColors.aquaCore,
                          strokeWidth: 2,
                        ),
                      )
                    : _gifs.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Text('😕',
                                    style: TextStyle(fontSize: 48)),
                                const SizedBox(height: 12),
                                Text(
                                  _searchController.text.isEmpty
                                      ? 'Could not load GIFs'
                                      : 'No GIFs found for "${_searchController.text}"',
                                  style: const TextStyle(
                                      color: Colors.white38),
                                ),
                              ],
                            ),
                          )
                        : GridView.builder(
                            controller: _scrollController,
                            padding:
                                const EdgeInsets.symmetric(horizontal: 8),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              crossAxisSpacing: 4,
                              mainAxisSpacing: 4,
                              childAspectRatio: 1,
                            ),
                            itemCount: _gifs.length + 1,
                            itemBuilder: (_, i) {
                              // Loading more indicator at end
                              if (i == _gifs.length) {
                                return _isLoadingMore
                                    ? const Center(
                                        child: CircularProgressIndicator(
                                          color: AppColors.aquaCore,
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const SizedBox();
                              }

                              final gif = _gifs[i];
                              return GestureDetector(
                                onTap: () {
                                  // Send original URL for full quality,
                                  // displayUrl for preview in chat
                                  widget.onGifSelected(
                                    gif['url']!,
                                    gif['displayUrl']!,
                                  );
                                  Navigator.pop(context);
                                },
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: CachedNetworkImage(
                                    imageUrl: gif['displayUrl']!,
                                    fit: BoxFit.cover,
                                    placeholder: (_, __) => Container(
                                      color: Colors.white10,
                                      child: const Center(
                                        child: CircularProgressIndicator(
                                          strokeWidth: 1,
                                          color: AppColors.aquaCore,
                                        ),
                                      ),
                                    ),
                                    errorWidget: (_, __, ___) => Container(
                                      color: Colors.white10,
                                      child: const Icon(
                                        Icons.gif_rounded,
                                        color: Colors.white24,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
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
    _scrollController.dispose();
    super.dispose();
  }
}
