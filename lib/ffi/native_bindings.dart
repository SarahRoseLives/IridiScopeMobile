import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';

final class IrMobileStats extends Struct {
  @Uint64()
  external int samples;
  @Uint64()
  external int totalSamples;
  @Uint64()
  external int bursts;
  @Uint64()
  external int framesOk;
  @Uint64()
  external int framesFail;
  @Uint64()
  external int messages;
  @Uint64()
  external int droppedSamples;
  @Double()
  external double elapsedS;
  @Double()
  external double rateSps;
  @Int32()
  external int running;
  @Int32()
  external int paused;
  @Int32()
  external int done;
  @Int32()
  external int fftSize;
  @Uint32()
  external int sampleRate;
  @Double()
  external double centerHz;
  @Float()
  external double floorDb;
  @Float()
  external double peakDb;
}

typedef _CreateNative = Pointer<Void> Function();
typedef _CreateDart = Pointer<Void> Function();

typedef _HandleNative = Void Function(Pointer<Void>);
typedef _HandleDart = void Function(Pointer<Void>);

typedef _OpenFileFdNative = Int32 Function(
    Pointer<Void>, Int32, Pointer<Utf8>, Pointer<Utf8>, Int32);
typedef _OpenFileFdDart = int Function(
    Pointer<Void>, int, Pointer<Utf8>, Pointer<Utf8>, int);

typedef _OpenPushNative = Int32 Function(
    Pointer<Void>, Uint32, Uint32, Int32, Int32);
typedef _OpenPushDart = int Function(
    Pointer<Void>, int, int, int, int);

typedef _StartNative = Int32 Function(Pointer<Void>);
typedef _StartDart = int Function(Pointer<Void>);

typedef _PauseNative = Void Function(Pointer<Void>, Int32);
typedef _PauseDart = void Function(Pointer<Void>, int);

typedef _SeekNative = Void Function(Pointer<Void>, Uint64);
typedef _SeekDart = void Function(Pointer<Void>, int);

typedef _SetFreqNative = Void Function(Pointer<Void>, Uint32);
typedef _SetFreqDart = void Function(Pointer<Void>, int);

typedef _SetIntNative = Void Function(Pointer<Void>, Int32);
typedef _SetIntDart = void Function(Pointer<Void>, int);

typedef _SetFloatNative = Void Function(Pointer<Void>, Float);
typedef _SetFloatDart = void Function(Pointer<Void>, double);

typedef _SetStrNative = Void Function(Pointer<Void>, Pointer<Utf8>);
typedef _SetStrDart = void Function(Pointer<Void>, Pointer<Utf8>);

typedef _PollSpectrumNative = Uint64 Function(
    Pointer<Void>, Pointer<Float>, Pointer<Float>, Int32);
typedef _PollSpectrumDart = int Function(
    Pointer<Void>, Pointer<Float>, Pointer<Float>, int);

typedef _PollEventsNative = Int32 Function(
    Pointer<Void>, Pointer<Uint8>, Int32);
typedef _PollEventsDart = int Function(
    Pointer<Void>, Pointer<Uint8>, int);

typedef _GetStatsNative = Void Function(
    Pointer<Void>, Pointer<IrMobileStats>);
typedef _GetStatsDart = void Function(
    Pointer<Void>, Pointer<IrMobileStats>);

class NativeBindings {
  NativeBindings._();

  static final NativeBindings instance = NativeBindings._();

  late final DynamicLibrary _lib = Platform.isAndroid
      ? DynamicLibrary.open('libiridiscope.so')
      : (throw UnsupportedError('IridiScope native library is Android-only'));

  late final _CreateDart create =
      _lib.lookupFunction<_CreateNative, _CreateDart>('ir_mobile_create');
  late final _HandleDart destroy =
      _lib.lookupFunction<_HandleNative, _HandleDart>('ir_mobile_destroy');

  late final _OpenFileFdDart openFileFd = _lib.lookupFunction<
      _OpenFileFdNative, _OpenFileFdDart>('ir_mobile_open_file_fd');
  late final _OpenPushDart openPush = _lib
      .lookupFunction<_OpenPushNative, _OpenPushDart>('ir_mobile_open_push');

  late final _StartDart start =
      _lib.lookupFunction<_StartNative, _StartDart>('ir_mobile_start');
  late final _HandleDart stop =
      _lib.lookupFunction<_HandleNative, _HandleDart>('ir_mobile_stop');
  late final _PauseDart pause =
      _lib.lookupFunction<_PauseNative, _PauseDart>('ir_mobile_pause');
  late final _SetIntDart setRealtime =
      _lib.lookupFunction<_SetIntNative, _SetIntDart>('ir_mobile_set_realtime');
  late final _SeekDart seekSample =
      _lib.lookupFunction<_SeekNative, _SeekDart>('ir_mobile_seek_sample');

  late final _SetFreqDart setFrequency = _lib
      .lookupFunction<_SetFreqNative, _SetFreqDart>('ir_mobile_set_frequency');
  late final _SetIntDart setFftSize = _lib
      .lookupFunction<_SetIntNative, _SetIntDart>('ir_mobile_set_fft_size');
  late final _SetIntDart setDcBlock = _lib
      .lookupFunction<_SetIntNative, _SetIntDart>('ir_mobile_set_dc_block');
  late final _SetFloatDart setAvgAlpha = _lib.lookupFunction<
      _SetFloatNative, _SetFloatDart>('ir_mobile_set_avg_alpha');
  late final _SetStrDart setVoiceDir = _lib.lookupFunction<
      _SetStrNative, _SetStrDart>('ir_mobile_set_voice_dir');

  late final _PollSpectrumDart pollSpectrum = _lib.lookupFunction<
      _PollSpectrumNative, _PollSpectrumDart>('ir_mobile_poll_spectrum');
  late final _PollEventsDart pollEvents = _lib.lookupFunction<
      _PollEventsNative, _PollEventsDart>('ir_mobile_poll_events');
  late final _GetStatsDart getStats = _lib
      .lookupFunction<_GetStatsNative, _GetStatsDart>('ir_mobile_get_stats');
  late final _PollEventsDart fileInfo = _lib.lookupFunction<
      _PollEventsNative, _PollEventsDart>('ir_mobile_file_info');

  void freePtr(Pointer<NativeType> ptr) => calloc.free(ptr);
}
