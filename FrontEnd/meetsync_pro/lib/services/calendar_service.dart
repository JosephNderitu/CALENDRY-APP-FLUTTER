import 'package:googleapis/calendar/v3.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'dart:async';

class CalendarService {
  static const _calendarScope = 'https://www.googleapis.com/auth/calendar';

  final FirebaseAuth _auth;
  final GoogleSignIn _googleSignIn;
  final http.Client _httpClient;

  CalendarService({
    FirebaseAuth? auth,
    GoogleSignIn? googleSignIn,
    http.Client? httpClient,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _googleSignIn = googleSignIn ?? GoogleSignIn.standard(scopes: [_calendarScope]),
        _httpClient = httpClient ?? http.Client();

  Future<CalendarApi> _getCalendarApi() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw CalendarException('User not authenticated');
    }

    // Get Google OAuth access token
    final googleAuth = await _getGoogleAuth();
    return CalendarApi(_AuthenticatedHttpClient(
      _httpClient,
      accessToken: googleAuth.accessToken,
    ));
  }

  Future<GoogleSignInAuthentication> _getGoogleAuth() async {
    try {
      // For users who signed in with Google
      if (_auth.currentUser?.providerData.any((info) => info.providerId == 'google.com') ?? false) {
        final googleUser = await _googleSignIn.signInSilently();
        if (googleUser == null) {
          throw CalendarException('Google authentication failed');
        }
        return await googleUser.authentication;
      }
      
      // For email/password users, we need to sign in with Google
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        throw CalendarException('Google sign-in cancelled');
      }
      return await googleUser.authentication;
    } catch (e) {
      throw CalendarException('Failed to get Google authentication: ${e.toString()}');
    }
  }

  Future<List<CalendarListEntry>> getUserCalendars() async {
    try {
      final calendarApi = await _getCalendarApi();
      final response = await calendarApi.calendarList.list();
      return response.items ?? [];
    } catch (e) {
      throw CalendarException('Failed to fetch calendars: ${e.toString()}');
    }
  }

  Future<Calendar> createCalendar(String name) async {
    try {
      final calendarApi = await _getCalendarApi();
      return await calendarApi.calendars.insert(
        Calendar(
          summary: name,
          description: 'Created from MeetSync Pro',
          timeZone: 'UTC',
        ),
      );
    } catch (e) {
      throw CalendarException('Failed to create calendar: ${e.toString()}');
    }
  }
}

class CalendarException implements Exception {
  final String message;
  CalendarException(this.message);

  @override
  String toString() => 'CalendarException: $message';
}

class _AuthenticatedHttpClient extends http.BaseClient {
  final http.Client _inner;
  final String? accessToken;

  _AuthenticatedHttpClient(this._inner, {required this.accessToken});

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    if (accessToken != null) {
      request.headers['Authorization'] = 'Bearer $accessToken';
    }
    request.headers['Content-Type'] = 'application/json';
    return _inner.send(request);
  }
}