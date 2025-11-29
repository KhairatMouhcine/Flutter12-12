import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class MeteoPage extends StatefulWidget {
  const MeteoPage({Key? key}) : super(key: key);

  @override
  State<MeteoPage> createState() => _MeteoPageState();
}

class _MeteoPageState extends State<MeteoPage> {
  final TextEditingController _cityController = TextEditingController();

  bool _isLoading = false;
  String? _currentLocation;
  String? _currentCity;
  WeatherData? _weatherData;
  String? _errorMessage;

  // Configuration Ollama
  final String ollamaBaseUrl = 'http://10.0.2.2:11434';
  final String modelName = 'llama3.2:latest';

  @override
  void initState() {
    super.initState();
    _initializeLocation();
  }

  // Récupérer l'IP et la localisation
  Future<void> _initializeLocation() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final ipResponse = await http.get(
        Uri.parse('https://api.ipify.org?format=json'),
      );
      final ipData = json.decode(ipResponse.body);
      final ip = ipData['ip'];

      // Détecter la localisation
      final locationCity = await _detectLocationWithOllama(ip);

      setState(() {
        _currentCity = locationCity;
      });

      await _fetchWeatherWithMCP(locationCity);
    } catch (e) {
      setState(() {
        _errorMessage = 'Erreur lors de la détection de localisation';
      });
      print('Erreur localisation: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Détecter la localisation depuis l'IP
  Future<String> _detectLocationWithOllama(String ip) async {
    try {
      final locationResponse = await http.get(
        Uri.parse('http://ip-api.com/json/$ip'),
      );
      final locationData = json.decode(locationResponse.body);

      final city = locationData['city'];
      final country = locationData['country'];

      setState(() {
        _currentLocation = '$city, $country';
      });

      return city;
    } catch (e) {
      return 'Paris';
    }
  }

  // Définition du MCP Tool météo
  Map<String, dynamic> _getWeatherToolDefinition() {
    return {
      'type': 'function',
      'function': {
        'name': 'get_weather',
        'description':
            'Récupère les informations météorologiques actuelles pour une ville. Comprend les surnoms: Casa=Casablanca, NYC=New York, LA=Los Angeles',
        'parameters': {
          'type': 'object',
          'properties': {
            'city': {
              'type': 'string',
              'description':
                  'Nom de la ville ou surnom (Paris, Casablanca, Casa, Maroc Casa, NYC)',
            },
          },
          'required': ['city'],
        },
      },
    };
  }

  // Normaliser les noms de villes avec Ollama
  Future<String> _normalizeCityName(String userInput) async {
    try {
      final response = await http.post(
        Uri.parse('$ollamaBaseUrl/api/chat'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'model': modelName,
          'messages': [
            {
              'role': 'system',
              'content':
                  '''Tu es un expert en géographie. Convertis les surnoms de villes en noms officiels.

Exemples:
- "Casa" ou "Maroc casa" → "Casablanca"
- "NYC" → "New York"
- "LA" → "Los Angeles"
- "Rabat Maroc" → "Rabat"
- "Paris France" → "Paris"

Réponds UNIQUEMENT avec le nom de la ville, sans explication.''',
            },
            {'role': 'user', 'content': userInput},
          ],
          'stream': false,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final cityName = data['message']['content'].trim();
        print('🌍 Normalisation: "$userInput" → "$cityName"');
        return cityName;
      }
      return userInput;
    } catch (e) {
      print('⚠️ Erreur normalisation: $e');
      return userInput;
    }
  }

  // Récupérer la météo via l'API
  Future<Map<String, dynamic>> _fetchWeatherData(String city) async {
    try {
      final geoResponse = await http.get(
        Uri.parse(
          'https://geocoding-api.open-meteo.com/v1/search?name=$city&count=1&language=fr&format=json',
        ),
      );
      final geoData = json.decode(geoResponse.body);

      if (geoData['results'] != null && geoData['results'].isNotEmpty) {
        final lat = geoData['results'][0]['latitude'];
        final lon = geoData['results'][0]['longitude'];
        final cityName = geoData['results'][0]['name'];

        final weatherResponse = await http.get(
          Uri.parse(
            'https://api.open-meteo.com/v1/forecast?latitude=$lat&longitude=$lon&current=temperature_2m,relative_humidity_2m,apparent_temperature,precipitation,weather_code,wind_speed_10m&daily=temperature_2m_max,temperature_2m_min,weather_code&timezone=auto&forecast_days=5',
          ),
        );
        final weatherData = json.decode(weatherResponse.body);

        return {
          'city': cityName,
          'current': weatherData['current'],
          'daily': weatherData['daily'],
        };
      }
      return {'error': 'Ville non trouvée'};
    } catch (e) {
      return {'error': 'Erreur: $e'};
    }
  }

  // Utiliser Ollama avec MCP pour récupérer la météo
  // Utiliser Ollama avec MCP pour récupérer la météo
  Future<void> _fetchWeatherWithMCP(String city) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Étape 1: Normaliser le nom de la ville
      final normalizedCity = await _normalizeCityName(city);

      // Étape 2: Appel à Ollama avec le tool météo
      final response = await http.post(
        Uri.parse('$ollamaBaseUrl/api/chat'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'model': modelName,
          'messages': [
            {
              'role': 'system',
              'content': '''Tu es un assistant météo intelligent. 
Utilise l'outil get_weather pour obtenir la météo.
Comprends les surnoms: Casa=Casablanca, NYC=New York, LA=Los Angeles.
Si l'utilisateur mentionne un pays avec une ville (ex: "Maroc casa"), extrait le nom de la ville.''',
            },
            {
              'role': 'user',
              'content': 'Donne-moi la météo pour $normalizedCity',
            },
          ],
          'tools': [_getWeatherToolDefinition()],
          'stream': false,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final message = data['message'];

        print('📡 Réponse Ollama: ${message.toString()}');

        String cityToFetch = normalizedCity;

        // Vérifier si l'outil a été appelé
        if (message['tool_calls'] != null && message['tool_calls'].isNotEmpty) {
          print('🔧 MCP Tool appelé par Ollama');

          try {
            final toolCall = message['tool_calls'][0];
            final functionData = toolCall['function'];

            // Gérer le cas où arguments est déjà un Map ou une String
            dynamic argumentsData = functionData['arguments'];
            Map<String, dynamic> arguments;

            if (argumentsData is String) {
              arguments = json.decode(argumentsData);
            } else if (argumentsData is Map) {
              arguments = Map<String, dynamic>.from(argumentsData);
            } else {
              arguments = {};
            }

            cityToFetch = arguments['city'] ?? normalizedCity;
            print('📍 Ville demandée par le tool: $cityToFetch');
          } catch (e) {
            print('⚠️ Erreur parsing tool call: $e');
            cityToFetch = normalizedCity;
          }
        } else {
          print('⚠️ Ollama n\'a pas appelé le tool, appel direct');
        }

        // Exécuter l'outil météo
        final weatherData = await _fetchWeatherData(cityToFetch);

        if (weatherData.containsKey('error')) {
          setState(() {
            _errorMessage = weatherData['error'];
          });
        } else {
          final weather = WeatherData.fromJson(weatherData);
          setState(() {
            _weatherData = weather;
            _currentCity = weather.city;
          });
          print('✅ Météo récupérée pour ${weather.city}');
        }
      } else {
        throw Exception('Erreur HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Erreur de connexion: $e';
      });
      print('❌ Erreur: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Rechercher une ville
  void _searchCity() {
    if (_cityController.text.trim().isNotEmpty) {
      _fetchWeatherWithMCP(_cityController.text.trim());
      _cityController.clear();
      FocusScope.of(context).unfocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0F172A), Color(0xFF1E293B), Color(0xFF334155)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: _isLoading
                    ? _buildLoadingState()
                    : _errorMessage != null
                    ? _buildErrorState()
                    : _weatherData != null
                    ? _buildWeatherContent()
                    : _buildEmptyState(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Météo',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (_currentLocation != null)
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on,
                          color: Color(0xFF3B82F6),
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _currentLocation!,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF3B82F6).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.wb_sunny,
                  color: Color(0xFF3B82F6),
                  size: 28,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.2)),
            ),
            child: TextField(
              controller: _cityController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Rechercher une ville (Paris, Casa, NYC)...',
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                prefixIcon: const Icon(Icons.search, color: Color(0xFF3B82F6)),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.send, color: Color(0xFF3B82F6)),
                  onPressed: _searchCity,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.all(16),
              ),
              onSubmitted: (_) => _searchCity(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF3B82F6).withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF3B82F6)),
              strokeWidth: 3,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Chargement de la météo...',
            style: TextStyle(color: Colors.white70, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.error_outline, color: Colors.red, size: 64),
          ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              _errorMessage!,
              style: const TextStyle(color: Colors.white70, fontSize: 16),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _initializeLocation(),
            icon: const Icon(Icons.refresh),
            label: const Text('Réessayer'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF3B82F6),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: const Color(0xFF3B82F6).withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.cloud_outlined,
              size: 80,
              color: Color(0xFF3B82F6),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Recherchez une ville',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Essayez: Paris, Casa, NYC, Tokyo...',
            style: TextStyle(color: Colors.white54, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildWeatherContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          _buildMainWeatherCard(),
          const SizedBox(height: 24),
          _buildWeatherDetails(),
          const SizedBox(height: 24),
          _buildForecast(),
        ],
      ),
    );
  }

  Widget _buildMainWeatherCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF3B82F6), Color(0xFF2563EB)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF3B82F6).withOpacity(0.5),
            blurRadius: 30,
            offset: const Offset(0, 15),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            _weatherData!.city,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _weatherData!.description,
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 24),
          Text(_weatherData!.icon, style: const TextStyle(fontSize: 120)),
          const SizedBox(height: 24),
          Text(
            '${_weatherData!.temperature.toStringAsFixed(0)}°',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 80,
              fontWeight: FontWeight.w200,
            ),
          ),
          Text(
            'Ressenti ${_weatherData!.feelsLike.toStringAsFixed(0)}°',
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeatherDetails() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          _buildDetailRow(
            Icons.water_drop,
            'Humidité',
            '${_weatherData!.humidity}%',
          ),
          const Divider(color: Colors.white24, height: 32),
          _buildDetailRow(
            Icons.air,
            'Vent',
            '${_weatherData!.windSpeed.toStringAsFixed(1)} km/h',
          ),
          const Divider(color: Colors.white24, height: 32),
          _buildDetailRow(
            Icons.umbrella,
            'Précipitations',
            '${_weatherData!.precipitation.toStringAsFixed(1)} mm',
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF3B82F6).withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: const Color(0xFF3B82F6), size: 24),
            ),
            const SizedBox(width: 16),
            Text(
              label,
              style: const TextStyle(color: Colors.white70, fontSize: 16),
            ),
          ],
        ),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildForecast() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Prévisions sur 5 jours',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 160, // Augmentez légèrement la hauteur
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _weatherData!.forecast.length,
            itemBuilder: (context, index) {
              final day = _weatherData!.forecast[index];
              return Container(
                width: 100,
                margin: const EdgeInsets.only(right: 12),
                padding: const EdgeInsets.all(12), // Réduisez le padding
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withOpacity(0.2)),
                ),
                child: Column(
                  mainAxisAlignment:
                      MainAxisAlignment.spaceEvenly, // Changé ici
                  mainAxisSize: MainAxisSize.min, // Ajouté
                  children: [
                    Text(
                      day['day'],
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4), // Réduit
                    Text(
                      day['icon'],
                      style: const TextStyle(fontSize: 28), // Réduit
                    ),
                    const SizedBox(height: 4), // Réduit
                    Text(
                      '${day['max']}°',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${day['min']}°',
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _cityController.dispose();
    super.dispose();
  }
}

// Modèles de données
class WeatherData {
  final String city;
  final double temperature;
  final double feelsLike;
  final String description;
  final int humidity;
  final double windSpeed;
  final double precipitation;
  final String icon;
  final List<Map<String, dynamic>> forecast;

  WeatherData({
    required this.city,
    required this.temperature,
    required this.feelsLike,
    required this.description,
    required this.humidity,
    required this.windSpeed,
    required this.precipitation,
    required this.icon,
    required this.forecast,
  });

  factory WeatherData.fromJson(Map<String, dynamic> json) {
    final current = json['current'];
    final weatherCode = current['weather_code'];
    final daily = json['daily'];

    List<Map<String, dynamic>> forecastList = [];
    final days = ['Aujourd\'hui', 'Demain', 'Mer', 'Jeu', 'Ven'];

    for (int i = 0; i < 5 && i < daily['temperature_2m_max'].length; i++) {
      forecastList.add({
        'day': days[i],
        'max': daily['temperature_2m_max'][i].toInt(),
        'min': daily['temperature_2m_min'][i].toInt(),
        'icon': _getWeatherIcon(daily['weather_code'][i]),
      });
    }

    return WeatherData(
      city: json['city'],
      temperature: current['temperature_2m'].toDouble(),
      feelsLike: current['apparent_temperature'].toDouble(),
      description: _getWeatherDescription(weatherCode),
      humidity: current['relative_humidity_2m'],
      windSpeed: current['wind_speed_10m'].toDouble(),
      precipitation: current['precipitation'].toDouble(),
      icon: _getWeatherIcon(weatherCode),
      forecast: forecastList,
    );
  }

  static String _getWeatherDescription(int code) {
    if (code == 0) return 'Ciel dégagé';
    if (code <= 3) return 'Partiellement nuageux';
    if (code <= 48) return 'Brouillard';
    if (code <= 67) return 'Pluvieux';
    if (code <= 77) return 'Neige';
    if (code <= 82) return 'Averses';
    if (code <= 99) return 'Orage';
    return 'Conditions variables';
  }

  static String _getWeatherIcon(int code) {
    if (code == 0) return '☀️';
    if (code <= 3) return '⛅';
    if (code <= 48) return '🌫️';
    if (code <= 67) return '🌧️';
    if (code <= 77) return '❄️';
    if (code <= 82) return '🌦️';
    if (code <= 99) return '⛈️';
    return '🌤️';
  }
}
