import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:edu_xpress_frontend/widgets/book_bot.dart';
import 'package:edu_xpress_frontend/services/api_config.dart';

class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final bool isError;
  final List<dynamic>? products;

  ChatMessage({
    required this.text, 
    required this.isUser, 
    required this.timestamp,
    this.isError = false,
    this.products,
  });
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final GlobalKey<AnimatedListState> _listKey = GlobalKey<AnimatedListState>();
  final List<ChatMessage> _messages = [];
  bool _isLoading = false;
  Map<int, int> cartQuantities = {};

  @override
  void initState() {
    super.initState();
    _fetchCartState();
    _fetchChatHistory(); // Load previous messages
    
    Future.delayed(const Duration(milliseconds: 500), () {
      if (_messages.isEmpty) {
        _addMessage(ChatMessage(
          text: "Hello! I'm your Edu-Xpress Assistant. I can find books in our catalog or suggest others from across the web. How can I help?",
          isUser: false,
          timestamp: DateTime.now(),
        ));
      }

      // Handle Prefill from arguments
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
        if (args != null && args.containsKey('prefill')) {
          _controller.text = args['prefill'];
          _sendMessage();
        }
      });
    });
  }

  Future<void> _fetchChatHistory() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString("token");
      if (token == null) return;

      final res = await http.get(
        Uri.parse("${ApiConfig.baseUrl}/chat/history"),
        headers: {"Authorization": "Bearer $token"},
      );

      if (res.statusCode == 200) {
        final List data = jsonDecode(res.body);
        if (data.isNotEmpty) {
          for (var h in data) {
            _addMessage(ChatMessage(
              text: h["message"],
              isUser: true,
              timestamp: h["timestamp"] != null ? DateTime.parse(h["timestamp"]) : DateTime.now(),
            ));
            _addMessage(ChatMessage(
              text: h["reply"],
              isUser: false,
              timestamp: h["timestamp"] != null ? DateTime.parse(h["timestamp"]) : DateTime.now(),
            ));
          }
        }
      }
    } catch (e) {
      debugPrint("Error fetching chat history: $e");
    }
  }

  Future<void> _fetchCartState() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString("token");
    if (token == null) return;

    try {
      final res = await http.get(
        Uri.parse("${ApiConfig.baseUrl}/cart"),
        headers: {"Authorization": "Bearer $token"},
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final Map<int, int> newQtys = {};
        for (var item in data["cart"]) {
          newQtys[item["product_id"]] = item["quantity"];
        }
        if (mounted) setState(() => cartQuantities = newQtys);
      }
    } catch (e) {
      debugPrint("Cart fetch error: $e");
    }
  }

  Future<void> _updateCart(Map product, bool increase) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString("token");
    if (token == null) return;

    int pid = product['id'];
    try {
      final url = increase ? "${ApiConfig.baseUrl}/cart/add" : "${ApiConfig.baseUrl}/cart/decrease/$pid";
      final res = increase 
        ? await http.post(Uri.parse(url), headers: {"Content-Type": "application/json", "Authorization": "Bearer $token"}, body: jsonEncode({"product_id": pid, "product_name": product['name'], "price": product['price']}))
        : await http.post(Uri.parse(url), headers: {"Authorization": "Bearer $token"});

      if (res.statusCode == 200 || res.statusCode == 201) {
        setState(() {
          int current = cartQuantities[pid] ?? 0;
          if (increase) {
            cartQuantities[pid] = current + 1;
          } else if (current > 0) {
            if (current == 1) cartQuantities.remove(pid);
            else cartQuantities[pid] = current - 1;
          }
        });
      }
    } catch (e) {
      debugPrint("Cart update error: $e");
    }
  }

  void _addMessage(ChatMessage message) {
    _messages.add(message);
    _listKey.currentState?.insertItem(_messages.length - 1, duration: const Duration(milliseconds: 500));
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOutBack,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    if (_controller.text.trim().isEmpty) return;

    final userText = _controller.text.trim();
    _controller.clear();

    _addMessage(ChatMessage(
      text: userText,
      isUser: true,
      timestamp: DateTime.now(),
    ));

    setState(() => _isLoading = true);
    _scrollToBottom();

    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString("token");

      final response = await http.post(
        Uri.parse("${ApiConfig.baseUrl}/chat"),
        headers: {
          "Content-Type": "application/json",
          if (token != null) "Authorization": "Bearer $token",
        },
        body: jsonEncode({"message": userText}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _addMessage(ChatMessage(
          text: data["reply"],
          isUser: false,
          timestamp: DateTime.now(),
          products: data["products"],
        ));
      } else {
        _addMessage(ChatMessage(
          text: "I'm having a little trouble connecting. Could you try that again?",
          isUser: false,
          timestamp: DateTime.now(),
          isError: true,
        ));
      }
    } catch (e) {
      _addMessage(ChatMessage(
        text: "Connection lost. Please check your internet and try again.",
        isUser: false,
        timestamp: DateTime.now(),
        isError: true,
      ));
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
        _scrollToBottom();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        elevation: 0,
        centerTitle: true,
        backgroundColor: colorScheme.primary,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const BookBot(size: 30, state: BookBotState.idle),
            const SizedBox(width: 10),
            const Column(
              children: [
                Text(
                  "Edu-Xpress Assistant",
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(radius: 3, backgroundColor: Colors.green),
                    SizedBox(width: 4),
                    Text("Online", style: TextStyle(color: Colors.white70, fontSize: 10)),
                  ],
                )
              ],
            ),
          ],
        ),
      ),
      body: Stack(
        children: [
          Column(
            children: [
              Expanded(
                child: AnimatedList(
                  key: _listKey,
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                  initialItemCount: _messages.length,
                  itemBuilder: (context, index, animation) {
                    return FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: animation.drive(Tween(
                          begin: const Offset(0, 0.2),
                          end: Offset.zero,
                        ).chain(CurveTween(curve: Curves.easeOutCubic))),
                        child: _buildChatBubble(_messages[index], theme),
                      ),
                    );
                  },
                ),
              ),
              _buildInputArea(theme),
            ],
          ),
          if (_isLoading)
            Positioned(
              left: 20,
              bottom: 85,
              child: _buildTypingMascot(),
            ),
        ],
      ),
    );
  }

  Widget _buildTypingMascot() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          BookBot(size: 25, state: BookBotState.idle),
          SizedBox(width: 8),
          Text(
            "Edu-AI is typing...",
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.deepOrange),
          ),
        ],
      ),
    );
  }

  Widget _buildChatBubble(ChatMessage message, ThemeData theme) {
    bool isUser = message.isUser;
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!isUser) ...[
                const BookBot(size: 25, state: BookBotState.idle),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Column(
                  crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                  children: [
                    Container(
                      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.7),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: isUser 
                            ? theme.colorScheme.primary 
                            : (message.isError ? Colors.red.withOpacity(0.1) : theme.cardColor),
                        borderRadius: BorderRadius.only(
                          topLeft: const Radius.circular(20),
                          topRight: const Radius.circular(20),
                          bottomLeft: Radius.circular(isUser ? 20 : 0),
                          bottomRight: Radius.circular(isUser ? 0 : 20),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          )
                        ],
                        border: message.isError ? Border.all(color: Colors.red.withOpacity(0.3)) : null,
                      ),
                      child: Text(
                        message.text,
                        style: TextStyle(
                          color: isUser ? Colors.white : (message.isError ? Colors.red[300] : theme.textTheme.bodyMedium?.color),
                          fontSize: 15,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (isUser) ...[
                const SizedBox(width: 8),
                CircleAvatar(
                  radius: 14,
                  backgroundColor: theme.colorScheme.primary.withOpacity(0.2),
                  child: Icon(Icons.person, size: 18, color: theme.colorScheme.primary),
                ),
              ],
            ],
          ),
          if (message.products != null && message.products!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 33, top: 10),
              child: SizedBox(
                height: 180,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: message.products!.length,
                  itemBuilder: (context, i) => _buildProductCard(message.products![i], theme),
                ),
              ),
            ),
          Padding(
            padding: EdgeInsets.only(
              left: isUser ? 0 : 40, 
              right: isUser ? 40 : 0, 
              bottom: 2,
            ),
            child: Text(
              DateFormat('hh:mm a').format(message.timestamp),
              style: TextStyle(color: theme.hintColor.withOpacity(0.5), fontSize: 9),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductCard(dynamic product, ThemeData theme) {
    int pid = product['id'];
    int qty = cartQuantities[pid] ?? 0;

    return Container(
      width: 140,
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.grey.withOpacity(0.2)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 5)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
              child: Image.network(
                product['image'] != null
                    ? (product['image'].toString().startsWith("http") ? product['image'] : "${ApiConfig.baseUrl}/uploads/product_images/${product['image']}")
                    : "",
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (c, e, s) => const Center(child: Icon(Icons.book, color: Colors.deepOrange)),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(product['name'], style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                Text("₹${product['price']}", style: const TextStyle(fontSize: 10, color: Colors.deepOrange, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                qty == 0 
                  ? SizedBox(
                      width: double.infinity,
                      height: 28,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(padding: EdgeInsets.zero),
                        onPressed: () => _updateCart(product, true),
                        child: const Text("Add", style: TextStyle(fontSize: 10)),
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        InkWell(onTap: () => _updateCart(product, false), child: const Icon(Icons.remove_circle_outline, size: 18, color: Colors.deepOrange)),
                        Text("$qty", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        InkWell(onTap: () => _updateCart(product, true), child: const Icon(Icons.add_circle_outline, size: 18, color: Colors.deepOrange)),
                      ],
                    ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputArea(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: theme.cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            offset: const Offset(0, -4),
            blurRadius: 10,
          )
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                decoration: BoxDecoration(
                  color: theme.brightness == Brightness.dark ? const Color(0xFF2C2C2C) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: TextField(
                  controller: _controller,
                  style: const TextStyle(fontSize: 15),
                  decoration: InputDecoration(
                    hintText: "Ask about books or orders...",
                    border: InputBorder.none,
                    hintStyle: TextStyle(color: theme.hintColor),
                  ),
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
            ),
            const SizedBox(width: 12),
            GestureDetector(
              onTap: _sendMessage,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.all(12),
                decoration: const BoxDecoration(
                  color: Colors.deepOrange,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.send_rounded, color: Colors.white, size: 22),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
