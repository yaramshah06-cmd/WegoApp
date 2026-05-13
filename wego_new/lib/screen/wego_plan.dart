import 'package:flutter/material.dart';
import 'payment_screen.dart';

class PlanData {
  final String duration;
  final String title;
  final int price;
  final String badge;
  final Color accentColor;
  final List<String> perks;
  final List<Color> bgColors;
  final String callerImageUrl;
  final String selfImageUrl;
  final String callerName;
  final String callDuration;
  final String currency; // ✅ NAYA

  const PlanData({
    required this.duration,
    required this.title,
    required this.price,
    required this.badge,
    required this.accentColor,
    required this.perks,
    required this.bgColors,
    required this.callerImageUrl,
    required this.selfImageUrl,
    required this.callerName,
    required this.callDuration,
    this.currency = 'Yen', // ✅ NAYA
  });
}

final List<PlanData> plans = [
  PlanData(
    duration: '3 Day',
    title: '3 Day Plan',
    price: 100,
    badge: '',
    currency: 'Yen',
    accentColor: const Color(0xFF3ECFCF),
    perks: ['100 matches limit', '3 days boost unlock', 'Level 3 unlock'],
    bgColors: [const Color(0xFF0A1628), const Color(0xFF0D2244), const Color(0xFF0A0A1A)],
    callerImageUrl: 'https://images.unsplash.com/photo-1544005313-94ddf0286df2?w=600&h=800&fit=crop&crop=face&q=90',
    selfImageUrl: 'https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?w=120&h=160&fit=crop&crop=face&q=80',
    callerName: 'Mei Ling, 22',
    callDuration: '00:03:21',
  ),
  PlanData(
    duration: 'Weekly',
    title: 'Weekly Plan',
    price: 160,
    badge: 'Most Popular',
    currency: 'Yen',
    accentColor: const Color(0xFF3ECFCF),
    perks: ['Unlimited matches', 'Weekly boost unlock', 'Level 5 unlock'],
    bgColors: [const Color(0xFF0A1A10), const Color(0xFF0D3018), const Color(0xFF0A0A1A)],
    callerImageUrl: 'https://images.unsplash.com/photo-1552058544-f2b08422138a?w=600&h=800&fit=crop&crop=face&q=90',
    selfImageUrl: 'https://images.unsplash.com/photo-1531746020798-e6953c6e8e04?w=120&h=160&fit=crop&crop=face&q=80',
    callerName: 'Wei Chen, 25',
    callDuration: '00:07:45',
  ),
  PlanData(
    duration: 'Monthly',
    title: 'Monthly Plan',
    price: 200,
    badge: 'Best Value',
    currency: 'Yen',
    accentColor: const Color(0xFF7F77DD),
    perks: ['Unlimited matches', 'Daily boost unlock', 'Level 10 + unlimited calls'],
    bgColors: [const Color(0xFF1A0A2E), const Color(0xFF2A145A), const Color(0xFF0A0A1A)],
    callerImageUrl: 'https://images.unsplash.com/photo-1521566652839-697aa473761a?w=600&h=800&fit=crop&crop=face&q=90',
    selfImageUrl: 'https://images.unsplash.com/photo-1552058544-f2b08422138a?w=120&h=160&fit=crop&crop=face&q=80',
    callerName: 'Xiao Yu, 21',
    callDuration: '00:12:09',
  ),
  // ✅ PKR Topup Plan
  PlanData(
    duration: 'Topup',
    title: 'PKR Topup Plan',
    price: 10000,
    badge: '+1 Level',
    currency: 'PKR', // ✅
    accentColor: const Color(0xFF4CAF50),
    perks: ['+1 Level direct', 'Instant boost', 'PKR 10,000 topup'],
    bgColors: [const Color(0xFF0A1A10), const Color(0xFF0D3018), const Color(0xFF0A0A1A)],
    callerImageUrl: 'https://images.unsplash.com/photo-1544005313-94ddf0286df2?w=600&h=800&fit=crop&crop=face&q=90',
    selfImageUrl: 'https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?w=120&h=160&fit=crop&crop=face&q=80',
    callerName: 'Support, 24/7',
    callDuration: '00:00:00',
  ),
  // ✅ USD Topup Plan
  PlanData(
    duration: 'Topup',
    title: 'USD Topup Plan',
    price: 100,
    badge: '+1 Level',
    currency: 'USD', // ✅
    accentColor: const Color(0xFF2196F3),
    perks: ['+1 Level direct', 'Instant boost', 'USD 100 topup'],
    bgColors: [const Color(0xFF0A1628), const Color(0xFF0D2244), const Color(0xFF0A0A1A)],
    callerImageUrl: 'https://images.unsplash.com/photo-1552058544-f2b08422138a?w=600&h=800&fit=crop&crop=face&q=90',
    selfImageUrl: 'https://images.unsplash.com/photo-1531746020798-e6953c6e8e04?w=120&h=160&fit=crop&crop=face&q=80',
    callerName: 'Support, 24/7',
    callDuration: '00:00:00',
  ),
];

