import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../ffi/native_bindings.dart';
import '../models/decoded_models.dart';
import '../models/iridium_message.dart';
import 'hackrf_service.dart';
import 'iq_file_service.dart';

enum IridiScopeState { idle, starting, running, paused, error }

enum SourceKind { none, hackRf, file }

class IridiScopeService extends ChangeNotifier {
  final NativeBindings _native = NativeBindings.instance;
  final HackRfService hackrf = HackRfService();
  final IqFileService files = IqFileService();

  IridiScopeState _state = IridiScopeState.idle;
  SourceKind _source = SourceKind.none;
  String? _error;

  Pointer<Void>? _handle;
  Pointer<Float>? _instPtr;
  Pointer<Float>? _avgPtr;
  Float32List? _instView;
  Float32List? _avgView;

  Pointer<Uint8>? _eventsPtr;
  int _eventsCapacity = 256 * 1024;
  Pointer<Uint8>? _infoPtr;
  Pointer<Utf8>? _errPtr;

  int _fftSize = 4096;
  int _sampleRate = 2400000;
  int _centerHz = 1621250000;
  int _lna = 24;
  int _vga = 32;
  bool _amp = false;
  bool _biasTee = false;
  bool _realtime = true;

  Timer? _spectrumTimer;
  Timer? _eventTimer;
  Float32List? _latestSpectrum;

  final _spectrumCtrl = StreamController<Float32List>.broadcast();

  final List<IridiumMessage> _messages = [];
  List<AcarsMessage> _acars = const [];
  List<SbdMessage> _sbd = const [];
  List<SmsMessage> _sms = const [];
  List<PagerMessage> _pager = const [];
  List<VoiceCallInfo> _voiceCalls = const [];
  List<SatelliteInfo> _satellites = const [];
  List<GroundBeamInfo> _beams = const [];
  RadioStats _stats = const RadioStats();
  Map<String, dynamic>? _fileInfo;
  IqFileHandle? _fileHandle;
  bool _disposed = false;

  final AudioPlayer _voicePlayer = AudioPlayer();
  StreamSubscription<void>? _voiceCompleteSub;
  final List<VoiceCallInfo> _voiceQueue = [];
  final Set<int> _voiceSeen = {};
  bool _voiceInitialized = false;
  bool _autoPlayVoice = true;
  int? _playingVoiceId;
  int _iraDebugCount = 0;
  int _lastMapDebugSats = -1;
  int _lastMapDebugBeams = -1;

  IridiScopeService() {
    _voiceCompleteSub = _voicePlayer.onPlayerComplete.listen((_) {
      _playingVoiceId = null;
      _notify();
      _playNextVoice();
    });
  }

  IridiScopeState get state => _state;
  SourceKind get source => _source;
  String? get error => _error;
  bool get isRunning => _state == IridiScopeState.running;
  bool get isPaused => _state == IridiScopeState.paused;
  int get fftSize => _fftSize;
  int get sampleRate => _sampleRate;
  int get centerHz => _centerHz;
  int get lna => _lna;
  int get vga => _vga;
  bool get amp => _amp;
  bool get biasTee => _biasTee;
  bool get realtime => _realtime;
  Float32List? get latestSpectrum => _latestSpectrum;
  Stream<Float32List> get spectrumStream => _spectrumCtrl.stream;
  List<IridiumMessage> get messages => List.unmodifiable(_messages);
  List<AcarsMessage> get acars => _acars;
  List<SbdMessage> get sbd => _sbd;
  List<SmsMessage> get sms => _sms;
  List<PagerMessage> get pager => _pager;
  List<VoiceCallInfo> get voiceCalls => _voiceCalls;
  List<SatelliteInfo> get satellites => _satellites;
  List<GroundBeamInfo> get beams => _beams;
  bool get autoPlayVoice => _autoPlayVoice;
  int? get playingVoiceId => _playingVoiceId;
  int get queuedVoiceCount => _voiceQueue.length;
  RadioStats get stats => _stats;
  Map<String, dynamic>? get fileInfo => _fileInfo;

  Pointer<Void> _ensureHandle() {
    final existing = _handle;
    if (existing != null && existing != nullptr) return existing;
    final h = _native.create();
    if (h == nullptr) {
      throw StateError('ir_mobile_create failed');
    }
    _handle = h;
    _ensureMemory();
    return h;
  }

  void _ensureMemory() {
    _eventsPtr ??= calloc<Uint8>(_eventsCapacity);
    _infoPtr ??= calloc<Uint8>(16 * 1024);
    _errPtr ??= calloc<Uint8>(1024).cast<Utf8>();
  }

