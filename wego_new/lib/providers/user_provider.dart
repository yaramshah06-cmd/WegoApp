import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  String name;
  String username;
  String bio;
  String email;
  String phone;
  String location;
  String avatarUrl;
  String gender;
  String language;

  UserModel({
    this.name = '',
    this.username = '',
    this.bio = '',
    this.email = '',
    this.phone = '',
    this.location = '',
    this.avatarUrl = '',
    this.gender = '',
    this.language = 'English',
  });

  UserModel copyWith({
    String? name,
    String? username,
    String? bio,
    String? email,
    String? phone,
    String? location,
    String? avatarUrl,
    String? gender,
    String? language,
  }) {
    return UserModel(
      name: name ?? this.name,
      username: username ?? this.username,
      bio: bio ?? this.bio,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      location: location ?? this.location,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      gender: gender ?? this.gender,
      language: language ?? this.language,
    );
  }
}

class UserProvider extends ChangeNotifier {
  UserModel _user = UserModel();
  bool _isLoading = false;

  UserModel get user => _user;
  bool get isLoading => _isLoading;

  // ✅ Firebase se real user data load karo
  Future<void> loadUserFromFirebase() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    _isLoading = true;
    notifyListeners();

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();

      if (doc.exists) {
        final data = doc.data()!;
        _user = UserModel(
          name: data['fullName'] ?? data['username'] ?? '',
          username: data['username'] ?? '',
          bio: data['bio'] ?? '',
          email: data['email'] ?? '',
          phone: data['mobileNumber'] ?? '',
          location: data['location'] ?? '',
          avatarUrl: data['photoUrl'] ?? '',
          gender: data['gender'] ?? '',
          language: data['language'] ?? 'English',
        );
      }
    } catch (e) {
      debugPrint('UserProvider load error: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  // ✅ Firebase mein update bhi karo
  Future<void> updateUserInFirebase(Map<String, dynamic> updates) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .update(updates);
    } catch (e) {
      debugPrint('UserProvider update error: $e');
    }
  }

  void updateUser(UserModel updatedUser) {
    _user = updatedUser;
    notifyListeners();
  }

  void updateName(String name) {
    _user = _user.copyWith(name: name);
    updateUserInFirebase({'fullName': name, 'username': name});
    notifyListeners();
  }

  void updateUsername(String username) {
    _user = _user.copyWith(username: username);
    updateUserInFirebase({'username': username, 'username_lower': username.toLowerCase()});
    notifyListeners();
  }

  void updateBio(String bio) {
    _user = _user.copyWith(bio: bio);
    updateUserInFirebase({'bio': bio});
    notifyListeners();
  }

  void updateEmail(String email) {
    _user = _user.copyWith(email: email);
    updateUserInFirebase({'email': email});
    notifyListeners();
  }

  void updatePhone(String phone) {
    _user = _user.copyWith(phone: phone);
    updateUserInFirebase({'mobileNumber': phone});
    notifyListeners();
  }

  void updateLocation(String location) {
    _user = _user.copyWith(location: location);
    updateUserInFirebase({'location': location});
    notifyListeners();
  }

  void updateAvatar(String avatarUrl) {
    _user = _user.copyWith(avatarUrl: avatarUrl);
    updateUserInFirebase({'photoUrl': avatarUrl});
    notifyListeners();
  }

  void updateGender(String gender) {
    _user = _user.copyWith(gender: gender);
    updateUserInFirebase({'gender': gender});
    notifyListeners();
  }

  void updateLanguage(String language) {
    _user = _user.copyWith(language: language);
    updateUserInFirebase({'language': language});
    notifyListeners();
  }
}