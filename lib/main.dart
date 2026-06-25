// Geliştirici: Mehmet Burak Zahter

import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_options.dart';

final ValueNotifier<bool> darkModeNotifier = ValueNotifier(false);
late SharedPreferences prefs;

// Uygulama başlangıcında Firebase ve yerel hafıza (tema ayarları) yüklenir.
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  prefs = await SharedPreferences.getInstance();
  bool savedDarkMode = prefs.getBool('isDarkMode') ?? false;
  darkModeNotifier.value = savedDarkMode;

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: darkModeNotifier,
      builder: (context, isDark, child) {
        SystemChrome.setSystemUIOverlayStyle(
          SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
          ),
        );

        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Zahter Kıraathane',
          themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
          theme: ThemeData.light().copyWith(
            scaffoldBackgroundColor: const Color(0xFFF4F7FA),
            primaryColor: const Color(0xFF6366F1),
            colorScheme: ColorScheme.light(
              primary: const Color(0xFF6366F1),
              secondary: const Color(0xFF10B981),
            ),
          ),
          darkTheme: ThemeData.dark().copyWith(
            scaffoldBackgroundColor: const Color(0xFF11111B),
            primaryColor: const Color(0xFF6366F1),
            colorScheme: ColorScheme.dark(
              primary: const Color(0xFF6366F1),
              secondary: const Color(0xFF10B981),
            ),
          ),
          home: const LobbyScreen(),
        );
      },
    );
  }
}

class LobbyScreen extends StatefulWidget {
  const LobbyScreen({super.key});

  @override
  State<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends State<LobbyScreen> {
  final _nameController = TextEditingController();
  final _roomController = TextEditingController();
  bool _isLoading = false;

  String? _selectedMicId;
  String? _selectedSpeakerId;
  double _micVolume = 1.0;
  double _speakerVolume = 1.0;

  @override
  void initState() {
    super.initState();
    _selectedMicId = prefs.getString('selectedMicId');
    _selectedSpeakerId = prefs.getString('selectedSpeakerId');
    _micVolume = prefs.getDouble('micVolume') ?? 1.0;
    _speakerVolume = prefs.getDouble('speakerVolume') ?? 1.0;

    _requestInitialPermissions();
  }

  // Mobil cihazlarda WebRTC'nin çökmesini önlemek için başlangıçta mikrofon izni istenir.
  Future<void> _requestInitialPermissions() async {
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      var status = await Permission.microphone.status;
      if (!status.isGranted) {
        await Permission.microphone.request();
      }
    }
  }

  // Lobi girişindeki kontrolleri ve son mikrofon iznini denetleyerek odaya geçişi başlatır.
  void _joinLobby() async {
    if (_nameController.text.isEmpty || _roomController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Lütfen isim ve masa kodunu eksiksiz girin.',
              style: TextStyle(fontWeight: FontWeight.w600)),
          backgroundColor: Colors.redAccent.shade400,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      var status = await Permission.microphone.status;
      if (!status.isGranted) {
        status = await Permission.microphone.request();
        if (!status.isGranted) {
          setState(() => _isLoading = false);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Masaya oturmak için Mikrofon izni vermeniz zorunludur!',
                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }
      }
    }

