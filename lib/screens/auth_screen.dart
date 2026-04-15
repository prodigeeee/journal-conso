import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' as io;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import '../widgets/glass_widgets.dart';

class AuthScreen extends StatefulWidget {
  final VoidCallback onAuthSuccess;
  final Color accentColor;
  final bool isDarkMode;

  const AuthScreen({
    super.key,
    required this.onAuthSuccess,
    required this.accentColor,
    required this.isDarkMode,
  });

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController(text: "Moi");
  final _ageController = TextEditingController(text: "35");
  final _weightController = TextEditingController(text: "70");
  String _gender = 'Homme';
  String? _imagePath;
  
  bool _isSignUp = false;
  bool _isLoading = false;

  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 50);
    if (image != null) {
      setState(() => _imagePath = image.path);
    }
  }

  Future<void> _handleAuth() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) return;
    
    setState(() => _isLoading = true);
    try {
      if (_isSignUp) {
        final res = await Supabase.instance.client.auth.signUp(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
          data: {
            'display_name': _nameController.text,
            'age': int.tryParse(_ageController.text) ?? 35,
            'weight': int.tryParse(_weightController.text) ?? 70,
            'gender': _gender,
            'image_path': _imagePath,
          },
        );
        // Si la session est créée immédiatement (auto-confirm)
        if (res.session != null) {
          widget.onAuthSuccess();
          return;
        }
        // Sinon on prévient qu'il faut vérifier ses mails
        if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Compte créé ! Veuillez vérifier vos e-mails pour valider votre inscription (ou connectez-vous si déjà validé).")),
          );
        }
      } else {
        await Supabase.instance.client.auth.signInWithPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
        widget.onAuthSuccess();
      }
    } on AuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: Colors.redAccent),
        );
      }
    } catch (e) {
      print("Erreur Auth: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Erreur de connexion au serveur"), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _resetPassword() async {
    if (_emailController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Veuillez saisir votre e-mail pour réinitialiser le mot de passe.")),
      );
      return;
    }
    setState(() => _isLoading = true);
    try {
      await Supabase.instance.client.auth.resetPasswordForEmail(_emailController.text.trim());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Lien de réinitialisation envoyé par e-mail !"), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Erreur lors de l'envoi du lien."), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage(widget.isDarkMode ? 'assets/images/background.jpg' : 'assets/images/light_background.jpg'),
            fit: BoxFit.cover,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: glassModule(
              isDarkMode: widget.isDarkMode,
              padding: const EdgeInsets.all(30),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ShaderMask(
                    shaderCallback: (bounds) => const LinearGradient(
                      colors: [Color(0xFFEA9216), Color(0xFFFFCC80)],
                    ).createShader(bounds),
                    child: const Text(
                      "JOURNAL CONSO",
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "SUIVEZ VOTRE CONSOMMATION.\nPRÉSERVEZ VOTRE ÉQUILIBRE.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: widget.accentColor.withValues(alpha: 0.8),
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 40),
                  Text(
                    _isSignUp ? "CRÉER UN COMPTE" : "CONNEXION",
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: widget.isDarkMode ? Colors.white : Colors.black87),
                  ),
                  const SizedBox(height: 30),
                  _buildTextField(_emailController, "E-mail", Icons.email_outlined, false),
                  const SizedBox(height: 15),
                  _buildTextField(_passwordController, "Mot de passe", Icons.lock_outline, true),
                  
                  if (_isSignUp) ...[
                    const SizedBox(height: 15),
                    const Divider(color: Colors.white10),
                    const SizedBox(height: 15),
                    
                    // Sélecteur de Photo de Profil
                    Center(
                      child: GestureDetector(
                        onTap: _pickImage,
                        child: Stack(
                          children: [
                            CircleAvatar(
                              radius: 40,
                              backgroundColor: Colors.white10,
                              backgroundImage: _imagePath != null 
                                ? (kIsWeb ? NetworkImage(_imagePath!) : FileImage(io.File(_imagePath!)) as ImageProvider)
                                : null,
                              child: _imagePath == null 
                                ? Icon(Icons.add_a_photo_outlined, color: widget.accentColor, size: 30)
                                : null,
                            ),
                            if (_imagePath != null)
                              Positioned(
                                right: 0,
                                bottom: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(color: widget.accentColor, shape: BoxShape.circle),
                                  child: const Icon(Icons.edit, size: 12, color: Colors.white),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    
                    _buildTextField(_nameController, "Prénom", Icons.person_outline, false),
                    const SizedBox(height: 15),
                    Row(
                      children: [
                        Expanded(child: _buildTextField(_ageController, "Âge", Icons.cake_outlined, false, isNumber: true)),
                        const SizedBox(width: 10),
                        Expanded(child: _buildTextField(_weightController, "Poids (kg)", Icons.monitor_weight_outlined, false, isNumber: true)),
                      ],
                    ),
                    const SizedBox(height: 15),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: ['Homme', 'Femme'].map((g) => GestureDetector(
                        onTap: () => setState(() => _gender = g),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                          decoration: BoxDecoration(
                            color: _gender == g ? widget.accentColor : Colors.white10,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(g, style: TextStyle(color: _gender == g ? Colors.white : Colors.white54, fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                      )).toList(),
                    ),
                  ],
                  
                  if (!_isSignUp) 
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _resetPassword,
                        child: Text(
                          "Mot de passe oublié ?",
                          style: TextStyle(fontSize: 11, color: widget.accentColor),
                        ),
                      ),
                    ),
                  const SizedBox(height: 25),
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _handleAuth,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: widget.accentColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                        elevation: 0,
                      ),
                      child: _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : Text(
                              _isSignUp ? "C'EST PARTI !" : "SE CONNECTER",
                              style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2),
                            ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextButton(
                    onPressed: () => setState(() => _isSignUp = !_isSignUp),
                    child: Text(
                      _isSignUp ? "Déjà un compte ? Connectez-vous" : "Pas de compte ? Inscrivez-vous",
                      style: TextStyle(color: widget.isDarkMode ? Colors.white70 : Colors.black54),
                    ),
                  ),
                  const Divider(height: 40, color: Colors.white10),
                  Text(
                    "Vos données sont chiffrées et sécurisées par Supabase",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 10, color: widget.isDarkMode ? Colors.white38 : Colors.black38),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, IconData icon, bool isPassword, {bool isNumber = false}) {
    return Container(
      decoration: BoxDecoration(
        color: widget.isDarkMode ? Colors.black26 : Colors.white.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextField(
        controller: controller,
        obscureText: isPassword,
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        style: TextStyle(color: widget.isDarkMode ? Colors.white : Colors.black87),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: widget.isDarkMode ? Colors.white54 : Colors.black54, fontSize: 13),
          prefixIcon: Icon(icon, color: widget.accentColor, size: 20),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }
}
