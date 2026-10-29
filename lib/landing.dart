import 'dart:async';
import 'dart:math' as math;

import 'package:fitfuseapp/login.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

const Color _midnight = Color(0xFF121A33);
const Color _midnight2 = Color(0xFF1E2A4F);
const Color _rose = Color(0xFFE0A58F);
const Color _roseDark = Color(0xFFA15A44);
const Color _porcelain = Color(0xFFFAF9F7);
const Color _ink = Color(0xFF0E1220);
const Color _slate = Color(0xFF5B6177);
const Color _blush = Color(0xFFF3E3DD);
const Color _line = Color(0xFFE7E4EC);

/// Marketing page shown before login. "Get started" opens the login screen.
class LandingPage extends StatefulWidget {
  const LandingPage({super.key});

  @override
  State<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage> {
  final ScrollController _scroll = ScrollController();
  final GlobalKey _featuresKey = GlobalKey();
  final GlobalKey _howKey = GlobalKey();

  void _openLogin() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
    );
  }

  void _jumpTo(GlobalKey key) {
    final ctx = key.currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(
      ctx,
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeInOutCubic,
    );
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.of(context).size.width >= 900;
    return Scaffold(
      backgroundColor: _porcelain,
      body: SingleChildScrollView(
        controller: _scroll,
        child: Column(
          children: [
            _Section(
              child: _Header(
                wide: wide,
                onFeatures: () => _jumpTo(_featuresKey),
                onHow: () => _jumpTo(_howKey),
                onStart: _openLogin,
              ),
            ),
            _Section(
              padding: EdgeInsets.fromLTRB(24, wide ? 48 : 24, 24, wide ? 88 : 56),
              child: _Hero(wide: wide, onStart: _openLogin, onHow: () => _jumpTo(_howKey)),
            ),
            const _Ticker(),
            Container(
              key: _featuresKey,
              width: double.infinity,
              color: Colors.white,
              child: _Section(
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: wide ? 88 : 56),
                child: _Features(wide: wide),
              ),
            ),
            Container(
              key: _howKey,
              child: _Section(
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: wide ? 88 : 56),
                child: _HowItWorks(wide: wide),
              ),
            ),
            _Section(
              padding: EdgeInsets.fromLTRB(24, 0, 24, wide ? 88 : 56),
              child: _CommunityBand(wide: wide, onStart: _openLogin),
            ),
            _Section(
              padding: EdgeInsets.fromLTRB(24, 0, 24, wide ? 88 : 56),
              child: _FinalCta(onStart: _openLogin),
            ),
            const _Footer(),
          ],
        ),
      ),
    );
  }
}

/// Centers content and caps its width on large screens.
class _Section extends StatelessWidget {
  const _Section({required this.child, this.padding = const EdgeInsets.symmetric(horizontal: 24)});
  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1160),
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

/// Fades and rises its child into view the first time it scrolls on screen.
class _Reveal extends StatefulWidget {
  const _Reveal({required this.child, this.delay = Duration.zero});
  final Widget child;
  final Duration delay;

  @override
  State<_Reveal> createState() => _RevealState();
}

class _RevealState extends State<_Reveal> {
  bool _visible = false;
  bool _queued = false;
  ScrollPosition? _position;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _position?.removeListener(_check);
    _position = Scrollable.maybeOf(context)?.position;
    _position?.addListener(_check);
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
  }

  void _check() {
    if (_queued || !mounted) return;
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.attached) return;
    final top = box.localToGlobal(Offset.zero).dy;
    if (top < MediaQuery.of(context).size.height * 0.92) {
      _queued = true;
      Future.delayed(widget.delay, () {
        if (mounted) setState(() => _visible = true);
      });
    }
  }

  @override
  void dispose() {
    _position?.removeListener(_check);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: _visible ? 1 : 0,
      duration: const Duration(milliseconds: 1200),
      curve: Curves.easeOut,
      child: AnimatedSlide(
        offset: _visible ? Offset.zero : const Offset(0, 0.12),
        duration: const Duration(milliseconds: 1200),
        curve: Curves.easeOutCubic,
        child: widget.child,
      ),
    );
  }
}

