import 'dart:convert';

import 'package:flutter_appauth/flutter_appauth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

/// Authentication service implementing OAuth2/OpenID Connect with Keycloak
/// Manages the complete authentication lifecycle, including:
/// - Authorization flow with PKCE
/// - Token management (access_token and refresh_token)
/// - Session validation
/// - Logout with token revocation
class AuthService {
  static const FlutterAppAuth appAuth = FlutterAppAuth();
  static const FlutterSecureStorage secureStorage = FlutterSecureStorage();

  /// Keycloak server settings
  /// - keycloakUrl: Base endpoint of the Keycloak server
  /// - realm: Tenant realm
  /// - clientId: OAuth2 client identifier
  /// - redirectUrl: Redirect URI after authentication
  /// - scopes: Requested OAuth2 scopes (openid, profile, email)
  final String keycloakUrl = 'http://192.168.50.3:8080';
  final String realm = 'example';
  final String clientId = 'mobile';
  final String redirectUrl = 'com.example.teste://callback';
  final List<String> scopes = ['openid', 'profile', 'email'];

  /// Initiates the OAuth2/OpenID Connect authentication flow
  ///
  /// Implements the Authorization Code Flow with PKCE
  /// 1. Configures authorization server endpoints
  /// 2. Initiates authorization flow
  /// 3. Exchanges code for tokens
  /// 4. Securely stores tokens
  ///
  /// @return Future<bool> - true if authentication successful
  Future<bool> authenticate() async {
    try {
      // OAuth2/OpenID Connect endpoint configuration
      final config = AuthorizationServiceConfiguration(
        authorizationEndpoint:
            '$keycloakUrl/realms/$realm/protocol/openid-connect/auth',
        tokenEndpoint:
            '$keycloakUrl/realms/$realm/protocol/openid-connect/token',
        endSessionEndpoint:
            '$keycloakUrl/realms/$realm/protocol/openid-connect/logout',
      );

      print("Starting OAuth2 authentication flow...");

      // Requests authorization and exchanges code for tokens
      final AuthorizationTokenResponse result =
          await appAuth.authorizeAndExchangeCode(
        AuthorizationTokenRequest(
          clientId,
          redirectUrl,
          serviceConfiguration: config,
          scopes: scopes,
          allowInsecureConnections: true,
          externalUserAgent: ExternalUserAgent.asWebAuthenticationSession,
          promptValues: ['login'],
        ),
      );

      // Securely stores JWT tokens
      await secureStorage.write(key: 'access_token', value: result.accessToken);
      await secureStorage.write(
          key: 'refresh_token', value: result.refreshToken);
      print("OAuth2 authentication completed successfully");
      print(result.accessToken);
      return true;
    } catch (e) {
      print('OAuth2 authentication failed: $e');
      return false;
    }
  }

  /// Recupera informações do usuário autenticado
  ///
  /// Utiliza o endpoint userinfo do OpenID Connect
  /// Requer token de acesso válido
  ///
  /// @return Future<Map<String, dynamic>> - Dados do usuário em formato JSON
  Future<Map<String, dynamic>> getUserInfo() async {
    final token = await getAccessToken();
    final response = await http.get(
      Uri.parse('$keycloakUrl/realms/$realm/protocol/openid-connect/userinfo'),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      print(response.body);
      return json.decode(response.body);
    } else {
      throw Exception('Falha ao recuperar informações do usuário');
    }
  }

  /// Recupera o token de acesso JWT armazenado
  ///
  /// @return Future<String?> - Token JWT ou null se não autenticado
  Future<String?> getAccessToken() async {
    return await secureStorage.read(key: 'access_token');
  }

  /// Verifica estado da autenticação
  ///
  /// @return Future<bool> - true se token de acesso presente
  Future<bool> isAuthenticated() async {
    final token = await secureStorage.read(key: 'access_token');
    return token != null;
  }

  /// Realiza logout e revogação de tokens
  ///
  /// Implementa:
  /// 1. Limpeza local de tokens
  /// 2. Revogação de tokens no servidor
  ///
  /// @return Future<bool> - true if logout successful
  Future<bool> logout() async {
    try {
      final accessToken = await getAccessToken();

      // Revoga tokens localmente
      await secureStorage.delete(key: 'access_token');
      await secureStorage.delete(key: 'refresh_token');

      if (accessToken == null) {
        return true;
      }

      // Revoga tokens no servidor Keycloak
      final response = await http.get(
        Uri.parse('$keycloakUrl/realms/$realm/protocol/openid-connect/logout'),
        headers: {
          'Authorization': 'Bearer $accessToken',
        },
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        print("Logout and token revocation completed");
        return true;
      } else {
        print(
            "Token revocation failed: ${response.statusCode} - ${response.body}");
        return true;
      }
    } catch (e) {
      print('Logout failed: $e');
      return true;
    }
  }
}
