import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'dart:async';

class VideoCallScreen extends StatefulWidget {
  const VideoCallScreen({Key? key}) : super(key: key);

  @override
  State<VideoCallScreen> createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends State<VideoCallScreen> {
  // Video players
  VideoPlayerController? _currentVideoController;

  // Speech recognition
  final SpeechToText _speechToText = SpeechToText();
  bool _isListening = false;
  String _userText = '';

  // State management
  CallState _callState = CallState.idle;
  bool _isCallActive = false;

  // Call timer
  int _callDuration = 0;
  Timer? _callTimer;

  final Random _random = Random();

  // API configurations
  final String ollamaUrl =
      'http://192.168.0.198:11434/api/generate'; // Pour émulateur Android
  // final String ollamaUrl = 'http://localhost:11434/api/generate'; // Pour iOS simulator
  final String dIdApiKey = 'xxxxxxxxxxxxx';
  final String dIdTalksUrl = 'https://api.d-id.com/talks';
  final String imageS3Url =
      's3://d-id-images-prod/google-oauth2|110635467151005719516/img_ACZTTgfnOoYya7PVE-F5C/1732555405028.jpg';

  String? _currentGeneratedVideoPath;
  String? _currentTalkId;

  @override
  void initState() {
    super.initState();
    _initializeSpeech();
  }

  Future<void> _initializeSpeech() async {
    await _speechToText.initialize();
  }

  // Start call
  void _startCall() {
    setState(() {
      _isCallActive = true;
      _callDuration = 0;
    });

    // Start timer
    _callTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _callDuration++;
        });
      }
    });

    // Start welcome video
    _startWelcomeVideo();
  }

  // End call - terminate immediately
  void _endCall() {
    // Cancel all timers
    _callTimer?.cancel();

    // Stop speech recognition
    _speechToText.stop();

    // Dispose video controller
    _currentVideoController?.pause();
    _currentVideoController?.dispose();
    _currentVideoController = null;

    // Delete current generated video if exists
    if (_currentGeneratedVideoPath != null) {
      File(_currentGeneratedVideoPath!).delete().catchError((e) {
        print('Error deleting video: $e');
      });
    }

    if (mounted) {
      setState(() {
        _isCallActive = false;
        _callState = CallState.idle;
        _callDuration = 0;
        _isListening = false;
        _userText = '';
        _currentGeneratedVideoPath = null;
        _currentTalkId = null;
      });
    }
  }

  // Format call duration (00:05)
  String _formatDuration(int seconds) {
    int minutes = seconds ~/ 60;
    int secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  // Step 1: Play welcome video when call starts
  Future<void> _startWelcomeVideo() async {
    setState(() => _callState = CallState.welcome);
    await _playVideo('assets/videos/welcome_video.mp4');

    // After welcome video finishes, start listening
    _currentVideoController?.addListener(_onWelcomeVideoComplete);
  }

  void _onWelcomeVideoComplete() {
    if (_currentVideoController != null &&
        _currentVideoController!.value.position >=
            _currentVideoController!.value.duration) {
      _currentVideoController?.removeListener(_onWelcomeVideoComplete);
      _startListening();
    }
  }

  // Step 2: Show listening video and capture speech - listen until user finishes
  // Step 2: SIMULATION POUR TESTER SANS MICRO
  Future<void> _startListening() async {
    if (!_isCallActive) return;

    setState(() {
      _callState = CallState.listening;
      _userText = '';
    });

    await _playVideo('assets/videos/listening.mp4', loop: true);

    // SIMULATION - Attends 3 secondes puis simule une question
    await Future.delayed(const Duration(seconds: 3));

    setState(() {
      _userText = "Quelle est la capitale de la France ?";
    });

    await Future.delayed(const Duration(seconds: 1));
    _stopListening();
  }

  Future<void> _stopListening() async {
    await _speechToText.stop();
    if (mounted) {
      setState(() => _isListening = false);
    }

    // Process user text with Ollama if not empty
    if (_userText.isNotEmpty) {
      await _processWithOllama(_userText);
    } else {
      // If no text, restart listening
      _startListening();
    }
  }

  // Step 3: Send to Ollama and get response
  Future<void> _processWithOllama(String userInput) async {
    if (!_isCallActive) return;

    print('User said: $userInput');

    // Show thinking video immediately
    _showThinking();

    try {
      final response = await http.post(
        Uri.parse(ollamaUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'model': 'llama3.2:latest',
          'prompt':
              '$userInput. Réponds en maximum 2-3 phrases courtes.', // Force short response
          'stream': false,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final aiResponse = data['response'];

        print('Ollama response: $aiResponse');

        if (_isCallActive) {
          // Send to D-ID to generate video (thinking continues)
          await _generateVideoWithDID(aiResponse);
        }
      } else {
        print('Ollama error: ${response.statusCode}');
        // Restart listening on error
        if (_isCallActive) _startListening();
      }
    } catch (e) {
      print('Error calling Ollama: $e');
      // Restart listening on error
      if (_isCallActive) _startListening();
    }
  }

  // Step 4: Show random thinking video (keeps looping until response ready)
  Future<void> _showThinking() async {
    if (!_isCallActive) return;

    setState(() => _callState = CallState.thinking);

    // Random thinking video (1, 2, or 3)
    final thinkingVideoNumber = _random.nextInt(3) + 1;
    final thinkingVideo = 'assets/videos/thinking$thinkingVideoNumber.mp4';

    // Loop thinking video indefinitely until response is ready
    await _playVideo(thinkingVideo, loop: true);
  }

  // Step 5: Generate video with D-ID
  Future<void> _generateVideoWithDID(String responseText) async {
    if (!_isCallActive) return;

    try {
      print('Creating D-ID talk...');

      // Create talk with D-ID
      final createResponse = await http.post(
        Uri.parse(dIdTalksUrl),
        headers: {
          'Authorization': 'Basic $dIdApiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'source_url': imageS3Url,
          'script': {'type': 'text', 'input': responseText},
        }),
      );

      if (createResponse.statusCode == 201) {
        final talkData = jsonDecode(createResponse.body);
        _currentTalkId = talkData['id'];

        print('Talk created: $_currentTalkId');

        // Keep showing thinking video and poll for completion
        await _pollForVideoCompletion(_currentTalkId!);
      } else {
        print('D-ID create error: ${createResponse.statusCode}');
        if (_isCallActive) _startListening();
      }
    } catch (e) {
      print('Error generating video with D-ID: $e');
      if (_isCallActive) _startListening();
    }
  }

  // Step 6: Poll D-ID until video is ready (thinking continues)
  Future<void> _pollForVideoCompletion(String talkId) async {
    const maxAttempts = 60; // 5 minutes max
    int attempts = 0;

    while (attempts < maxAttempts && _isCallActive) {
      await Future.delayed(const Duration(seconds: 5));

      try {
        final statusResponse = await http.get(
          Uri.parse('$dIdTalksUrl/$talkId'),
          headers: {'Authorization': 'Basic $dIdApiKey'},
        );

        if (statusResponse.statusCode == 200) {
          final statusData = jsonDecode(statusResponse.body);
          final status = statusData['status'];

          print('D-ID status: $status');

          if (status == 'done') {
            final resultUrl = statusData['result_url'];
            await _downloadAndPlayResponse(resultUrl, talkId);
            break;
          } else if (status == 'error') {
            print('D-ID video generation failed');
            if (_isCallActive) _startListening();
            break;
          }
          // If status is 'created' or 'started', keep thinking video playing
        }
      } catch (e) {
        print('Error polling D-ID: $e');
      }

      attempts++;
    }

    if (attempts >= maxAttempts) {
      print('Timeout waiting for D-ID video');
      if (_isCallActive) _startListening();
    }
  }

  // Step 7: Download generated video and play it
  Future<void> _downloadAndPlayResponse(String videoUrl, String talkId) async {
    if (!_isCallActive) return;

    try {
      print('Downloading video...');

      setState(() => _callState = CallState.responding);

      // Download video
      final response = await http.get(Uri.parse(videoUrl));

      if (response.statusCode == 200) {
        // Save to app documents directory
        final directory = await getApplicationDocumentsDirectory();
        final generationDir = Directory('${directory.path}/generation');

        if (!await generationDir.exists()) {
          await generationDir.create(recursive: true);
        }

        final videoPath = '${generationDir.path}/$talkId.mp4';
        final file = File(videoPath);
        await file.writeAsBytes(response.bodyBytes);

        _currentGeneratedVideoPath = videoPath;

        print('Video saved: $videoPath');

        // Play the response video
        await _playVideo(videoPath, isFile: true);

        // When video finishes, delete it and restart listening
        _currentVideoController?.addListener(_onResponseVideoComplete);
      }
    } catch (e) {
      print('Error downloading video: $e');
      if (_isCallActive) _startListening();
    }
  }

  // Step 8: Delete video after playing and restart listening
  void _onResponseVideoComplete() {
    if (_currentVideoController != null &&
        _currentVideoController!.value.position >=
            _currentVideoController!.value.duration) {
      _currentVideoController?.removeListener(_onResponseVideoComplete);

      // Delete the generated video
      if (_currentGeneratedVideoPath != null && _isCallActive) {
        File(_currentGeneratedVideoPath!)
            .delete()
            .then((_) {
              print('Generated video deleted');
              _currentGeneratedVideoPath = null;
              _currentTalkId = null;

              // Restart listening for next question
              if (_isCallActive) {
                _startListening();
              }
            })
            .catchError((e) {
              print('Error deleting video: $e');
              if (_isCallActive) _startListening();
            });
      }
    }
  }

  // Helper: Play video from asset or file
  Future<void> _playVideo(
    String path, {
    bool loop = false,
    bool isFile = false,
  }) async {
    if (!_isCallActive) return;

    // Dispose previous controller
    await _currentVideoController?.dispose();

    // Create new controller
    if (isFile) {
      _currentVideoController = VideoPlayerController.file(File(path));
    } else {
      _currentVideoController = VideoPlayerController.asset(path);
    }

    await _currentVideoController!.initialize();

    if (loop) {
      _currentVideoController!.setLooping(true);
    }

    if (mounted) {
      setState(() {});
    }
    await _currentVideoController!.play();
  }

  @override
  void dispose() {
    _callTimer?.cancel();
    _currentVideoController?.dispose();
    _speechToText.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Video player (full screen) - only show when call is active
          if (_isCallActive &&
              _currentVideoController != null &&
              _currentVideoController!.value.isInitialized)
            Center(
              child: AspectRatio(
                aspectRatio: _currentVideoController!.value.aspectRatio,
                child: VideoPlayer(_currentVideoController!),
              ),
            ),

          // Call not started - show call button
          if (!_isCallActive)
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'AI Assistant',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Ready to talk',
                    style: TextStyle(color: Colors.white70, fontSize: 18),
                  ),
                  const SizedBox(height: 60),
                  GestureDetector(
                    onTap: _startCall,
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.green.withOpacity(0.4),
                            blurRadius: 20,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.call,
                        color: Colors.white,
                        size: 40,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Call active - show overlay
          if (_isCallActive) ...[
            // Call duration only
            Positioned(
              top: 50,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // Call duration
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _formatDuration(_callDuration),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),

                    // Only show state for Thinking
                    if (_callState == CallState.thinking)
                      Container(
                        margin: const EdgeInsets.only(top: 12),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.8),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.psychology,
                              color: Colors.white,
                              size: 16,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Thinking...',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // End call button
            Positioned(
              bottom: 40,
              left: 0,
              right: 0,
              child: Center(
                child: GestureDetector(
                  onTap: _endCall,
                  child: Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.red.withOpacity(0.4),
                          blurRadius: 20,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.call_end,
                      color: Colors.white,
                      size: 35,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

enum CallState { idle, welcome, listening, thinking, responding }




