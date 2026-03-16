
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/firestore_mess_service.dart';
import 'home_screen.dart';

class CreateMessScreen extends StatefulWidget {
  const CreateMessScreen({super.key});

  @override
  State<CreateMessScreen> createState() => _CreateMessScreenState();
}

class _CreateMessScreenState extends State<CreateMessScreen> {
  final TextEditingController messNameController = TextEditingController();
  bool isLoading = false;

  Future<void> createMess() async {
    final messName = messNameController.text.trim();
    if (messName.isEmpty) {
      _show('Mess name likho');
      return;
    }
    setState(() => isLoading = true);
    try {
      await FirestoreMessService.createMess(messName: messName);
      if (!mounted) return;
      _show('Mess created successfully');
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      _show('Mess create failed: $e');
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
    messNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Mess'),
        actions: [
          IconButton(onPressed: _logout, icon: const Icon(Icons.logout_rounded)),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
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
                children: [
                  Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      color: colors.primaryContainer,
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: Icon(Icons.add_home_work_outlined, color: colors.primary, size: 38),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Create a new mess',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Enter a mess name. Join code and owner info will be created automatically.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 22),
                  TextField(
                    controller: messNameController,
                    decoration: const InputDecoration(
                      labelText: 'Mess Name',
                      prefixIcon: Icon(Icons.home_work_outlined),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton(
                      onPressed: isLoading ? null : createMess,
                      child: isLoading
                          ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('Create Mess'),
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
