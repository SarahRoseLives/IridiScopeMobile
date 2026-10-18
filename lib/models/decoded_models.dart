int _ts(int ns) => ns ~/ 1000;

String timeLabelFromNs(int ns) {
  if (ns <= 0) return '';
  final d = DateTime.fromMicrosecondsSinceEpoch(_ts(ns));
  return '${d.hour.toString().padLeft(2, '0')}:'
      '${d.minute.toString().padLeft(2, '0')}:'
      '${d.second.toString().padLeft(2, '0')}';
}

class AcarsMessage {
  final int timestampNs;
  final int ul;
  final String heading;
  final String reg;
  final String flight;
  final String mode;
  final String ack;
  final String label;
  final String labelDesc;
  final String bid;
  final String seqn;
  final String text;
  final String rawHex;
  final String errors;
  final bool crcOk;
  final bool cont;

  const AcarsMessage({
    required this.timestampNs,
    required this.ul,
    required this.heading,
    required this.reg,
    required this.flight,
    required this.mode,
    required this.ack,
    required this.label,
    required this.labelDesc,
    required this.bid,
    required this.seqn,
    required this.text,
    required this.rawHex,
    required this.errors,
    required this.crcOk,
    required this.cont,
  });

  factory AcarsMessage.fromJson(Map<String, dynamic> j) => AcarsMessage(
        timestampNs: (j['ts_ns'] as num?)?.toInt() ?? 0,
        ul: (j['ul'] as num?)?.toInt() ?? 0,
        heading: j['heading'] as String? ?? '',
        reg: j['reg'] as String? ?? '',
        flight: j['flight'] as String? ?? '',
        mode: j['mode'] as String? ?? '',
        ack: j['ack'] as String? ?? '',
        label: j['label'] as String? ?? '',
        labelDesc: j['label_desc'] as String? ?? '',
        bid: j['bid'] as String? ?? '',
        seqn: j['seqn'] as String? ?? '',
        text: j['text'] as String? ?? '',
        rawHex: j['raw_hex'] as String? ?? '',
        errors: j['errors'] as String? ?? '',
        crcOk: j['crc_ok'] == true,
        cont: j['cont'] == true,
      );

  String get title {
    final id = [reg, flight].where((s) => s.isNotEmpty).join(' / ');
    return id.isEmpty ? (labelDesc.isNotEmpty ? labelDesc : 'ACARS') : id;
  }

  String get timeLabel => timeLabelFromNs(timestampNs);
}

class SbdMessage {
  final int timestampNs;
  final double frequencyHz;
  final int ul;
  final String type;
  final int length;
  final String preheaderHex;
  final String payloadHex;
  final String text;
  final String info;
  final bool acars;
  final bool hasCrc;
  final bool crcOk;
  final bool hasNal;
  final double nalLat;
  final double nalLon;
  final int nalPdop;
  final int nalSeconds;
  final bool nalFix;
  final bool nalEmergency;
  final bool nalEmergencyAck;
  final bool nalMotion;
  final String nalInfo;

  const SbdMessage({
    required this.timestampNs,
    required this.frequencyHz,
    required this.ul,
    required this.type,
    required this.length,
    required this.preheaderHex,
    required this.payloadHex,
    required this.text,
    required this.info,
    required this.acars,
    required this.hasCrc,
    required this.crcOk,
    required this.hasNal,
    required this.nalLat,
    required this.nalLon,
    required this.nalPdop,
    required this.nalSeconds,
    required this.nalFix,
    required this.nalEmergency,
    required this.nalEmergencyAck,
    required this.nalMotion,
    required this.nalInfo,
  });

  factory SbdMessage.fromJson(Map<String, dynamic> j) => SbdMessage(
        timestampNs: (j['ts_ns'] as num?)?.toInt() ?? 0,
        frequencyHz: (j['freq'] as num?)?.toDouble() ?? 0,
        ul: (j['ul'] as num?)?.toInt() ?? 0,
        type: j['type'] as String? ?? '',
        length: (j['length'] as num?)?.toInt() ?? 0,
        preheaderHex: j['preheader_hex'] as String? ?? '',
        payloadHex: j['payload_hex'] as String? ?? '',
        text: j['text'] as String? ?? '',
        info: j['info'] as String? ?? '',
        acars: j['acars'] == true,
        hasCrc: j['has_crc'] == true,
        crcOk: j['crc_ok'] == true,
        hasNal: j['has_nal'] == true,
        nalLat: (j['nal_lat'] as num?)?.toDouble() ?? 0,
        nalLon: (j['nal_lon'] as num?)?.toDouble() ?? 0,
        nalPdop: (j['nal_pdop'] as num?)?.toInt() ?? 0,
        nalSeconds: (j['nal_seconds'] as num?)?.toInt() ?? 0,
        nalFix: j['nal_fix'] == true,
        nalEmergency: j['nal_emergency'] == true,
        nalEmergencyAck: j['nal_emergency_ack'] == true,
        nalMotion: j['nal_motion'] == true,
        nalInfo: j['nal_info'] as String? ?? '',
      );

  String get title => info.isNotEmpty ? info : 'SBD $type';
  String get timeLabel => timeLabelFromNs(timestampNs);
}

class SmsMessage {
  final int timestampNs;
  final int ul;
  final String from;
  final String to;
  final String text;
  final String dcs;
  final bool ok;

