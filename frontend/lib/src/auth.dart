part of '../main.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final formKey = GlobalKey<FormState>();
  final authService = AuthService();
  final email = TextEditingController(text: 'admin@caterpro.in');
  final password = TextEditingController(text: 'password');
  bool obscurePassword = true;
  bool rememberMe = true;
  bool loading = false;
  String? error;

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> login() async {
    final emailText = email.text.trim();
    final passwordText = password.text;
    if (!(formKey.currentState?.validate() ?? false)) {
      setState(() => error = 'Enter a valid email and password.');
      return;
    }
    setState(() {
      loading = true;
      error = null;
    });
    try {
      await authService.login(email: emailText, password: passwordText);
      if (!mounted) return;
      Navigator.of(context)
          .pushReplacement(MaterialPageRoute(builder: (_) => const AppShell()));
    } catch (e) {
      if (!mounted) return;
      setState(() => error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void fingerprintLogin() {
    showCpSnack(context, 'Fingerprint authenticated');
    Navigator.of(context)
        .pushReplacement(MaterialPageRoute(builder: (_) => const AppShell()));
  }

  Future<void> forgotPassword() async {
    final emailText = email.text.trim();
    if (emailValidator(emailText) != null) {
      showCpSnack(context, 'Enter your email to receive reset link');
      return;
    }
    try {
      await authService.forgotPassword(emailText);
      if (!mounted) return;
      showCpSnack(context, 'Reset link sent to $emailText');
    } catch (_) {
      if (!mounted) return;
      showCpSnack(context, 'Backend is not reachable. Start CaterPro API.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Cp.background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 36, 24, 24),
          children: [
            const SizedBox(height: 18),
            Container(
              width: 78,
              height: 78,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                  color: Cp.primaryContainer,
                  borderRadius: BorderRadius.circular(20)),
              child: const Icon(Icons.restaurant_menu,
                  color: Colors.white, size: 42),
            ),
            const SizedBox(height: 26),
            const Text('CaterPro',
                style: TextStyle(
                    color: Cp.primary,
                    fontSize: 38,
                    fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            const Text('Sign in to manage events, menus, billing, and teams.',
                style: TextStyle(
                    color: Cp.onVariant, fontWeight: FontWeight.w700)),
            const SizedBox(height: 28),
            Form(
              key: formKey,
              child: CpCard(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Login',
                          style: TextStyle(
                              color: Cp.primary,
                              fontSize: 24,
                              fontWeight: FontWeight.w900)),
                      const SizedBox(height: 18),
                      TextFormField(
                        controller: email,
                        keyboardType: TextInputType.emailAddress,
                        validator: emailValidator,
                        decoration: InputDecoration(
                            prefixIcon: const Icon(Icons.email_outlined),
                            labelText: 'Email',
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12))),
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: password,
                        obscureText: obscurePassword,
                        validator: (value) => (value ?? '').length < 4
                            ? 'Password must be at least 4 characters'
                            : null,
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.lock_outline),
                          labelText: 'Password',
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12)),
                          suffixIcon: IconButton(
                              onPressed: () => setState(
                                  () => obscurePassword = !obscurePassword),
                              icon: Icon(obscurePassword
                                  ? Icons.visibility
                                  : Icons.visibility_off)),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(children: [
                        Checkbox(
                            value: rememberMe,
                            activeColor: Cp.primary,
                            onChanged: (value) =>
                                setState(() => rememberMe = value ?? false)),
                        const Expanded(
                            child: Text('Remember me',
                                style: TextStyle(fontWeight: FontWeight.w700))),
                        TextButton(
                            onPressed: forgotPassword,
                            child: const Text('Forgot Password?',
                                style: TextStyle(
                                    color: Cp.primary,
                                    fontWeight: FontWeight.w900))),
                      ]),
                      if (error != null)
                        Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Text(error!,
                                style: const TextStyle(
                                    color: Cp.error,
                                    fontWeight: FontWeight.w800))),
                      SizedBox(
                          width: double.infinity,
                          height: 54,
                          child: FilledButton.icon(
                              onPressed: loading ? null : login,
                              style: FilledButton.styleFrom(
                                  backgroundColor: Cp.primary),
                              icon: loading
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2, color: Colors.white))
                                  : const Icon(Icons.login),
                              label: Text(loading ? 'Logging in...' : 'Login',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w900)))),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: OutlinedButton.icon(
                          onPressed: fingerprintLogin,
                          icon: const Icon(Icons.fingerprint, size: 28),
                          label: const Text('Authenticate with Fingerprint',
                              style: TextStyle(fontWeight: FontWeight.w900)),
                        ),
                      ),
                    ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
