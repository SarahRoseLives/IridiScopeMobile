enum WaterfallColorScheme { viridis, turbo, grayscale }

class WaterfallSettings {
  final int fftSize;
  final int sampleRateHz;
  final double minDb;
  final double maxDb;
  final int waterfallRows;
  final WaterfallColorScheme colorScheme;

  const WaterfallSettings({
    this.fftSize = 4096,
    this.sampleRateHz = 2400000,
    this.minDb = -80,
    this.maxDb = -20,
    this.waterfallRows = 180,
    this.colorScheme = WaterfallColorScheme.viridis,
  });

  WaterfallSettings copyWith({
    int? fftSize,
    int? sampleRateHz,
    double? minDb,
    double? maxDb,
    int? waterfallRows,
    WaterfallColorScheme? colorScheme,
  }) {
    return WaterfallSettings(
      fftSize: fftSize ?? this.fftSize,
      sampleRateHz: sampleRateHz ?? this.sampleRateHz,
      minDb: minDb ?? this.minDb,
      maxDb: maxDb ?? this.maxDb,
      waterfallRows: waterfallRows ?? this.waterfallRows,
      colorScheme: colorScheme ?? this.colorScheme,
    );
  }

  static String formatRate(int hz) {
    if (hz >= 1000000) {
      final mhz = hz / 1000000.0;
      return '${mhz.toStringAsFixed(mhz == mhz.roundToDouble() ? 0 : 1)} MHz';
    }
    return '${(hz / 1000).toStringAsFixed(0)} kHz';
  }

  static const List<int> hackRfRates = [
    2000000,
    2400000,
    4000000,
    6000000,
    8000000,
    10000000,
  ];
}
