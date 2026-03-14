import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/theme.dart';
import '../config/brand.dart';
import '../services/api_client.dart';
import '../state/auth_provider.dart';
import '../widgets/flow_button.dart';

/// Report modal - maps ReportModal.tsx.
class ReportModal extends ConsumerStatefulWidget {
  final String? roomId;
  final VoidCallback onClose;

  const ReportModal({super.key, this.roomId, required this.onClose});

  @override
  ConsumerState<ReportModal> createState() => _ReportModalState();
}

class _ReportModalState extends ConsumerState<ReportModal> {
  static const _reasons = [
    ('harassment', 'Harassment'),
    ('spam', 'Spam'),
    ('hate_speech', 'Hate speech'),
    ('inappropriate_content', 'Inappropriate content'),
    ('sharing_personal_info', 'Sharing personal information'),
    ('self_harm', 'Self-harm or crisis content'),
    ('underage_suspected', 'Underage suspected'),
    ('other', 'Other'),
  ];

  String? _reason;
  final _detailCtrl = TextEditingController();
  bool _submitted = false;
  String? _error;
  bool _loading = false;

  @override
  void dispose() {
    _detailCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_reason == null) return;
    setState(() { _loading = true; _error = null; });
    try {
      final token = ref.read(authProvider).token!;
      await ref.read(apiClientProvider).submitReport(
            token,
            _reason!,
            detail: _detailCtrl.text.trim(),
            roomId: widget.roomId,
          );
      setState(() => _submitted = true);
    } on AuthException {
      setState(() => _error = 'Session expired. Please sign in again.');
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onClose,
      child: Container(
        color: Colors.black54,
        alignment: Alignment.center,
        child: GestureDetector(
          onTap: () {}, // absorb inner taps
          child: Container(
            width: 380,
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: AppRadii.lgAll,
              border: Border.all(color: AppColors.border),
              boxShadow: warmShadow(blur: 32, opacity: 0.12),
            ),
            child: _submitted ? _successView() : _formView(),
          ),
        ),
      ),
    );
  }

  Widget _successView() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('✓', style: TextStyle(fontSize: 32, color: AppColors.success)),
        const SizedBox(height: 12),
        Text('Report submitted', style: AppTypography.heading(fontSize: 22)),
        const SizedBox(height: 8),
        Text(Brand.safetyThankYou, style: AppTypography.body(color: AppColors.slate), textAlign: TextAlign.center),
        const SizedBox(height: 20),
        FlowButton(label: 'Close', variant: FlowButtonVariant.ghost, onPressed: widget.onClose),
      ],
    );
  }

  Widget _formView() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Report user', style: AppTypography.heading(fontSize: 22)),
        const SizedBox(height: 6),
        Text('Select a reason:', style: AppTypography.body(color: AppColors.slate)),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _reasons.map((r) {
            final selected = _reason == r.$1;
            return ChoiceChip(
              label: Text(r.$2),
              selected: selected,
              backgroundColor: AppColors.accentDim,
              side: BorderSide(color: selected ? AppColors.accent : AppColors.border),
              labelStyle: AppTypography.ui(fontSize: 12, color: selected ? AppColors.accent : AppColors.slate),
              onSelected: (_) => setState(() => _reason = r.$1),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _detailCtrl,
          maxLength: 500,
          maxLines: 3,
          style: AppTypography.ui(fontSize: 13, color: AppColors.ink),
          decoration: const InputDecoration(hintText: 'Optional details…'),
        ),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(_error!, style: TextStyle(color: AppColors.danger, fontSize: 13)),
        ],
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            FlowButton(label: 'Cancel', variant: FlowButtonVariant.ghost, size: FlowButtonSize.sm, onPressed: widget.onClose),
            const SizedBox(width: 8),
            FlowButton(
              label: 'Submit',
              onPressed: _reason != null ? _submit : null,
              loading: _loading,
              size: FlowButtonSize.sm,
            ),
          ],
        ),
      ],
    );
  }
}
