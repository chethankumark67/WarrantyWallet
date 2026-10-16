import 'package:flutter/material.dart';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'firebase_options.dart'; // The generated options file

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const WarrantyWalletApp());
}

// ============================================================
// THEME
// ============================================================

const bg = Color(0xFF101214);
const surface = Color(0xFF181B1F);
const surface2 = Color(0xFF20242A);
const surface3 = Color(0xFF282D34);

const textPrimary = Color(0xFFE8E9EA);
const textSecondary = Color(0xFF8E969F);

const green = Color(0xFF91A88A);
const orange = Color(0xFFC59B62);
const red = Color(0xFFB86F6F);
const blueGrey = Color(0xFF8194A8);

// ============================================================
// APP
// ============================================================

class WarrantyWalletApp extends StatelessWidget {
  const WarrantyWalletApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Warranty Wallet',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: bg,
        colorScheme: const ColorScheme.dark(primary: green, surface: surface),
        inputDecorationTheme: const InputDecorationTheme(
          filled: true,
          fillColor: surface2,
          labelStyle: TextStyle(color: textSecondary),
          hintStyle: TextStyle(color: textSecondary),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(16)),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(16)),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(16)),
            borderSide: BorderSide(color: green),
          ),
        ),
      ),
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.userChanges(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Could not check your sign-in status: ${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        return snapshot.data == null ? const AuthPage() : const MainPage();
      },
    );
  }
}

String _userDisplayName(User? user) {
  final displayName = user?.displayName?.trim();
  if (displayName != null && displayName.isNotEmpty) return displayName;
  final email = user?.email;
  final emailName = email?.split('@').first;
  return emailName == null || emailName.isEmpty ? 'there' : emailName;
}

String _userInitials(String name) {
  final parts = name.trim().split(RegExp(r'\s+'));
  if (parts.first.isEmpty) return '?';
  if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
  return '${parts.first.substring(0, 1)}${parts.last.substring(0, 1)}'
      .toUpperCase();
}

String _safeFileExtension(String? name, {required String fallback}) {
  final fileName = name?.trim() ?? '';
  final separatorIndex = fileName.lastIndexOf('.');
  final extension = separatorIndex < 0
      ? null
      : fileName.substring(separatorIndex + 1).toLowerCase();
  if (extension == null || !RegExp(r'^[a-z0-9]{1,10}$').hasMatch(extension)) {
    return fallback;
  }
  return extension;
}

// ============================================================
// DATA MODEL
// ============================================================

class Product {
  final String id;
  final String name;
  final String brand;
  final String category;
  final String serial;
  final DateTime purchaseDate;
  final DateTime expiryDate;
  final String warranty;
  final String price;
  final String? imageUrl;
  final String? warrantyDocumentUrl;
  final String? warrantyDocumentName;

  const Product({
    required this.id,
    required this.name,
    required this.brand,
    required this.category,
    required this.serial,
    required this.purchaseDate,
    required this.expiryDate,
    required this.warranty,
    required this.price,
    this.imageUrl,
    this.warrantyDocumentUrl,
    this.warrantyDocumentName,
  });

  factory Product.fromDocument(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data();
    return Product(
      id: document.id,
      name: data['name'] as String? ?? 'Product',
      brand: data['brand'] as String? ?? '',
      category: data['category'] as String? ?? 'Other',
      serial: data['serial'] as String? ?? '',
      purchaseDate: (data['purchaseDate'] as Timestamp).toDate(),
      expiryDate: (data['expiryDate'] as Timestamp).toDate(),
      warranty: data['warranty'] as String? ?? '',
      price: data['price'] as String? ?? '',
      imageUrl: data['imageUrl'] as String?,
      warrantyDocumentUrl: data['warrantyDocumentUrl'] as String?,
      warrantyDocumentName: data['warrantyDocumentName'] as String?,
    );
  }

  String get status {
    final now = DateTime.now();

    if (expiryDate.isBefore(now)) {
      return 'Expired';
    }

    final daysLeft = expiryDate.difference(now).inDays;

    if (daysLeft <= 90) {
      return 'Expiring';
    }

    return 'Active';
  }

  IconData get icon => switch (category) {
    'Mobile' => Icons.phone_android,
    'Laptop' => Icons.laptop,
    'Audio' => Icons.headphones,
    'Appliance' => Icons.home,
    'Vehicle' => Icons.directions_car,
    _ => Icons.inventory_2,
  };
}

CollectionReference<Map<String, dynamic>>? get _userProductsCollection {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return null;
  return FirebaseFirestore.instance
      .collection('users')
      .doc(user.uid)
      .collection('products');
}

class UserProductsBuilder extends StatelessWidget {
  final Widget Function(BuildContext context, List<Product> products) builder;

  const UserProductsBuilder({super.key, required this.builder});

  @override
  Widget build(BuildContext context) {
    final collection = _userProductsCollection;
    if (collection == null) {
      return const Center(child: Text('Sign in to view your wallet.'));
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: collection.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Could not load your wallet: ${snapshot.error}',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final products = snapshot.data!.docs.map(Product.fromDocument).toList()
          ..sort((a, b) => b.purchaseDate.compareTo(a.purchaseDate));
        return builder(context, products);
      },
    );
  }
}