class PlanScreen extends StatefulWidget {
  const PlanScreen({super.key});

  @override
  State<PlanScreen> createState() => _PlanScreenState();
}

class _PlanScreenState extends State<PlanScreen> {
  final PageController _controller = PageController();
  int _currentPage = 0;

  void _goTo(int i) => _controller.animateToPage(
    i,
    duration: const Duration(milliseconds: 400),
    curve: Curves.easeInOut,
  );

  void _goToPayment() {
    final selectedPlan = plans[_currentPage];
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PaymentScreen(
          planTitle:    selectedPlan.title,
          planDuration: selectedPlan.duration,
          planPrice:    selectedPlan.price,
          planBadge:    selectedPlan.badge,
          accentColor:  selectedPlan.accentColor,
          perks:        selectedPlan.perks,
          currency:     selectedPlan.currency, // ✅ NAYA
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0A1A),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Premium Plans',
          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: plans.length,
                onPageChanged: (i) => setState(() => _currentPage = i),
                itemBuilder: (_, i) => _PlanPage(
                  plan: plans[i],
                  onSelectPlan: _goToPayment,
                ),
              ),
            ),
            _BottomNav(
              current: _currentPage,
              total: plans.length,
              onDot: _goTo,
              onPrev: _currentPage > 0 ? () => _goTo(_currentPage - 1) : null,
              onNext: _currentPage < plans.length - 1 ? () => _goTo(_currentPage + 1) : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _PlanPage extends StatelessWidget {
  final PlanData plan;
  final VoidCallback onSelectPlan;
  const _PlanPage({required this.plan, required this.onSelectPlan});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _VideoCallHeader(plan: plan),
        Expanded(
          child: Container(
            color: const Color(0xFF0A0A1A),
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _PerksList(plan: plan),
                const SizedBox(height: 18),
                _PricePill(plan: plan),
                const SizedBox(height: 10),
                _CTAButton(plan: plan, onTap: onSelectPlan),
                const SizedBox(height: 12),
                const Center(
                  child: Text(
                    'Cancel anytime · Secure payment',
                    style: TextStyle(fontSize: 11, color: Color(0x55FFFFFF)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _VideoCallHeader extends StatelessWidget {
  final PlanData plan;
  const _VideoCallHeader({required this.plan});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 260,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.network(
            plan.callerImageUrl,
            fit: BoxFit.cover,
            filterQuality: FilterQuality.high,
            loadingBuilder: (_, child, progress) {
              if (progress == null) return child;
              return _GradientFallback(
                plan: plan,
                child: Center(child: CircularProgressIndicator(color: plan.accentColor, strokeWidth: 2)),
              );
            },
            errorBuilder: (_, __, ___) => _GradientFallback(
              plan: plan,
              child: Center(child: Icon(Icons.videocam_rounded, color: plan.accentColor.withOpacity(0.5), size: 52)),
            ),
          ),
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x00000000), Color(0xAA000000), Color(0xFF0A0A1A)],
                stops: [0.2, 0.6, 1.0],
              ),
            ),
          ),
          Positioned(
            top: 0, left: 0, right: 0,
            child: Container(
              height: 28,
              color: Colors.black.withOpacity(0.55),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: List.generate(4, (i) => Container(
                      width: 3, height: 6 + i * 2.0,
                      margin: const EdgeInsets.only(right: 2),
                      decoration: BoxDecoration(
                        color: i < 3 ? Colors.white : Colors.white38,
                        borderRadius: BorderRadius.circular(1),
                      ),
                    )),
                  ),
                  Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle)),
                  const Text('3:12', style: TextStyle(color: Colors.white, fontSize: 10)),
                ],
              ),
            ),
          ),
          Positioned(top: 36, left: 10, child: _SelfViewCorner(plan: plan)),
          Positioned(
            top: 36, right: 10,
            child: Container(
              width: 30, height: 30,
              decoration: BoxDecoration(color: Colors.black.withOpacity(0.45), shape: BoxShape.circle),
              child: const Icon(Icons.close, color: Colors.white, size: 18),
            ),
          ),
          if (plan.badge.isNotEmpty)
            Positioned(
              top: 36, right: 48,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: plan.accentColor,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: plan.accentColor.withOpacity(0.45), blurRadius: 8)],
                ),
                child: Text(
                  plan.badge.toUpperCase(),
                  style: TextStyle(
                    fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 1,
                    color: plan.duration == 'Monthly' ? Colors.white : const Color(0xFF0A2020),
                  ),
                ),
              ),
            ),
          Positioned(
            bottom: 48, left: 14,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(plan.callerName, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700, shadows: [Shadow(blurRadius: 8, color: Colors.black87)])),
                const SizedBox(height: 3),
                Row(children: [
                  const Icon(Icons.access_time, color: Colors.white70, size: 12),
                  const SizedBox(width: 4),
                  Text(plan.callDuration, style: const TextStyle(color: Colors.white70, fontSize: 11, fontFamily: 'monospace')),
                ]),
              ],
            ),
          ),
          Positioned(bottom: 30, left: 14, child: Text('WEGOTALK', style: TextStyle(fontSize: 9, letterSpacing: 5, color: Colors.white.withOpacity(0.35)))),
          Positioned(bottom: 14, left: 14, child: Text(plan.title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white, shadows: [Shadow(blurRadius: 10, color: Colors.black87, offset: Offset(0, 2))]))),
        ],
      ),
    );
  }
}

