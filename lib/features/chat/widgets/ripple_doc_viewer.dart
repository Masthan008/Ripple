import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';

class RippleDocViewer extends StatefulWidget {
  final String? filePath;
  final String? fileUrl;
  final String fileName;

  const RippleDocViewer({
    super.key,
    this.filePath,
    this.fileUrl,
    required this.fileName,
  });

  @override
  State<RippleDocViewer> createState() => _RippleDocViewerState();
}

class _RippleDocViewerState extends State<RippleDocViewer> {
  bool _isLoading = true;
  String? _error;
  String? _localPath;
  String _textContent = '';
  List<String> _textLines = [];
  bool _wordWrap = true;
  String _searchQuery = '';
  final _searchCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadFile();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadFile() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      if (widget.filePath != null && widget.filePath!.isNotEmpty) {
        _localPath = widget.filePath;
      } else if (widget.fileUrl != null && widget.fileUrl!.isNotEmpty) {
        // Download file to cache
        final tempDir = await getTemporaryDirectory();
        final cacheFile = File('${tempDir.path}/${widget.fileName}');
        
        final client = HttpClient();
        final request = await client.getUrl(Uri.parse(widget.fileUrl!));
        final response = await request.close();
        await response.pipe(cacheFile.openWrite());
        _localPath = cacheFile.path;
      } else {
        throw 'No file source provided';
      }

