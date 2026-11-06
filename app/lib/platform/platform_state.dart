import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'client_platform.dart';

final clientPlatformProvider = Provider<ClientPlatform>((ref) => ClientPlatform());
final batteryExemptProvider = FutureProvider<bool?>((ref) => ref.watch(clientPlatformProvider).batteryExempt());
