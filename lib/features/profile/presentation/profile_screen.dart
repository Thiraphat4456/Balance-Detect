import 'package:balance_detect/core/providers/app_providers.dart';
import 'package:balance_detect/core/utils/id_generator.dart';
import 'package:balance_detect/core/widgets/app_scaffold_body.dart';
import 'package:balance_detect/core/widgets/loading_view.dart';
import 'package:balance_detect/features/profile/domain/patient_profile.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _ageController = TextEditingController();
  final _notesController = TextEditingController();
  PatientProfile? _profile;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final profile = await ref.read(assessmentRepositoryProvider).getProfile();
      if (!mounted) return;
      _profile = profile;
      _nameController.text = profile?.displayName ?? '';
      _ageController.text = profile?.age?.toString() ?? '';
      _notesController.text = profile?.notes ?? '';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    final profile = PatientProfile(
      id: _profile?.id ?? IdGenerator.generate('profile'),
      displayName: _nameController.text.trim(),
      age: _ageController.text.trim().isEmpty
          ? null
          : int.parse(_ageController.text.trim()),
      notes: _notesController.text.trim(),
      updatedAt: DateTime.now(),
    );
    try {
      await ref.read(assessmentRepositoryProvider).saveProfile(profile);
      _profile = profile;
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('บันทึกโปรไฟล์แล้ว')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const LoadingView(label: 'กำลังโหลดโปรไฟล์');
    return Scaffold(
      appBar: AppBar(title: const Text('โปรไฟล์')),
      body: AppScaffoldBody(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'ข้อมูลผู้ทดสอบ',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              const Text(
                'เก็บเฉพาะข้อมูลที่จำเป็นบนอุปกรณ์นี้ เพื่อใช้ประกอบประวัติการประเมิน',
              ),
              const SizedBox(height: 22),
              TextFormField(
                controller: _nameController,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'ชื่อหรือรหัสผู้ทดสอบ',
                  prefixIcon: Icon(Icons.badge_outlined),
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'กรุณาระบุชื่อหรือรหัส'
                    : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _ageController,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'อายุ (ไม่บังคับ)',
                  prefixIcon: Icon(Icons.cake_outlined),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) return null;
                  final age = int.tryParse(value.trim());
                  if (age == null || age < 1 || age > 120) {
                    return 'กรุณาระบุอายุ 1–120 ปี';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _notesController,
                minLines: 3,
                maxLines: 5,
                maxLength: 500,
                decoration: const InputDecoration(
                  labelText: 'หมายเหตุ (ไม่บังคับ)',
                  alignLabelWithHint: true,
                  prefixIcon: Icon(Icons.notes_outlined),
                ),
              ),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_outlined),
                label: Text(_saving ? 'กำลังบันทึก' : 'บันทึกข้อมูล'),
              ),
              if (kDebugMode) ...[
                const SizedBox(height: 28),
                const Divider(),
                const SizedBox(height: 10),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Developer debug overlay'),
                  subtitle: const Text(
                    'แสดง FPS, confidence และข้อมูลเซนเซอร์ระหว่างพัฒนา',
                  ),
                  value: ref.watch(debugOverlayProvider),
                  onChanged: (value) =>
                      ref.read(debugOverlayProvider.notifier).setEnabled(value),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
