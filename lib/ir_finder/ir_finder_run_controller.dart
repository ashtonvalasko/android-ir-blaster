import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:irblaster_controller/ir_finder/ir_finder_models.dart';
import 'package:irblaster_controller/ir_finder/ir_finder_prefs.dart';
import 'package:irblaster_controller/ir_finder/ir_finder_search.dart';

typedef IrFinderCandidateFetcher = Future<IrFinderCandidate?> Function(
    IrFinderRunController controller);
typedef IrFinderCandidateSender = Future<void> Function(
    IrFinderCandidate candidate);

class IrFinderRunController extends ChangeNotifier {
  final IrFinderCandidateFetcher fetchCandidate;
  final IrFinderCandidateSender sendCandidate;

  IrFinderMode mode = IrFinderMode.bruteforce;

  String protocolId = 'nec';
  String? brand;
  String? model;

  int delayMs = 500;

  int maxKeysToTest = 2000;

  int bruteMaxAttempts = 200;
  bool bruteAllCombinations = false;
  IrFinderSearchStrategy bruteStrategy = IrFinderSearchStrategy.smart;

  String prefixRaw = '';
  String kaseikyoVendor = '2002';

  bool onlySelectedProtocol = true;
  bool quickWinsFirst = true;
  bool uniqueDbSignals = true;
  bool candidatesExhausted = false;

  bool running = false;
  bool paused = false;

  int attempted = 0;
  DateTime? startedAt;

  int currentOffset = 0;

  BigInt bruteCursor = BigInt.zero;

  IrFinderCandidate? lastCandidate;
  Object? lastError;

  Timer? _timer;
  bool _tickBusy = false;
  bool _disposed = false;
  int _generation = 0;
  int _pauseRevision = 0;
  bool get busy => _tickBusy;
  int _nullCandidateSkips = 0;

  DateTime _lastPersistAt = DateTime.fromMillisecondsSinceEpoch(0);
  Timer? _persistDebounce;

  IrFinderRunController({
    required this.fetchCandidate,
    required this.sendCandidate,
  });

  void configure({
    required IrFinderMode mode,
    required String protocolId,
    required int delayMs,
    required int maxKeysToTest,
    required int bruteMaxAttempts,
    required bool bruteAllCombinations,
    required IrFinderSearchStrategy bruteStrategy,
    required String prefixRaw,
    required String kaseikyoVendor,
    required bool onlySelectedProtocol,
    required bool quickWinsFirst,
    required String? brand,
    required String? model,
  }) {
    final previousDelay = this.delayMs;
    this.mode = mode;
    this.protocolId = protocolId.trim().toLowerCase();
    this.delayMs = delayMs.clamp(250, 20000);
    this.maxKeysToTest = maxKeysToTest.clamp(1, 2147483647);
    this.bruteMaxAttempts = bruteMaxAttempts.clamp(1, 2147483647);
    this.bruteAllCombinations = bruteAllCombinations;
    this.bruteStrategy = bruteStrategy;
    this.prefixRaw = prefixRaw;
    this.kaseikyoVendor = kaseikyoVendor.toUpperCase();
    this.onlySelectedProtocol = onlySelectedProtocol;
    this.quickWinsFirst = quickWinsFirst;
    this.brand = brand;
    this.model = model;
    if (previousDelay != this.delayMs && !_tickBusy) _scheduleTimer();
    _schedulePersist();
    notifyListeners();
  }

  void restoreProgress({
    required int attempted,
    required int currentOffset,
    required BigInt bruteCursor,
    required DateTime? startedAt,
    required bool paused,
    bool uniqueDbSignals = true,
  }) {
    _generation++;
    this.uniqueDbSignals = uniqueDbSignals;
    candidatesExhausted = false;
    this.attempted = attempted.clamp(0, 2147483647);
    this.currentOffset = currentOffset.clamp(0, 2147483647);
    this.bruteCursor = bruteCursor < BigInt.zero ? BigInt.zero : bruteCursor;
    this.startedAt = startedAt;
    this.paused = paused;
    running = true;
    _cancelTimer();
    _schedulePersist();
    notifyListeners();
  }

