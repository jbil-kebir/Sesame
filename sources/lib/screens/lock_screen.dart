import 'dart:async';

import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';

import '../services/pin_service.dart';
import '../services/storage_service.dart';
import 'catalogue_screen.dart';
import 'home_screen.dart';
import 'pin_setup_screen.dart';

class LockScreen extends StatefulWidget {
  const LockScreen({super.key});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  final PinService _pinService = PinService();
  final LocalAuthentication _localAuth = LocalAuthentication();

  String _pin = '';
  String? _erreur;
  int _nbEchecs = 0;
  Duration _cooldown = Duration.zero;
  Timer? _timer;
  bool _biometrieDisponible = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _init() async {
    final echecs = await _pinService.nombreEchecs();
    final cooldown = await _pinService.cooldownRestant();
    final biometrie = await _biometrieActive();
    if (!mounted) return;
    setState(() {
      _nbEchecs = echecs;
      _cooldown = cooldown;
      _biometrieDisponible = biometrie;
    });
    if (cooldown > Duration.zero) _demarrerTimer();
    if (biometrie && echecs < PinService.maxEchecs) _authentifierBiometrie();
  }

  Future<bool> _biometrieActive() async {
    try {
      final supported = await _localAuth.isDeviceSupported();
      if (!supported) return false;
      final enrolled = await _localAuth.getAvailableBiometrics();
      return enrolled.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  void _demarrerTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) async {
      final remaining = await _pinService.cooldownRestant();
      if (!mounted) return;
      setState(() => _cooldown = remaining);
      if (remaining == Duration.zero) _timer?.cancel();
    });
  }

  Future<void> _authentifierBiometrie() async {
    try {
      final ok = await _localAuth.authenticate(
        localizedReason: 'Déverrouillez Sésame',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );
      if (ok && mounted) _acceder();
    } catch (_) {}
  }

  void _ajouterChiffre(String chiffre) {
    if (_cooldown > Duration.zero || _nbEchecs >= PinService.maxEchecs) return;
    if (_pin.length >= 6) return;
    setState(() {
      _pin += chiffre;
      _erreur = null;
    });
    if (_pin.length == 6) _verifier();
  }

  void _effacer() {
    if (_pin.isNotEmpty) {
      setState(() => _pin = _pin.substring(0, _pin.length - 1));
    }
  }

  Future<void> _verifier() async {
    final ok = await _pinService.verifierPin(_pin);
    if (ok) {
      await _pinService.reinitialiserEchecs();
      if (mounted) _acceder();
      return;
    }
    await _pinService.enregistrerEchec();
    final echecs = await _pinService.nombreEchecs();
    final cooldown = await _pinService.cooldownRestant();
    if (!mounted) return;
    setState(() {
      _pin = '';
      _nbEchecs = echecs;
      _cooldown = cooldown;
      if (echecs < PinService.maxEchecs) {
        final restants = PinService.maxEchecs - echecs;
        _erreur = 'Code incorrect — $restants tentative${restants > 1 ? 's' : ''} restante${restants > 1 ? 's' : ''}';
      } else {
        _erreur = null;
      }
    });
    if (cooldown > Duration.zero) _demarrerTimer();
  }

  void _acceder() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const HomeScreen()),
    );
  }

  Future<void> _ouvrirRecuperation() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1565C0),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _RecuperationSheet(
        pinService: _pinService,
        onCodeValide: () {
          Navigator.pop(ctx);
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const PinSetupScreen()),
          );
        },
        onReinitialiser: () {
          Navigator.pop(ctx);
          _confirmerReinitialisation();
        },
      ),
    );
  }

  Future<void> _confirmerReinitialisation() async {
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Réinitialiser l\'application'),
        content: const Text(
          'Toutes vos données seront effacées définitivement : '
          'raccourcis et mots de passe enregistrés.\n\n'
          'Cette action est irréversible.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Effacer tout'),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      await StorageService().reinitialiserApp();
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => const CatalogueScreen(
            premierLancement: true,
            urlsExistantes: {},
          ),
        ),
        (_) => false,
      );
    }
  }

  // ─── UI ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final bloque = _nbEchecs >= PinService.maxEchecs;

    return Scaffold(
      backgroundColor: const Color(0xFF1565C0),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 48),
            const Icon(Icons.lock, color: Colors.white, size: 52),
            const SizedBox(height: 16),
            const Text(
              'Sésame',
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              bloque ? 'Accès bloqué' : 'Entrez votre code d\'accès',
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 40),
            if (!bloque) _buildPoints(),
            const SizedBox(height: 16),
            SizedBox(
              height: 20,
              child: _erreur != null
                  ? Text(
                      _erreur!,
                      style: const TextStyle(
                        color: Colors.redAccent,
                        fontSize: 13,
                      ),
                    )
                  : null,
            ),
            if (_cooldown > Duration.zero)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Réessayez dans ${_formatCooldown(_cooldown)}',
                  style: const TextStyle(
                    color: Colors.orangeAccent,
                    fontSize: 14,
                  ),
                ),
              ),
            if (bloque)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 40, vertical: 24),
                child: Text(
                  'Nombre maximum de tentatives atteint.\nUtilisez un code de secours pour récupérer l\'accès.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70, fontSize: 14, height: 1.5),
                ),
              ),
            const Spacer(),
            if (!bloque) _buildClavier(),
            const SizedBox(height: 16),
            if (_biometrieDisponible && !bloque)
              IconButton(
                onPressed: _authentifierBiometrie,
                icon: const Icon(Icons.fingerprint, color: Colors.white70, size: 44),
                tooltip: 'Déverrouiller avec la biométrie',
              ),
            if (_nbEchecs >= 5 || bloque)
              TextButton(
                onPressed: _ouvrirRecuperation,
                child: const Text(
                  'Code oublié ?',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 15,
                    decoration: TextDecoration.underline,
                    decorationColor: Colors.white70,
                  ),
                ),
              ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildPoints() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(6, (i) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 10),
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: i < _pin.length ? Colors.white : Colors.transparent,
            border: Border.all(color: Colors.white, width: 2),
          ),
        );
      }),
    );
  }

  Widget _buildClavier() {
    final inactif = _cooldown > Duration.zero;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        children: [
          for (final row in [
            ['1', '2', '3'],
            ['4', '5', '6'],
            ['7', '8', '9'],
            ['', '0', '⌫'],
          ])
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: row.map((c) {
                if (c.isEmpty) return const SizedBox(width: 80, height: 72);
                return SizedBox(
                  width: 80,
                  height: 72,
                  child: TextButton(
                    onPressed: inactif
                        ? null
                        : () => c == '⌫' ? _effacer() : _ajouterChiffre(c),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white,
                      disabledForegroundColor: Colors.white38,
                      shape: const CircleBorder(),
                    ),
                    child: Text(
                      c,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w300,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  String _formatCooldown(Duration d) {
    if (d.inSeconds >= 60) {
      final m = d.inMinutes;
      final s = (d.inSeconds % 60).toString().padLeft(2, '0');
      return '${m}m${s}s';
    }
    return '${d.inSeconds}s';
  }
}

// ─── Feuille de récupération ──────────────────────────────────────────────────

class _RecuperationSheet extends StatefulWidget {
  final PinService pinService;
  final VoidCallback onCodeValide;
  final VoidCallback onReinitialiser;

  const _RecuperationSheet({
    required this.pinService,
    required this.onCodeValide,
    required this.onReinitialiser,
  });

  @override
  State<_RecuperationSheet> createState() => _RecuperationSheetState();
}

class _RecuperationSheetState extends State<_RecuperationSheet> {
  final TextEditingController _codeCtrl = TextEditingController();
  String? _erreurCode;
  bool _chargement = false;
  bool _reinitExpanded = false;

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _utiliserCode() async {
    final code = _codeCtrl.text.trim();
    if (code.isEmpty) {
      setState(() => _erreurCode = 'Saisissez un code de secours');
      return;
    }
    setState(() {
      _chargement = true;
      _erreurCode = null;
    });
    final ok = await widget.pinService.utiliserCodeSecours(code);
    if (!mounted) return;
    setState(() => _chargement = false);
    if (ok) {
      widget.onCodeValide();
    } else {
      setState(() => _erreurCode = 'Code invalide ou déjà utilisé');
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white30,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Récupération',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Entrez l\'un de vos codes de secours pour réinitialiser votre code d\'accès.',
            style: TextStyle(color: Colors.white70, fontSize: 14, height: 1.4),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _codeCtrl,
            textCapitalization: TextCapitalization.characters,
            style: const TextStyle(
              color: Colors.white,
              fontFamily: 'monospace',
              fontSize: 18,
              letterSpacing: 2,
            ),
            decoration: InputDecoration(
              hintText: 'XXXX-XXXX',
              hintStyle: const TextStyle(color: Colors.white38, letterSpacing: 2),
              errorText: _erreurCode,
              errorStyle: const TextStyle(color: Colors.redAccent),
              enabledBorder: const OutlineInputBorder(
                borderSide: BorderSide(color: Colors.white38),
                borderRadius: BorderRadius.all(Radius.circular(10)),
              ),
              focusedBorder: const OutlineInputBorder(
                borderSide: BorderSide(color: Colors.white),
                borderRadius: BorderRadius.all(Radius.circular(10)),
              ),
              errorBorder: const OutlineInputBorder(
                borderSide: BorderSide(color: Colors.redAccent),
                borderRadius: BorderRadius.all(Radius.circular(10)),
              ),
              focusedErrorBorder: const OutlineInputBorder(
                borderSide: BorderSide(color: Colors.redAccent),
                borderRadius: BorderRadius.all(Radius.circular(10)),
              ),
            ),
            onSubmitted: (_) => _utiliserCode(),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _chargement ? null : _utiliserCode,
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF1565C0),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: _chargement
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text(
                      'Déverrouiller',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
            ),
          ),
          const SizedBox(height: 24),
          const Divider(color: Colors.white24),
          const SizedBox(height: 12),
          InkWell(
            onTap: () => setState(() => _reinitExpanded = !_reinitExpanded),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded,
                      color: Colors.orangeAccent, size: 20),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Réinitialiser l\'application',
                      style: TextStyle(color: Colors.orangeAccent, fontSize: 14),
                    ),
                  ),
                  Icon(
                    _reinitExpanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: Colors.orangeAccent,
                  ),
                ],
              ),
            ),
          ),
          if (_reinitExpanded) ...[
            const SizedBox(height: 8),
            const Text(
              'Efface définitivement tous les raccourcis et mots de passe. '
              'Aucune récupération possible sans fichier de sauvegarde (.lncr).',
              style: TextStyle(
                color: Colors.white60,
                fontSize: 13,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: widget.onReinitialiser,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.redAccent,
                  side: const BorderSide(color: Colors.redAccent),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text('Effacer toutes les données'),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}
