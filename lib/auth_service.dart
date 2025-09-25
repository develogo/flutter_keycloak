import 'dart:convert';
import 'dart:developer' as developer;

import 'package:flutter_appauth/flutter_appauth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'models/user_entity.dart';

class AuthService {
  static const FlutterAppAuth _appAuth = FlutterAppAuth();
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
  );

  static const String _keycloakUrl = 'http://10.0.2.2:8080';
  static const String _realm = 'example';
  static const String _clientId = 'mobile';
  static const String _redirectUrl = 'com.example.teste://callback';
  static const List<String> _scopes = ['openid', 'profile', 'email'];
  
  static const String _accessTokenKey = 'access_token';
  static const String _refreshTokenKey = 'refresh_token';
  static const String _idTokenKey = 'id_token';
  static const String _tokenExpirationKey = 'token_expiration';

  Future<bool> authenticate() async {
    try {
      const config = AuthorizationServiceConfiguration(
        authorizationEndpoint:
            '$_keycloakUrl/realms/$_realm/protocol/openid-connect/auth',
        tokenEndpoint:
            '$_keycloakUrl/realms/$_realm/protocol/openid-connect/token',
        endSessionEndpoint:
            '$_keycloakUrl/realms/$_realm/protocol/openid-connect/logout',
      );

      final AuthorizationTokenResponse result =
          await _appAuth.authorizeAndExchangeCode(
        AuthorizationTokenRequest(
          _clientId,
          _redirectUrl,
          serviceConfiguration: config,
          scopes: _scopes,
          allowInsecureConnections: true,
          externalUserAgent: ExternalUserAgent.asWebAuthenticationSession,
          promptValues: ['login'],
          additionalParameters: {
            'kc_action': 'AUTHENTICATE',
          },
        ),
      );

      if (result.accessToken == null) {
        throw Exception('Authentication failed - no access token received');
      }

      await _storeTokens(result);
      developer.log('Authentication successful', name: 'AuthService');
      return true;
    } catch (e) {
      developer.log('Authentication failed: $e', name: 'AuthService');
      return false;
    }
  }

  Future<void> _storeTokens(AuthorizationTokenResponse result) async {
    await _secureStorage.write(key: _accessTokenKey, value: result.accessToken!);
    
    if (result.refreshToken != null) {
      await _secureStorage.write(key: _refreshTokenKey, value: result.refreshToken!);
    }
    
    if (result.idToken != null) {
      await _secureStorage.write(key: _idTokenKey, value: result.idToken!);
    }
    
    if (result.accessTokenExpirationDateTime != null) {
      await _secureStorage.write(
        key: _tokenExpirationKey,
        value: result.accessTokenExpirationDateTime!.millisecondsSinceEpoch.toString(),
      );
    }
  }

  Future<void> _storeRefreshedTokens(TokenResponse result) async {
    await _secureStorage.write(key: _accessTokenKey, value: result.accessToken!);
    
    if (result.refreshToken != null) {
      await _secureStorage.write(key: _refreshTokenKey, value: result.refreshToken!);
    }
    
    if (result.idToken != null) {
      await _secureStorage.write(key: _idTokenKey, value: result.idToken!);
    }
    
    if (result.accessTokenExpirationDateTime != null) {
      await _secureStorage.write(
        key: _tokenExpirationKey,
        value: result.accessTokenExpirationDateTime!.millisecondsSinceEpoch.toString(),
      );
    }
  }

  Future<UserEntity> getUserInfo() async {
    final token = await _getValidAccessToken();
    
    final response = await http.get(
      Uri.parse('$_keycloakUrl/realms/$_realm/protocol/openid-connect/userinfo'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      try {
        final userInfoJson = json.decode(response.body) as Map<String, dynamic>;
        return UserEntity.fromJson(userInfoJson);
      } catch (e) {
        throw Exception('Failed to parse user information: $e');
      }
    } else if (response.statusCode == 401) {
      await _clearTokens();
      throw Exception('Token expired or invalid');
    } else {
      throw Exception('Failed to retrieve user information: ${response.statusCode}');
    }
  }

  Future<String> _getValidAccessToken() async {
    final token = await getAccessToken();
    if (token == null) {
      throw Exception('No access token available');
    }

    if (await _isTokenExpired()) {
      final refreshed = await _refreshAccessToken();
      if (!refreshed) {
        throw Exception('Token expired and refresh failed');
      }
      return await getAccessToken() ?? '';
    }

    return token;
  }

  Future<bool> _isTokenExpired() async {
    final expirationStr = await _secureStorage.read(key: _tokenExpirationKey);
    if (expirationStr == null) return false;

    final expiration = DateTime.fromMillisecondsSinceEpoch(int.parse(expirationStr));
    final buffer = const Duration(minutes: 5); // Refresh 5 minutes before expiration
    
    return DateTime.now().add(buffer).isAfter(expiration);
  }

  Future<bool> _refreshAccessToken() async {
    try {
      final refreshToken = await _secureStorage.read(key: _refreshTokenKey);
      if (refreshToken == null) {
        developer.log('No refresh token available', name: 'AuthService');
        return false;
      }

      const config = AuthorizationServiceConfiguration(
        authorizationEndpoint:
            '$_keycloakUrl/realms/$_realm/protocol/openid-connect/auth',
        tokenEndpoint:
            '$_keycloakUrl/realms/$_realm/protocol/openid-connect/token',
        endSessionEndpoint:
            '$_keycloakUrl/realms/$_realm/protocol/openid-connect/logout',
      );

      final result = await _appAuth.token(
        TokenRequest(
          _clientId,
          _redirectUrl,
          refreshToken: refreshToken,
          serviceConfiguration: config,
          allowInsecureConnections: true,
        ),
      );

      if (result.accessToken != null) {
        await _storeRefreshedTokens(result);
        developer.log('Token refreshed successfully', name: 'AuthService');
        return true;
      }
      
      return false;
    } catch (e) {
      developer.log('Token refresh failed: $e', name: 'AuthService');
      await _clearTokens();
      return false;
    }
  }

  Future<String?> getAccessToken() async {
    return await _secureStorage.read(key: _accessTokenKey);
  }

  Future<bool> isAuthenticated() async {
    final token = await _secureStorage.read(key: _accessTokenKey);
    if (token == null) return false;

    // Check if token is expired
    if (await _isTokenExpired()) {
      // Try to refresh the token
      final refreshed = await _refreshAccessToken();
      return refreshed;
    }

    return true;
  }

  Future<bool> logout() async {
    try {
      final idToken = await _getIdToken();
      
      if (idToken != null) {
        // Use the proper endSession method from flutter_appauth
        try {
          const config = AuthorizationServiceConfiguration(
            authorizationEndpoint:
                '$_keycloakUrl/realms/$_realm/protocol/openid-connect/auth',
            tokenEndpoint:
                '$_keycloakUrl/realms/$_realm/protocol/openid-connect/token',
            endSessionEndpoint:
                '$_keycloakUrl/realms/$_realm/protocol/openid-connect/logout',
          );

          final endSessionRequest = EndSessionRequest(
            idTokenHint: idToken,
            postLogoutRedirectUrl: _redirectUrl,
            serviceConfiguration: config,
            allowInsecureConnections: true,
          );

          await _appAuth.endSession(endSessionRequest);
          developer.log('End session completed successfully', name: 'AuthService');
        } catch (e) {
          developer.log('End session failed, but continuing with local logout: $e', name: 'AuthService');
        }
      } else {
        developer.log('No ID token to logout with', name: 'AuthService');
      }

      // Always clear local tokens
      await _clearTokens();
      return true;
    } catch (e) {
      developer.log('Logout error: $e', name: 'AuthService');
      // Even if logout fails, we still want to clear local tokens
      await _clearTokens();
      return true;
    }
  }

  Future<String?> _getIdToken() async {
    return await _secureStorage.read(key: _idTokenKey);
  }

  Future<void> _clearTokens() async {
    await Future.wait([
      _secureStorage.delete(key: _accessTokenKey),
      _secureStorage.delete(key: _refreshTokenKey),
      _secureStorage.delete(key: _idTokenKey),
      _secureStorage.delete(key: _tokenExpirationKey),
    ]);
  }

  // Method to check if user needs to re-authenticate
  Future<bool> needsAuthentication() async {
    return !(await isAuthenticated());
  }

  // Get remaining token validity duration
  Future<Duration?> getTokenValidityDuration() async {
    final expirationStr = await _secureStorage.read(key: _tokenExpirationKey);
    if (expirationStr == null) return null;

    final expiration = DateTime.fromMillisecondsSinceEpoch(int.parse(expirationStr));
    final remaining = expiration.difference(DateTime.now());
    
    return remaining.isNegative ? Duration.zero : remaining;
  }
}
