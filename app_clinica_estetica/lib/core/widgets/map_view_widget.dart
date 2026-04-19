import 'package:flutter/material.dart';
import 'map_view/map_view_stub.dart'
    if (dart.library.html) 'map_view/map_view_web.dart'
    if (dart.library.io) 'map_view/map_view_mobile.dart';

abstract class MapViewWidget extends StatelessWidget {
  final String url;
  const MapViewWidget.internal({super.key, required this.url});

  factory MapViewWidget({required String url}) => MapViewImpl(url: url);
}

