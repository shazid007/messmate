import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  bool isLoading = false;
  bool obscurePassword = true;

  Future<void> signUpUser() async {
    final name = nameController.text.trim();
    final email = emailController.text.trim().toLowerCase();
    final password = passwordController.text.trim();
    if (name.isEmpty || email.isEmpty || password.isEmpty) return _show('Please fill all fields');
    setState(() => isLoading = true);
    try {
      final credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(email: email, password: password);
      final user = credential.user;
      if (user != null) {
        await user.updateDisplayName(name);
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'uid': user.uid,
          'name': name,
          'email': email,
          'messId': null,
          'role': null,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
      if (!mounted) return;
      Navigator.pop(context);
      _show('Account created successfully');
    } on FirebaseAuthException catch (e) {
      _show(e.message ?? 'Signup failed');
    } catch (e) {
      _show('Something went wrong: $e');
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _show(String message) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sign Up'), centerTitle: true),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(children: [
            const Icon(Icons.person_add_alt_1, size: 80),
            const SizedBox(height: 20),
            TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Name', border: OutlineInputBorder())),
            const SizedBox(height: 15),
            TextField(controller: emailController, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder())),
            const SizedBox(height: 15),
            TextField(controller: passwordController, obscureText: obscurePassword, decoration: InputDecoration(labelText: 'Password', border: const OutlineInputBorder(), suffixIcon: IconButton(onPressed: () => setState(() => obscurePassword = !obscurePassword), icon: Icon(obscurePassword ? Icons.visibility_off : Icons.visibility)))),
            const SizedBox(height: 20),
            SizedBox(width: double.infinity, height: 50, child: ElevatedButton(onPressed: isLoading ? null : signUpUser, child: isLoading ? const CircularProgressIndicator() : const Text('Create Account'))),
          ]),
        ),
      ),
    );
  }
}