String formatDate(DateTime date) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  return '${date.day} ${months[date.month - 1]} ${date.year}';
}

DateTime calculateExpiry(DateTime purchaseDate, String warranty) {
  switch (warranty) {
    case '6 Months':
      return DateTime(
        purchaseDate.year,
        purchaseDate.month + 6,
        purchaseDate.day,
      );

    case '1 Year':
      return DateTime(
        purchaseDate.year + 1,
        purchaseDate.month,
        purchaseDate.day,
      );

    case '2 Years':
      return DateTime(
        purchaseDate.year + 2,
        purchaseDate.month,
        purchaseDate.day,
      );

    case '3 Years':
      return DateTime(
        purchaseDate.year + 3,
        purchaseDate.month,
        purchaseDate.day,
      );

    case '5 Years':
      return DateTime(
        purchaseDate.year + 5,
        purchaseDate.month,
        purchaseDate.day,
      );

    default:
      return DateTime(
        purchaseDate.year + 1,
        purchaseDate.month,
        purchaseDate.day,
      );
  }
}

// ============================================================
// AUTHENTICATION
// ============================================================

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLogin = true;
  bool _isLoading = false;
  String? _errorMessage;
  late final Future<void> _googleSignInInitialization = GoogleSignIn.instance
      .initialize();

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      if (_isLogin) {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
      } else {
        final credential = await FirebaseAuth.instance
            .createUserWithEmailAndPassword(
              email: _emailController.text.trim(),
              password: _passwordController.text,
            );
        await credential.user?.updateDisplayName(_nameController.text.trim());
      }
    } on FirebaseAuthException catch (error) {
      if (mounted) {
        setState(() {
          _errorMessage = switch (error.code) {
            'email-already-in-use' =>
              'An account already exists for this email.',
            'invalid-email' => 'Enter a valid email address.',
            'user-disabled' => 'This account has been disabled.',
            'operation-not-allowed' =>
              'Email/password sign-in is not enabled for this Firebase project.',
            'user-not-found' ||
            'wrong-password' ||
            'invalid-credential' => 'The email or password is incorrect.',
            'weak-password' => 'Choose a stronger password.',
            'too-many-requests' => 'Too many attempts. Please try again later.',
            'network-request-failed' =>
              'Network error. Check your connection and try again.',
            _ => error.message ?? 'Authentication failed. Please try again.',
          };
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      if (kIsWeb) {
        await FirebaseAuth.instance.signInWithPopup(GoogleAuthProvider());
      } else {
        final supportsGoogleSignIn =
            defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS ||
            defaultTargetPlatform == TargetPlatform.macOS;
        if (!supportsGoogleSignIn) {
          setState(() {
            _errorMessage = 'Google sign-in is not available on this platform.';
          });
          return;
        }

        await _googleSignInInitialization;
        final account = await GoogleSignIn.instance.authenticate();
        final idToken = account.authentication.idToken;
        if (idToken == null) {
          setState(() {
            _errorMessage =
                'Google did not provide an ID token. Check your OAuth configuration.';
          });
          return;
        }

        await FirebaseAuth.instance.signInWithCredential(
          GoogleAuthProvider.credential(idToken: idToken),
        );
      }
    } on GoogleSignInException catch (error) {
      if (mounted && error.code != GoogleSignInExceptionCode.canceled) {
        setState(() {
          _errorMessage =
              error.description ??
              'Google sign-in failed. Check your Google OAuth configuration.';
        });
      }
    } on FirebaseAuthException catch (error) {
      if (mounted) {
        setState(() {
          _errorMessage = switch (error.code) {
            'account-exists-with-different-credential' =>
              'An account already exists with this email using another sign-in method.',
            'operation-not-allowed' =>
              'Google sign-in is not enabled in Firebase Authentication.',
            'popup-blocked' =>
              'The sign-in popup was blocked. Allow popups and try again.',
            'popup-closed-by-user' => null,
            'network-request-failed' =>
              'Network error. Check your connection and try again.',
            _ => error.message ?? 'Google sign-in failed. Please try again.',
          };
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(25),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 75,
                      height: 75,
                      decoration: BoxDecoration(
                        color: surface2,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: const Icon(
                        Icons.account_balance_wallet_outlined,
                        size: 38,
                        color: green,
                      ),
                    ),
                  ),
                  const SizedBox(height: 25),
                  const Text(
                    'WARRANTY\nWALLET',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 32,
                      height: .95,
                      letterSpacing: 3,
                      fontWeight: FontWeight.w800,
                      color: textPrimary,
                    ),
                  ),
                  const SizedBox(height: 15),
                  Text(
                    _isLogin
                        ? 'Sign in to access your wallet.'
                        : 'Create an account to get started.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: textSecondary, fontSize: 15),
                  ),
                  const SizedBox(height: 35),
                  if (!_isLogin) ...[
                    TextFormField(
                      key: const Key('nameField'),
                      controller: _nameController,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.person_outline),
                        labelText: 'Name',
                      ),
                      validator: (value) {
                        if (!_isLogin && (value?.trim().isEmpty ?? true)) {
                          return 'Enter your name.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 15),
                  ],
                  TextFormField(
                    key: const Key('emailField'),
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.mail_outline),
                      labelText: 'Email address',
                    ),
                    validator: (value) {
                      final email = value?.trim() ?? '';
                      if (email.isEmpty || !email.contains('@')) {
                        return 'Enter a valid email address.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 15),
                  TextFormField(
                    key: const Key('passwordField'),
                    controller: _passwordController,
                    obscureText: true,
                    autofillHints: [
                      _isLogin
                          ? AutofillHints.password
                          : AutofillHints.newPassword,
                    ],
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.lock_outline),
                      labelText: 'Password',
                    ),
                    validator: (value) {
                      final password = value ?? '';
                      if (password.isEmpty) {
                        return 'Enter your password.';
                      }
                      if (!_isLogin && password.length < 6) {
                        return 'Password must be at least 6 characters.';
                      }
                      return null;
                    },
                  ),
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 15),
                    Text(
                      _errorMessage!,
                      key: const Key('authError'),
                      style: const TextStyle(color: red),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  const SizedBox(height: 24),
                  SizedBox(
                    height: 56,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: green,
                        foregroundColor: bg,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(17),
                        ),
                      ),
                      onPressed: _isLoading ? null : _submit,
                      child: _isLoading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: bg,
                              ),
                            )
                          : Text(
                              _isLogin ? 'Sign in' : 'Create account',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Row(
                    children: [
                      Expanded(child: Divider(color: surface3)),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 14),
                        child: Text(
                          'OR',
                          style: TextStyle(
                            color: textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Expanded(child: Divider(color: surface3)),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    height: 54,
                    child: OutlinedButton(
                      key: const Key('googleSignInButton'),
                      onPressed: _isLoading ? null : _signInWithGoogle,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: textPrimary,
                        side: const BorderSide(color: surface3),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(17),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 21,
                              height: 21,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: green,
                              ),
                            )
                          : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'G',
                                  style: TextStyle(
                                    color: Color(0xFF4285F4),
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                SizedBox(width: 12),
                                Text('Continue with Google'),
                              ],
                            ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: _isLoading
                        ? null
                        : () {
                            setState(() {
                              _isLogin = !_isLogin;
                              _errorMessage = null;
                              _formKey.currentState?.reset();
                            });
                          },
                    child: Text(
                      _isLogin
                          ? 'New here? Create an account'
                          : 'Already have an account? Sign in',
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

// ============================================================
// MAIN
// ============================================================

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int page = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      const DashboardPage(),
      const ProductsPage(),
      const RemindersPage(),
      const ProfilePage(),
    ];

    return Scaffold(
      body: pages[page],

      floatingActionButton: page == 1
          ? FloatingActionButton.extended(
              backgroundColor: green,
              foregroundColor: bg,
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AddProductPage()),
                );

                setState(() {});
              },
              icon: const Icon(Icons.add),
              label: const Text('Add'),
            )
          : null,

      bottomNavigationBar: NavigationBar(
        backgroundColor: surface,
        indicatorColor: surface3,
        selectedIndex: page,
        onDestinationSelected: (value) {
          setState(() {
            page = value;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.inventory_2_outlined),
            selectedIcon: Icon(Icons.inventory_2),
            label: 'Wallet',
          ),
          NavigationDestination(
            icon: Icon(Icons.notifications_none),
            selectedIcon: Icon(Icons.notifications),
            label: 'Alerts',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Me',
          ),
        ],
      ),
    );
  }
}

