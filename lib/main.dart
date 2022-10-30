/// This sample is based on https://github.com/MaikuB/flutter_appauth/blob/master/flutter_appauth/example/lib/main.dart
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_appauth/flutter_appauth.dart';
import 'package:http/http.dart';

void main() => runApp(const MyApp());

class Config {
  // For a list of client IDs, go to https://demo.duendesoftware.com
  static const String clientId = 'interactive.public';
  static const String redirectUrl = 'com.duendesoftware.demo:/oauthredirect';
  static const String issuer = 'https://demo.duendesoftware.com';
  static const String authBaseUrl = 'https://demo.duendesoftware.com';
  static const String discoveryUrl =
      '$authBaseUrl/.well-known/openid-configuration';
  static const String postLogoutRedirectUrl = 'com.duendesoftware.demo:/';
  static const AuthorizationServiceConfiguration serviceConfiguration =
      AuthorizationServiceConfiguration(
    authorizationEndpoint: '$authBaseUrl/connect/authorize',
    tokenEndpoint: '$authBaseUrl/connect/token',
    endSessionEndpoint: '$authBaseUrl/connect/endsession',
  );

  static const List<String> scopes = <String>[
    'openid',
    'profile',
    'email',
    'offline_access',
    'api'
  ];
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final FlutterAppAuth _appAuth = const FlutterAppAuth();

  String? _codeVerifier;
  String? _nonce;
  String? _authorizationCode;
  String? _refreshToken;
  String? _accessToken;
  String? _idToken;
  String? _userInfo;

  final TextEditingController _authorizationCodeTextCtrl =
      TextEditingController();
  final TextEditingController _accessTokenTextCtrl = TextEditingController();
  final TextEditingController _accessTokenExpirationTextCtrl =
      TextEditingController();
  final TextEditingController _idTokenTextCtrl = TextEditingController();
  final TextEditingController _refreshTokenTextCtrl = TextEditingController();

  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('AppAuth Sample'),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              children: <Widget>[
                Visibility(
                  visible: _isLoading,
                  child: const LinearProgressIndicator(),
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  child: const Text('Sign in with no code exchange'),
                  onPressed: () => _signInWithNoCodeExchange(),
                ),
                ElevatedButton(
                  child: const Text(
                      'Sign in with no code exchange and generated nonce'),
                  onPressed: () => _signInWithNoCodeExchangeAndGeneratedNonce(),
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: _authorizationCode != null ? _exchangeCode : null,
                  child: const Text('Exchange code'),
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  child: const Text('Sign in with auto code exchange'),
                  onPressed: () => _signInWithAutoCodeExchange(),
                ),
                if (Platform.isIOS || Platform.isMacOS)
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: ElevatedButton(
                      child: const Text(
                        'Sign in with auto code exchange using ephemeral session',
                        textAlign: TextAlign.center,
                      ),
                      onPressed: () => _signInWithAutoCodeExchange(
                          preferEphemeralSession: true),
                    ),
                  ),
                ElevatedButton(
                  onPressed: _refreshToken != null ? _refresh : null,
                  child: const Text('Refresh token'),
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: _idToken != null
                      ? () async {
                          await _endSession();
                        }
                      : null,
                  child: const Text('End session'),
                ),
                const SizedBox(height: 8),
                const Text('authorization code'),
                TextField(
                  controller: _authorizationCodeTextCtrl,
                ),
                const Text('access token'),
                TextField(
                  controller: _accessTokenTextCtrl,
                ),
                const Text('access token expiration'),
                TextField(
                  controller: _accessTokenExpirationTextCtrl,
                ),
                const Text('id token'),
                TextField(
                  controller: _idTokenTextCtrl,
                ),
                const Text('refresh token'),
                TextField(
                  controller: _refreshTokenTextCtrl,
                ),
                const Text('test api results'),
                Text(_userInfo ?? ''),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _endSession() async {
    try {
      _setBusyState();
      await _appAuth.endSession(EndSessionRequest(
          idTokenHint: _idToken,
          postLogoutRedirectUrl: Config.postLogoutRedirectUrl,
          serviceConfiguration: Config.serviceConfiguration));
      _clearSessionInfo();
    } catch (_) {}
    _clearBusyState();
  }

  void _clearSessionInfo() {
    setState(() {
      _codeVerifier = null;
      _nonce = null;
      _authorizationCode = null;
      _authorizationCodeTextCtrl.clear();
      _accessToken = null;
      _accessTokenTextCtrl.clear();
      _idToken = null;
      _idTokenTextCtrl.clear();
      _refreshToken = null;
      _refreshTokenTextCtrl.clear();
      _accessTokenExpirationTextCtrl.clear();
      _userInfo = null;
    });
  }

  Future<void> _refresh() async {
    try {
      _setBusyState();
      final TokenResponse? result = await _appAuth.token(TokenRequest(
          Config.clientId, Config.redirectUrl,
          refreshToken: _refreshToken,
          issuer: Config.issuer,
          scopes: Config.scopes));
      _processTokenResponse(result);
      await _testApi(result);
    } catch (_) {
      _clearBusyState();
    }
  }

