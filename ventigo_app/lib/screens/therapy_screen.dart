import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../widgets/orb_background.dart';
import '../widgets/warm_card.dart';
import '../widgets/flow_button.dart';

// -- Mock therapist data (replace with API later) --
class _Therapist {
  final String name;
  final String title;
  final String photo; // emoji placeholder
  final String specialty;
  final List<String> tags;
  final double rating;
  final int reviews;
  final String availability;
  final int pricePerSession; // in USD
  final bool acceptsChat;
  final bool acceptsCall;
  final bool acceptsVideo;

  const _Therapist({
    required this.name,
    required this.title,
    required this.photo,
    required this.specialty,
    required this.tags,
    required this.rating,
    required this.reviews,
    required this.availability,
    required this.pricePerSession,
    this.acceptsChat = true,
    this.acceptsCall = true,
    this.acceptsVideo = true,
  });
}

const _therapists = [
  _Therapist(
    name: 'Dr. Sarah Mitchell',
    title: 'Licensed Clinical Psychologist',
    photo: '👩‍⚕️',
    specialty: 'Anxiety & Depression',
    tags: ['CBT', 'Mindfulness', 'Trauma'],
    rating: 4.9,
    reviews: 127,
    availability: 'Next available: Tomorrow',
    pricePerSession: 80,
  ),
  _Therapist(
    name: 'Dr. James Rodriguez',
    title: 'Licensed Marriage & Family Therapist',
    photo: '👨‍⚕️',
    specialty: 'Relationships & Family',
    tags: ['Couples', 'Family', 'Communication'],
    rating: 4.8,
    reviews: 89,
    availability: 'Next available: Today',
    pricePerSession: 70,
  ),
  _Therapist(
    name: 'Dr. Priya Sharma',
    title: 'Clinical Psychologist',
    photo: '👩‍💼',
    specialty: 'Stress & Burnout',
    tags: ['Work-Life', 'Self-Esteem', 'ACT'],
    rating: 4.9,
    reviews: 203,
    availability: 'Next available: Wed',
    pricePerSession: 90,
  ),
  _Therapist(
    name: 'Dr. Michael Chen',
    title: 'Licensed Professional Counselor',
    photo: '🧑‍⚕️',
    specialty: 'Grief & Loss',
    tags: ['Grief', 'Life Transitions', 'EMDR'],
    rating: 4.7,
    reviews: 64,
    availability: 'Next available: Thu',
    pricePerSession: 75,
  ),
  _Therapist(
    name: 'Dr. Amara Johnson',
    title: 'Psychiatrist',
    photo: '👩‍🔬',
    specialty: 'ADHD & Mood Disorders',
    tags: ['Medication', 'ADHD', 'Bipolar'],
    rating: 4.8,
    reviews: 156,
    availability: 'Next available: Fri',
    pricePerSession: 120,
  ),
];

class TherapyScreen extends StatefulWidget {
  const TherapyScreen({super.key});

  @override
  State<TherapyScreen> createState() => _TherapyScreenState();
}

