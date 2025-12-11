import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;

class FruitClassifier extends StatefulWidget {
  const FruitClassifier({super.key});

  @override
  State<FruitClassifier> createState() => _FruitClassifierState();
}

class _FruitClassifierState extends State<FruitClassifier> {
  File? _image;
  String _result = '';
  double _confidence = 0.0;
  bool _isLoading = false;

  Interpreter? _interpreter;
  List<String> _labels = ['Apple', 'Banana', 'Grape', 'Mango', 'Strawberry'];

  // Emojis pour chaque fruit
  final Map<String, String> _fruitEmojis = {
    'Apple': '🍎',
    'Banana': '🍌',
    'Grape': '🍇',
    'Mango': '🥭',
    'Strawberry': '🍓',
  };

  @override
  void initState() {
    super.initState();
    _loadModel();
  }

  Future<void> _loadModel() async {
    try {
      _interpreter = await Interpreter.fromAsset(
        'assets/models/mobilenet_fruit_classifier.tflite',
      );
      print('✅ Modèle MobileNet chargé avec ${_labels.length} classes');
    } catch (e) {
      print('❌ Erreur chargement modèle: $e');
    }
  }

  Future<void> _pickImageFromCamera() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? photo = await picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 800,
        maxHeight: 800,
      );

      if (photo != null) {
        setState(() {
          _image = File(photo.path);
          _result = '';
          _confidence = 0.0;
        });
        await _classifyImage();
      }
    } catch (e) {
      _showError('Erreur lors de la prise de photo: $e');
    }
  }

  Future<void> _pickImageFromGallery() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
      );

      if (image != null) {
        setState(() {
          _image = File(image.path);
          _result = '';
          _confidence = 0.0;
        });
        await _classifyImage();
      }
    } catch (e) {
      _showError('Erreur lors de la sélection: $e');
    }
  }

  Future<void> _classifyImage() async {
    if (_image == null || _interpreter == null) return;

    setState(() => _isLoading = true);

    try {
      final imageBytes = await _image!.readAsBytes();
      img.Image? originalImage = img.decodeImage(imageBytes);

      if (originalImage == null) {
        throw Exception('Impossible de décoder l\'image');
      }

      img.Image resizedImage = img.copyResize(
        originalImage,
        width: 224,
        height: 224,
      );

      var input = List.generate(1, (batch) {
        return List.generate(224, (y) {
          return List.generate(224, (x) {
            final pixel = resizedImage.getPixel(x, y);
            return [
              (pixel.r.toDouble() / 127.5) - 1.0,
              (pixel.g.toDouble() / 127.5) - 1.0,
              (pixel.b.toDouble() / 127.5) - 1.0,
            ];
          });
        });
      });

      var output = List.generate(
        1,
        (_) => List<double>.filled(_labels.length, 0.0),
      );

      _interpreter!.run(input, output);

      List<double> probabilities = _softmax(output[0]);

      double maxConfidence = probabilities[0];
      int maxIndex = 0;

      for (int i = 1; i < probabilities.length; i++) {
        if (probabilities[i] > maxConfidence) {
          maxConfidence = probabilities[i];
          maxIndex = i;
        }
      }

      setState(() {
        _result = _labels[maxIndex];
        _confidence = maxConfidence * 100;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('Erreur de classification: $e');
    }
  }

  List<double> _softmax(List<double> logits) {
    double maxLogit = logits.reduce((a, b) => a > b ? a : b);
    List<double> expValues = logits.map((x) => math.exp(x - maxLogit)).toList();
    double sumExp = expValues.reduce((a, b) => a + b);
    return expValues.map((x) => x / sumExp).toList();
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red[700],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  void dispose() {
    _interpreter?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0a0e27),
      appBar: AppBar(
        title: const Text(
          '🍎 Fruit Classifier',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF667eea), Color(0xFF764ba2)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0a0e27), Color(0xFF1a1f3a)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Zone d'image
                _buildImageContainer(),

                const SizedBox(height: 24),

                // Boutons
                _buildActionButtons(),

                const SizedBox(height: 24),

                // Résultat
                _buildResultCard(),

                const SizedBox(height: 24),

                // Liste des fruits supportés
                _buildSupportedFruits(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildImageContainer() {
    return Container(
      height: 300,
      decoration: BoxDecoration(
        color: const Color(0xFF1a1f3a),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFF667eea).withOpacity(0.3),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF667eea).withOpacity(0.2),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: _image == null
          ? Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFF667eea).withOpacity(0.2),
                        const Color(0xFF764ba2).withOpacity(0.2),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(
                    Icons.image_search,
                    size: 60,
                    color: Color(0xFF667eea),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Aucune image sélectionnée',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[400],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Prenez une photo ou choisissez dans la galerie',
                  style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                ),
              ],
            )
          : ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.file(_image!, fit: BoxFit.cover),
                  // Overlay gradient
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      height: 60,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.transparent,
                            Colors.black.withOpacity(0.7),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    ),
                  ),
                  // Indicateur de chargement
                  if (_isLoading)
                    Container(
                      color: Colors.black.withOpacity(0.5),
                      child: const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF667eea),
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: _buildGradientButton(
            icon: Icons.camera_alt,
            label: 'Caméra',
            colors: [const Color(0xFF667eea), const Color(0xFF764ba2)],
            onPressed: _pickImageFromCamera,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildGradientButton(
            icon: Icons.photo_library,
            label: 'Galerie',
            colors: [const Color(0xFFf093fb), const Color(0xFFf5576c)],
            onPressed: _pickImageFromGallery,
          ),
        ),
      ],
    );
  }

  Widget _buildGradientButton({
    required IconData icon,
    required String label,
    required List<Color> colors,
    required VoidCallback onPressed,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: colors),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: colors[0].withOpacity(0.4),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 22),
            const SizedBox(width: 10),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1a1f3a),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: _result.isNotEmpty
              ? const Color(0xFF4ade80).withOpacity(0.5)
              : const Color(0xFF667eea).withOpacity(0.3),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: _result.isNotEmpty
                ? const Color(0xFF4ade80).withOpacity(0.2)
                : const Color(0xFF667eea).withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF667eea).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.analytics,
                  color: Color(0xFF667eea),
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'Résultat',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          if (_isLoading)
            Column(
              children: [
                const CircularProgressIndicator(color: Color(0xFF667eea)),
                const SizedBox(height: 16),
                Text(
                  'Analyse en cours...',
                  style: TextStyle(color: Colors.grey[400]),
                ),
              ],
            )
          else if (_result.isEmpty)
            Column(
              children: [
                Icon(Icons.pending, size: 50, color: Colors.grey[600]),
                const SizedBox(height: 12),
                Text(
                  'Sélectionnez une image pour commencer',
                  style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                  textAlign: TextAlign.center,
                ),
              ],
            )
          else
            Column(
              children: [
                // Emoji du fruit
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFF4ade80).withOpacity(0.2),
                        const Color(0xFF22c55e).withOpacity(0.2),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _fruitEmojis[_result] ?? '🍎',
                    style: const TextStyle(fontSize: 60),
                  ),
                ),
                const SizedBox(height: 16),

                // Nom du fruit
                Text(
                  _result,
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),

                // Badge de confiance
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: _confidence >= 80
                          ? [const Color(0xFF4ade80), const Color(0xFF22c55e)]
                          : _confidence >= 50
                          ? [const Color(0xFFfbbf24), const Color(0xFFf59e0b)]
                          : [const Color(0xFFf87171), const Color(0xFFef4444)],
                    ),
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color:
                            (_confidence >= 80
                                    ? const Color(0xFF4ade80)
                                    : _confidence >= 50
                                    ? const Color(0xFFfbbf24)
                                    : const Color(0xFFf87171))
                                .withOpacity(0.4),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _confidence >= 80
                            ? Icons.verified
                            : _confidence >= 50
                            ? Icons.help
                            : Icons.warning,
                        color: Colors.white,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Confiance: ${_confidence.toStringAsFixed(1)}%',
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildSupportedFruits() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1a1f3a),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF667eea).withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Text(
            'Fruits supportés',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.grey[400],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: _labels.map((label) {
              final isSelected = _result == label;
              return Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFF667eea).withOpacity(0.3)
                          : const Color(0xFF0a0e27),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xFF667eea)
                            : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: Text(
                      _fruitEmojis[label] ?? '🍎',
                      style: const TextStyle(fontSize: 28),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 11,
                      color: isSelected ? Colors.white : Colors.grey[500],
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
