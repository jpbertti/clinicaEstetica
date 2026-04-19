import 'dart:ui_web' as ui;
import 'package:flutter/material.dart';
import 'dart:html' as html;
import '../map_view_widget.dart';

class MapViewImpl extends MapViewWidget {
  const MapViewImpl({super.key, required super.url}) : super.internal();

  @override
  Widget build(BuildContext context) {
    final viewType = 'map-iframe-${url.hashCode}';
    
    // ignore: undefined_prefixed_name
    ui.platformViewRegistry.registerViewFactory(
      viewType,
      (int viewId) => html.IFrameElement()
        ..src = url
        ..style.border = 'none'
        ..style.width = '100%'
        ..style.height = '100%',
    );

    return HtmlElementView(viewType: viewType);
  }
}

