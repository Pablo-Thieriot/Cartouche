import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() => runApp(const CartouchesApp());

class CartouchesApp extends StatelessWidget {
  const CartouchesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cartouches compatibles',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
      home: const AccueilPage(),
    );
  }
}

// ============ MODÈLES ============

class Cartouche {
  final String couleur;
  final String reference;

  const Cartouche({required this.couleur, required this.reference});

  factory Cartouche.fromJson(Map<String, dynamic> json) => Cartouche(
        couleur: json['couleur'] as String,
        reference: json['ref'] as String,
      );
}

class Imprimante {
  final String marque;
  final String modele;
  final String type;
  final List<Cartouche> cartouches;

  // Index de recherche calculés une seule fois, au premier accès.
  late final List<String> motsIndex = Recherche.mots(
    '$marque $modele ${cartouches.map((c) => c.reference).join(' ')}',
  );
  late final String blobIndex = motsIndex.join();

  Imprimante({
    required this.marque,
    required this.modele,
    required this.type,
    required this.cartouches,
  });

  factory Imprimante.fromJson(Map<String, dynamic> json) => Imprimante(
        marque: json['marque'] as String,
        modele: json['modele'] as String,
        type: json['type'] as String,
        cartouches: (json['cartouches'] as List)
            .map((c) => Cartouche.fromJson(c as Map<String, dynamic>))
            .toList(),
      );
}

// ============ DONNÉES (hors ligne, depuis les assets) ============

class DepotImprimantes {
  static Future<List<Imprimante>> charger() async {
    final brut = await rootBundle.loadString('assets/data/imprimantes.json');
    final json = jsonDecode(brut) as Map<String, dynamic>;
    return (json['imprimantes'] as List)
        .map((e) => Imprimante.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}

// ============ RECHERCHE (tolérante aux fautes de frappe légères) ============

class Recherche {
  static const _avecAccents = 'àâäéèêëîïôöùûüç';
  static const _sansAccents = 'aaaeeeeiioouuuc';

  static String _normaliser(String texte) {
    var resultat = texte.toLowerCase();
    for (var i = 0; i < _avecAccents.length; i++) {
      resultat = resultat.replaceAll(_avecAccents[i], _sansAccents[i]);
    }
    return resultat;
  }

  /// Découpe le texte en mots, sans accents ni ponctuation.
  static List<String> mots(String texte) => _normaliser(texte)
      .split(RegExp(r'[^a-z0-9]+'))
      .where((m) => m.isNotEmpty)
      .toList();

  /// Renvoie les imprimantes qui correspondent à TOUS les mots saisis.
  static List<Imprimante> filtrer(
    List<Imprimante> imprimantes,
    String requete, {
    String? marque,
  }) {
    final jetons = mots(requete);
    return imprimantes.where((imp) {
      if (marque != null && imp.marque != marque) return false;
      return jetons.every((j) => _correspond(j, imp));
    }).toList();
  }

  static bool _correspond(String jeton, Imprimante imp) {
    // Sous-chaîne : "2720", "deskjet2720", "mg30"...
    if (imp.blobIndex.contains(jeton)) return true;
    // Faute de frappe d'un caractère, pour les jetons d'au moins 4 lettres.
    if (jeton.length < 4) return false;
    return imp.motsIndex.any((mot) =>
        (mot.length - jeton.length).abs() <= 1 &&
        _levenshtein(jeton, mot) <= 1);
  }

  static int _levenshtein(String a, String b) {
    var precedente = List<int>.generate(b.length + 1, (j) => j);
    for (var i = 1; i <= a.length; i++) {
      final courante = List<int>.filled(b.length + 1, 0);
      courante[0] = i;
      for (var j = 1; j <= b.length; j++) {
        final cout = a[i - 1] == b[j - 1] ? 0 : 1;
        courante[j] = math.min(
          math.min(courante[j - 1] + 1, precedente[j] + 1),
          precedente[j - 1] + cout,
        );
      }
      precedente = courante;
    }
    return precedente[b.length];
  }
}

// ============ COULEURS DES CARTOUCHES ============

List<Color> couleursPour(String nom) {
  switch (nom.toLowerCase()) {
    case 'cyan':
      return const [Color(0xFF00BCD4), Color(0xFF00BCD4)];
    case 'magenta':
      return const [Color(0xFFE91E63), Color(0xFFE91E63)];
    case 'jaune':
      return const [Color(0xFFFFC107), Color(0xFFFFC107)];
    case 'tricolore':
      return const [Color(0xFF00BCD4), Color(0xFFE91E63), Color(0xFFFFC107)];
    case 'multipack':
      return const [
        Colors.black87,
        Color(0xFF00BCD4),
        Color(0xFFE91E63),
        Color(0xFFFFC107),
      ];
    default: // Noir
      return const [Colors.black87, Colors.black87];
  }
}

// ============ ÉCRAN PRINCIPAL ============

class AccueilPage extends StatefulWidget {
  const AccueilPage({super.key});

  @override
  State<AccueilPage> createState() => _AccueilPageState();
}

class _AccueilPageState extends State<AccueilPage> {
  static const _marques = ['Tous', 'HP', 'Canon', 'Epson'];

  final _controleur = TextEditingController();
  List<Imprimante> _toutes = [];
  List<Imprimante> _resultats = [];
  String _requete = '';
  String _marque = 'Tous';
  bool _chargement = true;

  @override
  void initState() {
    super.initState();
    DepotImprimantes.charger().then((donnees) {
      if (!mounted) return;
      setState(() {
        _toutes = donnees;
        _resultats = donnees;
        _chargement = false;
      });
    });
  }

  @override
  void dispose() {
    _controleur.dispose();
    super.dispose();
  }

  void _actualiser() {
    setState(() {
      _resultats = Recherche.filtrer(
        _toutes,
        _requete,
        marque: _marque == 'Tous' ? null : _marque,
      );
    });
  }

  Widget _filtreMarque(String marque) {
    return ChoiceChip(
      label: Text(marque),
      selected: _marque == marque,
      onSelected: (_) {
        _marque = marque;
        _actualiser();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cartouches compatibles')),
      body: _chargement
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                  child: TextField(
                    controller: _controleur,
                    onChanged: (valeur) {
                      _requete = valeur;
                      _actualiser();
                    },
                    decoration: InputDecoration(
                      hintText: 'Ex : deskjet 2720, mg3050, xp 235…',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _requete.isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _controleur.clear();
                                _requete = '';
                                _actualiser();
                              },
                            ),
                      filled: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Wrap(
                    spacing: 8,
                    children: _marques.map(_filtreMarque).toList(),
                  ),
                ),
                const SizedBox(height: 4),
                Expanded(
                  child: _resultats.isEmpty
                      ? const Center(child: Text('Aucune imprimante trouvée'))
                      : ListView.builder(
                          padding: const EdgeInsets.only(bottom: 16),
                          itemCount: _resultats.length,
                          itemBuilder: (_, i) =>
                              ImprimanteCarte(imprimante: _resultats[i]),
                        ),
                ),
              ],
            ),
    );
  }
}

