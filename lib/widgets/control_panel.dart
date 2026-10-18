import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/waterfall_settings.dart';
import '../services/iridiscope_service.dart';

class ControlPanel extends StatelessWidget {
  final WaterfallSettings settings;
  final ValueChanged<WaterfallSettings> onSettingsChanged;
  final Future<void> Function() onStartHackRf;
  final Future<void> Function() onPickFile;
  final Future<void> Function() onStop;
  final VoidCallback onClearMessages;

  const ControlPanel({
    super.key,
    required this.settings,
    required this.onSettingsChanged,
    required this.onStartHackRf,
    required this.onPickFile,
    required this.onStop,
    required this.onClearMessages,
  });

  @override
  Widget build(BuildContext context) {
    final service = context.watch<IridiScopeService>();
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SourceCard(
            service: service,
            onStartHackRf: onStartHackRf,
            onPickFile: onPickFile,
            onStop: onStop,
          ),
          const SizedBox(height: 8),
          _FrequencyCard(service: service),
          if (service.source == SourceKind.hackRf) ...[
            const SizedBox(height: 8),
            _HackRfCard(service: service),
          ],
          if (service.source == SourceKind.file) ...[
            const SizedBox(height: 8),
            _FileCard(service: service),
          ],
          const SizedBox(height: 8),
          _SpectrumCard(
            service: service,
            settings: settings,
            onChanged: onSettingsChanged,
          ),
          const SizedBox(height: 8),
          _StatsCard(service: service, onClearMessages: onClearMessages),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Colors.grey,
              letterSpacing: 1.4,
              fontWeight: FontWeight.w700,
            ));
  }
}

class _SourceCard extends StatelessWidget {
  final IridiScopeService service;
  final Future<void> Function() onStartHackRf;
  final Future<void> Function() onPickFile;
  final Future<void> Function() onStop;

  const _SourceCard({
    required this.service,
    required this.onStartHackRf,
    required this.onPickFile,
    required this.onStop,
  });

  @override
  Widget build(BuildContext context) {
    final running = service.state == IridiScopeState.running ||
        service.state == IridiScopeState.paused;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _SectionTitle('SOURCE'),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: service.state == IridiScopeState.starting
                        ? null
                        : onStartHackRf,
                    icon: const Icon(Icons.usb, size: 16),
                    label: Text(running && service.source == SourceKind.hackRf
                        ? 'RESTART HACKRF'
                        : 'HACKRF'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: service.state == IridiScopeState.starting
                        ? null
                        : onPickFile,
                    icon: const Icon(Icons.folder_open, size: 16),
                    label: const Text('IQ FILE'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: running ? onStop : null,
              icon: const Icon(Icons.stop, size: 16),
              label: const Text('STOP'),
            ),
            if (service.error != null) ...[
              const SizedBox(height: 8),
              Text(service.error!,
                  style: const TextStyle(color: Colors.redAccent, fontSize: 11)),
            ],
          ],
        ),
      ),
    );
  }
}

class _FrequencyCard extends StatelessWidget {
  final IridiScopeService service;
  const _FrequencyCard({required this.service});

