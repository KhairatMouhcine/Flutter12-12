import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class OllamaChatScreen extends StatefulWidget {
  const OllamaChatScreen({super.key});

  @override
  State<OllamaChatScreen> createState() => _OllamaChatScreenState();
}

class _OllamaChatScreenState extends State<OllamaChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  bool _isLoading = false;
  bool _apiHealthy = false;
  String _selectedMode = 'zero_shot';
  double _temperature = 0.7;
  int _maxTokens = 1000;
  String _modelInfo = '';

  // 🔧 CONFIGURE TON URL ICI
  // Pour Android Emulator: 'http://10.0.2.2:5003'
  // Pour iOS Simulator: 'http://localhost:5003'
  // Pour vrai téléphone (même WiFi): 'http://TON_IP:5003'
  final String _apiUrl = 'http://10.0.2.2:5003';

  @override
  void initState() {
    super.initState();
    _checkApiHealth();
    _addMessage(
      '👋 Bonjour ! Je suis propulsé par Llama 3.2 via Ollama.\n\n'
      '💭 Mode Zero-Shot: Réponses directes\n'
      '🧠 Mode Chain-of-Thought: Raisonnement étape par étape',
      isUser: false,
    );
  }

  Future<void> _checkApiHealth() async {
    try {
      final response = await http
          .get(Uri.parse('$_apiUrl/health'))
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _apiHealthy = data['ollama_connected'] == true;
          _modelInfo = data['default_model'] ?? 'llama3.2';
        });

        if (!_apiHealthy) {
          _addMessage(
            '⚠️ Ollama n\'est pas connecté. Lancez: ollama serve',
            isUser: false,
          );
        }
      } else {
        setState(() => _apiHealthy = false);
      }
    } catch (e) {
      setState(() => _apiHealthy = false);
      print('❌ Erreur health check: $e');
    }
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

  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty) return;

    if (!_apiHealthy) {
      _addMessage(
        '❌ API non disponible. Vérifiez que Flask et Ollama sont démarrés.',
        isUser: false,
      );
      return;
    }

    _addMessage(message, isUser: true);
    _messageController.clear();

    setState(() => _isLoading = true);

    try {
      final response = await http
          .post(
            Uri.parse('$_apiUrl/chat'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({
              'prompt': message,
              'mode': _selectedMode,
              'temperature': _temperature,
              'max_tokens': _maxTokens,
            }),
          )
          .timeout(const Duration(seconds: 120));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final aiResponse = data['response'] ?? 'Pas de réponse';
        final mode = data['mode'] ?? _selectedMode;

        String prefix = mode == 'chain_of_thought' ? '🧠 ' : '💭 ';
        _addMessage('$prefix$aiResponse', isUser: false);
      } else {
        final data = json.decode(response.body);
        _addMessage(
          '❌ Erreur: ${data['error'] ?? 'HTTP ${response.statusCode}'}',
          isUser: false,
        );
      }
    } catch (e) {
      _addMessage('❌ Erreur de connexion: $e', isUser: false);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showSettings() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '⚙️ Paramètres',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 20),

              // Mode
              const Text('🎯 Mode', style: TextStyle(color: Colors.white70)),
              const SizedBox(height: 8),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'zero_shot', label: Text('Zero-Shot')),
                  ButtonSegment(value: 'chain_of_thought', label: Text('CoT')),
                ],
                selected: {_selectedMode},
                onSelectionChanged: (Set<String> selection) {
                  setModalState(() => _selectedMode = selection.first);
                  setState(() {});
                },
              ),
              const SizedBox(height: 16),

              // Température
              Text(
                '🌡️ Température: ${_temperature.toStringAsFixed(1)}',
                style: const TextStyle(color: Colors.white70),
              ),
              Slider(
                value: _temperature,
                min: 0.0,
                max: 2.0,
                divisions: 20,
                onChanged: (value) {
                  setModalState(() => _temperature = value);
                  setState(() {});
                },
              ),

              // Max Tokens
              Text(
                '📝 Max Tokens: $_maxTokens',
                style: const TextStyle(color: Colors.white70),
              ),
              Slider(
                value: _maxTokens.toDouble(),
                min: 100,
                max: 4000,
                divisions: 39,
                onChanged: (value) {
                  setModalState(() => _maxTokens = value.toInt());
                  setState(() {});
                },
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
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
      backgroundColor: const Color(0xFF0a0e27),
      appBar: AppBar(
        title: const Text('🤖 LLM Chatbot'),
        centerTitle: true,
        backgroundColor: _apiHealthy ? const Color(0xFF667eea) : Colors.red,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _showSettings,
            tooltip: 'Paramètres',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _checkApiHealth,
            tooltip: 'Vérifier connexion',
          ),
        ],
      ),
      body: Column(
        children: [
          // Badge de statut
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: _apiHealthy
                    ? [const Color(0xFF667eea), const Color(0xFF764ba2)]
                    : [Colors.red[700]!, Colors.red[900]!],
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _apiHealthy ? Icons.check_circle : Icons.error,
                  size: 18,
                  color: Colors.white,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _apiHealthy
                        ? '🤖 $_modelInfo • ${_selectedMode == 'zero_shot' ? 'Zero-Shot' : 'Chain-of-Thought'}'
                        : '❌ Non connecté',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                    ),
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
            Container(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  const SizedBox(width: 16),
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.purple[300],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    _selectedMode == 'chain_of_thought'
                        ? 'Raisonnement en cours...'
                        : 'Génération...',
                    style: TextStyle(
                      fontStyle: FontStyle.italic,
                      color: Colors.grey[400],
                    ),
                  ),
                ],
              ),
            ),

          // Zone de saisie
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF1a1f3a),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
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
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Posez votre question...',
                        hintStyle: TextStyle(color: Colors.grey[500]),
                        filled: true,
                        fillColor: const Color(0xFF0a0e27),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(25),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                      ),
                      maxLines: null,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _sendMessage(),
                      enabled: !_isLoading && _apiHealthy,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                      ),
                      borderRadius: BorderRadius.circular(25),
                    ),
                    child: IconButton(
                      onPressed: (_isLoading || !_apiHealthy)
                          ? null
                          : _sendMessage,
                      icon: const Icon(Icons.send, color: Colors.white),
                    ),
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
            const CircleAvatar(
              backgroundColor: Color(0xFF667eea),
              radius: 18,
              child: Text('🤖', style: TextStyle(fontSize: 16)),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                gradient: message.isUser
                    ? const LinearGradient(
                        colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                      )
                    : null,
                color: message.isUser ? null : const Color(0xFF1a1f3a),
                borderRadius: BorderRadius.circular(18),
                border: message.isUser
                    ? null
                    : Border.all(
                        color: const Color(0xFF667eea).withOpacity(0.3),
                      ),
              ),
              child: Text(
                message.text,
                style: const TextStyle(color: Colors.white, fontSize: 15),
              ),
            ),
          ),
          if (message.isUser) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              backgroundColor: Colors.grey[700],
              radius: 18,
              child: const Icon(Icons.person, color: Colors.white, size: 20),
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
