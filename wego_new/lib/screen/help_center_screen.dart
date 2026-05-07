import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'app_localizations.dart';
import 'app_translations.dart';

class HelpCenterScreen extends StatefulWidget {
  const HelpCenterScreen({super.key});

  @override
  State<HelpCenterScreen> createState() => _HelpCenterScreenState();
}

class _HelpCenterScreenState extends State<HelpCenterScreen> {
  int _selectedTab = 0;
  String _selectedFilter = 'All';
  int? _expandedIndex;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  List<String> get _filters => [
    context.tr('filter_all'),
    context.tr('filter_account'),
    context.tr('filter_security'),
    context.tr('filter_otp'),
    context.tr('filter_report'),
    context.tr('filter_general'),
  ];

  List<Map<String, String>> get _faqItems => [
    // ── Account ──
    {
      'category': context.tr('filter_account'),
      'question': context.tr('faq_account_hacked_q'),
      'answer': context.tr('faq_account_hacked_a'),
    },
    {
      'category': context.tr('filter_account'),
      'question': context.tr('faq_delete_account_q'),
      'answer': context.tr('faq_delete_account_a'),
    },
    {
      'category': context.tr('filter_account'),
      'question': context.tr('faq_change_username_q'),
      'answer': context.tr('faq_change_username_a'),
    },
    {
      'category': context.tr('filter_account'),
      'question': context.tr('faq_account_banned_q'),
      'answer': context.tr('faq_account_banned_a'),
    },

    // ── Security ──
    {
      'category': context.tr('filter_security'),
      'question': context.tr('faq_unauthorized_activity_q'),
      'answer': context.tr('faq_unauthorized_activity_a'),
    },
    {
      'category': context.tr('filter_security'),
      'question': context.tr('faq_privacy_settings_q'),
      'answer': context.tr('faq_privacy_settings_a'),
    },
    {
      'category': context.tr('filter_security'),
      'question': context.tr('faq_suspicious_msg_q'),
      'answer': context.tr('faq_suspicious_msg_a'),
    },

    // ── OTP ──
    {
      'category': context.tr('filter_otp'),
      'question': context.tr('faq_otp_not_received_q'),
      'answer': context.tr('faq_otp_not_received_a'),
    },
    {
      'category': context.tr('filter_otp'),
      'question': context.tr('faq_otp_expired_q'),
      'answer': context.tr('faq_otp_expired_a'),
    },
    {
      'category': context.tr('filter_otp'),
      'question': context.tr('faq_wrong_otp_number_q'),
      'answer': context.tr('faq_wrong_otp_number_a'),
    },

    // ── Report ──
    {
      'category': context.tr('filter_report'),
      'question': context.tr('faq_report_user_q'),
      'answer': context.tr('faq_report_user_a'),
    },
    {
      'category': context.tr('filter_report'),
      'question': context.tr('faq_harassment_q'),
      'answer': context.tr('faq_harassment_a'),
    },
    {
      'category': context.tr('filter_report'),
      'question': context.tr('faq_fake_account_q'),
      'answer': context.tr('faq_fake_account_a'),
    },

    // ── General ──
    {
      'category': context.tr('filter_general'),
      'question': context.tr('faq_post_upload_q'),
      'answer': context.tr('faq_post_upload_a'),
    },
    {
      'category': context.tr('filter_general'),
      'question': context.tr('faq_app_crash_q'),
      'answer': context.tr('faq_app_crash_a'),
    },
    {
      'category': context.tr('filter_general'),
      'question': context.tr('faq_notification_q'),
      'answer': context.tr('faq_notification_a'),
    },
  ];

  List<Map<String, String>> get _filteredFaqs {
    return _faqItems.where((item) {
      final matchesFilter = _selectedFilter == context.tr('filter_all') ||
          item['category'] == _selectedFilter;
      final matchesSearch = _searchQuery.isEmpty ||
          item['question']!
              .toLowerCase()
              .contains(_searchQuery.toLowerCase()) ||
          item['answer']!
              .toLowerCase()
              .contains(_searchQuery.toLowerCase());
      return matchesFilter && matchesSearch;
    }).toList();
  }

