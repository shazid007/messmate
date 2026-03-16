
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/firestore_mess_service.dart';
import 'home_screen.dart';

class JoinMessScreen extends StatefulWidget {
  const JoinMessScreen({super.key});

  @override
  State<JoinMessScreen> createState() => _JoinMessScreenState();
}

class _JoinMessScreenState extends State<JoinMessScreen> {
  final TextEditingController joinCodeController = TextEditingController();
  bool isLoading = false;

  Future<void> joinMess() async {
    final code = joinCodeController.text.trim().toUpperCase();
    if (code.isEmpty) {
      _show('Enter join code');
      return;
    }
    setState(() => isLoading = true);
    try {
      await FirestoreMessService.joinMessByCode(code);
      if (!mounted) return;
      _show('Joined successfully');
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      _show('Join failed: $e');
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
  }

  void _show(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    joinCodeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Join Mess'),
        actions: [
          IconButton(onPressed: _logout, icon: const Icon(Icons.logout_rounded)),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(28),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x12000000),
                    blurRadius: 24,
                    offset: Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      color: colors.primaryContainer,
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: Icon(Icons.group_add_rounded, color: colors.primary, size: 38),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Join an existing mess',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Paste the join code shared by your mess owner.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 22),
                  TextField(
                    controller: joinCodeController,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(
                      labelText: 'Enter Join Code',
                      prefixIcon: Icon(Icons.vpn_key_outlined),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton(
                      onPressed: isLoading ? null : joinMess,
                      child: isLoading
                          ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('Join Mess'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