class _TherapyScreenState extends State<TherapyScreen> {
  String _selectedFilter = 'All';
  static const _filters = ['All', 'Anxiety', 'Depression', 'Relationships', 'Stress', 'Grief'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.snow,
      body: Stack(
        children: [
          const OrbBackground(),
          SafeArea(
            child: Column(
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: AppColors.listenerLight,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.listenerBorder),
                        ),
                        child: const Center(child: Text('🧠', style: TextStyle(fontSize: 22))),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Professional Therapy', style: AppTypography.title(fontSize: 20, color: AppColors.ink)),
                            Text('Licensed therapists, on your schedule', style: AppTypography.body(fontSize: 12, color: AppColors.slate)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Filter chips
                SizedBox(
                  height: 36,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: _filters.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (_, i) {
                      final f = _filters[i];
                      final active = f == _selectedFilter;
                      return GestureDetector(
                        onTap: () => setState(() => _selectedFilter = f),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: active ? AppColors.ink : AppColors.white,
                            borderRadius: AppRadii.fullAll,
                            border: Border.all(color: active ? AppColors.ink : AppColors.border),
                          ),
                          child: Text(f, style: AppTypography.ui(
                            fontSize: 12, fontWeight: FontWeight.w600,
                            color: active ? AppColors.white : AppColors.slate,
                          )),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),

                // Therapist list
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    itemCount: _therapists.length + 1, // +1 for disclaimer
                    itemBuilder: (_, i) {
                      if (i == _therapists.length) return _buildDisclaimer();
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: _TherapistCard(
                          therapist: _therapists[i],
                          onBook: () => _showBookingSheet(_therapists[i]),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDisclaimer() {
    return Container(
      margin: const EdgeInsets.only(top: 8, bottom: 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.amber.withValues(alpha: 0.08),
        borderRadius: AppRadii.mdAll,
        border: Border.all(color: AppColors.amber.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('⚠️', style: TextStyle(fontSize: 18)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Ventigo is a peer support platform, not a substitute for professional mental health care. If you are experiencing a mental health emergency, please contact emergency services or a crisis helpline.',
              style: AppTypography.body(fontSize: 11, color: AppColors.charcoal),
            ),
          ),
        ],
      ),
    );
  }

  void _showBookingSheet(_Therapist t) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _BookingSheet(therapist: t),
    );
  }
}

class _TherapistCard extends StatelessWidget {
  final _Therapist therapist;
  final VoidCallback onBook;

  const _TherapistCard({required this.therapist, required this.onBook});

  @override
  Widget build(BuildContext context) {
    return WarmCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Avatar
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: AppColors.listenerLight,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.listenerBorder),
                ),
                child: Center(child: Text(therapist.photo, style: const TextStyle(fontSize: 28))),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(therapist.name, style: AppTypography.ui(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.ink)),
                    const SizedBox(height: 2),
                    Text(therapist.title, style: AppTypography.body(fontSize: 11, color: AppColors.slate)),
                  ],
                ),
              ),
              // Rating
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.amber.withValues(alpha: 0.12),
                  borderRadius: AppRadii.fullAll,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('⭐', style: TextStyle(fontSize: 12)),
                    const SizedBox(width: 3),
                    Text('${therapist.rating}', style: AppTypography.ui(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.ink)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Specialty
          Text(therapist.specialty, style: AppTypography.ui(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.ink)),
          const SizedBox(height: 8),

          // Tags
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: therapist.tags.map((tag) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.pale,
                borderRadius: AppRadii.fullAll,
              ),
              child: Text(tag, style: AppTypography.micro(fontSize: 10, color: AppColors.graphite)),
            )).toList(),
          ),
          const SizedBox(height: 12),

          // Bottom row: availability, price, modes, book
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(therapist.availability, style: AppTypography.body(fontSize: 11, color: AppColors.slate)),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text('\$${therapist.pricePerSession}/session', style: AppTypography.ui(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.ink)),
                        const SizedBox(width: 10),
                        // Mode icons
                        if (therapist.acceptsChat) _modeIcon(Icons.chat_bubble_outline_rounded, 'Chat'),
                        if (therapist.acceptsCall) _modeIcon(Icons.phone_outlined, 'Call'),
                        if (therapist.acceptsVideo) _modeIcon(Icons.videocam_outlined, 'Video'),
                      ],
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: onBook,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.ink,
                    borderRadius: AppRadii.fullAll,
                  ),
                  child: Text('Book', style: AppTypography.ui(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.white)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _modeIcon(IconData icon, String tooltip) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: Tooltip(
        message: tooltip,
        child: Icon(icon, size: 16, color: AppColors.slate),
      ),
    );
  }
}

class _BookingSheet extends StatefulWidget {
  final _Therapist therapist;
  const _BookingSheet({required this.therapist});

  @override
  State<_BookingSheet> createState() => _BookingSheetState();
}

class _BookingSheetState extends State<_BookingSheet> {
  String _selectedMode = 'video';
  int _selectedDay = 1; // 0=today, 1=tomorrow, etc.
  int _selectedSlot = 0;
  bool _booking = false;
  bool _booked = false;

  static const _timeSlots = ['9:00 AM', '10:30 AM', '12:00 PM', '2:00 PM', '3:30 PM', '5:00 PM'];

