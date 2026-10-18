import 'package:flutter/services.dart';

class HackRfService {
  static const _channel =
      MethodChannel('dev.sarahsforge.iridiscope/hackrf');

  Future<void> init() async {
    final ok = await _channel.invokeMethod<bool>('init');
    if (ok != true) {
      throw PlatformException(
          code: 'HACKRF', message: 'HackRF initialization failed');
    }
  }

  Future<void> configure({
    required int hz,
    required int sampleRate,
    required int lna,
    required int vga,
    required bool amp,
    required bool biasTee,
  }) async {
    await _channel.invokeMethod<bool>('configure', {
      'hz': hz,
      'sampleRate': sampleRate,
      'lna': lna,
      'vga': vga,
      'amp': amp ? 1 : 0,
      'biasTee': biasTee ? 1 : 0,
    });
  }

  Future<void> start() async {
    await _channel.invokeMethod<bool>('start');
  }

  Future<void> stop() async {
    await _channel.invokeMethod<bool>('stop');
  }

  Future<void> close() async {
    await _channel.invokeMethod<bool>('close');
  }

  Future<void> setFrequency(int hz) async {
    await _channel.invokeMethod<bool>('setFrequency', {'hz': hz});
  }

  Future<void> setSampleRate(int hz) async {
    await _channel.invokeMethod<bool>('setSampleRate', {'hz': hz});
  }

  Future<void> setLna(int gain) async {
    await _channel.invokeMethod<bool>('setLna', {'gain': gain});
  }

  Future<void> setVga(int gain) async {
    await _channel.invokeMethod<bool>('setVga', {'gain': gain});
  }

  Future<void> setAmp(bool on) async {
    await _channel.invokeMethod<bool>('setAmp', {'on': on ? 1 : 0});
  }

  Future<void> setBiasTee(bool on) async {
    await _channel.invokeMethod<bool>('setBiasTee', {'on': on ? 1 : 0});
  }

  Future<int?> boardId() async {
    return _channel.invokeMethod<int>('getBoardId');
  }
}
