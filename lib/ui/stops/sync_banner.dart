import 'package:flutter/material.dart';

/// Shows how many outcomes are waiting to sync.
///
/// One semantics node, one label (exactly the visible text), announced as a
/// live region when it changes.
class SyncBanner extends StatelessWidget {
  const SyncBanner({super.key, required this.pendingCount});

  final int pendingCount;

  String get _label => switch (pendingCount) {
        0 => 'All outcomes synced',
        1 => '1 outcome waiting to sync',
        _ => '$pendingCount outcomes waiting to sync',
      };

  @override
  Widget build(BuildContext context) {
    final label = _label;
    return Semantics(
      container: true,
      liveRegion: true,
      label: label,
      excludeSemantics: true, // the Text below must not add a second label
      child: Container(
        width: double.infinity,
        color:
            pendingCount == 0 ? Colors.green.shade100 : Colors.orange.shade100,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Text(label, style: const TextStyle(color: Colors.black87)),
      ),
    );
  }
}
