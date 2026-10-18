import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/waterfall_settings.dart';
import '../services/iridiscope_service.dart';
import '../widgets/control_panel.dart';
import '../widgets/decoded_panel.dart';
import '../widgets/iridium_map.dart';
import '../widgets/message_feed.dart';
import '../widgets/spectrum_waterfall.dart';
import '../widgets/voice_panel.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  WaterfallSettings _settings = const WaterfallSettings();

  Future<void> _startHackRf() async {
    final service = context.read<IridiScopeService>();
    await service.startHackRf(
      centerHz: service.centerHz,
      sampleRate: _settings.sampleRateHz,
      fftSize: _settings.fftSize,
      lna: service.lna,
      vga: service.vga,
      amp: service.amp,
      biasTee: service.biasTee,
    );
    if (!mounted) return;
    setState(() {
      _settings = _settings.copyWith(sampleRateHz: service.sampleRate);
    });
  }

  Future<void> _pickFile() async {
    final service = context.read<IridiScopeService>();
    final file = await service.files.pick();
    if (file == null) return;
    await service.startFile(file, fftSize: _settings.fftSize);
    if (!mounted) return;
    setState(() {
      _settings = _settings.copyWith(sampleRateHz: service.sampleRate);
    });
  }

  Future<void> _stop() async {
    await context.read<IridiScopeService>().stop();
  }

  void _tune(int hz) {
    final clamped = hz.clamp(1616000000, 1626500000);
    context.read<IridiScopeService>().setFrequency(clamped);
  }

  @override
  Widget build(BuildContext context) {
    final service = context.watch<IridiScopeService>();
    final content = _buildContent(service);

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 12,
        title: const Row(
          children: [
            Icon(Icons.satellite_alt, size: 20, color: Colors.cyanAccent),
            SizedBox(width: 8),
            Text('IridiScope Mobile',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          ],
        ),
        actions: [
          _StatusChip(service: service),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(child: content),
    );
  }

  Widget _buildContent(IridiScopeService service) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 900;
        if (wide) {
          return Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                SizedBox(width: 340, child: _controls(service)),
                const SizedBox(width: 8),
                Expanded(child: _display(service)),
              ],
            ),
          );
        }

        return DefaultTabController(
          length: 6,
          child: Column(
            children: [
              const TabBar(
                isScrollable: true,
                tabs: [
                  Tab(text: 'WATERFALL'),
                  Tab(text: 'MESSAGES'),
                  Tab(text: 'ACARS'),
                  Tab(text: 'VOICE'),
                  Tab(text: 'MAP'),
                  Tab(text: 'CONTROLS'),
                ],
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: _waterfall(service),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: _messages(service),
                    ),
                    const Padding(
                      padding: EdgeInsets.all(8),
                      child: DecodedPanel(),
                    ),
                    const Padding(
                      padding: EdgeInsets.all(8),
                      child: VoicePanel(),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: _map(service),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: _controls(service),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _display(IridiScopeService service) {
    return Column(
      children: [
        Expanded(flex: 5, child: _waterfall(service)),
        const SizedBox(height: 8),
        Expanded(flex: 4, child: _decodedTabs(service)),
      ],
    );
  }

  Widget _decodedTabs(IridiScopeService service) {
    return DefaultTabController(
      length: 4,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            const TabBar(
              tabs: [
                Tab(text: 'MESSAGES'),
                Tab(text: 'ACARS'),
                Tab(text: 'VOICE'),
                Tab(text: 'MAP'),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  MessageFeed(
                    messages: service.messages,
                    onClear: service.clearMessages,
                  ),
                  const DecodedPanel(),
                  const VoicePanel(),
                  _map(service),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _map(IridiScopeService service) {
    return IridiumMap(
      satellites: service.satellites,
      beams: service.beams,
    );
  }

  Widget _waterfall(IridiScopeService service) {
    return SpectrumWaterfall(
      spectrumStream: service.spectrumStream,
      settings: _settings,
      centerHz: service.centerHz,
      sampleRateHz: service.sampleRate > 0
          ? service.sampleRate
          : _settings.sampleRateHz,
      onTune: _tune,
    );
  }

  Widget _messages(IridiScopeService service) {
    return MessageFeed(
      messages: service.messages,
      onClear: service.clearMessages,
    );
  }

  Widget _controls(IridiScopeService service) {
    return ControlPanel(
      settings: _settings,
      onSettingsChanged: (s) => setState(() => _settings = s),
      onStartHackRf: _startHackRf,
      onPickFile: _pickFile,
      onStop: _stop,
      onClearMessages: service.clearMessages,
    );
  }
}

class _StatusChip extends StatelessWidget {
  final IridiScopeService service;
  const _StatusChip({required this.service});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (service.state) {
      IridiScopeState.idle => ('IDLE', Colors.blueGrey),
      IridiScopeState.starting => ('STARTING', Colors.orange),
      IridiScopeState.running => ('RUNNING', Colors.greenAccent),
      IridiScopeState.paused => ('PAUSED', Colors.amber),
      IridiScopeState.error => ('ERROR', Colors.redAccent),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(
                  color: color, fontSize: 10, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
