import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

enum SupabaseConnectionState {
  connecting,
  connected,
  disconnected,
}

class SupabaseConnectionService {
  SupabaseConnectionService._();

  static final SupabaseConnectionService instance = SupabaseConnectionService._();

  final SupabaseClient _client = Supabase.instance.client;
  final ValueNotifier<SupabaseConnectionState> state =
      ValueNotifier<SupabaseConnectionState>(SupabaseConnectionState.connecting);

  Timer? _timer;
  bool _isChecking = false;

  void startMonitoring() {
    _timer ??= Timer.periodic(const Duration(seconds: 20), (_) => checkConnection());
    unawaited(checkConnection());
  }

  Future<void> checkConnection() async {
    if (_isChecking) return;
    _isChecking = true;
    state.value = SupabaseConnectionState.connecting;

    try {
      await _client.from('aturan_sig').select('id').limit(1);
      state.value = SupabaseConnectionState.connected;
    } catch (_) {
      state.value = SupabaseConnectionState.disconnected;
    } finally {
      _isChecking = false;
    }
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
  }
}
