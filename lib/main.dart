import 'dart:convert';
import 'dart:typed_data';

import 'package:borrowit/firebase_options.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'screens/auth_screen.dart';
import 'screens/home.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  if (!kIsWeb) {
    await initNotifications();
  }
  runApp(const BorrowItApp());
}

// BRAND PALETTE
class BorrowColors {
  static const Color navy = Color(0xFF232A4E);
  static const Color gold = Color(0xFFE5A93B);
  static const Color offWhite = Color(0xFFF6F4EE);
  static const Color background = Color(0xFFF8F9FC);
  static const Color cardBorder = Color(0xFFE5E7EB);
}

// MODELS
enum Status { pending, approved, borrowed, returned, cancelled }

extension StatusX on Status {
  String get label => name[0].toUpperCase() + name.substring(1);

  Color get color => switch (this) {
    Status.pending => BorrowColors.gold,
    Status.approved => const Color(0xFF2E63E5),
    Status.borrowed => const Color(0xFF7E3AF2),
    Status.returned => const Color(0xFF0E9F6E),
    Status.cancelled => const Color(0xFF9CA3AF),
  };

  static Status parse(String? s) =>
      Status.values.firstWhere((e) => e.name == s, orElse: () => Status.pending);
}

class Equipment {
  final String id, name, description, category;
  final String? imageUrl;
  final int total, available;

  Equipment({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    required this.total,
    required this.available,
    this.imageUrl,
  });

  factory Equipment.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data() ?? {};
    final img = (m['imageUrl'] ?? '') as String;
    return Equipment(
      id: d.id,
      name: m['name'] ?? '',
      description: m['description'] ?? '',
      category: m['category'] ?? 'General',
      total: (m['total'] ?? 0) as int,
      available: (m['available'] ?? 0) as int,
      imageUrl: img.isEmpty ? null : img,
    );
  }
}

class BorrowRequest {
  final String id, userId, equipmentId, equipmentName, purpose;
  final String? equipmentImageUrl, attachmentBase64;
  final DateTime needed, returnDate, createdAt;
  final Status status;

  BorrowRequest({
    required this.id,
    required this.userId,
    required this.equipmentId,
    required this.equipmentName,
    required this.purpose,
    required this.needed,
    required this.returnDate,
    required this.createdAt,
    required this.status,
    this.equipmentImageUrl,
    this.attachmentBase64,
  });

  factory BorrowRequest.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data() ?? {};
    DateTime ts(String k) => (m[k] as Timestamp?)?.toDate() ?? DateTime.now();
    String? opt(String k) {
      final v = (m[k] ?? '') as String;
      return v.isEmpty ? null : v;
    }

    return BorrowRequest(
      id: d.id,
      userId: m['userId'] ?? '',
      equipmentId: m['equipmentId'] ?? '',
      equipmentName: m['equipmentName'] ?? '',
      purpose: m['purpose'] ?? '',
      equipmentImageUrl: opt('equipmentImageUrl'),
      attachmentBase64: opt('attachmentBase64'),
      needed: ts('needed'),
      returnDate: ts('returnDate'),
      createdAt: ts('createdAt'),
      status: StatusX.parse(m['status']),
    );
  }
}

// AUTH & FIRESTORE
final _auth = FirebaseAuth.instance;
final _db = FirebaseFirestore.instance;

String currentUserName() =>
    _auth.currentUser?.displayName ?? _auth.currentUser?.email ?? 'Student';

Future<void> login(String email, String password) =>
    _auth.signInWithEmailAndPassword(email: email.trim(), password: password);

Future<void> register(String name, String email, String password) async {
  final cred = await _auth.createUserWithEmailAndPassword(
      email: email.trim(), password: password);
  await cred.user!.updateDisplayName(name.trim());
  await _db.collection('users').doc(cred.user!.uid).set({
    'name': name.trim(),
    'email': email.trim(),
    'createdAt': FieldValue.serverTimestamp(),
  });
}

Future<void> logout() => _auth.signOut();

String authMessage(Object e) {
  if (e is FirebaseAuthException) {
    switch (e.code) {
      case 'invalid-email':
        return 'Invalid email address';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Invalid email or password';
      case 'email-already-in-use':
        return 'Email already registered';
      case 'weak-password':
        return 'Password must be at least 6 characters';
      default:
        return e.message ?? 'Authentication failed';
    }
  }
  return e.toString();
}

Stream<List<Equipment>> streamEquipment() => _db
    .collection('equipment')
    .orderBy('name')
    .snapshots()
    .map((s) => s.docs.map(Equipment.fromDoc).toList());