// ============================================================
// DASHBOARD
// ============================================================

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return UserProductsBuilder(
      builder: (context, products) {
        final active = products.where((p) => p.status == 'Active').length;
        final expiring = products.where((p) => p.status == 'Expiring').length;
        final expired = products.where((p) => p.status == 'Expired').length;
        final user = FirebaseAuth.instance.currentUser;
        final displayName = _userDisplayName(user);

        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 25, 20, 30),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'GOOD EVENING,',
                            style: TextStyle(
                              color: textSecondary,
                              fontSize: 12,
                              letterSpacing: 2,
                            ),
                          ),
                          SizedBox(height: 5),
                          Text(
                            '$displayName.',
                            style: const TextStyle(
                              fontSize: 31,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: surface2,
                      child: Text(
                        _userInitials(displayName),
                        style: const TextStyle(
                          color: green,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 28),

                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: surface,
                    borderRadius: BorderRadius.circular(25),
                    border: Border.all(color: surface3),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.shield_outlined, color: green),
                          SizedBox(width: 10),
                          Text(
                            'YOUR WALLET',
                            style: TextStyle(
                              color: textSecondary,
                              letterSpacing: 1.5,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${products.length}',
                            style: const TextStyle(
                              fontSize: 54,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const Padding(
                            padding: EdgeInsets.only(bottom: 9, left: 10),
                            child: Text(
                              'products protected',
                              style: TextStyle(color: textSecondary),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 18),

                      Row(
                        children: [
                          miniStat('$active', 'Active', green),
                          miniStat('$expiring', 'Expiring', orange),
                          miniStat('$expired', 'Expired', red),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 30),

                if (products.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(26),
                    decoration: BoxDecoration(
                      color: surface,
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.inventory_2_outlined,
                          color: green,
                          size: 42,
                        ),
                        const SizedBox(height: 14),
                        const Text(
                          'Your wallet is empty',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Add a product you own to keep its warranty and documents in one place.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: textSecondary),
                        ),
                        const SizedBox(height: 18),
                        FilledButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const AddProductPage(),
                              ),
                            );
                          },
                          icon: const Icon(Icons.add),
                          label: const Text('Add your first product'),
                        ),
                      ],
                    ),
                  )
                else ...[
                  const Text(
                    'NEEDS YOUR ATTENTION',
                    style: TextStyle(
                      color: textSecondary,
                      fontSize: 12,
                      letterSpacing: 1.8,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...products
                      .where(
                        (p) => p.status == 'Expiring' || p.status == 'Expired',
                      )
                      .map((p) => attentionCard(context, p)),
                  const SizedBox(height: 25),
                  const Text(
                    'YOUR WALLET',
                    style: TextStyle(
                      color: textSecondary,
                      fontSize: 12,
                      letterSpacing: 1.8,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...products.map((p) => productCard(context, p)),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget miniStat(String number, String label, Color color) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            number,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: const TextStyle(color: textSecondary, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget attentionCard(BuildContext context, Product p) {
    final color = p.status == 'Expired' ? red : orange;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ProductDetailsPage(product: p)),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(17),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(19),
          border: Border.all(color: color.withOpacity(.35)),
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: color.withOpacity(.12),
              child: Icon(
                p.status == 'Expired' ? Icons.close : Icons.priority_high,
                color: color,
              ),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    p.name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    p.status == 'Expired'
                        ? 'Warranty expired'
                        : 'Warranty ends ${formatDate(p.expiryDate)}',
                    style: const TextStyle(color: textSecondary, fontSize: 12),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: color),
          ],
        ),
      ),
    );
  }

  Widget productCard(BuildContext context, Product p) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ProductDetailsPage(product: p)),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(19),
        ),
        child: Row(
          children: [
            Container(
              height: 52,
              width: 52,
              decoration: BoxDecoration(
                color: surface2,
                borderRadius: BorderRadius.circular(15),
              ),
              clipBehavior: Clip.antiAlias,
              child: p.imageUrl == null
                  ? Icon(p.icon, color: textPrimary)
                  : Image.network(
                      p.imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) =>
                          Icon(p.icon, color: textPrimary),
                    ),
            ),

            const SizedBox(width: 14),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    p.name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${p.brand} • ${p.category}',
                    style: const TextStyle(color: textSecondary, fontSize: 12),
                  ),
                ],
              ),
            ),

            statusBadge(p.status),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// PRODUCTS