/// Plays a one-off entrance (fade + rise, optional blur-free) after [delay].
class _Entrance extends StatelessWidget {
  const _Entrance({required this.child, required this.delay, this.dy = 28});
  final Widget child;
  final Duration delay;
  final double dy;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: Future.delayed(delay),
      builder: (context, snap) {
        final on = snap.connectionState == ConnectionState.done;
        return AnimatedOpacity(
          opacity: on ? 1 : 0,
          duration: const Duration(milliseconds: 1400),
          curve: Curves.easeOut,
          child: AnimatedSlide(
            offset: on ? Offset.zero : Offset(0, dy / 100),
            duration: const Duration(milliseconds: 1400),
            curve: Curves.easeOutCubic,
            child: child,
          ),
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.wide, required this.onFeatures, required this.onHow, required this.onStart});
  final bool wide;
  final VoidCallback onFeatures;
  final VoidCallback onHow;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 80,
      child: Row(
        children: [
          Flexible(
            child: RichText(
              overflow: TextOverflow.ellipsis,
              text: TextSpan(
                style: GoogleFonts.sora(fontSize: wide ? 20 : 16, fontWeight: FontWeight.w700, color: _ink, letterSpacing: -0.5),
                children: const [
                  TextSpan(text: 'NextGen '),
                  TextSpan(text: 'Cloth', style: TextStyle(color: _roseDark)),
                  TextSpan(text: ' Engine'),
                ],
              ),
            ),
          ),
          const Spacer(),
          if (wide) ...[
            _NavLink('Features', onFeatures),
            const SizedBox(width: 32),
            _NavLink('How it works', onHow),
            const SizedBox(width: 40),
          ],
          _PrimaryButton(label: 'Get started', onTap: onStart, height: 44),
        ],
      ),
    );
  }
}

class _NavLink extends StatefulWidget {
  const _NavLink(this.label, this.onTap);
  final String label;
  final VoidCallback onTap;

  @override
  State<_NavLink> createState() => _NavLinkState();
}

class _NavLinkState extends State<_NavLink> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(widget.label,
                style: GoogleFonts.manrope(fontSize: 15, fontWeight: FontWeight.w700, color: _hover ? _ink : _slate)),
            const SizedBox(height: 2),
            AnimatedContainer(
              duration: const Duration(milliseconds: 380),
              height: 2,
              width: _hover ? 36 : 0,
              color: _rose,
            ),
          ],
        ),
      ),
    );
  }
}

class _PrimaryButton extends StatefulWidget {
  const _PrimaryButton({required this.label, required this.onTap, this.height = 52, this.dark = true, this.outline = false});
  final String label;
  final VoidCallback onTap;
  final double height;
  final bool dark;
  final bool outline;

  @override
  State<_PrimaryButton> createState() => _PrimaryButtonState();
}

class _PrimaryButtonState extends State<_PrimaryButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final bg = widget.outline ? Colors.transparent : (widget.dark ? _midnight : _rose);
    final fg = widget.outline ? _midnight : (widget.dark ? Colors.white : _ink);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedSlide(
          offset: _hover ? const Offset(0, -0.06) : Offset.zero,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
          child: Container(
            height: widget.height,
            padding: const EdgeInsets.symmetric(horizontal: 28),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(14),
              border: widget.outline ? Border.all(color: _midnight, width: 1.5) : null,
              boxShadow: _hover && !widget.outline
                  ? [BoxShadow(color: bg.withOpacity(0.35), blurRadius: 18, offset: const Offset(0, 8))]
                  : null,
            ),
            child: Text(widget.label,
                style: GoogleFonts.manrope(fontSize: 15, fontWeight: FontWeight.w800, color: fg)),
          ),
        ),
      ),
    );
  }
}

class _Hero extends StatefulWidget {
  const _Hero({required this.wide, required this.onStart, required this.onHow});
  final bool wide;
  final VoidCallback onStart;
  final VoidCallback onHow;

  @override
  State<_Hero> createState() => _HeroState();
}

