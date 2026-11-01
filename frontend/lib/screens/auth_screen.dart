import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../auth/auth_api.dart';
import '../auth/auth_user.dart';
import '../theme.dart';

enum _AuthMode { login, register, verify }

class AuthScreen extends StatefulWidget {
  const AuthScreen({
    super.key,
    required this.api,
    required this.onAuthenticated,
    required this.dark,
    required this.toggleTheme,
  });

  final AuthApi api;
  final ValueChanged<AuthUser> onAuthenticated;
  final bool dark;
  final VoidCallback toggleTheme;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _studentCode = TextEditingController();
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _passwordConfirm = TextEditingController();
  final _code = TextEditingController();
  _AuthMode _mode = _AuthMode.login;
  int? _course;
  String? _verificationEmail;
  bool _loading = false;
  bool _remember = false;
  bool _showPassword = false;
  bool _showPasswordConfirm = false;
  bool _isError = false;
  String? _message;
  Map<String, List<String>> _fieldErrors = {};
  DateTime? _resendUntil;
  DateTime? _retryUntil;
  Timer? _cooldownTimer;

  int _secondsUntil(DateTime? until) {
    if (until == null) return 0;
    final milliseconds = until.difference(DateTime.now()).inMilliseconds;
    return milliseconds <= 0 ? 0 : (milliseconds / 1000).ceil();
  }

