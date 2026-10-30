import 'package:flutter/material.dart';

import '../main.dart';
import 'borrow_form.dart';
import 'equipment_detail.dart';

class EquipmentListPage extends StatefulWidget {
  const EquipmentListPage({super.key});
  @override
  State<EquipmentListPage> createState() => _EquipmentListPageState();
}

class _EquipmentListPageState extends State<EquipmentListPage> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Equipment>>(
      stream: streamEquipment(),
      builder: (context, snap) {
        if (snap.hasError) return Center(child: Text('Error: ${snap.error}'));
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());

        final all = snap.data!;
        final q = _q.toLowerCase();
        final items = all
            .where((e) =>
        e.name.toLowerCase().contains(q) ||
            e.description.toLowerCase().contains(q) ||
            e.category.toLowerCase().contains(q))
            .toList();

        return Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: SearchBar(
              hintText: 'Search equipment...',
              leading: const Icon(Icons.search, color: BorrowColors.navy),
              shape: WidgetStatePropertyAll(RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: BorrowColors.cardBorder),
              )),
              elevation: const WidgetStatePropertyAll(0),
              backgroundColor: const WidgetStatePropertyAll(Colors.white),
              onChanged: (v) => setState(() => _q = v),
            ),
          ),
          Expanded(
            child: all.isEmpty
                ? Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Text('No equipment yet'),
                TextButton(
                  onPressed: seedSamples,
                  child: const Text('Add sample equipment (demo)'),
                ),
              ]),
            )
                : items.isEmpty
                ? const Center(child: Text('No equipment found'))
                : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              itemBuilder: (_, i) => _EquipmentTile(items[i]),
            ),
          ),
        ]);
      },
    );
  }
}

class _EquipmentTile extends StatelessWidget {
  final Equipment e;
  const _EquipmentTile(this.e);

  @override
  Widget build(BuildContext context) {
    final ok = e.available > 0;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: BorrowColors.cardBorder),
      ),
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: EquipmentImage(name: e.name, imageUrl: e.imageUrl),
        title: Text(e.name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SizedBox(height: 2),
          Text(e.category, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
          Text(e.description, maxLines: 2, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 8),
          Row(children: [
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: ok ? BorrowColors.navy : Colors.grey.shade400,
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              ),
              onPressed: ok
                  ? () => Navigator.push(
                  context, MaterialPageRoute(builder: (_) => BorrowFormPage(e)))
                  : null,
              child: const Text('Borrow'),
            ),
            const SizedBox(width: 10),
            Text(
              ok ? '${e.available}/${e.total} available' : 'Unavailable',
              style: TextStyle(
                color: ok ? Colors.green.shade700 : Colors.red.shade700,
                fontWeight: FontWeight.w600,
              ),
            ),
          ]),
        ]),
        onTap: () => Navigator.push(
            context, MaterialPageRoute(builder: (_) => EquipmentDetailPage(e.id))),
      ),
    );
  }
}