Stream<Equipment?> streamEquipmentOne(String id) => _db
    .collection('equipment')
    .doc(id)
    .snapshots()
    .map((d) => d.exists ? Equipment.fromDoc(d) : null);

Future<void> seedSamples() async {
  const items = [
    ['Laptop', 'Dell Latitude 14", 16GB RAM, Windows 11. Charger included.', 'Computers', 5],
    ['Projector', 'Epson 3600-lumen HDMI/VGA projector with carrying case.', 'Presentation', 2],
    ['Camera', 'Canon DSLR with 18-55mm lens, 2 batteries and SD card.', 'Media', 3],
    ['HDMI Cable', '3-meter HDMI 2.0 cable.', 'Cables', 10],
    ['Extension Cord', '5-meter, 4-outlet surge-protected extension cord.', 'Cables', 8],
    ['Microphone', 'Wireless handheld microphone with receiver.', 'Audio', 4],
  ];
  final batch = _db.batch();
  for (final i in items) {
    batch.set(_db.collection('equipment').doc(), {
      'name': i[0],
      'description': i[1],
      'category': i[2],
      'total': i[3],
      'available': i[3],
      'imageUrl': '',
    });
  }
  await batch.commit();
}

Stream<List<BorrowRequest>> streamMyRequests() {
  final uid = _auth.currentUser!.uid;
  return _db
      .collection('requests')
      .where('userId', isEqualTo: uid)
      .snapshots()
      .map((s) {
    final list = s.docs.map(BorrowRequest.fromDoc).toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  });
}

Stream<BorrowRequest?> streamRequest(String id) => _db
    .collection('requests')
    .doc(id)
    .snapshots()
    .map((d) => d.exists ? BorrowRequest.fromDoc(d) : null);

Future<String> submitRequest({
  required Equipment equipment,
  required DateTime needed,
  required DateTime returnDate,
  required String purpose,
  Uint8List? image,
}) async {
  final uid = _auth.currentUser!.uid;
  final reqRef = _db.collection('requests').doc();

  String attachmentBase64 = '';
  if (image != null) {
    if (image.length > 500 * 1024) {
      throw Exception('Photo is too large. Please choose a smaller one.');
    }
    attachmentBase64 = base64Encode(image);
  }

  final eqRef = _db.collection('equipment').doc(equipment.id);
  await _db.runTransaction((tx) async {
    final snap = await tx.get(eqRef);
    final avail = (snap.data()?['available'] ?? 0) as int;
    if (avail <= 0) throw Exception('This item is no longer available.');
    tx.update(eqRef, {'available': avail - 1});
    tx.set(reqRef, {
      'userId': uid,
      'equipmentId': equipment.id,
      'equipmentName': equipment.name,
      'equipmentImageUrl': equipment.imageUrl ?? '',
      'needed': Timestamp.fromDate(needed),
      'returnDate': Timestamp.fromDate(returnDate),
      'purpose': purpose,
      'attachmentBase64': attachmentBase64,
      'status': Status.pending.name,
      'createdAt': FieldValue.serverTimestamp(),
    });
  });
  return reqRef.id;
}

Future<void> _setStatus(BorrowRequest r, Status next) {
  final reqRef = _db.collection('requests').doc(r.id);
  final eqRef = _db.collection('equipment').doc(r.equipmentId);
  final restock = next == Status.cancelled || next == Status.returned;

  return _db.runTransaction((tx) async {
    final reqSnap = await tx.get(reqRef);
    if (reqSnap.data()?['status'] != r.status.name) return;

    int? avail;
    if (restock) {
      final eq = await tx.get(eqRef);
      avail = (eq.data()?['available'] ?? 0) as int;
    }
    tx.update(reqRef, {'status': next.name});
    if (restock) tx.update(eqRef, {'available': avail! + 1});
  });
}

const autoStepSeconds = 15;

Future<void> autoAdvanceRequests(List<BorrowRequest> list) async {
  const flow = [Status.pending, Status.approved, Status.borrowed, Status.returned];
  for (final r in list) {
    if (r.status == Status.cancelled || r.status == Status.returned) continue;
    final age = DateTime.now().difference(r.createdAt).inSeconds;
    final target = (age ~/ autoStepSeconds).clamp(0, flow.length - 1);
    final current = flow.indexOf(r.status);
    if (target > current) {
      await _setStatus(r, flow[current + 1]);
    }
  }
}

Future<void> cancelRequest(BorrowRequest r) => _setStatus(r, Status.cancelled);

// NOTIFICATIONS
final _notifs = FlutterLocalNotificationsPlugin();