  Future<void> start() async {
    if (running && !paused) return;

    _cancelTimer();
    _generation++;
    uniqueDbSignals = true;
    candidatesExhausted = false;

    running = true;
    paused = false;
    attempted = 0;
    currentOffset = 0;
    bruteCursor = BigInt.zero;
    startedAt = DateTime.now();
    lastCandidate = null;
    lastError = null;
    _nullCandidateSkips = 0;

    notifyListeners();
    _schedulePersist();

    _scheduleTimer();
  }

  void pause() {
    if (!running) return;
    if (paused) return;
    paused = true;
    _pauseRevision++;
    _cancelTimer();
    notifyListeners();
    _schedulePersist();
  }

  void resume() {
    if (!running) return;
    if (!paused) return;
    paused = false;
    notifyListeners();
    _schedulePersist();
    _scheduleTimer();
  }

  Future<void> step() async {
    if (!running) {
      running = true;
      paused = true;
      startedAt ??= DateTime.now();
      notifyListeners();
      _schedulePersist();
    }
    if (!paused) return;
    await _tick(send: true, advance: true);
  }

  Future<void> trigger() async {
    if (!running) return;
    await _tick(send: true, advance: false);
  }

  void skip() {
    if (!running || _tickBusy) return;
    _advanceWithoutSend();
    notifyListeners();
    _schedulePersist();
  }

  Future<void> stop({bool clearPersistedSession = false}) async {
    if (!running && !paused) {
      if (clearPersistedSession) {
        await IrFinderPrefs.clearSession();
      }
      return;
    }
    _cancelTimer();
    _generation++;
    running = false;
    paused = false;
    notifyListeners();
    if (clearPersistedSession) {
      await IrFinderPrefs.clearSession();
    } else {
      await persistNow();
    }
  }

  Future<void> persistNow() async {
    final snap = snapshot();
    await IrFinderPrefs.saveSession(snap);
  }

  IrFinderSessionSnapshot snapshot() {
    return IrFinderSessionSnapshot(
      v: uniqueDbSignals ? 3 : 2,
      mode: mode,
      protocolId: protocolId,
      brand: brand,
      model: model,
      delayMs: delayMs,
      maxKeysToTest: maxKeysToTest,
      bruteMaxAttempts: bruteMaxAttempts,
      bruteAllCombinations: bruteAllCombinations,
      bruteStrategy: bruteStrategy,
      prefixRaw: prefixRaw,
      kaseikyoVendor: kaseikyoVendor,
      onlySelectedProtocol: onlySelectedProtocol,
      quickWinsFirst: quickWinsFirst,
      attempted: attempted,
      currentOffset: currentOffset,
      bruteCursorHex: bruteCursor.toRadixString(16),
      startedAtMs: startedAt?.millisecondsSinceEpoch ?? 0,
      paused: paused,
    );
  }

  void _scheduleTimer() {
    _cancelTimer();
    if (_disposed || !running || paused || _tickBusy) return;
    final int ms = delayMs.clamp(250, 20000);
    _timer = Timer(Duration(milliseconds: ms), () {
      _timer = null;
      unawaited(_tick(send: true, advance: true, automatic: true));
    });
  }

  /// Freeze the displayed, completed attempt before opening saved results.
  IrFinderCandidate? pauseForHit() {
    if (_tickBusy || lastError != null || lastCandidate == null) return null;
    pause();
    return lastCandidate;
  }

  void _cancelTimer() {
    _timer?.cancel();
    _timer = null;
  }

  void _schedulePersist() {
    _persistDebounce?.cancel();
    _persistDebounce = Timer(const Duration(milliseconds: 200), () async {
      _persistDebounce = null;
      final now = DateTime.now();
      if (now.difference(_lastPersistAt).inMilliseconds < 200) return;
      _lastPersistAt = now;
      await persistNow();
    });
  }

