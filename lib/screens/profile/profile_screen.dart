import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../services/storage_service.dart';
import '../../models/user_model.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _authService = AuthService();
  final _firestoreService = FirestoreService();
  final _storageService = StorageService();
  bool _uploadingAvatar = false;

  Future<void> _uploadAvatar(String uid) async {
    final file = await _storageService.pickImage();
    if (file == null) return;
    setState(() => _uploadingAvatar = true);
    try {
      final url = await _storageService.uploadAvatar(uid, file);
      await _firestoreService.updateUser(uid, {'avatarUrl': url});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to upload avatar: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _uploadingAvatar = false);
    }
  }

  Future<void> _signOut() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
    if (confirm == true) await _authService.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: StreamBuilder<UserModel?>(
        stream: _firestoreService
            .getUser(uid)
            .asStream(),
        builder: (context, snapshot) {
          final user = snapshot.data;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const SizedBox(height: 16),
                // Avatar
                GestureDetector(
                  onTap: () => _uploadAvatar(uid),
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 52,
                        backgroundColor:
                            const Color(0xFF00897B).withOpacity(0.2),
                        backgroundImage: user?.avatarUrl != null
                            ? NetworkImage(user!.avatarUrl!)
                            : null,
                        child: user?.avatarUrl == null
                            ? Text(
                                (user?.displayName.isNotEmpty == true
                                    ? user!.displayName[0].toUpperCase()
                                    : '?'),
                                style: const TextStyle(
                                    fontSize: 36,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF00897B)),
                              )
                            : null,
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: const BoxDecoration(
                            color: Color(0xFF00897B),
                            shape: BoxShape.circle,
                          ),
                          child: _uploadingAvatar
                              ? const Padding(
                                  padding: EdgeInsets.all(6),
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white),
                                )
                              : const Icon(Icons.camera_alt,
                                  color: Colors.white, size: 16),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  user?.displayName ?? 'Traveler',
                  style: const TextStyle(
                      fontSize: 22, fontWeight: FontWeight.bold),
                ),
                Text(
                  user?.email ?? '',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
                const SizedBox(height: 32),

                // Stats row
                Row(
                  children: [
                    _StatBox(
                      value: '${user?.tripIds.length ?? 0}',
                      label: 'Trips',
                    ),
                  ],
                ),
                const SizedBox(height: 32),

                // Settings tiles
                _SettingsTile(
                  icon: Icons.person_outline,
                  label: 'Edit Display Name',
                  onTap: () => _showEditNameDialog(context, uid,
                      user?.displayName ?? ''),
                ),
                const Divider(height: 1),
                _SettingsTile(
                  icon: Icons.notifications_outlined,
                  label: 'Notifications',
                  onTap: () {},
                ),
                const Divider(height: 1),
                _SettingsTile(
                  icon: Icons.privacy_tip_outlined,
                  label: 'Privacy',
                  onTap: () {},
                ),
                const Divider(height: 1),
                _SettingsTile(
                  icon: Icons.logout,
                  label: 'Sign Out',
                  color: Colors.red,
                  onTap: _signOut,
                ),
                const SizedBox(height: 32),
                Text(
                  'TropicaGuide v1.0.0',
                  style: TextStyle(
                      color: Colors.grey.shade400, fontSize: 12),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showEditNameDialog(
      BuildContext context, String uid, String current) {
    final ctrl = TextEditingController(text: current);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Display Name'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Your name'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (ctrl.text.trim().isNotEmpty) {
                await _firestoreService.updateUser(
                    uid, {'displayName': ctrl.text.trim()});
                if (ctx.mounted) Navigator.pop(ctx);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  final String value;
  final String label;
  const _StatBox({required this.value, required this.label});

  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: const Color(0xFF00897B).withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Text(value,
                  style: const TextStyle(
                      fontSize: 28, fontWeight: FontWeight.bold,
                      color: Color(0xFF00897B))),
              Text(label,
                  style: TextStyle(color: Colors.grey.shade600)),
            ],
          ),
        ),
      );
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;
  final VoidCallback onTap;
  const _SettingsTile(
      {required this.icon,
      required this.label,
      this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) => ListTile(
        leading: Icon(icon, color: color ?? Colors.grey.shade700),
        title: Text(label,
            style: TextStyle(color: color, fontWeight: FontWeight.w500)),
        trailing:
            const Icon(Icons.chevron_right, color: Colors.grey),
        onTap: onTap,
      );
}