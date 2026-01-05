
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';

/// Authentication result with user data or error
class AuthResult {
  final User? user;
  final String? error;
  final bool success;

  AuthResult({this.user, this.error, required this.success});

  factory AuthResult.success(User user) =>
      AuthResult(user: user, success: true);

  factory AuthResult.failure(String error) =>
      AuthResult(error: error, success: false);
}

/// Firebase Authentication Service
class AuthService extends ChangeNotifier {
    /// Sign in anonymously (guest login)
    Future<AuthResult> signInAnonymously() async {
      try {
        _setLoading(true);
        final credential = await _auth.signInAnonymously();
        return AuthResult.success(credential.user!);
      } on FirebaseAuthException catch (e) {
        return AuthResult.failure(_getErrorMessage(e.code));
      } catch (e) {
        return AuthResult.failure('Failed to sign in as guest');
      } finally {
        _setLoading(false);
      }
    }
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  User? _user;
  bool _isLoading = false;
  String? _verificationId;

  User? get user => _user;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _user != null;
  String? get verificationId => _verificationId;

  AuthService() {
    // Listen to auth state changes
    _auth.authStateChanges().listen((User? user) {
      _user = user;
      notifyListeners();
    });
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  // ==================== Email/Password ====================

  /// Sign up with email and password
  Future<AuthResult> signUpWithEmail({
    required String email,
    required String password,
    String? displayName,
  }) async {
    try {
      _setLoading(true);
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Update display name if provided
      if (displayName != null && credential.user != null) {
        await credential.user!.updateDisplayName(displayName);
        await credential.user!.reload();
        _user = _auth.currentUser;
      }

      return AuthResult.success(credential.user!);
    } on FirebaseAuthException catch (e) {
      return AuthResult.failure(_getErrorMessage(e.code));
    } catch (e) {
      return AuthResult.failure('An unexpected error occurred');
    } finally {
      _setLoading(false);
    }
  }

  /// Sign in with email and password
  Future<AuthResult> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      _setLoading(true);
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return AuthResult.success(credential.user!);
    } on FirebaseAuthException catch (e) {
      return AuthResult.failure(_getErrorMessage(e.code));
    } catch (e) {
      return AuthResult.failure('An unexpected error occurred');
    } finally {
      _setLoading(false);
    }
  }

  /// Send password reset email
  Future<AuthResult> sendPasswordResetEmail(String email) async {
    try {
      _setLoading(true);
      await _auth.sendPasswordResetEmail(email: email);
      return AuthResult(success: true);
    } on FirebaseAuthException catch (e) {
      return AuthResult.failure(_getErrorMessage(e.code));
    } catch (e) {
      return AuthResult.failure('An unexpected error occurred');
    } finally {
      _setLoading(false);
    }
  }

  // ==================== Google Sign In ====================

  /// Sign in with Google
  Future<AuthResult> signInWithGoogle() async {
    try {
      _setLoading(true);

      // Trigger the authentication flow
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        return AuthResult.failure('Google sign-in was cancelled');
      }

      // Obtain the auth details from the request
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      // Create a new credential
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase with the Google credential
      final userCredential = await _auth.signInWithCredential(credential);
      return AuthResult.success(userCredential.user!);
    } on FirebaseAuthException catch (e) {
      return AuthResult.failure(_getErrorMessage(e.code));
    } catch (e) {
      return AuthResult.failure('Failed to sign in with Google');
    } finally {
      _setLoading(false);
    }
  }

  // ==================== Phone Authentication ====================

  /// Send OTP to phone number
  Future<void> sendOtp({
    required String phoneNumber,
    required Function(String verificationId) onCodeSent,
    required Function(String error) onError,
    required Function(User user) onAutoVerified,
  }) async {
    try {
      _setLoading(true);
      
      // Validate phone number format
      if (!phoneNumber.startsWith('+')) {
        _setLoading(false);
        onError('Phone number must include country code (e.g., +1 for US)');
        return;
      }

      await _auth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        timeout: const Duration(seconds: 120),
        verificationCompleted: (PhoneAuthCredential credential) async {
          // Auto-verification (Android only)
          try {
            final userCredential = await _auth.signInWithCredential(credential);
            _setLoading(false);
            onAutoVerified(userCredential.user!);
          } catch (e) {
            _setLoading(false);
            onError('Auto-verification failed. Please enter the code manually.');
          }
        },
        verificationFailed: (FirebaseAuthException e) {
          _setLoading(false);
          debugPrint('Phone auth error code: ${e.code}');
          debugPrint('Phone auth error message: ${e.message}');
          debugPrint('Phone auth error stack: ${e.stackTrace}');
          onError(_getErrorMessage(e.code));
        },
        codeSent: (String verificationId, int? resendToken) {
          _verificationId = verificationId;
          _setLoading(false);
          onCodeSent(verificationId);
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          _verificationId = verificationId;
        },
      );
    } catch (e, stackTrace) {
      _setLoading(false);
      debugPrint('Phone auth exception: $e');
      debugPrint('Stack trace: $stackTrace');
      onError('Failed to send verification code: ${e.toString()}');
    }
  }

  /// Verify OTP code
  Future<AuthResult> verifyOtp(String otp) async {
    try {
      if (_verificationId == null) {
        return AuthResult.failure(
          'No verification ID found. Please request a new code.',
        );
      }

      _setLoading(true);

      final credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: otp,
      );

      final userCredential = await _auth.signInWithCredential(credential);
      return AuthResult.success(userCredential.user!);
    } on FirebaseAuthException catch (e) {
      return AuthResult.failure(_getErrorMessage(e.code));
    } catch (e) {
      return AuthResult.failure('Failed to verify code');
    } finally {
      _setLoading(false);
    }
  }

  // ==================== Sign Out ====================

  /// Sign out from all providers
  Future<void> signOut() async {
    try {
      _setLoading(true);
      await _googleSignIn.signOut();
      await _auth.signOut();
      _verificationId = null;
    } finally {
      _setLoading(false);
    }
  }
    /// Delete the current user account from Firebase and sign out of Google
    Future<AuthResult> deleteAccount() async {
      try {
        _setLoading(true);
        final user = _auth.currentUser;
        if (user == null) {
          return AuthResult.failure('No user is currently signed in.');
        }
        await user.delete();
        // Sign out of Google to prevent auto-login
        await _googleSignIn.signOut();
        _user = null;
        notifyListeners();
        return AuthResult(success: true);
      } on FirebaseAuthException catch (e) {
        // If recent login is required, handle accordingly in UI
        return AuthResult.failure(_getErrorMessage(e.code));
      } catch (e) {
        return AuthResult.failure('Failed to delete account.');
      } finally {
        _setLoading(false);
      }
    }

  // ==================== Helper Methods ====================

  /// Get user-friendly error message
  String _getErrorMessage(String code) {
    switch (code) {
      case 'email-already-in-use':
        return 'This email is already registered. Try signing in instead.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'operation-not-allowed':
        return 'This sign-in method is not enabled.';
      case 'weak-password':
        return 'Password is too weak. Use at least 6 characters.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'user-not-found':
        return 'No account found with this email.';
      case 'wrong-password':
        return 'Incorrect password. Please try again.';
      case 'invalid-credential':
        return 'Invalid email or password.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'invalid-verification-code':
        return 'Invalid verification code. Please try again.';
      case 'invalid-verification-id':
        return 'Verification expired. Please request a new code.';
      case 'invalid-phone-number':
        return 'Please enter a valid phone number with country code (e.g., +1234567890).';
      case 'quota-exceeded':
        return 'SMS quota exceeded. Please try again later.';
      case 'missing-phone-number':
        return 'Please enter your phone number.';
      case 'captcha-check-failed':
        return 'reCAPTCHA verification failed. Please try again.';
      case 'app-not-authorized':
        return 'This app is not authorized for phone authentication.';
      case 'web-context-cancelled':
        return 'Phone verification was cancelled.';
      case 'network-request-failed':
        return 'Network error. Please check your internet connection.';
      case 'session-expired':
        return 'Session expired. Please request a new code.';
      case 'missing-client-identifier':
        return 'App verification failed. Please restart the app.';
      case 'app-not-verified':
        return 'App not verified. Please check Firebase configuration.';
      case 'internal-error':
        return 'Server error. Please try again in a few minutes.';
      default:
        debugPrint('Unhandled auth error code: $code');
        return 'Authentication error ($code). Please try again.';
    }
  }
}
