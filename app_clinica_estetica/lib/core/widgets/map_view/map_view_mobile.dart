import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../map_view_widget.dart';

class MapViewImpl extends MapViewWidget {
  const MapViewImpl({super.key, required super.url}) : super.internal();

  @override
  Widget build(BuildContext context) {
    return _MobileMapStateful(url: url);
  }
}

class _MobileMapStateful extends StatefulWidget {
  final String url;
  const _MobileMapStateful({required this.url});

  @override
  State<_MobileMapStateful> createState() => _MobileMapStatefulState();
}

class _MobileMapStatefulState extends State<_MobileMapStateful> {
  late final WebViewController _controller;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            // Update loading bar.
          },
          onPageStarted: (String url) {
            if (mounted) {
              setState(() {
                _isLoading = true;
              });
            }
          },
          onPageFinished: (String url) {
            if (mounted) {
              setState(() {
                _isLoading = false;
              });
            }
          },
          onWebResourceError: (WebResourceError error) {
            debugPrint('WebView error: ${error.description}');
          },
        ),
      );

    _loadMap();
  }

  void _loadMap() {
    final html = '''
      <!DOCTYPE html>
      <html>
        <head>
          <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
          <style>
            body { margin: 0; padding: 0; overflow: hidden; background-color: #f5f5f5; }
            iframe { border: 0; width: 100vw; height: 100vh; position: absolute; top: 0; left: 0; }
          </style>
        </head>
        <body>
          <iframe 
            src="${widget.url}" 
            allowfullscreen="" 
            loading="lazy" 
            referrerpolicy="no-referrer-when-downgrade">
          </iframe>
        </body>
      </html>
    ''';
    _controller.loadHtmlString(html);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        WebViewWidget(controller: _controller),
        if (_isLoading)
          const Center(
            child: CircularProgressIndicator(),
          ),
      ],
    );
  }
}

