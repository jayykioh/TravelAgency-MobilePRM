import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/hotel_state.dart';

class GuestSelector extends StatelessWidget {
  const GuestSelector({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<HotelState>();
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => showModalBottomSheet<void>(
        context: context,
        builder: (_) => const _GuestSheet(),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            const Icon(Icons.people_outline, color: Color(0xFFFF5E1F)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '${state.guests} Adults · ${state.children} Children · ${state.rooms} Room',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GuestSheet extends StatelessWidget {
  const _GuestSheet();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<HotelState>();
    Widget counter(
      String label,
      int value,
      VoidCallback minus,
      VoidCallback plus,
    ) => ListTile(
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton.outlined(onPressed: minus, icon: const Icon(Icons.remove)),
          SizedBox(
            width: 34,
            child: Text('$value', textAlign: TextAlign.center),
          ),
          IconButton.filled(onPressed: plus, icon: const Icon(Icons.add)),
        ],
      ),
    );
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            counter(
              'Adults',
              state.guests,
              () => state.updateGuestConfig(adults: state.guests - 1),
              () => state.updateGuestConfig(adults: state.guests + 1),
            ),
            counter(
              'Children',
              state.children,
              () => state.updateGuestConfig(childGuests: state.children - 1),
              () => state.updateGuestConfig(childGuests: state.children + 1),
            ),
            counter(
              'Rooms',
              state.rooms,
              () => state.updateGuestConfig(roomCount: state.rooms - 1),
              () => state.updateGuestConfig(roomCount: state.rooms + 1),
            ),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Done'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
