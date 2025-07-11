import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:lottie/lottie.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _controller = TextEditingController();
  List results = [];
  bool isLoading = false;

  Future<void> search(String query) async {
    if (query.trim().isEmpty) return;

    setState(() => isLoading = true);
    final res = await http.get(Uri.parse('http://192.168.117.237:5000/search?q=$query'));
    final data = jsonDecode(res.body);

    setState(() {
      results = data;
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF4E6),
      appBar: AppBar(
        title: const Text("Search Books"),
        backgroundColor: Colors.deepOrange,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _controller,
              onSubmitted: search,
              decoration: InputDecoration(
                hintText: "Search for a book...",
                filled: true,
                fillColor: Colors.white,
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _controller.clear();
                    setState(() => results = []);
                  },
                ),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          if (isLoading)
            const CircularProgressIndicator(color: Colors.deepOrange)
          else if (results.isEmpty && _controller.text.isNotEmpty)
            Expanded(child: Center(child: Lottie.asset("assets/no_results.json", height: 200)))
          else
            Expanded(
              child: ListView.builder(
                itemCount: results.length,
                itemBuilder: (context, index) {
                  final book = results[index];
                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    child: ListTile(
                      leading: const Icon(Icons.book, color: Colors.deepOrange),
                      title: Text(book['name']),
                      trailing: Text("₹ ${book['price']}"),
                    ),
                  );
                },
              ),
            )
        ],
      ),
    );
  }
}
