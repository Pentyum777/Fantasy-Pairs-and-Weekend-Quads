@JS()
library msal_web;

import 'dart:convert';
import 'package:js/js.dart';

// These functions map directly to your MSAL JavaScript functions
@JS('msalLogin')
external void _msalLogin(String scopesJson);

@JS('msalGetToken')
external void _msalGetToken(String scopesJson);

// ---------------------------------------------------------------------------
// Web implementation of MSAL service
// ---------------------------------------------------------------------------
void initMsal({
  required String clientId,
  required String tenantId,
  required String redirectUri,
}) {
  // Your JS file already initializes MSAL automatically.
  // Nothing is required here.
  print("MSAL Web: initMsal() called (JS handles actual init)");
}

Future<String> loginWithMsal(List<String> scopes) async {
  _msalLogin(jsonEncode(scopes));
  return "";
}

Future<String> acquireTokenWithMsal(List<String> scopes) async {
  _msalGetToken(jsonEncode(scopes));
  return "";
}