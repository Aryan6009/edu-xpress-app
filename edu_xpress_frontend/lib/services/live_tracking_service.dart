import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'dart:async';
import 'package:edu_xpress_frontend/main.dart'; // Add this import

class ActiveOrder {
  final String id;
  final LatLng userLocation;
  final String address;
  String status;
  LatLng partnerLocation;
  double progress;
  int statusStep;

  ActiveOrder({
    required this.id,
    required this.userLocation,
    required this.address,
    this.status = "Order Confirmed",
    required this.partnerLocation,
    this.progress = 0.0,
    this.statusStep = 0,
  });
}

class LiveTrackingService extends ChangeNotifier {
  static final LiveTrackingService _instance = LiveTrackingService._internal();
  factory LiveTrackingService() => _instance;
  LiveTrackingService._internal();

  ActiveOrder? _activeOrder;
  ActiveOrder? get activeOrder => _activeOrder;

  static const LatLng _shopLocation = LatLng(26.8467, 80.9462);
  Timer? _moveTimer;

  void startTracking({required String orderId, required double lat, required double lng, required String address}) {
    _moveTimer?.cancel();
    
    _activeOrder = ActiveOrder(
      id: orderId,
      userLocation: LatLng(lat, lng),
      address: address,
      partnerLocation: _shopLocation,
    );
    notifyListeners();

    // Simulate movement
    const duration = Duration(seconds: 40); // Slightly longer for the persistent overlay
    const interval = Duration(milliseconds: 500);
    final totalSteps = duration.inMilliseconds / interval.inMilliseconds;
    int currentStep = 0;

    _moveTimer = Timer.periodic(interval, (timer) {
      if (_activeOrder == null) {
        timer.cancel();
        return;
      }

      currentStep++;
      _activeOrder!.progress = currentStep / totalSteps;

      if (_activeOrder!.progress >= 1.0) {
        _activeOrder!.progress = 1.0;
        _activeOrder!.status = "Delivered";
        _activeOrder!.statusStep = 3;
        _activeOrder!.partnerLocation = _activeOrder!.userLocation;
        notifyListeners();
        timer.cancel();
        
        // Remove overlay after 10 seconds of "Delivered"
        Timer(const Duration(seconds: 10), () {
          _activeOrder = null;
          notifyListeners();
        });
      } else {
        double lat = _shopLocation.latitude + (_activeOrder!.userLocation.latitude - _shopLocation.latitude) * _activeOrder!.progress;
        double lng = _shopLocation.longitude + (_activeOrder!.userLocation.longitude - _shopLocation.longitude) * _activeOrder!.progress;
        _activeOrder!.partnerLocation = LatLng(lat, lng);

        if (_activeOrder!.progress < 0.3) {
          _activeOrder!.status = "Order Confirmed";
          _activeOrder!.statusStep = 0;
        } else if (_activeOrder!.progress < 0.7) {
          _activeOrder!.status = "Picked Up";
          _activeOrder!.statusStep = 1;
        } else {
          _activeOrder!.status = "Arriving Soon";
          _activeOrder!.statusStep = 2;
        }
        notifyListeners();
      }
    });
  }

  void clearTracking() {
    _activeOrder = null;
    _moveTimer?.cancel();
    notifyListeners();
  }
}

class LiveTrackingOverlay extends StatelessWidget {
  const LiveTrackingOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: LiveTrackingService(),
      builder: (context, child) {
        final activeOrder = LiveTrackingService().activeOrder;
        if (activeOrder == null) return const SizedBox.shrink();

        return Positioned(
          bottom: 10,
          left: 10,
          right: 10,
          child: GestureDetector(
            onTap: () {
              navigatorKey.currentState?.pushNamed(
                "/track_order",
                arguments: {
                  "address": activeOrder.address,
                  "lat": activeOrder.userLocation.latitude,
                  "lng": activeOrder.userLocation.longitude,
                }
              );
            },
            child: Material(
              elevation: 10,
              borderRadius: BorderRadius.circular(20),
              color: Colors.white,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.deepOrange.withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.deepOrange.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.directions_bike, color: Colors.deepOrange, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(activeOrder.status, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          Text("Tracking your delivery...", style: TextStyle(color: Colors.grey[600], fontSize: 11)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 40,
                      height: 40,
                      child: CircularProgressIndicator(
                        value: activeOrder.progress,
                        backgroundColor: Colors.grey[200],
                        valueColor: const AlwaysStoppedAnimation<Color>(Colors.deepOrange),
                        strokeWidth: 3,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
