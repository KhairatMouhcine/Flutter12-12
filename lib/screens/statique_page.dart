import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:speech_to_text/speech_to_text.dart';
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
  int _thinkingDuration = 0;

  final Random _random = Random();

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

    if (mounted) {
      setState(() {
        _isCallActive = false;
        _callState = CallState.idle;
        _callDuration = 0;
        _thinkingDuration = 0;
        _isListening = false;
        _userText = '';
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

  // Step 2: Show listening video and capture speech
  Future<void> _startListening() async {
    if (!_isCallActive) return; // Don't start if call ended

    setState(() {
      _callState = CallState.listening;
      _userText = '';
    });

    await _playVideo('assets/videos/listening.mp4', loop: true);

    // Start speech recognition
    _speechToText.listen(
      onResult: (result) {
        if (mounted) {
          setState(() {
            _userText = result.recognizedWords;
          });
        }
      },
    );

    setState(() => _isListening = true);

    // After 10 seconds, stop listening and show thinking
    await Future.delayed(const Duration(seconds: 10));

    if (_isCallActive) {
      _stopListening();
    }
  }

  Future<void> _stopListening() async {
    await _speechToText.stop();
    if (mounted) {
      setState(() => _isListening = false);
    }

    // Show thinking video
    _showThinking();
  }

  // Step 3: Show random thinking video (1-10 seconds)
  Future<void> _showThinking() async {
    if (!_isCallActive) return; // Don't continue if call ended

    setState(() => _callState = CallState.thinking);

    // Random thinking duration between 1-10 seconds
    final thinkingSeconds = _random.nextInt(10) + 1;
    setState(() => _thinkingDuration = thinkingSeconds);

    // Random thinking video (1, 2, or 3)
    final thinkingVideoNumber = _random.nextInt(3) + 1;
    final thinkingVideo = 'assets/videos/thinking$thinkingVideoNumber.mp4';

    await _playVideo(thinkingVideo, loop: true);

    // Wait for random duration
    await Future.delayed(Duration(seconds: thinkingSeconds));

    if (_isCallActive) {
      // Show response
      _showResponse();
    }
  }

  // Step 4: Show response video
  Future<void> _showResponse() async {
    if (!_isCallActive) return; // Don't continue if call ended

    setState(() {
      _callState = CallState.responding;
      _thinkingDuration = 0;
    });

    await _playVideo('assets/videos/reponse.mp4');

    // When response video finishes, restart listening
    _currentVideoController?.addListener(_onResponseVideoComplete);
  }

  void _onResponseVideoComplete() {
    if (_currentVideoController != null &&
        _currentVideoController!.value.position >=
            _currentVideoController!.value.duration) {
      _currentVideoController?.removeListener(_onResponseVideoComplete);

      if (_isCallActive) {
        // Restart listening cycle
        _startListening();
      }
    }
  }

  // Helper: Play video from asset
  Future<void> _playVideo(String path, {bool loop = false}) async {
    if (!_isCallActive) return; // Don't play if call ended

    // Dispose previous controller
    await _currentVideoController?.dispose();

    // Create new controller
    _currentVideoController = VideoPlayerController.asset(path);

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
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.psychology,
                              color: Colors.white,
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Thinking... (${_thinkingDuration}s)',
                              style: const TextStyle(
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
