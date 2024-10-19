import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:html';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Yamaloader',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: VideoDownloader(),
    );
  }
}

class VideoDownloader extends StatefulWidget {
  @override
  _VideoDownloaderState createState() => _VideoDownloaderState();
}

class _VideoDownloaderState extends State<VideoDownloader> {
  TextEditingController urlController = TextEditingController();
  List<Map<String, dynamic>> formats = [];
  String? selectedFormat; // Nullable String to handle selection
  bool isLoadingFormats = false;
  bool isDownloading = false;
  double downloadProgress = 0.0;

  // Fetch available formats for the given YouTube URL
  Future<void> fetchFormats() async {
    final url = urlController.text;
    if (url.isEmpty) return;

    setState(() {
      isLoadingFormats = true;
      formats = [];
      selectedFormat = null;
    });

    try {
      final response = await http.post(
        Uri.parse('http://localhost:5000/get_formats'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'url': url}),
      );

      if (response.statusCode == 200) {
        setState(() {
          formats = List<Map<String, dynamic>>.from(json.decode(response.body));
          if (formats.isNotEmpty) {
            selectedFormat = formats[0]['format_id'] as String;
          }
        });
      } else {
        print('Error fetching formats: ${response.body}');
      }
    } catch (e) {
      print('Error: $e');
    } finally {
      setState(() {
        isLoadingFormats = false;
      });
    }
  }

  Future<void> downloadVideo() async {
    if (selectedFormat == null || urlController.text.isEmpty) return;

    setState(() {
      isDownloading = true;
      downloadProgress = 0.0;
    });

    try {
      final response = await http.post(
        Uri.parse('http://localhost:5000/download'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'url': urlController.text,
          'format': selectedFormat,
        }),
      );

      if (response.statusCode == 200) {
        // This will allow you to download the file directly
        final blob = Blob([response.bodyBytes]);
        final url = Url.createObjectUrlFromBlob(blob);
        AnchorElement(href: url)
          ..setAttribute('download', 'video.mp4') // You can adjust the name
          ..click();
        Url.revokeObjectUrl(url); // Clean up the URL
        setState(() {
          isDownloading = false;
        });
      } else {
        print('Error: ${response.body}');
      }
    } catch (e) {
      print('Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Download YouTube Videos with Yamaloader'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: urlController,
                    decoration: const InputDecoration(
                      labelText: 'Enter YouTube Video URL',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: isLoadingFormats ? null : fetchFormats,
                  child: isLoadingFormats
                      ? const CircularProgressIndicator()
                      : const Text('Proceed'),
                ),
              ],
            ),
            if (formats.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text('Select Video Quality'),
              DropdownButton<String>(
                value: selectedFormat,
                onChanged: (String? newValue) {
                  setState(() {
                    selectedFormat = newValue;
                  });
                },
                items: formats.map<DropdownMenuItem<String>>((format) {
                  final formatInfo = format['format_note'] != ''
                      ? '${format['format_note']} (${format['ext']})'
                      : '${format['ext']}';
                  final size = format['filesize'] != null
                      ? ' - ${(format['filesize'] / (1024 * 1024)).toStringAsFixed(2)} MB'
                      : '';
                  return DropdownMenuItem<String>(
                    value: format['format_id'] as String,
                    child: Text('$formatInfo$size'),
                  );
                }).toList(),
              ),
            ],
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: isDownloading ? null : downloadVideo,
              child: isDownloading
                  ? const CircularProgressIndicator()
                  : const Text('Download'),
            ),
          ],
        ),
      ),
    );
  }
}