  @override
  Widget build(BuildContext context) {
    final mhz = service.centerHz / 1e6;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _SectionTitle('FREQUENCY'),
            const SizedBox(height: 4),
            Text('${mhz.toStringAsFixed(6)} MHz',
                style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'monospace',
                    letterSpacing: 0.5)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: [
                for (final d in [-100000, -10000, -1000, 1000, 10000, 100000])
                  ActionChip(
                    visualDensity: VisualDensity.compact,
                    label: Text('${d > 0 ? '+' : ''}${d ~/ 1000}k',
                        style: const TextStyle(fontSize: 10)),
                    onPressed: () =>
                        service.setFrequency(service.centerHz + d),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _HackRfCard extends StatelessWidget {
  final IridiScopeService service;
  const _HackRfCard({required this.service});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _SectionTitle('HACKRF'),
            const SizedBox(height: 6),
            Row(
              children: [
                const Text('Sample rate', style: TextStyle(fontSize: 12)),
                const Spacer(),
                DropdownButton<int>(
                  value: WaterfallSettings.hackRfRates.contains(service.sampleRate)
                      ? service.sampleRate
                      : WaterfallSettings.hackRfRates.first,
                  items: [
                    for (final r in WaterfallSettings.hackRfRates)
                      DropdownMenuItem(
                          value: r,
                          child: Text(WaterfallSettings.formatRate(r),
                              style: const TextStyle(fontSize: 12))),
                  ],
                  onChanged: (v) {
                    if (v != null) service.restartHackRf(sampleRate: v);
                  },
                ),
              ],
            ),
            _SliderRow(
              label: 'LNA',
              value: service.lna.toDouble(),
              min: 0,
              max: 40,
              divisions: 5,
              valueLabel: '${service.lna} dB',
              onChanged: (v) => service.setLna(v.round()),
            ),
            _SliderRow(
              label: 'VGA',
              value: service.vga.toDouble(),
              min: 0,
              max: 62,
              divisions: 31,
              valueLabel: '${service.vga} dB',
              onChanged: (v) => service.setVga(v.round()),
            ),
            SwitchListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: const Text('Amp', style: TextStyle(fontSize: 12)),
              value: service.amp,
              onChanged: service.setAmp,
            ),
            SwitchListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: const Text('Bias tee / antenna power',
                  style: TextStyle(fontSize: 12)),
              value: service.biasTee,
              onChanged: service.setBiasTee,
            ),
          ],
        ),
      ),
    );
  }
}

class _FileCard extends StatelessWidget {
  final IridiScopeService service;
  const _FileCard({required this.service});

