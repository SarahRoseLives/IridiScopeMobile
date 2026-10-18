import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/decoded_models.dart';
import '../services/iridiscope_service.dart';

class VoicePanel extends StatelessWidget {
  const VoicePanel({super.key});

  @override
  Widget build(BuildContext context) {
    final service = context.watch<IridiScopeService>();
    final calls = service.voiceCalls;
    final active = calls.where((c) => c.active).length;
    final playingId = service.playingVoiceId;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 8, 0),
            child: Row(
              children: [
                Text('VOICE CALLS',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Colors.grey,
                          letterSpacing: 1.4,
                          fontWeight: FontWeight.w700,
                        )),
                const SizedBox(width: 8),
                Text(
                  active > 0 ? '$active active' : '${calls.length}',
                  style: const TextStyle(
                      fontSize: 11,
                      color: Colors.white54,
                      fontFamily: 'monospace'),
                ),
                const Spacer(),
                Text('AUTO',
                    style: TextStyle(
                        fontSize: 10,
                        color: service.autoPlayVoice
                            ? Colors.cyanAccent
                            : Colors.white38,
                        fontWeight: FontWeight.w700)),
                Transform.scale(
                  scale: 0.75,
                  child: Switch(
                    value: service.autoPlayVoice,
                    onChanged: service.setAutoPlayVoice,
                  ),
                ),
                IconButton(
                  tooltip: 'Stop playback',
                  visualDensity: VisualDensity.compact,
                  onPressed: playingId == null ? null : service.stopVoice,
                  icon: const Icon(Icons.stop_circle_outlined, size: 18),
                ),
              ],
            ),
          ),
          if (service.queuedVoiceCount > 0)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                '${service.queuedVoiceCount} call(s) queued for playback',
                style: const TextStyle(fontSize: 10, color: Colors.white54),
              ),
            ),
          const Divider(height: 1),
          Expanded(
            child: calls.isEmpty
                ? const Center(
                    child: Text('Waiting for AMBE voice frames...',
                        style:
                            TextStyle(color: Colors.white38, fontSize: 12)))
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    itemCount: calls.length,
                    separatorBuilder: (_, __) =>
                        const Divider(height: 1, indent: 12, endIndent: 12),
                    itemBuilder: (_, i) {
                      final call = calls[calls.length - 1 - i];
                      final playing = playingId == call.id;
                      final canPlay =
                          call.wavPath.isNotEmpty && !call.active;
                      return ListTile(
                        dense: true,
                        visualDensity: const VisualDensity(
                            horizontal: -2, vertical: -2),
                        leading: IconButton(
                          icon: Icon(
                            playing
                                ? Icons.stop
                                : canPlay
                                    ? Icons.play_arrow
                                    : Icons.hourglass_empty,
                            size: 20,
                            color: canPlay
                                ? Colors.cyanAccent
                                : Colors.white24,
                          ),
                          onPressed: canPlay
                              ? () => playing
                                  ? service.stopVoice()
                                  : service.playVoice(call)
                              : null,
                        ),
                        title: Text(call.title,
                            style: const TextStyle(fontSize: 12)),
                        subtitle: Text(
                          '${call.durationS.toStringAsFixed(1)} s  ·  '
                          '${call.frames} frames  ·  '
                          '${call.quality}% quality',
                          style: const TextStyle(
                              fontSize: 10.5, color: Colors.white54),
                        ),
                        trailing: Text(
                          call.active ? 'LIVE' : call.timeLabel,
                          style: TextStyle(
                              fontSize: 10,
                              color: call.active
                                  ? Colors.greenAccent
                                  : Colors.white38,
                              fontFamily: 'monospace'),
                        ),
                        onTap: canPlay
                            ? () => playing
                                ? service.stopVoice()
                                : service.playVoice(call)
                            : null,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