  const SmsMessage({
    required this.timestampNs,
    required this.ul,
    required this.from,
    required this.to,
    required this.text,
    required this.dcs,
    required this.ok,
  });

  factory SmsMessage.fromJson(Map<String, dynamic> j) => SmsMessage(
        timestampNs: (j['ts_ns'] as num?)?.toInt() ?? 0,
        ul: (j['ul'] as num?)?.toInt() ?? 0,
        from: j['from'] as String? ?? '',
        to: j['to'] as String? ?? '',
        text: j['text'] as String? ?? '',
        dcs: j['dcs'] as String? ?? '',
        ok: j['ok'] == true,
      );

  String get title => from.isNotEmpty ? 'SMS from $from' : 'SMS to $to';
  String get timeLabel => timeLabelFromNs(timestampNs);
}

class PagerMessage {
  final int timestampNs;
  final int ric;
  final int fmt;
  final int seq;
  final int parts;
  final bool ok;
  final String text;

  const PagerMessage({
    required this.timestampNs,
    required this.ric,
    required this.fmt,
    required this.seq,
    required this.parts,
    required this.ok,
    required this.text,
  });

  factory PagerMessage.fromJson(Map<String, dynamic> j) => PagerMessage(
        timestampNs: (j['ts_ns'] as num?)?.toInt() ?? 0,
        ric: (j['ric'] as num?)?.toInt() ?? 0,
        fmt: (j['fmt'] as num?)?.toInt() ?? 0,
        seq: (j['seq'] as num?)?.toInt() ?? 0,
        parts: (j['parts'] as num?)?.toInt() ?? 0,
        ok: j['ok'] == true,
        text: j['text'] as String? ?? '',
      );

  String get title => 'RIC $ric';
  String get timeLabel => timeLabelFromNs(timestampNs);
}

class VoiceCallInfo {
  final int id;
  final double channelHz;
  final int startNs;
  final int endNs;
  final int frames;
  final double errorRatio;
  final bool active;
  final String wavPath;
  final double durationS;

  const VoiceCallInfo({
    required this.id,
    required this.channelHz,
    required this.startNs,
    required this.endNs,
    required this.frames,
    required this.errorRatio,
    required this.active,
    required this.wavPath,
    required this.durationS,
  });

  factory VoiceCallInfo.fromJson(Map<String, dynamic> j) => VoiceCallInfo(
        id: (j['id'] as num?)?.toInt() ?? 0,
        channelHz: (j['channel_hz'] as num?)?.toDouble() ?? 0,
        startNs: (j['start_ns'] as num?)?.toInt() ?? 0,
        endNs: (j['end_ns'] as num?)?.toInt() ?? 0,
        frames: (j['frames'] as num?)?.toInt() ?? 0,
        errorRatio: (j['error_ratio'] as num?)?.toDouble() ?? 1,
        active: j['active'] == true,
        wavPath: j['wav_path'] as String? ?? '',
        durationS: (j['duration_s'] as num?)?.toDouble() ?? 0,
      );

  String get title =>
      '${(channelHz / 1e6).toStringAsFixed(4)} MHz';
  String get timeLabel => timeLabelFromNs(startNs);
  int get quality => ((1.0 - errorRatio) * 100).clamp(0, 100).round();
}

class SatelliteInfo {
  final int id;
  final double lat;
  final double lon;
  final int altKm;
  final int beam;
  final int lastSeenNs;
  final int count;
  final bool hasPos;

  const SatelliteInfo({
    required this.id,
    required this.lat,
    required this.lon,
    required this.altKm,
    required this.beam,
    required this.lastSeenNs,
    required this.count,
    required this.hasPos,
  });

  factory SatelliteInfo.fromJson(Map<String, dynamic> j) => SatelliteInfo(
        id: (j['id'] as num?)?.toInt() ?? 0,
        lat: (j['lat'] as num?)?.toDouble() ?? 0,
        lon: (j['lon'] as num?)?.toDouble() ?? 0,
        altKm: (j['alt_km'] as num?)?.toInt() ?? 0,
        beam: (j['beam'] as num?)?.toInt() ?? 0,
        lastSeenNs: (j['last_seen_ns'] as num?)?.toInt() ?? 0,
        count: (j['count'] as num?)?.toInt() ?? 0,
        hasPos: j['has_pos'] == true,
      );
}

class GroundBeamInfo {
  final int sat;
  final int beam;
  final double lat;
  final double lon;
  final int altKm;
  final int lastSeenNs;
  final int count;
  final int pages;
  final bool hasPos;

  const GroundBeamInfo({
    required this.sat,
    required this.beam,
    required this.lat,
    required this.lon,
    required this.altKm,
    required this.lastSeenNs,
    required this.count,
    required this.pages,
    required this.hasPos,
  });

  factory GroundBeamInfo.fromJson(Map<String, dynamic> j) => GroundBeamInfo(
        sat: (j['sat'] as num?)?.toInt() ?? 0,
        beam: (j['beam'] as num?)?.toInt() ?? 0,
        lat: (j['lat'] as num?)?.toDouble() ?? 0,
        lon: (j['lon'] as num?)?.toDouble() ?? 0,
        altKm: (j['alt_km'] as num?)?.toInt() ?? 0,
        lastSeenNs: (j['last_seen_ns'] as num?)?.toInt() ?? 0,
        count: (j['count'] as num?)?.toInt() ?? 0,
        pages: (j['pages'] as num?)?.toInt() ?? 0,
        hasPos: j['has_pos'] == true,
      );
}
