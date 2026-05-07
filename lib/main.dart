import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'design/theme.dart';
import 'pages/payment_page.dart';

void main() {
  runApp(const ZendPayApp());
}

final _router = GoRouter(
  routes: [
    // Fixed-amount request: zdfi.me/john_o/abc123
    GoRoute(
      path: '/:zendtag/:requestId',
      builder: (context, state) {
        final zendtag = state.pathParameters['zendtag']!;
        final requestId = state.pathParameters['requestId']!;
        return PaymentPage(zendtag: zendtag, requestId: requestId);
      },
    ),
    // PWYW: zdfi.me/john_o
    GoRoute(
      path: '/:zendtag',
      builder: (context, state) {
        final zendtag = state.pathParameters['zendtag']!;
        return PaymentPage(zendtag: zendtag);
      },
    ),
    // Root fallback
    GoRoute(
      path: '/',
      builder: (context, state) => const _NotFoundPage(),
    ),
  ],
  errorBuilder: (context, state) => const _NotFoundPage(),
);

class ZendPayApp extends StatelessWidget {
  const ZendPayApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'ZendPay',
      debugShowCheckedModeBanner: false,
      theme: buildZendPayTheme(),
      routerConfig: _router,
    );
  }
}

class _NotFoundPage extends StatelessWidget {
  const _NotFoundPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'zdfi.me',
              style: TextStyle(
                fontFamily: 'InstrumentSerif',
                fontSize: 32,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'This link does not exist!',
              style: TextStyle(
                fontFamily: 'DMSans',
                fontSize: 16,
                color: Color(0xFF6B7A6E),
              ),
            ),
            const SizedBox(height: 24),
            TextButton(
              onPressed: () {},
              child: const Text('Get your own payment link'),
            ),
          ],
        ),
      ),
    );
  }
}
