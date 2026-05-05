import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'dart:async';

class TrackOrderScreen extends StatefulWidget {
  const TrackOrderScreen({super.key});

  @override
  State<TrackOrderScreen> createState() => _TrackOrderScreenState();
}

class _TrackOrderScreenState extends State<TrackOrderScreen> {
  // Fixed Shop Location (Hazratganj, Lucknow)
  static const LatLng _shopLocation = LatLng(26.8467, 80.9462);
  
  LatLng? _userLocation;
  String _userAddress = "Your Location";
  
  // Delivery Partner State
  LatLng _partnerLocation = _shopLocation;
  double _progress = 0.0;
  String _orderStatus = "Order Confirmed";
  int _statusStep = 0; // 0: Confirmed, 1: Picked Up, 2: Near You, 3: Delivered

  Timer? _moveTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      if (args != null) {
        setState(() {
          _userLocation = LatLng(args['lat'], args['lng']);
          _userAddress = args['address'];
        });
        _startSimulation();
      }
    });
  }

  void _startSimulation() {
    // Simulate partner moving towards user over 30 seconds for demo
    const duration = Duration(seconds: 30);
    const interval = Duration(milliseconds: 100);
    final totalSteps = duration.inMilliseconds / interval.inMilliseconds;
    int currentStep = 0;

    _moveTimer = Timer.periodic(interval, (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      currentStep++;
      _progress = currentStep / totalSteps;

      if (_progress >= 1.0) {
        timer.cancel();
        setState(() {
          _partnerLocation = _userLocation!;
          _orderStatus = "Delivered";
          _statusStep = 3;
        });
      } else {
        setState(() {
          // Linear interpolation for movement
          double lat = _shopLocation.latitude + (_userLocation!.latitude - _shopLocation.latitude) * _progress;
          double lng = _shopLocation.longitude + (_userLocation!.longitude - _shopLocation.longitude) * _progress;
          _partnerLocation = LatLng(lat, lng);

          // Update status based on progress
          if (_progress < 0.3) {
            _orderStatus = "Order Confirmed";
            _statusStep = 0;
          } else if (_progress < 0.7) {
            _orderStatus = "Picked Up & On the way";
            _statusStep = 1;
          } else {
            _orderStatus = "Arriving Soon";
            _statusStep = 2;
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _moveTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_userLocation == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Track Your Order", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          // 🗺️ Map View
          FlutterMap(
            options: MapOptions(
              initialCenter: LatLng(
                (_shopLocation.latitude + _userLocation!.latitude) / 2,
                (_shopLocation.longitude + _userLocation!.longitude) / 2,
              ),
              initialZoom: 14.5,
            ),
            children: [
              TileLayer(
                urlTemplate: "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
                subdomains: const ['a', 'b', 'c'],
                userAgentPackageName: 'com.edu.xpress.app',
              ),
              // Route Line
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: [_shopLocation, _userLocation!],
                    color: Colors.deepOrange.withOpacity(0.4),
                    strokeWidth: 4,
                    isDotted: true,
                  ),
                ],
              ),
              MarkerLayer(
                markers: [
                  // Shop Marker
                  Marker(
                    point: _shopLocation,
                    width: 40,
                    height: 40,
                    child: const Icon(Icons.store, color: Colors.blue, size: 35),
                  ),
                  // User Marker
                  Marker(
                    point: _userLocation!,
                    width: 40,
                    height: 40,
                    child: const Icon(Icons.location_on, color: Colors.red, size: 35),
                  ),
                  // Delivery Partner Marker
                  Marker(
                    point: _partnerLocation,
                    width: 50,
                    height: 50,
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: [BoxShadow(blurRadius: 4, color: Colors.black.withOpacity(0.1))],
                          ),
                          child: const Text("Partner", style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold)),
                        ),
                        const Icon(Icons.directions_bike, color: Colors.deepOrange, size: 30),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),

          // 📦 Order Status & Info Card
          Positioned(
            bottom: 20,
            left: 15,
            right: 15,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [BoxShadow(blurRadius: 20, color: Colors.black.withOpacity(0.1))],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Status Header
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.deepOrange.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.flash_on, color: Colors.deepOrange),
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_orderStatus, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                            const Text("Arriving in 15-20 mins", style: TextStyle(color: Colors.grey, fontSize: 13)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 30),
                  
                  // Progress Tracker
                  Row(
                    children: List.generate(4, (index) {
                      bool isDone = index <= _statusStep;
                      return Expanded(
                        child: Row(
                          children: [
                            Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: isDone ? Colors.deepOrange : Colors.grey[300],
                                shape: BoxShape.circle,
                              ),
                            ),
                            if (index < 3)
                              Expanded(
                                child: Container(
                                  height: 2,
                                  color: index < _statusStep ? Colors.deepOrange : Colors.grey[300],
                                ),
                              ),
                          ],
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 10),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("Confirmed", style: TextStyle(fontSize: 10, color: Colors.grey)),
                      Text("Picked up", style: TextStyle(fontSize: 10, color: Colors.grey)),
                      Text("Near You", style: TextStyle(fontSize: 10, color: Colors.grey)),
                      Text("Delivered", style: TextStyle(fontSize: 10, color: Colors.grey)),
                    ],
                  ),
                  const SizedBox(height: 20),
                  
                  // Delivery Partner Details
                  Row(
                    children: [
                      const CircleAvatar(
                        radius: 20,
                        backgroundColor: Colors.blueGrey,
                        child: Icon(Icons.person, color: Colors.white),
                      ),
                      const SizedBox(width: 15),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Rahul Kumar", style: TextStyle(fontWeight: FontWeight.bold)),
                            Text("Delivery Partner", style: TextStyle(color: Colors.grey, fontSize: 12)),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () {},
                        icon: const Icon(Icons.phone, color: Colors.green),
                        style: IconButton.styleFrom(backgroundColor: Colors.green.withOpacity(0.1)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
