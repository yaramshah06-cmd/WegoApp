import 'package:flutter/material.dart';
import 'app_localizations.dart';
import 'app_translations.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDarkMode ? Colors.white : const Color(0xFF374151);
    final subTextColor = isDarkMode ? Colors.white70 : const Color(0xFF6B7280);
    final primaryColor = const Color(0xFF2563EB);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.chevron_left, color: primaryColor, size: 30),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          context.tr('privacy_policy_title'), // ✅
          style: TextStyle(
            color: primaryColor,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Last Update Date
            Text(
              '${context.tr('last_update')}: 14/08/2024', // ✅
              style: TextStyle(
                color: subTextColor,
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 16),

            Text(
              'Lorem ipsum dolor sit amet, consectetur adipiscing elit. Praesent pellentesque congue lorem, vel tincidunt tortor placerat a. Proin ac diam quam. Aenean in sagittis magna, ut feugiat diam. Fusce a scelerisque neque, sed accumsan metus.',
              style: TextStyle(color: textColor, fontSize: 14, height: 1.6),
            ),
            const SizedBox(height: 16),

            Text(
              'Nunc auctor tortor in dolor luctus, quis euismod urna tincidunt. Aenean arcu metus, bibendum at rhoncus at, volutpat ut lacus. Morbi pellentesque malesuada eros semper ultrices. Vestibulum lobortis enim vel neque auctor, a ultrices ex placerat. Mauris ut lacinia justo, sed suscipit tortor. Nam egestas nulla posuere neque tincidunt porta.',
              style: TextStyle(color: textColor, fontSize: 14, height: 1.6),
            ),
            const SizedBox(height: 32),

            // Terms & Conditions heading
            Text(
              context.tr('terms_conditions'), // ✅
              style: TextStyle(
                color: primaryColor,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),

            _buildNumberedItem(
              number: 1,
              text: 'Ut lacinia justo sit amet lorem sodales accumsan. Proin malesuada eleifend fermentum. Donec condimentum, nunc at rhoncus faucibus, ex nisi laoreet ipsum, eu pharetra eros est vitae orci. Morbi quis rhoncus mi. Nullam lacinia ornare accumsan. Duis laoreet, ex eget rutrum pharetra, lectus nisl posuere risus, vel facilisis nisi tellus ac turpis.',
              textColor: textColor,
            ),
            const SizedBox(height: 16),

            _buildNumberedItem(
              number: 2,
              text: 'Ut lacinia justo sit amet lorem sodales accumsan. Proin malesuada eleifend fermentum. Donec condimentum, nunc at rhoncus faucibus, ex nisi laoreet ipsum, eu pharetra eros est vitae orci. Morbi quis rhoncus mi. Nullam lacinia ornare accumsan. Duis laoreet, ex eget rutrum pharetra, lectus nisl posuere risus, vel facilisis nisi tellus.',
              textColor: textColor,
            ),
            const SizedBox(height: 16),

            _buildNumberedItem(
              number: 3,
              text: 'Lorem ipsum dolor sit amet, consectetur adipiscing elit. Praesent pellentesque congue lorem, vel tincidunt tortor placerat a. Proin ac diam quam. Aenean in sagittis magna, ut feugiat diam.',
              textColor: textColor,
            ),
            const SizedBox(height: 16),

            _buildNumberedItem(
              number: 4,
              text: 'Nunc auctor tortor in dolor luctus, quis euismod urna tincidunt. Aenean arcu metus, bibendum at rhoncus at, volutpat ut lacus. Morbi pellentesque malesuada eros semper ultrices. Vestibulum lobortis enim vel neque auctor, a ultrices ex placerat. Mauris ut lacinia justo, sed suscipit tortor. Nam egestas nulla posuere neque.',
              textColor: textColor,
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildNumberedItem({
    required int number,
    required String text,
    required Color textColor,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$number.',
          style: TextStyle(
            color: textColor,
            fontSize: 14,
            fontWeight: FontWeight.w500,
            height: 1.6,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(color: textColor, fontSize: 14, height: 1.6),
          ),
        ),
      ],
    );
  }
}