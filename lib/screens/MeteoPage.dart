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

  final String ollamaBaseUrl = 'http://10.0.2.2:11434';
  final String modelName = 'llama3.2:latest';

  @override
  void initState() {
    super.initState();
    _initializeLocation();
  }

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

      final locationCity = await _detectLocationWithOllama(ip);
      setState(() => _currentCity = locationCity);

      await _fetchWeatherWithMCP(locationCity);
    } catch (e) {
      setState(
        () => _errorMessage = 'Erreur lors de la détection de localisation',
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<String> _detectLocationWithOllama(String ip) async {
    try {
      final locationResponse = await http.get(
        Uri.parse('http://ip-api.com/json/$ip'),
      );
      final locationData = json.decode(locationResponse.body);
      final city = locationData['city'];
      final country = locationData['country'];

      setState(() => _currentLocation = '$city, $country');
      return city;
    } catch (e) {
      return 'Paris';
    }
  }

  Map<String, dynamic> _getWeatherToolDefinition() {
    return {
      'type': 'function',
      'function': {
        'name': 'get_weather',
        'description':
            'Récupère les informations météorologiques actuelles pour une ville.',
        'parameters': {
          'type': 'object',
          'properties': {
            'city': {
              'type': 'string',
              'description':
                  'Nom de la ville ou surnom (Paris, Casablanca, Casa, NYC)',
            },
          },
          'required': ['city'],
        },
      },
    };
  }

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
Exemples: "Casa" → "Casablanca", "NYC" → "New York", "LA" → "Los Angeles"
Réponds UNIQUEMENT avec le nom de la ville.''',
            },
            {'role': 'user', 'content': userInput},
          ],
          'stream': false,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['message']['content'].trim();
      }
      return userInput;
    } catch (e) {
      return userInput;
    }
  }

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

  Future<void> _fetchWeatherWithMCP(String city) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final normalizedCity = await _normalizeCityName(city);

      final response = await http.post(
        Uri.parse('$ollamaBaseUrl/api/chat'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'model': modelName,
          'messages': [
            {
              'role': 'system',
              'content':
                  'Tu es un assistant météo intelligent. Utilise l\'outil get_weather pour obtenir la météo.',
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

        String cityToFetch = normalizedCity;

        if (message['tool_calls'] != null && message['tool_calls'].isNotEmpty) {
          try {
            final toolCall = message['tool_calls'][0];
            dynamic argumentsData = toolCall['function']['arguments'];
            Map<String, dynamic> arguments = argumentsData is String
                ? json.decode(argumentsData)
                : Map<String, dynamic>.from(argumentsData);
            cityToFetch = arguments['city'] ?? normalizedCity;
          } catch (e) {
            cityToFetch = normalizedCity;
          }
        }

        final weatherData = await _fetchWeatherData(cityToFetch);

        if (weatherData.containsKey('error')) {
          setState(() => _errorMessage = weatherData['error']);
        } else {
          final weather = WeatherData.fromJson(weatherData);
          setState(() {
            _weatherData = weather;
            _currentCity = weather.city;
          });
        }
      }
    } catch (e) {
      setState(() => _errorMessage = 'Erreur de connexion: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

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
      backgroundColor: const Color(0xFF0a0e27),
      appBar: AppBar(
        title: const Text(
          '🌤️ Météo',
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
        child: SafeArea(
          child: Column(
            children: [
              // Badge MCP Tool
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  vertical: 10,
                  horizontal: 16,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF667eea).withOpacity(0.2),
                      const Color(0xFF764ba2).withOpacity(0.2),
                    ],
                  ),
                  border: Border(
                    bottom: BorderSide(
                      color: const Color(0xFF667eea).withOpacity(0.3),
                    ),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF667eea).withOpacity(0.3),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.build_circle,
                        size: 16,
                        color: Color(0xFF667eea),
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'Mode: MCP Tool + Ollama',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),

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
          // Titre et localisation
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  Color(0xFF667eea),
                  Color(0xFF764ba2),
                  Color(0xFFf093fb),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF667eea).withOpacity(0.4),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Météo Intelligente',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (_currentLocation != null) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(
                              Icons.location_on,
                              color: Colors.white70,
                              size: 16,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                _currentLocation!,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 14,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Text('🌍', style: TextStyle(fontSize: 32)),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Barre de recherche
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF1a1f3a),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: const Color(0xFF667eea).withOpacity(0.3),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: TextField(
              controller: _cityController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Rechercher une ville (Paris, Casa, NYC)...',
                hintStyle: TextStyle(color: Colors.grey[500]),
                prefixIcon: const Icon(Icons.search, color: Color(0xFF667eea)),
                suffixIcon: GestureDetector(
                  onTap: _searchCity,
                  child: Container(
                    margin: const EdgeInsets.all(8),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.send,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
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
            padding: const EdgeInsets.all(30),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF667eea).withOpacity(0.2),
                  const Color(0xFF764ba2).withOpacity(0.2),
                ],
              ),
              shape: BoxShape.circle,
            ),
            child: const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF667eea)),
              strokeWidth: 3,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Chargement de la météo...',
            style: TextStyle(color: Colors.grey[400], fontSize: 16),
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
            padding: const EdgeInsets.all(30),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.error_outline, color: Colors.red, size: 60),
          ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              _errorMessage!,
              style: TextStyle(color: Colors.grey[400], fontSize: 16),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 24),
          _buildActionButton(
            icon: Icons.refresh,
            label: 'Réessayer',
            onPressed: _initializeLocation,
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
            padding: const EdgeInsets.all(40),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF667eea).withOpacity(0.2),
                  const Color(0xFF764ba2).withOpacity(0.2),
                ],
              ),
              shape: BoxShape.circle,
            ),
            child: const Text('🌤️', style: TextStyle(fontSize: 80)),
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
          Text(
            'Essayez: Paris, Casa, NYC, Tokyo...',
            style: TextStyle(color: Colors.grey[500], fontSize: 16),
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
          const SizedBox(height: 20),
          _buildWeatherDetails(),
          const SizedBox(height: 20),
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
          colors: [Color(0xFF1a1f3a), Color(0xFF2d3561)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: const Color(0xFF667eea).withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF667eea).withOpacity(0.2),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            _weatherData!.city,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF667eea).withOpacity(0.3),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              _weatherData!.description,
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ),
          const SizedBox(height: 24),
          Text(_weatherData!.icon, style: const TextStyle(fontSize: 100)),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${_weatherData!.temperature.toStringAsFixed(0)}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 80,
                  fontWeight: FontWeight.w200,
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(top: 16),
                child: Text(
                  '°C',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 28,
                    fontWeight: FontWeight.w300,
                  ),
                ),
              ),
            ],
          ),
          Text(
            'Ressenti ${_weatherData!.feelsLike.toStringAsFixed(0)}°C',
            style: TextStyle(color: Colors.grey[500], fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildWeatherDetails() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1a1f3a),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF667eea).withOpacity(0.2)),
      ),
      child: Column(
        children: [
          _buildDetailRow(
            Icons.water_drop,
            'Humidité',
            '${_weatherData!.humidity}%',
            const Color(0xFF4facfe),
          ),
          _buildDivider(),
          _buildDetailRow(
            Icons.air,
            'Vent',
            '${_weatherData!.windSpeed.toStringAsFixed(1)} km/h',
            const Color(0xFF667eea),
          ),
          _buildDivider(),
          _buildDetailRow(
            Icons.umbrella,
            'Précipitations',
            '${_weatherData!.precipitation.toStringAsFixed(1)} mm',
            const Color(0xFFf093fb),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Divider(
        color: const Color(0xFF667eea).withOpacity(0.2),
        height: 1,
      ),
    );
  }

  Widget _buildDetailRow(
    IconData icon,
    String label,
    String value,
    Color color,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 16),
            Text(
              label,
              style: TextStyle(color: Colors.grey[400], fontSize: 16),
            ),
          ],
        ),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildForecast() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF667eea).withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.calendar_today,
                color: Color(0xFF667eea),
                size: 18,
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'Prévisions sur 5 jours',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 150,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _weatherData!.forecast.length,
            itemBuilder: (context, index) {
              final day = _weatherData!.forecast[index];
              final isToday = index == 0;
              return Container(
                width: 95,
                margin: const EdgeInsets.only(right: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: isToday
                      ? const LinearGradient(
                          colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                        )
                      : null,
                  color: isToday ? null : const Color(0xFF1a1f3a),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isToday
                        ? Colors.transparent
                        : const Color(0xFF667eea).withOpacity(0.2),
                  ),
                  boxShadow: isToday
                      ? [
                          BoxShadow(
                            color: const Color(0xFF667eea).withOpacity(0.4),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : null,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Text(
                      day['day'],
                      style: TextStyle(
                        color: isToday ? Colors.white : Colors.grey[400],
                        fontSize: 13,
                        fontWeight: isToday
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(day['icon'], style: const TextStyle(fontSize: 28)),
                    Column(
                      children: [
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
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 14,
                          ),
                        ),
                      ],
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

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF667eea), Color(0xFF764ba2)],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF667eea).withOpacity(0.4),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white),
            const SizedBox(width: 10),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _cityController.dispose();
    super.dispose();
  }
}

// Modèle de données (inchangé)
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