class _HeroState extends State<_Hero> {
  static const _phrases = ['Decide faster.', 'Feel confident.', 'Stand out.'];
  int _i = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 5500), (_) {
      if (mounted) setState(() => _i = (_i + 1) % _phrases.length);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.wide ? 64.0 : 40.0;
    final headStyle = GoogleFonts.sora(
        fontSize: size, height: 1.08, fontWeight: FontWeight.w600, letterSpacing: -size * 0.035, color: _ink);

    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Entrance(
          delay: const Duration(milliseconds: 140),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(color: const Color(0xFFF5EBE7), borderRadius: BorderRadius.circular(999)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const _PulseDot(),
              const SizedBox(width: 10),
              Text('YOUR PERSONAL AI STYLIST',
                  style: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 1.4, color: _roseDark)),
            ]),
          ),
        ),
        const SizedBox(height: 22),
        Wrap(children: [
          _Entrance(delay: const Duration(milliseconds: 350), dy: 40, child: Text('Dress ', style: headStyle)),
          _Entrance(delay: const Duration(milliseconds: 560), dy: 40, child: Text('better.', style: headStyle)),
        ]),
        _Entrance(
          delay: const Duration(milliseconds: 840),
          dy: 40,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 1200),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeIn,
            transitionBuilder: (child, anim) => FadeTransition(
              opacity: anim,
              child: SlideTransition(
                position: Tween<Offset>(begin: const Offset(0, 0.5), end: Offset.zero).animate(anim),
                child: child,
              ),
            ),
            layoutBuilder: (current, previous) => Stack(
              alignment: Alignment.centerLeft,
              children: [...previous, if (current != null) current],
            ),
            child: ShaderMask(
              key: ValueKey(_i),
              shaderCallback: (r) => const LinearGradient(colors: [_roseDark, _rose, _roseDark]).createShader(r),
              child: Text(_phrases[_i], style: headStyle.copyWith(color: Colors.white)),
            ),
          ),
        ),
        const SizedBox(height: 20),
        _Entrance(
          delay: const Duration(milliseconds: 1120),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Text.rich(
              TextSpan(
                style: GoogleFonts.manrope(fontSize: widget.wide ? 19 : 16, height: 1.55, color: _slate),
                children: [
                  const TextSpan(text: 'Build your digital wardrobe, '),
                  TextSpan(text: 'compare outfits with AI', style: _hl),
                  const TextSpan(text: ', and get looks matched to '),
                  TextSpan(text: 'the weather', style: _hl),
                  const TextSpan(text: ' and the occasion — all in one place.'),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 32),
        _Entrance(
          delay: const Duration(milliseconds: 1330),
          child: Wrap(spacing: 14, runSpacing: 14, children: [
            _PrimaryButton(label: 'Start free', onTap: widget.onStart),
            _PrimaryButton(label: 'See how it works', onTap: widget.onHow, outline: true),
          ]),
        ),
      ],
    );

    final phone = _Entrance(delay: const Duration(milliseconds: 700), child: const _PhoneMock());

    if (widget.wide) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(child: text),
          const SizedBox(width: 56),
          Expanded(child: Center(child: phone)),
        ],
      );
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [text, const SizedBox(height: 48), Center(child: phone)]);
  }

  static final TextStyle _hl = GoogleFonts.manrope(
    fontWeight: FontWeight.w700,
    color: _ink,
    backgroundColor: const Color(0x66F3C9BB),
  );
}

class _PulseDot extends StatefulWidget {
  const _PulseDot();

  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 3000))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) => Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          color: _roseDark,
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: _roseDark.withOpacity(0.5 * (1 - _c.value)), spreadRadius: 10 * _c.value)],
        ),
      ),
    );
  }
}

class _PhoneMock extends StatefulWidget {
  const _PhoneMock();

  @override
  State<_PhoneMock> createState() => _PhoneMockState();
}

