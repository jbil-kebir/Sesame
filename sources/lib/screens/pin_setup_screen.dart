import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/pin_service.dart';
import 'home_screen.dart';

class PinSetupScreen extends StatefulWidget {
  const PinSetupScreen({super.key});

  @override
  State<PinSetupScreen> createState() => _PinSetupScreenState();
}

enum _Etape { saisie, confirmation, codesSecours }

class _PinSetupScreenState extends State<PinSetupScreen> {
  final PinService _pinService = PinService();

  _Etape _etape = _Etape.saisie;
  String _pinSaisi = '';
  String _pinConfirmation = '';
  String _pinActuel = '';
  List<String> _codesSecours = [];
  bool _codesConfirmes = false;
  String? _erreur;

  // ─── Saisie PIN ───────────────────────────────────────────────────────────

  void _ajouterChiffre(String chiffre) {
    final estConfirmation = _etape == _Etape.confirmation;
    final current = estConfirmation ? _pinConfirmation : _pinSaisi;
    if (current.length >= 6) return;
    setState(() {
      _erreur = null;
      if (estConfirmation) {
        _pinConfirmation += chiffre;
      } else {
        _pinSaisi += chiffre;
      }
    });
    if (estConfirmation && _pinConfirmation.length == 6) _validerConfirmation();
    if (!estConfirmation && _pinSaisi.length == 6) _passerAConfirmation();
  }

  void _effacer() {
    setState(() {
      _erreur = null;
      if (_etape == _Etape.confirmation && _pinConfirmation.isNotEmpty) {
        _pinConfirmation = _pinConfirmation.substring(0, _pinConfirmation.length - 1);
      } else if (_etape == _Etape.saisie && _pinSaisi.isNotEmpty) {
        _pinSaisi = _pinSaisi.substring(0, _pinSaisi.length - 1);
      }
    });
  }

  void _passerAConfirmation() {
    setState(() {
      _pinActuel = _pinSaisi;
      _etape = _Etape.confirmation;
    });
  }

  Future<void> _validerConfirmation() async {
    if (_pinConfirmation != _pinActuel) {
      setState(() {
        _erreur = 'Les codes ne correspondent pas';
        _pinConfirmation = '';
      });
      return;
    }
    await _pinService.configurerPin(_pinActuel);
    final codes = await _pinService.genererCodesSecours();
    setState(() {
      _codesSecours = codes;
      _etape = _Etape.codesSecours;
    });
  }

  void _terminer() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const HomeScreen()),
      (_) => false,
    );
  }

  // ─── UI ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: const Color(0xFF1565C0),
        body: SafeArea(
          child: _etape == _Etape.codesSecours
              ? _buildCodesSecours()
              : _buildSaisiePin(),
        ),
      ),
    );
  }

  Widget _buildSaisiePin() {
    final pin = _etape == _Etape.saisie ? _pinSaisi : _pinConfirmation;
    final titre = _etape == _Etape.saisie
        ? 'Créer votre code d\'accès'
        : 'Confirmer le code';
    final sous = _etape == _Etape.saisie
        ? 'Ce code protège l\'accès à vos identifiants'
        : 'Saisissez à nouveau le même code';

    return Column(
      children: [
        const SizedBox(height: 48),
        const Icon(Icons.lock_outline, color: Colors.white, size: 48),
        const SizedBox(height: 24),
        Text(
          titre,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          sous,
          style: const TextStyle(color: Colors.white70, fontSize: 14),
        ),
        const SizedBox(height: 48),
        _buildPoints(pin),
        const SizedBox(height: 16),
        SizedBox(
          height: 24,
          child: _erreur != null
              ? Text(
                  _erreur!,
                  style: const TextStyle(color: Colors.redAccent, fontSize: 14),
                )
              : null,
        ),
        const Spacer(),
        _buildClavier(),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildPoints(String pin) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(6, (i) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 10),
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: i < pin.length ? Colors.white : Colors.transparent,
            border: Border.all(color: Colors.white, width: 2),
          ),
        );
      }),
    );
  }

  Widget _buildClavier() {
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
                return _toucheClavier(c);
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _toucheClavier(String label) {
    return SizedBox(
      width: 80,
      height: 72,
      child: TextButton(
        onPressed: () => label == '⌫' ? _effacer() : _ajouterChiffre(label),
        style: TextButton.styleFrom(
          foregroundColor: Colors.white,
          shape: const CircleBorder(),
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w300),
        ),
      ),
    );
  }

  // ─── Écran codes de secours ───────────────────────────────────────────────

  Widget _buildCodesSecours() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 32),
          Row(
            children: [
              const Icon(Icons.shield_outlined, color: Colors.white, size: 32),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Codes de secours',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'Si vous oubliez votre code, chacun de ces 8 codes permet de '
            'déverrouiller l\'application une seule fois.\n\n'
            'Notez-les sur papier ou enregistrez-les dans un gestionnaire '
            'de mots de passe.',
            style: TextStyle(color: Colors.white70, fontSize: 14, height: 1.5),
          ),
          const SizedBox(height: 24),
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                for (var i = 0; i < _codesSecours.length; i += 2)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Expanded(child: _codeChip(_codesSecours[i])),
                        const SizedBox(width: 12),
                        Expanded(
                          child: i + 1 < _codesSecours.length
                              ? _codeChip(_codesSecours[i + 1])
                              : const SizedBox(),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          TextButton.icon(
            onPressed: () {
              Clipboard.setData(
                ClipboardData(text: _codesSecours.join('\n')),
              );
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Codes copiés dans le presse-papier'),
                ),
              );
            },
            icon: const Icon(Icons.copy, color: Colors.white60, size: 16),
            label: const Text(
              'Copier tous les codes',
              style: TextStyle(color: Colors.white60, fontSize: 13),
            ),
          ),
          const SizedBox(height: 20),
          CheckboxListTile(
            value: _codesConfirmes,
            onChanged: (v) => setState(() => _codesConfirmes = v ?? false),
            title: const Text(
              'J\'ai sauvegardé mes codes de secours',
              style: TextStyle(color: Colors.white, fontSize: 14),
            ),
            checkColor: const Color(0xFF1565C0),
            activeColor: Colors.white,
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _codesConfirmes ? _terminer : null,
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF1565C0),
                disabledBackgroundColor: Colors.white24,
                disabledForegroundColor: Colors.white38,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Accéder à Sésame',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _codeChip(String code) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        code,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.white,
          fontFamily: 'monospace',
          fontSize: 15,
          fontWeight: FontWeight.w600,
          letterSpacing: 2,
        ),
      ),
    );
  }
}