    setState(() => _isLoading = false);

    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChatRoomScreen(
            username: _nameController.text.trim(),
            roomCode: _roomController.text.trim(),
            initialMicId: _selectedMicId,
            initialSpeakerId: _selectedSpeakerId,
            initialMicVolume: _micVolume,
            initialSpeakerVolume: _speakerVolume,
          ),
        ),
      );
    }
  }

  // Kullanılabilir mikrofon ve hoparlör donanımlarını listeleyen ayar arayüzü.
  void _showSettingsDialog() async {
    List<MediaDeviceInfo> devices = [];
    List<MediaDeviceInfo> audioInputs = [];
    List<MediaDeviceInfo> audioOutputs = [];
    bool isMobile = !kIsWeb && (Platform.isAndroid || Platform.isIOS);

    try {
      devices = await navigator.mediaDevices.enumerateDevices();
      audioInputs = devices.where((d) => d.kind == 'audioinput').toList();
      audioOutputs = devices.where((d) => d.kind == 'audiooutput').toList();

      if (audioInputs.isNotEmpty && !audioInputs.any((d) => d.deviceId == _selectedMicId)) {
        _selectedMicId = audioInputs.first.deviceId;
      }
      if (audioOutputs.isNotEmpty && !audioOutputs.any((d) => d.deviceId == _selectedSpeakerId)) {
        _selectedSpeakerId = audioOutputs.first.deviceId;
      }
    } catch (e) {
      debugPrint("Cihaz listesi alınırken hata oluştu: $e");
    }

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return ValueListenableBuilder<bool>(
          valueListenable: darkModeNotifier,
          builder: (context, isDark, child) {
            return StatefulBuilder(
              builder: (context, setModalState) {
                return Container(
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                  padding: EdgeInsets.only(
                      bottom: MediaQuery.of(context).viewInsets.bottom,
                      left: 24, right: 24, top: 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.settings_suggest_rounded, color: Color(0xFF6366F1), size: 28),
                          const SizedBox(width: 12),
                          Text('Giriş Öncesi Ayarlar', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF0F172A))),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF6366F1)),
                            tooltip: 'Cihazları Yenile',
                            onPressed: () async {
                              try {
                                List<MediaDeviceInfo> updatedDevices = await navigator.mediaDevices.enumerateDevices();
                                setModalState(() {
                                  audioInputs = updatedDevices.where((d) => d.kind == 'audioinput').toList();
                                  audioOutputs = updatedDevices.where((d) => d.kind == 'audiooutput').toList();
                                  if (audioInputs.isNotEmpty && !audioInputs.any((d) => d.deviceId == _selectedMicId)) {
                                    _selectedMicId = audioInputs.first.deviceId;
                                  }
                                  if (audioOutputs.isNotEmpty && !audioOutputs.any((d) => d.deviceId == _selectedSpeakerId)) {
                                    _selectedSpeakerId = audioOutputs.first.deviceId;
                                  }
                                });
                              } catch (e) {
                                debugPrint("Yenileme sırasında hata: $e");
                              }
                            },
                          ),
                          IconButton(
                            icon: Icon(Icons.close_rounded, color: isDark ? const Color(0xFFA6ADC8) : const Color(0xFF64748B)),
                            onPressed: () => Navigator.pop(context),
                          )
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Icon(isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                              color: isDark ? Colors.amber : const Color(0xFF64748B), size: 22),
                          const SizedBox(width: 8),
                          Text('Karanlık Tema', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF475569))),
                          const Spacer(),
                          Switch(
                            value: isDark,
                            activeColor: const Color(0xFF6366F1),
                            onChanged: (val) {
                              darkModeNotifier.value = val;
                              prefs.setBool('isDarkMode', val);
                              setModalState(() {});
                            },
                          ),
                        ],
                      ),
                      Divider(color: isDark ? const Color(0xFF313244) : Colors.grey.shade200, height: 32),
                      Text('Mikrofon (Giriş Cihazı)', style: TextStyle(fontWeight: FontWeight.w700, color: isDark ? const Color(0xFFA6ADC8) : const Color(0xFF475569))),
                      const SizedBox(height: 8),
                      if (audioInputs.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: Text('Sistem varsayılan girişi kullanılıyor.', style: TextStyle(color: isDark ? const Color(0xFF6C7086) : Colors.grey, fontStyle: FontStyle.italic, fontSize: 14)),
                        )
                      else
                        DropdownButtonFormField<String>(
                          dropdownColor: isDark ? const Color(0xFF232336) : Colors.white,
                          isExpanded: true,
                          value: _selectedMicId,
                          items: audioInputs.map((d) => DropdownMenuItem(
                                value: d.deviceId,
                                child: Text(d.label.isNotEmpty ? d.label : 'Bilinmeyen Mikrofon', style: TextStyle(color: isDark ? Colors.white : const Color(0xFF1E293B), fontSize: 14, fontWeight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis),
                              )).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setModalState(() => _selectedMicId = val);
                              prefs.setString('selectedMicId', val);
                            }
                          },
                          decoration: InputDecoration(
                            filled: true, fillColor: isDark ? const Color(0xFF181825) : const Color(0xFFF8FAFC),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: isDark ? const Color(0xFF313244) : Colors.grey.shade300)),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: isDark ? const Color(0xFF313244) : Colors.grey.shade300)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          ),
                        ),
                      const SizedBox(height: 16),
                      if (!isMobile) ...[
                        Row(
                          children: [
                            Icon(Icons.mic_none_rounded, color: isDark ? const Color(0xFFA6ADC8) : const Color(0xFF94A3B8), size: 20),
                            const SizedBox(width: 8),
                            Text('Mikrofon Hassasiyeti', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isDark ? const Color(0xFFA6ADC8) : const Color(0xFF64748B))),
                            Expanded(
                              child: Slider(
                                value: _micVolume,
                                activeColor: const Color(0xFF10B981),
                                onChanged: (val) {
                                  setModalState(() => _micVolume = val);
                                  prefs.setDouble('micVolume', val);
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                      ],
                      Text('Hoparlör (Çıkış Cihazı)', style: TextStyle(fontWeight: FontWeight.w700, color: isDark ? const Color(0xFFA6ADC8) : const Color(0xFF475569))),
                      const SizedBox(height: 8),
                      if (audioOutputs.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: Text('Sistem varsayılan çıkışı kullanılıyor.', style: TextStyle(color: isDark ? const Color(0xFF6C7086) : Colors.grey, fontStyle: FontStyle.italic, fontSize: 14)),
                        )
                      else
                        DropdownButtonFormField<String>(
                          dropdownColor: isDark ? const Color(0xFF232336) : Colors.white,
                          isExpanded: true,
                          value: _selectedSpeakerId,
                          items: audioOutputs.map((d) => DropdownMenuItem(
                                value: d.deviceId,
                                child: Text(d.label.isNotEmpty ? d.label : 'Bilinmeyen Hoparlör', style: TextStyle(color: isDark ? Colors.white : const Color(0xFF1E293B), fontSize: 14, fontWeight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis),
                              )).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setModalState(() => _selectedSpeakerId = val);
                              prefs.setString('selectedSpeakerId', val);
                            }
                          },
                          decoration: InputDecoration(
                            filled: true, fillColor: isDark ? const Color(0xFF181825) : const Color(0xFFF8FAFC),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: isDark ? const Color(0xFF313244) : Colors.grey.shade300)),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: isDark ? const Color(0xFF313244) : Colors.grey.shade300)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          ),
                        ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Icon(Icons.volume_down_rounded, color: isDark ? const Color(0xFFA6ADC8) : const Color(0xFF94A3B8), size: 20),
                          const SizedBox(width: 8),
                          Text('Uygulama Sesi', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isDark ? const Color(0xFFA6ADC8) : const Color(0xFF64748B))),
                          Expanded(
                            child: Slider(
                              value: _speakerVolume,
                              activeColor: const Color(0xFF6366F1),
                              onChanged: (val) {
                                setModalState(() => _speakerVolume = val);
                                prefs.setDouble('speakerVolume', val);
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),
                    ],
                  ),
                );
              },
            );
          }
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isDark = darkModeNotifier.value;
    
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_rounded, color: Color(0xFF6366F1), size: 28),
            onPressed: _showSettingsDialog,
            tooltip: 'Ses Ayarları',
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark 
                ? const [Color(0xFF1E1E2E), Color(0xFF11111B)] 
                : const [Color(0xFFE0E7FF), Color(0xFFF4F7FA)],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 28.0, vertical: 40.0),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF232336) : Colors.white,
                borderRadius: BorderRadius.circular(32),
                boxShadow: [
                  BoxShadow(
                    color: isDark ? Colors.black.withOpacity(0.3) : const Color(0xFF6366F1).withOpacity(0.08),
                    blurRadius: 30,
                    offset: const Offset(0, 15),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF313244) : const Color(0xFFEEF2FF),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                            color: const Color(0xFF6366F1).withOpacity(0.2),
                            blurRadius: 15,
                            spreadRadius: -5)
                      ],
                    ),
                    child: const Icon(Icons.coffee_rounded,
                        size: 50, color: Color(0xFF6366F1)),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Zahter Kıraathane',
                    style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                        letterSpacing: -0.5),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Sesli Sohbet ve yazışma odalarına katılın.',
                    style: TextStyle(
                        color: isDark ? const Color(0xFFA6ADC8) : const Color(0xFF64748B),
                        fontSize: 14,
                        fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 36),
                  _buildTextField(_nameController, 'Kullanıcı Adı', Icons.person_outline_rounded, isDark),
                  const SizedBox(height: 16),
                  _buildTextField(_roomController, 'Masa Kodu (Örn: masa1)', Icons.table_restaurant_rounded, isDark),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6366F1),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                        elevation: 4,
                        shadowColor: const Color(0xFF6366F1).withOpacity(0.4),
                      ),
                      onPressed: _isLoading ? null : _joinLobby,
                      child: _isLoading
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2))
                          : const Text('Masaya Otur',
                              style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String hint, IconData icon, bool isDark) {
    return TextField(
      controller: controller,
      style: TextStyle(
          color: isDark ? Colors.white : const Color(0xFF0F172A), fontWeight: FontWeight.w600),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
            color: isDark ? const Color(0xFF6C7086) : const Color(0xFF94A3B8), fontWeight: FontWeight.normal),
        prefixIcon: Icon(icon, color: const Color(0xFF6366F1), size: 22),
        filled: true,
        fillColor: isDark ? const Color(0xFF181825) : const Color(0xFFF8FAFC),
        contentPadding: const EdgeInsets.symmetric(vertical: 18),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: isDark ? const Color(0xFF313244) : const Color(0xFFCBD5E1).withOpacity(0.5)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFF6366F1), width: 2),
        ),
      ),
    );
  }
}

class ChatRoomScreen extends StatefulWidget {
  final String username;
  final String roomCode;
  
  final String? initialMicId;
  final String? initialSpeakerId;
  final double initialMicVolume;
  final double initialSpeakerVolume;

  const ChatRoomScreen({
    super.key, 
    required this.username, 
    required this.roomCode,
    this.initialMicId,
    this.initialSpeakerId,
    this.initialMicVolume = 1.0,
    this.initialSpeakerVolume = 1.0,
  });

