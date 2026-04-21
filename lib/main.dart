import 'secrets.dart';
import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:record/record.dart';
import 'dart:math' as math;
import 'package:flutter/foundation.dart' show kIsWeb; 
import 'dart:io'; 
import 'dart:typed_data';
import 'package:http/http.dart' as http; 

// NEW: FIREBASE IMPORTS
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // INITIALIZING FIREBASE WITH YOUR KEYS
  await Firebase.initializeApp(
    options: const FirebaseOptions(
  apiKey: myApiKey,           // Uses the hidden variable
  authDomain: "acoustic-diagnostics.firebaseapp.com",
  projectId: "acoustic-diagnostics",
  storageBucket: "acoustic-diagnostics.appspot.com",
  messagingSenderId: "665782228023",
  appId: myAppId,             // Uses the hidden variable
),
  );
  
  runApp(const ScannerApp());
}

class ScannerApp extends StatelessWidget {
  const ScannerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Acoustic Diagnostics',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Colors.black,
        primaryColor: Colors.cyanAccent,
        colorScheme: const ColorScheme.dark(
          primary: Colors.cyanAccent,
          secondary: Colors.pinkAccent,
        ),
      ),
      home: const HomeScreen(), 
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.memory, size: 100, color: Colors.cyanAccent),
            const SizedBox(height: 30),
            const Text(
              'ACOUSTIC\nDIAGNOSTICS',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: 4),
            ),
            const SizedBox(height: 15),
            const Text(
              'EDGE COMPUTING & MULTIMODAL AI\nTARGETING UN SDG 9: INFRASTRUCTURE',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.pinkAccent, fontFamily: 'Courier', fontSize: 12),
            ),
            const SizedBox(height: 60),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.cyanAccent,
                  side: const BorderSide(color: Colors.cyanAccent, width: 2),
                  shape: const BeveledRectangleBorder(),
                ),
                onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const DashboardScreen())),
                child: const Text('AUTHENTICATE & ENTER', style: TextStyle(letterSpacing: 2)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  String _statusText = 'SYSTEM_READY';
  bool _isLoading = false;
  final AudioRecorder audioRecorder = AudioRecorder();
  final String apiKey = 'AIzaSyAfYfm63W1RWJF6_Q6f3OZt8TScm2-ROTw'; 

  Future<void> _handleScan() async {
    final hasPermission = await audioRecorder.hasPermission();
    if (hasPermission) {
      setState(() { _isLoading = true; _statusText = 'LISTENING: RECORDING LIVE AUDIO...'; });
      await audioRecorder.start(const RecordConfig(encoder: AudioEncoder.wav), path: kIsWeb ? '' : 'temp.wav');
      await Future.delayed(const Duration(seconds: 4));
      final audioPath = await audioRecorder.stop();
      if (audioPath != null) { await _analyzeAudio(audioPath); }
    }
  }

  Future<void> _analyzeAudio(String path) async {
  int retryCount = 0;
  const int maxRetries = 3;

  while (retryCount < maxRetries) {
    try {
      setState(() => _statusText = 'UPLINK: TRANSMITTING TO AI (Attempt ${retryCount + 1})...');
      
      Uint8List audioBytes;
      if (kIsWeb) {
        final response = await http.get(Uri.parse(path));
        audioBytes = response.bodyBytes;
      } else {
        audioBytes = await File(path).readAsBytes();
      }

      final model = GenerativeModel(model: 'gemini-2.5-flash', apiKey: apiKey);
      const prompt = 'You are an expert mechanical AI. Identify the acoustic profile and the likely mechanical failure. One sentence, STATUS: ALL CAPS.';
      
      final content = [Content.multi([TextPart(prompt), DataPart('audio/wav', audioBytes)])];
      final response = await model.generateContent(content);
      final resultText = response.text?.toUpperCase() ?? 'ANALYSIS_COMPLETE';

      // Save to Firebase
      await FirebaseFirestore.instance.collection('scans').add({
        'timestamp': FieldValue.serverTimestamp(),
        'result': resultText,
      });

      setState(() { _statusText = resultText; _isLoading = false; });
      return; // Exit function successfully!

    } catch (e) {
      if (e.toString().contains('503')) {
        retryCount++;
        setState(() => _statusText = 'SERVER BUSY... RETRYING IN 2s...');
        await Future.delayed(const Duration(seconds: 2));
      } else {
        setState(() { _statusText = 'ERROR: $e'; _isLoading = false; });
        break;
      }
    }
  }
  setState(() { _statusText = 'SERVER UNAVAILABLE. PLEASE TRY IN 1 MINUTE.'; _isLoading = false; });
}
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SYSTEM_DASHBOARD', style: TextStyle(color: Colors.cyanAccent, letterSpacing: 2)),
        centerTitle: true,
        backgroundColor: Colors.black,
        actions: [
          IconButton(
            icon: const Icon(Icons.history, color: Colors.pinkAccent),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const HistoryScreen())),
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _isLoading ? _buildWaveform() : const Icon(Icons.settings_input_antenna, size: 80, color: Colors.cyanAccent),
            const SizedBox(height: 40),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 30),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(border: Border.all(color: Colors.cyanAccent), color: Colors.cyanAccent.withValues(alpha:0.05)),
              child: Text(_statusText, textAlign: TextAlign.center, style: const TextStyle(color: Colors.cyanAccent, fontFamily: 'Courier')),
            ),
            const SizedBox(height: 60),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.pinkAccent, shape: const BeveledRectangleBorder()),
              onPressed: _isLoading ? null : _handleScan,
              child: const Padding(padding: EdgeInsets.symmetric(horizontal: 40, vertical: 15), child: Text('INITIALIZE SCAN')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWaveform() {
    return Row(mainAxisAlignment: MainAxisAlignment.center, children: List.generate(10, (i) => AnimatedContainer(duration: const Duration(milliseconds: 100), width: 5, height: 20 + (math.Random().nextInt(50).toDouble()), margin: const EdgeInsets.symmetric(horizontal: 2), color: Colors.pinkAccent)));
  }
}

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('CLOUD_LOGS', style: TextStyle(color: Colors.cyanAccent))),
      // NEW: FETCH DATA LIVE FROM CLOUD
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('scans').orderBy('timestamp', descending: true).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final docs = snapshot.data!.docs;
          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, i) {
              final data = docs[i].data() as Map<String, dynamic>;
              return ListTile(
                title: Text(data['result'] ?? '', style: const TextStyle(color: Colors.cyanAccent, fontSize: 13)),
                subtitle: Text(data['timestamp']?.toDate().toString().substring(0,16) ?? 'Processing...', style: const TextStyle(color: Colors.pinkAccent, fontSize: 10)),
              );
            },
          );
        },
      ),
    );
  }
}