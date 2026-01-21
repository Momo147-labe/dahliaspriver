import 'package:flutter/material.dart';
import 'individual_card_page.dart';
import 'bulk_card_print_page.dart';

class BadgeGeneratorPage extends StatelessWidget {
  const BadgeGeneratorPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Générateur de Badges'),
          backgroundColor: const Color(0xFF0d6073),
          bottom: const TabBar(
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            tabs: [
              Tab(
                icon: Icon(Icons.person),
                text: 'Carte Individuelle',
              ),
              Tab(
                icon: Icon(Icons.group),
                text: 'Cartes par Classe',
              ),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            IndividualCardPage(),
            BulkCardPrintPage(),
          ],
        ),
      ),
    );
  }
}
