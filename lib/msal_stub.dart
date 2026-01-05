void initMsal({
  required String clientId,
  required String tenantId,
  required String redirectUri,
}) {
  print(">>> USING MSAL STUB IMPLEMENTATION");
}

Future<String> loginWithMsal(List<String> scopes) {
  throw UnsupportedError("MSAL is only supported on web.");
}

Future<String> acquireTokenWithMsal(List<String> scopes) {
  throw UnsupportedError("MSAL authentication is only supported on Flutter Web."
  );
}