  @override
  Widget build(BuildContext context) {
    final t = widget.therapist;
    final now = DateTime.now();

    return Container(
      decoration: BoxDecoration(
        color: AppColors.snow,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(24, 16, 24, MediaQuery.of(context).padding.bottom + 24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.mist, borderRadius: BorderRadius.circular(2))),
            ),
            const SizedBox(height: 20),

            if (_booked) ...[
              // Success state
              Center(
                child: Column(
                  children: [
                    Container(
                      width: 80, height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.success.withValues(alpha: 0.12),
                        border: Border.all(color: AppColors.success.withValues(alpha: 0.3), width: 2),
                      ),
                      child: const Center(child: Text('✓', style: TextStyle(fontSize: 36, color: Color(0xFF7ECAA0)))),
                    ),
                    const SizedBox(height: 16),
                    Text('Appointment Booked!', style: AppTypography.title(fontSize: 22)),
                    const SizedBox(height: 8),
                    Text('${t.name} · ${_timeSlots[_selectedSlot]}', style: AppTypography.body(fontSize: 14, color: AppColors.slate)),
                    const SizedBox(height: 4),
                    Text(
                      _selectedMode == 'video' ? 'Video Call' : _selectedMode == 'call' ? 'Phone Call' : 'Chat Session',
                      style: AppTypography.ui(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.lavender),
                    ),
                    const SizedBox(height: 24),
                    FlowButton(
                      label: 'Done',
                      onPressed: () => Navigator.of(context).pop(),
                      expand: true,
                    ),
                  ],
                ),
              ),
            ] else ...[
              // Therapist info
              Row(
                children: [
                  Container(
                    width: 48, height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.listenerLight,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.listenerBorder),
                    ),
                    child: Center(child: Text(t.photo, style: const TextStyle(fontSize: 24))),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(t.name, style: AppTypography.ui(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.ink)),
                        Text(t.specialty, style: AppTypography.body(fontSize: 12, color: AppColors.slate)),
                      ],
                    ),
                  ),
                  Text('\$${t.pricePerSession}', style: AppTypography.title(fontSize: 20, color: AppColors.ink)),
                ],
              ),
              const SizedBox(height: 24),

              // Session type
              Text('SESSION TYPE', style: AppTypography.label()),
              const SizedBox(height: 10),
              Row(
                children: [
                  if (t.acceptsVideo) _modeButton('video', Icons.videocam_rounded, 'Video Call'),
                  if (t.acceptsCall) _modeButton('call', Icons.phone_rounded, 'Call'),
                  if (t.acceptsChat) _modeButton('chat', Icons.chat_bubble_rounded, 'Chat'),
                ],
              ),
              const SizedBox(height: 20),

              // Day selection
              Text('SELECT DAY', style: AppTypography.label()),
              const SizedBox(height: 10),
              SizedBox(
                height: 64,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: 7,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, i) {
                    final day = now.add(Duration(days: i));
                    final active = i == _selectedDay;
                    final dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
                    return GestureDetector(
                      onTap: () => setState(() => _selectedDay = i),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 52,
                        decoration: BoxDecoration(
                          color: active ? AppColors.ink : AppColors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: active ? AppColors.ink : AppColors.border),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(dayNames[day.weekday - 1], style: AppTypography.micro(fontSize: 10, color: active ? AppColors.white.withValues(alpha: 0.6) : AppColors.slate)),
                            const SizedBox(height: 2),
                            Text('${day.day}', style: AppTypography.ui(fontSize: 16, fontWeight: FontWeight.w700, color: active ? AppColors.white : AppColors.ink)),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),

              // Time slots
              Text('SELECT TIME', style: AppTypography.label()),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: List.generate(_timeSlots.length, (i) {
                  final active = i == _selectedSlot;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedSlot = i),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: active ? AppColors.accent : AppColors.white,
                        borderRadius: AppRadii.smAll,
                        border: Border.all(color: active ? AppColors.accent : AppColors.border),
                      ),
                      child: Text(
                        _timeSlots[i],
                        style: AppTypography.ui(fontSize: 13, fontWeight: FontWeight.w600, color: active ? AppColors.white : AppColors.ink),
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 24),

              // Book button
              FlowButton(
                label: _booking ? 'Booking…' : 'Confirm Booking · \$${t.pricePerSession}',
                onPressed: _booking ? null : _handleBook,
                expand: true,
                loading: _booking,
              ),
              const SizedBox(height: 8),
              FlowButton(
                label: 'Cancel',
                variant: FlowButtonVariant.ghost,
                onPressed: () => Navigator.of(context).pop(),
                expand: true,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _modeButton(String mode, IconData icon, String label) {
    final active = _selectedMode == mode;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedMode = mode),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.only(right: 8),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: active ? AppColors.lavender.withValues(alpha: 0.15) : AppColors.white,
            borderRadius: AppRadii.mdAll,
            border: Border.all(color: active ? AppColors.lavender : AppColors.border),
          ),
          child: Column(
            children: [
              Icon(icon, size: 22, color: active ? AppColors.lavender : AppColors.slate),
              const SizedBox(height: 4),
              Text(label, style: AppTypography.micro(fontSize: 10, color: active ? AppColors.ink : AppColors.slate)),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleBook() async {
    setState(() => _booking = true);
    // Simulate booking API call
    await Future.delayed(const Duration(seconds: 1));
    if (mounted) setState(() { _booking = false; _booked = true; });
  }
}
