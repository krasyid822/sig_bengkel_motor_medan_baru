import 'package:flutter/material.dart';
import 'package:sig_bengkel_motor_medan_baru/services/supabase_connection_service.dart';

class SupabaseStatusDot extends StatelessWidget {
  const SupabaseStatusDot({super.key});

  @override
  Widget build(BuildContext context) {
    final service = SupabaseConnectionService.instance;

    return ValueListenableBuilder<SupabaseConnectionState>(
      valueListenable: service.state,
      builder: (context, state, _) {
        final config = _resolveState(state);
        return IconButton(
          tooltip: config.label,
          onPressed: service.checkConnection,
          icon: Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              color: config.color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: config.color.withValues(alpha: 0.4),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ],
              border: Border.all(color: Colors.white, width: 1.4),
            ),
          ),
        );
      },
    );
  }

  ({Color color, String label}) _resolveState(SupabaseConnectionState state) {
    switch (state) {
      case SupabaseConnectionState.connected:
        return (color: const Color(0xFF22C55E), label: 'Supabase terhubung dengan aman');
      case SupabaseConnectionState.disconnected:
        return (color: const Color(0xFFEF4444), label: 'Supabase gagal terkoneksi');
      case SupabaseConnectionState.connecting:
        return (color: const Color(0xFFF59E0B), label: 'Sedang menghubungkan ke Supabase');
    }
  }
}