const _notifDetails = NotificationDetails(
  android: AndroidNotificationDetails(
    'borrowit_channel',
    'Borrowing updates',
    channelDescription: 'Request status changes and return reminders',
    importance: Importance.high,
    priority: Priority.high,
  ),
  iOS: DarwinNotificationDetails(),
);

Future<void> initNotifications() async {
  tzdata.initializeTimeZones();
  await _notifs.initialize(
    settings: const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    ),
  );
  await _notifs
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.requestNotificationsPermission();
}

int _notifId(String requestId, [int salt = 0]) =>
    requestId.hashCode.abs() % 100000 + salt;

Future<void> showNotification(String requestId, String title, String body) async {
  if (kIsWeb) return;
  await _notifs.show(
    id: _notifId(requestId),
    title: title,
    body: body,
    notificationDetails: _notifDetails,
  );
}

Future<void> scheduleReturnReminder(
    String requestId, String equipmentName, DateTime returnDate) async {
  if (kIsWeb) return;
  final now = DateTime.now();
  var when = DateTime(returnDate.year, returnDate.month, returnDate.day, 9)
      .subtract(const Duration(days: 1));
  var text = '"$equipmentName" is due back tomorrow.';
  if (when.isBefore(now)) {
    when = DateTime(returnDate.year, returnDate.month, returnDate.day, 9);
    text = '"$equipmentName" is due back today.';
  }
  if (when.isBefore(now)) return;

  await _notifs.zonedSchedule(
    id: _notifId(requestId, 500000),
    title: 'Return reminder',
    body: text,
    scheduledDate: tz.TZDateTime.from(when, tz.local),
    notificationDetails: _notifDetails,
    androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
  );
}

Future<void> cancelReminder(String requestId) async {
  if (kIsWeb) return;
  await _notifs.cancel(id: _notifId(requestId, 500000));
}

// HELPERS & WIDGETS
IconData equipmentIcon(String name) {
  final n = name.toLowerCase();
  if (n.contains('laptop')) return Icons.laptop_mac;
  if (n.contains('projector')) return Icons.videocam_outlined;
  if (n.contains('camera')) return Icons.photo_camera_outlined;
  if (n.contains('cable') || n.contains('cord')) return Icons.cable;
  if (n.contains('mic')) return Icons.mic_none;
  return Icons.devices_other;
}

String fmt(DateTime d) => '${d.day}/${d.month}/${d.year}';

class BorrowItLogo extends StatelessWidget {
  final double size;
  const BorrowItLogo({super.key, this.size = 120});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Image.asset(
        'assets/borrowit_logo.png',
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: BorrowColors.navy,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Center(
            child: Stack(alignment: Alignment.center, children: [
              Icon(Icons.sync, color: BorrowColors.gold, size: size * 0.7),
              Text(
                'B',
                style: TextStyle(
                  color: BorrowColors.offWhite,
                  fontWeight: FontWeight.w900,
                  fontSize: size * 0.45,
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

class EquipmentImage extends StatelessWidget {
  final String name;
  final String? imageUrl;
  final double size;
  const EquipmentImage({
    super.key,
    required this.name,
    this.imageUrl,
    this.size = 64,
  });

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: BorrowColors.navy.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(equipmentIcon(name), size: size * 0.5, color: BorrowColors.navy),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: imageUrl == null
          ? fallback
          : Image.network(
              imageUrl!,
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => fallback,
              loadingBuilder: (c, child, p) => p == null ? child : fallback,
            ),
    );
  }
}

class StatusChip extends StatelessWidget {
  final Status s;
  const StatusChip(this.s, {super.key});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: s.color.withOpacity(0.18),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          s.label,
          style: TextStyle(
            color: s.color,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      );
}

// ROOT APP
class BorrowItApp extends StatelessWidget {
  const BorrowItApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BorrowIT',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: BorrowColors.background,
        colorScheme: ColorScheme.fromSeed(
          seedColor: BorrowColors.navy,
          primary: BorrowColors.navy,
          secondary: BorrowColors.gold,
          surface: Colors.white,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: BorrowColors.navy,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: BorrowColors.navy,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: Colors.white,
          indicatorColor: BorrowColors.gold.withOpacity(0.2),
          iconTheme: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? const IconThemeData(color: BorrowColors.navy)
                : const IconThemeData(color: Colors.grey),
          ),
        ),
      ),
      home: StreamBuilder<User?>(
        stream: _auth.authStateChanges(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }
          return snap.hasData ? const HomeShell() : const AuthScreen();
        },
      ),
    );
  }
}