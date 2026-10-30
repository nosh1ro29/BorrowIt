import 'dart:async';

import 'package:flutter/material.dart';

import '../main.dart';
import 'equipment_list.dart';
import 'requests_page.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _tab = 0;
  static const _titles = ['Equipment', 'My Requests', 'Borrowing History'];

  StreamSubscription<List<BorrowRequest>>? _sub;
  Timer? _timer;
  List<BorrowRequest> _latest = [];
  final Map<String, Status> _last = {};
  bool _first = true;

  @override
  void initState() {
    super.initState();
    _sub = streamMyRequests().listen((list) {
      _latest = list;
      for (final r in list) {
        final old = _last[r.id];
        if (!_first && old != null && old != r.status) {
          showNotification(r.id, 'Request ${r.status.label}',
              '"${r.equipmentName}" is now ${r.status.name}.');
          if (r.status == Status.returned || r.status == Status.cancelled) {
            cancelReminder(r.id);
          }
        }
        _last[r.id] = r.status;
      }
      _first = false;
    });

    _timer = Timer.periodic(
      const Duration(seconds: 5),
          (_) => autoAdvanceRequests(_latest),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const pages = [
      EquipmentListPage(),
      MyRequestsPage(history: false),
      MyRequestsPage(history: true),
    ];

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: Row(children: [
          const BorrowItLogo(size: 34),
          const SizedBox(width: 12),
          Text(_titles[_tab], style: const TextStyle(fontWeight: FontWeight.bold)),
        ]),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.account_circle, color: BorrowColors.gold),
            onSelected: (_) => logout(),
            itemBuilder: (_) => [
              PopupMenuItem(
                enabled: false,
                child: Text(currentUserName(),
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(value: 'out', child: Text('Logout')),
            ],
          ),
        ],
      ),
      body: pages[_tab],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.devices), label: 'Equipment'),
          NavigationDestination(icon: Icon(Icons.assignment), label: 'My Requests'),
          NavigationDestination(icon: Icon(Icons.history), label: 'History'),
        ],
      ),
    );
  }
}