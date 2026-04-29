import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/providers/theme_provider.dart';
import '../../../core/utils/snackbar_utils.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  bool isLogin = true;
  bool isLoading = false;
  bool obscurePassword = true;
  
  // Controllers
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final usernameController = TextEditingController();
  final phoneController = TextEditingController();
  final dobController = TextEditingController();
  final firstNameController = TextEditingController();
  final lastNameController = TextEditingController();

  final supabase = Supabase.instance.client;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    usernameController.dispose();
    phoneController.dispose();
    dobController.dispose();
    firstNameController.dispose();
    lastNameController.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    setState(() => isLoading = true);
    try {
      if (isLogin) {
        // Login Logic
        String emailToLogin = emailController.text.trim();
        final password = passwordController.text;

        // Check if input is not an email (meaning it's a username)
        if (!emailToLogin.contains('@')) {
          final res = await supabase.rpc(
            'get_email_by_username',
            params: {'lookup_username': emailToLogin},
          );
          
          if (res == null || res.toString().isEmpty) {
            throw Exception('Username not found. Please check your username or try email.');
          }
          
          // Found the email for this username
          emailToLogin = res.toString();
        }

        await supabase.auth.signInWithPassword(
          email: emailToLogin,
          password: password,
        );
        
        if (mounted) {
          SnackbarUtils.showSuccess('Login Successful');
        }
      } else {
        // Signup Logic
        final res = await supabase.auth.signUp(
          email: emailController.text.trim(),
          password: passwordController.text,
        );
        
        if (res.user != null) {
          // Insert profile data
          await supabase.from('profiles').insert({
            'id': res.user!.id,
            'username': usernameController.text.trim(),
            if (firstNameController.text.trim().isNotEmpty) 'first_name': firstNameController.text.trim(),
            if (lastNameController.text.trim().isNotEmpty) 'last_name': lastNameController.text.trim(),
            if (phoneController.text.trim().isNotEmpty) 'phone_number': phoneController.text.trim(),
            if (dobController.text.trim().isNotEmpty) 'dob': dobController.text.trim(),
          });
          
          if (mounted) {
            SnackbarUtils.showSuccess('Registration Successful!');
          }
        }
      }
    } catch (e) {
      if (mounted) {
        SnackbarUtils.showError(e.toString());
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: Icon(
              isDark ? Icons.light_mode : Icons.dark_mode,
              color: Theme.of(context).colorScheme.onSurface,
            ),
            onPressed: () {
              ref.read(themeProvider.notifier).toggleTheme();
            },
          ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 10),
                  Text(
                    'Go ahead and set up\nyour account',
                    style: TextStyle(
                      fontSize: 28, 
                      fontWeight: FontWeight.bold, 
                      height: 1.2,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Sign in-up to enjoy the best managing experience',
                    style: TextStyle(color: Colors.grey[400], fontSize: 14),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
          SliverFillRemaining(
            hasScrollBody: false,
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(32),
                  topRight: Radius.circular(32),
                ),
              ),
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                    // Toggle
                    Container(
                      height: 50,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.grey[900] : Colors.grey[100],
                        borderRadius: BorderRadius.circular(25),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setState(() => isLogin = true),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: isLogin 
                                      ? (isDark ? Colors.grey[800] : Colors.white) 
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(25),
                                  boxShadow: isLogin ? [
                                    BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)
                                  ] : null,
                                ),
                                alignment: Alignment.center,
                                child: Text('Login', style: TextStyle(
                                  color: isLogin ? Theme.of(context).colorScheme.onSurface : Colors.grey,
                                  fontWeight: FontWeight.bold,
                                )),
                              ),
                            ),
                          ),
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setState(() => isLogin = false),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: !isLogin 
                                      ? (isDark ? Colors.grey[800] : Colors.white) 
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(25),
                                  boxShadow: !isLogin ? [
                                    BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)
                                  ] : null,
                                ),
                                alignment: Alignment.center,
                                child: Text('Register', style: TextStyle(
                                  color: !isLogin ? Theme.of(context).colorScheme.onSurface : Colors.grey,
                                  fontWeight: FontWeight.bold,
                                )),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // Form fields
                    if (!isLogin) ...[
                      Row(
                        children: [
                          Expanded(
                            child: _buildTextField(
                              controller: firstNameController,
                              label: 'First Name',
                              icon: Icons.person_outline,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildTextField(
                              controller: lastNameController,
                              label: 'Last Name',
                              icon: Icons.person_outline,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        controller: usernameController,
                        label: 'Username',
                        icon: Icons.alternate_email,
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        controller: phoneController,
                        label: 'Phone Number',
                        icon: Icons.phone_outlined,
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        controller: dobController,
                        label: 'Date of Birth',
                        icon: Icons.calendar_today_outlined,
                        readOnly: true,
                        onTap: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: DateTime.now().subtract(const Duration(days: 365 * 18)),
                            firstDate: DateTime(1900),
                            lastDate: DateTime.now(),
                            builder: (context, child) {
                              return Theme(
                                data: Theme.of(context).copyWith(
                                  colorScheme: Theme.of(context).colorScheme.copyWith(
                                    primary: const Color(0xFF799E83),
                                    onPrimary: Colors.white,
                                  ),
                                ),
                                child: child!,
                              );
                            },
                          );
                          if (date != null) {
                            final formatted = "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
                            dobController.text = formatted;
                          }
                        },
                      ),
                      const SizedBox(height: 16),
                    ],
                    _buildTextField(
                      controller: emailController,
                      label: isLogin ? 'Email Address or Username' : 'Email Address',
                      icon: Icons.email_outlined,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: passwordController,
                      label: 'Password',
                      icon: Icons.lock_outline,
                      isPassword: true,
                      obscureText: obscurePassword,
                      onSuffixTap: () {
                        setState(() {
                          obscurePassword = !obscurePassword;
                        });
                      },
                    ),
                    
                    if (isLogin) ...[
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          SizedBox(
                            height: 24,
                            width: 24,
                            child: Checkbox(
                              value: true,
                              onChanged: (v) {},
                              activeColor: const Color(0xFF799E83),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text('Remember me', style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 12)),
                          const Spacer(),
                          const Text('Forgot Password?', style: TextStyle(color: Colors.black54, fontSize: 12)),
                        ],
                      ),
                    ],
                    
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: isLoading ? null : submit,
                        child: isLoading 
                          ? const CircularProgressIndicator(color: Colors.white)
                          : Text(isLogin ? 'Login' : 'Register', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    
                    const SizedBox(height: 24),
                    const Row(
                      children: [
                        Expanded(child: Divider()),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16.0),
                          child: Text('Or login with', style: TextStyle(color: Colors.grey, fontSize: 12)),
                        ),
                        Expanded(child: Divider()),
                      ],
                    ),
                    const SizedBox(height: 24),
                    
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildSocialButton('Google', 'assets/google.png', Theme.of(context).colorScheme.onSurface),
                        _buildSocialButton('Facebook', 'assets/facebook.png', Colors.blue),
                      ],
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ],
        ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool isPassword = false,
    bool readOnly = false,
    bool obscureText = false,
    VoidCallback? onTap,
    VoidCallback? onSuffixTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          obscureText: isPassword ? obscureText : false,
          readOnly: readOnly,
          onTap: onTap,
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: Colors.grey),
            suffixIcon: isPassword 
                ? IconButton(
                    icon: Icon(
                      obscureText ? Icons.visibility_off : Icons.visibility,
                      color: Colors.grey,
                    ),
                    onPressed: onSuffixTap,
                  ) 
                : null,
            filled: true,
            fillColor: isDark ? Colors.grey[900] : Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: isDark ? Colors.grey[800]! : Colors.grey[300]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: isDark ? Colors.grey[800]! : Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFF799E83)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSocialButton(String text, String assetPath, Color textColor) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(
        border: Border.all(color: isDark ? Colors.grey[800]! : Colors.grey[300]!),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          // Icon placeholder
          Icon(Icons.g_mobiledata, color: textColor), // Replace with asset
          const SizedBox(width: 8),
          Text(text, style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