class _PhoneMockState extends State<_PhoneMock> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 14))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Widget _tile(Color bg, Color fg, IconData icon, String label) => Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            height: 104,
            decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(16)),
            child: Icon(icon, color: fg, size: 38),
          ),
          const SizedBox(height: 6),
          Text(label, style: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w700, color: _ink)),
        ]),
      );

  Widget _badge(String text, Color dot) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _line),
          boxShadow: [BoxShadow(color: _midnight.withOpacity(0.16), blurRadius: 30, offset: const Offset(0, 12))],
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: dot, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Text(text, style: GoogleFonts.manrope(fontSize: 13, fontWeight: FontWeight.w800, color: _ink)),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) {
        final s = math.sin(_c.value * 2 * math.pi);
        final c = math.sin(_c.value * 2 * math.pi + 1.5);
        return SizedBox(
          width: 400,
          height: 600,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 360 + 30 * s.abs(),
                height: 360 + 30 * s.abs(),
                decoration: BoxDecoration(shape: BoxShape.circle, color: _blush.withOpacity(0.55 + 0.25 * s.abs())),
              ),
              Transform.translate(
                offset: Offset(0, -10 * s),
                child: Transform.rotate(
                  angle: 0.012 * s,
                  child: Container(
                    width: 300,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _midnight,
                      borderRadius: BorderRadius.circular(38),
                      boxShadow: [BoxShadow(color: _midnight.withOpacity(0.28), blurRadius: 60, offset: const Offset(0, 30))],
                    ),
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
                      decoration: BoxDecoration(color: _porcelain, borderRadius: BorderRadius.circular(28)),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                        Text('Good morning', style: GoogleFonts.manrope(fontSize: 12, color: _slate, fontWeight: FontWeight.w600)),
                        Text('What will you wear today?',
                            style: GoogleFonts.sora(fontSize: 20, fontWeight: FontWeight.w600, color: _ink, letterSpacing: -0.4, height: 1.15)),
                        const SizedBox(height: 14),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(color: _midnight, borderRadius: BorderRadius.circular(18)),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(color: _rose, borderRadius: BorderRadius.circular(999)),
                              child: Text('AI STYLIST',
                                  style: GoogleFonts.manrope(fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.2, color: _ink)),
                            ),
                            const SizedBox(height: 8),
                            Text("Can't decide? Let AI pick the best.",
                                style: GoogleFonts.sora(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white, height: 1.2)),
                            const SizedBox(height: 4),
                            Text('Compare up to 3 outfits.', style: GoogleFonts.manrope(fontSize: 12, color: const Color(0xFFCBD2E6))),
                          ]),
                        ),
                        const SizedBox(height: 12),
                        Row(children: [
                          _tile(_blush, _roseDark, Icons.checkroom_rounded, 'Casual Denim'),
                          const SizedBox(width: 10),
                          _tile(const Color(0xFFE4E8F2), const Color(0xFF4A5A8A), Icons.dry_cleaning_rounded, 'Evening Chic'),
                        ]),
                        const SizedBox(height: 10),
                        Row(children: [
                          _tile(const Color(0xFFEFE9E2), _slate, Icons.directions_walk_rounded, 'Sneakers'),
                          const SizedBox(width: 10),
                          _tile(const Color(0xFFF5EBE7), _roseDark, Icons.checkroom_outlined, 'Linen Shirt'),
                        ]),
                      ]),
                    ),
                  ),
                ),
              ),
              Positioned(top: 70 + 6 * c, right: 0, child: _badge('AI pick: Evening Chic', _rose)),
              Positioned(bottom: 90 - 6 * c, left: 0, child: _badge('Clear · 24°', _midnight)),
            ],
          ),
        );
      },
    );
  }
}

/// Endlessly scrolling band of feature names.
class _Ticker extends StatefulWidget {
  const _Ticker();

  @override
  State<_Ticker> createState() => _TickerState();
}

