import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math';
import 'package:syncfusion_flutter_pdf/pdf.dart';

class RAGChatPage extends StatefulWidget {
  const RAGChatPage({super.key});

  @override
  State<RAGChatPage> createState() => _RAGChatPageState();
}

class _RAGChatPageState extends State<RAGChatPage> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  bool _isLoading = false;
  bool _isPdfLoaded = false;

  // Configuration Ollama
  final String _ollamaUrl = 'http://10.0.2.2:11434';

  // Base de connaissances extraite du PDF
  List<DocumentChunk> _documentChunks = [];
  Map<String, List<double>> _embeddingsCache = {};

  // Statistiques
  int _totalChunks = 0;
  String _pdfFileName = 'doc.pdf';

  @override
  void initState() {
    super.initState();
    _loadAndProcessPDF();
    _addMessage(
      'Bonjour ! Je suis votre assistant RAG. Je charge le document PDF...',
      isUser: false,
    );
  }

  // ==================== GESTION DU PDF ====================

  Future<void> _loadAndProcessPDF() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Charger le PDF depuis assets
      final ByteData data = await rootBundle.load('assets/fichier/doc.pdf');
      final Uint8List bytes = data.buffer.asUint8List();

      // Extraire le texte
      final PdfDocument document = PdfDocument(inputBytes: bytes);
      String fullText = '';

      // Parcourir toutes les pages
      for (int i = 0; i < document.pages.count; i++) {
        final PdfTextExtractor extractor = PdfTextExtractor(document);
        final String pageText = extractor.extractText(startPageIndex: i);
        fullText += pageText + '\n\n';
      }

      document.dispose();

      print('📄 Texte extrait: ${fullText.length} caractères');

      // Découper en chunks
      _documentChunks = _splitTextIntoChunks(fullText);
      _totalChunks = _documentChunks.length;

      print('📦 ${_totalChunks} chunks créés');

      // Pré-calculer les embeddings
      await _precomputeEmbeddings();

      setState(() {
        _isPdfLoaded = true;
      });

      _addMessage(
        '✅ Document chargé avec succès !\n'
        '📄 Fichier: $_pdfFileName\n'
        '📦 ${_totalChunks} sections indexées\n'
        '🔍 Prêt à répondre à vos questions !',
        isUser: false,
      );
    } catch (e) {
      print('❌ Erreur chargement PDF: $e');
      _addMessage('❌ Erreur lors du chargement du PDF: $e', isUser: false);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Découper le texte en chunks
  List<DocumentChunk> _splitTextIntoChunks(
    String text, {
    int chunkSize = 500,
    int overlap = 50,
  }) {
    final List<DocumentChunk> chunks = [];
    final words = text.split(RegExp(r'\s+'));

    for (int i = 0; i < words.length; i += chunkSize - overlap) {
      final end = (i + chunkSize < words.length) ? i + chunkSize : words.length;
      final chunkWords = words.sublist(i, end);
      final chunkText = chunkWords.join(' ');

      if (chunkText.trim().isNotEmpty) {
        chunks.add(
          DocumentChunk(
            id: 'chunk_${chunks.length}',
            content: chunkText,
            metadata: {
              'chunk_index': chunks.length,
              'start_word': i,
              'end_word': end,
            },
          ),
        );
      }
    }

    return chunks;
  }

  // ==================== EMBEDDINGS ====================

  Future<void> _precomputeEmbeddings() async {
    int processed = 0;
    for (var chunk in _documentChunks) {
      final embedding = await _generateEmbedding(chunk.content);
      if (embedding.isNotEmpty) {
        _embeddingsCache[chunk.id] = embedding;
        processed++;

        if (processed % 5 == 0) {
          print('🔄 Embeddings: $processed/${_documentChunks.length}');
        }
      }
    }
    print('✅ Tous les embeddings calculés: ${_embeddingsCache.length}');
  }

  Future<List<double>> _generateEmbedding(String text) async {
    try {
      final response = await http.post(
        Uri.parse('$_ollamaUrl/api/embeddings'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'model': 'llama3.2:latest', 'prompt': text}),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return List<double>.from(data['embedding']);
      }
      return [];
    } catch (e) {
      print('⚠️ Erreur embedding: $e');
      return [];
    }
  }

  // ==================== RECHERCHE ====================

  double _cosineSimilarity(List<double> a, List<double> b) {
    if (a.isEmpty || b.isEmpty || a.length != b.length) return 0;

    double dotProduct = 0;
    double normA = 0;
    double normB = 0;

    for (int i = 0; i < a.length; i++) {
      dotProduct += a[i] * b[i];
      normA += a[i] * a[i];
      normB += b[i] * b[i];
    }

    return dotProduct / (sqrt(normA) * sqrt(normB));
  }

  Future<List<RetrievalResult>> _retrieveRelevantChunks(
    String query, {
    int topK = 3,
  }) async {
    final queryEmbedding = await _generateEmbedding(query);
    if (queryEmbedding.isEmpty) return [];

    final results = <RetrievalResult>[];

    for (var chunk in _documentChunks) {
      final chunkEmbedding = _embeddingsCache[chunk.id];
      if (chunkEmbedding != null) {
        final score = _cosineSimilarity(queryEmbedding, chunkEmbedding);
        results.add(RetrievalResult(chunk: chunk, score: score));
      }
    }

    results.sort((a, b) => b.score.compareTo(a.score));
    return results.take(topK).toList();
  }

  // ==================== GÉNÉRATION RAG ====================

  Future<void> _sendRAGMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty || !_isPdfLoaded) return;

    _addMessage(message, isUser: true);
    _messageController.clear();

    setState(() {
      _isLoading = true;
    });

    try {
      // Étape 1: Récupérer les chunks pertinents
      print('🔍 Recherche de contexte...');
      final relevantChunks = await _retrieveRelevantChunks(message, topK: 3);

      // Étape 2: Construire le contexte
      String context = '';
      for (var result in relevantChunks) {
        context += 'Context (score: ${result.score.toStringAsFixed(3)}):\n';
        context += '${result.chunk.content}\n\n';
      }

      print('📚 Contexte récupéré: ${context.length} caractères');

      // Étape 3: Construire le prompt RAG
      final prompt =
          '''Tu es un assistant intelligent qui répond aux questions en te basant UNIQUEMENT sur le contexte fourni.

CONTEXTE EXTRAIT DU DOCUMENT:
$context

QUESTION DE L'UTILISATEUR:
$message

INSTRUCTIONS:
- Réponds UNIQUEMENT en te basant sur le contexte ci-dessus
- Si la réponse n'est pas dans le contexte, dis "Je ne trouve pas cette information dans le document"
- Sois précis et cite le contexte si pertinent
- Réponds en français

RÉPONSE:''';

      // Étape 4: Appeler Ollama
      final response = await http.post(
        Uri.parse('$_ollamaUrl/api/generate'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'model': 'llama3.2:latest',
          'prompt': prompt,
          'stream': false,
          'options': {
            'temperature': 0.3, // Moins créatif, plus factuel
            'top_p': 0.9,
          },
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final aiResponse = data['response'] ?? 'Pas de réponse';

        // Ajouter les sources
        String sourcesInfo = '\n\n📚 Sources (scores de pertinence):';
        for (var result in relevantChunks) {
          sourcesInfo +=
              '\n• Chunk ${result.chunk.metadata['chunk_index']} - Score: ${(result.score * 100).toStringAsFixed(1)}%';
        }

        _addMessage(aiResponse + sourcesInfo, isUser: false);
      } else {
        _addMessage('Erreur: ${response.statusCode}', isUser: false);
      }
    } catch (e) {
      _addMessage('Erreur: $e', isUser: false);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // ==================== UI ====================

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('RAG Chat - PDF'),
        centerTitle: true,
        backgroundColor: Colors.teal,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Badge RAG
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            color: Colors.teal.shade50,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _isPdfLoaded ? Icons.check_circle : Icons.hourglass_empty,
                  size: 16,
                  color: _isPdfLoaded ? Colors.green : Colors.orange,
                ),
                const SizedBox(width: 8),
                Text(
                  _isPdfLoaded
                      ? 'RAG actif • $_totalChunks chunks indexés'
                      : 'Chargement du document...',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.teal,
                  ),
                ),
              ],
            ),
          ),

          // Messages
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

          // Loading
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
                    'Recherche dans le document...',
                    style: TextStyle(
                      fontStyle: FontStyle.italic,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),

          // Input
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
                        hintText: _isPdfLoaded
                            ? 'Posez une question sur le document...'
                            : 'Chargement...',
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
                      enabled: _isPdfLoaded && !_isLoading,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _sendRAGMessage(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FloatingActionButton(
                    onPressed: (_isLoading || !_isPdfLoaded)
                        ? null
                        : _sendRAGMessage,
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
              child: const Icon(
                Icons.description,
                color: Colors.white,
                size: 20,
              ),
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

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}

// ==================== MODÈLES ====================

class ChatMessage {
  final String text;
  final bool isUser;

  ChatMessage({required this.text, required this.isUser});
}

class DocumentChunk {
  final String id;
  final String content;
  final Map<String, dynamic> metadata;

  DocumentChunk({
    required this.id,
    required this.content,
    required this.metadata,
  });
}

class RetrievalResult {
  final DocumentChunk chunk;
  final double score;

  RetrievalResult({required this.chunk, required this.score});
}
