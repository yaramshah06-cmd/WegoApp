import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Main method: Show custom popup, then get location (allowed or auto-detect)
  Future<void> requestAndSaveLocation(BuildContext context) async {
    if (!context.mounted) return;

    // Show our custom beautiful permission dialog
    final bool userTappedAllow = await _showLocationPermissionDialog(context);

    if (userTappedAllow) {
      // User pressed "Allow" — request real GPS permission
      await _requestRealLocation();
    } else {
      // User pressed "Deny" — auto-detect via IP/default
      await _autoDetectAndSaveLocation();
    }
  }

  /// Beautiful custom dialog
  Future<bool> _showLocationPermissionDialog(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 30,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Location icon with gradient background
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF4A6CF7), Color(0xFF9B59F5)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(
                  Icons.location_on_rounded,
                  color: Colors.white,
                  size: 42,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Allow Location Access',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1A1A2E),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'WeGo Marriage wants to use your location to show you nearby matches and relevant profiles in your area.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 28),

              // Allow button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(ctx).pop(true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4A6CF7),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Allow Location',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Deny button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  style: TextButton.styleFrom(
                    backgroundColor: const Color(0xFFF5F5F5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    'Not Now',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'You can change this later in settings',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[400],
                ),
              ),
            ],
          ),
        ),
      ),
    );
    return result ?? false;
  }

  /// User allowed — get real GPS location
  Future<void> _requestRealLocation() async {
    try {
      // Check if location service is enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        await _autoDetectAndSaveLocation();
        return;
      }

      // Check/request permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.deniedForever ||
          permission == LocationPermission.denied) {
        // Still denied — use auto detect
        await _autoDetectAndSaveLocation();
        return;
      }

      // Get actual GPS position
      final Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );

      // Reverse geocode to get city/country
      String city = '';
      String country = '';
      String address = '';
      try {
        final placemarks = await placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        );
        if (placemarks.isNotEmpty) {
          final place = placemarks.first;
          city = place.locality ?? place.subAdministrativeArea ?? '';
          country = place.country ?? '';
          address =
          '${place.street ?? ''}, ${place.locality ?? ''}, ${place.country ?? ''}';
        }
      } catch (_) {}

      // Save to Firebase
      await _saveLocationToFirebase(
        latitude: position.latitude,
        longitude: position.longitude,
        city: city,
        country: country,
        address: address,
        method: 'gps',
      );
    } catch (e) {
      // Fallback to auto detect if any error
      await _autoDetectAndSaveLocation();
    }
  }

  /// User denied — auto detect via default/IP-based
  Future<void> _autoDetectAndSaveLocation() async {
    try {
      // Try with low accuracy (network/cell-tower based, no explicit permission needed)
      Position? position;
      try {
        position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.low,
            timeLimit: Duration(seconds: 8),
          ),
        );
      } catch (_) {
        // If even low accuracy fails, use last known
        position = await Geolocator.getLastKnownPosition();
      }

      if (position != null) {
        String city = '';
        String country = '';
        String address = '';
        try {
          final placemarks = await placemarkFromCoordinates(
            position.latitude,
            position.longitude,
          );
          if (placemarks.isNotEmpty) {
            final place = placemarks.first;
            city = place.locality ?? place.subAdministrativeArea ?? '';
            country = place.country ?? '';
            address =
            '${place.street ?? ''}, ${place.locality ?? ''}, ${place.country ?? ''}';
          }
        } catch (_) {}

        await _saveLocationToFirebase(
          latitude: position.latitude,
          longitude: position.longitude,
          city: city,
          country: country,
          address: address,
          method: 'auto_detect',
        );
      } else {
        // Absolute fallback — save empty location
        await _saveLocationToFirebase(
          latitude: 0,
          longitude: 0,
          city: 'Unknown',
          country: 'Unknown',
          address: '',
          method: 'fallback',
        );
      }
    } catch (e) {
      debugPrint('Auto detect location error: $e');
    }
  }

  /// Save location data to Firebase Firestore
  Future<void> _saveLocationToFirebase({
    required double latitude,
    required double longitude,
    required String city,
    required String country,
    required String address,
    required String method,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      await _firestore.collection('users').doc(user.uid).set(
        {
          'location': {
            'latitude': latitude,
            'longitude': longitude,
            'city': city,
            'country': country,
            'address': address,
            'method': method, // 'gps', 'auto_detect', or 'fallback'
            'updatedAt': FieldValue.serverTimestamp(),
          },
        },
        SetOptions(merge: true), // merge so other fields stay intact
      );

      debugPrint(
          '✅ Location saved: $city, $country ($method) [$latitude, $longitude]');
    } catch (e) {
      debugPrint('❌ Failed to save location: $e');
    }
  }
}