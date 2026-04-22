import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/app_state.dart';

class AddListSheet extends ConsumerStatefulWidget {
  const AddListSheet({super.key});

  @override
  ConsumerState<AddListSheet> createState() => _AddListSheetState();
}

class _AddListSheetState extends ConsumerState<AddListSheet> {
  final _controller = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;
    final name = _controller.text.trim();
    if (name.isEmpty) return;
    setState(() => _isSubmitting = true);
    try {
      await ref.read(appStateProvider.notifier).addList(name);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'New list',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            autofocus: true,
            enabled: !_isSubmitting,
            decoration: const InputDecoration(hintText: 'List name'),
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _isSubmitting ? null : _submit,
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }
}
