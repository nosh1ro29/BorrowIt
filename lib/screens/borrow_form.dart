import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../main.dart';


class BorrowFormPage extends StatefulWidget {
  final Equipment e;
  const BorrowFormPage(this.e, {super.key});
  @override
  State<BorrowFormPage> createState() => _BorrowFormPageState();
}

class _BorrowFormPageState extends State<BorrowFormPage> {
  final _purpose = TextEditingController();
  DateTime? _needed, _return;
  Uint8List? _image;
  String? _error;
  bool _loading = false;

  @override
  void dispose() {
    _purpose.dispose();
    super.dispose();
  }

  Future<void> _pick(bool isNeeded) async {
    final today = DateUtils.dateOnly(DateTime.now());
    final first = isNeeded ? today : (_needed ?? today);
    final d = await showDatePicker(
      context: context,
      initialDate: (isNeeded ? _needed : _return) ?? first,
      firstDate: first,
      lastDate: today.add(const Duration(days: 365)),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: BorrowColors.navy,
            onPrimary: Colors.white,
            onSurface: BorrowColors.navy,
          ),
        ),
        child: child!,
      ),
    );
    if (d == null) return;
    setState(() {
      if (isNeeded) {
        _needed = d;
        if (_return != null && _return!.isBefore(d)) _return = null;
      } else {
        _return = d;
      }
      _error = null;
    });
  }

  Future<void> _pickImage(ImageSource source) async {
    final x = await ImagePicker()
        .pickImage(source: source, imageQuality: 40, maxWidth: 800);
    if (x == null) return;
    final bytes = await x.readAsBytes();
    setState(() => _image = bytes);
  }

  void _imageOptions() {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Wrap(children: [
          ListTile(
            leading: const Icon(Icons.camera_alt, color: BorrowColors.navy),
            title: const Text('Take a photo'),
            onTap: () {
              Navigator.pop(context);
              _pickImage(ImageSource.camera);
            },
          ),
          ListTile(
            leading: const Icon(Icons.photo_library, color: BorrowColors.navy),
            title: const Text('Choose from gallery'),
            onTap: () {
              Navigator.pop(context);
              _pickImage(ImageSource.gallery);
            },
          ),
        ]),
      ),
    );
  }

  Future<void> _submit() async {
    if (_needed == null || _return == null) {
      setState(() => _error = 'Please choose both dates');
      return;
    }
    if (_purpose.text.trim().length < 5) {
      setState(() => _error = 'Please describe the purpose');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final id = await submitRequest(
        equipment: widget.e,
        needed: _needed!,
        returnDate: _return!,
        purpose: _purpose.text.trim(),
        image: _image,
      );
      await showNotification(id, 'Request submitted',
          'Your request for "${widget.e.name}" is pending approval.');
      await scheduleReturnReminder(id, widget.e.name, _return!);

      if (!mounted) return;
      Navigator.popUntil(context, (r) => r.isFirst);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        backgroundColor: BorrowColors.navy,
        content: Text('Request submitted! Status: Pending'),
      ));
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Borrow Request')),
    body: ListView(padding: const EdgeInsets.all(16), children: [
      Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: BorrowColors.cardBorder),
        ),
        child: ListTile(
          leading: EquipmentImage(
              name: widget.e.name, imageUrl: widget.e.imageUrl, size: 48),
          title: Text(widget.e.name,
              style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
      ),
      const SizedBox(height: 16),
      _DateTile(label: 'Date needed', value: _needed, onTap: () => _pick(true)),
      const SizedBox(height: 12),
      _DateTile(label: 'Return date', value: _return, onTap: () => _pick(false)),
      const SizedBox(height: 12),
      TextField(
        controller: _purpose,
        maxLines: 3,
        decoration: const InputDecoration(
          labelText: 'Purpose',
          alignLabelWithHint: true,
          border: OutlineInputBorder(),
        ),
      ),
      const SizedBox(height: 16),
      const Text('Attach a photo (optional)',
          style: TextStyle(fontWeight: FontWeight.w600)),
      const SizedBox(height: 8),
      if (_image != null)
        Stack(alignment: Alignment.topRight, children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.memory(_image!,
                height: 180, width: double.infinity, fit: BoxFit.cover),
          ),
          IconButton.filled(
            onPressed: () => setState(() => _image = null),
            icon: const Icon(Icons.close),
          ),
        ])
      else
        OutlinedButton.icon(
          onPressed: _imageOptions,
          icon: const Icon(Icons.add_a_photo, color: BorrowColors.navy),
          label: const Text('Camera / Gallery',
              style: TextStyle(color: BorrowColors.navy)),
        ),
      if (_error != null)
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Text(_error!,
              style: const TextStyle(
                  color: Colors.redAccent, fontWeight: FontWeight.bold)),
        ),
      const SizedBox(height: 24),
      FilledButton(
        style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16)),
        onPressed: _loading ? null : _submit,
        child: _loading
            ? const SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(
                strokeWidth: 2, color: Colors.white))
            : const Text('Submit Request',
            style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    ]),
  );
}

class _DateTile extends StatelessWidget {
  final String label;
  final DateTime? value;
  final VoidCallback onTap;
  const _DateTile({required this.label, required this.value, required this.onTap});

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        suffixIcon: const Icon(Icons.calendar_today, color: BorrowColors.navy),
      ),
      child: Text(value == null ? 'Select date' : fmt(value!)),
    ),
  );
}