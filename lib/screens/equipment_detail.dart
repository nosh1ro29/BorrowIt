import 'package:flutter/material.dart';

import '../main.dart';
import 'borrow_form.dart';


class EquipmentDetailPage extends StatelessWidget {
  final String equipmentId;
  const EquipmentDetailPage(this.equipmentId, {super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Equipment?>(
      stream: streamEquipmentOne(equipmentId),
      builder: (context, snap) {
        final e = snap.data;
        if (e == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Equipment')),
            body: const Center(child: CircularProgressIndicator()),
          );
        }
        final ok = e.available > 0;

        return Scaffold(
          appBar: AppBar(title: Text(e.name)),
          body: ListView(padding: const EdgeInsets.all(16), children: [
            Center(child: EquipmentImage(name: e.name, imageUrl: e.imageUrl, size: 160)),
            const SizedBox(height: 16),
            Text(e.name,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold, color: BorrowColors.navy)),
            const SizedBox(height: 8),
            Wrap(spacing: 8, children: [
              Chip(
                side: BorderSide.none,
                label: Text(ok ? '${e.available} Available' : 'Unavailable'),
                backgroundColor:
                ok ? BorrowColors.gold.withOpacity(0.2) : Colors.red.shade100,
                labelStyle: TextStyle(
                  color: ok ? const Color(0xFF8D6200) : Colors.red.shade800,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Chip(
                side: BorderSide.none,
                avatar: const Icon(Icons.category, size: 16, color: BorrowColors.navy),
                label: Text(e.category),
                backgroundColor: BorrowColors.navy.withOpacity(0.08),
              ),
            ]),
            const Divider(height: 32),
            Text('Description',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text(e.description),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.inventory, color: BorrowColors.navy),
              title: const Text('Stock'),
              subtitle: Text('${e.available} available of ${e.total} total'),
            ),
          ]),
          bottomNavigationBar: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: ok ? BorrowColors.navy : Colors.grey,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                icon: const Icon(Icons.send),
                label: const Text('Request to Borrow',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                onPressed: ok
                    ? () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => BorrowFormPage(e)))
                    : null,
              ),
            ),
          ),
        );
      },
    );
  }
}