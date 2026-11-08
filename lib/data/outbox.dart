import 'dart:convert';

import 'package:http/http.dart' as http;

import '../domain/delivery_outcome.dart';
import 'local_store.dart';

/// The storage key for the whole queue (a JSON document).
const String outboxStorageKey = 'tawseel.outbox.v1';

enum EntryStatus { pending, rejected }

/// One queued outcome. Immutable; the outbox replaces entries with [copyWith].
final class OutboxEntry {
  const OutboxEntry({
    required this.id,
    required this.outcome,
    this.attempts = 0,
    this.status = EntryStatus.pending,
    this.rejectionReason,
  });

  /// Generated on the phone when the outcome is recorded; sent as the
  /// Idempotency-Key header.
  final String id;
  final DeliveryOutcome outcome;

  /// How many times this entry has been sent, whatever the answer was.
  final int attempts;
  final EntryStatus status;
  final String? rejectionReason;

  OutboxEntry copyWith({
    DeliveryOutcome? outcome,
    int? attempts,
    EntryStatus? status,
    String? rejectionReason,
  }) => OutboxEntry(
    id: id,
    outcome: outcome ?? this.outcome,
    attempts: attempts ?? this.attempts,
    status: status ?? this.status,
    rejectionReason: rejectionReason ?? this.rejectionReason,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'outcome': outcome.toJson(),
    'attempts': attempts,
    'status': status.name,
    'rejectionReason': rejectionReason,
  };

  factory OutboxEntry.fromJson(Map<String, Object?> json) {
    final id = json['id'];
    final outcome = json['outcome'];
    final attempts = json['attempts'];
    final status = json['status'];
    final reason = json['rejectionReason'];
    if (id is! String ||
        outcome is! Map ||
        attempts is! int ||
        status is! String ||
        (reason != null && reason is! String)) {
      throw FormatException('bad outbox entry: $json');
    }
    return OutboxEntry(
      id: id,
      outcome: DeliveryOutcome.fromJson(outcome.cast<String, Object?>()),
      attempts: attempts,
      status: EntryStatus.values.byName(status),
      rejectionReason: reason as String?,
    );
  }

  @override
  String toString() =>
      'OutboxEntry($id, ${outcome.parcelId}, attempts: $attempts, ${status.name})';
}

/// What one sync run did.
final class SyncReport {
  const SyncReport({
    required this.sent,
    required this.rejected,
    required this.remaining,
    this.authRequired = false,
    this.retryAfter,
  });

  /// Entries the server accepted in this run (200, 201 or 409).
  final int sent;

  /// Entries the server rejected in this run (400 or 422).
  final int rejected;

  /// Pending entries left after the run.
  final int remaining;

  /// True when the run stopped on a 401.
  final bool authRequired;

  /// Set when the run stopped on a transient failure: wait this long.
  final Duration? retryAfter;

  @override
  String toString() =>
      'SyncReport(sent: $sent, rejected: $rejected, '
      'remaining: $remaining, authRequired: $authRequired, '
      'retryAfter: $retryAfter)';
}

/// 5 s × 2^(n−1), capped at 300 s. [consecutiveFailures] must be at least 1,
/// otherwise throw ArgumentError.
Duration retryDelay(int consecutiveFailures) {
  if (consecutiveFailures < 1) {
    throw ArgumentError.value(
      consecutiveFailures,
      'consecutiveFailures',
      'must be at least 1',
    );
  }
  // From 7 on, 5 * 2^(n-1) is already >= 320 s, so the cap applies. Returning
  // early also avoids shifting by a huge n (integer overflow).
  if (consecutiveFailures >= 7) return const Duration(seconds: 300);
  return Duration(seconds: 5 * (1 << (consecutiveFailures - 1)));
}

/// An offline-first queue of delivery outcomes. See the README for the rules.
///
/// Keep the constructor and the public method signatures exactly.
class Outbox {
  Outbox({
    required LocalStore store,
    required http.Client client,
    required Uri baseUrl,
    required String Function() newId,
  }) : _store = store,
       _client = client,
       _baseUrl = baseUrl,
       _newId = newId;

  final LocalStore _store;
  final http.Client _client;
  final Uri _baseUrl;
  final String Function() _newId;

  /// The whole queue (pending and rejected), in order. Loaded once from the
  /// store, then kept in step with it: every change is written before the
  /// operation that made it completes.
  List<OutboxEntry>? _entries;
  Future<void>? _loaded;

  /// Writes are chained so a later snapshot can never be overtaken by an
  /// earlier one.
  Future<void> _lastWrite = Future<void>.value();

  Future<SyncReport>? _inFlight;
  bool _ending = false;

  // ---------------------------------------------------------------- storage

  Future<void> _ensureLoaded() {
    return _loaded ??= _load().onError<Object>((error, stack) {
      _loaded = null; // let the next call try again
      Error.throwWithStackTrace(error, stack);
    });
  }

  Future<void> _load() async {
    final raw = await _store.read(outboxStorageKey);
    _entries = _decode(raw);
  }

