import 'package:flutter/material.dart';

import '../main.dart';
import 'request_detail.dart';


class MyRequestsPage extends StatelessWidget {
  final bool history;
  const MyRequestsPage({super.key, required this.history});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<BorrowRequest>>(
      stream: streamMyRequests(),
      builder: (context, snap) {
        if (snap.hasError) return Center(child: Text('Error: ${snap.error}'));
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());

        final list = snap.data!
            .where((r) =>
        history ? r.status == Status.returned : r.status != Status.returned)
            .toList();

        if (list.isEmpty) {
          return Center(
            child: Text(
              history
                  ? 'No completed borrowing yet'
                  : 'No requests yet.\nBrowse equipment to make one!',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: list.length,
          itemBuilder: (_, i) => _RequestCard(list[i]),
        );
      },
    );
  }
}

class _RequestCard extends StatelessWidget {
  final BorrowRequest r;
  const _RequestCard(this.r);

  @override
  Widget build(BuildContext context) => Card(
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: const BorderSide(color: BorrowColors.cardBorder),
    ),
    margin: const EdgeInsets.only(bottom: 10),
    child: InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => Navigator.push(
          context, MaterialPageRoute(builder: (_) => RequestDetailPage(r.id))),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(children: [
          EquipmentImage(
              name: r.equipmentName, imageUrl: r.equipmentImageUrl, size: 56),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(r.equipmentName,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              Text('${fmt(r.needed)}  →  ${fmt(r.returnDate)}'),
            ]),
          ),
          StatusChip(r.status),
        ]),
      ),
    ),
  );
}