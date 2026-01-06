@JS()
library msal_web;

import 'dart:async';
import 'package:js/js.dart';

@JS('msal.PublicClientApplication')
class PublicClientApplication {
  external PublicClientApplication(dynamic config);
  external Future<dynamic> loginPopup(dynamic request);
  external Future<dynamic> acquireTokenSilent(dynamic request);
}

@JS()
@anonymous
class MsalConfig {
  external factory MsalConfig({
    required dynamic auth,
    dynamic cache,
  });
}

@JS()
@anonymous
class AuthConfig {
  external factory AuthConfig({
    required String clientId,
    required String authority,
    required String redirectUri,
  });
}

late PublicClientApplication _msal;

void initMsal() {
  final config = MsalConfig(
    auth: AuthConfig(
      clientId: "YOUR_CLIENT_ID_HERE",
      authority: "https://login.microsoftonline.com/common",
      redirectUri: "http://localhost:8080",
    ),
  );

  _msal = PublicClientApplication(config);
}

Future<String?> acquireTokenWithMsal(List<String> scopes) async {
  try {
    final result = await _msal.loginPopup({
      "scopes": scopes,
    });

    return result?['accessToken'] as String?;
  } catch (e) {
    return null;
  }
}