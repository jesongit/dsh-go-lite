import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens Platform pages (authorization, top-up) outside the app's WebView.
abstract interface class AccountBrowser {
  /// True when something was launched.
  Future<bool> open(Uri url);
}

/// Chrome Custom Tab first (shares the browser's DeepSeek login cookies and
/// keeps the user next to the app), the default browser as a fallback. OAuth
/// stays out of embedded WebViews (RFC 8252).
class SystemAccountBrowser implements AccountBrowser {
  const SystemAccountBrowser();

  @override
  Future<bool> open(Uri url) async {
    for (final mode in const [LaunchMode.inAppBrowserView, LaunchMode.externalApplication]) {
      try {
        if (await launchUrl(url, mode: mode)) return true;
      } catch (_) {
        // No Custom Tabs provider: try the next mode.
      }
    }
    return false;
  }
}

final accountBrowserProvider = Provider<AccountBrowser>((ref) => const SystemAccountBrowser());