class _TickerState extends State<_Ticker> with SingleTickerProviderStateMixin {
  static const _items = ['Digital wardrobe', 'AI outfit comparison', 'Weather-aware looks', 'Style community', 'Trend explorer'];
  static const double _itemW = 260;
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 70))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final setW = _itemW * _items.length;
    return Container(
      width: double.infinity,
      height: 58,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border.symmetric(horizontal: BorderSide(color: _line)),
      ),
      child: ClipRect(
        child: OverflowBox(
          alignment: Alignment.centerLeft,
          maxWidth: double.infinity,
          child: AnimatedBuilder(
            animation: _c,
            builder: (_, child) => Transform.translate(offset: Offset(-_c.value * setW, 0), child: child),
            child: Row(
              children: [
                for (var r = 0; r < 4; r++)
                  for (final t in _items)
                    SizedBox(
                      width: _itemW,
                      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Text(t.toUpperCase(),
                            style: GoogleFonts.manrope(fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 2, color: _slate)),
                        const SizedBox(width: 18),
                        const Text('✦', style: TextStyle(color: _rose, fontSize: 14)),
                      ]),
                    ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Eyebrow extends StatelessWidget {
  const _Eyebrow(this.eyebrow, this.title, {this.wide = true});
  final String eyebrow;
  final String title;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    return _Reveal(
      child: Align(
        alignment: Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(eyebrow.toUpperCase(),
                style: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 1.4, color: _roseDark)),
            const SizedBox(height: 12),
            Text(title,
                style: GoogleFonts.sora(
                    fontSize: wide ? 44 : 28, height: 1.1, fontWeight: FontWeight.w600, letterSpacing: -1, color: _ink)),
          ]),
        ),
      ),
    );
  }
}

class _Features extends StatelessWidget {
  const _Features({required this.wide});
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final cards = <Widget>[
      const _FeatureCard(Icons.auto_awesome, Color(0xFFF5EBE7), _roseDark, 'AI outfit comparison',
          'Upload up to three outfits and get a scored comparison, with a clear pick and the reasons behind it.'),
      const _FeatureCard(Icons.checkroom_rounded, Color(0xFFE4E8F2), _midnight, 'Digital wardrobe',
          'Photograph what you own, sort it by category, and build outfits from your real closet.'),
      const _FeatureCard(Icons.wb_sunny_outlined, _blush, _roseDark, "Weather-aware looks",
          "Daily suggestions adjust to today's weather so you never over- or under-dress."),
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _Eyebrow('Features', 'Everything you need to look put together', wide: wide),
      const SizedBox(height: 48),
      wide
          ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              for (var i = 0; i < cards.length; i++) ...[
                Expanded(child: _Reveal(delay: Duration(milliseconds: 220 * i), child: cards[i])),
                if (i < cards.length - 1) const SizedBox(width: 24),
              ]
            ])
          : Column(children: [for (final c in cards) Padding(padding: const EdgeInsets.only(bottom: 16), child: _Reveal(child: c))]),
    ]);
  }
}

class _FeatureCard extends StatefulWidget {
  const _FeatureCard(this.icon, this.bg, this.fg, this.title, this.body);
  final IconData icon;
  final Color bg;
  final Color fg;
  final String title;
  final String body;

  @override
  State<_FeatureCard> createState() => _FeatureCardState();
}

class _FeatureCardState extends State<_FeatureCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedSlide(
        offset: _hover ? const Offset(0, -0.02) : Offset.zero,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 320),
          padding: const EdgeInsets.all(28),
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: _line),
            boxShadow: _hover ? [BoxShadow(color: _midnight.withOpacity(0.10), blurRadius: 40, offset: const Offset(0, 18))] : [],
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            AnimatedRotation(
              turns: _hover ? -0.02 : 0,
              duration: const Duration(milliseconds: 450),
              child: AnimatedScale(
                scale: _hover ? 1.1 : 1,
                duration: const Duration(milliseconds: 450),
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(color: widget.bg, borderRadius: BorderRadius.circular(14)),
                  child: Icon(widget.icon, color: widget.fg, size: 24),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(widget.title, style: GoogleFonts.sora(fontSize: 20, fontWeight: FontWeight.w700, color: _ink, letterSpacing: -0.4)),
            const SizedBox(height: 8),
            Text(widget.body, style: GoogleFonts.manrope(fontSize: 15, height: 1.6, color: _slate)),
          ]),
        ),
      ),
    );
  }
}

