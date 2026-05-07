import 'package:flutter/material.dart';
import 'app_localizations.dart';
import 'app_translations.dart';

class ProfileEditScreen extends StatefulWidget {
  const ProfileEditScreen({super.key});

  @override
  State<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> {
  final TextEditingController _nameController =
  TextEditingController(text: 'John Doe');
  final TextEditingController _phoneController =
  TextEditingController(text: '+123 567 89000');
  final TextEditingController _emailController =
  TextEditingController(text: 'johndoe@example.com');
  final TextEditingController _dobController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _dobController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime(1995, 1, 1),
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF4A6CF7),
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _dobController.text =
        '${picked.day.toString().padLeft(2, '0')} / '
            '${picked.month.toString().padLeft(2, '0')} / '
            '${picked.year}';
      });
    }
  }

  void _updateProfile() {
    final email = _emailController.text.trim();

    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr('email_empty')), // ✅
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(email)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr('email_invalid')), // ✅
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // TODO: Add your update logic here
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.tr('profile_updated')), // ✅
        backgroundColor: const Color(0xFF4A6CF7),
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
          icon: Icon(
            Icons.arrow_back_ios,
            color: isDark ? Colors.white : const Color(0xFF4A6CF7),
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          context.tr('profile'), // ✅
          style: TextStyle(
            color: isDark ? Colors.white : const Color(0xFF4A6CF7),
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),

            // Avatar
            Center(
              child: Stack(
                children: [
                  Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: const Color(0xFF4A6CF7), width: 2),
                    ),
                    child: const CircleAvatar(
                      radius: 45,
                      backgroundImage:
                      AssetImage('assets/images/profile.png'),
                      backgroundColor: Color(0xFFE0E0E0),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(5),
                      decoration: const BoxDecoration(
                        color: Color(0xFF4A6CF7),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.edit,
                          color: Colors.white, size: 14),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Full Name
            _buildLabel(context.tr('full_name'), textColor), // ✅
            const SizedBox(height: 8),
            _buildTextField(
              controller: _nameController,
              hint: context.tr('enter_full_name'), // ✅
              keyboardType: TextInputType.name,
              textColor: textColor,
              isDark: isDark,
            ),

            const SizedBox(height: 20),

            // Phone Number
            _buildLabel(context.tr('phone_number'), textColor), // ✅
            const SizedBox(height: 8),
            _buildTextField(
              controller: _phoneController,
              hint: '+1 000 000 0000',
              keyboardType: TextInputType.phone,
              textColor: textColor,
              isDark: isDark,
            ),

            const SizedBox(height: 20),

            // Email
            _buildLabel(context.tr('email'), textColor), // ✅
            const SizedBox(height: 8),
            _buildTextField(
              controller: _emailController,
              hint: context.tr('enter_email'), // ✅
              keyboardType: TextInputType.emailAddress,
              textColor: textColor,
              isDark: isDark,
            ),

            const SizedBox(height: 20),

            // Date of Birth
            _buildLabel(context.tr('date_of_birth'), textColor), // ✅
            const SizedBox(height: 8),
            GestureDetector(
              onTap: _selectDate,
              child: AbsorbPointer(
                child: _buildTextField(
                  controller: _dobController,
                  hint: context.tr('enter_date'), // ✅
                  keyboardType: TextInputType.datetime,
                  hintColor: const Color(0xFF4A6CF7),
                  textColor: textColor,
                  isDark: isDark,
                  suffixIcon: const Icon(
                    Icons.calendar_today_outlined,
                    color: Color(0xFF4A6CF7),
                    size: 18,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 40),

            // Update Profile Button
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: _updateProfile,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4A6CF7),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(32),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  context.tr('update_profile'), // ✅
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String text, Color textColor) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.bold,
        color: textColor,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required Color textColor,
    required bool isDark,
    TextInputType keyboardType = TextInputType.text,
    Color hintColor = Colors.grey,
    Widget? suffixIcon,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: TextStyle(fontSize: 14, color: textColor),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
            color: isDark ? Colors.white60 : hintColor, fontSize: 14),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: isDark
            ? Colors.white.withValues(alpha: 0.1)
            : const Color(0xFFF0F2FF),
        contentPadding:
        const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:
          const BorderSide(color: Color(0xFF4A6CF7), width: 1.5),
        ),
      ),
    );
  }
}