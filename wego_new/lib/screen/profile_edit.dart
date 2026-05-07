import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:wego_marriage/providers/user_provider.dart';
import 'app_localizations.dart';
import 'app_translations.dart';
class ProfileEditScreen extends StatefulWidget {
  const ProfileEditScreen({super.key});

  @override
  State<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  String _selectedGender = 'Male';
  String _selectedLanguage = 'English';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = context.read<UserProvider>().user;
      _nameController.text = user.name;
      _usernameController.text = user.username;
      _bioController.text = user.bio;
      _emailController.text = user.email;
      _phoneController.text = user.phone;
      _locationController.text = user.location;
      _selectedGender = user.gender;
      _selectedLanguage = user.language;
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _bioController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _changeProfilePicture() async {
    // Step 1: Pehle hamara custom permission dialog dikhao
    final bool allowed = await _showPermissionDialog();
    
    if (!allowed) {
      return; // User ne deny kiya
    }

    // Step 2: Ab actual system permission maango
    PermissionStatus status;
    if (Platform.isAndroid) {
      status = await Permission.photos.request();
      if (status.isDenied) {
        status = await Permission.storage.request();
      }
    } else {
      status = await Permission.photos.request();
    }

    // Step 3: Check karo permission mili ya nahi
    if (!status.isGranted && !status.isLimited) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('❌ Permission denied. Please allow access from settings.'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
      if (status.isPermanentlyDenied) {
        if (mounted) _showSettingsDialog();
      }
      return;
    }

    // Step 4: Permission granted - ab gallery open karo
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
      maxWidth: 800,
    );

    if (image != null) {
      if (mounted) {
        context.read<UserProvider>().updateAvatar(image.path);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('✅ Profile picture updated!'),
            backgroundColor: const Color(0xFF3DDC84),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    }
  }