  static List<OutboxEntry> _decode(String? raw) {
    if (raw == null || raw.isEmpty) return <OutboxEntry>[];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return <OutboxEntry>[];
      return [
        for (final item in decoded)
          OutboxEntry.fromJson((item as Map).cast<String, Object?>()),
      ];
    } catch (_) {
      return <OutboxEntry>[];
    }
  }

  Future<void> _save() {
    final payload = jsonEncode([for (final e in _entries!) e.toJson()]);
    final previous = _lastWrite;
    final write = () async {
      try {
        await previous;
      } catch (_) {
        // an earlier failed write was already reported to its own caller
      }
      await _store.write(outboxStorageKey, payload);
    }();
    _lastWrite = write;
    return write;
  }

  // ------------------------------------------------------------- validation

  static void _validate(DeliveryOutcome o) {
    if (o.parcelId.isEmpty) {
      throw ArgumentError.value(o.parcelId, 'parcelId', 'must not be empty');
    }
    if (!o.recordedAt.isUtc) {
      throw ArgumentError.value(o.recordedAt, 'recordedAt', 'must be UTC');
    }
    switch (o.status) {
      case OutcomeStatus.delivered:
        if (o.codCollectedPiasters < 0) {
          throw ArgumentError.value(
            o.codCollectedPiasters,
            'codCollectedPiasters',
            'must be >= 0 for a delivery',
          );
        }
        if (o.reason != null) {
          throw ArgumentError.value(
            o.reason,
            'reason',
            'a delivered outcome has no reason',
          );
        }
      case OutcomeStatus.failed:
        if (o.reason == null) {
          throw ArgumentError.notNull('reason');
        }
        if (o.codCollectedPiasters != 0) {
          throw ArgumentError.value(
            o.codCollectedPiasters,
            'codCollectedPiasters',
            'a failed outcome collects no cash',
          );
        }
    }
  }

  // ----------------------------------------------------------------- public

  /// Validates, queues (or corrects) and persists before completing.
  Future<OutboxEntry> record(DeliveryOutcome outcome) async {
    _validate(outcome);
    await _ensureLoaded();

    final before = _entries!;
    final entries = [...before];

    // A correction replaces an entry only if it was never sent.
    final index = entries.indexWhere(
      (e) =>
          e.status == EntryStatus.pending &&
          e.attempts == 0 &&
          e.outcome.parcelId == outcome.parcelId,
    );

    final OutboxEntry entry;
    if (index >= 0) {
      entry = entries[index].copyWith(outcome: outcome);
      entries[index] = entry;
    } else {
      entry = OutboxEntry(id: _newId(), outcome: outcome);
      entries.add(entry);
    }

    _entries = entries;
    try {
      await _save();
    } catch (_) {
      if (identical(_entries, entries)) _entries = before;
      rethrow;
    }
    return entry;
  }

  /// Pending entries, in send order.
  Future<List<OutboxEntry>> pending() async {
    await _ensureLoaded();
    return List.unmodifiable(
      _entries!.where((e) => e.status == EntryStatus.pending),
    );
  }

  Future<List<OutboxEntry>> rejected() async {
    await _ensureLoaded();
    return List.unmodifiable(
      _entries!.where((e) => e.status == EntryStatus.rejected),
    );
  }

  Future<int> pendingCount() async => (await pending()).length;

  /// Sends pending entries oldest first. Single-flight: while a run is going,
  /// every caller gets the same future.
  Future<SyncReport> sync() {
    final running = _inFlight;
    if (running != null && !_ending) return running;

    _ending = false;
    late final Future<SyncReport> run;
    run = _runSync().whenComplete(() {
      if (identical(_inFlight, run)) _inFlight = null;
    });
    _inFlight = run;
    return run;
  }

  // ------------------------------------------------------------------- sync

  Uri get _endpoint {
    final path = _baseUrl.path.endsWith('/')
        ? _baseUrl.path.substring(0, _baseUrl.path.length - 1)
        : _baseUrl.path;
    return _baseUrl.replace(path: '$path/v1/outcomes');
  }

  void _replace(OutboxEntry entry) {
    _entries = [for (final e in _entries!) e.id == entry.id ? entry : e];
  }

  void _remove(String id) {
    _entries = [
      for (final e in _entries!)
        if (e.id != id) e,
    ];
  }

  static String? _messageFrom(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map && decoded['message'] is String) {
        return decoded['message'] as String;
      }
    } catch (_) {}
    return null;
  }

  Future<SyncReport> _runSync() async {
    await _ensureLoaded();

    var sent = 0;
    var rejected = 0;
    var authRequired = false;
    Duration? retryAfter;

    while (true) {
      // Looked up fresh each time: outcomes recorded during the run are
      // appended, and the run picks them up.
      final index = _entries!.indexWhere(
        (e) => e.status == EntryStatus.pending,
      );
      if (index < 0) break;

      // Count the attempt (and persist it) before the request goes out.
      final entry = _entries![index].copyWith(
        attempts: _entries![index].attempts + 1,
      );
      _replace(entry);
      await _save();

      final http.Response response;
      try {
        response = await _client.post(
          _endpoint,
          headers: {
            'Content-Type': 'application/json',
            'Idempotency-Key': entry.id,
          },
          // Bytes, so the client does not append "; charset=utf-8".
          body: utf8.encode(
            jsonEncode({'id': entry.id, ...entry.outcome.toJson()}),
          ),
        );
      } on Exception {
        retryAfter = retryDelay(entry.attempts);
        break;
      }

      final code = response.statusCode;
      if (code == 200 || code == 201 || code == 409) {
        _remove(entry.id);
        sent++;
        await _save();
      } else if (code == 400 || code == 422) {
        _replace(
          entry.copyWith(
            status: EntryStatus.rejected,
            rejectionReason: _messageFrom(response.body) ?? 'HTTP $code',
          ),
        );
        rejected++;
        await _save();
      } else if (code == 401) {
        authRequired = true;
        break;
      } else {
        retryAfter = retryDelay(entry.attempts);
        break;
      }
    }

    final remaining = _entries!
        .where((e) => e.status == EntryStatus.pending)
        .length;
    _ending = true; // no awaits between here and the return
    return SyncReport(
      sent: sent,
      rejected: rejected,
      remaining: remaining,
      authRequired: authRequired,
      retryAfter: retryAfter,
    );
  }
}
