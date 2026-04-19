import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

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
  InAppWebViewController? _controller;
  final StorageService _storage = StorageService();
  bool _chargement = true;
  bool _peutReculer = false;
  String? _erreur;
  bool _injectionEffectuee = false;
  bool _dialogueEnCours = false;
  bool _telechargementEnCours = false;

  Map<String, String>? _identifiantsEnAttente;
  bool _formulaireConnexionDetecte = false;

  // ─── JS handlers ──────────────────────────────────────────────────────────

  void _setupJsHandlers(InAppWebViewController controller) {
    controller.addJavaScriptHandler(
      handlerName: 'CredentialCapture',
      callback: (args) {
        if (args.isNotEmpty) _stockerIdentifiantsEnAttente(args[0].toString());
      },
    );
    controller.addJavaScriptHandler(
      handlerName: 'CredentialSaveNow',
      callback: (args) {
        if (args.isNotEmpty) _proposerSauvegardeDepuisMessage(args[0].toString());
      },
    );
    controller.addJavaScriptHandler(
      handlerName: 'FormDetected',
      callback: (_) => setState(() => _formulaireConnexionDetecte = true),
    );
  }

  // ─── Injection des identifiants ───────────────────────────────────────────

  Future<void> _injecterIdentifiants() async {
    if (_injectionEffectuee || widget.login == null || widget.motDePasse == null) return;

    final loginJs = jsonEncode(widget.login);
    final mdpJs = jsonEncode(widget.motDePasse);

    final result = await _controller?.evaluateJavascript(source: '''
      (function() {
        var inputs = document.querySelectorAll('input');
        var passwordField = null;
        var loginField = null;

        for (var i = 0; i < inputs.length; i++) {
          var inp = inputs[i];
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

    if (result == true) {
      setState(() => _injectionEffectuee = true);
    }
  }

  void _injecterWindowOpen() {
    _controller?.evaluateJavascript(source: '''
      window.open = function(url) {
        if (url && url !== 'about:blank') window.location.href = url;
      };
    ''');
  }

  void _injecterCapture() {
    _controller?.evaluateJavascript(source: r'''
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
            window.flutter_inappwebview.callHandler('CredentialCapture', JSON.stringify({ login: l, password: p }));
          } catch(e) {}
        }

        function getAllInputsDeep(root) {
          var results = [];
          var inputs = root.querySelectorAll('input');
          for (var i = 0; i < inputs.length; i++) results.push(inputs[i]);
          var all = root.querySelectorAll('*');
          for (var i = 0; i < all.length; i++) {
            if (all[i].shadowRoot) {
              var nested = getAllInputsDeep(all[i].shadowRoot);
              for (var j = 0; j < nested.length; j++) results.push(nested[j]);
            }
          }
          return results;
        }

        window.__captureManuelle = function() {
          var inputs = getAllInputsDeep(document);
          for (var i = 0; i < inputs.length; i++) {
            var pwd = inputs[i];
            if (pwd.type !== 'password' || !pwd.value) continue;
            // Chercher le champ login parmi tous les inputs
            var login = null;
            for (var j = i - 1; j >= 0; j--) {
              var t = inputs[j].type;
              if ((t === 'text' || t === 'email' || t === '') && inputs[j].value) {
                login = inputs[j];
                break;
              }
            }
            if (login) {
              try {
                window.flutter_inappwebview.callHandler('CredentialSaveNow', JSON.stringify({
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
            try { window.flutter_inappwebview.callHandler('FormDetected', '1'); } catch(e) {}
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

  // ─── Capture manuelle ─────────────────────────────────────────────────────

  Future<void> _captureManuelle() async {
    await _controller?.evaluateJavascript(
      source: 'if(window.__captureManuelle) window.__captureManuelle();',
    );
    final enAttente = _identifiantsEnAttente;
    if (enAttente != null) {
      _identifiantsEnAttente = null;
      await _proposerSauvegarde(enAttente['login']!, enAttente['password']!);
    }
  }

  // ─── HTTP Auth (.htpasswd) ────────────────────────────────────────────────

  Future<HttpAuthResponse?> _gererAuthHttp(URLAuthenticationChallenge challenge) async {
    if (!mounted) return HttpAuthResponse(action: HttpAuthResponseAction.CANCEL);

    // Identifiants déjà stockés → réponse automatique, pas de dialog
    if (widget.login != null && widget.motDePasse != null) {
      return HttpAuthResponse(
        username: widget.login!,
        password: widget.motDePasse!,
        action: HttpAuthResponseAction.PROCEED,
        permanentPersistence: true,
      );
    }

    // Premier accès → dialog de saisie
    final loginCtrl = TextEditingController();
    final mdpCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Authentification requise\n${challenge.protectionSpace.host}',
          style: const TextStyle(fontSize: 15),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: loginCtrl,
              decoration: const InputDecoration(labelText: 'Identifiant'),
              autofocus: true,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: mdpCtrl,
              decoration: const InputDecoration(labelText: 'Mot de passe'),
              obscureText: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Se connecter'),
          ),
        ],
      ),
    );
    final loginText = loginCtrl.text;
    final mdpText = mdpCtrl.text;
    loginCtrl.dispose();
    mdpCtrl.dispose();
    if (ok == true) {
      // Proposer la sauvegarde après le chargement de la page
      _identifiantsEnAttente = {'login': loginText, 'password': mdpText};
      return HttpAuthResponse(
        username: loginText,
        password: mdpText,
        action: HttpAuthResponseAction.PROCEED,
        permanentPersistence: true,
      );
    }
    return HttpAuthResponse(action: HttpAuthResponseAction.CANCEL);
  }

  // ─── Téléchargement (PDF, etc.) ───────────────────────────────────────────

  Future<void> _telecharger(DownloadStartRequest request) =>
      _telechargerUrl(request.url.toString());

  Future<void> _telechargerUrl(String url) async {
    setState(() => _telechargementEnCours = true);
    try {
      final cookies = await CookieManager.instance().getCookies(url: WebUri(url));
      final cookieHeader = cookies.map((c) => '${c.name}=${c.value}').join('; ');

      final response = await http.get(
        Uri.parse(url),
        headers: {
          if (cookieHeader.isNotEmpty) 'Cookie': cookieHeader,
          'User-Agent': 'Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 '
              '(KHTML, like Gecko) Chrome/131.0.6778.135 Mobile Safari/537.36',
        },
      );

      if (response.statusCode != 200) throw Exception('HTTP ${response.statusCode}');

      final filename = _extraireNomFichier(response.headers, url);
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/$filename');
      await file.writeAsBytes(response.bodyBytes);

      if (!mounted) return;
      setState(() => _telechargementEnCours = false);
      await OpenFilex.open(file.path);
    } catch (e) {
      if (!mounted) return;
      setState(() => _telechargementEnCours = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Impossible d\'ouvrir le fichier : $e')),
      );
    }
  }

  // ─── Drives cloud ─────────────────────────────────────────────────────────

  // Retourne null si l'URL n'est pas un drive connu.
  // Retourne une URL de téléchargement direct si c'est Google Drive.
  // Retourne '' pour les autres drives (ouvrir dans le navigateur externe).
  String? _urlDrive(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return null;
    final host = uri.host.toLowerCase();

    // Google Drive → conversion en lien de téléchargement direct
    if (host == 'drive.google.com' || host == 'docs.google.com') {
      // Format /file/d/FILE_ID/...
      final match = RegExp(r'/(?:file|document|spreadsheets|presentation)/d/([^/?#]+)')
          .firstMatch(uri.path);
      if (match != null) {
        return 'https://drive.google.com/uc?export=download&id=${match.group(1)}';
      }
      // Format ?id=FILE_ID ou open?id=FILE_ID
      final id = uri.queryParameters['id'];
      if (id != null) {
        return 'https://drive.google.com/uc?export=download&id=$id';
      }
      return ''; // lien Google Drive non reconnu → ouvrir externalement
    }

    // Autres drives → ouvrir dans le navigateur externe
    const drivesExternes = [
      'drive.proton.me',
      'onedrive.live.com',
      '1drv.ms',
      'dropbox.com',
      'www.dropbox.com',
      'box.com',
      'app.box.com',
    ];
    if (drivesExternes.any((d) => host == d || host.endsWith('.$d')) ||
        host.contains('sharepoint.com') ||
        host.contains('sharepoint-df.com')) {
      return '';
    }

    return null;
  }

  String _extraireNomFichier(Map<String, String> headers, String url) {
    final cd = headers['content-disposition'] ?? '';
    final match = RegExp(r'filename\s*=\s*"?([^";\n]+)"?').firstMatch(cd);
    if (match != null) return match.group(1)!.trim();
    final path = Uri.parse(url).path;
    final name = path.split('/').last;
    return name.isNotEmpty ? name : 'fichier_${DateTime.now().millisecondsSinceEpoch}';
  }

  // ─── Gestion des credentials ──────────────────────────────────────────────

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

  Future<void> _proposerSauvegarde(String login, String password) async {
    if (_dialogueEnCours || !mounted) return;

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

  // ─── UI ───────────────────────────────────────────────────────────────────

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
              onPressed: () => _controller?.goBack(),
            ),
          if (_formulaireConnexionDetecte || _identifiantsEnAttente != null)
            IconButton(
              icon: const Icon(Icons.key),
              tooltip: 'Enregistrer les identifiants',
              onPressed: _captureManuelle,
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _controller?.reload(),
          ),
          IconButton(
            icon: const Icon(Icons.open_in_browser),
            tooltip: 'Ouvrir dans le navigateur',
            onPressed: () async {
              final uri = await _controller?.getUrl();
              final url = uri?.toString() ?? widget.url;
              await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          InAppWebView(
            initialUrlRequest: URLRequest(url: WebUri(widget.url)),
            initialSettings: InAppWebViewSettings(
              javaScriptEnabled: true,
              userAgent: 'Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 '
                  '(KHTML, like Gecko) Chrome/131.0.6778.135 Mobile Safari/537.36',
              useShouldOverrideUrlLoading: true,
              useOnDownloadStart: true,
            ),
            onWebViewCreated: (controller) {
              _controller = controller;
              _setupJsHandlers(controller);
            },
            onLoadStart: (controller, url) {
              setState(() {
                _chargement = true;
                _erreur = null;
              });
            },
            onLoadStop: (controller, url) async {
              final peutReculer = await controller.canGoBack();
              setState(() {
                _chargement = false;
                _peutReculer = peutReculer;
                _formulaireConnexionDetecte = false;
              });
              _injecterWindowOpen();
              await _injecterIdentifiants();
              final enAttente = _identifiantsEnAttente;
              if (enAttente != null) {
                _identifiantsEnAttente = null;
                await _proposerSauvegarde(enAttente['login']!, enAttente['password']!);
              }
              _injecterCapture();
            },
            shouldOverrideUrlLoading: (controller, navigationAction) async {
              final url = navigationAction.request.url?.toString() ?? '';
              if (url.startsWith('intent://') ||
                  url.startsWith('market://') ||
                  url.startsWith('android-app://')) {
                launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication)
                    .catchError((_) {});
                return NavigationActionPolicy.CANCEL;
              }
              final driveUrl = _urlDrive(url);
              if (driveUrl != null) {
                if (driveUrl.isNotEmpty) {
                  // Google Drive → téléchargement direct
                  _telechargerUrl(driveUrl);
                } else {
                  // Autre drive → navigateur externe
                  launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication)
                      .catchError((_) {});
                }
                return NavigationActionPolicy.CANCEL;
              }
              return NavigationActionPolicy.ALLOW;
            },
            onReceivedError: (controller, request, error) {
              if (request.isForMainFrame == true) {
                setState(() {
                  _chargement = false;
                  _erreur = error.description;
                });
              }
            },
            onReceivedServerTrustAuthRequest: (controller, challenge) async {
              return ServerTrustAuthResponse(
                  action: ServerTrustAuthResponseAction.PROCEED);
            },
            onReceivedHttpAuthRequest: (controller, challenge) async {
              return _gererAuthHttp(challenge);
            },
            onDownloadStartRequest: (controller, downloadStartRequest) async {
              await _telecharger(downloadStartRequest);
            },
          ),
          if (_chargement)
            const Center(child: CircularProgressIndicator()),
          if (_telechargementEnCours)
            Container(
              color: Colors.black45,
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 16),
                    Text(
                      'Téléchargement en cours...',
                      style: TextStyle(color: Colors.white, fontSize: 15),
                    ),
                  ],
                ),
              ),
            ),
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
                        style:
                            TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _erreur!,
                        style:
                            const TextStyle(fontSize: 12, color: Colors.grey),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: () => _controller?.reload(),
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
