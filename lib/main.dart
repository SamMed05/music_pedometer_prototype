import 'package:flutter/material.dart';
import 'package:sensors/sensors.dart';
// import 'package:audioplayers/audioplayers.dart';
import 'package:just_audio/just_audio.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:package_info_plus/package_info_plus.dart';

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
  double _windowSize = 150; // How many point to display on the chart
  double _bufferMilliseconds = 400; // Default buffer (500 ms corresponds to 120 BPM, it's 1/4 os 120)
  double _threshold = 7; // Threshold for step detection (Lower = more sensitive)
  double _originalBPM = 135; // Example BPM, has to be fetched from metadata or an online API
  double _currentPlaybackRate = 1.0; // Track current playback rate for smooth transitions
  String _playbackMode = "Normal"; // Playback mode
  bool _isRunningMode = false; // Variable to track running mode

  String _versionNumber = ""; // State variable to hold the version number

  @override
  void initState() {
    super.initState();
    _accelerometerStream = accelerometerEvents;
    _audioPlayer.setLoopMode(LoopMode.one);

    // Load the audio file and set it as the source for the audio player
    _audioPlayer.setAsset('assets/audio-example.mp3');

    // Listen to accelerometer data
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

    // Fetch the version number and set it to the state variable (can't do it directly since it's of type Future)
    getVersionNumber().then((value) {
      setState(() {
        _versionNumber = value;
      });
    });
  }

  void _detectStep(AccelerometerEvent event) {
    // Check if the current event qualifies as a step by comparing the y-axis acceleration magnitude to a threshold
    double threshold = 10;
    if (event.y.abs() > threshold) {
      DateTime now = DateTime.now();

      // Ensure a buffer time between steps to avoid registering multiple steps for a single motion
      if (_lastStepTime != null && now.difference(_lastStepTime!).inMilliseconds > _bufferMilliseconds) {
        // Calculate the time interval since the last step in seconds
        double interval = now.difference(_lastStepTime!).inMilliseconds / 1000.0;

        // Add the step interval to a list and only keep the last 10 intervals
        _stepIntervals.add(interval);
        if (_stepIntervals.length > 10) {
          _stepIntervals.removeAt(0);
        }
        
        // Calculate average step interval from the list of step intervals
        _stepInterval = _stepIntervals.reduce((a, b) => a + b) / _stepIntervals.length;

        // Update step count and last step time
        _lastStepTime = now;
        _stepCount++;
        
        // Synchronize music tempo to the detected steps per minute
        _syncMusicToSteps();
      } else if (_lastStepTime == null) {
        // If this is the first step detected, set the last step time to the current time
        _lastStepTime = now;
      }
    }
  }

  void _syncMusicToSteps() {
    if (_stepInterval > 0) {
      // Calculate step frequency and adjust music playback rate
      double _stepFrequency = 1 / _stepInterval;

      // Calculate the user SPM (Steps Per Minute)
      double _userSPM = _stepFrequency * 60;

      // To calculate the playback rate a proportion can be used as follows:
      // SPM : BPM = x : 1
      // for example:
      // 100 SPM : 150 BPM = x : 1   -->   100*1/150 = 0.67 (or 67% of the original speed)
      // _currentPlaybackRate = _userSPM / _originalBPM; // Adjust playback rate to match user's BPM to the song's original BPM

      double _playbackRate = _userSPM / _originalBPM; // Calculate playback rate

      if (_playbackMode == "HalfTime") {
        _playbackRate /= 2;
      } else if (_playbackMode == "DoubleTime") {
        _playbackRate *= 2;
      }

      // Clamp the playback rate to keep it in a reasonable range
      double _clampedPlaybackRate = _playbackRate.clamp(0.5, 2.0);
      
      // Set the calculated playback rate to the audio player
      _audioPlayer.setSpeed(_clampedPlaybackRate);

      // Update the current playback rate
      _currentPlaybackRate = _clampedPlaybackRate;
    }
  }

  void _toggleRunningMode(bool value) {
    setState(() {
      _isRunningMode = value;
      if (_isRunningMode) {
        _bufferMilliseconds = 300; // Set buffer to 300ms for running mode
        _threshold = 9; // Set threshold to 9 for running mode
      } else {
        // Reset to default values or other values
        _bufferMilliseconds = 400; // Default buffer value
        _threshold = 7; // Default threshold value
      }
    });
  }

  void _playMusic() async {
    await _audioPlayer.play();
  }

  void _pauseMusic() async {
    await _audioPlayer.pause();
  }

  void _stopMusic() async {
    await _audioPlayer.stop();
  }

  void _resetStepCount() {
    setState(() {
      _stepCount = 0;
      _stepIntervals.clear();
      _stepInterval = 0;
      _lastStepTime = null;
    });
  }

  Future<String> getVersionNumber() async {
    PackageInfo packageInfo = await PackageInfo.fromPlatform();

    // String appName = packageInfo.appName;
    // String packageName = packageInfo.packageName;
    String version = packageInfo.version;
    // String buildNumber = packageInfo.buildNumber;

    return version;
  }

  // A function that creates and displays an AlertDialog to show info
  void _showInfoDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('About'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('Author: Samuel Mediani'),
              // Text('Version: 0.1.1'),
              Text('Version: $_versionNumber'),
              SizedBox(height: 10),
              Text('GitHub:'),
              GestureDetector(
                child: Text(
                  'https://github.com/SamMed05/music_pedometer_prototype',
                  style: TextStyle(color: Colors.blue),
                ),
                onTap: () async {
                  final url = Uri.parse('https://github.com/SamMed05/music_pedometer_prototype');
                  if (await canLaunchUrl(url)) {
                    await launchUrl(url);
                  } else {
                    throw 'Could not launch $url';
                  }
                },
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              child: Text('OK'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Music Pedometer Prototype'),
        actions: [
          IconButton(
            icon: Icon(Icons.info_outline),
            onPressed: _showInfoDialog,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              'Accelerometer for step detection works better when the phone is vertical.',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.normal),
            ),
          ),
          Expanded(
            child: LineChart(
              LineChartData(
                lineBarsData: [
                  LineChartBarData(
                    spots: _accData.isNotEmpty ? _accData : [FlSpot(0, 0)], // Ensure there is at least one data point
                    isCurved: true,
                    color: Colors.deepPurple,
                    dotData: FlDotData(show: false),
                    // belowBarData: BarAreaData(show: true),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.deepPurple.withOpacity(0.4),
                          Colors.deepPurple.withOpacity(0.3),
                          Colors.deepPurple.withOpacity(0.2),
                          Colors.deepPurple.withOpacity(0.1),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ],
                // borderData: FlBorderData(show: true),
                borderData: FlBorderData(
                  show: true,
                  border: Border.all(
                    color: Color.fromARGB(0, 255, 255, 255),
                    width: 2,
                  ),
                ),
                // gridData: FlGridData(show: true),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: true,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: Color.fromARGB(255, 146, 146, 146),
                    strokeWidth: 0.5,
                  ),
                  getDrawingVerticalLine: (value) => FlLine(
                    color: Color.fromARGB(255, 146, 146, 146),
                    strokeWidth: 0.5,
                  ),
                ),

                lineTouchData: LineTouchData(enabled: false),
                minY: -15, // Fix Y-axis minimum value
                maxY: 15,  // Fix Y-axis maximum value
              ),
            ),
          ),

          // Various info
          Text('Original BPM (song): $_originalBPM'),
          Text('Step Count: $_stepCount'),
          Text('Step Interval: ${_stepInterval.toStringAsFixed(2)} seconds'),
          Text('User BPM (target): ${_stepInterval > 0 ? (60 / _stepInterval).toStringAsFixed(2) : 'N/A'}'), // substitute 60 with _originalBPM
          Text('Current Playback Rate: ${_currentPlaybackRate.toStringAsFixed(2)}'),

          // Slider for adjusting the original BPM
          Slider(
            value: _originalBPM,
            min: 60,
            max: 200,
            divisions: 140,
            label: _originalBPM.round().toString(),
            onChanged: (value) {
              setState(() {
                _originalBPM = value;
              });
            },
          ),
          Text('Original BPM: ${_originalBPM.round()}'),

          // Slider for adjusting the buffer
          Slider(
            value: _bufferMilliseconds,
            min: 100,
            max: 1000,
            divisions: 9,
            label: _bufferMilliseconds.round().toString(),
            onChanged: (value) {
              setState(() {
                _bufferMilliseconds = value;
              });
            },
          ),
          Text('Buffer: ${_bufferMilliseconds.round()} ms'),

          // Slider for adjusting the threshold
          Slider(
            value: _threshold,
            min: 5,
            max: 20,
            divisions: 15,
            label: _threshold.toString(),
            onChanged: (value) {
              setState(() {
                _threshold = value;
              });
            },
          ),
          Text('Threshold: $_threshold'),

          // Running Mode Switch
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Running Mode'),
              Switch(
                value: _isRunningMode,
                onChanged: _toggleRunningMode,
              ),
            ],
          ),

          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(icon: Icon(Icons.play_arrow), onPressed: _playMusic, color: Colors.black, iconSize: 40),
              IconButton(icon: Icon(Icons.pause), onPressed: _pauseMusic, color: Colors.black, iconSize: 40),
              IconButton(icon: Icon(Icons.stop), onPressed: _stopMusic, color: Colors.black, iconSize: 40),
              IconButton(icon: Icon(Icons.refresh), onPressed: _resetStepCount, color: Colors.black, iconSize: 40),
              // or
              // ElevatedButton(onPressed: _playMusic, child: Text('Play')),
              // ElevatedButton(onPressed: _pauseMusic, child: Text('Pause')),
              // ElevatedButton(onPressed: _stopMusic, child: Text('Stop')),
              // ElevatedButton(onPressed: _resetStepCount, child: Text('Reset')),
              // ElevatedButton(onPressed: _loadMusic, child: Text('Load Music')),
            ],
          ),

          // Dropdown for selecting playback mode
          DropdownButton<String>(
            value: _playbackMode,
            items: ["Normal", "HalfTime", "DoubleTime"].map((String mode) {
              return DropdownMenuItem<String>(
                value: mode,
                child: Text(mode),
              );
            }).toList(),
            onChanged: (String? newValue) {
              setState(() {
                _playbackMode = newValue!;
              });
            },
          ),
          Text('Playback Mode: $_playbackMode'),
        ],
      ),
      // floatingActionButton: FloatingActionButton(
      //   onPressed: _loadMusic,
      //   child: Icon(Icons.add),
      // ),
    );
  }
}