part of '../main.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final formKey = GlobalKey<FormState>();
  final authService = AuthService();
  final biometricService = BiometricAuthService();
  final email = TextEditingController(text: 'admin@caterpro.in');
  final password = TextEditingController(text: 'password');
  bool obscurePassword = true;
  bool rememberMe = true;
  bool loading = false;
  bool checkingBiometric = true;
  bool biometricSupported = false;
  bool biometricEnabled = false;
  bool hasSavedSession = false;
  String? error;

  @override
  void initState() {
    super.initState();
    loadBiometricState();
  }

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
      await setupFingerprintAfterFirstLogin();
      if (!mounted) return;
      Navigator.of(context)
          .pushReplacement(MaterialPageRoute(builder: (_) => const AppShell()));
    } catch (e) {
      if (!mounted) return;
      setState(() => error = friendlyNetworkMessage(e));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> loadBiometricState() async {
    final supported = await biometricService.isSupported();
    final enabled = await biometricService.isEnabled();
    final session = await authService.savedSession();
    if (!mounted) return;
    setState(() {
      biometricSupported = supported;
      biometricEnabled = enabled;
      hasSavedSession = session != null;
      checkingBiometric = false;
    });
  }

  Future<void> setupFingerprintAfterFirstLogin() async {
    if (!rememberMe) return;
    final supported = await biometricService.isSupported();
    final enabled = await biometricService.isEnabled();
    if (!supported || enabled) return;
    final confirmed = await biometricService.authenticate(
        'Confirm fingerprint to enable CaterPro fingerprint login');
    if (confirmed) {
      await biometricService.setEnabled(true);
      if (mounted) {
        setState(() {
          biometricSupported = true;
          biometricEnabled = true;
          hasSavedSession = true;
        });
        showCpSnack(context, 'Fingerprint login enabled');
      }
    }
  }

  Future<void> fingerprintLogin() async {
    setState(() {
      loading = true;
      error = null;
    });
    final session = await authService.savedSession();
    if (session == null) {
      await biometricService.setEnabled(false);
      if (!mounted) return;
      setState(() {
        biometricEnabled = false;
        hasSavedSession = false;
        loading = false;
        error = 'Login with password once to set up fingerprint login.';
      });
      return;
    }
    final ok = await biometricService
        .authenticate('Use fingerprint to unlock CaterPro');
    if (!mounted) return;
    if (!ok) {
      setState(() {
        loading = false;
        error = 'Fingerprint authentication failed. Try again or use password.';
      });
      return;
    }
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
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: scheme.surface,
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
            Text('CaterPro',
                style: TextStyle(
                    color: scheme.primary,
                    fontSize: 38,
                    fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            Text('Sign in to manage events, menus, billing, and teams.',
                style: TextStyle(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 28),
            Form(
              key: formKey,
              child: CpCard(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Login',
                          style: TextStyle(
                              color: scheme.primary,
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
                            child: Text('Forgot Password?',
                                style: TextStyle(
                                    color: scheme.primary,
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
                                  backgroundColor: scheme.primary,
                                  foregroundColor: scheme.onPrimary),
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
                      if (!checkingBiometric &&
                          biometricSupported &&
                          biometricEnabled &&
                          hasSavedSession) ...[
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          height: 54,
                          child: OutlinedButton.icon(
                            onPressed: loading ? null : fingerprintLogin,
                            icon: const Icon(Icons.fingerprint, size: 28),
                            label: const Text('Login with Fingerprint',
                                style: TextStyle(fontWeight: FontWeight.w900)),
                          ),
                        ),
                      ],
                    ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String friendlyNetworkMessage(Object error) {
  final message = error.toString().replaceFirst('Exception: ', '');
  if (message.contains('SocketException') ||
      message.contains('Failed host lookup') ||
      message.contains('No address associated with hostname') ||
      message.contains('ClientException')) {
    return 'Unable to reach CaterPro live backend. Check internet connection and try again.';
  }
  return message;
}