// ============ WIDGETS ============

class ImprimanteCarte extends StatelessWidget {
  final Imprimante imprimante;

  const ImprimanteCarte({super.key, required this.imprimante});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Chip(
                  label: Text(imprimante.marque),
                  visualDensity: VisualDensity.compact,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    imprimante.modele,
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(top: 2, bottom: 10),
              child: Text(imprimante.type, style: theme.textTheme.bodySmall),
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: imprimante.cartouches
                  .map((c) => CartoucheTuile(cartouche: c))
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class CartoucheTuile extends StatelessWidget {
  final Cartouche cartouche;

  const CartoucheTuile({super.key, required this.cartouche});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.only(left: 10, right: 2, top: 4, bottom: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Pastille(couleur: cartouche.couleur),
          const SizedBox(width: 8),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(cartouche.couleur, style: theme.textTheme.labelSmall),
              Text(
                cartouche.reference,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          IconButton(
            tooltip: 'Copier la référence',
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.copy_rounded, size: 18),
            onPressed: () => _copier(context, cartouche.reference),
          ),
        ],
      ),
    );
  }
}

class _Pastille extends StatelessWidget {
  final String couleur;

  const _Pastille({required this.couleur});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 18,
      height: 18,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(colors: couleursPour(couleur)),
        border: Border.all(color: Colors.black26),
      ),
    );
  }
}

void _copier(BuildContext context, String reference) {
  Clipboard.setData(ClipboardData(text: reference));
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text('Référence « $reference » copiée'),
        duration: const Duration(seconds: 1),
      ),
    );
}
