import 'package:flutter/material.dart';

import '../models/catalogue.dart';
import '../models/catalogue_en_ligne.dart';
import '../services/catalogue_en_ligne_service.dart';
import '../services/storage_service.dart';
import 'catalogue_screen.dart';

class CataloguesEnLigneScreen extends StatefulWidget {
  const CataloguesEnLigneScreen({super.key});

  @override
  State<CataloguesEnLigneScreen> createState() =>
      _CataloguesEnLigneScreenState();
}

class _CataloguesEnLigneScreenState extends State<CataloguesEnLigneScreen> {
  final CatalogueEnLigneService _service = CatalogueEnLigneService();
  final StorageService _storage = StorageService();

  List<CatalogueEnLigneInfo> _catalogues = [];
  Map<String, int?> _versionsLocales = {};
  bool _chargement = true;
  String? _erreur;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    setState(() {
      _chargement = true;
      _erreur = null;
    });
    try {
      final catalogues = await _service.chargerIndex();
      final versions = <String, int?>{};
      for (final c in catalogues) {
        versions[c.id] = await _service.versionLocale(c.id);
      }
      setState(() {
        _catalogues = catalogues;
        _versionsLocales = versions;
        _chargement = false;
      });
    } catch (_) {
      setState(() {
        _erreur = 'Impossible de charger les catalogues.\nVérifiez votre connexion.';
        _chargement = false;
      });
    }
  }

  Future<void> _ouvrirCatalogue(CatalogueEnLigneInfo info) async {
    // Téléchargement
    List<CatalogueCategorie> categories;
    try {
      _afficherChargement();
      categories = await _service.telechargerCatalogue(info.url);
    } catch (_) {
      if (!mounted) return;
      Navigator.pop(context); // ferme le dialog de chargement
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Téléchargement impossible. Vérifiez votre connexion.')),
      );
      return;
    }
    if (!mounted) return;
    Navigator.pop(context); // ferme le dialog de chargement

    // URLs déjà présentes pour griser les doublons dans CatalogueScreen
    final existants = await _storage.charger();
    final urlsExistantes = existants.map((r) => r.url).toSet();
    if (!mounted) return;

    final nbImportes = await Navigator.push<int>(
      context,
      MaterialPageRoute(
        builder: (_) => CatalogueScreen(
          premierLancement: false,
          urlsExistantes: urlsExistantes,
          categories: categories,
        ),
      ),
    );

    if (nbImportes != null && nbImportes > 0) {
      await _service.sauvegarderVersion(info.id, info.version);
      setState(() => _versionsLocales[info.id] = info.version);
    }
  }

  void _afficherChargement() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Téléchargement…'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── UI ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        title: const Text('Catalogues en ligne'),
        actions: [
          IconButton(
            onPressed: _chargement ? null : _charger,
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualiser',
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_chargement) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_erreur != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off, size: 56, color: Colors.grey),
              const SizedBox(height: 16),
              Text(
                _erreur!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _charger,
                icon: const Icon(Icons.refresh),
                label: const Text('Réessayer'),
              ),
            ],
          ),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _charger,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _catalogues.length,
        itemBuilder: (context, i) => _buildCarte(_catalogues[i]),
      ),
    );
  }

  Widget _buildCarte(CatalogueEnLigneInfo info) {
    final versionLocale = _versionsLocales[info.id];
    final dejaImporte = versionLocale != null;
    final majDispo = dejaImporte && info.version > versionLocale;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _ouvrirCatalogue(info),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      info.nom,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (majDispo)
                    _badge('Mise à jour', Colors.orange)
                  else if (dejaImporte)
                    _badge('Importé', Colors.green),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                info.description,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[600],
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(Icons.link, size: 14, color: Colors.grey[500]),
                  const SizedBox(width: 4),
                  Text(
                    '${info.nbRaccourcis} raccourci${info.nbRaccourcis > 1 ? 's' : ''}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                  ),
                  const SizedBox(width: 16),
                  Icon(Icons.calendar_today, size: 14, color: Colors.grey[500]),
                  const SizedBox(width: 4),
                  Text(
                    info.updated,
                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _badge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color.withValues(alpha: 0.9),
        ),
      ),
    );
  }
}
