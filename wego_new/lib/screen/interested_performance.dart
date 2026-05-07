import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:wego_marriage/screen/home_feed_screen.dart';
import 'app_localizations.dart';
import 'app_translations.dart';
class InterestsScreen extends StatefulWidget {
  final Map<String, dynamic> userInfo; // Ye line add karein

  const InterestsScreen({super.key, required this.userInfo}); // Constructor update karein

  @override
  State<InterestsScreen> createState() => _InterestsScreenState();
}

class _InterestsScreenState extends State<InterestsScreen> {
  static const Color primaryBlue = Color(0xFF4A6CF7);

  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _isLoading = false;

  final Set<String> _selectedInterests = {};

  final List<Map<String, dynamic>> _interests = [
    {'label': 'Photography', 'icon': Icons.camera_alt_outlined},
    {'label': 'Shopping', 'icon': Icons.shopping_bag_outlined},
    {'label': 'Karaoke', 'icon': Icons.mic_outlined},
    {'label': 'Yoga', 'icon': Icons.self_improvement_outlined},
    {'label': 'Cooking', 'icon': Icons.restaurant_outlined},
    {'label': 'Tennis', 'icon': Icons.sports_tennis_outlined},
    {'label': 'Run', 'icon': Icons.directions_run_outlined},
    {'label': 'Swimming', 'icon': Icons.pool_outlined},
    {'label': 'Art', 'icon': Icons.palette_outlined},
    {'label': 'Traveling', 'icon': Icons.landscape_outlined},
    {'label': 'Extreme', 'icon': Icons.whatshot_outlined},
    {'label': 'Music', 'icon': Icons.music_note_outlined},
    {'label': 'Drink', 'icon': Icons.local_bar_outlined},
    {'label': 'Video games', 'icon': Icons.sports_esports_outlined},
  ];

  void _toggleInterest(String label) {
    setState(() {
      if (_selectedInterests.contains(label)) {
        _selectedInterests.remove(label);
      } else {
        if (_selectedInterests.length < 5) {
          _selectedInterests.add(label);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Maximum 5 interests allowed'),
              backgroundColor: Colors.orange,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    });
  }

  Future<void> _handleContinue() async {
    if (_selectedInterests.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please select at least one interest'),
          backgroundColor: primaryBlue,
          behavior: SnackBarBehavior.floating,
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // ✅ Step 1: Current user ka data lo
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('User not logged in');
      }

      // ✅ Step 2: Firestore mein interests save karo
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
        'interests': _selectedInterests.toList(),
        'interestsUpdatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      setState(() => _isLoading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Interests saved successfully!'),
          backgroundColor: Colors.green,
        ),
      );

      // ✅ Step 3: Navigate to next screen
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => const HomeFeedScreen(),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save interests: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color textColor = isDark ? Colors.white : Colors.black87;
    final Color secondaryTextColor = isDark ? Colors.white70 : Colors.black54;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Bar
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16.0, vertical: 12.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.grey[900] : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: IconButton(
                      onPressed: () => Navigator.maybePop(context),
                      icon: Icon(Icons.arrow_back_ios,
                          color: textColor, size: 18),
                      padding: EdgeInsets.zero,
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const HomeFeedScreen(),
                        ),
                      );
                    },
                    child: const Text(
                      'Skip',
                      style: TextStyle(
                        color: primaryBlue,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Title & Subtitle
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Text(
                'Your interests',
                style: TextStyle(
                  color: textColor,
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.2,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Text(
                'Select a few of your interests and let everyone\nknow what you\'re passionate about.',
                style: TextStyle(
                  color: secondaryTextColor,
                  fontSize: 13.5,
                  height: 1.5,
                ),
              ),
            ),

            const SizedBox(height: 28),

            // Interests Grid
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: GridView.builder(
                  physics: const BouncingScrollPhysics(),
                  gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 2.6,
                  ),
                  itemCount: _interests.length,
                  itemBuilder: (context, index) {
                    final item = _interests[index];
                    final label = item['label'] as String;
                    final icon = item['icon'] as IconData;
                    final isSelected = _selectedInterests.contains(label);

                    return _buildInterestTile(
                      label: label,
                      icon: icon,
                      isSelected: isSelected,
                      onTap: () => _toggleInterest(label),
                      primaryBlue: primaryBlue,
                      textColor: textColor,
                    );
                  },
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Continue Button
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleContinue,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryBlue,
                    disabledBackgroundColor: primaryBlue.withValues(alpha: 0.4),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    elevation: 4,
                    shadowColor: primaryBlue.withValues(alpha: 0.4),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text(
                          'Continue',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.4,
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInterestTile({
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
    required Color primaryBlue,
    required Color textColor,
  }) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: isSelected ? primaryBlue : (isDark ? Colors.grey[900] : Colors.white),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? primaryBlue : (isDark ? Colors.white12 : Colors.grey.shade200),
            width: 1.5,
          ),
          boxShadow: isSelected
              ? [
            BoxShadow(
              color: primaryBlue.withValues(alpha: 0.25),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ]
              : [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding:
          const EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0),
          child: Row(
            children: [
              Icon(
                icon,
                color: isSelected ? Colors.white : primaryBlue,
                size: 22,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isSelected ? Colors.white : textColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
