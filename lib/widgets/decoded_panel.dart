import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/decoded_models.dart';
import '../services/iridiscope_service.dart';

class DecodedPanel extends StatefulWidget {
  const DecodedPanel({super.key});

  @override
  State<DecodedPanel> createState() => _DecodedPanelState();
}

class _DecodedPanelState extends State<DecodedPanel> {
  String _tab = 'ACARS';

  static const _tabs = ['ACARS', 'SBD', 'SMS', 'PAGER'];

  @override
  Widget build(BuildContext context) {
    final service = context.watch<IridiScopeService>();
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: Row(
              children: [
                Text('DECODED TRAFFIC',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Colors.grey,
                          letterSpacing: 1.4,
                          fontWeight: FontWeight.w700,
                        )),
                const Spacer(),
                Text(
                  '${service.acars.length + service.sbd.length + service.sms.length + service.pager.length}',
                  style: const TextStyle(
                      fontSize: 11,
                      color: Colors.white54,
                      fontFamily: 'monospace'),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              children: [
                for (final t in _tabs)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      label: Text(t, style: const TextStyle(fontSize: 11)),
                      selected: _tab == t,
                      visualDensity: VisualDensity.compact,
                      onSelected: (_) => setState(() => _tab = t),
                    ),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(child: _list(service)),
        ],
      ),
    );
  }

  Widget _list(IridiScopeService service) {
    switch (_tab) {
      case 'ACARS':
        return _emptyOrList(
          service.acars,
          (AcarsMessage m) => _AcarsTile(message: m),
        );
      case 'SBD':
        return _emptyOrList(
          service.sbd,
          (SbdMessage m) => _SbdTile(message: m),
        );
      case 'SMS':
        return _emptyOrList(
          service.sms,
          (SmsMessage m) => _SmsTile(message: m),
        );
      default:
        return _emptyOrList(
          service.pager,
          (PagerMessage m) => _PagerTile(message: m),
        );
    }
  }

  Widget _emptyOrList<T>(List<T> items, Widget Function(T) builder) {
    if (items.isEmpty) {
      return const Center(
        child: Text('No messages decoded yet',
            style: TextStyle(color: Colors.white38, fontSize: 12)),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: items.length,
      separatorBuilder: (_, __) =>
          const Divider(height: 1, indent: 12, endIndent: 12),
      itemBuilder: (_, i) => builder(items[items.length - 1 - i]),
    );
  }
}

class _AcarsTile extends StatelessWidget {
  final AcarsMessage message;
  const _AcarsTile({required this.message});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      visualDensity: const VisualDensity(horizontal: -2, vertical: -2),
      leading: _Badge(
        text: message.label.isEmpty ? 'AC' : message.label,
        color: Colors.orangeAccent,
      ),
      title: Text(message.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 12)),
      subtitle: Text(
        message.text.isEmpty ? message.labelDesc : message.text,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 10.5, color: Colors.white54),
      ),
      trailing: Text(message.timeLabel,
          style: const TextStyle(
              fontSize: 10, color: Colors.white38, fontFamily: 'monospace')),
      onTap: () => _showDetails(context, 'ACARS', {
        'Registration': message.reg,
        'Flight': message.flight,
        'Mode': message.mode,
        'Ack': message.ack,
        'Label': '${message.label} ${message.labelDesc}',
        'BID': message.bid,
        'Sequence': message.seqn,
        'Text': message.text,
        'Raw': message.rawHex,
        'Errors': message.errors,
        'CRC': message.crcOk ? 'OK' : 'BAD',
      }),
    );
  }
}

class _SbdTile extends StatelessWidget {
  final SbdMessage message;
  const _SbdTile({required this.message});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      visualDensity: const VisualDensity(horizontal: -2, vertical: -2),
      leading: _Badge(
        text: 'SBD',
        color: message.hasNal ? Colors.greenAccent : Colors.tealAccent,
      ),
      title: Text(message.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 12)),
      subtitle: Text(
        message.text.isNotEmpty
            ? message.text
            : '${message.length} bytes  ·  ${message.type}',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 10.5, color: Colors.white54),
      ),
      trailing: Text(message.timeLabel,
          style: const TextStyle(
              fontSize: 10, color: Colors.white38, fontFamily: 'monospace')),
      onTap: () => _showDetails(context, 'SBD', {
        'Type': message.type,
        'Length': '${message.length}',
        'Info': message.info,
        'Text': message.text,
        'Payload': message.payloadHex,
        'Preheader': message.preheaderHex,
        'CRC': message.hasCrc ? (message.crcOk ? 'OK' : 'BAD') : 'none',
        if (message.hasNal) 'NAL position': '${message.nalLat}, ${message.nalLon}',
        if (message.hasNal) 'NAL info': message.nalInfo,
        if (message.hasNal) 'Emergency': '${message.nalEmergency}',
      }),
    );
  }
}

class _SmsTile extends StatelessWidget {
  final SmsMessage message;
  const _SmsTile({required this.message});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      visualDensity: const VisualDensity(horizontal: -2, vertical: -2),
      leading: const _Badge(text: 'SMS', color: Colors.purpleAccent),
      title: Text(message.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 12)),
      subtitle: Text(message.text,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 10.5, color: Colors.white54)),
      trailing: Text(message.timeLabel,
          style: const TextStyle(
              fontSize: 10, color: Colors.white38, fontFamily: 'monospace')),
      onTap: () => _showDetails(context, 'SMS', {
        'From': message.from,
        'To': message.to,
        'DCS': message.dcs,
        'Text': message.text,
        'Decoded': message.ok ? 'yes' : 'no',
      }),
    );
  }
}

class _PagerTile extends StatelessWidget {
  final PagerMessage message;
  const _PagerTile({required this.message});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      visualDensity: const VisualDensity(horizontal: -2, vertical: -2),
      leading: const _Badge(text: 'MSG', color: Colors.blueAccent),
      title: Text(message.title,
          style: const TextStyle(fontSize: 12)),
      subtitle: Text(message.text,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 10.5, color: Colors.white54)),
      trailing: Text(message.timeLabel,
          style: const TextStyle(
              fontSize: 10, color: Colors.white38, fontFamily: 'monospace')),
      onTap: () => _showDetails(context, 'Pager', {
        'RIC': '${message.ric}',
        'Format': '${message.fmt}',
        'Sequence': '${message.seq}/${message.parts}',
        'Text': message.text,
        'Valid': message.ok ? 'yes' : 'no',
      }),
    );
  }
}

class _Badge extends StatelessWidget {
  final String text;
  final Color color;
  const _Badge({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Text(text,
          style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              fontFamily: 'monospace')),
    );
  }
}

void _showDetails(BuildContext context, String title, Map<String, String> rows) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(ctx).textTheme.titleMedium),
            const SizedBox(height: 12),
            for (final r in rows.entries)
              if (r.value.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 110,
                        child: Text(r.key,
                            style: const TextStyle(
                                color: Colors.grey, fontSize: 12)),
                      ),
                      Expanded(
                        child: SelectableText(r.value,
                            style: const TextStyle(
                                fontSize: 12, fontFamily: 'monospace')),
                      ),
                    ],
                  ),
                ),
          ],
        ),
      ),
    ),
  );
}
