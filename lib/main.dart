import 'package:flutter/material.dart';
import 'package:sensors/sensors.dart';
// import 'package:audioplayers/audioplayers.dart';
import 'package:just_audio/just_audio.dart';
import 'package:fl_chart/fl_chart.dart';

void main() {
  runApp(PedometerApp());
}

class PedometerApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pedometer Music Sync',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: PedometerHomePage(),
    );
  }
}

class PedometerHomePage extends StatefulWidget {
  @override
  _PedometerHomePageState createState() => _PedometerHomePageState();
}

class _PedometerHomePageState extends State<PedometerHomePage> {
  AudioPlayer _audioPlayer = AudioPlayer();
  // AudioCache _audioCache = AudioCache();
  int _stepCount = 0;
  double _stepInterval = 0;
  List<FlSpot> _accData = [];
  Stream<AccelerometerEvent>? _accelerometerStream;
  DateTime? _lastStepTime;
  List<double> _stepIntervals = [];

  @override
  void initState() {
    super.initState();
    _accelerometerStream = accelerometerEvents;
    // _audioPlayer.setReleaseMode(ReleaseMode.loop);
    _audioPlayer.setLoopMode(LoopMode.one);

    // Preload the audio file
    // _audioCache.load('audio-example.mp3');

    // Load the audio file and set it as the source for the audio player
    _audioPlayer.setAsset('assets/audio-example.mp3');

    _accelerometerStream?.listen((AccelerometerEvent event) {
      _detectStep(event); // Detect step based on accelerometer event

      setState(() {
        // Add new accelerometer data to the list
        _accData.add(FlSpot(DateTime.now().millisecondsSinceEpoch.toDouble(), event.y));
        
        // Keep only the latest 100 data points
        if (_accData.length > 100) {
          _accData.removeAt(0);
        }
      });
    });
  }

  void _detectStep(AccelerometerEvent event) {
    double threshold = 10; // Adjust threshold based on your requirement
    if (event.y.abs() > threshold) {
      DateTime now = DateTime.now();
      if (_lastStepTime != null) {
        double interval = now.difference(_lastStepTime!).inMilliseconds / 1000.0;
        _stepIntervals.add(interval);
        if (_stepIntervals.length > 10) {
          _stepIntervals.removeAt(0);
        }
        // Calculate average step interval
        _stepInterval = _stepIntervals.reduce((a, b) => a + b) / _stepIntervals.length;
      }
      
      // Update step count and last step time
      _lastStepTime = now;
      _stepCount++;

      _syncMusicToSteps();
    }
  }

  void _syncMusicToSteps() {
    if (_stepInterval > 0) {
      double stepFrequency = 1 / _stepInterval; // Calculate step frequency and adjust music playback rate
      double musicSpeed = 1; // TODO Calculate musicSpeed
      
      // _audioPlayer.setPlaybackRate(musicSpeed);
      _audioPlayer.setSpeed(musicSpeed);
    }
  }

  void _playMusic() async {
    // await _audioPlayer.resume();
    await _audioPlayer.play();
  }

  void _pauseMusic() async {
    await _audioPlayer.pause();
  }

  void _stopMusic() async {
    await _audioPlayer.stop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Pedometer Music Sync'),
      ),
      body: Column(
        children: [
          Expanded(
            child: LineChart(
              LineChartData(
                lineBarsData: [
                  LineChartBarData(spots: _accData),
                ],
              ),
            ),
          ),
          Text('Step Count: $_stepCount'),
          Text('Step Interval: $_stepInterval seconds'),
          Row(
            children: [
              IconButton(icon: Icon(Icons.play_arrow), onPressed: _playMusic),
              IconButton(icon: Icon(Icons.pause), onPressed: _pauseMusic),
              IconButton(icon: Icon(Icons.stop), onPressed: _stopMusic),
            ],
          ),
        ],
      ),
    );
  }
}