  @override
  State<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends State<ChatRoomScreen>
    with WidgetsBindingObserver {
  final _messageController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  MediaStream? _localStream;
  final Map<String, RTCPeerConnection> _peers = {};
  final Map<String, MediaStreamTrack> _remoteAudioTracks = {};
  final Map<String, RTCVideoRenderer> _remoteRenderers = {};
  final Map<String, MediaStream> _remoteStreams = {};

  final Map<String, List<RTCIceCandidate>> _candidateQueue = {};
  final Set<String> _remoteDescriptionSet = {};

  StreamSubscription? _signalSubscription;
  StreamSubscription? _participantsSubscription;

  late Stream<QuerySnapshot> _participantsStream;
  late Stream<QuerySnapshot> _messagesStream;

  bool _isMuted = false;
  bool _isDeaf = false;
  bool _isSpeaking = false;

  Timer? _statsTimer;
  Timer? _heartbeatTimer;

  final Map<String, bool> _localMutedUsers = {};
  String? _selectedWhisperTarget;

  String? _selectedAudioInputId;
  String? _selectedAudioOutputId;
  late double _micVolume;
  late double _speakerVolume;

  final Map<String, int> _lastHeartbeatValues = {};
  final Map<String, DateTime> _lastHeartbeatChanges = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    _selectedAudioInputId = widget.initialMicId ?? prefs.getString('selectedMicId');
    _selectedAudioOutputId = widget.initialSpeakerId ?? prefs.getString('selectedSpeakerId');
    _micVolume = widget.initialMicVolume;
    _speakerVolume = widget.initialSpeakerVolume;

    _participantsStream = _firestore
        .collection('lobiler')
        .doc(widget.roomCode)
        .collection('katilimcilar')
        .snapshots();

    _messagesStream = _firestore
        .collection('lobiler')
        .doc(widget.roomCode)
        .collection('mesajlar')
        .orderBy('tarih', descending: true)
        .snapshots();

    _initWebRTC();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.detached) {
      _firestore
          .collection('lobiler')
          .doc(widget.roomCode)
          .collection('katilimcilar')
          .doc(widget.username)
          .delete();
    }
  }

  // Android tabanlı cihazlarda ses çıkışını hoparlör moduna zorlar.
  Future<void> _forceSpeakerphone() async {
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      try {
        await Helper.setSpeakerphoneOn(true);
      } catch (e) {
        debugPrint("Hoparlör ayarlanırken hata: $e");
      }
    }
  }

  // WebRTC'yi başlatır, yerel ses akışını yakalar, sinyalleşme dinleyicilerini kurar.
  Future<void> _initWebRTC() async {
    final Map<String, dynamic> audioConstraints = {
      'echoCancellation': true,
      'noiseSuppression': true,
      'autoGainControl': true,
    };
    
    if (_selectedAudioInputId != null) {
      audioConstraints['deviceId'] = {'exact': _selectedAudioInputId};
    }

    final Map<String, dynamic> mediaConstraints = {
      'audio': audioConstraints,
      'video': false,
    };

    try {
      _localStream = await navigator.mediaDevices.getUserMedia(mediaConstraints);
      if (_localStream != null && _localStream!.getAudioTracks().isNotEmpty) {
        try {
          bool isMobile = !kIsWeb && (Platform.isAndroid || Platform.isIOS);
          if (!isMobile) {
            await Helper.setVolume(_micVolume, _localStream!.getAudioTracks().first);
          }
        } catch (e) {
          debugPrint("İlk mikrofon ses seviyesi uygulanamadı: $e");
        }
      }
    } catch (e) {
      debugPrint("Özel ayarlarla mikrofon açılamadı: $e");
      try {
        _localStream = await navigator.mediaDevices.getUserMedia({'audio': true, 'video': false});
        _selectedAudioInputId = null; 
      } catch (e2) {
        debugPrint("Yedek mikrofon da açılamadı: $e2");
        if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
             const SnackBar(
               content: Text('Mikrofon başlatılamadı! Lütfen ayarlardan mikrofon izni verildiğine emin olun.',
               style: TextStyle(fontWeight: FontWeight.bold)),
               backgroundColor: Colors.redAccent,
             )
           );
        }
      }
    }

    try {
      if (!kIsWeb && (Platform.isWindows || Platform.isMacOS)) {
        if (_selectedAudioOutputId != null) {
          await Helper.selectAudioOutput(_selectedAudioOutputId!);
        }
      } else if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
        await _forceSpeakerphone();
      }
    } catch (e) {
      debugPrint('Sesi hoparlöre alırken hata: $e');
    }

    var roomRef = _firestore.collection('lobiler').doc(widget.roomCode);

    var oldSignals = await roomRef
        .collection('signals')
        .where('target', isEqualTo: widget.username)
        .get();
    for (var doc in oldSignals.docs) {
      await doc.reference.delete();
    }

    _signalSubscription = roomRef
        .collection('signals')
        .where('target', isEqualTo: widget.username)
        .snapshots()
        .listen(_handleSignals);

    _participantsSubscription = _participantsStream.listen((snap) {
      final now = DateTime.now();
      for (var doc in snap.docs) {
        final peerId = doc.id;
        if (peerId == widget.username) continue;

        final data = doc.data() as Map<String, dynamic>;
        final int currentHeartbeat = data['heartbeat'] as int? ?? 0;

        final lastVal = _lastHeartbeatValues[peerId];
        if (lastVal == null || lastVal != currentHeartbeat) {
          _lastHeartbeatValues[peerId] = currentHeartbeat;
          _lastHeartbeatChanges[peerId] = now;
        }
      }

      for (var change in snap.docChanges) {
        String peerId = change.doc.id;
        if (peerId == widget.username) continue;

        if (change.type == DocumentChangeType.added) {
          if (widget.username.compareTo(peerId) > 0 && !_peers.containsKey(peerId)) {
            _initiateConnection(peerId);
          }
        } else if (change.type == DocumentChangeType.removed) {
          _removePeer(peerId);
          _lastHeartbeatValues.remove(peerId);
          _lastHeartbeatChanges.remove(peerId);
        }
      }
    });

    _enterRoomRegistry();
    _sendSystemMessage("${widget.username} masaya katıldı 👋");
    _startAudioLevelMonitoring();
    _startHeartbeat(); 
  }

  // Firestore üzerindeki heartbeat değerini günceller ve inaktif kullanıcıları odadan çıkarır.
  void _startHeartbeat() {
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 15), (timer) async {
      if (!mounted) return;

      _firestore
          .collection('lobiler')
          .doc(widget.roomCode)
          .collection('katilimcilar')
          .doc(widget.username)
          .update({
        'heartbeat': FieldValue.increment(1),
      }).catchError((e) {
        debugPrint("Heartbeat gönderilemedi: $e");
      });

      final now = DateTime.now();
      final peerIds = List<String>.from(_lastHeartbeatChanges.keys);

      for (var peerId in peerIds) {
        final lastChange = _lastHeartbeatChanges[peerId];
        if (lastChange != null && now.difference(lastChange).inSeconds > 45) {
          _firestore
              .collection('lobiler')
              .doc(widget.roomCode)
              .collection('katilimcilar')
              .doc(peerId)
              .delete()
              .catchError((e) => debugPrint("İnaktif üye silinemedi: $e"));

          _lastHeartbeatValues.remove(peerId);
          _lastHeartbeatChanges.remove(peerId);
        }
      }
    });
  }

  Future<void> _setLocalMicVolume(double volume) async {
    setState(() {
      _micVolume = volume;
    });
    prefs.setDouble('micVolume', volume);
    if (_localStream != null && _localStream!.getAudioTracks().isNotEmpty) {
      try {
        bool isMobile = !kIsWeb && (Platform.isAndroid || Platform.isIOS);
        if (!isMobile) {
          final track = _localStream!.getAudioTracks().first;
          await Helper.setVolume(volume, track);
        }
      } catch (e) {
        debugPrint("Mikrofon sesi ayarlanamadı: $e");
      }
    }
  }

  Future<void> _setSpeakerVolume(double volume) async {
    setState(() {
      _speakerVolume = volume;
    });
    prefs.setDouble('speakerVolume', volume);
    for (var track in _remoteAudioTracks.values) {
      try {
        await Helper.setVolume(volume, track);
      } catch (e) {
        debugPrint("Uzak ses kanalı ses seviyesi ayarlanamadı: $e");
      }
    }
  }

  void _showSettingsDialog() async {
    List<MediaDeviceInfo> devices = [];
    List<MediaDeviceInfo> audioInputs = [];
    List<MediaDeviceInfo> audioOutputs = [];
    bool isMobile = !kIsWeb && (Platform.isAndroid || Platform.isIOS);

    try {
      devices = await navigator.mediaDevices.enumerateDevices();
      audioInputs = devices.where((d) => d.kind == 'audioinput').toList();
      audioOutputs = devices.where((d) => d.kind == 'audiooutput').toList();

      if (audioInputs.isNotEmpty && !audioInputs.any((d) => d.deviceId == _selectedAudioInputId)) {
        _selectedAudioInputId = audioInputs.first.deviceId;
      }
      if (audioOutputs.isNotEmpty && !audioOutputs.any((d) => d.deviceId == _selectedAudioOutputId)) {
        _selectedAudioOutputId = audioOutputs.first.deviceId;
      }
    } catch (e) {
      debugPrint("Cihaz listesi alınırken hata: $e");
    }

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return ValueListenableBuilder<bool>(
          valueListenable: darkModeNotifier,
          builder: (context, isDark, child) {
            return StatefulBuilder(
              builder: (context, setModalState) {
                return Container(
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                  padding: EdgeInsets.only(
                      bottom: MediaQuery.of(context).viewInsets.bottom,
                      left: 24, right: 24, top: 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.settings_suggest_rounded, color: Color(0xFF6366F1), size: 28),
                          const SizedBox(width: 12),
                          Text('Masa İçi Ayarlar', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF0F172A))),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF6366F1)),
                            tooltip: 'Cihazları Yenile',
                            onPressed: () async {
                              try {
                                List<MediaDeviceInfo> updatedDevices = await navigator.mediaDevices.enumerateDevices();
                                setModalState(() {
                                  audioInputs = updatedDevices.where((d) => d.kind == 'audioinput').toList();
                                  audioOutputs = updatedDevices.where((d) => d.kind == 'audiooutput').toList();
                                  if (audioInputs.isNotEmpty && !audioInputs.any((d) => d.deviceId == _selectedAudioInputId)) {
                                    _selectedAudioInputId = audioInputs.first.deviceId;
                                  }
                                  if (audioOutputs.isNotEmpty && !audioOutputs.any((d) => d.deviceId == _selectedAudioOutputId)) {
                                    _selectedAudioOutputId = audioOutputs.first.deviceId;
                                  }
                                });
                              } catch (e) {
                                debugPrint("Yenileme hatası: $e");
                              }
                            },
                          ),
                          IconButton(
                            icon: Icon(Icons.close_rounded, color: isDark ? const Color(0xFFA6ADC8) : const Color(0xFF64748B)),
                            onPressed: () => Navigator.pop(context),
                          )
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Icon(isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                              color: isDark ? Colors.amber : const Color(0xFF64748B), size: 22),
                          const SizedBox(width: 8),
                          Text('Karanlık Tema', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF475569))),
                          const Spacer(),
                          Switch(
                            value: isDark,
                            activeColor: const Color(0xFF6366F1),
                            onChanged: (val) {
                              darkModeNotifier.value = val;
                              prefs.setBool('isDarkMode', val);
                              setModalState(() {});
                            },
                          ),
                        ],
                      ),
                      Divider(color: isDark ? const Color(0xFF313244) : Colors.grey.shade200, height: 32),
                      Text('Mikrofon (Giriş Cihazı)', style: TextStyle(fontWeight: FontWeight.w700, color: isDark ? const Color(0xFFA6ADC8) : const Color(0xFF475569))),
                      const SizedBox(height: 8),
                      if (audioInputs.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: Text('Sistem varsayılan girişi kullanılıyor.', style: TextStyle(color: isDark ? const Color(0xFF6C7086) : Colors.grey, fontStyle: FontStyle.italic, fontSize: 14)),
                        )
                      else
                        DropdownButtonFormField<String>(
                          dropdownColor: isDark ? const Color(0xFF232336) : Colors.white,
                          isExpanded: true,
                          value: _selectedAudioInputId,
                          items: audioInputs.map((d) => DropdownMenuItem(
                                value: d.deviceId,
                                child: Text(d.label.isNotEmpty ? d.label : 'Bilinmeyen Mikrofon', style: TextStyle(color: isDark ? Colors.white : const Color(0xFF1E293B), fontSize: 14, fontWeight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis),
                              )).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setModalState(() => _selectedAudioInputId = val);
                              _changeMicrophone(val);
                            }
                          },
                          decoration: InputDecoration(
                            filled: true, fillColor: isDark ? const Color(0xFF181825) : const Color(0xFFF8FAFC),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: isDark ? const Color(0xFF313244) : Colors.grey.shade300)),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: isDark ? const Color(0xFF313244) : Colors.grey.shade300)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          ),
                        ),
                      const SizedBox(height: 16),
                      if (!isMobile) ...[
                        Row(
                          children: [
                            Icon(Icons.mic_none_rounded, color: isDark ? const Color(0xFFA6ADC8) : const Color(0xFF94A3B8), size: 20),
                            const SizedBox(width: 8),
                            Text('Mikrofon Hassasiyeti', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isDark ? const Color(0xFFA6ADC8) : const Color(0xFF64748B))),
                            Expanded(
                              child: Slider(
                                value: _micVolume,
                                activeColor: const Color(0xFF10B981),
                                onChanged: (val) {
                                  setModalState(() => _micVolume = val);
                                  _setLocalMicVolume(val);
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                      ],
                      Text('Hoparlör (Çıkış Cihazı)', style: TextStyle(fontWeight: FontWeight.w700, color: isDark ? const Color(0xFFA6ADC8) : const Color(0xFF475569))),
                      const SizedBox(height: 8),
                      if (audioOutputs.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: Text('Sistem varsayılan çıkışı kullanılıyor.', style: TextStyle(color: isDark ? const Color(0xFF6C7086) : Colors.grey, fontStyle: FontStyle.italic, fontSize: 14)),
                        )
                      else
                        DropdownButtonFormField<String>(
                          dropdownColor: isDark ? const Color(0xFF232336) : Colors.white,
                          isExpanded: true,
                          value: _selectedAudioOutputId,
                          items: audioOutputs.map((d) => DropdownMenuItem(
                                value: d.deviceId,
                                child: Text(d.label.isNotEmpty ? d.label : 'Bilinmeyen Hoparlör', style: TextStyle(color: isDark ? Colors.white : const Color(0xFF1E293B), fontSize: 14, fontWeight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis),
                              )).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setModalState(() => _selectedAudioOutputId = val);
                              _changeSpeaker(val);
                            }
                          },
                          decoration: InputDecoration(
                            filled: true, fillColor: isDark ? const Color(0xFF181825) : const Color(0xFFF8FAFC),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: isDark ? const Color(0xFF313244) : Colors.grey.shade300)),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: isDark ? const Color(0xFF313244) : Colors.grey.shade300)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          ),
                        ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Icon(Icons.volume_down_rounded, color: isDark ? const Color(0xFFA6ADC8) : const Color(0xFF94A3B8), size: 20),
                          const SizedBox(width: 8),
                          Text('Uygulama Sesi', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isDark ? const Color(0xFFA6ADC8) : const Color(0xFF64748B))),
                          Expanded(
                            child: Slider(
                              value: _speakerVolume,
                              activeColor: const Color(0xFF6366F1),
                              onChanged: (val) {
                                setModalState(() => _speakerVolume = val);
                                _setSpeakerVolume(val);
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),
                    ],
                  ),
                );
              },
            );
          }
        );
      },
    );
  }

  // Çalışma esnasında mikrofon değiştiğinde mevcut WebRTC ses izlerini yeni mikrofonla değiştirir.
  Future<void> _changeMicrophone(String deviceId) async {
    try {
      final constraints = {
        'audio': {
          'deviceId': {'exact': deviceId},
          'echoCancellation': true,
          'noiseSuppression': true,
          'autoGainControl': true,
        },
        'video': false,
      };

      MediaStream newStream = await navigator.mediaDevices.getUserMedia(constraints);
      if (newStream.getAudioTracks().isNotEmpty) {
        MediaStreamTrack newAudioTrack = newStream.getAudioTracks().first;
        newAudioTrack.enabled = !_isMuted;

        try {
          bool isMobile = !kIsWeb && (Platform.isAndroid || Platform.isIOS);
          if (!isMobile) {
            await Helper.setVolume(_micVolume, newAudioTrack);
          }
        } catch (e) {
          debugPrint("Mikrofon değişiminde ses uygulanamadı: $e");
        }

        for (var pc in _peers.values) {
          var senders = await pc.getSenders();
          for (var sender in senders) {
            if (sender.track?.kind == 'audio') {
              await sender.replaceTrack(newAudioTrack);
            }
          }
        }

        if (_localStream != null) {
          for (var track in _localStream!.getTracks()) track.stop();
          _localStream!.dispose();
        }
        _localStream = newStream;
      }
      
      prefs.setString('selectedMicId', deviceId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Mikrofon değiştirildi.')));
      }
    } catch (e) {
      debugPrint("Mikrofon değiştirme hatası: $e");
    }
  }

  Future<void> _changeSpeaker(String deviceId) async {
    try {
      if (!kIsWeb && (Platform.isWindows || Platform.isMacOS)) {
        await Helper.selectAudioOutput(deviceId);
      }
      
      prefs.setString('selectedSpeakerId', deviceId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Hoparlör değiştirildi.')));
      }
    } catch (e) {
      debugPrint("Hoparlör değiştirme hatası: $e");
    }
  }

  // Firestore'dan gelen WebRTC bağlantı sinyallerini (SDP Offer/Answer ve ICE Candidate) işler.
  void _handleSignals(QuerySnapshot snapshot) async {
    for (var change in snapshot.docChanges) {
      if (change.type == DocumentChangeType.added) {
        var doc = change.doc.data() as Map<String, dynamic>;
        String sender = doc['sender'];
        String type = doc['type'];
        var data = doc['data'];

        if (type == 'offer') {
          try {
            var pc = await _createPeerConnection(sender);
            await pc.setRemoteDescription(
                RTCSessionDescription(data['sdp'], data['type']));

            _remoteDescriptionSet.add(sender);
            _processCandidateQueue(sender);

            var answer = await pc.createAnswer({'offerToReceiveAudio': true});
            await pc.setLocalDescription(answer);
            _sendSignal(sender, 'answer',
                {'sdp': answer.sdp, 'type': answer.type});
          } catch (e) {
            debugPrint('Offer islenirken hata: $e');
          }
        } else if (type == 'answer') {
          try {
            var pc = _peers[sender];
            if (pc != null) {
              await pc.setRemoteDescription(
                  RTCSessionDescription(data['sdp'], data['type']));

              _remoteDescriptionSet.add(sender);
              _processCandidateQueue(sender);
            }
          } catch (e) {
            debugPrint('Answer islenirken hata: $e');
          }
        } else if (type == 'candidate') {
          try {
            String? candidateStr = data['candidate'];
            String? sdpMid = data['sdpMid'];
            
            int? sdpMLineIndex;
            var rawIndex = data['sdpMLineIndex'] ?? data['sdpMlineIndex'];
            if (rawIndex != null) {
              sdpMLineIndex = int.tryParse(rawIndex.toString());
            }

            if (candidateStr != null) {
              var candidate = RTCIceCandidate(candidateStr, sdpMid, sdpMLineIndex);

              if (_remoteDescriptionSet.contains(sender) &&
                  _peers[sender] != null) {
                await _peers[sender]!.addCandidate(candidate);
              } else {
                _candidateQueue.putIfAbsent(sender, () => []).add(candidate);
              }
            }
          } catch (e) {
            debugPrint('Candidate islenirken hata: $e');
          }
        }

        change.doc.reference
            .delete()
            .catchError((e) => debugPrint('Sinyal silinirken hata: $e'));
      }
    }
  }

  void _processCandidateQueue(String peerId) {
    if (_candidateQueue.containsKey(peerId)) {
      for (var cand in _candidateQueue[peerId]!) {
        _peers[peerId]?.addCandidate(cand);
      }
      _candidateQueue.remove(peerId);
    }
  }

  // Yeni katılan kullanıcılar için ilk WebRTC el sıkışmasını (SDP Offer) başlatır.
  Future<void> _initiateConnection(String peerId) async {
    try {
      var pc = await _createPeerConnection(peerId);
      var offer = await pc.createOffer({'offerToReceiveAudio': true});
      await pc.setLocalDescription(offer);
      _sendSignal(peerId, 'offer', {'sdp': offer.sdp, 'type': offer.type});
    } catch (e) {
      debugPrint('Baglanti baslatilirken hata ($peerId): $e');
    }
  }

  // Herhangi bir sebepten dolayı kopan Peer (Eş) bağlantılarını sıfırlayıp yeniden bağlar.
  void _handleConnectionFailure(String peerId) {
    if (!mounted) return;
    debugPrint("Bağlantı koptu veya başarısız oldu: $peerId. Yeniden kuruluyor...");
    _removePeer(peerId);
    
    if (widget.username.compareTo(peerId) > 0) {
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted && !_peers.containsKey(peerId)) {
          _initiateConnection(peerId);
        }
      });
    }
  }

  // Belirli bir kullanıcı için RTCPeerConnection (P2P bağlantı) nesnesini oluşturur ve yapılandırır.
  Future<RTCPeerConnection> _createPeerConnection(String peerId) async {
    if (_peers.containsKey(peerId)) {
      try {
        await _peers[peerId]?.close();
        await _peers[peerId]?.dispose();
      } catch (e) {
        debugPrint("Eski bağlantı temizlenirken hata: $e");
      }
      _peers.remove(peerId);
    }

    Map<String, dynamic> configuration = {
      "iceServers": [
        {"urls": "stun:stun.l.google.com:19302"},
        {"urls": "stun:stun1.l.google.com:19302"},
      ]
    };

    RTCPeerConnection pc = await createPeerConnection(configuration);

    if (_localStream != null) {
      for (var track in _localStream!.getTracks()) {
        await pc.addTrack(track, _localStream!);
      }
    }

    pc.onIceConnectionState = (RTCIceConnectionState state) {
      debugPrint('ICE Baglanti Durumu Degisti ($peerId): $state');
      if (state == RTCIceConnectionState.RTCIceConnectionStateFailed ||
          state == RTCIceConnectionState.RTCIceConnectionStateDisconnected) {
        _handleConnectionFailure(peerId);
      }
    };

    pc.onIceCandidate = (RTCIceCandidate candidate) {
      if (candidate.candidate != null) {
        Map<String, dynamic> candidateMap = {
          'candidate': candidate.candidate,
          'sdpMid': candidate.sdpMid,
          'sdpMLineIndex': candidate.sdpMLineIndex,
          'sdpMlineIndex': candidate.sdpMLineIndex,
        };
        _sendSignal(peerId, 'candidate', candidateMap);
      }
    };

    pc.onTrack = (RTCTrackEvent event) async {
      if (event.track.kind == 'audio') {
        _remoteAudioTracks[peerId] = event.track;
        event.track.enabled = !_isDeaf && !(_localMutedUsers[peerId] ?? false);

        try {
          await Helper.setVolume(_speakerVolume, event.track);
        } catch (e) {
          debugPrint("Uzak kanala başlangıç ses seviyesi uygulanamadı: $e");
        }

        await _forceSpeakerphone();

        bool isMobile = !kIsWeb && (Platform.isAndroid || Platform.isIOS);
        if (!isMobile) {
          if (event.streams.isNotEmpty) {
            final remoteStream = event.streams[0];
            _remoteStreams[peerId] = remoteStream;
            final renderer = RTCVideoRenderer();
            await renderer.initialize();
            renderer.srcObject = remoteStream;
            _remoteRenderers[peerId] = renderer;
          }
        }
      }
    };

    _peers[peerId] = pc;
    return pc;
  }

  // WebRTC el sıkışma paketlerini Firestore'a yazarak karşı tarafa ulaştırır.
  void _sendSignal(String target, String type, Map<String, dynamic> data) {
    _firestore
        .collection('lobiler')
        .doc(widget.roomCode)
        .collection('signals')
        .add({
      'sender': widget.username,
      'target': target,
      'type': type,
      'data': data,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  // Ayrılan eşin (Peer) tüm WebRTC ve donanım kaynaklarını bellekten temizler.
  void _removePeer(String peerId) {
    try {
      _peers[peerId]?.close();
      _peers[peerId]?.dispose(); 
    } catch (e) {
      debugPrint("Bağlantı kapatılırken hata: $e");
    }
    _peers.remove(peerId);
    _remoteAudioTracks.remove(peerId);
    _candidateQueue.remove(peerId);
    _remoteDescriptionSet.remove(peerId);
    
    try {
      _remoteRenderers[peerId]?.dispose();
    } catch (e) {
      debugPrint("Renderer silinirken hata: $e");
    }
    _remoteRenderers.remove(peerId);
    _remoteStreams.remove(peerId);
  }

  // WebRTC ses istatistiklerini (audioLevel) okuyarak kullanıcının o an konuşup konuşmadığını tespit eder.
  void _startAudioLevelMonitoring() {
    _statsTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) async {
      if (!mounted || _peers.isEmpty || _isMuted) {
        if (_isSpeaking) _updateSpeakingState(false);
        return;
      }

      try {
        RTCPeerConnection? activePc;
        for (var pc in _peers.values) {
          if (pc.connectionState == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
            activePc = pc;
            break;
          }
        }

        if (activePc == null) {
          if (_isSpeaking) _updateSpeakingState(false);
          return;
        }

        var stats = await activePc.getStats();
        bool isCurrentlySpeaking = false;

        for (var report in stats) {
          if (report.type == 'media-source') {
            var values = report.values;
            if (values.containsKey('audioLevel')) {
              double level = double.tryParse(values['audioLevel'].toString()) ?? 0.0;
              if (level > 0.03) {
                isCurrentlySpeaking = true;
              }
            }
          }
        }

        if (_isSpeaking != isCurrentlySpeaking) {
          _updateSpeakingState(isCurrentlySpeaking);
        }
      } catch (e) {
        debugPrint("Stats monitoring pasif hata: $e");
      }
    });
  }

  void _updateSpeakingState(bool state) {
    if (!mounted) return;
    setState(() => _isSpeaking = state);

    _firestore
        .collection('lobiler')
        .doc(widget.roomCode)
        .collection('katilimcilar')
        .doc(widget.username)
        .update({'isSpeaking': state});
  }

  void _enterRoomRegistry() {
    _firestore
        .collection('lobiler')
        .doc(widget.roomCode)
        .collection('katilimcilar')
        .doc(widget.username)
        .set({
      'isim': widget.username,
      'isMuted': _isMuted,
      'isDeaf': _isDeaf,
      'isSpeaking': false,
      'heartbeat': 1, 
      'girisTarihi': FieldValue.serverTimestamp(),
    });
  }

  void _updateRegistry() {
    _firestore
        .collection('lobiler')
        .doc(widget.roomCode)
        .collection('katilimcilar')
        .doc(widget.username)
        .set({
      'isim': widget.username,
      'isMuted': _isMuted,
      'isDeaf': _isDeaf,
      'isSpeaking': _isSpeaking,
      'heartbeat': FieldValue.increment(1),
      'girisTarihi': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  void _sendSystemMessage(String text) {
    _firestore
        .collection('lobiler')
        .doc(widget.roomCode)
        .collection('mesajlar')
        .add({
      'gonderen': 'Sistem',
      'mesaj': text,
      'tarih': FieldValue.serverTimestamp(),
      'isSystem': true,
      'isWhisper': false,
    });
  }

  // Normal mesajları veya hedeflenen kullanıcıya özel gizli fısıltıları Firestore'a yazar.
  void _sendTextMessage() {
    if (_messageController.text.isNotEmpty) {
      bool isWhisper = _selectedWhisperTarget != null;
      _firestore
          .collection('lobiler')
          .doc(widget.roomCode)
          .collection('mesajlar')
          .add({
        'gonderen': widget.username,
        'mesaj': _messageController.text,
        'tarih': FieldValue.serverTimestamp(),
        'isSystem': false,
        'isWhisper': isWhisper,
        'whisperTarget': _selectedWhisperTarget,
      });
      _messageController.clear();
      setState(() => _selectedWhisperTarget = null);
    }
  }

  void _toggleMute() {
    if (_localStream != null && _localStream!.getAudioTracks().isNotEmpty) {
      setState(() {
        _isMuted = !_isMuted;
        _localStream!.getAudioTracks()[0].enabled = !_isMuted;
        if (_isMuted) _updateSpeakingState(false);
      });
      _updateRegistry();
    }
  }

  void _toggleDeaf() {
    setState(() {
      _isDeaf = !_isDeaf;
      _remoteAudioTracks.forEach((peerId, track) {
        track.enabled = !_isDeaf && !(_localMutedUsers[peerId] ?? false);
      });
    });
    _updateRegistry();
  }

  void _toggleLocalMute(String targetUser) {
    setState(() {
      bool isCurrentlyMuted = _localMutedUsers[targetUser] ?? false;
      _localMutedUsers[targetUser] = !isCurrentlyMuted;

      if (_remoteAudioTracks.containsKey(targetUser)) {
        _remoteAudioTracks[targetUser]!.enabled =
            !_isDeaf && !_localMutedUsers[targetUser]!;
      }
    });
  }

  void _leaveRoom() async {
    _sendSystemMessage("${widget.username} masadan ayrıldı.");

    var roomRef = _firestore.collection('lobiler').doc(widget.roomCode);

    await roomRef.collection('katilimcilar').doc(widget.username).delete();

    var mySignals = await roomRef
        .collection('signals')
        .where('target', isEqualTo: widget.username)
        .get();
    for (var doc in mySignals.docs) doc.reference.delete();

    if (mounted) Navigator.pop(context);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);

    _statsTimer?.cancel();
    _heartbeatTimer?.cancel(); 
    _signalSubscription?.cancel();
    _participantsSubscription?.cancel();

    _firestore
        .collection('lobiler')
        .doc(widget.roomCode)
        .collection('katilimcilar')
        .doc(widget.username)
        .delete();

    for (var pc in _peers.values) {
      try {
        pc.close();
        pc.dispose();
      } catch (e) {
        debugPrint("Kapatmada hata: $e");
      }
    }
    _peers.clear();
    _remoteAudioTracks.clear();
    _candidateQueue.clear();
    _remoteDescriptionSet.clear();

    for (var renderer in _remoteRenderers.values) {
      try {
        renderer.dispose();
      } catch (e) {
        debugPrint("Renderer imhasında hata: $e");
      }
    }
    _remoteRenderers.clear();
    _remoteStreams.clear();

    if (_localStream != null) {
      try {
        for (var track in _localStream!.getTracks()) track.stop();
        _localStream!.dispose();
      } catch (e) {
        debugPrint("Lokal stream imhasında hata: $e");
      }
    }
    _messageController.dispose();
    super.dispose();
  }

  String _formatTime(Timestamp? timestamp) {
    if (timestamp == null) return "...";
    DateTime date = timestamp.toDate();
    return "${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}";
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: darkModeNotifier,
      builder: (context, isDark, child) {
        return Scaffold(
          backgroundColor: isDark ? const Color(0xFF11111B) : const Color(0xFFF4F7FA),
          appBar: AppBar(
            backgroundColor: isDark ? const Color(0xFF1E1E2E) : Colors.white,
            elevation: 0,
            centerTitle: true,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
            ),
            leading: IconButton(
              icon: Icon(Icons.arrow_back_ios_new_rounded,
                  color: isDark ? Colors.white : const Color(0xFF334155), size: 22),
              onPressed: _leaveRoom,
            ),
            title: Column(
              children: [
                Text(widget.roomCode,
                    style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                        color: isDark ? Colors.white : const Color(0xFF0F172A))),
                Text('Zahter Kıraathane',
                    style: TextStyle(
                        fontSize: 12,
                        color: isDark ? const Color(0xFFA6ADC8) : const Color(0xFF64748B),
                        fontWeight: FontWeight.w600)),
              ],
            ),
            actions: [
              IconButton(
                icon: Icon(Icons.settings_suggest_rounded, color: isDark ? const Color(0xFFA6ADC8) : const Color(0xFF64748B), size: 24),
                onPressed: _showSettingsDialog,
              ),
              IconButton(
                icon: Icon(_isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
                    color: _isMuted ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                    size: 24),
                onPressed: _toggleMute,
              ),
              IconButton(
                icon: Icon(
                    _isDeaf ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                    color: _isDeaf ? const Color(0xFFF59E0B) : const Color(0xFF6366F1),
                    size: 24),
                onPressed: _toggleDeaf,
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: Column(
            children: [
              if (_isMuted || _isDeaf)
                Container(
                  margin: const EdgeInsets.only(top: 8, left: 16, right: 16),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF4A1525) : Colors.red.shade50,
                      borderRadius: BorderRadius.circular(12)),
                  child: Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _isMuted && _isDeaf 
                              ? Icons.headset_off_rounded 
                              : (_isDeaf ? Icons.headset_off_rounded : Icons.mic_off_rounded),
                          color: isDark ? const Color(0xFFFCA5A5) : Colors.red,
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _isMuted && _isDeaf
                              ? "Mikrofon ve Kulaklık kapalı."
                              : _isDeaf
                                  ? "Kulaklık kapalı (Sağır modu)."
                                  : "Mikrofonunuz kapalı.",
                          style: TextStyle(
                              fontSize: 13,
                              color: isDark ? const Color(0xFFFCA5A5) : Colors.red,
                              fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
              Container(
                height: 80,
                width: double.infinity,
                margin: const EdgeInsets.only(top: 8),
                child: StreamBuilder<QuerySnapshot>(
                  stream: _participantsStream, 
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const SizedBox();
                    var members = snapshot.data!.docs;
                    return ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: members.length,
                      itemBuilder: (context, index) {
                        var member = members[index].data() as Map<String, dynamic>;
                        String uName = member['isim'] ?? '';
                        bool mMuted = member['isMuted'] ?? false;
                        bool mDeaf = member['isDeaf'] ?? false;
                        bool mSpeaking = member['isSpeaking'] ?? false;
                        bool isLocalMuted = _localMutedUsers[uName] ?? false;
                        bool isMe = uName == widget.username;

                        String firstChar =
                            uName.isNotEmpty ? uName.substring(0, 1).toUpperCase() : "?";
                        bool isSelectedWhisper = _selectedWhisperTarget == uName;

                        return GestureDetector(
                          onTap: () {
                            if (!isMe) {
                              setState(() => _selectedWhisperTarget =
                                  isSelectedWhisper ? null : uName);
                            }
                          },
                          child: Container(
                            margin: const EdgeInsets.only(right: 10, top: 8, bottom: 8),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 6),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF232336) : Colors.white,
                              borderRadius: BorderRadius.circular(24),
                              boxShadow: [
                                if (mSpeaking)
                                  BoxShadow(
                                      color: Colors.greenAccent.withOpacity(0.6),
                                      blurRadius: 15,
                                      spreadRadius: 2)
                                else
                                  BoxShadow(
                                      color: Colors.black.withOpacity(0.03),
                                      blurRadius: 8,
                                      offset: const Offset(0, 4))
                              ],
                              border: Border.all(
                                color: mSpeaking
                                    ? Colors.green
                                    : (isSelectedWhisper
                                        ? const Color(0xFF6366F1)
                                        : Colors.transparent),
                                width: mSpeaking ? 2.0 : 1.5,
                              ),
                            ),
                            child: Row(
                              children: [
                                Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    CircleAvatar(
                                      radius: 16,
                                      backgroundColor: isMe
                                          ? const Color(0xFF10B981)
                                          : const Color(0xFF6366F1),
                                      child: Text(firstChar,
                                          style: const TextStyle(
                                              fontSize: 14,
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold)),
                                    ),
                                    if (mSpeaking && !mMuted)
                                      Positioned(
                                        bottom: -2,
                                        right: -2,
                                        child: Container(
                                          padding: const EdgeInsets.all(2),
                                          decoration: const BoxDecoration(
                                              color: Colors.white,
                                              shape: BoxShape.circle),
                                          child: const Icon(Icons.graphic_eq_rounded,
                                              size: 12, color: Colors.green),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(width: 10),
                                Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      isMe ? 'Sen' : uName,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: mSpeaking
                                            ? FontWeight.w800
                                            : FontWeight.w700,
                                        color: mSpeaking
                                            ? Colors.green.shade500
                                            : (isDark ? Colors.white : const Color(0xFF1E293B)),
                                      ),
                                    ),
                                    Row(
                                      children: [
                                        Icon(
                                            mMuted
                                                ? Icons.mic_off_rounded
                                                : Icons.mic_rounded,
                                            size: 12,
                                            color: mMuted
                                                ? const Color(0xFFEF4444)
                                                : const Color(0xFF94A3B8)),
                                        const SizedBox(width: 4),
                                        Icon(
                                            mDeaf
                                                ? Icons.volume_off_rounded
                                                : Icons.volume_up_rounded,
                                            size: 12,
                                            color: mDeaf
                                                ? const Color(0xFFF59E0B)
                                                : const Color(0xFF94A3B8)),
                                      ],
                                    )
                                  ],
                                ),
                                if (!isMe) ...[
                                  const SizedBox(width: 8),
                                  GestureDetector(
                                    onTap: () => _toggleLocalMute(uName),
                                    child: Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: isLocalMuted
                                            ? (isDark ? const Color(0xFF4A1525) : Colors.red.shade50)
                                            : (isDark ? const Color(0xFF313244) : const Color(0xFFF1F5F9)),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        isLocalMuted
                                            ? Icons.volume_off_rounded
                                            : Icons.volume_up_rounded,
                                        size: 14,
                                        color: isLocalMuted
                                            ? const Color(0xFFEF4444)
                                            : (isDark ? const Color(0xFFA6ADC8) : const Color(0xFF64748B)),
                                      ),
                                    ),
                                  ),
                                ]
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: _messagesStream, 
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                      return const Center(
                          child: CircularProgressIndicator(color: Color(0xFF6366F1)));
                    }
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.speaker_notes_off_rounded,
                                size: 48, color: isDark ? const Color(0xFF45475A) : const Color(0xFFCBD5E1)),
                            const SizedBox(height: 12),
                            Text("Masada henüz çıt yok.\nSohbeti sen başlat!",
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    color: isDark ? const Color(0xFF6C7086) : const Color(0xFF94A3B8), fontSize: 15)),
                          ],
                        ),
                      );
                    }

                    var docs = snapshot.data!.docs;
                    return ListView.builder(
                      reverse: true,
                      padding:
                          const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      itemCount: docs.length,
                      itemBuilder: (context, index) {
                        var data = docs[index].data() as Map<String, dynamic>;
                        String sender = data['gonderen'] ?? '';
                        bool isMe = sender == widget.username;
                        bool isSystem = data['isSystem'] ?? false;
                        bool isWhisper = data['isWhisper'] ?? false;
                        String? whisperTarget = data['whisperTarget'];
                        String timeText = _formatTime(data['tarih'] as Timestamp?);

                        if (isWhisper &&
                            sender != widget.username &&
                            whisperTarget != widget.username) {
                          return const SizedBox.shrink();
                        }

                        if (isSystem) {
                          return Center(
                            child: Container(
                              margin: const EdgeInsets.symmetric(vertical: 12),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 6),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF232336) : Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                      color: Colors.black.withOpacity(0.02),
                                      blurRadius: 4)
                                ],
                              ),
                              child: Text(data['mesaj'] ?? '',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: isDark ? const Color(0xFFA6ADC8) : const Color(0xFF64748B),
                                      fontWeight: FontWeight.w500)),
                            ),
                          );
                        }

                        return Align(
                          alignment:
                              isMe ? Alignment.centerRight : Alignment.centerLeft,
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            constraints: BoxConstraints(
                                maxWidth: MediaQuery.of(context).size.width * 0.75),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: isWhisper
                                  ? (isDark ? const Color(0xFF3B2D50) : const Color(0xFFF3E8FF))
                                  : (isMe
                                      ? const Color(0xFF6366F1)
                                      : (isDark ? const Color(0xFF232336) : Colors.white)),
                              borderRadius: BorderRadius.only(
                                topLeft: const Radius.circular(20),
                                topRight: const Radius.circular(20),
                                bottomLeft: isMe
                                    ? const Radius.circular(20)
                                    : const Radius.circular(4),
                                bottomRight: isMe
                                    ? const Radius.circular(4)
                                    : const Radius.circular(20),
                              ),
                              boxShadow: [
                                BoxShadow(
                                    color: isMe
                                        ? const Color(0xFF6366F1).withOpacity(0.2)
                                        : Colors.black.withOpacity(isDark ? 0.2 : 0.04),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4))
                              ],
                              border: isWhisper
                                  ? Border.all(
                                      color: const Color(0xFFD8B4FE), width: 1)
                                  : null,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (!isMe) ...[
                                  Text(
                                    isWhisper
                                        ? '$sender 🔒 [Sana Fısıldadı]'
                                        : sender,
                                    style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w800,
                                        color: isWhisper
                                            ? const Color(0xFF7C3AED)
                                            : const Color(0xFF6366F1)),
                                  ),
                                  const SizedBox(height: 4),
                                ],
                                if (isMe && isWhisper) ...[
                                  Text(
                                    '🔒 $whisperTarget kişisine fısıldadın:',
                                    style: const TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF9333EA),
                                        fontStyle: FontStyle.italic,
                                        fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 4),
                                ],
                                Text(
                                  data['mesaj'] ?? '',
                                  style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w500,
                                      color: isMe && !isWhisper
                                          ? Colors.white
                                          : (isDark ? Colors.white : const Color(0xFF1E293B))),
                                ),
                                const SizedBox(height: 6),
                                Align(
                                  alignment: Alignment.bottomRight,
                                  child: Text(
                                    timeText,
                                    style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: isMe && !isWhisper
                                            ? Colors.white.withOpacity(0.7)
                                            : (isDark ? const Color(0xFF6C7086) : const Color(0xFF94A3B8))),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
              SafeArea(
                child: Container(
                  margin: const EdgeInsets.only(
                      left: 16, right: 16, bottom: 16, top: 8),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 20,
                          offset: const Offset(0, 5))
                    ],
                    border: Border.all(
                        color: _selectedWhisperTarget != null
                            ? const Color(0xFF9333EA)
                            : Colors.transparent,
                        width: 1.5),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_selectedWhisperTarget != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF3B2D50) : const Color(0xFFF3E8FF),
                            borderRadius:
                                const BorderRadius.vertical(top: Radius.circular(28)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.lock_outline_rounded,
                                  size: 14, color: Color(0xFF7C3AED)),
                              const SizedBox(width: 6),
                              Text(
                                '$_selectedWhisperTarget kişisine gizli fısıltı...',
                                style: const TextStyle(
                                    color: Color(0xFF7C3AED),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700),
                              ),
                              const Spacer(),
                              GestureDetector(
                                onTap: () =>
                                    setState(() => _selectedWhisperTarget = null),
                                child: const Icon(Icons.close_rounded,
                                    size: 16, color: Color(0xFF7C3AED)),
                              )
                            ],
                          ),
                        ),
                      Row(
                        children: [
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: _messageController,
                              textInputAction: TextInputAction.send,
                              onSubmitted: (value) => _sendTextMessage(),
                              style: TextStyle(
                                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500),
                              decoration: InputDecoration(
                                hintText: _selectedWhisperTarget != null
                                    ? 'Fısıltı yazın...'
                                    : 'Masaya bir şeyler yaz...',
                                hintStyle:
                                    TextStyle(color: isDark ? const Color(0xFF6C7086) : const Color(0xFF94A3B8)),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 14),
                              ),
                            ),
                          ),
                          Container(
                            margin: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: _selectedWhisperTarget != null
                                  ? const Color(0xFF9333EA)
                                  : const Color(0xFF6366F1),
                              shape: BoxShape.circle,
                            ),
                            child: IconButton(
                              icon: const Icon(Icons.send_rounded,
                                  color: Colors.white, size: 20),
                              onPressed: _sendTextMessage,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      }
    );
  }
}