  int get _resendSeconds => _secondsUntil(_resendUntil);
  int get _retrySeconds => _secondsUntil(_retryUntil);

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    for (final controller in [
      _email,
      _password,
      _studentCode,
      _firstName,
      _lastName,
      _passwordConfirm,
      _code,
    ]) {
      controller.clear();
      controller.dispose();
    }
    super.dispose();
  }

  void _watchCooldowns() {
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {});
      if (_resendSeconds == 0 && _retrySeconds == 0) timer.cancel();
    });
  }

  void _changeMode(
    _AuthMode mode, {
    bool preservePassword = false,
    String? verificationEmail,
    String? message,
    bool error = false,
  }) {
    setState(() {
      _mode = mode;
      _verificationEmail = mode == _AuthMode.verify ? verificationEmail : null;
      _formKey = GlobalKey<FormState>();
      _fieldErrors = {};
      _message = message;
      _isError = error;
      _code.clear();
      _passwordConfirm.clear();
      _studentCode.clear();
      _firstName.clear();
      _lastName.clear();
      _course = null;
      _showPassword = false;
      _showPasswordConfirm = false;
      if (!preservePassword) _password.clear();
    });
  }

  String? _fieldError(String field) {
    final errors = _fieldErrors[field];
    return errors == null || errors.isEmpty ? null : errors.join('\n');
  }

  void _clearFieldError(String field) {
    if (!_fieldErrors.containsKey(field)) return;
    setState(() => _fieldErrors.remove(field));
  }

  String? _validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Мэйл хаягаа оруулна уу.';
    }
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value.trim())) {
      return 'Зөв мэйл хаяг оруулна уу.';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) return 'Нууц үгээ оруулна уу.';
    if (_mode != _AuthMode.login && value.length < 10) {
      return 'Нууц үг 10-аас доошгүй тэмдэгттэй байна.';
    }
    return null;
  }

  String? _validateStudentCode(String? value) {
    final code = value?.trim().toUpperCase() ?? '';
    if (code.isEmpty) return 'Оюутны кодоо оруулна уу.';
    if (code.length > 32 ||
        !RegExp(
          r'^[\p{L}\p{N}][\p{L}\p{N}_-]*$',
          unicode: true,
        ).hasMatch(code)) {
      return 'Код үсэг эсвэл тоогоор эхэлж, 32 хүртэлх үсэг, тоо, _ эсвэл - тэмдэгттэй байна.';
    }
    return null;
  }

  String? _validateName(String? value, String label) {
    final name = value?.trim() ?? '';
    if (name.isEmpty) return '$label оруулна уу.';
    if (name.length > 150) return '150 хүртэлх тэмдэгт оруулна уу.';
    return null;
  }

  void _restartVerification() {
    _email.text = _verificationEmail ?? _email.text;
    _changeMode(
      _AuthMode.login,
      message:
          'Баталгаажуулах хүсэлт дууссан байна. Бүртгүүлсэн мэйл, нууц үгээрээ нэвтрээд баталгаажуулалтаа үргэлжлүүлнэ үү.',
      error: true,
    );
  }

  void _handleError(AuthApiException error) {
    if (error.code == 'verification_required' ||
        error.code == 'verification_email_mismatch') {
      _restartVerification();
      return;
    }
    final message = switch (error.code) {
      'invalid_credentials' => 'Мэйл хаяг эсвэл нууц үг буруу байна.',
      'invalid_code' =>
        'Код буруу, ашиглагдсан эсвэл хугацаа дууссан байна. Кодоо шалгах эсвэл шинээр авна уу.',
      'email_delivery_failed' =>
        'Мэйл илгээж чадсангүй. Түр хүлээгээд дахин оролдоно уу.',
      'throttled' =>
        'Хэт олон хүсэлт илгээсэн байна. Түр хүлээгээд дахин оролдоно уу.',
      _ => error.message,
    };
    setState(() {
      _message = message;
      _isError = true;
      _fieldErrors = Map<String, List<String>>.from(error.fieldErrors);
      if (error.code == 'invalid_code') {
        _fieldErrors['code'] = [
          'Кодоо шалгана уу. Шаардлагатай бол шинэ код авна уу.',
        ];
      }
      if (error.statusCode == 429) {
        final seconds = error.retryAfterSeconds ?? 60;
        _retryUntil = DateTime.now().add(Duration(seconds: seconds));
      }
    });
    if (error.statusCode == 429) _watchCooldowns();
  }

  Future<void> _submit() async {
    if (_loading || _retrySeconds > 0) return;
    if (_mode == _AuthMode.verify && _verificationEmail == null) {
      _restartVerification();
      return;
    }
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final submittedEmail = _email.text.trim().toLowerCase();
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _message = null;
      _fieldErrors = {};
    });
    try {
      switch (_mode) {
        case _AuthMode.login:
          final user = await widget.api.login(
            email: submittedEmail,
            password: _password.text,
            rememberMe: _remember,
          );
          if (!mounted) return;
          _password.clear();
          _passwordConfirm.clear();
          _code.clear();
          _verificationEmail = null;
          TextInput.finishAutofillContext();
          widget.onAuthenticated(user);
        case _AuthMode.register:
          await widget.api.register(
            email: submittedEmail,
            studentCode: _studentCode.text.trim().toUpperCase(),
            firstName: _firstName.text.trim(),
            lastName: _lastName.text.trim(),
            course: _course!,
            password: _password.text,
            passwordConfirm: _passwordConfirm.text,
          );
          if (!mounted) return;
          _changeMode(
            _AuthMode.verify,
            preservePassword: true,
            verificationEmail: submittedEmail,
            message:
                'Баталгаажуулах кодоо мэйлээсээ шалгана уу. Ирсэн мэйл болон спам хавтсаа шалгаарай.',
          );
          _resendUntil = DateTime.now().add(const Duration(seconds: 60));
          _watchCooldowns();
        case _AuthMode.verify:
          await widget.api.verifyEmail(
            email: _verificationEmail!,
            code: _code.text.trim(),
            password: _password.text,
          );
          if (!mounted) return;
          _email.text = _verificationEmail!;
          TextInput.finishAutofillContext(shouldSave: false);
          _changeMode(
            _AuthMode.login,
            message:
                'Мэйл хаяг баталгаажлаа. Одоо мэйл болон нууц үгээрээ нэвтэрнэ үү.',
          );
      }
    } on AuthApiException catch (error) {
      if (!mounted) return;
      if (_mode == _AuthMode.login && error.code == 'email_not_verified') {
        _changeMode(
          _AuthMode.verify,
          preservePassword: true,
          verificationEmail: submittedEmail,
          message:
              'Эхлээд мэйл хаягаа баталгаажуулна уу. Код байхгүй бол «Код дахин авах» товчийг дарна уу.',
        );
      } else {
        _handleError(error);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _message =
            'Хүсэлт амжилтгүй боллоо. Холболтоо шалгаад дахин оролдоно уу.';
        _isError = true;
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resend() async {
    if (_mode != _AuthMode.verify ||
        _loading ||
        _resendSeconds > 0 ||
        _retrySeconds > 0) {
      return;
    }
    final verificationEmail = _verificationEmail;
    if (verificationEmail == null) {
      _restartVerification();
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _message = null;
      _fieldErrors = {};
    });
    try {
      await widget.api.resendVerification(email: verificationEmail);
      if (!mounted) return;
      setState(() {
        _code.clear();
        _message =
            'Шинэ код авах хүсэлт илгээгдлээ. Мэйл болон спам хавтсаа шалгана уу. Хамгийн сүүлд ирсэн кодыг ашиглаарай.';
        _isError = false;
        _resendUntil = DateTime.now().add(const Duration(seconds: 60));
      });
      _watchCooldowns();
    } on AuthApiException catch (error) {
      if (mounted) _handleError(error);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _message = 'Код авах хүсэлт амжилтгүй боллоо. Дахин оролдоно уу.';
        _isError = true;
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String get _title => switch (_mode) {
    _AuthMode.login => 'Тавтай морил',
    _AuthMode.register => 'Бүртгэл үүсгэх',
    _AuthMode.verify => 'Мэйлээ баталгаажуулах',
  };

  String get _description => switch (_mode) {
    _AuthMode.login => 'Оюутны мэдээллийн системдээ нэвтрээрэй.',
    _AuthMode.register =>
      'Мэйл хаягаа баталгаажуулаад хамт олонтойгоо нэгдээрэй.',
    _AuthMode.verify =>
      'Мэйлээр ирсэн 6 оронтой кодыг оруулна уу. Код 10 минутын хугацаанд хүчинтэй.',
  };

  String get _submitLabel => switch (_mode) {
    _AuthMode.login => 'Нэвтрэх',
    _AuthMode.register => 'Бүртгүүлэх',
    _AuthMode.verify => 'Баталгаажуулах',
  };

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 960;
            return Column(
              children: [
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: wide ? 44 : 20,
                    vertical: 18,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: AppColors.blue,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.school_outlined,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'МТС',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              'Оюутны мэдээллийн систем',
                              style: TextStyle(
                                fontSize: 12,
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: _loading ? null : widget.toggleTheme,
                        tooltip: widget.dark
                            ? 'Гэгээтэй горим'
                            : 'Харанхуй горим',
                        icon: Icon(
                          widget.dark
                              ? Icons.light_mode_outlined
                              : Icons.dark_mode_outlined,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: EdgeInsets.fromLTRB(
                      wide ? 44 : 16,
                      18,
                      wide ? 44 : 16,
                      36,
                    ),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: (constraints.maxHeight - 154)
                            .clamp(0, double.infinity)
                            .toDouble(),
                      ),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1040),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              if (wide) ...[
                                const Expanded(child: _WelcomePanel()),
                                const SizedBox(width: 72),
                              ],
                              Expanded(
                                child: Align(
                                  alignment: Alignment.center,
                                  child: ConstrainedBox(
                                    constraints: const BoxConstraints(
                                      maxWidth: 448,
                                    ),
                                    child: _buildForm(context),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildForm(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(MediaQuery.sizeOf(context).width < 400 ? 20 : 32),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(24),
      ),
      child: AutofillGroup(
        child: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: widget.dark
                        ? const Color(0xFF253858)
                        : AppColors.paleBlue,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    switch (_mode) {
                      _AuthMode.login => Icons.login_rounded,
                      _AuthMode.register => Icons.person_add_alt_1_outlined,
                      _AuthMode.verify => Icons.mark_email_read_outlined,
                    },
                    color: AppColors.blue,
                    size: 26,
                  ),
                ),
              ),
              const SizedBox(height: 22),
              Text(
                _title,
                style: const TextStyle(
                  fontSize: 26,
                  height: 1.2,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                _description,
                style: TextStyle(color: colors.onSurfaceVariant, height: 1.5),
              ),
              if (_message != null) ...[
                const SizedBox(height: 20),
                Semantics(
                  liveRegion: true,
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: _isError
                          ? colors.errorContainer
                          : (widget.dark
                                ? const Color(0xFF253858)
                                : AppColors.paleBlue),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _message!,
                      style: TextStyle(
                        color: _isError
                            ? colors.onErrorContainer
                            : colors.onSurface,
                        fontSize: 13,
                        height: 1.5,
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 26),
              if (_mode == _AuthMode.register) ...[
                TextFormField(
                  key: const ValueKey('auth_student_code'),
                  controller: _studentCode,
                  enabled: !_loading,
                  textInputAction: TextInputAction.next,
                  textCapitalization: TextCapitalization.characters,
                  autocorrect: false,
                  maxLength: 32,
                  decoration: InputDecoration(
                    labelText: 'Оюутны код',
                    counterText: '',
                    prefixIcon: const Icon(Icons.badge_outlined),
                    errorText: _fieldError('student_code'),
                    errorMaxLines: 4,
                  ),
                  validator: _validateStudentCode,
                  onChanged: (_) => _clearFieldError('student_code'),
                ),
                const SizedBox(height: 18),
                TextFormField(
                  key: const ValueKey('auth_first_name'),
                  controller: _firstName,
                  enabled: !_loading,
                  textInputAction: TextInputAction.next,
                  textCapitalization: TextCapitalization.words,
                  autofillHints: const [AutofillHints.givenName],
                  maxLength: 150,
                  decoration: InputDecoration(
                    labelText: 'Оюутны нэр',
                    counterText: '',
                    prefixIcon: const Icon(Icons.person_outline),
                    errorText: _fieldError('first_name'),
                    errorMaxLines: 4,
                  ),
                  validator: (value) => _validateName(value, 'Оюутны нэрээ'),
                  onChanged: (_) => _clearFieldError('first_name'),
                ),
                const SizedBox(height: 18),
                TextFormField(
                  key: const ValueKey('auth_last_name'),
                  controller: _lastName,
                  enabled: !_loading,
                  textInputAction: TextInputAction.next,
                  textCapitalization: TextCapitalization.words,
                  autofillHints: const [AutofillHints.familyName],
                  maxLength: 150,
                  decoration: InputDecoration(
                    labelText: 'Оюутны овог',
                    counterText: '',
                    prefixIcon: const Icon(Icons.person_outline),
                    errorText: _fieldError('last_name'),
                    errorMaxLines: 4,
                  ),
                  validator: (value) => _validateName(value, 'Оюутны овгоо'),
                  onChanged: (_) => _clearFieldError('last_name'),
                ),
                const SizedBox(height: 18),
                DropdownButtonFormField<int>(
                  key: const ValueKey('auth_course'),
                  initialValue: _course,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: 'Оюутны курс',
                    prefixIcon: const Icon(Icons.school_outlined),
                    errorText: _fieldError('course'),
                    errorMaxLines: 4,
                  ),
                  hint: const Text('Курсээ сонгоно уу'),
                  items: [
                    for (var course = 1; course <= 6; course++)
                      DropdownMenuItem(
                        value: course,
                        child: Text('$course-р курс'),
                      ),
                  ],
                  validator: (value) =>
                      value == null ? 'Оюутны курсээ сонгоно уу.' : null,
                  onChanged: _loading
                      ? null
                      : (value) {
                          setState(() => _course = value);
                          _clearFieldError('course');
                        },
                ),
                const SizedBox(height: 18),
              ],
              if (_mode == _AuthMode.verify)
                InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'Бүртгүүлсэн мэйл',
                    prefixIcon: const Icon(Icons.mark_email_read_outlined),
                    errorText: _fieldError('email'),
                    errorMaxLines: 4,
                  ),
                  child: Text(
                    _verificationEmail ?? '',
                    key: const ValueKey('auth_verification_email'),
                    style: TextStyle(color: colors.onSurface),
                  ),
                )
              else
                TextFormField(
                  key: const ValueKey('auth_email'),
                  controller: _email,
                  enabled: !_loading,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.email],
                  autocorrect: false,
                  decoration: InputDecoration(
                    labelText: _mode == _AuthMode.register
                        ? 'Оюутны мэйл'
                        : 'Мэйл хаяг',
                    hintText: 'student@example.com',
                    prefixIcon: const Icon(Icons.alternate_email),
                    errorText: _fieldError('email'),
                    errorMaxLines: 4,
                  ),
                  validator: _validateEmail,
                  onChanged: (_) => _clearFieldError('email'),
                ),
              const SizedBox(height: 18),
              TextFormField(
                key: const ValueKey('auth_password'),
                controller: _password,
                enabled: !_loading,
                obscureText: !_showPassword,
                autocorrect: false,
                enableSuggestions: false,
                textInputAction: _mode == _AuthMode.login
                    ? TextInputAction.done
                    : TextInputAction.next,
                autofillHints: [
                  _mode == _AuthMode.login
                      ? AutofillHints.password
                      : AutofillHints.newPassword,
                ],
                decoration: InputDecoration(
                  labelText: _mode == _AuthMode.verify
                      ? 'Бүртгэлийн нууц үг'
                      : 'Нууц үг',
                  helperText: _mode == _AuthMode.login
                      ? null
                      : '10-аас доошгүй тэмдэгт; үсэг, тоо хослуулна уу.',
                  helperMaxLines: 3,
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    onPressed: _loading
                        ? null
                        : () => setState(() => _showPassword = !_showPassword),
                    tooltip: _showPassword ? 'Нууц үг нуух' : 'Нууц үг харах',
                    icon: Icon(
                      _showPassword
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                    ),
                  ),
                  errorText: _fieldError('password'),
                  errorMaxLines: 6,
                ),
                validator: _validatePassword,
                onChanged: (_) => _clearFieldError('password'),
                onFieldSubmitted: (_) {
                  if (_mode == _AuthMode.login) _submit();
                },
              ),
              if (_mode == _AuthMode.register) ...[
                const SizedBox(height: 18),
                TextFormField(
                  key: const ValueKey('auth_password_confirm'),
                  controller: _passwordConfirm,
                  enabled: !_loading,
                  obscureText: !_showPasswordConfirm,
                  autocorrect: false,
                  enableSuggestions: false,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.newPassword],
                  decoration: InputDecoration(
                    labelText: 'Нууц үг давтах',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      onPressed: _loading
                          ? null
                          : () => setState(
                              () =>
                                  _showPasswordConfirm = !_showPasswordConfirm,
                            ),
                      tooltip: _showPasswordConfirm
                          ? 'Давтсан нууц үг нуух'
                          : 'Давтсан нууц үг харах',
                      icon: Icon(
                        _showPasswordConfirm
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                      ),
                    ),
                    errorText: _fieldError('password_confirm'),
                    errorMaxLines: 4,
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Нууц үгээ давтан оруулна уу.';
                    }
                    return value != _password.text
                        ? 'Нууц үг таарахгүй байна.'
                        : null;
                  },
                  onChanged: (_) => _clearFieldError('password_confirm'),
                  onFieldSubmitted: (_) => _submit(),
                ),
              ],
              if (_mode == _AuthMode.verify) ...[
                const SizedBox(height: 18),
                TextFormField(
                  key: const ValueKey('auth_code'),
                  controller: _code,
                  enabled: !_loading,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.oneTimeCode],
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(6),
                  ],
                  decoration: InputDecoration(
                    labelText: '6 оронтой код',
                    hintText: '000000',
                    prefixIcon: const Icon(Icons.pin_outlined),
                    errorText: _fieldError('code'),
                    errorMaxLines: 4,
                  ),
                  validator: (value) =>
                      value == null || !RegExp(r'^[0-9]{6}$').hasMatch(value)
                      ? '6 оронтой кодоо бүрэн оруулна уу.'
                      : null,
                  onChanged: (_) => _clearFieldError('code'),
                  onFieldSubmitted: (_) => _submit(),
                ),
              ],
              if (_mode == _AuthMode.login) ...[
                const SizedBox(height: 12),
                CheckboxListTile(
                  key: const ValueKey('auth_remember'),
                  value: _remember,
                  onChanged: _loading
                      ? null
                      : (value) => setState(() => _remember = value ?? false),
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  visualDensity: VisualDensity.compact,
                  title: const Text(
                    'Төхөөрөмж дээр сануулах',
                    style: TextStyle(fontSize: 13),
                  ),
                  subtitle: Text(
                    '30 хоног нэвтэрсэн хэвээр байна.',
                    style: TextStyle(
                      fontSize: 12,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              FilledButton(
                key: const ValueKey('auth_submit'),
                onPressed: _loading || _retrySeconds > 0 ? null : _submit,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 18,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                child: _loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        _retrySeconds > 0
                            ? '$_retrySeconds секунд хүлээнэ үү'
                            : _submitLabel,
                      ),
              ),
              if (_mode == _AuthMode.verify) ...[
                const SizedBox(height: 12),
                TextButton.icon(
                  key: const ValueKey('auth_resend'),
                  onPressed: _loading || _resendSeconds > 0 || _retrySeconds > 0
                      ? null
                      : _resend,
                  icon: const Icon(Icons.refresh_rounded, size: 19),
                  label: Text(
                    _resendSeconds > 0
                        ? 'Код дахин авах ($_resendSeconds с)'
                        : 'Код дахин авах',
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
              const SizedBox(height: 20),
              Divider(color: Theme.of(context).dividerColor),
              const SizedBox(height: 10),
              if (_mode == _AuthMode.login) ...[
                Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      'Шинэ хэрэглэгч үү?',
                      style: TextStyle(
                        fontSize: 13,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                    TextButton(
                      key: const ValueKey('auth_to_register'),
                      onPressed: _loading
                          ? null
                          : () => _changeMode(_AuthMode.register),
                      child: const Text('Бүртгүүлэх'),
                    ),
                  ],
                ),
              ] else
                TextButton.icon(
                  key: const ValueKey('auth_to_login'),
                  onPressed: _loading
                      ? null
                      : () => _changeMode(_AuthMode.login),
                  icon: const Icon(Icons.arrow_back_rounded, size: 18),
                  label: const Text(
                    'Нэвтрэх хэсэг рүү буцах',
                    textAlign: TextAlign.center,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WelcomePanel extends StatelessWidget {
  const _WelcomePanel();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF253858)
                : AppColors.paleBlue,
            borderRadius: BorderRadius.circular(24),
          ),
          child: const Text(
            'ОЮУТНЫ НЭГДСЭН ОРОН ЗАЙ',
            style: TextStyle(
              color: AppColors.blue,
              fontSize: 11,
              letterSpacing: 1,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'Мэдээллээ хуваалцъя.\nХамтдаа суралцъя.',
          style: TextStyle(
            fontSize: 42,
            fontWeight: FontWeight.w800,
            height: 1.2,
            letterSpacing: -1,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Хичээл, сургуулийн мэдээ болон оюутны хамтын орон зайгаа нэг дороос.',
          style: TextStyle(
            fontSize: 16,
            height: 1.7,
            color: colors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 36),
        const _WelcomeFeature(
          icon: Icons.campaign_outlined,
          title: 'Мэдээ, мэдээлэл',
          description: 'Сургуулийн зар, шинэ мэдээллээ цаг тухайд нь.',
        ),
        const SizedBox(height: 24),
        const _WelcomeFeature(
          icon: Icons.groups_2_outlined,
          title: 'Хамтын орон зай',
          description: 'Багш, оюутнуудтайгаа холбоотой байгаарай.',
        ),
      ],
    );
  }
}

class _WelcomeFeature extends StatelessWidget {
  const _WelcomeFeature({
    required this.icon,
    required this.title,
    required this.description,
  });
  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, color: AppColors.blue),
      const SizedBox(width: 16),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
            ),
            const SizedBox(height: 6),
            Text(
              description,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                height: 1.5,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    ],
  );
}