  @override
  Widget build(BuildContext context) {
    final info = service.fileInfo;
    final stats = service.stats;
    final total = stats.totalSamples > 0 ? stats.totalSamples : 1;
    final pos = stats.samples.clamp(0, total);
    final name = info?['path'] as String? ?? 'IQ file';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _SectionTitle('IQ FILE'),
            const SizedBox(height: 4),
            Text(name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12)),
            const SizedBox(height: 4),
            if (info != null)
              Text(
                '${info['format']}  ·  '
                '${WaterfallSettings.formatRate((info['sample_rate'] as num?)?.toInt() ?? 0)}  ·  '
                '${((info['duration_s'] as num?)?.toDouble() ?? 0).toStringAsFixed(1)} s',
                style: const TextStyle(fontSize: 11, color: Colors.white54),
              ),
            const SizedBox(height: 6),
            Row(
              children: [
                IconButton(
                  onPressed: () => service.setPaused(!service.isPaused),
                  icon: Icon(service.isPaused ? Icons.play_arrow : Icons.pause,
                      size: 20),
                ),
                Expanded(
                  child: Slider(
                    value: pos.toDouble(),
                    max: total.toDouble(),
                    onChanged: (v) => service.seekSample(v.round()),
                  ),
                ),
              ],
            ),
            Row(
              children: [
                const Text('Real-time', style: TextStyle(fontSize: 11)),
                const Spacer(),
                Switch(
                  value: service.realtime,
                  onChanged: service.setRealtime,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SpectrumCard extends StatelessWidget {
  final IridiScopeService service;
  final WaterfallSettings settings;
  final ValueChanged<WaterfallSettings> onChanged;

  const _SpectrumCard({
    required this.service,
    required this.settings,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _SectionTitle('SPECTRUM'),
            const SizedBox(height: 6),
            Row(
              children: [
                const Text('FFT', style: TextStyle(fontSize: 12)),
                const Spacer(),
                DropdownButton<int>(
                  value: settings.fftSize,
                  items: const [
                    DropdownMenuItem(value: 1024, child: Text('1024')),
                    DropdownMenuItem(value: 2048, child: Text('2048')),
                    DropdownMenuItem(value: 4096, child: Text('4096')),
                    DropdownMenuItem(value: 8192, child: Text('8192')),
                  ],
                  onChanged: (v) {
                    if (v == null) return;
                    service.setFftSize(v);
                    onChanged(settings.copyWith(fftSize: v));
                  },
                ),
              ],
            ),
            Row(
              children: [
                const Text('Colour', style: TextStyle(fontSize: 12)),
                const Spacer(),
                DropdownButton<WaterfallColorScheme>(
                  value: settings.colorScheme,
                  items: const [
                    DropdownMenuItem(
                        value: WaterfallColorScheme.viridis,
                        child: Text('Viridis')),
                    DropdownMenuItem(
                        value: WaterfallColorScheme.turbo,
                        child: Text('Turbo')),
                    DropdownMenuItem(
                        value: WaterfallColorScheme.grayscale,
                        child: Text('Grey')),
                  ],
                  onChanged: (v) {
                    if (v != null) {
                      onChanged(settings.copyWith(colorScheme: v));
                    }
                  },
                ),
              ],
            ),
            Row(
              children: [
                Text('${settings.minDb.toInt()} … ${settings.maxDb.toInt()} dB',
                    style: const TextStyle(
                        fontSize: 11, fontFamily: 'monospace')),
                const Spacer(),
              ],
            ),
            RangeSlider(
              values: RangeValues(settings.minDb, settings.maxDb),
              min: -140,
              max: 0,
              divisions: 140,
              labels: RangeLabels(
                  settings.minDb.toInt().toString(),
                  settings.maxDb.toInt().toString()),
              onChanged: (r) {
                if (r.end - r.start < 10) return;
                onChanged(settings.copyWith(minDb: r.start, maxDb: r.end));
              },
            ),
            Row(
              children: [
                const Text('Rows', style: TextStyle(fontSize: 12)),
                Expanded(
                  child: Slider(
                    value: settings.waterfallRows.toDouble(),
                    min: 60,
                    max: 400,
                    divisions: 34,
                    onChanged: (v) => onChanged(
                        settings.copyWith(waterfallRows: v.round())),
                  ),
                ),
                Text('${settings.waterfallRows}',
                    style: const TextStyle(fontSize: 11)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatsCard extends StatelessWidget {
  final IridiScopeService service;
  final VoidCallback onClearMessages;

  const _StatsCard({required this.service, required this.onClearMessages});

  @override
  Widget build(BuildContext context) {
    final s = service.stats;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const _SectionTitle('STATS'),
                const Spacer(),
                TextButton(
                  onPressed: onClearMessages,
                  child: const Text('CLEAR', style: TextStyle(fontSize: 11)),
                ),
              ],
            ),
            _StatRow('Bursts', '${s.bursts}'),
            _StatRow('Frames OK', '${s.framesOk}'),
            _StatRow('Frames fail', '${s.framesFail}'),
            _StatRow('Messages', '${service.messages.length}'),
            _StatRow('Dropped', '${s.droppedSamples}'),
            _StatRow('Floor', '${s.floorDb.toStringAsFixed(1)} dB'),
            _StatRow('Peak', '${s.peakDb.toStringAsFixed(1)} dB'),
            if (s.totalSamples > 0)
              _StatRow(
                  'Progress',
                  '${(100 * s.samples / s.totalSamples).clamp(0, 100).toStringAsFixed(1)}%'),
          ],
        ),
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  final String label;
  final String value;
  const _StatRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Text(label,
              style: const TextStyle(fontSize: 11, color: Colors.white54)),
          const Spacer(),
          Text(value,
              style: const TextStyle(
                  fontSize: 11, fontFamily: 'monospace', color: Colors.white70)),
        ],
      ),
    );
  }
}

class _SliderRow extends StatelessWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final String valueLabel;
  final ValueChanged<double> onChanged;

  const _SliderRow({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.valueLabel,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
            width: 34,
            child: Text(label, style: const TextStyle(fontSize: 12))),
        Expanded(
          child: Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            divisions: divisions,
            onChanged: onChanged,
          ),
        ),
        SizedBox(
          width: 54,
          child: Text(valueLabel,
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 11, fontFamily: 'monospace')),
        ),
      ],
    );
  }
}
