import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:lottie/lottie.dart';
import 'package:edu_xpress_frontend/widgets/chatbot_fab.dart';

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
    final res = await http.get(Uri.parse('http://10.184.119.237:5000/search?q=$query'));
    final data = jsonDecode(res.body);

    setState(() {
      results = data;
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: const Text("Search Books"),
        backgroundColor: colorScheme.primary,
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
                fillColor: theme.cardColor,
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
      floatingActionButton: const ChatBotFAB(),
    );
  }
}
