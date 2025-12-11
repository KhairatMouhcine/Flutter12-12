import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import 'dart:convert';

class RagChatScreen extends StatefulWidget {
  const RagChatScreen({super.key});

  @override
  State<RagChatScreen> createState() => _RagChatScreenState();
}

class _RagChatScreenState extends State<RagChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  bool _isLoading = false;
  bool _isUploading = false;
  String? _sessionId;
  int _uploadedFiles = 0;

  final String _apiUrl = "http://100.112.11.220:5002";

  @override
  void initState() {
    super.initState();
    _createSession();
  }

  Future<void> _createSession() async {
    setState(() => _isLoading = true);

    try {
      final response = await http
          .post(Uri.parse('$_apiUrl/session'))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() => _sessionId = data['session_id']);
        _addMessage(
          '👋 Bonjour ! Session RAG créée avec succès.\n\n'
          '📄 Vous pouvez télécharger des fichiers (PDF, TXT, etc.) en cliquant sur le bouton 📎\n\n'
          '💬 Posez-moi des questions sur vos documents !',
          isUser: false,
        );
      } else {
        _addMessage(
          '❌ Erreur lors de la création de la session.',
          isUser: false,
        );
      }
    } catch (e) {
      _addMessage(
        '❌ Impossible de se connecter au serveur.\n\nVérifiez que le serveur Flask est démarré sur le port 5002.',
        isUser: false,
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _uploadFile() async {
    if (_sessionId == null) {
      _addMessage('❌ Aucune session active.', isUser: false);
      return;
    }

    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'txt', 'md', 'json', 'csv'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;

      if (file.bytes == null) {
        _addMessage('❌ Impossible de lire le fichier.', isUser: false);
        return;
      }

      setState(() => _isUploading = true);
      _addMessage('📤 Envoi de "${file.name}"...', isUser: true);

      var request = http.MultipartRequest('POST', Uri.parse('$_apiUrl/upload'));
      request.fields['session_id'] = _sessionId!;
      request.files.add(
        http.MultipartFile.fromBytes('file', file.bytes!, filename: file.name),
      );

      final streamedResponse = await request.send().timeout(
        const Duration(seconds: 60),
      );
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final chunks = data['chunks'] ?? 0;
        setState(() => _uploadedFiles++);
        _addMessage(
          '✅ Fichier "${file.name}" ingéré avec succès !\n📊 $chunks chunks créés et indexés.',
          isUser: false,
        );
      } else {
        final data = json.decode(response.body);
        _addMessage(
          '❌ Erreur: ${data['error'] ?? 'Erreur inconnue'}',
          isUser: false,
        );
      }
    } catch (e) {
      _addMessage('❌ Erreur lors du téléchargement: $e', isUser: false);
    } finally {
      setState(() => _isUploading = false);
    }
  }

  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty) return;

    if (_sessionId == null) {
      _addMessage('❌ Aucune session active.', isUser: false);
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
            body: json.encode({'session_id': _sessionId, 'prompt': message}),
          )
          .timeout(const Duration(seconds: 120));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final aiResponse = data['response'] ?? 'Pas de réponse';
        final contextUsed = data['context_used'] == true;
        String prefix = contextUsed ? '📚 ' : '💭 ';
        _addMessage('$prefix$aiResponse', isUser: false);
      } else {
        final data = json.decode(response.body);
        _addMessage(
          '❌ Erreur: ${data['error'] ?? 'Erreur HTTP ${response.statusCode}'}',
          isUser: false,
        );
      }
    } catch (e) {
      _addMessage('❌ Erreur de connexion: $e', isUser: false);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _addMessage(String text, {required bool isUser}) {
    setState(() => _messages.add(ChatMessage(text: text, isUser: isUser)));
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

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isConnected = _sessionId != null;

    return Scaffold(
      backgroundColor: const Color(0xFF0a0e27),
      appBar: AppBar(
        title: const Text(
          '🎓 EMSI RAG Assistant',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isConnected
                  ? [const Color(0xFF667eea), const Color(0xFF764ba2)]
                  : [Colors.red[700]!, Colors.red[900]!],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() {
                _sessionId = null;
                _messages.clear();
                _uploadedFiles = 0;
              });
              _createSession();
            },
            tooltip: 'Nouvelle session',
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0a0e27), Color(0xFF1a1f3a)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Column(
          children: [
            // Badge de statut
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isConnected
                      ? [
                          const Color(0xFF667eea).withOpacity(0.3),
                          const Color(0xFF764ba2).withOpacity(0.3),
                        ]
                      : [
                          Colors.red.withOpacity(0.3),
                          Colors.red[900]!.withOpacity(0.3),
                        ],
                ),
                border: Border(
                  bottom: BorderSide(
                    color: isConnected
                        ? const Color(0xFF667eea).withOpacity(0.3)
                        : Colors.red.withOpacity(0.3),
                  ),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: isConnected
                          ? const Color(0xFF667eea).withOpacity(0.3)
                          : Colors.red.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      isConnected ? Icons.check_circle : Icons.error,
                      size: 18,
                      color: isConnected ? const Color(0xFF667eea) : Colors.red,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isConnected ? 'Session Active' : 'Non connecté',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: isConnected ? Colors.white : Colors.red[300],
                          ),
                        ),
                        if (isConnected)
                          Text(
                            '$_uploadedFiles fichier(s) chargé(s)',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[400],
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (isConnected) _buildUploadButton(),
                ],
              ),
            ),

            // Liste des messages
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(16),
                itemCount: _messages.length,
                itemBuilder: (context, index) =>
                    _buildMessageBubble(_messages[index]),
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
                      'Le modèle analyse et génère une réponse...',
                      style: TextStyle(
                        fontStyle: FontStyle.italic,
                        color: Colors.grey[400],
                      ),
                    ),
                  ],
                ),
              ),

            // Zone de saisie
            _buildInputArea(isConnected),
          ],
        ),
      ),
    );
  }

  Widget _buildUploadButton() {
    return GestureDetector(
      onTap: _isUploading ? null : _uploadFile,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFf093fb), Color(0xFFf5576c)],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFf093fb).withOpacity(0.4),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_isUploading)
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            else
              const Icon(Icons.attach_file, size: 18, color: Colors.white),
            const SizedBox(width: 6),
            Text(
              _isUploading ? 'Envoi...' : 'Ajouter',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputArea(bool isConnected) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1a1f3a),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Bouton upload
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF667eea).withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              onPressed: (_isUploading || !isConnected) ? null : _uploadFile,
              icon: Icon(
                Icons.attach_file,
                color: isConnected ? const Color(0xFF667eea) : Colors.grey,
              ),
              tooltip: 'Télécharger un fichier',
            ),
          ),
          const SizedBox(width: 12),
          // Champ de texte
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
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25),
                  borderSide: const BorderSide(
                    color: Color(0xFF667eea),
                    width: 2,
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
              ),
              maxLines: null,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _sendMessage(),
              enabled: !_isLoading && isConnected,
            ),
          ),
          const SizedBox(width: 12),
          // Bouton envoyer
          Container(
            decoration: BoxDecoration(
              gradient: isConnected
                  ? const LinearGradient(
                      colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                    )
                  : null,
              color: isConnected ? null : Colors.grey,
              borderRadius: BorderRadius.circular(25),
              boxShadow: isConnected
                  ? [
                      BoxShadow(
                        color: const Color(0xFF667eea).withOpacity(0.4),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            child: IconButton(
              onPressed: (_isLoading || !isConnected) ? null : _sendMessage,
              icon: const Icon(Icons.send, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: message.isUser
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!message.isUser) ...[
            Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const CircleAvatar(
                backgroundColor: Color(0xFF1a1f3a),
                radius: 18,
                child: Text('🎓', style: TextStyle(fontSize: 16)),
              ),
            ),
            const SizedBox(width: 10),
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
                borderRadius: BorderRadius.circular(20),
                border: message.isUser
                    ? null
                    : Border.all(
                        color: const Color(0xFF667eea).withOpacity(0.3),
                      ),
                boxShadow: [
                  BoxShadow(
                    color: message.isUser
                        ? const Color(0xFF667eea).withOpacity(0.3)
                        : Colors.black.withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Text(
                message.text,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  height: 1.4,
                ),
              ),
            ),
          ),
          if (message.isUser) ...[
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFf093fb), Color(0xFFf5576c)],
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const CircleAvatar(
                backgroundColor: Color(0xFF1a1f3a),
                radius: 18,
                child: Icon(Icons.person, color: Colors.white, size: 20),
              ),
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
