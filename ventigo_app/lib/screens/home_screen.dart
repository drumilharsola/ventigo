import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../config/theme.dart';
import '../data/quotes.dart';
import '../state/auth_provider.dart';
import '../widgets/warm_card.dart';
import '../widgets/flow_logo.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _speakCount = 0;
  int _listenCount = 0;
  int _appreciationCount = 0;
  late final String _quote = quoteOfTheDay();

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    final token = ref.read(authProvider).token;
    if (token == null) return;
    try {
      final me = await ref.read(apiClientProvider).getMe(token);
      if (mounted) {
        setState(() {
          _speakCount = me.speakCount;
          _listenCount = me.listenCount;
          _appreciationCount = me.appreciationCount;
        });
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final narrow = MediaQuery.sizeOf(context).width < 720;

    return Scaffold(
      backgroundColor: AppColors.snow,
      body: Stack(
        children: [
          // Ambient orb
          Positioned(
            top: -120,
            right: -120,
            child: RepaintBoundary(child: Container(
              width: 400,
              height: 400,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  AppColors.accentGlow.withValues(alpha: 0.15),
                  Colors.transparent,
                ]),
              ),
            )),
          ),
          SafeArea(
            child: Column(
              children: [
                // ── Sticky header (does not scroll) ──
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const FlowLogo(dark: true),
                      IconButton(
                        onPressed: () {},
                        icon: Icon(Icons.notifications_none_rounded, color: AppColors.ink, size: 24),
                      ),
                    ],
                  ),
                ),
                // ── Scrollable body ──
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 16),

                  // Greeting
                  RichText(
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    text: TextSpan(
                      style: AppTypography.display(
                        fontSize: narrow ? 26 : 38,
                        color: AppColors.ink,
                      ),
                      children: [
                        const TextSpan(text: 'Welcome back,\n'),
                        TextSpan(
                          text: '${auth.username ?? 'friend'}.',
                          style: TextStyle(
                            fontStyle: FontStyle.italic,
                            color: AppColors.accent,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // -- Quote card (dark) --
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      color: AppColors.ink,
                      borderRadius: AppRadii.lgAll,
                    ),
                    child: Stack(
                      children: [
                        Positioned(
                          top: -20,
                          right: -20,
                          child: Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(colors: [
                                AppColors.peach.withValues(alpha: 0.1),
                                Colors.transparent,
                              ]),
                            ),
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('\u2726 THOUGHT OF THE DAY',
                                style: AppTypography.label(color: AppColors.peach)),
                            const SizedBox(height: 16),
                            Text(
                              '"$_quote"',
                              maxLines: 5,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.title(
                                fontSize: 18,
                                color: AppColors.white,
                              ).copyWith(
                                fontStyle: FontStyle.italic,
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // -- Action cards --
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => context.go('/chats'),
                          child: Container(
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color: AppColors.venterLight,
                              borderRadius: AppRadii.lgAll,
                              border: Border.all(color: AppColors.venterBorder),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('\ud83c\udf99', style: TextStyle(fontSize: 28)),
                                const SizedBox(height: 12),
                                Text('Need to vent?', style: AppTypography.title(fontSize: 16, color: AppColors.ink)),
                                const SizedBox(height: 4),
                                Text('15-min anonymous session', style: AppTypography.body(fontSize: 12, color: AppColors.graphite)),
                                const SizedBox(height: 12),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: AppColors.peach,
                                    borderRadius: AppRadii.fullAll,
                                  ),
                                  child: Text('Start \u2192', style: AppTypography.ui(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.white)),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => context.go('/chats'),
                          child: Container(
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color: AppColors.listenerLight,
                              borderRadius: AppRadii.lgAll,
                              border: Border.all(color: AppColors.listenerBorder),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('\ud83e\udd0d', style: TextStyle(fontSize: 28)),
                                const SizedBox(height: 12),
                                Text('Hold space', style: AppTypography.title(fontSize: 16, color: AppColors.ink)),
                                const SizedBox(height: 4),
                                Text("Be someone's listener today", style: AppTypography.body(fontSize: 12, color: AppColors.graphite)),
                                const SizedBox(height: 12),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: AppColors.lavender,
                                    borderRadius: AppRadii.fullAll,
                                  ),
                                  child: Text('Browse \u2192', style: AppTypography.ui(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.white)),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // -- Stats row --
                  Row(
                    children: [
                      Expanded(child: WarmCard(
                        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                        child: Column(children: [
                          Text('$_speakCount', style: AppTypography.display(fontSize: 24)),
                          const SizedBox(height: 4),
                          Text('VENTED', style: AppTypography.micro(fontSize: 10)),
                        ]),
                      )),
                      const SizedBox(width: 8),
                      Expanded(child: WarmCard(
                        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                        child: Column(children: [
                          Text('$_listenCount', style: AppTypography.display(fontSize: 24)),
                          const SizedBox(height: 4),
                          Text('LISTENED', style: AppTypography.micro(fontSize: 10)),
                        ]),
                      )),
                      const SizedBox(width: 8),
                      Expanded(child: WarmCard(
                        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                        child: Column(children: [
                          Text('$_appreciationCount', style: AppTypography.display(fontSize: 24)),
                          const SizedBox(height: 4),
                          Text('APPREC. \u2726', style: AppTypography.micro(fontSize: 10)),
                        ]),
                      )),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Wellbeing tip
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.listenerLight,
                      borderRadius: AppRadii.lgAll,
                      border: Border.all(color: AppColors.listenerBorder),
                    ),
                    child: Row(
                      children: [
                        const Text('\ud83e\uddd8', style: TextStyle(fontSize: 28)),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Take a moment',
                                  style: AppTypography.title(
                                      fontSize: 16, color: AppColors.ink)),
                              const SizedBox(height: 4),
                              Text(
                                'Close your eyes. Take 3 deep breaths. You deserve this pause.',
                                style: AppTypography.body(
                                    fontSize: 13, color: AppColors.graphite),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
          ),
        ],
      ),
    );
  }
}
