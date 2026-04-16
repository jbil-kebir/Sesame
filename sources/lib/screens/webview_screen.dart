import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../services/storage_service.dart';

class WebViewScreen extends StatefulWidget {
  final String raccourciId;
  final String nom;
  final String url;
  final String? login;
  final String? motDePasse;
  final void Function(String login, String password)? onCredentialsSaved;

  const WebViewScreen({
    super.key,
    required this.raccourciId,
    required this.nom,
    required this.url,
    this.login,
    this.motDePasse,
    this.onCredentialsSaved,
  });

  @override
  State<WebViewScreen> createState() => _WebViewScreenState();
}

class _WebViewScreenState extends State<WebViewScreen> {
  late final WebViewController _controller;
  final StorageService _storage = StorageService();
  bool _chargement = true;
  bool _peutReculer = false;
  String? _erreur;
  bool _injectionEffectuee = false;
  bool _dialogueEnCours = false;

  // Identifiants capturés sur une page, proposés à la sauvegarde à la page suivante
  Map<String, String>? _identifiantsEnAttente;

  // Vrai quand la page courante contient un champ password rempli
  bool _formulaireConnexionDetecte = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent(
        'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 '
        '(KHTML, like Gecko) Chrome/124.0.0.0 Mobile Safari/537.36',
      )
      ..addJavaScriptChannel(
        'CredentialCapture',
        onMessageReceived: (msg) => _stockerIdentifiantsEnAttente(msg.message),
      )
      ..addJavaScriptChannel(
        'CredentialSaveNow',
        onMessageReceived: (msg) => _proposerSauvegardeDepuisMessage(msg.message),
      )
      ..addJavaScriptChannel(
        'FormDetected',
        onMessageReceived: (_) => setState(() => _formulaireConnexionDetecte = true),
      )
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (_) => setState(() {
          _chargement = true;
          _erreur = null;
        }),
        onPageFinished: (_) async {
          final peutReculer = await _controller.canGoBack();
          setState(() {
            _chargement = false;
            _peutReculer = peutReculer;
            _formulaireConnexionDetecte = false;
          });
          _injecterWindowOpen();
          // Tenter l'injection sur chaque page jusqu'au premier succès.
          // Le JS n'agit que sur les champs visibles ; dès qu'il remplit un
          // formulaire, _injectionEffectuee passe à true et on s'arrête.
          await _injecterIdentifiants();
          // Si des identifiants ont été capturés sur la page précédente,
          // proposer la sauvegarde maintenant que la navigation a réussi.
          final enAttente = _identifiantsEnAttente;
          if (enAttente != null) {
            _identifiantsEnAttente = null;
            await _proposerSauvegarde(enAttente['login']!, enAttente['password']!);
          }
          _injecterCapture();
        },
        onNavigationRequest: (request) {
          final url = request.url;
          if (url.startsWith('intent://') ||
              url.startsWith('market://') ||
              url.startsWith('android-app://')) {
            launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication)
                .catchError((_) {});
            return NavigationDecision.prevent;
          }
          return NavigationDecision.navigate;
        },
        onWebResourceError: (error) {
          if (error.isForMainFrame ?? true) {
            setState(() {
              _chargement = false;
              _erreur = error.description;
            });
          }
        },
      ))
      ..loadRequest(Uri.parse(widget.url));
  }

  // Injecte les identifiants enregistrés (si présents) et soumet le formulaire.
  // N'agit que sur les champs visibles (offsetParent != null) pour éviter de
  // remplir des champs cachés (token CSRF…) sur les pages post-connexion.
  // Dès qu'une injection réussit, _injectionEffectuee passe à true et les
  // appels suivants (pages suivantes) deviennent des no-ops.
  Future<void> _injecterIdentifiants() async {
    if (_injectionEffectuee || widget.login == null || widget.motDePasse == null) return;

    final loginJs = jsonEncode(widget.login);
    final mdpJs = jsonEncode(widget.motDePasse);

    final result = await _controller.runJavaScriptReturningResult('''
      (function() {
        var inputs = document.querySelectorAll('input');
        var passwordField = null;
        var loginField = null;

        for (var i = 0; i < inputs.length; i++) {
          var inp = inputs[i];
          // Ignorer les champs masqués (hidden, display:none, visibility:hidden…)
          if (inp.type === 'password' && inp.offsetParent !== null) {
            passwordField = inp;
            for (var j = i - 1; j >= 0; j--) {
              var t = inputs[j].type;
              if ((t === 'text' || t === 'email' || t === '') && inputs[j].offsetParent !== null) {
                loginField = inputs[j];
                break;
              }
            }
            break;
          }
        }

        function setVal(el, val) {
          var setter = Object.getOwnPropertyDescriptor(
              window.HTMLInputElement.prototype, 'value').set;
          setter.call(el, val);
          el.dispatchEvent(new Event('input', {bubbles: true}));
          el.dispatchEvent(new Event('change', {bubbles: true}));
        }

        if (loginField) setVal(loginField, $loginJs);
        if (passwordField) {
          setVal(passwordField, $mdpJs);

          setTimeout(function() {
            var form = passwordField.closest('form');
            var submitBtn = null;
            if (form) {
              submitBtn = form.querySelector(
                'button[type="submit"], input[type="submit"], button:not([type="button"])'
              );
            }
            if (!submitBtn) {
              submitBtn = document.querySelector(
                'button[type="submit"], input[type="submit"]'
              );
            }
            if (submitBtn) {
              submitBtn.click();
            } else if (form) {
              form.dispatchEvent(new Event('submit', {bubbles: true, cancelable: true}));
            }
          }, 600);
          return true;
        }
        return false;
      })();
    ''');

    if (result.toString() == 'true') {
      setState(() => _injectionEffectuee = true);
    }
  }

  // Redirige window.open() dans la même WebView (évite les pages blanches)
  void _injecterWindowOpen() {
    _controller.runJavaScript('''
      window.open = function(url) {
        if (url && url !== 'about:blank') window.location.href = url;
      };
    ''');
  }

  // Injecte le script de capture des identifiants.
  // - Blur sur le champ password → stocké côté Flutter, dialog à la page suivante
  // - CredentialSaveNow → canal utilisé par le bouton manuel pour dialog immédiate
  // - FormDetected → signale à Flutter qu'un formulaire de connexion est présent
  void _injecterCapture() {
    _controller.runJavaScript(r'''
      (function() {
        function trouverLogin(passwordField) {
          var inputs = document.querySelectorAll('input');
          for (var i = 0; i < inputs.length; i++) {
            if (inputs[i] === passwordField) {
              for (var j = i - 1; j >= 0; j--) {
                var t = inputs[j].type;
                if (t === 'text' || t === 'email' || t === '') return inputs[j];
              }
              break;
            }
          }
          return null;
        }

        function envoyerCapture(loginField, passwordField) {
          if (!loginField || !passwordField) return;
          var l = loginField.value;
          var p = passwordField.value;
          if (!l || !p) return;
          try {
            CredentialCapture.postMessage(JSON.stringify({ login: l, password: p }));
          } catch(e) {}
        }

        // Expose une fonction globale pour la capture manuelle (bouton AppBar)
        window.__captureManuelle = function() {
          var pwds = document.querySelectorAll('input[type="password"]');
          for (var i = 0; i < pwds.length; i++) {
            var pwd = pwds[i];
            if (!pwd.value) continue;
            var login = trouverLogin(pwd);
            if (login && login.value) {
              try {
                CredentialSaveNow.postMessage(JSON.stringify({
                  login: login.value,
                  password: pwd.value
                }));
              } catch(e) {}
              return true;
            }
          }
          return false;
        };

        function attacherBlur(pwd) {
          if (pwd._blurAttachee) return;
          pwd._blurAttachee = true;
          pwd.addEventListener('blur', function() {
            var loginField = trouverLogin(pwd);
            envoyerCapture(loginField, pwd);
          });
        }

        function attacherSubmit(form) {
          if (form._submitAttachee) return;
          form._submitAttachee = true;
          form.addEventListener('submit', function() {
            var inputs = form.querySelectorAll('input');
            var pwd = null, login = null;
            for (var i = 0; i < inputs.length; i++) {
              if (inputs[i].type === 'password') {
                pwd = inputs[i];
                for (var j = i - 1; j >= 0; j--) {
                  var t = inputs[j].type;
                  if (t === 'text' || t === 'email' || t === '') {
                    login = inputs[j];
                    break;
                  }
                }
                break;
              }
            }
            envoyerCapture(login, pwd);
          }, true);
        }

        function scanner() {
          var pwds = document.querySelectorAll('input[type="password"]');
          if (pwds.length > 0) {
            try { FormDetected.postMessage('1'); } catch(e) {}
            pwds.forEach(attacherBlur);
          }
          document.querySelectorAll('form').forEach(attacherSubmit);
        }

        scanner();

        var observer = new MutationObserver(function() { scanner(); });
        if (document.body) {
          observer.observe(document.body, { childList: true, subtree: true });
        }
      })();
    ''');
  }

  // Bouton manuel : lit le formulaire visible et propose la sauvegarde immédiatement.
  // Si les champs sont déjà soumis (vides), utilise les identifiants en attente.
  Future<void> _captureManuelle() async {
    // Cas 1 : formulaire encore visible (utilisateur clique avant de soumettre)
    await _controller.runJavaScript(
      'if(window.__captureManuelle) window.__captureManuelle();',
    );
    // Cas 2 : formulaire déjà soumis → utiliser les identifiants capturés en attente
    final enAttente = _identifiantsEnAttente;
    if (enAttente != null) {
      _identifiantsEnAttente = null;
      await _proposerSauvegarde(enAttente['login']!, enAttente['password']!);
    }
  }

  void _proposerSauvegardeDepuisMessage(String message) {
    if (!mounted) return;
    try {
      final data = jsonDecode(message) as Map<String, dynamic>;
      final login = data['login'] as String;
      final password = data['password'] as String;
      if (login.isNotEmpty && password.isNotEmpty) {
        _proposerSauvegarde(login, password);
      }
    } catch (_) {}
  }

  // Stocke les identifiants sans afficher la dialog : elle sera montrée
  // à la prochaine page chargée (connexion réussie confirmée).
  void _stockerIdentifiantsEnAttente(String message) {
    if (!mounted) return;
    try {
      final data = jsonDecode(message) as Map<String, dynamic>;
      final login = data['login'] as String;
      final password = data['password'] as String;
      if (login.isNotEmpty && password.isNotEmpty) {
        _identifiantsEnAttente = {'login': login, 'password': password};
      }
    } catch (_) {}
  }

  // Affiche la dialog de sauvegarde après navigation réussie
  Future<void> _proposerSauvegarde(String login, String password) async {
    if (_dialogueEnCours || !mounted) return;

    // Ne pas proposer si ce sont déjà les identifiants enregistrés
    if (login == widget.login) {
      final mdpExistant = await _storage.chargerMotDePasse(widget.raccourciId);
      if (mdpExistant == password) return;
    }

    if (!mounted) return;
    _dialogueEnCours = true;

    final sauvegarder = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sauvegarder les identifiants ?'),
        content: Text(
          'Identifiant : $login\n\nVoulez-vous enregistrer ces identifiants pour "${widget.nom}" ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Non'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sauvegarder'),
          ),
        ],
      ),
    );

    _dialogueEnCours = false;

    if (sauvegarder == true) {
      await _storage.sauvegarderMotDePasse(widget.raccourciId, password);
      widget.onCredentialsSaved?.call(login, password);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.nom),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (_peutReculer)
            IconButton(
              icon: const Icon(Icons.arrow_back_ios),
              onPressed: () => _controller.goBack(),
            ),
          if (_formulaireConnexionDetecte || _identifiantsEnAttente != null)
            IconButton(
              icon: const Icon(Icons.key),
              tooltip: 'Enregistrer les identifiants',
              onPressed: _captureManuelle,
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _controller.reload(),
          ),
          IconButton(
            icon: const Icon(Icons.open_in_browser),
            tooltip: 'Ouvrir dans le navigateur',
            onPressed: () async {
              final url = await _controller.currentUrl() ?? widget.url;
              await launchUrl(Uri.parse(url),
                  mode: LaunchMode.externalApplication);
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_chargement)
            const Center(child: CircularProgressIndicator()),
          if (_erreur != null)
            Container(
              color: Theme.of(context).colorScheme.surface,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.wifi_off, size: 48, color: Colors.grey),
                      const SizedBox(height: 16),
                      const Text(
                        'La page n\'a pas pu être chargée.',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _erreur!,
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: () => _controller.reload(),
                        icon: const Icon(Icons.refresh),
                        label: const Text('Réessayer'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
