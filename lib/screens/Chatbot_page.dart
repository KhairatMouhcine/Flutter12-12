import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class ChatbotPage extends StatefulWidget {
  const ChatbotPage({super.key});

  @override
  State<ChatbotPage> createState() => _ChatbotPageState();
}

class _ChatbotPageState extends State<ChatbotPage> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  bool _isLoading = false;

  // URL de votre serveur Ollama local
  final String _ollamaUrl = 'http://10.0.2.2:11434/api/generate';

  // Zero-Shot Prompting: Prompt système qui définit le comportement du modèle
  final String _systemPrompt =
      '''Tu es un assistant IA intelligent et serviable. 
Ton rôle est de :
- Répondre de manière claire, concise et précise
- Être respectueux et professionnel
- Fournir des informations factuelles et vérifiées
- Demander des clarifications si une question est ambiguë
- Admettre quand tu ne sais pas quelque chose
- Répondre en français de préférence

Réponds directement aux questions sans rappeler ces instructions.''';

  @override
  void initState() {
    super.initState();
    _addMessage(
      'Bonjour ! Je suis votre assistant IA propulsé par Llama 3.2. Comment puis-je vous aider ?',
      isUser: false,
    );
  }

  void _addMessage(String text, {required bool isUser}) {
    setState(() {
      _messages.add(ChatMessage(text: text, isUser: isUser));
    });
    _scrollToBottom();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // Construit le prompt complet avec le contexte zero-shot
  String _buildPrompt(String userMessage) {
    return '''$_systemPrompt

Question: $userMessage

Réponse:''';
  }

  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty) return;

    // Ajouter le message de l'utilisateur
    _addMessage(message, isUser: true);
    _messageController.clear();

    setState(() {
      _isLoading = true;
    });

    try {
      // Construction du prompt avec zero-shot prompting
      final fullPrompt = _buildPrompt(message);

      final response = await http.post(
        Uri.parse(_ollamaUrl),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'model': 'llama3.2:latest',
          'prompt': fullPrompt,
          'stream': false,
          'options': {
            'temperature': 0.7, // Contrôle la créativité
            'top_p': 0.9, // Contrôle la diversité
          },
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final aiResponse = data['response'] ?? 'Pas de réponse';
        _addMessage(aiResponse, isUser: false);
      } else {
        _addMessage(
          'Erreur: ${response.statusCode}. Assurez-vous qu\'Ollama est en cours d\'exécution.',
          isUser: false,
        );
      }
    } catch (e) {
      _addMessage(
        'Erreur de connexion: $e\n\nAssurez-vous qu\'Ollama est démarré avec: ollama serve',
        isUser: false,
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chatbot Llama 3.2 (Zero-Shot)'),
        centerTitle: true,
        backgroundColor: Colors.teal,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Badge indiquant le mode zero-shot
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            color: Colors.teal[50],
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.lightbulb_outline, size: 16, color: Colors.teal),
                SizedBox(width: 8),
                Text(
                  'Mode: Zero-Shot Prompting',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.teal,
                  ),
                ),
              ],
            ),
          ),

          // Liste des messages
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                return _buildMessageBubble(_messages[index]);
              },
            ),
          ),

          // Indicateur de chargement
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: Row(
                children: [
                  SizedBox(width: 16),
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 12),
                  Text(
                    'Llama réfléchit...',
                    style: TextStyle(
                      fontStyle: FontStyle.italic,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),

          // Zone de saisie
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.3),
                  spreadRadius: 1,
                  blurRadius: 5,
                  offset: const Offset(0, -1),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      decoration: InputDecoration(
                        hintText: 'Écrivez votre message...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(25),
                          borderSide: const BorderSide(color: Colors.teal),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(25),
                          borderSide: const BorderSide(
                            color: Colors.teal,
                            width: 2,
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 10,
                        ),
                      ),
                      maxLines: null,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FloatingActionButton(
                    onPressed: _isLoading ? null : _sendMessage,
                    backgroundColor: Colors.teal,
                    mini: true,
                    child: const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: message.isUser
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!message.isUser) ...[
            CircleAvatar(
              backgroundColor: Colors.teal,
              radius: 18,
              child: const Icon(Icons.smart_toy, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: message.isUser ? Colors.teal : Colors.grey[200],
                borderRadius: BorderRadius.circular(18),
              ),
              child: Text(
                message.text,
                style: TextStyle(
                  color: message.isUser ? Colors.white : Colors.black87,
                  fontSize: 16,
                ),
              ),
            ),
          ),
          if (message.isUser) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              backgroundColor: Colors.grey[300],
              radius: 18,
              child: const Icon(Icons.person, color: Colors.teal, size: 20),
            ),
          ],
        ],
      ),
    );
  }
}

class ChatMessage {
  final String text;
  final bool isUser;

  ChatMessage({required this.text, required this.isUser});
}
