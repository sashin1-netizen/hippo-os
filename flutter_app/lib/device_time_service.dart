import 'package:flutter_timezone/flutter_timezone.dart';

class DeviceClockSnapshot {
  const DeviceClockSnapshot({
    required this.ianaZone,
    required this.localIso8601,
    required this.utcOffsetMinutes,
    required this.localHour,
    required this.localMinute,
    required this.epochMilliseconds,
  });

  final String ianaZone;
  final String localIso8601;
  final int utcOffsetMinutes;
  final int localHour;
  final int localMinute;
  final int epochMilliseconds;

  Map<String, Object> toEnginePayload() => <String, Object>{
        'iana_zone': ianaZone,
        'local_iso8601': localIso8601,
        'utc_offset_minutes': utcOffsetMinutes,
        'local_hour': localHour,
        'local_minute': localMinute,
        'epoch_milliseconds': epochMilliseconds,
      };
}

class DeviceTimeService {
  const DeviceTimeService();

  Future<DeviceClockSnapshot> snapshot() async {
    final zone = await FlutterTimezone.getLocalTimezone();
    final now = DateTime.now();
    return DeviceClockSnapshot(
      ianaZone: zone.identifier,
      localIso8601: now.toIso8601String(),
      utcOffsetMinutes: now.timeZoneOffset.inMinutes,
      localHour: now.hour,
      localMinute: now.minute,
      epochMilliseconds: now.millisecondsSinceEpoch,
    );
  }
}
