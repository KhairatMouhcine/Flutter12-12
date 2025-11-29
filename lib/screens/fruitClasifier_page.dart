import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  List<String>? _labels;

  @override
  void initState() {
    super.initState();
    _loadModel();
  }

  Future<void> _loadModel() async {
    try {
      _interpreter = await Interpreter.fromAsset(
        'assets/models/fruit_classifier.tflite',
      );

      final labelsData = await rootBundle.loadString(
        'assets/models/fruit_classes.json',
      );
      final Map<String, dynamic> jsonResult = json.decode(labelsData);

      _labels = [];
      jsonResult.forEach((key, value) {
        int index = int.parse(key);
        while (_labels!.length <= index) {
          _labels!.add('');
        }
        _labels![index] = value;
      });

      print('✅ Modèle chargé avec ${_labels!.length} classes');
      print('📋 Classes: $_labels');

      // Afficher les détails du modèle
      print('📊 Input shape: ${_interpreter!.getInputTensor(0).shape}');
      print('📊 Output shape: ${_interpreter!.getOutputTensor(0).shape}');
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
    if (_image == null || _interpreter == null || _labels == null) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final imageBytes = await _image!.readAsBytes();
      img.Image? originalImage = img.decodeImage(imageBytes);

      if (originalImage == null) {
        throw Exception('Impossible de décoder l\'image');
      }

      // Redimensionner à 32x32
      img.Image resizedImage = img.copyResize(
        originalImage,
        width: 32,
        height: 32,
      );

      // Préparer l'input avec le bon format [1, 32, 32, 3]
      var input = List.generate(1, (batch) {
        return List.generate(32, (y) {
          return List.generate(32, (x) {
            final pixel = resizedImage.getPixel(x, y);
            // IMPORTANT: Normaliser entre 0 et 1 (division par 255)
            return [
              pixel.r.toDouble() / 255.0,
              pixel.g.toDouble() / 255.0,
              pixel.b.toDouble() / 255.0,
            ];
          });
        });
      });

      // Préparer l'output [1, nombre_de_classes]
      var output = List.generate(
        1,
        (_) => List<double>.filled(_labels!.length, 0.0),
      );

      print(
        '🔍 Input shape: ${input.length}x${input[0].length}x${input[0][0].length}x${input[0][0][0].length}',
      );
      print('🔍 Output shape: ${output.length}x${output[0].length}');

      // Faire la prédiction
      _interpreter!.run(input, output);

      print('📊 Predictions: ${output[0]}');

      // Trouver la classe avec la plus haute probabilité
      double maxConfidence = output[0][0];
      int maxIndex = 0;

      for (int i = 1; i < output[0].length; i++) {
        if (output[0][i] > maxConfidence) {
          maxConfidence = output[0][i];
          maxIndex = i;
        }
      }

      print('✅ Classe prédite: ${_labels![maxIndex]} (index: $maxIndex)');
      print('✅ Confiance: ${maxConfidence * 100}%');

      setState(() {
        _result = _labels![maxIndex];
        _confidence = maxConfidence * 100;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showError('Erreur de classification: $e');
      print('❌ Erreur détaillée: $e');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
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
      appBar: AppBar(
        title: const Text('Fruit Classifier'),
        centerTitle: true,
        backgroundColor: Colors.teal,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                height: 300,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: Colors.teal, width: 2),
                ),
                child: _image == null
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.image_outlined,
                            size: 80,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Aucune image sélectionnée',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      )
                    : ClipRRect(
                        borderRadius: BorderRadius.circular(15),
                        child: Image.file(_image!, fit: BoxFit.cover),
                      ),
              ),

              const SizedBox(height: 30),

              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _pickImageFromCamera,
                      icon: const Icon(Icons.camera_alt),
                      label: const Text('Caméra'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _pickImageFromGallery,
                      icon: const Icon(Icons.photo_library),
                      label: const Text('Galerie'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 30),

              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.teal[50],
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: Colors.teal, width: 2),
                ),
                child: Column(
                  children: [
                    const Text(
                      'Résultat',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.teal,
                      ),
                    ),
                    const SizedBox(height: 15),

                    if (_isLoading)
                      const CircularProgressIndicator()
                    else if (_result.isEmpty)
                      const Text(
                        'Sélectionnez une image pour commencer',
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                        textAlign: TextAlign.center,
                      )
                    else
                      Column(
                        children: [
                          const Icon(
                            Icons.check_circle,
                            color: Colors.green,
                            size: 50,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            _result,
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Colors.teal,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.teal,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              'Confiance: ${_confidence.toStringAsFixed(1)}%',
                              style: const TextStyle(
                                fontSize: 16,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
