import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:edu_xpress_frontend/screens/map_picker_screen.dart';

class AddressScreen extends StatefulWidget {
  const AddressScreen({super.key});

  @override
  State<AddressScreen> createState() => _AddressScreenState();
}

class _AddressScreenState extends State<AddressScreen> {
  List addresses = [];
  bool loading = true;
  final String baseUrl = "http://10.184.119.237:5000";

  Future<void> fetchAddresses() async {
    setState(() => loading = true);
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString("token");

    try {
      final res = await http.get(
        Uri.parse("$baseUrl/addresses"),
        headers: {"Authorization": "Bearer $token"},
      );
      if (res.statusCode == 200) {
        setState(() {
          addresses = jsonDecode(res.body);
          loading = false;
        });
      }
    } catch (e) {
      setState(() => loading = false);
    }
  }

  Future<void> deleteAddress(int id) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString("token");

    try {
      final res = await http.delete(
        Uri.parse("$baseUrl/delete-address/$id"),
        headers: {"Authorization": "Bearer $token"},
      );
      if (res.statusCode == 200) {
        fetchAddresses();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Address deleted")));
      }
    } catch (e) {
      debugPrint("Delete error: $e");
    }
  }

  Future<void> selectAddress(Map addr) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString("selected_address", addr['address']);
    await prefs.setString("selected_name", addr['recipient_name'] ?? "");
    await prefs.setString("selected_phone", addr['recipient_phone'] ?? "");
    await prefs.setDouble("selected_lat", addr['latitude']);
    await prefs.setDouble("selected_lng", addr['longitude']);
    Navigator.pop(context, true);
  }

  @override
  void initState() {
    super.initState();
    fetchAddresses();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: const Text("Saved Addresses"),
        backgroundColor: colorScheme.primary,
        elevation: 0,
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : addresses.isEmpty
              ? _buildEmptyState(theme)
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: addresses.length,
                  itemBuilder: (context, index) {
                    final addr = addresses[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 2,
                      child: ListTile(
                        onTap: () => selectAddress(addr),
                        contentPadding: const EdgeInsets.all(16),
                        leading: CircleAvatar(
                          backgroundColor: Colors.deepOrange.withOpacity(0.1),
                          child: const Icon(Icons.location_on, color: Colors.deepOrange),
                        ),
                        title: Text(addr['address'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text("Lat: ${addr['latitude'].toStringAsFixed(4)}, Lng: ${addr['longitude'].toStringAsFixed(4)}",
                              style: TextStyle(fontSize: 12, color: theme.hintColor)),
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.red),
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text("Delete Address?"),
                                content: const Text("Are you sure you want to remove this address?"),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
                                  TextButton(onPressed: () {
                                    Navigator.pop(context);
                                    deleteAddress(addr['id']);
                                  }, child: const Text("Delete", style: TextStyle(color: Colors.red))),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const MapPickerScreen()),
          );
          if (result == true) {
            fetchAddresses();
          }
        },
        label: const Text("Add New Address"),
        icon: const Icon(Icons.add_location_alt),
        backgroundColor: Colors.deepOrange,
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.location_off_outlined, size: 80, color: theme.hintColor),
          const SizedBox(height: 16),
          Text("No addresses saved yet", style: TextStyle(fontSize: 18, color: theme.hintColor)),
          const SizedBox(height: 8),
          Text("Add your delivery location for faster checkout", style: TextStyle(color: theme.hintColor.withOpacity(0.7))),
        ],
      ),
    );
  }
}