  Future<void> _tick(
      {required bool send,
      required bool advance,
      bool automatic = false}) async {
    if (_disposed || !running || (automatic && paused)) return;
    if (_tickBusy) return;

    if (advance && mode == IrFinderMode.database) {
      if (attempted >= maxKeysToTest) {
        await stop(clearPersistedSession: false);
        return;
      }
    } else if (advance) {
      if (!bruteAllCombinations && attempted >= bruteMaxAttempts) {
        await stop(clearPersistedSession: false);
        return;
      }
    }

    _cancelTimer();
    final generation = _generation;
    final pauseRevision = _pauseRevision;
    _tickBusy = true;
    notifyListeners();
    try {
      if (!send) return;

      IrFinderCandidate? c;

      if (!advance && lastCandidate != null) {
        c = lastCandidate;
      } else {
        c = await fetchCandidate(this);
      }

      if (_disposed || generation != _generation || !running) return;
      if (automatic && (paused || pauseRevision != _pauseRevision)) return;

      if (c == null) {
        if (candidatesExhausted) {
          await stop(clearPersistedSession: false);
          return;
        }
        _nullCandidateSkips += 1;
        if (mode == IrFinderMode.bruteforce) {
          lastError ??= 'No more candidates (exhausted).';
          await stop(clearPersistedSession: false);
          return;
        }
        if (_nullCandidateSkips >= 25) {
          lastError ??=
              'Database candidate missing repeatedly. The DB may have changed; restart recommended.';
          await stop(clearPersistedSession: false);
          return;
        }
        if (advance) {
          _advanceWithoutSend();
        }
        notifyListeners();
        _schedulePersist();
        return;
      }

      Object? err;
      try {
        await sendCandidate(c);
        err = null;
      } catch (e) {
        err = e;
      }

      // A send already handed to hardware cannot be cancelled, but it must not
      // overwrite a newer run or a position explicitly chosen with Jump.
      if (_disposed || generation != _generation || !running) return;

      lastCandidate = c;
      lastError = err;
      _nullCandidateSkips = 0;
      if (err != null) pause();

      if (advance) {
        _advanceAfterSend();
      }

      notifyListeners();
      _schedulePersist();
    } catch (e) {
      if (!_disposed && generation == _generation && running) {
        lastError = e;
        pause();
      }
    } finally {
      _tickBusy = false;
      if (!_disposed) {
        notifyListeners();
        // Cooldown starts after the asynchronous lookup/send completes.
        _scheduleTimer();
      }
    }
  }

  void _advanceAfterSend() {
    attempted = (attempted + 1).clamp(0, 2147483647);
    currentOffset = (currentOffset + 1).clamp(0, 2147483647);
    if (mode == IrFinderMode.bruteforce) {
      bruteCursor += BigInt.one;
    }
  }

  void _advanceWithoutSend() {
    attempted = (attempted + 1).clamp(0, 2147483647);
    currentOffset = (currentOffset + 1).clamp(0, 2147483647);
    if (mode == IrFinderMode.bruteforce) {
      bruteCursor += BigInt.one;
    }
  }

  // Jump methods to reposition safely without breaking DB ordering
  void jumpToOffset(int value) {
    _generation++;
    final int v = value.clamp(0, 2147483647);
    currentOffset = v;
    // Pause to avoid racing the timer while relocating
    paused = true;
    _cancelTimer();
    _schedulePersist();
    notifyListeners();
  }

  void jumpToBrute(BigInt value) {
    _generation++;
    final BigInt v = (value < BigInt.zero) ? BigInt.zero : value;
    bruteCursor = v;
    paused = true;
    _cancelTimer();
    _schedulePersist();
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    _cancelTimer();
    _persistDebounce?.cancel();
    _persistDebounce = null;
    super.dispose();
  }
}
