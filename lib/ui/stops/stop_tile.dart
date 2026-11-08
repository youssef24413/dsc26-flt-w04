import 'package:flutter/material.dart';

import '../../domain/stop.dart';

/// One stop row. A ListTile, so it grows with the text, mirrors in RTL
/// (the dot is the leading widget) and keeps 48 px tap targets.
class StopTile extends StatelessWidget {
  const StopTile({
    super.key,
    required this.stop,
    required this.onTap,
    required this.onCall,
    this.selected = false,
  });

  final Stop stop;
  final VoidCallback onTap;
  final VoidCallback onCall;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final (color, statusLabel) = switch (stop.status) {
      StopStatus.pending => (Colors.amber.shade700, 'Pending'),
      StopStatus.delivered => (Colors.green.shade700, 'Delivered'),
      StopStatus.failed => (Colors.red.shade700, 'Failed'),
    };
    return ListTile(
      selected: selected,
      onTap: onTap,
      leading: Semantics(
        label: statusLabel,
        child: Container(
          key: Key('stop-dot-${stop.id}'),
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
      ),
      title: Text(
        stop.customerName,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      // No maxLines and no fixed height: the row grows with the address.
      subtitle: Text(stop.address),
      trailing: IconButton(
        key: Key('call-${stop.id}'),
        tooltip: 'Call ${stop.customerName}',
        icon: const Icon(Icons.call),
        onPressed: onCall,
      ),
    );
  }
}
