import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/catalogue.dart';
import '../models/raccourci.dart';
import '../services/export_service.dart';
import '../services/storage_service.dart';
import 'catalogue_screen.dart';
import 'catalogues_en_ligne_screen.dart';
import 'webview_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final StorageService _storage = StorageService();
  List<Raccourci> _raccourcis = [];
  bool _vueGrille = true;
  bool _modeReorganisation = false;
  bool _backupAutoDisponible = false;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    final data = await _storage.charger();
    final chemin = await _cheminBackupAuto();
    setState(() {
      _raccourcis = data;
      _backupAutoDisponible = File(chemin).existsSync();
    });
  }

  Future<void> _sauvegarder() async {
    await _storage.sauvegarder(_raccourcis);
  }

  String _faviconUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return '';
    return 'https://icons.duckduckgo.com/ip3/${uri.host}.ico';
  }

  // Couleur dérivée du nom par hash — palette Material Dark
  Color _couleurDepuisNom(String nom) {
    const palette = [
      Color(0xFF1565C0), // blue
      Color(0xFF2E7D32), // green
      Color(0xFFAD1457), // pink
      Color(0xFF6A1B9A), // purple
      Color(0xFF00695C), // teal
      Color(0xFFE65100), // orange
      Color(0xFF4527A0), // deep purple
      Color(0xFF00838F), // cyan
      Color(0xFF558B2F), // light green
      Color(0xFF6D4C41), // brown
    ];
    final index = nom.codeUnits.fold(0, (a, b) => a + b) % palette.length;
    return palette[index];
  }

  // Favicon dans un conteneur arrondi, avec initiale colorée en fallback
  Widget _iconeSite(Raccourci raccourci, {double size = 44}) {
    final couleur = _couleurDepuisNom(raccourci.nom);
    final initiale =
        raccourci.nom.isNotEmpty ? raccourci.nom[0].toUpperCase() : '?';
    final radius = size * 0.22;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: couleur.withOpacity(0.10),
        borderRadius: BorderRadius.circular(radius),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Image.network(
          _faviconUrl(raccourci.url),
          width: size,
          height: size,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => Center(
            child: Text(
              initiale,
              style: TextStyle(
                color: couleur,
                fontSize: size * 0.44,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _ouvrirRaccourci(Raccourci raccourci) async {
    final motDePasse = raccourci.login != null
        ? await _storage.chargerMotDePasse(raccourci.id)
        : null;
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => WebViewScreen(
          raccourciId: raccourci.id,
          nom: raccourci.nom,
          url: raccourci.url,
          login: raccourci.login,
          motDePasse: motDePasse,
          onCredentialsSaved: (login, _) {
            setState(() => raccourci.login = login);
            _sauvegarder();
          },
        ),
      ),
    );
  }

  Future<void> _ouvrirFormulaire({Raccourci? raccourci}) async {
    final mdpExistant = raccourci != null
        ? await _storage.chargerMotDePasse(raccourci.id)
        : null;

    if (!mounted) return;

    final nomController = TextEditingController(text: raccourci?.nom ?? '');
    final urlController = TextEditingController(text: raccourci?.url ?? '');
    final loginController = TextEditingController(text: raccourci?.login ?? '');
    final mdpController = TextEditingController(text: mdpExistant ?? '');
    bool mdpVisible = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(raccourci == null ? 'Ajouter un raccourci' : 'Modifier'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nomController,
                  decoration: const InputDecoration(labelText: 'Nom'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: urlController,
                  decoration: const InputDecoration(labelText: 'URL'),
                  keyboardType: TextInputType.url,
                ),
                const Divider(height: 28),
                TextField(
                  controller: loginController,
                  decoration: const InputDecoration(
                    labelText: 'Identifiant (optionnel)',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: mdpController,
                  obscureText: !mdpVisible,
                  decoration: InputDecoration(
                    labelText: 'Mot de passe (optionnel)',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                        mdpVisible ? Icons.visibility_off : Icons.visibility,
                      ),
                      onPressed: () =>
                          setDialogState(() => mdpVisible = !mdpVisible),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () async {
                final nom = nomController.text.trim();
                final url = urlController.text.trim();
                if (nom.isEmpty || url.isEmpty) return;

                final login = loginController.text.trim();
                final mdp = mdpController.text;

                final String targetId;
                if (raccourci == null) {
                  targetId = DateTime.now().millisecondsSinceEpoch.toString();
                  setState(() {
                    _raccourcis.add(Raccourci(
                      id: targetId,
                      nom: nom,
                      url: url,
                      login: login.isEmpty ? null : login,
                    ));
                  });
                } else {
                  targetId = raccourci.id;
                  setState(() {
                    raccourci.nom = nom;
                    raccourci.url = url;
                    raccourci.login = login.isEmpty ? null : login;
                  });
                }

                if (login.isNotEmpty && mdp.isNotEmpty) {
                  await _storage.sauvegarderMotDePasse(targetId, mdp);
                } else {
                  await _storage.supprimerMotDePasse(targetId);
                }

                _sauvegarder();
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text('Valider'),
            ),
          ],
        ),
      ),
    );
  }

  void _afficherOptions(Raccourci raccourci) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Modifier'),
              onTap: () {
                Navigator.pop(context);
                _ouvrirFormulaire(raccourci: raccourci);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text(
                'Supprimer',
                style: TextStyle(color: Colors.red),
              ),
              onTap: () {
                _storage.supprimerMotDePasse(raccourci.id);
                setState(() => _raccourcis.remove(raccourci));
                _sauvegarder();
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _carteGrille(Raccourci raccourci) {
    return GestureDetector(
      onTap: () => _ouvrirRaccourci(raccourci),
      onLongPress: () => _afficherOptions(raccourci),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Stack(
          children: [
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _iconeSite(raccourci, size: 44),
                    const SizedBox(height: 10),
                    Text(
                      raccourci.nom,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (raccourci.login != null)
              const Positioned(
                top: 6,
                right: 6,
                child: Icon(Icons.lock, size: 12, color: Colors.grey),
              ),
          ],
        ),
      ),
    );
  }

  Widget _carteListe(Raccourci raccourci) {
    final host = Uri.tryParse(raccourci.url)?.host ?? raccourci.url;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: _iconeSite(raccourci, size: 40),
      title: Text(
        raccourci.nom,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        host,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 12),
      ),
      trailing: raccourci.login != null
          ? const Icon(Icons.lock, size: 16, color: Colors.grey)
          : null,
      onTap: () => _ouvrirRaccourci(raccourci),
      onLongPress: () => _afficherOptions(raccourci),
    );
  }

  // ─── Export / Import ────────────────────────────────────────────────────

  Future<String?> _demanderPassphrase(String titre) async {
    final controller = TextEditingController();
    bool visible = false;
    return showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(titre),
          content: TextField(
            controller: controller,
            obscureText: !visible,
            autofocus: true,
            decoration: InputDecoration(
              labelText: 'Passphrase',
              suffixIcon: IconButton(
                icon: Icon(visible ? Icons.visibility_off : Icons.visibility),
                onPressed: () =>
                    setDialogState(() => visible = !visible),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () {
                final p = controller.text;
                if (p.isEmpty) return;
                Navigator.pop(ctx, p);
              },
              child: const Text('Confirmer'),
            ),
          ],
        ),
      ),
    );
  }

  void _afficherChargement(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        content: Row(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(width: 16),
            Text(message),
          ],
        ),
      ),
    );
  }

  Future<void> _exporter() async {
    final passphrase = await _demanderPassphrase('Exporter');
    if (passphrase == null || !mounted) return;

    // Nom de fichier par défaut, modifiable par l'utilisateur
    final now = DateTime.now();
    final nomDefaut =
        'sesame_${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}'
        '_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';
    final nomController = TextEditingController(text: nomDefaut);

    final nomFichier = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nom du fichier'),
        content: TextField(
          controller: nomController,
          autofocus: true,
          decoration: const InputDecoration(suffixText: '.lncr'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              final n = nomController.text.trim();
              if (n.isEmpty) return;
              Navigator.pop(ctx, n);
            },
            child: const Text('Exporter'),
          ),
        ],
      ),
    );
    if (nomFichier == null || !mounted) return;

    _afficherChargement('Export en cours…');

    try {
      final raccourcisExport = _raccourcis.where((r) => !r.estSeparateur).toList();
      final passwords = <String, String>{};
      for (final r in raccourcisExport) {
        if (r.login != null) {
          final mdp = await _storage.chargerMotDePasse(r.id);
          if (mdp != null) passwords[r.id] = mdp;
        }
      }

      final contenu = await ExportService.chiffrer(
        raccourcis: raccourcisExport,
        passwords: passwords,
        passphrase: passphrase,
      );

      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/$nomFichier.lncr');
      await file.writeAsString(contenu);

      if (!mounted) return;
      Navigator.pop(context);

      await Share.shareXFiles([XFile(file.path)], text: 'Sauvegarde Sésame');
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erreur lors de l'export : $e")),
        );
      }
    }
  }

  Future<void> _importer() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.any);
    if (result == null || !mounted) return;

    final path = result.files.single.path;
    if (path == null) return;

    final passphrase = await _demanderPassphrase('Importer');
    if (passphrase == null || !mounted) return;

    final action = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Importer'),
        content: const Text(
          'Remplacer : efface les raccourcis existants.\n\n'
          'Ajouter : fusionne avec les raccourcis existants. '
          'Les noms en doublon reçoivent un numéro (ex. : "Ma banque (2)").',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          OutlinedButton(
            onPressed: () => Navigator.pop(ctx, 'ajouter'),
            child: const Text('Ajouter'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, 'remplacer'),
            child: const Text('Remplacer'),
          ),
        ],
      ),
    );
    if (action == null || !mounted) return;

    _afficherChargement('Import en cours…');

    try {
      final contenu = await File(path).readAsString();
      final (:raccourcis, :passwords) = await ExportService.dechiffrer(
        contenu: contenu,
        passphrase: passphrase,
      );

      if (!mounted) return;

      if (action == 'remplacer') {
        await _storage.effacerTout();
        await _storage.sauvegarder(raccourcis);
        for (final entry in passwords.entries) {
          await _storage.sauvegarderMotDePasse(entry.key, entry.value);
        }
        Navigator.pop(context);
        setState(() => _raccourcis = raccourcis);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${raccourcis.length} raccourci(s) importé(s)')),
        );
      } else {
        // Fusion : nouveaux IDs pour éviter les conflits, noms dédupliqués
        final nomsExistants = _raccourcis.map((r) => r.nom).toSet();
        final base = DateTime.now().millisecondsSinceEpoch;
        final ajouts = <Raccourci>[];
        final ajoutsPasswords = <String, String>{};

        for (var i = 0; i < raccourcis.length; i++) {
          final r = raccourcis[i];
          final nouveauId = (base + i).toString();

          String nom = r.nom;
          if (nomsExistants.contains(nom)) {
            var n = 2;
            while (nomsExistants.contains('$nom ($n)')) n++;
            nom = '$nom ($n)';
          }
          nomsExistants.add(nom);

          ajouts.add(Raccourci(id: nouveauId, nom: nom, url: r.url, login: r.login));

          final mdp = passwords[r.id];
          if (mdp != null) ajoutsPasswords[nouveauId] = mdp;
        }

        final tousLesRaccourcis = [..._raccourcis, ...ajouts];
        await _storage.sauvegarder(tousLesRaccourcis);
        for (final entry in ajoutsPasswords.entries) {
          await _storage.sauvegarderMotDePasse(entry.key, entry.value);
        }

        Navigator.pop(context);
        setState(() => _raccourcis = tousLesRaccourcis);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${ajouts.length} raccourci(s) ajouté(s)')),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Échec de l\'import. Vérifiez la passphrase ou le fichier.'),
          ),
        );
      }
    }
  }

  // ─── Effacement + backup auto ────────────────────────────────────────────

  Future<String> _cheminBackupAuto() async {
    final dir = await getApplicationDocumentsDirectory();
    return '${dir.path}/backup_auto.json';
  }

  Future<void> _effacerTousLesRaccourcis() async {
    if (_raccourcis.isEmpty) return;

    final chemin = await _cheminBackupAuto();
    await File(chemin).writeAsString(
      jsonEncode(_raccourcis.map((r) => r.toJson()).toList()),
    );

    if (!mounted) return;
    final confirme = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tout effacer'),
        content: Text(
          'Sauvegarde créée.\n\nEffacer les ${_raccourcis.length} raccourci(s) ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child:
                const Text('Effacer', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirme != true || !mounted) return;

    await _storage.effacerRaccourcis();
    setState(() {
      _raccourcis = [];
      _backupAutoDisponible = true;
    });
  }

  Future<void> _restaurerBackupAuto() async {
    final chemin = await _cheminBackupAuto();
    final file = File(chemin);
    if (!await file.exists()) return;

    if (!mounted) return;
    final confirme = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restaurer la sauvegarde'),
        content: const Text(
            'Remplacer les raccourcis actuels par la dernière sauvegarde ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Restaurer'),
          ),
        ],
      ),
    );
    if (confirme != true || !mounted) return;

    final data = await file.readAsString();
    final List<dynamic> decoded = jsonDecode(data);
    final raccourcis = decoded.map((e) => Raccourci.fromJson(e)).toList();

    await _storage.sauvegarder(raccourcis);
    setState(() => _raccourcis = raccourcis);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${raccourcis.length} raccourci(s) restauré(s)')),
    );
  }

  Future<void> _importerCatalogue() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.any);
    if (result == null || !mounted) return;

    final path = result.files.single.path;
    if (path == null) return;

    try {
      final contenu = await File(path).readAsString();
      final data = jsonDecode(contenu) as Map<String, dynamic>;
      final categories = (data['categories'] as List)
          .map((c) => CatalogueCategorie.fromJson(c as Map<String, dynamic>))
          .toList();

      if (!mounted) return;
      final urlsExistantes = _raccourcis.map((r) => r.url).toSet();
      final nbAjoutes = await Navigator.push<int>(
        context,
        MaterialPageRoute(
          builder: (_) => CatalogueScreen(
            premierLancement: false,
            urlsExistantes: urlsExistantes,
            categories: categories,
          ),
        ),
      );
      if (!mounted) return;
      if (nbAjoutes != null && nbAjoutes > 0) {
        await _charger();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '$nbAjoutes raccourci${nbAjoutes > 1 ? 's ajoutés' : ' ajouté'}'),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Fichier catalogue invalide.')),
        );
      }
    }
  }

  Future<void> _ouvrirCatalogue() async {
    final urlsExistantes = _raccourcis.map((r) => r.url).toSet();
    final nbAjoutes = await Navigator.push<int>(
      context,
      MaterialPageRoute(
        builder: (_) => CatalogueScreen(
          premierLancement: false,
          urlsExistantes: urlsExistantes,
        ),
      ),
    );
    if (!mounted) return;
    if (nbAjoutes != null && nbAjoutes > 0) {
      await _charger();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              '$nbAjoutes raccourci${nbAjoutes > 1 ? 's ajoutés' : ' ajouté'}'),
        ),
      );
    }
  }

  Future<void> _ouvrirCataloguesEnLigne() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CataloguesEnLigneScreen()),
    );
    if (!mounted) return;
    await _charger();
  }

  Future<void> _afficherAPropos() async {
    final info = await PackageInfo.fromPlatform();
    final version = info.version.replaceAll(RegExp(r'\.0$'), '');
    if (!mounted) return;
    showAboutDialog(
      context: context,
      applicationName: 'Sésame',
      applicationVersion: 'v$version',
      applicationLegalese: '© ${DateTime.now().year}',
      children: [
        const SizedBox(height: 16),
        InkWell(
          onTap: () => launchUrl(
            Uri.parse(
                'https://jbil-kebir.github.io/Sesame/confidentialite.html'),
            mode: LaunchMode.externalApplication,
          ),
          child: const Text(
            'Politique de confidentialité',
            style: TextStyle(
              color: Colors.blue,
              decoration: TextDecoration.underline,
            ),
          ),
        ),
      ],
    );
  }

  // ─── Séparateurs ─────────────────────────────────────────────────────────

  Widget _separateurLigne() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          const Expanded(child: Divider()),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Icon(Icons.drag_handle, size: 16, color: Colors.grey[400]),
          ),
          const Expanded(child: Divider()),
        ],
      ),
    );
  }

  List<Widget> _buildSlivers() {
    final slivers = <Widget>[];
    var segmentStart = 0;
    bool premierSegment = true;

    void ajouterSegment(int fin) {
      final segment = _raccourcis.sublist(segmentStart, fin)
          .where((r) => !r.estSeparateur)
          .toList();
      if (segment.isEmpty) return;
      slivers.add(SliverPadding(
        padding: EdgeInsets.fromLTRB(12, premierSegment ? 12 : 0, 12, 0),
        sliver: SliverGrid(
          delegate: SliverChildBuilderDelegate(
            (_, j) => _carteGrille(segment[j]),
            childCount: segment.length,
          ),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 1.05,
          ),
        ),
      ));
      premierSegment = false;
    }

    for (var i = 0; i < _raccourcis.length; i++) {
      if (_raccourcis[i].estSeparateur) {
        ajouterSegment(i);
        slivers.add(SliverToBoxAdapter(child: _separateurLigne()));
        segmentStart = i + 1;
      }
    }
    ajouterSegment(_raccourcis.length);
    slivers.add(const SliverPadding(padding: EdgeInsets.only(bottom: 12)));
    return slivers;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _modeReorganisation
          ? AppBar(
              title: const Text('Réorganiser'),
              backgroundColor: Colors.blueGrey,
              foregroundColor: Colors.white,
              automaticallyImplyLeading: false,
              actions: [
                IconButton(
                  icon: const Icon(Icons.add),
                  tooltip: 'Ajouter un séparateur',
                  onPressed: () {
                    final id = DateTime.now().millisecondsSinceEpoch.toString();
                    setState(() => _raccourcis.add(Raccourci.separateur(id)));
                    _sauvegarder();
                  },
                ),
                TextButton(
                  onPressed: () => setState(() => _modeReorganisation = false),
                  child: const Text(
                    'Terminer',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            )
          : AppBar(
              title: const Text('Sésame'),
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              actions: [
                IconButton(
                  icon: Icon(_vueGrille ? Icons.list : Icons.grid_view),
                  onPressed: () => setState(() => _vueGrille = !_vueGrille),
                ),
                IconButton(
                  icon: const Icon(Icons.info_outline),
                  onPressed: _afficherAPropos,
                ),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'reorganiser')
                      setState(() => _modeReorganisation = true);
                    if (value == 'catalogue') _ouvrirCatalogue();
                    if (value == 'catalogue_sesame') _importerCatalogue();
                    if (value == 'catalogue_en_ligne') _ouvrirCataloguesEnLigne();
                    if (value == 'export') _exporter();
                    if (value == 'import') _importer();
                    if (value == 'effacer') _effacerTousLesRaccourcis();
                    if (value == 'restaurer') _restaurerBackupAuto();
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                        value: 'reorganiser', child: Text('Réorganiser')),
                    const PopupMenuDivider(),
                    const PopupMenuItem(
                        value: 'catalogue',
                        child: Text('Catalogue par défaut')),
                    const PopupMenuItem(
                        value: 'catalogue_sesame',
                        child: Text('Importer un catalogue (.sesame)')),
                    const PopupMenuItem(
                        value: 'catalogue_en_ligne',
                        child: Text('Catalogues en ligne')),
                    const PopupMenuDivider(),
                    const PopupMenuItem(value: 'export', child: Text('Exporter')),
                    const PopupMenuItem(value: 'import', child: Text('Importer')),
                    const PopupMenuDivider(),
                    const PopupMenuItem(
                      value: 'effacer',
                      child: Text('Tout effacer',
                          style: TextStyle(color: Colors.red)),
                    ),
                    if (_backupAutoDisponible)
                      const PopupMenuItem(
                        value: 'restaurer',
                        child: Text('Restaurer la sauvegarde'),
                      ),
                  ],
                ),
              ],
            ),
      body: _raccourcis.isEmpty
          ? const Center(child: Text('Appuyez sur + pour ajouter un raccourci'))
          : _modeReorganisation
              ? ReorderableListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  onReorder: (oldIndex, newIndex) {
                    setState(() {
                      if (newIndex > oldIndex) newIndex--;
                      final item = _raccourcis.removeAt(oldIndex);
                      _raccourcis.insert(newIndex, item);
                    });
                    _sauvegarder();
                  },
                  itemCount: _raccourcis.length,
                  itemBuilder: (_, i) {
                    final r = _raccourcis[i];
                    if (r.estSeparateur) {
                      return ListTile(
                        key: ValueKey(r.id),
                        leading: IconButton(
                          icon: const Icon(Icons.delete_outline,
                              color: Colors.red),
                          onPressed: () {
                            setState(() => _raccourcis.remove(r));
                            _sauvegarder();
                          },
                        ),
                        title: const Divider(),
                        trailing:
                            const Icon(Icons.drag_handle, color: Colors.grey),
                      );
                    }
                    return ListTile(
                      key: ValueKey(r.id),
                      leading: _iconeSite(r, size: 36),
                      title: Text(r.nom,
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(
                        Uri.tryParse(r.url)?.host ?? r.url,
                        style: const TextStyle(fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: const Icon(Icons.drag_handle, color: Colors.grey),
                    );
                  },
                )
              : _vueGrille
                  ? CustomScrollView(slivers: _buildSlivers())
                  : ListView.builder(
                      itemCount: _raccourcis.length,
                      itemBuilder: (_, i) {
                        final r = _raccourcis[i];
                        if (r.estSeparateur) return _separateurLigne();
                        return _carteListe(r);
                      },
                    ),
      floatingActionButton: _modeReorganisation
          ? null
          : FloatingActionButton(
              onPressed: () => _ouvrirFormulaire(),
              child: const Icon(Icons.add),
            ),
    );
  }
}
