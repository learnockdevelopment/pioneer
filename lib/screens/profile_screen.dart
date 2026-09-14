import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:elmasa/models/workspace.dart';
import 'package:elmasa/providers/workspace_provider.dart';
import 'package:elmasa/providers/language_provider.dart';
import 'package:elmasa/providers/theme_provider.dart';
import 'package:elmasa/widgets/premium_loader.dart';
import 'package:intl/intl.dart';
import 'package:elmasa/utils/iconly.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isGroupsLoading = false;
  List<dynamic> _groups = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final wp = Provider.of<WorkspaceProvider>(context, listen: false);
      final token = wp.activeWorkspace?.token;
      debugPrint('🔑 [ProfileScreen] Active Workspace Token: $token');
      print('🔑 [ProfileScreen] Active Workspace Token: $token');
      _fetchGroups();
    });
  }

  Future<void> _fetchGroups() async {
    setState(() => _isGroupsLoading = true);
    try {
      final wp = Provider.of<WorkspaceProvider>(context, listen: false);
      await Future.wait([
        wp.getMe(force: true),
        wp.getGroups(force: true),
      ]);
      if (mounted) {
        setState(() {
          _groups = wp.cachedGroups?['groups'] ?? [];
        });
      }
    } catch (_) {} finally {
      if (mounted) setState(() => _isGroupsLoading = false);
    }
  }

  Future<void> _joinGroup(Map<String, dynamic> g) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text("JOIN GROUP", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
        content: Text("Join group ${g['name']}?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text("CANCEL")),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text("YES, JOIN")),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isGroupsLoading = true);
    try {
      final wp = Provider.of<WorkspaceProvider>(context, listen: false);
      await wp.joinGroup(g['id']);
      await _fetchGroups(); // Refresh
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Joined successfully!"), backgroundColor: Colors.green));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isGroupsLoading = false);
    }
  }

  String _stripHtml(String? html) {
    if (html == null) return '';
    RegExp exp = RegExp(r"<[^>]*>", multiLine: true, caseSensitive: true);
    return html.replaceAll(exp, '').trim();
  }

  Future<String?> _uploadImage(File file, String fileName) async {
    final wp = Provider.of<WorkspaceProvider>(context, listen: false);
    final auth = await wp.getImageKitAuth();
    
    final token = auth['token'];
    final signature = auth['signature'];
    final expire = auth['expire'].toString();
    final publicKey = "public_uTRkc37+UR5RO3Rbyo/rR7Iimu0=";
    
    if (token == null || signature == null) {
      throw Exception('Failed to get ImageKit auth');
    }

    var request = http.MultipartRequest('POST', Uri.parse('https://upload.imagekit.io/api/v1/files/upload'));
    request.fields['publicKey'] = publicKey;
    request.fields['signature'] = signature;
    request.fields['expire'] = expire;
    request.fields['token'] = token;
    request.fields['fileName'] = fileName;
    request.fields['useUniqueFileName'] = 'true';
    request.fields['folder'] = '/avatars/';

    request.files.add(await http.MultipartFile.fromPath('file', file.path));

    var response = await request.send();
    var responseData = await response.stream.bytesToString();
    var jsonMap = json.decode(responseData);

    if (response.statusCode == 200) {
      return jsonMap['url'];
    } else {
      throw Exception(jsonMap['message'] ?? 'Upload failed');
    }
  }

  Future<void> _pickAndUploadAvatar(ImageSource source) async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: source, imageQuality: 80);
      if (image != null) {
        setState(() => _isGroupsLoading = true); 
        File file = File(image.path);
        String fileName = image.name;
        String? newUrl = await _uploadImage(file, fileName);
        if (newUrl != null) {
          final wp = Provider.of<WorkspaceProvider>(context, listen: false);
          await wp.updateProfile(avatarUrl: newUrl);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Avatar updated successfully!'), backgroundColor: Colors.green));
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isGroupsLoading = false);
    }
  }

  void _showImagePickerBottomSheet() {
    final lang = Provider.of<LanguageProvider>(context, listen: false);
    final isRTL = lang.currentLocale.languageCode == 'ar';
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                isRTL ? 'اختر صورة الملف الشخصي' : 'Choose Profile Picture',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildImagePickerOption(
                    icon: Icons.camera_alt_rounded,
                    label: isRTL ? 'الكاميرا' : 'Camera',
                    onTap: () {
                      Navigator.pop(context);
                      _pickAndUploadAvatar(ImageSource.camera);
                    },
                  ),
                  _buildImagePickerOption(
                    icon: Icons.photo_library_rounded,
                    label: isRTL ? 'المعرض' : 'Gallery',
                    onTap: () {
                      Navigator.pop(context);
                      _pickAndUploadAvatar(ImageSource.gallery);
                    },
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildImagePickerOption({required IconData icon, required String label, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 32, color: Theme.of(context).primaryColor),
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Future<bool?> _showPremiumAlert(BuildContext context, {
    required String title,
    required String message,
    required String confirmText,
    required String cancelText,
    bool isDestructive = false,
  }) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final onSurfaceVariant = Theme.of(context).colorScheme.onSurfaceVariant;
    final primaryColor = Theme.of(context).primaryColor;
    final lang = Provider.of<LanguageProvider>(context, listen: false);

    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(title, style: TextStyle(fontWeight: FontWeight.w900, color: isDestructive ? const Color(0xFFEF4444) : onSurface, fontSize: 18)),
        content: Text(message, style: TextStyle(color: onSurfaceVariant, fontSize: 14, height: 1.4)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(lang.translate('cancel'), style: const TextStyle(color: Color(0xFF94A3B8)))),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: isDestructive ? const Color(0xFFEF4444) : primaryColor, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: Text(confirmText),
          ),
        ],
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    final wp = Provider.of<WorkspaceProvider>(context);
    final lang = Provider.of<LanguageProvider>(context);
    final theme = Provider.of<ThemeProvider>(context);
    final workspace = wp.activeWorkspace;
    final otherWorkspaces = wp.workspaces.where((w) => w.id != workspace?.id).toList();
    final isRTL = lang.currentLocale.languageCode == 'ar';
    
    final cardColor = Theme.of(context).cardColor;
    final primaryColor = Theme.of(context).primaryColor;
    final onSurface = Theme.of(context).colorScheme.onSurface;

    // SPLIT GROUPS
    final joinedGroups = _groups.where((g) => g['is_member'] == true || g['is_member'] == 1).toList();
    final availableGroups = _groups.where((g) => g['is_member'] == false || g['is_member'] == 0 || g['is_member'] == null).toList();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: cardColor, elevation: 0,
        automaticallyImplyLeading: false,
        leading: IconButton(
          icon: Icon(IconlyLight.category, color: onSurface, size: 24),
          onPressed: () => lang.currentLocale.languageCode == 'ar' ? Scaffold.of(context).openDrawer() : Scaffold.of(context).openEndDrawer(),
        ),
        title: Text(lang.translate('profile') ?? 'Profile', style: TextStyle(color: onSurface, fontSize: 16, fontWeight: FontWeight.w900)),
        centerTitle: true,
        actions: [
          IconButton(icon: Icon(theme.isDarkMode ? Icons.light_mode_rounded : Icons.dark_mode_rounded, color: primaryColor, size: 24), onPressed: () => theme.toggleTheme()),
          IconButton(
            icon: Icon(IconlyLight.notification, color: onSurface, size: 24),
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(lang.translate('no_notifications') ?? 'لا توجد إشعارات جديدة'))),
          ),
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Center(
              child: Column(
                children: [
                      GestureDetector(
                        onTap: _showImagePickerBottomSheet,
                        child: Stack(
                          children: [
                            (() {
                              final Map<String, dynamic> user = (wp.cachedME?['user'] is Map)
                                  ? Map<String, dynamic>.from(wp.cachedME!['user'])
                                  : {};
                              final String? userImageUrl = workspace?.studentPhotoUrl ?? user['image_url'] ?? user['image'] ?? user['avatar'] ?? user['avatar_url'];
                              final bool hasUserImage = userImageUrl != null && userImageUrl.isNotEmpty;
                              
                              return Container(
                                padding: const EdgeInsets.all(3),
                                decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: primaryColor.withOpacity(0.1), width: 2)),
                                child: CircleAvatar(
                                  radius: 40,
                                  backgroundColor: primaryColor,
                                  backgroundImage: hasUserImage ? NetworkImage(userImageUrl!) : null,
                                  child: hasUserImage
                                      ? null
                                      : Text(
                                          (workspace?.studentName ?? 'S')[0],
                                          style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900),
                                        ),
                                ),
                              );
                            })(),
                            Positioned(
                              bottom: 0, 
                              right: 0, 
                              child: Container(
                                padding: const EdgeInsets.all(6), 
                                decoration: BoxDecoration(
                                  color: primaryColor, 
                                  shape: BoxShape.circle, 
                                  border: Border.all(color: cardColor, width: 2)
                                ), 
                                child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 14)
                              )
                            ),
                          ],
                        ),
                      ),
                  const SizedBox(height: 16),
                  Text(workspace?.studentName ?? lang.translate('student_Learnock'), style: TextStyle(color: onSurface, fontSize: 22, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 6),
                  Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: primaryColor.withOpacity(0.08), borderRadius: BorderRadius.circular(100)), child: Text(workspace?.email ?? '', style: TextStyle(color: primaryColor, fontSize: 12, fontWeight: FontWeight.w900))),
                ],
              ),
            ),
            const SizedBox(height: 32),

            if (joinedGroups.isNotEmpty) ...[
              _buildSectionHeader(context, lang.translate('my_current_groups') ?? 'MY GROUPS'),
              const SizedBox(height: 12),
              ...joinedGroups.map((g) => _buildGroupCard(context, g, primaryColor, onSurface, lang)),
              const SizedBox(height: 24),
            ],
            


            const SizedBox(height: 32),
            _buildActionSection(context, wp, lang),

            const SizedBox(height: 32),
            _buildSectionHeader(context, lang.translate('tech_info')),
            const SizedBox(height: 12),
            _buildInfoCard(context, Icons.fingerprint_rounded, lang.translate('device_id'), wp.deviceId),
            _buildInfoCard(context, Icons.info_outline_rounded, lang.translate('version'), '1.0.14'),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupCard(BuildContext context, Map<String, dynamic> g, Color primary, Color onSurface, LanguageProvider lang) {
    bool isMember = g['is_member'] == true || g['is_member'] == 1 || g['is_member'] == 'true';
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(24), border: Border.all(color: isMember ? primary : Theme.of(context).dividerColor, width: 2)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: primary.withOpacity(0.1), shape: BoxShape.circle), child: Icon(Icons.people_rounded, color: primary, size: 20)),
              const SizedBox(width: 16),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(g['name'] ?? '', style: TextStyle(color: onSurface, fontWeight: FontWeight.w900, fontSize: 15)),
                Text("${g['day_name'] ?? ''} @ ${g['session_time'] ?? ''}", style: TextStyle(color: onSurface.withOpacity(0.5), fontSize: 11, fontWeight: FontWeight.bold)),
              ])),
              if (isMember) Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: primary, borderRadius: BorderRadius.circular(100)), child: Text(lang.translate('joined') ?? "JOINED", style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w900)))
              else ElevatedButton(
                onPressed: () => _joinGroup(g),
                style: ElevatedButton.styleFrom(backgroundColor: primary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(horizontal: 16), elevation: 0),
                child: Text(lang.translate('select_action') ?? "SELECT", style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900)),
              ),
            ],
          ),
          if (g['description'] != null) ...[
            const SizedBox(height: 12),
            Text(_stripHtml(g['description']), style: TextStyle(color: onSurface.withOpacity(0.4), fontSize: 11, height: 1.4)),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    final primaryColor = Theme.of(context).primaryColor;
    return Container(width: double.infinity, alignment: AlignmentDirectional.centerStart, child: Text(title.toUpperCase(), style: TextStyle(color: primaryColor, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.5)));
  }

  Widget _buildActionSection(BuildContext context, WorkspaceProvider wp, LanguageProvider lang) {
    final primaryColor = Theme.of(context).primaryColor;
    return Column(
      children: [
        if (wp.activeWorkspace?.enablePurchasing ?? true)
          SizedBox(width: double.infinity, height: 56, child: ElevatedButton(onPressed: () => Navigator.pushNamed(context, '/wallet'), style: ElevatedButton.styleFrom(backgroundColor: primaryColor, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), elevation: 4, shadowColor: primaryColor.withOpacity(0.3)), child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.stars_rounded, size: 20), const SizedBox(width: 10), Text((lang.translate('redeem_voucher') ?? 'CHARGE WALLET').toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 0.5))]))),
        const SizedBox(height: 12),
        InkWell(onTap: () => Navigator.pushNamed(context, '/favorites'), borderRadius: BorderRadius.circular(16), child: Container(height: 56, width: double.infinity, decoration: BoxDecoration(color: primaryColor.withOpacity(0.1), borderRadius: BorderRadius.circular(20)), child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.favorite_rounded, size: 20, color: primaryColor), const SizedBox(width: 10), Text((lang.translate('favorites') ?? 'FAVORITES').toUpperCase(), style: TextStyle(color: primaryColor, fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 0.5))]))),
        const SizedBox(height: 12),
        InkWell(onTap: () async { final nav = Navigator.of(context); final confirmed = await _showPremiumAlert(context, title: lang.translate('logout'), message: lang.translate('logout_confirm'), confirmText: lang.translate('logout'), cancelText: lang.translate('cancel'), isDestructive: true); if (confirmed == true) { showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator())); try { await wp.logout(); } catch (_) {} nav.pushNamedAndRemoveUntil('/onboarding', (route) => false); } }, borderRadius: BorderRadius.circular(12), child: Container(padding: const EdgeInsets.symmetric(vertical: 12), width: double.infinity, child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.logout_rounded, color: Color(0xFFEF4444), size: 18), const SizedBox(width: 10), Text(lang.translate('logout'), style: const TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.w900, fontSize: 14))]))),
      ],
    );
  }

  Widget _buildInfoCard(BuildContext context, IconData icon, String label, String value) {
    final primaryColor = Theme.of(context).primaryColor;
    return Container(margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: primaryColor.withOpacity(0.05), borderRadius: BorderRadius.circular(20), border: Border.all(color: primaryColor.withOpacity(0.05), width: 1)), child: Row(children: [Icon(icon, color: primaryColor.withOpacity(0.4), size: 18), const SizedBox(width: 16), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label.toUpperCase(), style: TextStyle(color: primaryColor.withOpacity(0.5), fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 0.5)), Text(value, style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.w900, fontSize: 13))]))]));
  }
}

