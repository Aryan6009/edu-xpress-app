import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';

class MapPickerScreen extends StatefulWidget {
  const MapPickerScreen({super.key});

  @override
  State<MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends State<MapPickerScreen> {
  LatLng _selectedLocation = const LatLng(26.8467, 80.9462); // Default: Lucknow
  String _address = "Select a location";
  String _currentCity = ""; 
  final MapController _mapController = MapController();
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _houseController = TextEditingController();
  final TextEditingController _landmarkController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  bool _isLoading = false;
  bool _isSearching = false;
  List<dynamic> _suggestions = [];
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _addressController.text = _address;
    _getCurrentLocation();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _addressController.dispose();
    _houseController.dispose();
    _landmarkController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (query.length > 2) {
        _fetchSuggestions(query);
      } else {
        setState(() => _suggestions = []);
      }
    });
  }

  Future<void> _fetchSuggestions(String query) async {
    setState(() => _isSearching = true);
    try {
      List<dynamic> features = await _performSearch(query);

      // 1. If empty, try appending the current city for context
      if (features.isEmpty && _currentCity.isNotEmpty && !query.toLowerCase().contains(_currentCity.toLowerCase())) {
        features = await _performSearch("$query, $_currentCity");
      }

      // 2. If still empty, perform a "fuzzy" search by stripping specific house/plot numbers
      if (features.isEmpty && query.contains("/")) {
        String fuzzyQuery = query.split("/").first; // e.g., "sec-18" from "sec-18/45/302"
        if (fuzzyQuery.length > 2) {
          features = await _performSearch(fuzzyQuery);
          if (features.isEmpty && _currentCity.isNotEmpty) {
            features = await _performSearch("$fuzzyQuery, $_currentCity");
          }
        }
      }

      setState(() {
        _suggestions = features;
      });
    } catch (e) {
      print("Suggestion error: $e");
    } finally {
      setState(() => _isSearching = false);
    }
  }

  Future<List<dynamic>> _performSearch(String query) async {
    // Stage A: Photon API
    final uri = Uri.https("photon.komoot.io", "/api/", {
      "q": query,
      "limit": "5",
      "lat": _selectedLocation.latitude.toString(),
      "lon": _selectedLocation.longitude.toString(),
    });

    final res = await http.get(uri);
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      List<dynamic> features = data["features"];
      if (features.isNotEmpty) return features;
    }

    // Stage B: Nominatim Fallback with Biasing
    final nomUri = Uri.https("nominatim.openstreetmap.org", "/search", {
      "q": query,
      "format": "json",
      "limit": "3",
      "countrycodes": "in",
      "viewbox": "${_selectedLocation.longitude - 1},${_selectedLocation.latitude - 1},${_selectedLocation.longitude + 1},${_selectedLocation.latitude + 1}",
    });
    
    final nomRes = await http.get(nomUri, headers: {"User-Agent": "edu_xpress_app"});
    if (nomRes.statusCode == 200) {
      final nomData = jsonDecode(nomRes.body);
      return nomData.map<dynamic>((e) => {
        "properties": {
          "name": e["display_name"].split(",").first.trim(),
          "city": e["display_name"].split(",").length > 1 ? e["display_name"].split(",")[1].trim() : null,
          "state": "India"
        },
        "geometry": {"coordinates": [double.parse(e["lon"]), double.parse(e["lat"])]}
      }).toList();
    }
    
    return [];
  }

  void _selectSuggestion(dynamic suggestion) {
    final coords = suggestion["geometry"]["coordinates"];
    final lat = coords[1];
    final lon = coords[0];
    final newLoc = LatLng(lat, lon);
    
    final props = suggestion["properties"];
    List<String> addressParts = [];
    if (props["name"] != null) addressParts.add(props["name"]);
    if (props["street"] != null) addressParts.add(props["street"]);
    if (props["city"] != null) addressParts.add(props["city"]);
    if (props["state"] != null) addressParts.add(props["state"]);
    
    String formattedAddress = addressParts.join(", ");
    
    setState(() {
      _selectedLocation = newLoc;
      _address = formattedAddress;
      _suggestions = [];
      _searchController.text = formattedAddress;
      _addressController.text = formattedAddress;
      _mapController.move(newLoc, 16);
    });
    FocusScope.of(context).unfocus();
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _isLoading = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Location services are disabled.")));
        setState(() => _isLoading = false);
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Location permissions are denied.")));
          setState(() => _isLoading = false);
          return;
        }
      }
      
      if (permission == LocationPermission.deniedForever) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Location permissions are permanently denied.")));
        setState(() => _isLoading = false);
        return;
      }

      // 1. Use Geolocator to get current position
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      // 4. Add debug logs
      print("Location: ${position.latitude}, ${position.longitude}");

      // 2. Update map center and 3. Use setState
      setState(() {
        _selectedLocation = LatLng(position.latitude, position.longitude);
        _suggestions = [];
        // 6. Use controller.move
        _mapController.move(_selectedLocation, 17);
      });
      
      _reverseGeocode(_selectedLocation);
      
    } catch (e) {
      print("Location error: $e");
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Could not fetch current location.")));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _reverseGeocode(LatLng location) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        location.latitude,
        location.longitude,
      );
      if (placemarks.isNotEmpty) {
        Placemark p = placemarks.first;
        setState(() {
          _currentCity = p.locality ?? "";
          String formattedAddr = "${p.name}, ${p.subLocality}, ${p.locality}, ${p.administrativeArea} ${p.postalCode}";
          _address = formattedAddr;
          _addressController.text = formattedAddr;
          _searchController.text = formattedAddr;
        });
      }
    } catch (e) {
      String latLngAddr = "Lat: ${location.latitude.toStringAsFixed(4)}, Lng: ${location.longitude.toStringAsFixed(4)}";
      setState(() {
        _address = latLngAddr;
        _addressController.text = latLngAddr;
      });
    }
  }

  Future<void> _saveAddress() async {
    // Combine fields for the final address
    String house = _houseController.text.trim();
    String landmark = _landmarkController.text.trim();
    String area = _addressController.text.trim();
    
    String finalAddress = "";
    if (house.isNotEmpty) finalAddress += "$house, ";
    finalAddress += area;
    if (landmark.isNotEmpty) finalAddress += " (Landmark: $landmark)";
    
    if (area.isEmpty || area == "Select a location") {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please select a valid area on map")));
      return;
    }

    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString("token");

    setState(() => _isLoading = true);
    final response = await http.post(
      Uri.parse("http://10.184.119.237:5000/save-address"),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token"
      },
      body: jsonEncode({
        "address": finalAddress,
        "recipient_name": _nameController.text.trim(),
        "recipient_phone": _phoneController.text.trim(),
        "latitude": _selectedLocation.latitude,
        "longitude": _selectedLocation.longitude,
      }),
    );

    if (response.statusCode == 201) {
      if (mounted) Navigator.pop(context, true);
    } else {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Failed to save address")));
    }
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Select Delivery Location"),
        backgroundColor: colorScheme.surface,
        foregroundColor: theme.textTheme.titleLarge?.color,
        elevation: 0,
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _selectedLocation,
              initialZoom: 16,
              onTap: (tapPosition, point) {
                setState(() {
                   _selectedLocation = point;
                   _suggestions = [];
                });
                _reverseGeocode(point);
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.edu_xpress',
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: _selectedLocation,
                    width: 50,
                    height: 50,
                    child: const Icon(Icons.location_on, color: Colors.deepOrange, size: 45),
                  ),
                ],
              ),
            ],
          ),
          
          // Search Bar Overlay
          Positioned(
            top: 15,
            left: 15,
            right: 15,
            child: Column(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: theme.cardColor,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8, offset: const Offset(0, 2))],
                  ),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: "Search area, street or city...",
                      prefixIcon: const Icon(Icons.search, color: Colors.deepOrange),
                      suffixIcon: _isSearching 
                          ? const Padding(padding: EdgeInsets.all(12), child: SizedBox(height: 10, width: 10, child: CircularProgressIndicator(strokeWidth: 2)))
                          : IconButton(icon: const Icon(Icons.clear), onPressed: () {
                              _searchController.clear();
                              setState(() => _suggestions = []);
                            }),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 15),
                    ),
                    onChanged: _onSearchChanged,
                  ),
                ),
                if (_suggestions.isNotEmpty || (_searchController.text.length > 2 && !_isSearching && _suggestions.isEmpty))
                  Container(
                    margin: const EdgeInsets.only(top: 5),
                    constraints: const BoxConstraints(maxHeight: 250),
                    decoration: BoxDecoration(
                      color: theme.cardColor,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8)],
                    ),
                    child: _suggestions.isEmpty 
                      ? const ListTile(
                          leading: Icon(Icons.info_outline, color: Colors.grey),
                          title: Text("No results found. Try adding city name.", style: TextStyle(fontSize: 13, color: Colors.grey)),
                        )
                      : ListView.separated(
                          shrinkWrap: true,
                          padding: EdgeInsets.zero,
                          itemCount: _suggestions.length,
                          separatorBuilder: (context, index) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final s = _suggestions[index];
                            final props = s["properties"];
                            String title = props["name"] ?? "";
                            String subtitle = [props["city"], props["state"], props["country"]]
                                .where((e) => e != null && e != title)
                                .join(", ");
                            
                            return ListTile(
                              leading: const Icon(Icons.location_on_outlined, size: 20),
                              title: Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                              subtitle: subtitle.isNotEmpty ? Text(subtitle, style: const TextStyle(fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis) : null,
                              onTap: () => _selectSuggestion(s),
                            );
                          },
                        ),
                  ),
              ],
            ),
          ),

          // Bottom Address Form
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: const BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, spreadRadius: 2)],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.location_on, color: Colors.deepOrange, size: 24),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _address == "Select a location" ? "Select delivery area" : _address,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      TextButton(
                        onPressed: () => _searchController.clear(),
                        child: const Text("Change", style: TextStyle(color: Colors.deepOrange)),
                      ),
                    ],
                  ),
                  const Divider(),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _buildInputField(
                          controller: _houseController,
                          hint: "House / Flat / Floor No.",
                          theme: theme,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildInputField(
                          controller: _landmarkController,
                          hint: "Landmark (Optional)",
                          theme: theme,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _buildInputField(
                          controller: _nameController,
                          hint: "Recipient Name",
                          theme: theme,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildInputField(
                          controller: _phoneController,
                          hint: "Recipient Phone",
                          theme: theme,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _buildInputField(
                    controller: _addressController,
                    hint: "Area / Street / Locality",
                    maxLines: 2,
                    theme: theme,
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _saveAddress,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepOrange,
                      minimumSize: const Size(double.infinity, 55),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _isLoading 
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text("Save & Proceed", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ),

          // Locate Me Button (Moved to end for top-layer and higher bottom offset)
          Positioned(
            right: 15,
            bottom: 400, // Increased from 300 to avoid overlap
            child: FloatingActionButton(
              mini: true,
              backgroundColor: theme.cardColor,
              onPressed: _getCurrentLocation,
              child: const Icon(Icons.my_location, color: Colors.deepOrange),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputField({required TextEditingController controller, required String hint, int maxLines = 1, required ThemeData theme}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: theme.brightness == Brightness.dark ? const Color(0xFF2C2C2C) : Colors.grey[100],
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: theme.dividerColor),
      ),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        style: const TextStyle(fontSize: 14),
        decoration: InputDecoration(
          border: InputBorder.none,
          hintText: hint,
          hintStyle: TextStyle(color: theme.hintColor, fontSize: 13),
        ),
      ),
    );
  }
}
