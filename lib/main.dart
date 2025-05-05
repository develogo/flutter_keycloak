import 'package:flutter/material.dart';
import 'package:teste/auth_service.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Keycloak',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Flutter Keycloak'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final AuthService authService = AuthService();
  Map<String, dynamic>? userInfo;
  bool isLoading = false;

  Future<void> _handleLogin() async {
    setState(() => isLoading = true);
    final success = await authService.authenticate();
    if (success) {
      try {
        final info = await authService.getUserInfo();
        setState(() {
          userInfo = info;
          isLoading = false;
        });
      } catch (e) {
        setState(() => isLoading = false);
        print('Error fetching user information: $e');
      }
    } else {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            if (isLoading)
              const CircularProgressIndicator()
            else if (userInfo != null)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Text('Username: ${userInfo!['preferred_username']}'),
                    Text('Email: ${userInfo!['email']}'),
                    Text('ID: ${userInfo!['sub']}'),
                    Text('Email verified: ${userInfo!['email_verified']}'),
                  ],
                ),
              ),
            ElevatedButton(
              onPressed: _handleLogin,
              child: const Text('Login'),
            ),
            ElevatedButton(
              onPressed: () {
                authService.logout();
                setState(() => userInfo = null);
              },
              child: const Text('Logout'),
            ),
          ],
        ),
      ),
    );
  }
}