// ============================================================

class ProductsPage extends StatefulWidget {
  const ProductsPage({super.key});

  @override
  State<ProductsPage> createState() => _ProductsPageState();
}

class _ProductsPageState extends State<ProductsPage> {
  String filter = 'All';
  String search = '';

  @override
  Widget build(BuildContext context) {
    return UserProductsBuilder(
      builder: (context, products) {
        final filtered = products.where((p) {
          final query = search.toLowerCase();
          final matchesSearch =
              p.name.toLowerCase().contains(query) ||
              p.brand.toLowerCase().contains(query) ||
              p.category.toLowerCase().contains(query);
          final matchesFilter = filter == 'All' || p.status == filter;
          return matchesSearch && matchesFilter;
        }).toList();

        return SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 25, 20, 15),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'My Wallet',
                        style: TextStyle(
                          fontSize: 29,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    IconButton(onPressed: () {}, icon: const Icon(Icons.tune)),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: TextField(
                  onChanged: (value) {
                    setState(() {
                      search = value;
                    });
                  },
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Find something...',
                  ),
                ),
              ),

              const SizedBox(height: 13),

              SizedBox(
                height: 42,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  children: [
                    chip('All'),
                    chip('Active'),
                    chip('Expiring'),
                    chip('Expired'),
                  ],
                ),
              ),

              const SizedBox(height: 10),

              Expanded(
                child: filtered.isEmpty
                    ? Center(
                        child: Text(
                          products.isEmpty
                              ? 'Your wallet is empty. Add a product to get started.'
                              : 'No products match your search or filter.',
                          style: const TextStyle(color: textSecondary),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(20, 5, 20, 100),
                        itemCount: filtered.length,
                        itemBuilder: (_, index) {
                          return productCard(context, filtered[index]);
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget chip(String title) {
    return Padding(
      padding: const EdgeInsets.only(right: 7),
      child: ChoiceChip(
        label: Text(title),
        selected: filter == title,
        selectedColor: green,
        backgroundColor: surface2,
        labelStyle: TextStyle(
          color: filter == title ? bg : textSecondary,
          fontWeight: FontWeight.bold,
        ),
        onSelected: (_) {
          setState(() {
            filter = title;
          });
        },
      ),
    );
  }

  Widget productCard(BuildContext context, Product p) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ProductDetailsPage(product: p)),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 11),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(19),
        ),
        child: Row(
          children: [
            Container(
              height: 55,
              width: 55,
              decoration: BoxDecoration(
                color: surface2,
                borderRadius: BorderRadius.circular(15),
              ),
              clipBehavior: Clip.antiAlias,
              child: p.imageUrl == null
                  ? Icon(p.icon, color: textPrimary)
                  : Image.network(
                      p.imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) =>
                          Icon(p.icon, color: textPrimary),
                    ),
            ),

            const SizedBox(width: 14),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    p.name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${p.brand} • ${p.category}',
                    style: const TextStyle(color: textSecondary, fontSize: 12),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'Until ${formatDate(p.expiryDate)}',
                    style: const TextStyle(color: textSecondary, fontSize: 11),
                  ),
                ],
              ),
            ),

            statusBadge(p.status),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// ADD PRODUCT
