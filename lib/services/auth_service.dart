import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
	// Get current user
	User? get currentUser => _client.auth.currentUser;
		final SupabaseClient _client = Supabase.instance.client;

	// Guest login: Try anonymous authentication or create a guest session
	Future<AuthResponse?> signInAsGuest() async {
		try {
			// Option 1: Try anonymous authentication (if enabled in Supabase)
			try {
				final response = await _client.auth.signInAnonymously();
				if (response.session != null) {
					return response;
				}
			} catch (anonymousError) {
				// Anonymous auth might not be enabled, continue with fallback
				print('Anonymous auth not available: $anonymousError');
			}

			// Option 2: Use a dynamic guest email with timestamp
			final timestamp = DateTime.now().millisecondsSinceEpoch;
			final guestEmail = 'guest_$timestamp@truthlens.app';
			final guestPassword = 'GuestPass123!';

			// Try to register the new guest user
			try {
				final signUpResponse = await _client.auth.signUp(
					email: guestEmail, 
					password: guestPassword,
					emailRedirectTo: null, // Don't require email confirmation
					data: {
						'is_guest': true,
						'created_at': DateTime.now().toIso8601String(),
						'display_name': 'Guest User',
					}
				);

				// If signup is successful, the user should be automatically signed in
				if (signUpResponse.session != null) {
					return signUpResponse;
				} else if (signUpResponse.user != null) {
					// If user is created but not signed in (email confirmation required)
					// Try to sign in immediately
					final loginResponse = await _client.auth.signInWithPassword(
						email: guestEmail, 
						password: guestPassword
					);
					return loginResponse;
				} else {
					throw 'Failed to create guest user';
				}
			} catch (e) {
				print('Guest signup error details: $e');
				if (e.toString().contains('email_address_invalid')) {
					throw 'Invalid email format for guest user';
				} else if (e.toString().contains('email_address_not_authorized')) {
					throw 'Email domain not authorized for guest signup';
				} else if (e.toString().contains('signup_disabled')) {
					throw 'User registration is disabled';
				} else {
					throw 'Guest login failed: ${e.toString()}';
				}
			}
		} catch (e) {
			throw 'Guest authentication failed: ${e.toString()}';
		}
	}

	// Local guest mode - doesn't require server authentication
	Future<bool> enableLocalGuestMode() async {
		try {
			// Store guest mode flag in local storage
			final prefs = await SharedPreferences.getInstance();
			await prefs.setBool('is_local_guest', true);
			await prefs.setString('guest_session_start', DateTime.now().toIso8601String());
			return true;
		} catch (e) {
			return false;
		}
	}

	// Check if user is in local guest mode
	Future<bool> isLocalGuest() async {
		try {
			final prefs = await SharedPreferences.getInstance();
			return prefs.getBool('is_local_guest') ?? false;
		} catch (e) {
			return false;
		}
	}

	// Clear local guest mode
	Future<void> clearLocalGuestMode() async {
		try {
			final prefs = await SharedPreferences.getInstance();
			await prefs.remove('is_local_guest');
			await prefs.remove('guest_session_start');
		} catch (e) {
			// Ignore errors when clearing
		}
	}

	// Email login
	Future<AuthResponse?> signInWithEmailPassword(String email, String password) async {
		try {
			final response = await _client.auth.signInWithPassword(email: email, password: password);
			if (response.session != null) {
				return response;
			} else {
				throw 'Invalid email or password.';
			}
		} catch (e) {
			throw 'Authentication failed: ${e.toString()}';
		}
	}

	// Register with email and password
	Future<AuthResponse?> registerWithEmailPassword(String email, String password) async {
		try {
			final response = await _client.auth.signUp(email: email, password: password);
			if (response.session != null) {
				return response;
			} else {
				throw 'Registration failed.';
			}
		} catch (e) {
			throw 'Registration failed: ${e.toString()}';
		}
	}

	// Sign out
	Future<void> signOut() async {
		try {
			// Clear local guest mode if active
			await clearLocalGuestMode();
			
			// Sign out from Supabase if there's an active session
			if (_client.auth.currentUser != null) {
				await _client.auth.signOut();
			}
		} catch (e) {
			// Even if sign out fails, clear local guest mode
			await clearLocalGuestMode();
			rethrow;
		}
	}
}