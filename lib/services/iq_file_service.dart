import 'package:flutter/services.dart';

class IqFileHandle {
  final int fd;
  final String name;
  final int size;

  const IqFileHandle({
    required this.fd,
    required this.name,
    required this.size,
  });
}

class IqFileService {
  static const _channel = MethodChannel('dev.sarahsforge.iridiscope/files');

  /// Launches Android's SAF picker and returns an open descriptor for the
  /// original file. No cache copy is made, so multi-gigabyte recordings work.
  Future<IqFileHandle?> pick() async {
    final result =
        await _channel.invokeMethod<Map<dynamic, dynamic>>('pickIqFile');
    if (result == null) return null;
    return IqFileHandle(
      fd: (result['fd'] as num).toInt(),
      name: result['name'] as String? ?? 'iq-file',
      size: (result['size'] as num?)?.toInt() ?? 0,
    );
  }

  Future<void> close(IqFileHandle? handle) async {
    if (handle == null) return;
    try {
      await _channel.invokeMethod<bool>('closeIqFile', {'fd': handle.fd});
    } catch (_) {
      // The activity may already be gone.
    }
  }
}
