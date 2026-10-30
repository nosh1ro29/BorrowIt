import 'package:flutter/material.dart';

import 'dart:convert';
import '../main.dart';


class RequestDetailPage extends StatelessWidget {
  final String requestId;
  const RequestDetailPage(this.requestId, {super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<BorrowRequest?>(
      stream: streamRequest(requestId),
      builder: (context, snap) {
        final r = snap.data;
        if (r == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Request')),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        const steps = [Status.pending, Status.approved, Status.borrowed, Status.returned];
        final cancelled = r.status == Status.cancelled;
        final current = steps.indexOf(r.status);

        return Scaffold(
          appBar: AppBar(title: Text('Request #${r.id.substring(0, 5).toUpperCase()}')),
          body: ListView(padding: const EdgeInsets.all(16), children: [
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: BorrowColors.cardBorder),
              ),
              child: ListTile(
                leading: EquipmentImage(
                    name: r.equipmentName, imageUrl: r.equipmentImageUrl, size: 48),
                title: Text(r.equipmentName),
                trailing: StatusChip(r.status),
              ),
            ),
            const SizedBox(height: 8),
            ListTile(
                leading: const Icon(Icons.event, color: BorrowColors.navy),
                title: const Text('Date needed'),
                subtitle: Text(fmt(r.needed))),
            ListTile(
                leading: const Icon(Icons.event_available, color: BorrowColors.navy),
                title: const Text('Return date'),
                subtitle: Text(fmt(r.returnDate))),
            ListTile(
                leading: const Icon(Icons.notes, color: BorrowColors.navy),
                title: const Text('Purpose'),
                subtitle: Text(r.purpose)),
            if (r.attachmentBase64 != null) ...[
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.memory(
                  base64Decode(r.attachmentBase64!),
                  height: 200,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
            ],
            const Divider(height: 32),
            Text('Request Status',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            if (cancelled)
              const ListTile(
                  leading: Icon(Icons.cancel, color: Colors.grey),
                  title: Text('Cancelled'))
            else
              for (var i = 0; i < steps.length; i++)
                ListTile(
                  dense: true,
                  leading: Icon(
                    i <= current ? Icons.check_circle : Icons.radio_button_unchecked,
                    color: i <= current ? steps[i].color : Colors.grey.shade400,
                  ),
                  title: Text(
                    steps[i].label,
                    style: TextStyle(
                      fontWeight: i == current ? FontWeight.bold : FontWeight.normal,
                      color: i == current ? BorrowColors.navy : Colors.black87,
                    ),
                  ),
                ),
            const SizedBox(height: 20),
            if (r.status == Status.pending)
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(foregroundColor: Colors.redAccent),
                icon: const Icon(Icons.cancel),
                label: const Text('Cancel Request'),
                onPressed: () async {
                  await cancelRequest(r);
                  await cancelReminder(r.id);
                },
              ),
          ]),
        );
      },
    );
  }
}