// lib/screens/auth/login_screen.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:telecom_analyzer/core/constants.dart';
import 'package:telecom_analyzer/core/theme.dart';
import 'package:telecom_analyzer/data/repositories/auth_repository.dart';

// ── Login State ────────────────────────────────────────────────────────────────
enum _LoginStatus { idle, loading, error }

class _LoginState {
  final _LoginStatus status;
  final String? errorMessage;
  const _LoginState({this.status = _LoginStatus.idle, this.errorMessage});
  _LoginState copyWith({_LoginStatus? status, String? errorMessage}) => _LoginState(
    status: status ?? this.status,
    errorMessage: errorMessage ?? this.errorMessage,
  );
}

class _LoginNotifier extends StateNotifier<_LoginState> {
  _LoginNotifier() : super(const _LoginState());
  final _repo = AuthRepository();

  Future<void> login(String identifier, String password) async {
    state = state.copyWith(status: _LoginStatus.loading, errorMessage: null);
    try {
      await _repo.login(identifier, password);
      state = state.copyWith(status: _LoginStatus.idle);
    } catch (e) {
      state = state.copyWith(
        status: _LoginStatus.error,
        errorMessage: e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }
}

final _loginProvider = StateNotifierProvider.autoDispose<_LoginNotifier, _LoginState>(
  (_) => _LoginNotifier(),
);

// ── Screen ─────────────────────────────────────────────────────────────────────
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});
  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _identifierCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscurePassword = true;

  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _fadeAnim  = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.12), end: Offset.zero)
        .animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic));
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _identifierCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    await ref.read(_loginProvider.notifier).login(
      _identifierCtrl.text.trim(),
      _passwordCtrl.text,
    );
    if (mounted && ref.read(_loginProvider).status == _LoginStatus.idle) {
      context.go(AppRoutes.ingest);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state  = ref.watch(_loginProvider);
    final size   = MediaQuery.sizeOf(context);
    final isWide = size.width >= 600;

    return Scaffold(
      backgroundColor: AppColors.bgBase,
      body: Stack(
        children: [
          Positioned(
            top: -100, left: -80,
            child: _GlowCircle(color: AppColors.accent, size: 350),
          ),
          Positioned(
            bottom: -120, right: -60,
            child: _GlowCircle(color: AppColors.secondary, size: 300),
          ),
          if (isWide)
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
                child: const ColoredBox(color: Colors.transparent),
              ),
            ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: isWide ? 0 : 24,
                  vertical: 32,
                ),
                child: FadeTransition(
                  opacity: _fadeAnim,
                  child: SlideTransition(
                    position: _slideAnim,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 440),
                      child: isWide
                          ? _GlassCard(child: _LoginForm(
                              formKey: _formKey,
                              identifierCtrl: _identifierCtrl,
                              passwordCtrl: _passwordCtrl,
                              obscurePassword: _obscurePassword,
                              onToggleObscure: () => setState(() => _obscurePassword = !_obscurePassword),
                              onSubmit: _submit,
                              state: state,
                            ))
                          : _LoginForm(
                              formKey: _formKey,
                              identifierCtrl: _identifierCtrl,
                              passwordCtrl: _passwordCtrl,
                              obscurePassword: _obscurePassword,
                              onToggleObscure: () => setState(() => _obscurePassword = !_obscurePassword),
                              onSubmit: _submit,
                              state: state,
                            ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Login Form ─────────────────────────────────────────────────────────────────
class _LoginForm extends StatelessWidget {
  const _LoginForm({
    required this.formKey,
    required this.identifierCtrl,
    required this.passwordCtrl,
    required this.obscurePassword,
    required this.onToggleObscure,
    required this.onSubmit,
    required this.state,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController identifierCtrl;
  final TextEditingController passwordCtrl;
  final bool obscurePassword;
  final VoidCallback onToggleObscure;
  final VoidCallback onSubmit;
  final _LoginState state;

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Column(
              children: [
                Container(
                  width: 72, height: 72,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.accent, AppColors.secondary],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.accent.withValues(alpha: 0.35),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.cell_tower, color: Colors.white, size: 36),
                ),
                const SizedBox(height: 20),
                Text('Telecom Analyzer',
                    style: AppTextStyles.displayLarge.copyWith(fontSize: 26)),
                const SizedBox(height: 6),
                Text('Sign in to your account', style: AppTextStyles.bodyMedium),
              ],
            ),
          ),
          const SizedBox(height: 36),

          if (state.status == _LoginStatus.error && state.errorMessage != null) ...[
            _ErrorBanner(message: state.errorMessage!),
            const SizedBox(height: 16),
          ],

          Text('Username or Email', style: AppTextStyles.labelLarge),
          const SizedBox(height: 8),
          TextFormField(
            controller: identifierCtrl,
            autofillHints: const [AutofillHints.username, AutofillHints.email],
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              hintText: 'admin or admin@telecom.local',
              prefixIcon: Icon(Icons.person_outline, color: AppColors.textMuted, size: 20),
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Username or email is required';
              return null;
            },
          ),
          const SizedBox(height: 20),

          Text('Password', style: AppTextStyles.labelLarge),
          const SizedBox(height: 8),
          TextFormField(
            controller: passwordCtrl,
            obscureText: obscurePassword,
            autofillHints: const [AutofillHints.password],
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => onSubmit(),
            decoration: InputDecoration(
              hintText: '••••••••',
              prefixIcon: const Icon(Icons.lock_outline, color: AppColors.textMuted, size: 20),
              suffixIcon: IconButton(
                icon: Icon(
                  obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  color: AppColors.textMuted, size: 20,
                ),
                onPressed: onToggleObscure,
                splashRadius: 18,
              ),
            ),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Password is required';
              return null;
            },
          ),
          const SizedBox(height: 28),

          SizedBox(
            width: double.infinity,
            height: 52,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: state.status == _LoginStatus.loading
                  ? Container(
                      key: const ValueKey('loading'),
                      decoration: BoxDecoration(
                        color: AppColors.accent.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Center(
                        child: SizedBox(
                          width: 22, height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor: AlwaysStoppedAnimation(AppColors.accent),
                          ),
                        ),
                      ),
                    )
                  : ElevatedButton(
                      key: const ValueKey('login'),
                      onPressed: onSubmit,
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Ink(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [AppColors.accent, Color(0xFF0099EE)],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: Text('Sign In',
                              style: AppTextStyles.labelLarge.copyWith(
                                color: AppColors.bgBase,
                                fontSize: 15,
                                letterSpacing: 0.6,
                              )),
                        ),
                      ),
                    ),
            ),
          ),

          const SizedBox(height: 24),
          Center(
            child: Text(
              'Default credentials: admin / Admin@1234!',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textMuted, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Sub-widgets ────────────────────────────────────────────────────────────────
class _GlowCircle extends StatelessWidget {
  const _GlowCircle({required this.color, required this.size});
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size, height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: RadialGradient(
        colors: [color.withValues(alpha: 0.18), Colors.transparent],
        stops: const [0.0, 1.0],
      ),
    ),
  );
}

class _GlassCard extends StatelessWidget {
  const _GlassCard({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(24),
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
      child: Container(
        padding: const EdgeInsets.all(36),
        decoration: BoxDecoration(
          color: AppColors.bgSurface.withValues(alpha: 0.75),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.bgBorder.withValues(alpha: 0.6)),
        ),
        child: child,
      ),
    ),
  );
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    decoration: BoxDecoration(
      color: AppColors.error.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppColors.error.withValues(alpha: 0.4)),
    ),
    child: Row(
      children: [
        const Icon(Icons.error_outline, color: AppColors.error, size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Text(message,
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.error)),
        ),
      ],
    ),
  );
}
