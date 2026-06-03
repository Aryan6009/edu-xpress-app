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
  int? rating; // Added rating field

  ActiveOrder({
    required this.id,
    required this.userLocation,
    required this.address,
    this.status = "Order Confirmed",
    required this.partnerLocation,
    this.progress = 0.0,
    this.statusStep = 0,
    this.rating,
  });
}

class LiveTrackingService extends ChangeNotifier {
  static final LiveTrackingService _instance = LiveTrackingService._internal();
  factory LiveTrackingService() => _instance;
  LiveTrackingService._internal();

  ActiveOrder? _activeOrder;
  ActiveOrder? get activeOrder => _activeOrder;
  
  // Persist delivered status for the session
  final Set<String> _deliveredOrderIds = {};
  bool isDeliveredLocally(String orderId) => _deliveredOrderIds.contains(orderId);

  static const LatLng _shopLocation = LatLng(26.8467, 80.9462);
  Timer? _moveTimer;

  void setRating(int rating) {
    if (_activeOrder != null) {
      _activeOrder!.rating = rating;
      notifyListeners();
      
      // Auto-clear after rating
      Timer(const Duration(seconds: 2), () {
        _activeOrder = null;
        notifyListeners();
      });
    }
  }

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
    const duration = Duration(seconds: 40); 
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
        
        // Add to delivered set
        _deliveredOrderIds.add(_activeOrder!.id);
        
        notifyListeners();
        timer.cancel();

        // Show Delivery Notification
        _showDeliveryNotification();
        
        // Remove overlay after 20 seconds of "Delivered" if not rated
        Timer(const Duration(seconds: 20), () {
          if (_activeOrder != null && _activeOrder!.rating == null) {
            _activeOrder = null;
            notifyListeners();
          }
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

  void _showDeliveryNotification() {
    final context = navigatorKey.currentContext;
    if (context != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 10),
              Expanded(child: Text("YAY! Your order has been delivered!")),
            ],
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: "VIEW",
            textColor: Colors.white,
            onPressed: () => navigatorKey.currentState?.pushNamed("/orders"),
          ),
        ),
      );
    }
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

        bool isDelivered = activeOrder.status == "Delivered";

        return Positioned(
          bottom: 20,
          left: 15,
          right: 15,
          child: Material(
            elevation: 12,
            borderRadius: BorderRadius.circular(24),
            color: isDelivered ? (activeOrder.rating != null ? Colors.blueGrey : Colors.green) : Colors.white,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 500),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: (isDelivered ? Colors.white : Colors.deepOrange).withOpacity(0.2),
                  width: 1.5,
                ),
              ),
              child: isDelivered && activeOrder.rating == null 
                ? _buildRatingUI(activeOrder)
                : _buildTrackingUI(activeOrder, isDelivered),
            ),
          ),
        );
      },
    );
  }

  Widget _buildRatingUI(ActiveOrder order) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          "How was Arif's delivery?",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(5, (index) {
            return IconButton(
              onPressed: () => LiveTrackingService().setRating(index + 1),
              icon: const Icon(Icons.star_border, color: Colors.white, size: 30),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildTrackingUI(ActiveOrder activeOrder, bool isDelivered) {
    return GestureDetector(
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
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: (isDelivered ? Colors.white : Colors.deepOrange).withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isDelivered ? (activeOrder.rating != null ? Icons.thumb_up : Icons.check_circle) : Icons.directions_bike,
              color: isDelivered ? Colors.white : Colors.deepOrange,
              size: 28,
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  isDelivered 
                    ? (activeOrder.rating != null ? "Thanks for rating Arif!" : "Order Delivered!") 
                    : "Arif is on the way!",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: isDelivered ? Colors.white : Colors.black87,
                  ),
                ),
                Text(
                  isDelivered 
                    ? (activeOrder.rating != null ? "We value your feedback." : "Hope you enjoy your books!") 
                    : "Tracking Mohammad Arif...",
                  style: TextStyle(
                    color: isDelivered ? Colors.white70 : Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          if (!isDelivered)
            SizedBox(
              width: 45,
              height: 45,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircularProgressIndicator(
                    value: activeOrder.progress,
                    backgroundColor: Colors.grey[200],
                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.deepOrange),
                    strokeWidth: 4,
                  ),
                  Text(
                    "${(activeOrder.progress * 100).toInt()}%",
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            )
          else
            const Icon(Icons.arrow_forward_ios, size: 18, color: Colors.white),
        ],
      ),
    );
  }
}
