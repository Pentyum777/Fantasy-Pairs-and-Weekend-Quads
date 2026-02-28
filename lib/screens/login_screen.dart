import 'package:flutter/material.dart';

class LoginScreen extends StatefulWidget {
  final void Function() onLoggedIn;

  const LoginScreen({super.key, required this.onLoggedIn});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _loading = false;
  bool _hovering = false;

  void _login() {
    setState(() => _loading = true);
    widget.onLoggedIn();
  }

  bool isPortraitPhone(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return size.height > size.width && size.width < 600;
  }

  @override
  Widget build(BuildContext context) {
    final bool mobile = isPortraitPhone(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text(""),
        centerTitle: true,
        backgroundColor: Colors.blue.shade700,
      ),
      body: Center(
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: mobile ? 24 : 40,
            vertical: mobile ? 28 : 40,
          ),
          decoration: BoxDecoration(
            color: Colors.grey.shade900.withAlpha((255 * 0.15).round()),
            borderRadius: BorderRadius.circular(mobile ? 16 : 22),
            border: Border.all(
              color: Colors.grey.shade300.withAlpha(153),
              width: mobile ? 1.1 : 1.4,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(46),
                blurRadius: mobile ? 6 : 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: _loading
              ? const CircularProgressIndicator()
              : MouseRegion(
                  onEnter: (_) => setState(() => _hovering = true),
                  onExit: (_) => setState(() => _hovering = false),
                  child: GestureDetector(
                    onTap: _login,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: EdgeInsets.all(mobile ? 12 : 20),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(mobile ? 16 : 22),
                        boxShadow: _hovering
                            ? [
                                BoxShadow(
                                  color: Colors.blueAccent.withAlpha((255 * 0.55).round()),
                                  blurRadius: 25,
                                  spreadRadius: 4,
                                ),
                              ]
                            : [
                                BoxShadow(
                                  color: Colors.black.withAlpha(46),
                                  blurRadius: mobile ? 6 : 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                      ),
                      child: Image.asset(
                        "assets/images/Football.Logo.png",
                        height: mobile ? 100 : 150,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}