  Future<void> _exchangeCode() async {
    try {
      _setBusyState();
      final TokenResponse? result = await _appAuth.token(TokenRequest(
          Config.clientId, Config.redirectUrl,
          authorizationCode: _authorizationCode,
          discoveryUrl: Config.discoveryUrl,
          codeVerifier: _codeVerifier,
          nonce: _nonce,
          scopes: Config.scopes));
      _processTokenResponse(result);
      await _testApi(result);
    } catch (_) {
      _clearBusyState();
    }
  }

  Future<void> _signInWithNoCodeExchange() async {
    try {
      _setBusyState();
      // use the discovery endpoint to find the configuration
      final AuthorizationResponse? result = await _appAuth.authorize(
        AuthorizationRequest(Config.clientId, Config.redirectUrl,
            discoveryUrl: Config.discoveryUrl,
            scopes: Config.scopes,
            loginHint: 'bob'),
      );

      // or just use the issuer
      // var result = await _appAuth.authorize(
      //   AuthorizationRequest(
      //     _clientId,
      //     _redirectUrl,
      //     issuer: _issuer,
      //     scopes: _scopes,
      //   ),
      // );
      if (result != null) {
        _processAuthResponse(result);
      }
    } catch (_) {
      _clearBusyState();
    }
  }

  Future<void> _signInWithNoCodeExchangeAndGeneratedNonce() async {
    try {
      _setBusyState();
      final Random random = Random.secure();
      final String nonce =
          base64Url.encode(List<int>.generate(16, (_) => random.nextInt(256)));
      // use the discovery endpoint to find the configuration
      final AuthorizationResponse? result = await _appAuth.authorize(
        AuthorizationRequest(Config.clientId, Config.redirectUrl,
            discoveryUrl: Config.discoveryUrl,
            scopes: Config.scopes,
            loginHint: 'bob',
            nonce: nonce),
      );

      if (result != null) {
        _processAuthResponse(result);
      }
    } catch (_) {
      _clearBusyState();
    }
  }

  Future<void> _signInWithAutoCodeExchange(
      {bool preferEphemeralSession = false}) async {
    try {
      _setBusyState();

      // show that we can also explicitly specify the endpoints rather than getting from the details from the discovery document
      final AuthorizationTokenResponse? result =
          await _appAuth.authorizeAndExchangeCode(
        AuthorizationTokenRequest(
          Config.clientId,
          Config.redirectUrl,
          serviceConfiguration: Config.serviceConfiguration,
          scopes: Config.scopes,
          preferEphemeralSession: preferEphemeralSession,
        ),
      );

      // this code block demonstrates passing in values for the prompt parameter. in this case it prompts the user login even if they have already signed in. the list of supported values depends on the identity provider
      // final AuthorizationTokenResponse result = await _appAuth.authorizeAndExchangeCode(
      //   AuthorizationTokenRequest(_clientId, _redirectUrl,
      //       serviceConfiguration: _serviceConfiguration,
      //       scopes: _scopes,
      //       promptValues: ['login']),
      // );

      if (result != null) {
        _processAuthTokenResponse(result);
        await _testApi(result);
      }
    } catch (_) {
      _clearBusyState();
    }
  }

  void _clearBusyState() {
    setState(() {
      _isLoading = false;
    });
  }

  void _setBusyState() {
    setState(() {
      _isLoading = true;
    });
  }

  void _processAuthTokenResponse(AuthorizationTokenResponse response) {
    setState(() {
      _accessToken = _accessTokenTextCtrl.text = response.accessToken!;
      _idToken = _idTokenTextCtrl.text = response.idToken!;
      _refreshToken = _refreshTokenTextCtrl.text = response.refreshToken!;
      _accessTokenExpirationTextCtrl.text =
          response.accessTokenExpirationDateTime!.toIso8601String();
    });
  }

  void _processAuthResponse(AuthorizationResponse response) {
    setState(() {
      // save the code verifier and nonce as it must be used when exchanging the token
      _codeVerifier = response.codeVerifier;
      _nonce = response.nonce;
      _authorizationCode =
          _authorizationCodeTextCtrl.text = response.authorizationCode!;
      _isLoading = false;
    });
  }

  void _processTokenResponse(TokenResponse? response) {
    setState(() {
      _accessToken = _accessTokenTextCtrl.text = response!.accessToken!;
      _idToken = _idTokenTextCtrl.text = response.idToken!;
      _refreshToken = _refreshTokenTextCtrl.text = response.refreshToken!;
      _accessTokenExpirationTextCtrl.text =
          response.accessTokenExpirationDateTime!.toIso8601String();
    });
  }

  Future<void> _testApi(TokenResponse? response) async {
    final Response httpResponse = await get(
        Uri.parse('https://demo.duendesoftware.com/api/test'),
        headers: <String, String>{'Authorization': 'Bearer $_accessToken'});
    setState(() {
      _userInfo = httpResponse.statusCode == 200 ? httpResponse.body : '';
      _isLoading = false;
    });
  }
}
