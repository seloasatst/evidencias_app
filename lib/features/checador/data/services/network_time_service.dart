import 'dart:async';
import 'dart:io';

class ServerTimeException implements Exception {
  final String message;
  ServerTimeException(this.message);
  @override
  String toString() => message;
}

class NetworkTimeService {
  static DateTime? _lastSyncedNetworkTime;
  static final Stopwatch _elapsedStopwatch = Stopwatch();
  static bool _hasSynced = false;

  static bool get hasSynced => _hasSynced;
  static DateTime? get lastSyncedServerTime => _lastSyncedNetworkTime;
  static bool get isTimeSecure => _hasSynced && _elapsedStopwatch.isRunning;

  static final List<String> _timeEndpoints = [
    'https://www.google.com',
    'https://1.1.1.1',
    'https://www.cloudflare.com',
    'https://www.microsoft.com',
  ];

  static Future<DateTime> fetchGoogleCentralMexicoTime() async {
    // Timeout global de 5s para todo el proceso de sincronización
    return Future(() async {
      for (final url in _timeEndpoints) {
        try {
          final client = HttpClient();
          client.connectionTimeout = const Duration(seconds: 3);
          final request = await client.headUrl(Uri.parse(url));
          final response = await request.close();

          final dateHeader = response.headers.value(HttpHeaders.dateHeader);
          client.close(force: true);

          if (dateHeader != null) {
            final gmtTime = HttpDate.parse(dateHeader);
            final mexicoCentralTime = gmtTime.toUtc().subtract(const Duration(hours: 6));

            _lastSyncedNetworkTime = DateTime(
              mexicoCentralTime.year,
              mexicoCentralTime.month,
              mexicoCentralTime.day,
              mexicoCentralTime.hour,
              mexicoCentralTime.minute,
              mexicoCentralTime.second,
              mexicoCentralTime.millisecond,
            );
            _elapsedStopwatch.reset();
            _elapsedStopwatch.start();
            _hasSynced = true;

            return _lastSyncedNetworkTime!;
          }
        } catch (_) {
          continue;
        }
      }
      return getRealTime();
    }).timeout(
      const Duration(seconds: 5),
      onTimeout: () => getRealTime(), // fallback al reloj local si hay timeout
    );
  }

  static Future<DateTime> ensureServerTimeSynced() async {
    if (!isTimeSecure) {
      await fetchGoogleCentralMexicoTime();
    }

    if (!isTimeSecure) {
      throw ServerTimeException(
        '¡HORA NO VALIDADA!\nSe requiere conexión a internet para sincronizar la hora oficial de la empresa.',
      );
    }

    return getRealTime();
  }

  static DateTime getRealTime() {
    if (_lastSyncedNetworkTime != null && _elapsedStopwatch.isRunning) {
      return _lastSyncedNetworkTime!.add(_elapsedStopwatch.elapsed);
    }
    return DateTime.now();
  }
}