  Future<bool> _showPermissionDialog() async {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => PopScope(
        canPop: false,
        child: AlertDialog(
          backgroundColor: isDark ? Colors.grey[900] : Colors.white,
          title: Text(
            '🔒 Gallery Permission',
            style: TextStyle(color: isDark ? Colors.white : Colors.black87),
          ),
          content: Text(
            'Please allow access to your gallery to change profile picture.\n\n'
            'This is our security filter.',
            style: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context, false); // Deny
              },
              child: const Text(
                'Deny',
                style: TextStyle(color: Colors.red),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context, true); // Allow
              },
              child: const Text(
                'Allow',
                style: TextStyle(
                  color: Color(0xFF3DDC84),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    ) ?? false;
  }

  void _showSettingsDialog() {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? Colors.grey[900] : Colors.white,
        title: Text(
          'Open Settings',
          style: TextStyle(color: isDark ? Colors.white : Colors.black87),
        ),
        content: Text(
          'Please enable photo access in app settings.',
          style: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: isDark ? Colors.white70 : Colors.black54)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
            },
            child: const Text('Open', style: TextStyle(color: Color(0xFF3DDC84))),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color textColor = isDark ? Colors.white : Colors.black87;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textColor),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Edit Profile',
          style: TextStyle(
            color: textColor,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: _saveProfile,
            child: const Text(
              'Save',
              style: TextStyle(
                color: Color(0xFF3DDC84),
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Profile Picture Section
            _buildProfilePictureSection(),
            const SizedBox(height: 24),
            
            // Personal Information
            _buildSectionTitle('Personal Information', textColor),
            const SizedBox(height: 12),
            _buildTextField(
              controller: _nameController,
              label: 'Full Name',
              icon: Icons.person,
              textColor: textColor,
              isDark: isDark,
            ),
            const SizedBox(height: 12),
            _buildTextField(
              controller: _usernameController,
              label: 'Username',
              icon: Icons.alternate_email,
              textColor: textColor,
              isDark: isDark,
            ),
            const SizedBox(height: 12),
            _buildTextField(
              controller: _bioController,
              label: 'Bio',
              icon: Icons.description,
              maxLines: 3,
              textColor: textColor,
              isDark: isDark,
            ),
            
            const SizedBox(height: 24),
            
            // Contact Information
            _buildSectionTitle('Contact Information', textColor),
            const SizedBox(height: 12),
            _buildTextField(
              controller: _emailController,
              label: 'Email',
              icon: Icons.email,
              keyboardType: TextInputType.emailAddress,
              textColor: textColor,
              isDark: isDark,
            ),
            const SizedBox(height: 12),
            _buildTextField(
              controller: _phoneController,
              label: 'Phone',
              icon: Icons.phone,
              keyboardType: TextInputType.phone,
              textColor: textColor,
              isDark: isDark,
            ),
            const SizedBox(height: 12),
            _buildTextField(
              controller: _locationController,
              label: 'Location',
              icon: Icons.location_on,
              textColor: textColor,
              isDark: isDark,
            ),
            
            const SizedBox(height: 24),
            
            // Additional Details
            _buildSectionTitle('Additional Details', textColor),
            const SizedBox(height: 12),
            _buildDropdown(
              label: 'Gender',
              value: _selectedGender,
              items: ['Male', 'Female', 'Other'],
              onChanged: (value) {
                setState(() {
                  _selectedGender = value!;
                });
              },
              isDark: isDark,
              textColor: textColor,
            ),
            const SizedBox(height: 12),
            _buildDropdown(
              label: 'Language',
              value: _selectedLanguage,
              items: ['English', 'Korean', 'Urdu', 'Hindi'],
              onChanged: (value) {
                setState(() {
                  _selectedLanguage = value!;
                });
              },
              isDark: isDark,
              textColor: textColor,
            ),
            
            const SizedBox(height: 30),
            
            // Save Button
            _buildSaveButton(),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildProfilePictureSection() {
    final user = context.watch<UserProvider>().user;
    return Center(
      child: Column(
        children: [
          Stack(
            children: [
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 5),
                    ),
                  ],
                  ),
                  child: ClipOval(
                  child: user.avatarUrl.startsWith('http')
                      ? Image.network(
                          user.avatarUrl,
                          fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                            color: const Color(0xFF7B4EDB),
                            child: const Icon(Icons.person, color: Colors.white, size: 60),
                          ),
                        )
                      : Image.file(
                          File(user.avatarUrl),
                          fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                            color: const Color(0xFF7B4EDB),
                            child: const Icon(Icons.person, color: Colors.white, size: 60),
                          ),
                        ),
                  ),
                  ),              Positioned(
                bottom: 0,
                right: 0,
                child: GestureDetector(
                  onTap: _changeProfilePicture,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF3DDC84),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Change Profile Picture',
            style: TextStyle(
              color: Color(0xFF3DDC84),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, Color textColor) {
    return Text(
      title,
      style: TextStyle(
        color: textColor,
        fontSize: 18,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required Color textColor,
    required bool isDark,
    int maxLines = 1,
    TextInputType? keyboardType,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.grey[200],
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextFormField(
        controller: controller,
        style: TextStyle(color: textColor),
        maxLines: maxLines,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: isDark ? Colors.white70 : Colors.black54),
          labelText: label,
          labelStyle: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'Please enter $label';
          }
          if (label == 'Email') {
            final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
            if (!emailRegex.hasMatch(value)) {
              return 'Please enter a valid email address';
            }
          }
          return null;
        },
      ),
    );
  }

  Widget _buildDropdown({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    required bool isDark,
    required Color textColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.grey[200],
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          dropdownColor: isDark ? const Color(0xFF1A1A1A) : Colors.white,
          items: items.map((String item) {
            return DropdownMenuItem(
              value: item,
              child: Text(
                item,
                style: TextStyle(color: textColor, fontSize: 16),
              ),
            );
          }).toList(),
          onChanged: onChanged,
          icon: Icon(Icons.arrow_drop_down, color: isDark ? Colors.white : Colors.black87),
        ),
      ),
    );
  }

  Widget _buildSaveButton() {
    return ElevatedButton(
      onPressed: _saveProfile,
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF3DDC84),
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      child: const Text(
        'Save Changes',
        style: TextStyle(
          color: Colors.black,
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  void _saveProfile() {
    if (_formKey.currentState!.validate()) {
      final userProvider = context.read<UserProvider>();
      userProvider.updateUser(
        UserModel(
          name: _nameController.text,
          username: _usernameController.text,
          bio: _bioController.text,
          email: _emailController.text,
          phone: _phoneController.text,
          location: _locationController.text,
          gender: _selectedGender,
          language: _selectedLanguage,
          avatarUrl: userProvider.user.avatarUrl,
        ),
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Profile updated successfully!'),
          backgroundColor: const Color(0xFF3DDC84),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
      Navigator.of(context).pop();
    }
  }
}