  void _allocSpectrum(int bins) {
    _instPtr?.let((p) => _native.freePtr(p));
    _avgPtr?.let((p) => _native.freePtr(p));
    _instPtr = calloc<Float>(bins);
    _avgPtr = calloc<Float>(bins);
    _instView = _instPtr!.asTypedList(bins);
    _avgView = _avgPtr!.asTypedList(bins);
  }

  void _freeMemory() {
    _instPtr?.let((p) => _native.freePtr(p));
    _avgPtr?.let((p) => _native.freePtr(p));
    _eventsPtr?.let((p) => _native.freePtr(p));
    _infoPtr?.let((p) => _native.freePtr(p));
    _errPtr?.let((p) => _native.freePtr(p.cast<Uint8>()));
    _instPtr = null;
    _avgPtr = null;
    _eventsPtr = null;
    _infoPtr = null;
    _errPtr = null;
    _instView = null;
    _avgView = null;
  }

  Future<void> _initVoiceDir(Pointer<Void> h) async {
    try {
      final base = await getApplicationDocumentsDirectory();
      final dir = Directory('${base.path}/voice');
      await dir.create(recursive: true);
      final ptr = dir.path.toNativeUtf8();
      _native.setVoiceDir(h, ptr);
      calloc.free(ptr);
    } catch (e) {
      debugPrint('voice dir: $e');
    }
  }

  Future<void> startHackRf({
    int? centerHz,
    int? sampleRate,
    int? fftSize,
    int? lna,
    int? vga,
    bool? amp,
    bool? biasTee,
  }) async {
    if (_state == IridiScopeState.starting) return;
    await _stopInternal();
    _setState(IridiScopeState.starting);
    _error = null;

    _source = SourceKind.hackRf;
    _centerHz = centerHz ?? _centerHz;
    _sampleRate = sampleRate ?? _sampleRate;
    _fftSize = fftSize ?? _fftSize;
    _lna = lna ?? _lna;
    _vga = vga ?? _vga;
    _amp = amp ?? _amp;
    _biasTee = biasTee ?? _biasTee;
    _realtime = false;

    try {
      final h = _ensureHandle();
      _ensureMemory();
      _allocSpectrum(_fftSize);
      final rc = _native.openPush(
          h, _centerHz, _sampleRate, _fftSize, 2);
      if (rc != 0) throw StateError('open_push failed ($rc)');
      await _initVoiceDir(h);

      await hackrf.init();
      await hackrf.configure(
        hz: _centerHz,
        sampleRate: _sampleRate,
        lna: _lna,
        vga: _vga,
        amp: _amp,
        biasTee: _biasTee,
      );
      final sr = _native.start(h);
      if (sr != 0) throw StateError('native start failed ($sr)');
      await hackrf.start();
      _startPollers();
      _setState(IridiScopeState.running);
    } catch (e) {
      await _stopInternal();
      _setError('$e');
    }
  }

  Future<void> restartHackRf({int? sampleRate}) async {
    final rate = sampleRate ?? _sampleRate;
    await startHackRf(
      centerHz: _centerHz,
      sampleRate: rate,
      fftSize: _fftSize,
      lna: _lna,
      vga: _vga,
      amp: _amp,
      biasTee: _biasTee,
    );
  }

  Future<void> startFile(IqFileHandle file,
      {int? centerHz, int? fftSize}) async {
    if (_state == IridiScopeState.starting) return;
    await _stopInternal();
    _setState(IridiScopeState.starting);
    _error = null;
    _source = SourceKind.file;
    _fftSize = fftSize ?? _fftSize;
    _realtime = true;

    try {
      final handle = file;
      _fileHandle = handle;
      final h = _ensureHandle();
      _ensureMemory();

      final namePtr = handle.name.toNativeUtf8();
      final rc = _native.openFileFd(
          h, handle.fd, namePtr, _errPtr!, 1024);
      calloc.free(namePtr);
      if (rc != 0) {
        final msg = _errPtr!.toDartString();
        throw StateError(msg.isEmpty ? 'open_file_fd failed ($rc)' : msg);
      }

      _native.setRealtime(h, 1);
      _readFileInfo(h);
      await _initVoiceDir(h);
      _allocSpectrum(_fftSize);
      final sr = _native.start(h);
      if (sr != 0) throw StateError('native start failed ($sr)');
      _startPollers();
      _setState(IridiScopeState.running);
    } catch (e) {
      await _stopInternal();
      _setError('$e');
    }
  }

