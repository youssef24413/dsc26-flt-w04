import 'package:flutter/material.dart';

import '../../domain/stop.dart';
import 'stop_tile.dart';
import 'sync_banner.dart';

/// From this available width (included) the list and the details sit side by
/// side.
const double _expandedBreakpoint = 600;

/// Today's stops for one courier.
class TawseelStopsApp extends StatefulWidget {
  const TawseelStopsApp({
    super.key,
    required this.stops,
    required this.pendingCount,
    this.textDirection = TextDirection.ltr,
  });

  final List<Stop> stops;
  final int pendingCount;
  final TextDirection textDirection;

  @override
  State<TawseelStopsApp> createState() => _TawseelStopsAppState();
}

class _TawseelStopsAppState extends State<TawseelStopsApp> {
  String? _selectedId;

  Stop? get _selected {
    if (widget.stops.isEmpty) return null;
    for (final s in widget.stops) {
      if (s.id == _selectedId) return s;
    }
    return widget.stops.first; // the first stop until another row is tapped
  }

  Widget _list(String? selectedId, {required bool highlight}) {
    return ListView.builder(
      itemCount: widget.stops.length,
      itemBuilder: (context, i) {
        final stop = widget.stops[i];
        return StopTile(
          key: Key('stop-${stop.id}'),
          stop: stop,
          selected: highlight && stop.id == selectedId,
          onTap: () => setState(() => _selectedId = stop.id),
          onCall: () {},
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tawseel stops',
      debugShowCheckedModeBanner: false,
      builder: (context, child) =>
          Directionality(textDirection: widget.textDirection, child: child!),
      home: Scaffold(
        appBar: AppBar(title: const Text("Today's stops")),
        body: Column(
          children: [
            SyncBanner(
              key: const Key('sync-banner'),
              pendingCount: widget.pendingCount,
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final selected = _selected;
                  if (constraints.maxWidth < _expandedBreakpoint) {
                    return KeyedSubtree(
                      key: const Key('layout-compact'),
                      child: _list(selected?.id, highlight: false),
                    );
                  }
                  final listWidth =
                      (constraints.maxWidth * 0.45).clamp(280.0, 420.0).toDouble();
                  return KeyedSubtree(
                    key: const Key('layout-expanded'),
                    child: Row(
                      children: [
                        SizedBox(
                          width: listWidth,
                          child: _list(selected?.id, highlight: true),
                        ),
                        const VerticalDivider(width: 1),
                        Expanded(
                          child: selected == null
                              ? const SizedBox.shrink()
                              : _StopDetail(
                                  key: const Key('stop-detail'),
                                  stop: selected,
                                ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StopDetail extends StatelessWidget {
  const _StopDetail({super.key, required this.stop});

  final Stop stop;

  static String _egp(int piasters) =>
      'EGP ${piasters ~/ 100}.${(piasters % 100).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    final status = switch (stop.status) {
      StopStatus.pending => 'Pending',
      StopStatus.delivered => 'Delivered',
      StopStatus.failed => 'Failed',
    };
    Widget field(String label, String value) => Padding(
          padding: const EdgeInsetsDirectional.only(top: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: theme.labelMedium),
              Text(value, style: theme.bodyLarge),
            ],
          ),
        );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(stop.customerName, style: theme.headlineSmall),
          field('Address', stop.address),
          field('Phone', stop.phone),
          field('Cash on delivery', _egp(stop.codPiasters)),
          field('Status', status),
        ],
      ),
    );
  }
}
