import 'package:flutter/material.dart';
import '../map_view_widget.dart';

class MapViewImpl extends MapViewWidget {
  const MapViewImpl({super.key, required super.url}) : super.internal();

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('Plataforma não suportada para o mapa'));
  }
}