class _HowItWorks extends StatelessWidget {
  const _HowItWorks({required this.wide});
  final bool wide;

  Widget _step(String n, String title, String body) => Container(
        padding: const EdgeInsets.only(top: 20),
        decoration: const BoxDecoration(border: Border(top: BorderSide(color: _midnight, width: 2))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(n, style: GoogleFonts.sora(fontSize: 14, fontWeight: FontWeight.w700, color: _roseDark)),
          const SizedBox(height: 8),
          Text(title, style: GoogleFonts.sora(fontSize: 22, fontWeight: FontWeight.w700, color: _ink, letterSpacing: -0.5)),
          const SizedBox(height: 8),
          Text(body, style: GoogleFonts.manrope(fontSize: 15, height: 1.6, color: _slate)),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final steps = [
      _step('01', 'Add your clothes', "Snap a photo of each piece. We check it's a real wardrobe item and file it for you."),
      _step('02', 'Ask the stylist', 'Pick an occasion or compare outfits and let the AI recommend the strongest look.'),
      _step('03', 'Share and discover', "Post your outfits, follow creators and explore what's trending in the community."),
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _Eyebrow('How it works', 'From closet to confident in three steps', wide: wide),
      const SizedBox(height: 48),
      wide
          ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              for (var i = 0; i < steps.length; i++) ...[
                Expanded(child: _Reveal(delay: Duration(milliseconds: 260 * i), child: steps[i])),
                if (i < steps.length - 1) const SizedBox(width: 24),
              ]
            ])
          : Column(children: [for (final s in steps) Padding(padding: const EdgeInsets.only(bottom: 28), child: _Reveal(child: s))]),
    ]);
  }
}

class _CommunityBand extends StatelessWidget {
  const _CommunityBand({required this.wide, required this.onStart});
  final bool wide;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final copy = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('A community that shares your taste',
          style: GoogleFonts.sora(fontSize: wide ? 40 : 26, height: 1.12, fontWeight: FontWeight.w600, color: Colors.white, letterSpacing: -1)),
      const SizedBox(height: 16),
      Text('Follow stylists you admire, vote on looks and get inspired by real outfits from real wardrobes.',
          style: GoogleFonts.manrope(fontSize: 17, height: 1.6, color: const Color(0xFFCBD2E6))),
    ]);
    final button = _PrimaryButton(label: 'Join the community', onTap: onStart, dark: false);
    return _Reveal(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: Container(
          width: double.infinity,
          color: _midnight,
          child: Stack(children: [
            Positioned(
              right: -80,
              top: -80,
              child: Container(width: 320, height: 320, decoration: const BoxDecoration(shape: BoxShape.circle, color: _midnight2)),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: wide ? 48 : 24, vertical: wide ? 64 : 36),
              child: wide
                  ? Row(children: [Expanded(child: copy), const SizedBox(width: 40), button])
                  : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [copy, const SizedBox(height: 24), button]),
            ),
          ]),
        ),
      ),
    );
  }
}

class _FinalCta extends StatelessWidget {
  const _FinalCta({required this.onStart});
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return _Reveal(
      child: Column(children: [
        Text('Ready for your best-dressed day?',
            textAlign: TextAlign.center,
            style: GoogleFonts.sora(fontSize: 40, height: 1.1, fontWeight: FontWeight.w600, color: _ink, letterSpacing: -1)),
        const SizedBox(height: 16),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Text('Create your free account and build your first outfit in minutes.',
              textAlign: TextAlign.center, style: GoogleFonts.manrope(fontSize: 18, height: 1.55, color: _slate)),
        ),
        const SizedBox(height: 32),
        _PrimaryButton(label: 'Create free account', onTap: onStart, height: 56),
      ]),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(border: Border(top: BorderSide(color: _line))),
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        runSpacing: 12,
        spacing: 24,
        children: [
          Text('NextGen Cloth Engine', style: GoogleFonts.sora(fontWeight: FontWeight.w700, color: _ink)),
          Text('Your personal AI stylist for every occasion.', style: GoogleFonts.manrope(fontSize: 14, color: _slate)),
        ],
      ),
    );
  }
}