  void _readFileInfo(Pointer<Void> h) {
    final len = _native.fileInfo(h, _infoPtr!, 16 * 1024);
    if (len <= 0) return;
    try {
      final map = jsonDecode(
              utf8.decode(_infoPtr!.asTypedList(len), allowMalformed: true))
          as Map<String, dynamic>;
      _fileInfo = map;
      final rate = (map['sample_rate'] as num?)?.toInt() ?? 0;
      final center = (map['center_hz'] as num?)?.toDouble() ?? 0;
      if (rate > 0) _sampleRate = rate;
      if (center > 0) _centerHz = center.round();
    } catch (_) {}
  }

  void _startPollers() {
    _spectrumTimer?.cancel();
    _eventTimer?.cancel();
    _spectrumTimer =
        Timer.periodic(const Duration(milliseconds: 50), (_) => _pollSpectrum());
    _eventTimer =
        Timer.periodic(const Duration(milliseconds: 200), (_) => _pollEvents());
  }

  void _pollSpectrum() {
    final h = _handle;
    final inst = _instPtr;
    final avg = _avgPtr;
    final view = _avgView;
    if (h == null || inst == null || avg == null || view == null) return;
    final seq = _native.pollSpectrum(h, inst, avg, _fftSize);
    if (seq == 0) return;
    final frame = Float32List.fromList(view);
    _latestSpectrum = frame;
    if (!_spectrumCtrl.isClosed) _spectrumCtrl.add(frame);
  }

  void _handleVoiceAutoPlay() {
    if (!_voiceInitialized) {
      // Don't replay calls that were already complete when the app started.
      for (final c in _voiceCalls) {
        if (!c.active) _voiceSeen.add(c.id);
      }
      _voiceInitialized = true;
      return;
    }
    if (!_autoPlayVoice) return;
    for (final c in _voiceCalls) {
      if (c.active || c.wavPath.isEmpty) continue;
      if (_voiceSeen.add(c.id)) _voiceQueue.add(c);
    }
    _playNextVoice();
  }

  Future<void> _playNextVoice() async {
    if (!_autoPlayVoice || _playingVoiceId != null || _voiceQueue.isEmpty) {
      return;
    }
    final call = _voiceQueue.removeAt(0);
    _playingVoiceId = call.id;
    _notify();
    try {
      await _voicePlayer.stop();
      await _voicePlayer.play(DeviceFileSource(call.wavPath));
    } catch (e) {
      debugPrint('voice autoplay: $e');
      _playingVoiceId = null;
      _notify();
      await _playNextVoice();
    }
  }

  Future<void> playVoice(VoiceCallInfo call) async {
    if (call.wavPath.isEmpty) return;
    _voiceQueue.clear();
    try {
      await _voicePlayer.stop();
      await _voicePlayer.play(DeviceFileSource(call.wavPath));
      _playingVoiceId = call.id;
      _notify();
    } catch (e) {
      debugPrint('voice play: $e');
      _playingVoiceId = null;
      _notify();
    }
  }

  Future<void> stopVoice() async {
    _voiceQueue.clear();
    await _voicePlayer.stop();
    _playingVoiceId = null;
    _notify();
  }

  void setAutoPlayVoice(bool on) {
    _autoPlayVoice = on;
    if (!on) _voiceQueue.clear();
    _notify();
  }

  void _pollEvents() {
    final h = _handle;
    if (h == null) return;
    var len = _native.pollEvents(h, _eventsPtr!, _eventsCapacity);
    if (len == -2) {
      _eventsPtr?.let((p) => _native.freePtr(p));
      _eventsCapacity = 1024 * 1024;
      _eventsPtr = calloc<Uint8>(_eventsCapacity);
      len = _native.pollEvents(h, _eventsPtr!, _eventsCapacity);
    }
    if (len <= 0) return;

    try {
      final map = jsonDecode(
              utf8.decode(_eventsPtr!.asTypedList(len), allowMalformed: true))
          as Map<String, dynamic>;
      final incoming = (map['messages'] as List<dynamic>? ?? const []);
      for (final item in incoming) {
        if (item is! Map<String, dynamic>) continue;
        final msg = IridiumMessage.fromJson(item);
        _messages.insert(0, msg);
        if (kDebugMode && msg.type == 'IRA' && _iraDebugCount < 20) {
          _iraDebugCount++;
          debugPrint('IRA dbg: ${msg.pretty}');
        }
      }
      if (_messages.length > 500) _messages.removeRange(500, _messages.length);

      List<Map<String, dynamic>> maps(String key) =>
          (map[key] as List<dynamic>? ?? const [])
              .whereType<Map<String, dynamic>>()
              .toList();

      _acars = maps('acars').map(AcarsMessage.fromJson).toList();
      _sbd = maps('sbd').map(SbdMessage.fromJson).toList();
      _sms = maps('sms').map(SmsMessage.fromJson).toList();
      _pager = maps('pager').map(PagerMessage.fromJson).toList();
      _voiceCalls = maps('voice').map(VoiceCallInfo.fromJson).toList();
      _handleVoiceAutoPlay();
      _satellites =
          maps('satellites').map(SatelliteInfo.fromJson).toList();
      _beams = maps('beams').map(GroundBeamInfo.fromJson).toList();
      final positioned = _satellites.where((s) => s.hasPos).length;
      final beamPos = _beams.where((b) => b.hasPos).length;
      if (kDebugMode &&
          (positioned != _lastMapDebugSats || beamPos != _lastMapDebugBeams)) {
        _lastMapDebugSats = positioned;
        _lastMapDebugBeams = beamPos;
        debugPrint('MAP dbg: sats=${_satellites.length} positioned=$positioned '
            'beams=${_beams.length} beamPos=$beamPos');
      }

      _stats = RadioStats.fromJson(map['stats'] as Map<String, dynamic>?);
      if (!_disposed) notifyListeners();
    } catch (e) {
      debugPrint('IridiScope pollEvents: $e');
    }
  }

