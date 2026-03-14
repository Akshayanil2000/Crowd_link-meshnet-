import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:uuid/uuid.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseDatabase _db = FirebaseDatabase.instanceFor(
    app: Firebase.app(),
    databaseURL: 'https://mesh-net-6f9a0-default-rtdb.asia-southeast1.firebasedatabase.app/',
  );

  AuthService._internal() {
    _db.setPersistenceEnabled(true);
    _db.ref('users').keepSynced(true);
  }

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Generate a unique short Mesh ID like  MN-A3F9K2
  String _generateMeshId() {
    final chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rand = List.generate(6, (_) {
      return chars[DateTime.now().microsecondsSinceEpoch % chars.length];
    });
    // Add randomness via uuid
    final uuidPart = const Uuid().v4().replaceAll('-', '').toUpperCase().substring(0, 6);
    return 'MN-$uuidPart';
  }

  /// Register with email, password and display name
  Future<String?> register({
    required String email,
    required String password,
    required String name,
  }) async {
    try {
      final cred = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      await cred.user!.updateDisplayName(name);

      final meshId = _generateMeshId();
      final uid = cred.user!.uid;

      // Save user profile in RTDB
      await _db.ref('users/$uid').set({
        'meshId': meshId,
        'name': name,
        'email': email,
        'createdAt': ServerValue.timestamp,
      });

      // Reverse lookup: meshId → uid
      await _db.ref('meshIds/$meshId').set(uid);

      return null; // no error
    } on FirebaseAuthException catch (e) {
      return e.message;
    } catch (e) {
      return e.toString();
    }
  }

  /// Sign in with email and password
  Future<String?> signIn({required String email, required String password}) async {
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
      return null;
    } on FirebaseAuthException catch (e) {
      return e.message;
    }
  }

  /// Sign out
  Future<void> signOut() async => _auth.signOut();

  /// Get current user's profile from RTDB
  Future<Map<String, dynamic>?> getUserProfile() async {
    final uid = currentUser?.uid;
    if (uid == null) return null;
    final snap = await _db.ref('users/$uid').get();
    if (snap.exists) return Map<String, dynamic>.from(snap.value as Map);
    return null;
  }

  /// Look up a user by Mesh ID
  Future<Map<String, dynamic>?> getUserByMeshId(String meshId) async {
    final uidSnap = await _db.ref('meshIds/$meshId').get();
    if (!uidSnap.exists) return null;
    final uid = uidSnap.value as String;
    final snap = await _db.ref('users/$uid').get();
    if (snap.exists) {
      final data = Map<String, dynamic>.from(snap.value as Map);
      data['uid'] = uid;
      return data;
    }
    return null;
  }

  /// Add a friend by their Mesh ID
  Future<String?> addFriendByMeshId(String meshId) async {
    final myUid = currentUser?.uid;
    if (myUid == null) return 'Not logged in';
    if (meshId.trim().isEmpty) return 'Please enter a Mesh ID';

    final target = await getUserByMeshId(meshId.trim().toUpperCase());
    if (target == null) return 'No user found with that Mesh ID';
    if (target['uid'] == myUid) return 'You cannot add yourself';

    final friendUid = target['uid'] as String;
    final myProfile = await getUserProfile();

    // Write friend entry for both users
    await Future.wait<void>([
      _db.ref('friends/$myUid/$friendUid').set({
        'meshId': target['meshId'],
        'name': target['name'],
        'addedAt': ServerValue.timestamp,
      }),
      _db.ref('friends/$friendUid/$myUid').set({
        'meshId': myProfile?['meshId'] ?? '',
        'name': myProfile?['name'] ?? '',
        'addedAt': ServerValue.timestamp,
      }),
    ]);

    return null; // success
  }

  /// Stream friends list
  Stream<List<Map<String, dynamic>>> friendsStream() {
    final uid = currentUser?.uid;
    if (uid == null) return const Stream.empty();
    return _db.ref('friends/$uid').onValue.map((event) {
      if (!event.snapshot.exists) return [];
      final data = Map<String, dynamic>.from(event.snapshot.value as Map);
      return data.entries.map((e) {
        final friend = Map<String, dynamic>.from(e.value as Map);
        friend['uid'] = e.key;
        return friend;
      }).toList();
    });
  }

  /// Stream messages with a specific friend
  Stream<List<Map<String, dynamic>>> messagesStream(String friendUid) {
    final myUid = currentUser?.uid;
    if (myUid == null) return const Stream.empty();
    final chatId = _chatId(myUid, friendUid);
    return _db.ref('messages/$chatId').orderByChild('timestamp').onValue.map((event) {
      if (!event.snapshot.exists) return [];
      final data = Map<String, dynamic>.from(event.snapshot.value as Map);
      return data.entries.map((e) {
        final msg = Map<String, dynamic>.from(e.value as Map);
        msg['id'] = e.key;
        return msg;
      }).toList()
        ..sort((a, b) => (a['timestamp'] ?? 0).compareTo(b['timestamp'] ?? 0));
    });
  }

  /// Send a message
  Future<void> sendMessage(String friendUid, String text, {String type = 'text', Map<String, dynamic>? metadata}) async {
    final myUid = currentUser?.uid;
    if (myUid == null || (text.trim().isEmpty && metadata == null)) return;
    final chatId = _chatId(myUid, friendUid);
    
    Map<String, dynamic> msgData = {
      'text': text.trim(),
      'senderId': myUid,
      'type': type,
      'timestamp': ServerValue.timestamp,
    };
    
    if (metadata != null) {
      msgData.addAll(metadata);
    }
    
    await _db.ref('messages/$chatId').push().set(msgData);
  }

  /// Send a message on behalf of another user (Gateway forwarding)
  Future<void> sendMessageOnBehalf(String senderUid, String friendUid, String text, {String type = 'text', Map<String, dynamic>? metadata}) async {
    if (text.trim().isEmpty && metadata == null) return;
    final chatId = _chatId(senderUid, friendUid);
    
    Map<String, dynamic> msgData = {
      'text': text.trim(),
      'senderId': senderUid,
      'type': type,
      'timestamp': ServerValue.timestamp,
    };
    
    if (metadata != null) {
      msgData.addAll(metadata);
    }
    
    await _db.ref('messages/$chatId').push().set(msgData);
  }

  /// Consistent chat room ID (alphabetically sorted UIDs)
  String _chatId(String uid1, String uid2) {
    final ids = [uid1, uid2]..sort();
    return '${ids[0]}_${ids[1]}';
  }
}
