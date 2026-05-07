import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';
import 'app_localizations.dart'; // ✅ ADD
import 'app_localizations.dart';
import 'app_translations.dart';
class LanguageScreen extends StatefulWidget {
  const LanguageScreen({super.key});

  @override
  State<LanguageScreen> createState() => _LanguageScreenState();
}

class _LanguageScreenState extends State<LanguageScreen> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final provider = context.watch<SettingsProvider>();
    final languages = provider.languageList;

    // Search filter
    final filtered = _searchQuery.isEmpty
        ? languages
        : languages.where((l) {
      final q = _searchQuery.toLowerCase();
      return l['name']!.toLowerCase().contains(q) ||
          l['native']!.toLowerCase().contains(q);
    }).toList();

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Icon(
            Icons.arrow_back_ios,
            color: isDark ? Colors.white : const Color(0xFF4A6CF7),
            size: 20,
          ),
        ),
        title: Text(
          context.tr('select_language'), // ✅ TRANSLATED
          style: TextStyle(
            color: isDark ? Colors.white : const Color(0xFF4A6CF7),
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // ── Search Bar ──────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              onChanged: (v) => setState(() => _searchQuery = v),
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black87,
              ),
              decoration: InputDecoration(
                hintText: context.tr('search_language'), // ✅ TRANSLATED
                hintStyle: TextStyle(
                  color: isDark ? Colors.white38 : Colors.black38,
                ),
                prefixIcon:
                const Icon(Icons.search, color: Color(0xFF4A6CF7)),
                filled: true,
                fillColor: isDark
                    ? Colors.white.withValues(alpha: 0.07)
                    : const Color(0xFF4A6CF7).withValues(alpha: 0.07),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
            ),
          ),

          // ── Language List ───────────────────────────────────
          Expanded(
            child: filtered.isEmpty
                ? Center(
              child: Text(
                context.tr('no_language_found'), // ✅ TRANSLATED
                style: TextStyle(
                  color: isDark ? Colors.white54 : Colors.black45,
                ),
              ),
            )
                : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              itemCount: filtered.length,
              itemBuilder: (context, index) {
                final lang = filtered[index];
                final isSelected =
                    provider.preferredLanguage == lang['name'];

                return GestureDetector(
                  onTap: () async {
                    await provider
                        .setPreferredLanguage(lang['name']!);
                    if (context.mounted) Navigator.pop(context);
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFF4A6CF7)
                          .withValues(alpha: 0.12)
                          : (isDark
                          ? Colors.white.withValues(alpha: 0.05)
                          : Colors.grey.withValues(alpha: 0.07)),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xFF4A6CF7)
                            : Colors.transparent,
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      children: [
                        // Flag
                        Text(
                          lang['flag']!,
                          style: const TextStyle(fontSize: 26),
                        ),
                        const SizedBox(width: 14),

                        // Names — ye translate nahi honge
                        // kyunki ye language ke apne naam hain
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                            CrossAxisAlignment.start,
                            children: [
                              Text(
                                lang['name']!, // English name
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: isDark
                                      ? Colors.white
                                      : Colors.black87,
                                ),
                              ),
                              Text(
                                lang['native']!, // Original script
                                style: TextStyle(
                                  fontSize: 13,
                                  color: isDark
                                      ? Colors.white54
                                      : Colors.black45,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Checkmark
                        if (isSelected)
                          const Icon(
                            Icons.check_circle_rounded,
                            color: Color(0xFF4A6CF7),
                            size: 22,
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}