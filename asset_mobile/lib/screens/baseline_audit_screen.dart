import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';

class BaselineAuditScreen extends StatefulWidget {
  const BaselineAuditScreen({super.key});

  @override
  State<BaselineAuditScreen> createState() => _BaselineAuditScreenState();
}

class _BaselineAuditScreenState extends State<BaselineAuditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _deskNumberController = TextEditingController();
  final _areaController = TextEditingController(text: 'COLLECTION');

  final Map<String, bool> _selectedAssets = {
    'PC': true,
    'MONITOR': true,
    'KEYBOARD': true,
    'MOUSE': true,
    'HEADSET': false,
  };

  bool _isSubmitting = false;

  @override
  void dispose() {
    _deskNumberController.dispose();
    _areaController.dispose();
    super.dispose();
  }

  Future<void> _submitAudit() async {
    if (!_formKey.currentState!.validate()) return;

    final selectedTypes = _selectedAssets.entries
        .where((e) => e.value)
        .map((e) => e.key)
        .toList();

    if (selectedTypes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one asset type')),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final apiService = context.read<ApiService>();
      await apiService.baselineAudit(
        deskNumber: int.parse(_deskNumberController.text),
        area: _areaController.text,
        assetTypes: selectedTypes,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Baseline audit completed')),
      );
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() {
        _isSubmitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Baseline Audit'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Batch create assets for a desk',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _deskNumberController,
              decoration: const InputDecoration(
                labelText: 'Desk Number',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter desk number';
                }
                if (int.tryParse(value) == null) {
                  return 'Please enter a valid number';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _areaController,
              decoration: const InputDecoration(
                labelText: 'Area',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter area';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),
            const Text(
              'Select Asset Types:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ..._selectedAssets.keys.map((type) {
              return CheckboxListTile(
                title: Text(type),
                value: _selectedAssets[type],
                onChanged: (value) {
                  setState(() {
                    _selectedAssets[type] = value ?? false;
                  });
                },
              );
            }),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isSubmitting ? null : _submitAudit,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(16),
              ),
              child: _isSubmitting
                  ? const CircularProgressIndicator()
                  : const Text('Submit Audit'),
            ),
          ],
        ),
      ),
    );
  }
}
