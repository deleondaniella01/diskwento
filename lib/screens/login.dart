import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
// Import for basic widgets
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:myapp/main.dart';
import 'package:myapp/screens/banks_page.dart';
import 'interests_page.dart'; // Import the new interests page
import 'package:shared_preferences/shared_preferences.dart';

// void main() async {
//   WidgetsFlutterBinding.ensureInitialized();
//   // Only initialize if not already initialized
//   if (Firebase.apps.isEmpty) {
//     await Firebase.initializeApp(
//       options: DefaultFirebaseOptions.currentPlatform,
//     );
//   }
//   runApp(const MyApp());
// }

// class MyApp extends StatelessWidget {
//   const MyApp({super.key});

//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       title: 'Dibs!',
//       theme: ThemeData(
//         primarySwatch: Colors.blue,
//         visualDensity: VisualDensity.adaptivePlatformDensity,
//       ),
//       home: AuthPage(
//         title: 'Dibs!',
//         analytics: FirebaseAnalytics.instance,
//         observer: FirebaseAnalyticsObserver(analytics: FirebaseAnalytics.instance),
//       ),
//     );
//   }
// }

class AuthPage extends StatefulWidget {
  const AuthPage({super.key,
    required this.title,
    required this.analytics,
    required this.observer,
  });