class _SelfViewCorner extends StatelessWidget {
  final PlanData plan;
  const _SelfViewCorner({required this.plan});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 64, height: 82,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withOpacity(0.8), width: 1.5),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(9),
        child: Image.network(
          plan.selfImageUrl,
          fit: BoxFit.cover,
          filterQuality: FilterQuality.high,
          loadingBuilder: (_, child, progress) {
            if (progress == null) return child;
            return Container(color: Colors.black54, child: Center(child: Icon(Icons.person_rounded, color: plan.accentColor.withOpacity(0.6), size: 24)));
          },
          errorBuilder: (_, __, ___) => Container(color: Colors.black54, child: Center(child: Icon(Icons.person_rounded, color: plan.accentColor.withOpacity(0.6), size: 24))),
        ),
      ),
    );
  }
}

class _GradientFallback extends StatelessWidget {
  final PlanData plan;
  final Widget child;
  const _GradientFallback({required this.plan, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: plan.bgColors)),
      child: child,
    );
  }
}

class _PerksList extends StatelessWidget {
  final PlanData plan;
  const _PerksList({required this.plan});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: plan.perks.map((p) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(children: [
          Container(width: 7, height: 7, decoration: BoxDecoration(color: plan.accentColor, shape: BoxShape.circle)),
          const SizedBox(width: 12),
          Text(p, style: const TextStyle(fontSize: 14, color: Color(0xCCFFFFFF))),
        ]),
      )).toList(),
    );
  }
}

class _PricePill extends StatelessWidget {
  final PlanData plan;
  const _PricePill({required this.plan});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: plan.accentColor.withOpacity(0.09),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: plan.accentColor, width: 1),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${plan.duration} Subscription', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white)),
            const SizedBox(height: 3),
            Text(
              plan.duration == '3 Day' ? '3 days full access'
                  : plan.duration == 'Weekly' ? '7 days full access'
                  : plan.duration == 'Topup' ? 'Instant level boost'
                  : '30 days full access',
              style: const TextStyle(fontSize: 12, color: Color(0x77FFFFFF)),
            ),
          ]),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('${plan.price}', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: Colors.white)),
            Text(plan.currency, style: const TextStyle(fontSize: 12, color: Color(0x77FFFFFF))), // ✅ Dynamic currency
          ]),
        ],
      ),
    );
  }
}

class _CTAButton extends StatelessWidget {
  final PlanData plan;
  final VoidCallback onTap;
  const _CTAButton({required this.plan, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: plan.accentColor,
          foregroundColor: plan.duration == 'Monthly' ? Colors.white : const Color(0xFF0A2020),
          padding: const EdgeInsets.symmetric(vertical: 15),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 0,
        ),
        child: Text(
          plan.duration == 'Topup' ? 'Topup Now — ${plan.price} ${plan.currency}' : 'Start ${plan.duration} Plan',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: 0.5),
        ),
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  final int current, total;
  final void Function(int) onDot;
  final VoidCallback? onPrev, onNext;

  const _BottomNav({required this.current, required this.total, required this.onDot, this.onPrev, this.onNext});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF0A0A1A),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(total, (i) {
              final active = i == current;
              return GestureDetector(
                onTap: () => onDot(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: active ? 20 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: active ? const Color(0xFF3ECFCF) : Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _navBtn('Pehla', onPrev),
              Text('Plan ${current + 1} / $total', style: const TextStyle(fontSize: 12, color: Color(0x66FFFFFF))),
              _navBtn('Agla', onNext),
            ],
          ),
        ],
      ),
    );
  }

  Widget _navBtn(String label, VoidCallback? onPressed) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        backgroundColor: Colors.white.withOpacity(0.07),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      child: Text(label, style: const TextStyle(fontSize: 13)),
    );
  }
}