// ============================================================

class AddProductPage extends StatefulWidget {
  const AddProductPage({super.key});

  @override
  State<AddProductPage> createState() => _AddProductPageState();
}

class _AddProductPageState extends State<AddProductPage> {
  int step = 0;

  String category = '';
  String warranty = '1 Year';

  DateTime? purchaseDate;

  final nameController = TextEditingController();
  final brandController = TextEditingController();
  final serialController = TextEditingController();
  final priceController = TextEditingController();
  Uint8List? _productImageBytes;
  String? _productImageName;
  Uint8List? _warrantySheetBytes;
  String? _warrantySheetName;
  bool _isSaving = false;

  @override
  void dispose() {
    nameController.dispose();
    brandController.dispose();
    serialController.dispose();
    priceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: bg,
        title: Text(
          'Add Product ${step + 1}/3',
          style: const TextStyle(fontSize: 15),
        ),
      ),

      body: Column(
        children: [
          LinearProgressIndicator(
            value: (step + 1) / 3,
            minHeight: 3,
            color: green,
            backgroundColor: surface2,
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(22),
              child: step == 0
                  ? chooseCategory()
                  : step == 1
                  ? productInformation()
                  : documents(),
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: green,
                      foregroundColor: bg,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(17),
                      ),
                    ),
                    onPressed: _isSaving
                        ? null
                        : () {
                            if (step == 0 && category.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Please select a category.'),
                                ),
                              );
                              return;
                            }

