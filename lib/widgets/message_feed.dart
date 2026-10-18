import 'package:flutter/material.dart';

import '../models/iridium_message.dart';

class MessageFeed extends StatefulWidget {
  final List<IridiumMessage> messages;
  final VoidCallback onClear;

  const MessageFeed({
    super.key,
    required this.messages,
    required this.onClear,
  });

  @override
  State<MessageFeed> createState() => _MessageFeedState();
}

class _MessageFeedState extends State<MessageFeed> {
  String _filter = 'ALL';

  static const _filters = ['ALL', 'IRA', 'IBC', 'IDA', 'IMS'];

  List<IridiumMessage> get _filtered {
    if (_filter == 'ALL') return widget.messages;
    return widget.messages.where((m) => m.type == _filter).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 8, 0),
            child: Row(
              children: [
                Text('DECODED MESSAGES',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Colors.grey,
                          letterSpacing: 1.4,
                          fontWeight: FontWeight.w700,
                        )),
                const SizedBox(width: 8),
                Text('${widget.messages.length}',
                    style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 11,
                        fontFamily: 'monospace')),
                const Spacer(),
                IconButton(
                  tooltip: 'Clear',
                  visualDensity: VisualDensity.compact,
                  onPressed: widget.onClear,
                  icon: const Icon(Icons.clear_all, size: 18),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 34,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              children: [
                for (final f in _filters)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      label: Text(f, style: const TextStyle(fontSize: 11)),
                      selected: _filter == f,
                      visualDensity: VisualDensity.compact,
                      onSelected: (_) => setState(() => _filter = f),
                    ),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: filtered.isEmpty
                ? const Center(
                    child: Text('Waiting for Iridium bursts...',
                        style:
                            TextStyle(color: Colors.white38, fontSize: 12)))
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) =>
                        const Divider(height: 1, indent: 12, endIndent: 12),
                    itemBuilder: (context, index) =>
                        _MessageTile(message: filtered[index]),
                  ),
          ),
        ],
      ),
    );
  }
}

class _MessageTile extends StatelessWidget {
  final IridiumMessage message;

  const _MessageTile({required this.message});

  Color get _color {
    switch (message.type) {
      case 'IRA':
        return Colors.cyanAccent;
      case 'IBC':
        return Colors.greenAccent;
      case 'IDA':
        return Colors.orangeAccent;
      case 'IMS':
        return Colors.purpleAccent;
      case 'VO':
      case 'VOC':
      case 'VOD':
        return Colors.pinkAccent;
      default:
        return Colors.blueGrey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      visualDensity: const VisualDensity(horizontal: -2, vertical: -2),
      leading: Container(
        width: 42,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(vertical: 3),
        decoration: BoxDecoration(
          color: _color.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: _color.withValues(alpha: 0.5)),
        ),
        child: Text(message.type,
            style: TextStyle(
                color: _color,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                fontFamily: 'monospace')),
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              message.pretty.isEmpty ? message.type : message.pretty,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12),
            ),
          ),
          if (message.timeLabel.isNotEmpty)
            Text(message.timeLabel,
                style: const TextStyle(
                    fontSize: 10,
                    color: Colors.white38,
                    fontFamily: 'monospace')),
        ],
      ),
      subtitle: message.subtitle.isEmpty
          ? null
          : Text(message.subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 10.5, color: Colors.white54)),
      trailing: message.error
          ? const Icon(Icons.warning_amber, size: 14, color: Colors.orange)
          : null,
      onTap: () => _showDetails(context, message),
    );
  }

  void _showDetails(BuildContext context, IridiumMessage m) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        final rows = <MapEntry<String, String>>[
          MapEntry('Type', m.type),
          MapEntry('Frequency', m.frequencyLabel),
          MapEntry('Time', m.timeLabel),
          MapEntry('Confidence', '${m.confidence}%'),
          MapEntry('Direction', m.uplink != 0 ? 'Uplink' : 'Downlink'),
          MapEntry('Symbols', '${m.symbols}'),
          if (m.ira != null) MapEntry('IRA', _mapText(m.ira!)),
          if (m.ibc != null) MapEntry('IBC', _mapText(m.ibc!)),
          if (m.ida != null) MapEntry('IDA', _mapText(m.ida!)),
          if (m.ims != null) MapEntry('IMS', _mapText(m.ims!)),
        ];
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(m.pretty.isEmpty ? m.type : m.pretty,
                    style: Theme.of(ctx).textTheme.titleMedium),
                const SizedBox(height: 12),
                for (final r in rows)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 92,
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
        );
      },
    );
  }

  String _mapText(Map<String, dynamic> map) {
    return map.entries
        .map((e) => '${e.key}=${e.value}')
        .where((s) => !s.endsWith('='))
        .join('  ');
  }
}
