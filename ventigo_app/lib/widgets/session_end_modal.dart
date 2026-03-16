import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../config/theme.dart';
import '../widgets/flow_button.dart';

/// Session-end modal with mood check, appreciation, continue, and extend.
class SessionEndModal extends StatefulWidget {
  final bool canExtend;
  final bool canContinue;
  final bool peerLeft;
  final bool continueWaiting;
  final String? peerUsername;
  final VoidCallback onExtend;
  final VoidCallback onContinue;
  final VoidCallback onClose;
  final void Function(String mood)? onFeedback;
  final Future<void> Function(String message)? onAppreciation;

  const SessionEndModal({
    super.key,
    required this.canExtend,
    this.canContinue = true,
    this.peerLeft = false,
    this.continueWaiting = false,
    this.peerUsername,
    required this.onExtend,
    this.onContinue = _noop,
    required this.onClose,
    this.onFeedback,
    this.onAppreciation,
  });

  static void _noop() {}

  @override
  State<SessionEndModal> createState() => _SessionEndModalState();
}

class _SessionEndModalState extends State<SessionEndModal> {
  String? _selectedMood;
  final _appreciationController = TextEditingController();
  bool _appreciationSent = false;
  bool _appreciationSending = false;

  @override
  void dispose() {
    _appreciationController.dispose();
    super.dispose();
  }

  Future<void> _submitAppreciation() async {
    final text = _appreciationController.text.trim();
    if (text.isEmpty || widget.onAppreciation == null) return;
    setState(() => _appreciationSending = true);
    try {
      await widget.onAppreciation!(text);
      setState(() { _appreciationSent = true; _appreciationSending = false; });
    } catch (_) {
      setState(() => _appreciationSending = false);
    }
  }

  static const _moods = [
    ('😌', 'Calm', 'calm'),
    ('😊', 'Better', 'better'),
    ('😐', 'Same', 'same'),
    ('😔', 'Worse', 'worse'),
  ];

  Widget _buildHeader() {
    return Column(
      children: [
        Container(
          width: 100, height: 100,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.venterLight,
            border: Border.all(color: AppColors.venterBorder, width: 2),
          ),
          alignment: Alignment.center,
          child: const Text('🌿', style: TextStyle(fontSize: 44)),
        ),
        const SizedBox(height: 20),
        Text(
          'Session complete.',
          style: AppTypography.display(fontSize: 28),
        ),
        const SizedBox(height: 8),
        Text(
          'You showed up. That matters.\nTake a breath \u2014 you deserve it.',
          style: AppTypography.body(color: AppColors.slate),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildMoodPicker() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: _moods.map((m) {
        final selected = _selectedMood == m.$3;
        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              setState(() => _selectedMood = m.$3);
              widget.onFeedback?.call(m.$3);
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: selected ? AppColors.accentDim : Colors.transparent,
                border: Border.all(
                  color: selected ? AppColors.accent : Colors.transparent,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(m.$1, style: const TextStyle(fontSize: 24)),
                  const SizedBox(height: 4),
                  Text(m.$2, style: AppTypography.micro(fontSize: 10, color: AppColors.slate)),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  List<Widget> _buildActionButtons(BuildContext context) {
    return [
      if (widget.canContinue && !widget.peerLeft) ...[
        FlowButton(
          label: widget.continueWaiting ? 'Waiting for them…' : 'Continue chatting',
          onPressed: widget.continueWaiting ? null : widget.onContinue,
          expand: true,
        ),
        const SizedBox(height: 10),
      ],
      if (widget.canExtend && !widget.peerLeft) ...[
        FlowButton(
          label: 'Extend 15 minutes',
          variant: widget.canContinue ? FlowButtonVariant.ghost : FlowButtonVariant.primary,
          onPressed: widget.onExtend,
          expand: true,
        ),
        const SizedBox(height: 10),
      ],
      FlowButton(
        label: 'Back to lobby',
        variant: FlowButtonVariant.ghost,
        onPressed: () => context.go('/chats'),
        expand: true,
      ),
      const SizedBox(height: 10),
      FlowButton(
        label: 'Close',
        variant: FlowButtonVariant.ghost,
        size: FlowButtonSize.sm,
        onPressed: widget.onClose,
      ),
    ];
  }

  Widget _buildAppreciation() {
    if (widget.onAppreciation == null) return const SizedBox.shrink();
    final peer = widget.peerUsername ?? 'them';

    if (_appreciationSent) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.accentDim,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.accentGlow),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('💛', style: TextStyle(fontSize: 18)),
            const SizedBox(width: 8),
            Text('Appreciation sent!', style: AppTypography.ui(color: AppColors.accent, fontWeight: FontWeight.w600)),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Leave a note for $peer 💛', style: AppTypography.micro(color: AppColors.amber)),
        const SizedBox(height: 8),
        TextField(
          controller: _appreciationController,
          maxLength: 500,
          maxLines: 3,
          minLines: 1,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            hintText: 'You made this conversation meaningful…',
            hintStyle: AppTypography.body(color: AppColors.fog),
            filled: true,
            fillColor: AppColors.card,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.accent),
            ),
            counterText: '',
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: FlowButton(
            label: _appreciationSending ? 'Sending…' : 'Send appreciation',
            size: FlowButtonSize.sm,
            onPressed: _appreciationSending ? null : _submitAppreciation,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 360,
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: AppRadii.lgAll,
            border: Border.all(color: AppColors.border),
            boxShadow: warmShadow(blur: 32, opacity: 0.12),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildHeader(),
                const SizedBox(height: 20),
                if (!widget.peerLeft) ...[
                  _buildMoodPicker(),
                  const SizedBox(height: 20),
                  _buildAppreciation(),
                  const SizedBox(height: 24),
                ],
                ..._buildActionButtons(context),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