                            if (step == 1 &&
                                nameController.text.trim().isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Please enter a product name.'),
                                ),
                              );
                              return;
                            }

                            if (step < 2) {
                              setState(() {
                                step++;
                              });
                            } else {
                              saveProduct();
                            }
                          },
                    child: _isSaving
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: bg,
                            ),
                          )
                        : Text(step == 2 ? 'Save to Wallet' : 'Continue  →'),
                  ),
                ),
                if (step == 2)
                  TextButton(
                    onPressed: _isSaving
                        ? null
                        : () => saveProduct(skipUploads: true),
                    child: const Text('Skip photos and warranty sheet'),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget chooseCategory() {
    final categories = [
      ['Mobile', Icons.phone_android],
      ['Laptop', Icons.laptop],
      ['Audio', Icons.headphones],
      ['Appliance', Icons.home],
      ['Vehicle', Icons.directions_car],
      ['Other', Icons.category],
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),

        const Text(
          'What are we\nprotecting?',
          style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800),
        ),

        const SizedBox(height: 10),

        const Text(
          'Pick a category. You can add the details next.',
          style: TextStyle(color: textSecondary),
        ),

        const SizedBox(height: 30),

        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.35,
          ),
          itemCount: categories.length,
          itemBuilder: (_, index) {
            final selected = category == categories[index][0];

            return GestureDetector(
              onTap: () {
                setState(() {
                  category = categories[index][0] as String;
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  color: selected ? green.withOpacity(.15) : surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: selected ? green : surface3,
                    width: selected ? 1.5 : 1,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      categories[index][1] as IconData,
                      size: 32,
                      color: selected ? green : textSecondary,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      categories[index][0] as String,
                      style: TextStyle(
                        color: selected ? green : textPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget productInformation() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),

        const Text(
          'Tell us about it.',
          style: TextStyle(fontSize: 31, fontWeight: FontWeight.w800),
        ),

        const SizedBox(height: 8),

        const Text(
          'Just the basics. We’ll handle the rest.',
          style: TextStyle(color: textSecondary),
        ),

        const SizedBox(height: 30),

        field(nameController, 'Product name', Icons.inventory_2_outlined),

        field(brandController, 'Brand', Icons.business_outlined),

        field(serialController, 'Serial number', Icons.qr_code_2),

        field(priceController, 'Purchase price', Icons.currency_rupee),

        const SizedBox(height: 10),

        const Text(
          'Warranty period',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),

        const SizedBox(height: 12),

        Wrap(
          spacing: 8,
          children: [
            warrantyChip('6 Months'),
            warrantyChip('1 Year'),
            warrantyChip('2 Years'),
            warrantyChip('3 Years'),
            warrantyChip('5 Years'),
          ],
        ),

        const SizedBox(height: 25),

        const Text(
          'Purchase date',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),

        const SizedBox(height: 10),

        GestureDetector(
          onTap: selectPurchaseDate,
          child: Container(
            padding: const EdgeInsets.all(17),
            decoration: BoxDecoration(
              color: surface2,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                const Icon(Icons.calendar_today_outlined, color: green),
                const SizedBox(width: 13),
                Text(
                  purchaseDate == null
                      ? 'Choose purchase date'
                      : formatDate(purchaseDate!),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> selectPurchaseDate() async {
    final selected = await showDatePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2035),
      initialDate: purchaseDate ?? DateTime.now(),
    );

    if (selected != null) {
      setState(() {
        purchaseDate = selected;
      });
    }
  }

  Widget documents() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),

        const Text(
          'Almost done.',
          style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800),
        ),

        const SizedBox(height: 8),

        const Text(
          'Add proof of purchase so you never have to hunt for it.',
          style: TextStyle(color: textSecondary),
        ),

        const SizedBox(height: 35),

        if (_productImageBytes != null) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Image.memory(
              _productImageBytes!,
              height: 190,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(height: 12),
        ],
        uploadBox(
          Icons.camera_alt_outlined,
          'Product photo',
          _productImageName ?? 'Optional · JPG or PNG',
          _pickProductImage,
        ),
        uploadBox(
          Icons.description_outlined,
          'Warranty sheet',
          _warrantySheetName ?? 'Optional · PDF, JPG or PNG',
          _pickWarrantySheet,
        ),

        const SizedBox(height: 25),

        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: green.withOpacity(.08),
            borderRadius: BorderRadius.circular(18),
          ),
          child: const Row(
            children: [
              Icon(Icons.auto_awesome, color: green),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Your product details and uploaded files are private to your account.',
                  style: TextStyle(color: textSecondary, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget field(TextEditingController controller, String hint, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 13),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(prefixIcon: Icon(icon), hintText: hint),
      ),
    );
  }

  Widget warrantyChip(String value) {
    final selected = warranty == value;

    return ChoiceChip(
      label: Text(value),
      selected: selected,
      selectedColor: green,
      backgroundColor: surface2,
      labelStyle: TextStyle(
        color: selected ? bg : textSecondary,
        fontWeight: FontWeight.bold,
      ),
      onSelected: (_) {
        setState(() {
          warranty = value;
        });
      },
    );
  }

  Widget uploadBox(
    IconData icon,
    String title,
    String subtitle,
    VoidCallback onPick,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 13),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(19),
        border: Border.all(color: surface3),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: surface2,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, color: green),
          ),

          const SizedBox(width: 13),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(color: textSecondary, fontSize: 11),
                ),
              ],
            ),
          ),

          OutlinedButton(
            onPressed: _isSaving ? null : onPick,
            child: Text(subtitle.startsWith('Optional') ? 'Choose' : 'Change'),
          ),
        ],
      ),
    );
  }

  Future<void> _pickProductImage() async {
    try {
      final image = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1800,
      );
      if (image == null) return;
      final bytes = await image.readAsBytes();
      if (bytes.length >= 15 * 1024 * 1024) {
        _showError('Choose a product photo smaller than 15 MB.');
        return;
      }
      if (!mounted) return;
      setState(() {
        _productImageBytes = bytes;
        _productImageName = image.name;
      });
    } on FirebaseException catch (error) {
      _showError('Could not select the product image: ${error.message}');
    } catch (error) {
      _showError('Could not select the product image: $error');
    }
  }

  Future<void> _pickWarrantySheet() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
      );
      if (result.isEmpty) return;
      final file = result.single;
      final bytes = await file.readAsBytes();
      if (bytes.length >= 15 * 1024 * 1024) {
        _showError('Choose a warranty sheet smaller than 15 MB.');
        return;
      }
      if (!mounted) return;
      setState(() {
        _warrantySheetBytes = bytes;
        _warrantySheetName = file.name;
      });
    } on FirebaseException catch (error) {
      _showError('Could not select the warranty sheet: ${error.message}');
    } catch (error) {
      _showError('Could not select the warranty sheet: $error');
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> saveProduct({bool skipUploads = false}) async {
    final collection = _userProductsCollection;
    if (collection == null) {
      _showError('Please sign in again before saving a product.');
      return;
    }

    setState(() {
      _isSaving = true;
    });

    final date = purchaseDate ?? DateTime.now();
    final expiry = calculateExpiry(date, warranty);
    final productDocument = collection.doc();
    final storage = FirebaseStorage.instance;
    final uploadedFiles = <Reference>[];

    try {
      String? imageUrl;
      String? warrantyDocumentUrl;

      if (!skipUploads && _productImageBytes != null) {
        final extension = _safeFileExtension(
          _productImageName,
          fallback: 'jpg',
        );
        final contentType = switch (extension) {
          'png' => 'image/png',
          'webp' => 'image/webp',
          'heic' => 'image/heic',
          'heif' => 'image/heif',
          'gif' => 'image/gif',
          _ => 'image/jpeg',
        };
        final imageRef = storage.ref(
          'users/${FirebaseAuth.instance.currentUser!.uid}/products/'
          '${productDocument.id}/product_image.$extension',
        );
        await imageRef.putData(
          _productImageBytes!,
          SettableMetadata(contentType: contentType),
        );
        uploadedFiles.add(imageRef);
        imageUrl = await imageRef.getDownloadURL();
      }

      if (!skipUploads &&
          _warrantySheetBytes != null &&
          _warrantySheetName != null) {
        final extension = _safeFileExtension(
          _warrantySheetName,
          fallback: 'pdf',
        );
        final contentType = switch (extension) {
          'pdf' => 'application/pdf',
          'png' => 'image/png',
          _ => 'image/jpeg',
        };
        final documentRef = storage.ref(
          'users/${FirebaseAuth.instance.currentUser!.uid}/products/'
          '${productDocument.id}/warranty_sheet.$extension',
        );
        await documentRef.putData(
          _warrantySheetBytes!,
          SettableMetadata(contentType: contentType),
        );
        uploadedFiles.add(documentRef);
        warrantyDocumentUrl = await documentRef.getDownloadURL();
      }

      await productDocument.set({
        'name': nameController.text.trim(),
        'brand': brandController.text.trim(),
        'category': category,
        'serial': serialController.text.trim(),
        'purchaseDate': Timestamp.fromDate(date),
        'expiryDate': Timestamp.fromDate(expiry),
        'warranty': warranty,
        'price': priceController.text.trim().isEmpty
            ? ''
            : '₹${priceController.text.trim()}',
        'imageUrl': imageUrl,
        'warrantyDocumentUrl': warrantyDocumentUrl,
        'warrantyDocumentName': skipUploads ? null : _warrantySheetName,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      Navigator.pop(context);
    } on FirebaseException catch (error) {
      final cleanupFailures = <String>[];
      for (final file in uploadedFiles) {
        try {
          await file.delete();
        } on FirebaseException catch (cleanupError) {
          cleanupFailures.add(cleanupError.message ?? cleanupError.code);
        }
      }
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
        _showError(
          'Could not save product: ${error.message ?? error.code}'
          '${cleanupFailures.isEmpty ? '' : ' Some uploaded files could not be removed.'}',
        );
      }
    } catch (error) {
      final cleanupFailed = <String>[];
      for (final file in uploadedFiles) {
        try {
          await file.delete();
        } on FirebaseException catch (cleanupError) {
          cleanupFailed.add(cleanupError.message ?? cleanupError.code);
        }
      }
      _showError(
        'Could not save product: $error'
        '${cleanupFailed.isEmpty ? '' : ' Some uploaded files could not be removed.'}',
      );
    } finally {
      if (mounted && _isSaving) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }
}

// ============================================================
// PRODUCT DETAILS
// ============================================================

class ProductDetailsPage extends StatelessWidget {
  final Product product;

  const ProductDetailsPage({super.key, required this.product});

  @override
  Widget build(BuildContext context) {
    final statusColor = product.status == 'Active'
        ? green
        : product.status == 'Expiring'
        ? orange
        : red;

    final daysLeft = product.expiryDate.difference(DateTime.now()).inDays;

    return Scaffold(
      appBar: AppBar(title: const Text('Product'), backgroundColor: bg),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(25),
              decoration: BoxDecoration(
                color: surface,
                borderRadius: BorderRadius.circular(25),
              ),
              child: Column(
                children: [
                  Container(
                    height: 85,
                    width: 85,
                    decoration: BoxDecoration(
                      color: surface2,
                      borderRadius: BorderRadius.circular(25),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: product.imageUrl == null
                        ? Icon(product.icon, size: 42, color: green)
                        : Image.network(
                            product.imageUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) =>
                                Icon(product.icon, size: 42, color: green),
                          ),
                  ),

                  const SizedBox(height: 18),

                  Text(
                    product.name,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 25,
                      fontWeight: FontWeight.w800,
                    ),
                  ),

                  Text(
                    '${product.brand} • ${product.category}',
                    style: const TextStyle(color: textSecondary),
                  ),

                  const SizedBox(height: 20),

                  statusBadge(product.status),
                ],
              ),
            ),

            const SizedBox(height: 14),

            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: surface,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'WARRANTY',
                    style: TextStyle(
                      color: textSecondary,
                      fontSize: 11,
                      letterSpacing: 2,
                    ),
                  ),

                  const SizedBox(height: 10),

                  Text(
                    product.status == 'Expired'
                        ? 'Expired'
                        : '$daysLeft days left',
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                    ),
                  ),

                  const SizedBox(height: 15),

                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: LinearProgressIndicator(
                      value: warrantyProgress(),
                      minHeight: 9,
                      color: statusColor,
                      backgroundColor: surface3,
                    ),
                  ),

                  const SizedBox(height: 12),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        formatDate(product.purchaseDate),
                        style: const TextStyle(
                          color: textSecondary,
                          fontSize: 11,
                        ),
                      ),
                      Text(
                        formatDate(product.expiryDate),
                        style: const TextStyle(
                          color: textSecondary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 15),

            sectionTitle('DETAILS'),

            detail(
              'Brand',
              product.brand.isEmpty ? 'Not provided' : product.brand,
            ),
            detail(
              'Serial Number',
              product.serial.isEmpty ? 'Not provided' : product.serial,
            ),
            detail(
              'Purchase Price',
              product.price.isEmpty ? 'Not provided' : product.price,
            ),
            detail('Warranty', product.warranty),
            detail('Purchase Date', formatDate(product.purchaseDate)),

            const SizedBox(height: 15),

            sectionTitle('DOCUMENTS'),

            document(
              context,
              Icons.description,
              'Warranty sheet',
              product.warrantyDocumentName ?? 'No sheet added',
              product.warrantyDocumentUrl,
            ),

            const SizedBox(height: 15),

            sectionTitle('ACTIONS'),

            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: green,
                  foregroundColor: bg,
                ),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Warranty claim initiated ✓')),
                  );
                },
                icon: const Icon(Icons.build_outlined),
                label: const Text('Start Warranty Claim'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  double warrantyProgress() {
    final total = product.expiryDate.difference(product.purchaseDate).inSeconds;

    final elapsed = DateTime.now().difference(product.purchaseDate).inSeconds;

    if (elapsed <= 0) return 0;

    if (elapsed >= total) return 1;

    return elapsed / total;
  }

  Widget sectionTitle(String text) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(
          text,
          style: const TextStyle(
            color: textSecondary,
            fontSize: 11,
            letterSpacing: 2,
          ),
        ),
      ),
    );
  }

  Widget detail(String title, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 7),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(title, style: const TextStyle(color: textSecondary)),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget document(
    BuildContext context,
    IconData icon,
    String title,
    String file,
    String? url,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icon, color: green),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  file,
                  style: const TextStyle(color: textSecondary, fontSize: 11),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: url == null
                ? null
                : () async {
                    final opened = await launchUrl(
                      Uri.parse(url),
                      mode: LaunchMode.externalApplication,
                    );
                    if (!opened && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Could not open the warranty sheet.'),
                        ),
                      );
                    }
                  },
            icon: const Icon(Icons.open_in_new),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// REMINDERS