  Future<void> _launchEmail() async {
    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: 'wegomarriage100@gmail.com',
      query: 'subject=Help Request - WeGo Talk',
    );
    if (await canLaunchUrl(emailUri)) {
      await launchUrl(emailUri);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr('email_app_not_found')), // ✅
            backgroundColor: const Color(0xFF4A6CF7),
          ),
        );
      }
    }
  }

  Future<void> _launchWhatsApp() async {
    final Uri waUri = Uri.parse('https://wa.me/923001234567');
    if (await canLaunchUrl(waUri)) {
      await launchUrl(waUri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _copyEmail() async {
    await Clipboard.setData(
        const ClipboardData(text: 'wegomarriage100@gmail.com'));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr('email_copied')), // ✅
          backgroundColor: const Color(0xFF4A6CF7),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color textColor = isDark ? Colors.white : Colors.black87;
    final Color secondaryTextColor = isDark ? Colors.white60 : Colors.black54;
    final Color primaryBlue = const Color(0xFF4A6CF7);
    final Color cardColor = isDark ? const Color(0xFF1E1E2E) : Colors.white;
    final Color bgColor =
    isDark ? const Color(0xFF121212) : const Color(0xFFF5F6FA);

    // Reset filter to 'All' key when language changes
    if (!_filters.contains(_selectedFilter)) {
      _selectedFilter = context.tr('filter_all');
    }

    return Scaffold(
      backgroundColor: bgColor,
      body: Column(
        children: [
          // ── Blue Header ──
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [primaryBlue, const Color(0xFF7B5CF7)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(32),
                bottomRight: Radius.circular(32),
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                child: Column(
                  children: [
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.chevron_left,
                              color: Colors.white, size: 30),
                          onPressed: () => Navigator.pop(context),
                        ),
                        Expanded(
                          child: Text(
                            context.tr('help_center'), // ✅
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 48),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      context.tr('help_center_subtitle'), // ✅
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 13),
                    ),
                    const SizedBox(height: 20),
                    // Search bar
                    Container(
                      height: 50,
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF1E1E2E)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.15),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: TextField(
                        controller: _searchController,
                        onChanged: (val) =>
                            setState(() => _searchQuery = val),
                        style: TextStyle(
                            color: isDark ? Colors.white : Colors.black87),
                        decoration: InputDecoration(
                          hintText: context.tr('help_search_hint'), // ✅
                          hintStyle: TextStyle(
                            color: isDark
                                ? Colors.white38
                                : const Color(0xFFAAAAAA),
                            fontSize: 14,
                          ),
                          prefixIcon:
                          Icon(Icons.search, color: primaryBlue),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                            icon: Icon(Icons.clear,
                                color: Colors.grey[400], size: 20),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                              : null,
                          border: InputBorder.none,
                          contentPadding:
                          const EdgeInsets.symmetric(vertical: 15),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── Body ──
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Tab bar ✅ TRANSLATED
                  Container(
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        _buildTab(context.tr('tab_faq'), 0, primaryBlue, isDark),          // ✅
                        _buildTab(context.tr('tab_contact_us'), 1, primaryBlue, isDark),   // ✅
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  if (_selectedTab == 0) ...[
                    // Filter chips ✅
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: _filters
                            .map((f) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: _buildFilterChip(
                              f, primaryBlue, cardColor, isDark),
                        ))
                            .toList(),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Results count ✅
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        '${_filteredFaqs.length} ${context.tr('results')}',
                        style: TextStyle(
                            color: secondaryTextColor, fontSize: 12),
                      ),
                    ),

                    // FAQ list
                    if (_filteredFaqs.isEmpty)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32.0),
                          child: Column(
                            children: [
                              Icon(Icons.search_off,
                                  size: 48, color: Colors.grey[400]),
                              const SizedBox(height: 12),
                              Text(
                                context.tr('no_results_found'), // ✅
                                style: TextStyle(
                                    color: secondaryTextColor,
                                    fontSize: 15),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                context.tr('contact_via_email'), // ✅
                                style: TextStyle(
                                    color: primaryBlue, fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      ..._filteredFaqs.asMap().entries.map((entry) {
                        final index = entry.key;
                        final item = entry.value;
                        final isExpanded = _expandedIndex == index;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _buildFaqItem(
                            category: item['category']!,
                            question: item['question']!,
                            answer: item['answer']!,
                            isExpanded: isExpanded,
                            onTap: () => setState(() =>
                            _expandedIndex = isExpanded ? null : index),
                            cardColor: cardColor,
                            primaryBlue: primaryBlue,
                            textColor: textColor,
                            secondaryTextColor: secondaryTextColor,
                          ),
                        );
                      }),
                  ] else ...[
                    _buildContactUs(cardColor, primaryBlue, textColor,
                        secondaryTextColor, isDark),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTab(
      String label, int index, Color primaryBlue, bool isDark) {
    final isSelected = _selectedTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() {
          _selectedTab = index;
          _expandedIndex = null;
        }),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.all(4),
          padding: const EdgeInsets.symmetric(vertical: 13),
          decoration: BoxDecoration(
            color: isSelected ? primaryBlue : Colors.transparent,
            borderRadius: BorderRadius.circular(26),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected
                  ? Colors.white
                  : (isDark ? Colors.white38 : Colors.black38),
              fontWeight:
              isSelected ? FontWeight.bold : FontWeight.w500,
              fontSize: 15,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip(
      String label, Color primaryBlue, Color cardColor, bool isDark) {
    final isSelected = _selectedFilter == label;
    return GestureDetector(
      onTap: () => setState(() {
        _selectedFilter = label;
        _expandedIndex = null;
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? primaryBlue : cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? primaryBlue
                : (isDark ? Colors.white10 : const Color(0xFFDDDDEE)),
          ),
          boxShadow: isSelected
              ? [
            BoxShadow(
              color: primaryBlue.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            )
          ]
              : [],
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected
                ? Colors.white
                : (isDark ? Colors.white60 : Colors.black54),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildFaqItem({
    required String category,
    required String question,
    required String answer,
    required bool isExpanded,
    required VoidCallback onTap,
    required Color cardColor,
    required Color primaryBlue,
    required Color textColor,
    required Color secondaryTextColor,
  }) {
    final Color categoryColor = _getCategoryColor(category);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
          border: isExpanded
              ? Border.all(
              color: primaryBlue.withValues(alpha: 0.4), width: 1.5)
              : Border.all(color: Colors.transparent),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: categoryColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      category,
                      style: TextStyle(
                        color: categoryColor,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      question,
                      style: TextStyle(
                        color: textColor,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Icon(
                    isExpanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: primaryBlue,
                    size: 24,
                  ),
                ],
              ),
            ),
            AnimatedCrossFade(
              firstChild: const SizedBox.shrink(),
              secondChild: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Divider(
                        height: 1,
                        color: Colors.grey.withValues(alpha: 0.2)),
                    const SizedBox(height: 12),
                    Text(
                      answer,
                      style: TextStyle(
                        color: secondaryTextColor,
                        fontSize: 13,
                        height: 1.7,
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Still need help? ✅ TRANSLATED
                    GestureDetector(
                      onTap: _launchEmail,
                      child: Row(
                        children: [
                          Icon(Icons.mail_outline,
                              size: 14, color: Colors.blue[400]),
                          const SizedBox(width: 6),
                          Text(
                            context.tr('still_need_help'), // ✅
                            style: TextStyle(
                              color: Colors.blue[400],
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              crossFadeState: isExpanded
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 250),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactUs(Color cardColor, Color primaryBlue, Color textColor,
      Color secondaryTextColor, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header card ✅ TRANSLATED
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [primaryBlue, const Color(0xFF7B5CF7)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.support_agent, color: Colors.white, size: 36),
              const SizedBox(height: 12),
              Text(
                context.tr('available_247'), // ✅
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(
                context.tr('support_tagline'), // ✅
                style: const TextStyle(
                    color: Colors.white70, fontSize: 13, height: 1.5),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // ✅ TRANSLATED
        Text(context.tr('contact_methods'),
            style: TextStyle(
                color: textColor,
                fontSize: 16,
                fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),

        // Email card ✅ TRANSLATED
        _buildContactCard(
          cardColor: cardColor,
          icon: Icons.email_outlined,
          iconColor: const Color(0xFF4A6CF7),
          title: context.tr('email_support'),       // ✅
          subtitle: 'wegomarriage100@gmail.com',
          badge: '24/7',
          badgeColor: Colors.green,
          onTap: _launchEmail,
          onLongPress: _copyEmail,
          trailing: context.tr('send_email'),       // ✅
          isDark: isDark,
        ),
        const SizedBox(height: 10),

        // Response time ✅ TRANSLATED
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? Colors.white10 : const Color(0xFFEEEEF5),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.info_outline,
                      color: Colors.amber[600], size: 18),
                  const SizedBox(width: 8),
                  Text(context.tr('response_time'),  // ✅
                      style: TextStyle(
                          color: textColor,
                          fontSize: 14,
                          fontWeight: FontWeight.w600)),
                ],
              ),
              const SizedBox(height: 12),
              _buildInfoRow(context.tr('response_urgent'),  '2-4 ${context.tr('hours')}',  textColor, secondaryTextColor), // ✅
              _buildInfoRow(context.tr('response_general'),  '12-24 ${context.tr('hours')}', textColor, secondaryTextColor), // ✅
              _buildInfoRow(context.tr('response_feedback'), '24-48 ${context.tr('hours')}', textColor, secondaryTextColor), // ✅
            ],
          ),
        ),
        const SizedBox(height: 10),

        // Email format guide ✅ TRANSLATED
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? Colors.white10 : const Color(0xFFEEEEF5),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.edit_note, color: primaryBlue, size: 20),
                  const SizedBox(width: 8),
                  Text(context.tr('how_to_write_email'),  // ✅
                      style: TextStyle(
                          color: textColor,
                          fontSize: 14,
                          fontWeight: FontWeight.w600)),
                ],
              ),
              const SizedBox(height: 12),
              _buildGuideItem(context.tr('guide_subject'),     context.tr('guide_subject_val'),     secondaryTextColor), // ✅
              _buildGuideItem(context.tr('guide_uid'),         context.tr('guide_uid_val'),         secondaryTextColor), // ✅
              _buildGuideItem(context.tr('guide_email'),       context.tr('guide_email_val'),       secondaryTextColor), // ✅
              _buildGuideItem(context.tr('guide_description'), context.tr('guide_description_val'), secondaryTextColor), // ✅
              _buildGuideItem(context.tr('guide_screenshot'),  context.tr('guide_screenshot_val'),  secondaryTextColor), // ✅
            ],
          ),
        ),
        const SizedBox(height: 10),

        // Copy email button ✅ TRANSLATED
        GestureDetector(
          onTap: _copyEmail,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : const Color(0xFFF0F0FF),
              borderRadius: BorderRadius.circular(16),
              border:
              Border.all(color: primaryBlue.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.copy, color: primaryBlue, size: 18),
                const SizedBox(width: 8),
                Text(
                  context.tr('copy_email_address'), // ✅
                  style: TextStyle(
                      color: primaryBlue,
                      fontWeight: FontWeight.w600,
                      fontSize: 13),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildContactCard({
    required Color cardColor,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required String badge,
    required Color badgeColor,
    required VoidCallback onTap,
    required VoidCallback onLongPress,
    required String trailing,
    required bool isDark,
  }) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(title,
                          style: TextStyle(
                              color:
                              isDark ? Colors.white : Colors.black87,
                              fontWeight: FontWeight.w600,
                              fontSize: 14)),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: badgeColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(badge,
                            style: TextStyle(
                                color: badgeColor,
                                fontSize: 10,
                                fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(subtitle,
                      style: TextStyle(
                          color:
                          isDark ? Colors.white54 : Colors.black54,
                          fontSize: 12)),
                ],
              ),
            ),
            Text(trailing,
                style: TextStyle(
                    color: iconColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(
      String label, String value, Color textColor, Color subColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: subColor, fontSize: 12)),
          Text(value,
              style: TextStyle(
                  color: textColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildGuideItem(
      String label, String value, Color subColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(label,
                style: const TextStyle(
                    color: Color(0xFF4A6CF7),
                    fontSize: 12,
                    fontWeight: FontWeight.bold)),
          ),
          Expanded(
            child: Text(value,
                style: TextStyle(color: subColor, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Color _getCategoryColor(String category) {
    if (category == context.tr('filter_account'))  return const Color(0xFF4A6CF7);
    if (category == context.tr('filter_security')) return Colors.red;
    if (category == context.tr('filter_otp'))      return Colors.orange;
    if (category == context.tr('filter_report'))   return Colors.purple;
    if (category == context.tr('filter_general'))  return Colors.teal;
    return const Color(0xFF4A6CF7);
  }
}