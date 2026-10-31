import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show SignOutScope;
import '../l10n/data_error_message.dart';
import '../l10n/l10n.dart';
import '../main.dart' show supabase;
import '../services/data_service.dart';
import '../theme/app_theme.dart';

/// Confirmation + execution of "Delete account". The player must type a
/// confirm word before the destructive button enables. On success the session
/// is dropped locally; the router redirect then returns to the landing screen.
Future<void> showDeleteAccountDialog(BuildContext context) => showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const DeleteAccountDialog(),
    );

class DeleteAccountDialog extends StatefulWidget {
  const DeleteAccountDialog({super.key});

  @override
  State<DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<DeleteAccountDialog> {
  final _controller = TextEditingController();
  bool _deleting = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // Both words are free of the Turkish dotted/dotless i, so a plain
  // toUpperCase() compares correctly on every keyboard.
  bool _matches(String word) =>
      _controller.text.trim().toUpperCase() == word.toUpperCase();

  Future<void> _delete() async {
    final l = context.l10n;
    final navigator = Navigator.of(context);
    setState(() {
      _deleting = true;
      _error = null;
    });
    try {
      await dataService.deleteAccount();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _deleting = false;
        _error = dataErrorMessage(l, e);
      });
      return;
    }
    // The server already removed the user, so the token is dead: the remote
    // logout may be refused, but the local session must go either way.
    try {
      await supabase.auth.signOut(scope: SignOutScope.local);
    } catch (_) {}
    if (navigator.mounted) navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final word = l.deleteAccountWord;
    return AlertDialog(
      title: Text(l.deleteAccountTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l.deleteAccountBody),
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              enabled: !_deleting,
              autocorrect: false,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                labelText: l.deleteAccountTypeHint(word),
              ),
              onChanged: (_) => setState(() {}),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!,
                  style: const TextStyle(color: RallyColors.accent2)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _deleting ? null : () => Navigator.pop(context),
          child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
        ),
        TextButton(
          onPressed: _deleting || !_matches(word) ? null : _delete,
          child: _deleting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(l.deleteAccountConfirm,
                  style: TextStyle(
                      color: _matches(word) ? RallyColors.accent2 : null)),
        ),
      ],
    );
  }
}