      final ext = widget.fileName.split('.').last.toLowerCase();
      if (_isTextExtension(ext)) {
        final file = File(_localPath!);
        _textContent = await file.readAsString();
        _textLines = _textContent.split('\n');
      }

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load document: $e';
          _isLoading = false;
        });
      }
    }
  }

  bool _isTextExtension(String ext) {
    return const [
      'txt', 'json', 'csv', 'log', 'yaml', 'yml',
      'xml', 'ini', 'md', 'dart', 'js', 'html', 'css', 'py'
    ].contains(ext);
  }

  bool _isImageExtension(String ext) {
    return const ['png', 'jpg', 'jpeg', 'gif', 'webp', 'bmp'].contains(ext);
  }

  bool _isPdfExtension(String ext) {
    return ext == 'pdf';
  }

  bool _isOfficeExtension(String ext) {
    return const ['doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx'].contains(ext);
  }

  void _openExternally() {
    if (_localPath != null) {
      OpenFilex.open(_localPath!);
    }
  }

  List<TextSpan> _highlightSearchMatches(String text, double fontSize) {
    if (_searchQuery.isEmpty) {
      return [TextSpan(text: text, style: TextStyle(color: Colors.white70, fontSize: fontSize))];
    }

    final spans = <TextSpan>[];
    int start = 0;
    final lowercaseText = text.toLowerCase();
    final lowercaseQuery = _searchQuery.toLowerCase();

    while (true) {
      final index = lowercaseText.indexOf(lowercaseQuery, start);
      if (index == -1) {
        spans.add(TextSpan(
          text: text.substring(start),
          style: TextStyle(color: Colors.white70, fontSize: fontSize),
        ));
        break;
      }

      if (index > start) {
        spans.add(TextSpan(
          text: text.substring(start, index),
          style: TextStyle(color: Colors.white70, fontSize: fontSize),
        ));
      }

      spans.add(TextSpan(
        text: text.substring(index, index + _searchQuery.length),
        style: TextStyle(
          color: Colors.black,
          backgroundColor: Colors.amberAccent,
          fontWeight: FontWeight.bold,
          fontSize: fontSize,
        ),
      ));

      start = index + _searchQuery.length;
    }

    return spans;
  }

  @override
  Widget build(BuildContext context) {
    final ext = widget.fileName.split('.').last.toLowerCase();
    final isText = _isTextExtension(ext);
    final isImage = _isImageExtension(ext);
    final isPdf = _isPdfExtension(ext);
    final isOffice = _isOfficeExtension(ext);
    final canRenderInline = isText || isImage || isPdf;

    return Scaffold(
      backgroundColor: AppColors.abyssBackground,
      appBar: AppBar(
        title: Text(widget.fileName, style: AppTextStyles.headingSmall),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          if (_localPath != null)
            IconButton(
              icon: const Icon(Icons.open_in_new_rounded, color: AppColors.aquaCore),
              tooltip: 'Open with External App',
              onPressed: _openExternally,
            ),
          if (isText && !_isLoading && _error == null) ...[
            IconButton(
              icon: Icon(_wordWrap ? Icons.wrap_text_rounded : Icons.keyboard_tab_rounded,
                  color: AppColors.aquaCore),
              tooltip: _wordWrap ? 'Disable Word Wrap' : 'Enable Word Wrap',
              onPressed: () {
                setState(() {
                  _wordWrap = !_wordWrap;
                });
              },
            ),
          ],
        ],
      ),
      body: _buildBody(isText, isImage, isPdf, isOffice, ext, canRenderInline),
    );
  }

  Widget _buildBody(bool isText, bool isImage, bool isPdf, bool isOffice, String ext, bool canRenderInline) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.aquaCore));
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 48),
              const SizedBox(height: 16),
              Text(_error!, style: const TextStyle(color: Colors.white70), textAlign: TextAlign.center),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _openExternally,
                icon: const Icon(Icons.open_in_new_rounded),
                label: const Text('Open Externally'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.aquaCore,
                  foregroundColor: Colors.black,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (isText) {
      return _buildTextViewer();
    }

    if (isImage && _localPath != null) {
      return Center(
        child: InteractiveViewer(
          maxScale: 5.0,
          child: Image.file(File(_localPath!)),
        ),
      );
    }

    if (isPdf && _localPath != null) {
      final pdfUri = Uri.file(_localPath!).toString();
      return InAppWebView(
        initialSettings: InAppWebViewSettings(
          javaScriptEnabled: true,
          allowFileAccessFromFileURLs: true,
          allowUniversalAccessFromFileURLs: true,
        ),
        initialUrlRequest: URLRequest(
          url: WebUri(pdfUri),
        ),
      );
    }

    // Binary / Office / PDF fallback inspector
    return _buildBinaryFallbackInspector(ext);
  }

  Widget _buildTextViewer() {
    return Column(
      children: [
        // Search bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: TextField(
            controller: _searchCtrl,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Search text...',
              hintStyle: const TextStyle(color: Colors.white30),
              prefixIcon: const Icon(Icons.search_rounded, color: Colors.white30),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded, color: Colors.white30),
                      onPressed: () {
                        setState(() {
                          _searchCtrl.clear();
                          _searchQuery = '';
                        });
                      },
                    )
                  : null,
              filled: true,
              fillColor: Colors.white.withOpacity(0.04),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            onChanged: (val) {
              setState(() {
                _searchQuery = val;
              });
            },
          ),
        ),

        // Text display
        Expanded(
          child: Scrollbar(
            controller: _scrollCtrl,
            child: ListView.builder(
              controller: _scrollCtrl,
              padding: const EdgeInsets.all(16.0),
              itemCount: _textLines.length,
              itemBuilder: (context, index) {
                final lineNum = index + 1;
                final lineText = _textLines[index];

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Line number
                    SizedBox(
                      width: 32,
                      child: Text(
                        '$lineNum',
                        style: const TextStyle(
                          color: Colors.white24,
                          fontFamily: 'monospace',
                          fontSize: 12,
                        ),
                        textAlign: TextAlign.right,
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Line content
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: _wordWrap ? Axis.vertical : Axis.horizontal,
                        child: RichText(
                          text: TextSpan(
                            children: _highlightSearchMatches(lineText, 12.0),
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              height: 1.4,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBinaryFallbackInspector(String ext) {
    final file = File(_localPath!);
    final sizeBytes = file.lengthSync();
    final sizeMb = (sizeBytes / (1024 * 1024)).toStringAsFixed(2);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.aquaCore.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.insert_drive_file_rounded,
                color: AppColors.aquaCore,
                size: 64,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              widget.fileName,
              style: AppTextStyles.headingSmall.copyWith(fontSize: 18),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              '${ext.toUpperCase()} File • $sizeMb MB',
              style: const TextStyle(color: Colors.white54, fontSize: 13),
            ),
            const SizedBox(height: 32),
            const Text(
              'Ripple has securely processed this document. To view formatting, spreadsheets, or print, please open it using an external office app.',
              style: TextStyle(color: Colors.white38, fontSize: 12, height: 1.5),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _openExternally,
                icon: const Icon(Icons.open_in_new_rounded),
                label: const Text('Open with External App', style: TextStyle(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.aquaCore,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