  Future<void> stop() async {
    await _stopInternal();
    _setState(IridiScopeState.idle);
  }

  Future<void> _stopInternal() async {
    _spectrumTimer?.cancel();
    _eventTimer?.cancel();
    _spectrumTimer = null;
    _eventTimer = null;

    if (_source == SourceKind.hackRf) {
      try {
        await hackrf.stop();
      } catch (_) {}
    }

    final h = _handle;
    if (h != null && h != nullptr) _native.stop(h);

    if (_fileHandle != null) {
      await files.close(_fileHandle);
      _fileHandle = null;
    }
    _fileInfo = null;
    _source = SourceKind.none;
  }

  Future<void> closeHackRf() async {
    try {
      await hackrf.close();
    } catch (_) {}
  }

  void setFrequency(int hz) {
    if (hz <= 0) return;
    _centerHz = hz;
    final h = _handle;
    if (h != null) _native.setFrequency(h, hz);
    if (_source == SourceKind.hackRf) unawaited(hackrf.setFrequency(hz));
    _notify();
  }

  void setFftSize(int n) {
    if (n < 256) return;
    _fftSize = n;
    _allocSpectrum(n);
    final h = _handle;
    if (h != null) _native.setFftSize(h, n);
    _notify();
  }

  void setLna(int gain) {
    _lna = gain;
    if (_source == SourceKind.hackRf) unawaited(hackrf.setLna(gain));
    _notify();
  }

  void setVga(int gain) {
    _vga = gain;
    if (_source == SourceKind.hackRf) unawaited(hackrf.setVga(gain));
    _notify();
  }

  void setAmp(bool on) {
    _amp = on;
    if (_source == SourceKind.hackRf) unawaited(hackrf.setAmp(on));
    _notify();
  }

  void setBiasTee(bool on) {
    _biasTee = on;
    if (_source == SourceKind.hackRf) unawaited(hackrf.setBiasTee(on));
    _notify();
  }

  void setPaused(bool paused) {
    final h = _handle;
    if (h != null) _native.pause(h, paused ? 1 : 0);
    _setState(paused ? IridiScopeState.paused : IridiScopeState.running);
  }

  void setRealtime(bool on) {
    _realtime = on;
    final h = _handle;
    if (h != null) _native.setRealtime(h, on ? 1 : 0);
    _notify();
  }

  void seekSample(int sample) {
    final h = _handle;
    if (h != null) _native.seekSample(h, sample < 0 ? 0 : sample);
  }

  void clearMessages() {
    _messages.clear();
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void _setState(IridiScopeState s) {
    _state = s;
    _notify();
  }

  void _setError(String message) {
    _state = IridiScopeState.error;
    _error = message;
    _notify();
  }

  @override
  void dispose() {
    _disposed = true;
    _spectrumTimer?.cancel();
    _eventTimer?.cancel();
    _voiceCompleteSub?.cancel();
    unawaited(_voicePlayer.dispose());
    unawaited(_shutdown());
    _spectrumCtrl.close();
    super.dispose();
  }

  Future<void> _shutdown() async {
    try {
      await hackrf.stop();
    } catch (_) {}
    try {
      await hackrf.close();
    } catch (_) {}
    await files.close(_fileHandle);
    _fileHandle = null;

    final h = _handle;
    if (h != null && h != nullptr) {
      _native.stop(h);
      _native.destroy(h);
      _handle = null;
    }
    _freeMemory();
  }
}

extension _Let<T> on T {
  R let<R>(R Function(T) block) => block(this);
}