// ============================================================

class RemindersPage extends StatefulWidget {
  const RemindersPage({super.key});

  @override
  State<RemindersPage> createState() => _RemindersPageState();
}

class _RemindersPageState extends State<RemindersPage> {
  bool ninety = true;
  bool thirty = true;
  bool seven = true;

  @override
  Widget build(BuildContext context) {
    return UserProductsBuilder(
      builder: (context, products) => SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text(
              'Alerts',
              style: TextStyle(fontSize: 29, fontWeight: FontWeight.w800),
            ),

            const SizedBox(height: 7),

            const Text(
              'We’ll tell you before something expires.',
              style: TextStyle(color: textSecondary),
            ),

            const SizedBox(height: 28),

            ...products
                .where((p) => p.status == 'Expiring')
                .map(
                  (p) => alertCard(
                    p.name,
                    'Warranty expires ${formatDate(p.expiryDate)}',
                    orange,
                    Icons.warning_amber,
                  ),
                ),
            if (!products.any((p) => p.status == 'Expiring'))
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: surface,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Text(
                  'No warranties are approaching expiry.',
                  style: TextStyle(color: textSecondary),
                ),
              ),

            const SizedBox(height: 25),

            const Text(
              'REMINDER SCHEDULE',
              style: TextStyle(
                color: textSecondary,
                fontSize: 11,
                letterSpacing: 2,
              ),
            ),

            const SizedBox(height: 10),

            reminderSwitch(
              '90 days before',
              'Early heads-up',
              ninety,
              (v) => setState(() => ninety = v),
            ),

            reminderSwitch(
              '30 days before',
              'Time to check your product',
              thirty,
              (v) => setState(() => thirty = v),
            ),

            reminderSwitch(
              '7 days before',
              'Last call',
              seven,
              (v) => setState(() => seven = v),
            ),
          ],
        ),
      ),
    );
  }

  Widget alertCard(String name, String subtitle, Color color, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(19),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: color.withOpacity(.12),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(color: textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget reminderSwitch(
    String title,
    String subtitle,
    bool value,
    Function(bool) onChanged,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(17),
      ),
      child: SwitchListTile(
        activeColor: green,
        value: value,
        onChanged: onChanged,
        title: Text(title),
        subtitle: Text(
          subtitle,
          style: const TextStyle(color: textSecondary, fontSize: 12),
        ),
      ),
    );
  }
}

