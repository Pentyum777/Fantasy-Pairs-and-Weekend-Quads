@JS()
library msal_test;

// ignore: deprecated_member_use
import 'package:js/js.dart';

@JS('msal.PublicClientApplication')
class PublicClientApplication {
  external factory PublicClientApplication(dynamic config);
  external Future<dynamic> loginPopup(dynamic request);
}

void testMsal() {
  final config = {
    'auth': {
      'clientId': 'c75121a5-552e-46c6-a357-2e5029b56131',
      'authority': 'https://login.microsoftonline.com/common'
    }
  };

  final pca = PublicClientApplication(config);

  pca.loginPopup({'scopes': ['User.Read']}).then((result) {
    print('LOGIN SUCCESS: $result');
  }).catchError((err) {
    print('LOGIN ERROR: $err');
  });
}