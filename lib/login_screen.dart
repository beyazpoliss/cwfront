import 'dart:io';
import 'dart:ui';
import 'package:cwfront/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'app_localizations.dart';
import 'home_screen.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _slideAnimation;
  bool _obscurePassword = true;
  bool _dontForgetMe = false; // "Don't forget me" checkbox state
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  final _storage = const FlutterSecureStorage(); // Secure storage

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _fadeAnimation =
        Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(
          parent: _controller,
          curve: Curves.easeIn,
        ));

    _slideAnimation =
        Tween<double>(begin: 50.0, end: 0.0).animate(CurvedAnimation(
          parent: _controller,
          curve: Curves.easeOut,
        ));

    _controller.forward();
    _checkRememberedCredentials(); // Check for remembered credentials
  }

  // Check if the user has opted for "Don't forget me" and auto-fill credentials
  Future<void> _checkRememberedCredentials() async {
    String? savedUsername = await _storage.read(key: 'remembered_username');
    String? savedPassword = await _storage.read(key: 'remembered_password');
    String? remember = await _storage.read(key: 'remember_me');

    if(remember == null){
      _dontForgetMe = false; // Set the checkbox to true
      return;
    }

    if (savedUsername != null && savedPassword != null) {
      // Auto-fill the username and password fields
      _usernameController.text = savedUsername;
      _passwordController.text = savedPassword;
      await _login(); // Automatically attempt login
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_formKey.currentState!.validate()) {
      try {

        final response = await http.post(
          Uri.parse('${StorageService.url}/login'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({
            'username': _usernameController.text,
            'password': _passwordController.text,
          }),
        );

        // Debug logs for response
        print('Response status: ${response.statusCode}');
        print('Response body: ${response.body}');

        if (response.statusCode == 200) {
          final responseData = json.decode(response.body);
          final token = responseData['token'];

          // Token debug log
          print('Token: $token');

          await StorageService.write('jwt_token', token);
          await StorageService.write("username", _usernameController.text);

          // If "Don't forget me" is checked, store the credentials
          if (_dontForgetMe) {
            await _storage.write(
                key: 'remembered_username', value: _usernameController.text);
            await _storage.write(
                key: 'remembered_password', value: _passwordController.text);
          } else {
            // Clear the credentials if the user opts out of "Don't forget me"
            await _storage.delete(key: 'remembered_username');
            await _storage.delete(key: 'remembered_password');
          }

          // Navigate to HomeScreen
          if (context.mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const HomeScreen()),
            );
          }
        } else {
          // Invalid login handling
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${AppLocalizations.of(context)!.translate(
                  'login_failed')}: ${response.body}'),
            ),
          );
        }
      } catch (e) {
        String errorMessage = AppLocalizations.of(context)!.translate(
            'login_error');

        print('Error: $e');
        if (e is SocketException) {
          errorMessage =
              AppLocalizations.of(context)!.translate('no_connection');
          print('SocketException: $e');
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);

    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/images/background.jpg'),
                fit: BoxFit.cover,
              ),
            ),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
              child: Container(color: Colors.black.withOpacity(0.9)),
            ),
          ),
          SafeArea(
            child: Stack(
              children: [
                Positioned(
                  top: 16,
                  left: MediaQuery
                      .of(context)
                      .size
                      .width / 2 - 32,
                  child: const Text(
                    'CW',
                    style: TextStyle(color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.bold),
                  ),
                ),
                SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: Form(
                        key: _formKey,
                        child: Column(
                          children: [
                            SizedBox(height: MediaQuery
                                .of(context)
                                .size
                                .height * 0.20),
                            TextFormField(
                              controller: _usernameController,
                              style: const TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                hintText: localizations?.translate(
                                    'username_hint') ?? 'Username',
                                hintStyle: const TextStyle(
                                    color: Colors.white70),
                                prefixIcon: const Icon(Icons.person_outline,
                                    color: Colors.white70),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(30),
                                  borderSide: BorderSide(
                                      color: Colors.white.withOpacity(0.3)),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(30),
                                  borderSide: BorderSide(
                                      color: Colors.white.withOpacity(0.3)),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(30),
                                  borderSide: const BorderSide(
                                      color: Colors.blue),
                                ),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return localizations?.translate(
                                      'enter_username') ??
                                      'Please enter your username';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _passwordController,
                              obscureText: _obscurePassword,
                              style: const TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                hintText: localizations?.translate(
                                    'password_hint') ?? 'Password',
                                hintStyle: const TextStyle(
                                    color: Colors.white70),
                                prefixIcon: const Icon(
                                    Icons.lock_outline, color: Colors.white70),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscurePassword ? Icons.visibility : Icons
                                        .visibility_off,
                                    color: Colors.white70,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _obscurePassword = !_obscurePassword;
                                    });
                                  },
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(30),
                                  borderSide: BorderSide(
                                      color: Colors.white.withOpacity(0.3)),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(30),
                                  borderSide: BorderSide(
                                      color: Colors.white.withOpacity(0.3)),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(30),
                                  borderSide: const BorderSide(
                                      color: Colors.blue),
                                ),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return localizations?.translate(
                                      'enter_password') ??
                                      'bra';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.start,
                              children: [
                                Checkbox(
                                  value: _dontForgetMe,
                                  onChanged: (bool? value) {
                                    setState(() {
                                      _dontForgetMe = value ?? false;
                                    });
                                  },
                                  checkColor: Colors.white,
                                  activeColor: const Color(0xFFB8860B),
                                ),
                                Text(
                                  localizations?.translate('dont_forget_me') ??
                                      "Don't forget me",
                                  style: const TextStyle(color: Colors.white),
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),
                            SizedBox(
                              width: double.infinity,
                              height: 56,
                              child: ElevatedButton(
                                onPressed: _login,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFB8860B),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(30),
                                  ),
                                  elevation: 5,
                                ),
                                child: Text(
                                  localizations?.translate('sign_in') ??
                                      'Sign In',
                                  style: const TextStyle(fontSize: 18,
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
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