// ============================================================
// PROFILE
// ============================================================

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final displayName = _userDisplayName(user);
    final email = user?.email ?? '';

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Me',
            style: TextStyle(fontSize: 29, fontWeight: FontWeight.w800),
          ),

          const SizedBox(height: 25),

          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: surface,
              borderRadius: BorderRadius.circular(22),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: surface2,
                  child: Text(
                    _userInitials(displayName),
                    style: const TextStyle(
                      color: green,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),

                SizedBox(width: 15),

                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      email,
                      style: const TextStyle(
                        color: textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 25),

          option(Icons.person_outline, 'Personal details'),

          option(Icons.notifications_none, 'Notifications'),

          option(Icons.lock_outline, 'Privacy & security'),

          option(Icons.help_outline, 'Help & support'),

          option(Icons.info_outline, 'About Warranty Wallet'),

          const SizedBox(height: 20),

          OutlinedButton.icon(
            onPressed: () async {
              try {
                await FirebaseAuth.instance.signOut();
              } on FirebaseAuthException {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Could not log out. Please try again.'),
                    ),
                  );
                }
              }
            },
            icon: const Icon(Icons.logout),
            label: const Text('Log out'),
          ),
        ],
      ),
    );
  }

  Widget option(IconData icon, String title) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: ListTile(
        leading: Icon(icon, color: textSecondary),
        title: Text(title),
        trailing: const Icon(Icons.chevron_right, color: textSecondary),
        onTap: () {},
      ),
    );
  }
}

// ============================================================
// STATUS BADGE
// ============================================================

Widget statusBadge(String status) {
  final Color color = status == 'Active'
      ? green
      : status == 'Expiring'
      ? orange
      : red;

  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
    decoration: BoxDecoration(
      color: color.withOpacity(.12),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Text(
      status,
      style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
    ),
  );
}
