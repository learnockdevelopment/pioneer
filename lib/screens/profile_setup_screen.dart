import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:elmasa/providers/workspace_provider.dart';
import 'package:elmasa/providers/language_provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  bool _isLoading = false;
  File? _selectedImage;
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final wp = Provider.of<WorkspaceProvider>(context, listen: false);
      final user = wp.cachedME?['user'] as Map<String, dynamic>? ?? {};
      final phoneArg = ModalRoute.of(context)?.settings.arguments as String?;
      _nameController.text = user['name'] ?? wp.activeWorkspace?.studentName ?? '';
      _phoneController.text = phoneArg ?? user['phone'] ?? '';
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
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

  Future<void> _pickImage(ImageSource source) async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: source, imageQuality: 80);
    if (image != null) {
      setState(() {
        _selectedImage = File(image.path);
      });
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
                style: GoogleFonts.cairo(fontSize: 18, fontWeight: FontWeight.bold),
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
                      _pickImage(ImageSource.camera);
                    },
                  ),
                  _buildImagePickerOption(
                    icon: Icons.photo_library_rounded,
                    label: isRTL ? 'المعرض' : 'Gallery',
                    onTap: () {
                      Navigator.pop(context);
                      _pickImage(ImageSource.gallery);
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
          Text(label, style: GoogleFonts.cairo(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Future<void> _submitProfile() async {
    setState(() => _isLoading = true);
    final wp = Provider.of<WorkspaceProvider>(context, listen: false);
    try {
      String? avatarUrl;
      if (_selectedImage != null) {
        try {
          avatarUrl = await _uploadImage(_selectedImage!, _selectedImage!.path.split('/').last);
        } catch (imgErr) {
          debugPrint('⚠️ Profile image upload error: $imgErr');
        }
      }
      
      try {
        await wp.updateProfile(
          name: _nameController.text.trim(),
          phone: _phoneController.text.trim(),
          avatarUrl: avatarUrl,
        );
      } catch (updateErr) {
        debugPrint('⚠️ Profile update API error: $updateErr');
        final errStr = updateErr.toString().toLowerCase();
        if (!errStr.contains('404') && !errStr.contains('not found')) {
          rethrow;
        }
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('profile_setup_skipped_${wp.activeWorkspace?.id}', true);

      if (mounted) {
        Navigator.pushReplacementNamed(context, '/dashboard');
      }
    } catch (e) {
      debugPrint('❌ SUBMIT PROFILE FAILED: $e');
      if (mounted) {
        final msg = e.toString().replaceAll('Exception: ', '').replaceAll('ServerException: ', '');
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(msg),
          backgroundColor: Colors.redAccent,
        ));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _skip() async {
    final wp = Provider.of<WorkspaceProvider>(context, listen: false);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('profile_setup_skipped_${wp.activeWorkspace?.id}', true);
    if (mounted) {
      Navigator.pushReplacementNamed(context, '/dashboard');
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = Provider.of<LanguageProvider>(context);
    final isRTL = lang.currentLocale.languageCode == 'ar';
    final primaryColor = Theme.of(context).primaryColor;
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _skip,
            child: Text(
              lang.translate('skip') ?? (isRTL ? 'تخطي' : 'Skip'),
              style: GoogleFonts.cairo(color: onSurface.withOpacity(0.6), fontWeight: FontWeight.bold),
            ),
          )
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                isRTL ? 'إعداد الملف الشخصي' : 'Profile Setup',
                style: GoogleFonts.cairo(color: onSurface, fontSize: 28, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              Text(
                isRTL ? 'قم بإضافة صورتك وتحديث بياناتك' : 'Add your photo and update your details',
                style: GoogleFonts.cairo(color: onSurface.withOpacity(0.6), fontSize: 14),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),
              GestureDetector(
                onTap: _showImagePickerBottomSheet,
                child: Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    Container(
                      width: 130,
                      height: 130,
                      decoration: BoxDecoration(
                        color: primaryColor.withOpacity(0.1),
                        shape: BoxShape.circle,
                        border: Border.all(color: primaryColor, width: 3),
                        boxShadow: [
                          BoxShadow(
                            color: primaryColor.withOpacity(0.2),
                            blurRadius: 20,
                            spreadRadius: 2,
                            offset: const Offset(0, 8),
                          )
                        ],
                        image: _selectedImage != null
                            ? DecorationImage(image: FileImage(_selectedImage!), fit: BoxFit.cover)
                            : null,
                      ),
                      child: _selectedImage == null
                          ? Icon(Icons.person_rounded, size: 60, color: primaryColor.withOpacity(0.5))
                          : null,
                    ),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: primaryColor,
                        shape: BoxShape.circle,
                        border: Border.all(color: Theme.of(context).scaffoldBackgroundColor, width: 4),
                      ),
                      child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 20),
                    )
                  ],
                ),
              ),
              const SizedBox(height: 48),
              _buildModernTextField(
                controller: _nameController,
                label: lang.translate('full_name') ?? (isRTL ? 'الاسم كامل' : 'Full Name'),
                icon: Icons.person_outline_rounded,
                isRTL: isRTL,
              ),
              const SizedBox(height: 20),
              _buildModernTextField(
                controller: _phoneController,
                label: lang.translate('phone_number') ?? (isRTL ? 'رقم الهاتف' : 'Phone Number'),
                icon: Icons.phone_outlined,
                isRTL: isRTL,
              ),
              const SizedBox(height: 48),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submitProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    elevation: 8,
                    shadowColor: primaryColor.withOpacity(0.4),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: _isLoading
                      ? const SpinKitThreeBounce(color: Colors.white, size: 24)
                      : Text(
                          (lang.translate('save') ?? (isRTL ? 'حفظ' : 'SAVE')).toUpperCase(),
                          style: GoogleFonts.cairo(fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 1.0),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModernTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required bool isRTL,
  }) {
    final primaryColor = Theme.of(context).primaryColor;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        textAlign: isRTL ? TextAlign.right : TextAlign.left,
        textDirection: isRTL ? TextDirection.rtl : TextDirection.ltr,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: GoogleFonts.cairo(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5)),
          prefixIcon: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Icon(icon, color: primaryColor.withOpacity(0.7)),
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
        ),
      ),
    );
  }
}
