// lib/screens/trail_map_screen.dart
// ignore_for_file: unused_import

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_compass/flutter_compass.dart';

// Coordenadas das Tags
final List<LatLng> tagCoordinates = [
  LatLng(-19.348935, -43.619372), // Tag 1
  LatLng(-19.349137, -43.616880), // Tag 2
  LatLng(-19.349398, -43.615951), // Tag 3
  LatLng(-19.350161, -43.612595), // Tag 4
  LatLng(-19.354978, -43.606314), // Tag 5
  LatLng(-19.371427, -43.600635), // Tag 6
  LatLng(-19.383878, -43.590989), // Tag 7
  LatLng(-19.384595, -43.589932), // Tag 8
  LatLng(-19.379513, -43.576581), // Tag 9
];

class TrailMapScreen extends StatefulWidget {
  // 1. Recebe os dados da tela "mãe" (LiveTrailScreen)
  final MapController mapController;
  final LatLng? userLocation;
  final double? heading;

  const TrailMapScreen({
    super.key,
    required this.mapController,
    this.userLocation,
    this.heading,
  });

  @override
  State<TrailMapScreen> createState() => _TrailMapScreenState();
}

class _TrailMapScreenState extends State<TrailMapScreen> {
  @override
  Widget build(BuildContext context) {
    // Cria a lista de Marcadores (Markers) para as tags
    final List<Marker> tagMarkers = [];
    for (int i = 0; i < tagCoordinates.length; i++) {
      tagMarkers.add(
        Marker(
          width: 80.0,
          height: 80.0,
          point: tagCoordinates[i],
          child: Tooltip(
            message: 'Tag ${i + 1}',
            child: Column(
              children: [
                Icon(Icons.location_pin, color: Colors.blue, size: 35),
                Text(
                  'T${i + 1}',
                  style: const TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                    backgroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Marcador do Usuário (O "Avatar")
    if (widget.userLocation != null) {
      tagMarkers.add(Marker(
        point: widget.userLocation!,
        width: 60,
        height: 60,
        child: Transform.rotate(
          // Gira o ícone com base na bússola
          angle: ((widget.heading ?? 0) * (3.14159 / 180) ), 
          child: const Icon(Icons.navigation, color: Colors.blueAccent, size: 50),
        ),
      ));
    }

   
    return FlutterMap(
      mapController: widget.mapController, 
      options: MapOptions(
        initialCenter: tagCoordinates.first, 
        initialZoom: 15.0,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.example.aplicativo_trilha',
        ),
        PolylineLayer(
          polylines: [
            Polyline(points: tagCoordinates, color: Colors.red, strokeWidth: 4.0),
          ],
        ),
        MarkerLayer(markers: tagMarkers),
      ],
    );
  }
}