  final String title;
  final FirebaseAnalytics analytics;
  final FirebaseAnalyticsObserver observer;

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  bool isSignIn = true;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleGoogleSignIn() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        // The user canceled the sign-in flow
        return;
      }
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      await _auth.signInWithCredential(credential);
      // Navigate to the home page after successful sign-in
      _navigateToBankPage(); // <--- change here
    } catch (e) {
      print('Error signing in with Google: $e');
      // TODO: Show an error message to the user
    }
  }

  Future<void> _handleSignIn() async {
    try {
      await _auth.signInWithEmailAndPassword(
        email: _emailController.text,
        password: _passwordController.text,
      );
      final prefs = await SharedPreferences.getInstance();
      final interestsSet = prefs.getBool('interestsSet') ?? false;

      if (interestsSet) {
        // Go directly to HomePage
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => MyHomePage(
              title: 'Dibs',
              analytics: widget.analytics,
              observer: widget.observer,
            ),
          ),
        );
      } else {
        // Go to InterestsPage for first-time setup
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => InterestsPage(
              title: 'Dibs',
              analytics: widget.analytics,
              observer: widget.observer,
            ),
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') {
        print('No user found for that email.');
      } else if (e.code == 'wrong-password') {
        print('Wrong password provided for that user.');
      } else {
        print('Error signing in: ${e.message}');
      }
      // TODO: Show an appropriate error message to the user
    } catch (e) {
       ('Error signing in: $e');
      // TODO: Show an error message to the user
    }
  }

  // void _navigateToInterestsPage() {
  //    Navigator.pushReplacement(
  //       context,
  //       MaterialPageRoute(builder: (context) => const InterestsPage()),
  //     );
  // }

  void _navigateToBankPage() {
     Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => BanksPage(
          title: 'Dibs',
          analytics: widget.analytics,
          observer: widget.observer,
        )),
      );
  }

  // void _navigateToHomePage() {
  //   Navigator.pushReplacement(
  //     context,
  //     MaterialPageRoute(
  //       builder: (context) => MyHomePage(
  //         title: 'Dibs',
  //         analytics: widget.analytics,
  //         observer: widget.observer,
  //       ),
  //     ),
  //   );
  // }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFB3E5FC), // Light blue
              Color(0xFFE1F5FE), // Lighter blue
            ],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                const SizedBox(height: 50),
                // App Logo Placeholder
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check,
                    size: 50,
                    color: Colors.blueAccent,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Dibs!',
                  style: TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0277BD), // Darker blue
                  ),
                ),
                const SizedBox(height: 5),
                const Text(
                  'Your exclusive claim to best deals',
                  style: TextStyle(
                    fontSize: 16,
                    color: Color(0xFF039BE5), // Medium blue
                  ),
                ),
                const SizedBox(height: 40),
                Card(
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  elevation: 8,
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () {
                                  setState(() {
                                    isSignIn = true;
                                  });
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: isSignIn ? const Color(0xFF29B6F6) : Colors.grey[200],
                                  foregroundColor: isSignIn ? Colors.white : Colors.black87,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  padding: const EdgeInsets.symmetric(vertical: 15),
                                ),
                                child: const Text('Sign In'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () {
                                  setState(() {
                                    isSignIn = false;
                                  });
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: !isSignIn ? const Color(0xFF29B6F6) : Colors.grey[200],
                                  foregroundColor: !isSignIn ? Colors.white : Colors.black87,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  padding: const EdgeInsets.symmetric(vertical: 15),
                                ),
                                child: const Text('Sign Up'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        if (isSignIn) ...[
                          _buildSignInForm(),
                        ] else ...[
                          _buildSignUpForm(),
                        ],
                        const SizedBox(height: 20),
                        const Text(
                          'Or continue with',
                          style: TextStyle(color: Colors.grey),
                        ),
                        const SizedBox(height: 10),
                        OutlinedButton(
                          onPressed: _handleGoogleSignIn, // Call the Google Sign-In function
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            side: const BorderSide(color: Colors.grey),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Image.network(
                                'https://upload.wikimedia.org/wikipedia/commons/thumb/c/c1/Google_%22G%22_logo.svg/1200px-Google_%22G%22_logo.svg.png',
                                height: 24,
                              ),
                              const SizedBox(width: 10),
                              const Text(
                                'Continue with Google',
                                style: TextStyle(fontSize: 16),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 40),
                const Text(
                  '© 2024 Dibs! All rights reserved.',
                  style: TextStyle(color: Colors.black54),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSignInForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Text('Email'),
        const SizedBox(height: 8),
        TextField(
          controller: _emailController, // Use the email controller
          decoration: InputDecoration(
            hintText: 'Enter your email',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
            fillColor: Colors.grey[200],
            filled: true,
          ),
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 15),
        const Text('Password'),
        const SizedBox(height: 8),
        TextField(
          controller: _passwordController, // Use the password controller
          decoration: InputDecoration(
            hintText: 'Enter your password',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
            fillColor: Colors.grey[200],
            filled: true,
          ),
          obscureText: true,
        ),
        const SizedBox(height: 15),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Checkbox(value: false, onChanged: (bool? value) {}),
                const Text('Remember me'),
              ],
            ),
            TextButton(
              onPressed: () {
                // TODO: Implement Forgot Password
              },
              child: const Text('Forgot password?'),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Center(
          child: ElevatedButton(
            onPressed: _handleSignIn, // Call the sign-in function
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF29B6F6),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 80, vertical: 15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Sign In'),
          ),
        ),
      ],
    );
  }

  Widget _buildSignUpForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Text('Full Name'),
        const SizedBox(height: 8),
        TextField(
          decoration: InputDecoration(
            hintText: 'Enter your full name',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
            fillColor: Colors.grey[200],
            filled: true,
          ),
          keyboardType: TextInputType.name,
        ),
        const SizedBox(height: 15),
        const Text('Email'),
        const SizedBox(height: 8),
        TextField(
          decoration: InputDecoration(
            hintText: 'Enter your email',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
            fillColor: Colors.grey[200],
            filled: true,
          ),
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 15),
        const Text('Password'),
        const SizedBox(height: 8),
        TextField(
          decoration: InputDecoration(
            hintText: 'Create a password',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
            fillColor: Colors.grey[200],
            filled: true,
          ),
          obscureText: true,
        ),
        const SizedBox(height: 15),
        const Text('Confirm Password'),
        const SizedBox(height: 8),
        TextField(
          decoration: InputDecoration(
            hintText: 'Confirm your password',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
            fillColor: Colors.grey[200],
            filled: true,
          ),
          obscureText: true,
        ),
        const SizedBox(height: 15),
        Row(
          children: [
            Checkbox(value: false, onChanged: (bool? value) {}),
            const Expanded(
              child: Text('I agree to the Terms & Conditions'),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Center(
          child: ElevatedButton(
            onPressed: () {
              // TODO: Implement Sign Up
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF8BC34A), // Green color
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 80, vertical: 15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Create Account'),
          ),
        ),
      ],
    );
  }
}