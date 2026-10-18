class IridiumMessage {
  final int seq;
  final String type;
  final String pretty;
  final double frequencyHz;
  final int timestampNs;
  final int confidence;
  final int uplink;
  final int symbols;
  final bool error;
  final Map<String, dynamic>? ira;
  final Map<String, dynamic>? ibc;
  final Map<String, dynamic>? ida;
  final Map<String, dynamic>? ims;

  const IridiumMessage({
    required this.seq,
    required this.type,
    required this.pretty,
    required this.frequencyHz,
    required this.timestampNs,
    required this.confidence,
    required this.uplink,
    required this.symbols,
    required this.error,
    this.ira,
    this.ibc,
    this.ida,
    this.ims,
  });

  factory IridiumMessage.fromJson(Map<String, dynamic> json) {
    return IridiumMessage(
      seq: (json['seq'] as num?)?.toInt() ?? 0,
      type: json['type'] as String? ?? '?',
      pretty: json['pretty'] as String? ?? '',
      frequencyHz: (json['freq'] as num?)?.toDouble() ?? 0,
      timestampNs: (json['ts_ns'] as num?)?.toInt() ?? 0,
      confidence: (json['confidence'] as num?)?.toInt() ?? 0,
      uplink: (json['uplink'] as num?)?.toInt() ?? 0,
      symbols: (json['symbols'] as num?)?.toInt() ?? 0,
      error: json['error'] == true,
      ira: json['ira'] as Map<String, dynamic>?,
      ibc: json['ibc'] as Map<String, dynamic>?,
      ida: json['ida'] as Map<String, dynamic>?,
      ims: json['ims'] as Map<String, dynamic>?,
    );
  }

  String get frequencyLabel =>
      frequencyHz > 0 ? '${(frequencyHz / 1e6).toStringAsFixed(4)} MHz' : '';

  String get timeLabel {
    if (timestampNs <= 0) return '';
    final d = DateTime.fromMicrosecondsSinceEpoch(timestampNs ~/ 1000);
    return '${d.hour.toString().padLeft(2, '0')}:'
        '${d.minute.toString().padLeft(2, '0')}:'
        '${d.second.toString().padLeft(2, '0')}';
  }

  String get subtitle {
    final parts = <String>[];
    if (frequencyLabel.isNotEmpty) parts.add(frequencyLabel);
    if (ira != null) {
      parts.add('SAT ${ira!['sat']} / BEAM ${ira!['beam']}');
      final lat = (ira!['lat'] as num?)?.toDouble() ?? 0;
      final lon = (ira!['lon'] as num?)?.toDouble() ?? 0;
      if (lat != 0 || lon != 0) {
        parts.add('${lat.toStringAsFixed(2)}, ${lon.toStringAsFixed(2)}');
      }
    }
    if (ibc != null) parts.add('SAT ${ibc!['sat']} / BEAM ${ibc!['beam']}');
    if (ida != null) {
      final text = ida!['text'] as String? ?? '';
      if (text.isNotEmpty) parts.add(text);
    }
    if (ims != null) {
      final text = ims!['text'] as String? ?? '';
      if (text.isNotEmpty) parts.add(text);
    }
    if (confidence > 0) parts.add('$confidence%');
    return parts.join('  ·  ');
  }
}

class RadioStats {
  final int samples;
  final int totalSamples;
  final int bursts;
  final int framesOk;
  final int framesFail;
  final int messages;
  final int droppedSamples;
  final double elapsedS;
  final double rateSps;
  final bool running;
  final bool paused;
  final bool done;
  final int fftSize;
  final int sampleRate;
  final double centerHz;
  final double floorDb;
  final double peakDb;

  const RadioStats({
    this.samples = 0,
    this.totalSamples = 0,
    this.bursts = 0,
    this.framesOk = 0,
    this.framesFail = 0,
    this.messages = 0,
    this.droppedSamples = 0,
    this.elapsedS = 0,
    this.rateSps = 0,
    this.running = false,
    this.paused = false,
    this.done = false,
    this.fftSize = 0,
    this.sampleRate = 0,
    this.centerHz = 0,
    this.floorDb = -120,
    this.peakDb = -120,
  });

  factory RadioStats.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const RadioStats();
    return RadioStats(
      samples: (json['samples'] as num?)?.toInt() ?? 0,
      totalSamples: (json['total_samples'] as num?)?.toInt() ?? 0,
      bursts: (json['bursts'] as num?)?.toInt() ?? 0,
      framesOk: (json['frames_ok'] as num?)?.toInt() ?? 0,
      framesFail: (json['frames_fail'] as num?)?.toInt() ?? 0,
      messages: (json['messages'] as num?)?.toInt() ?? 0,
      droppedSamples: (json['dropped_samples'] as num?)?.toInt() ?? 0,
      elapsedS: (json['elapsed_s'] as num?)?.toDouble() ?? 0,
      rateSps: (json['rate_sps'] as num?)?.toDouble() ?? 0,
      running: json['running'] == true,
      paused: json['paused'] == true,
      done: json['done'] == true,
      fftSize: (json['fft_size'] as num?)?.toInt() ?? 0,
      sampleRate: (json['sample_rate'] as num?)?.toInt() ?? 0,
      centerHz: (json['center_hz'] as num?)?.toDouble() ?? 0,
      floorDb: (json['floor_db'] as num?)?.toDouble() ?? -120,
      peakDb: (json['peak_db'] as num?)?.toDouble() ?? -120,
    );
  }
}
