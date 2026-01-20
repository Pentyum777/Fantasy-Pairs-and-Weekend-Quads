import 'dart:js' as js;
import 'dart:convert';
import 'dart:async';

class MsalService {
  // Stream for delivering tokens to the app
  static final _tokenStreamController = StreamController<String>.broadcast();

  // Called by main.dart when JS dispatches the token event
  static void receiveTokenFromJs(String token) {
    _tokenStreamController.add(token);
  }

  // App code listens here
  static void listenForToken(void Function(String token) callback) {
    _tokenStreamController.stream.listen(callback);
  }

  // Trigger login via JS
  static void startLogin(List<String> scopes) {
    js.context.callMethod('msalLogin', [jsonEncode(scopes)]);
  }
}