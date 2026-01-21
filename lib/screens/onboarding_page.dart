import 'package:flutter/material.dart';
import 'config/create_school_page.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final PageController _controller = PageController();
  int _currentPage = 0;

  // Liste des pages onboarding (5 pages)
  final List<_OnboardData> pages = [
    _OnboardData(
      title: "Bienvenue sur Guinée École",
      subtitle:
          "Transformez la gestion de votre établissement scolaire avec notre solution complète et intuitive. Conçue spécialement pour les écoles guinéennes, cette application vous permet de gérer efficacement tous les aspects administratifs et pédagogiques, même dans les zones à connectivité limitée.",
      imageUrl:
          "assets/ondoarding/Gemini_Generated_Image_bntnrmbntnrmbntn.png",
    ),
    _OnboardData(
      title: "Gestion Complète des Élèves",
      subtitle: "Créez des profils détaillés pour chaque élève avec photos, informations personnelles, historique académique et suivi des performances. Gérez les inscriptions, les transferts et maintenez un registre complet de tous vos étudiants avec une interface simple et rapide.",
      imageUrl: "assets/ondoarding/Gemini_Generated_Image_hq85bvhq85bvhq85.png",
    ),
    _OnboardData(
      title: "Organisation des Classes & Enseignants",
      subtitle: "Structurez votre établissement en créant des classes, en assignant les enseignants et en gérant les emplois du temps. Suivez les effectifs, organisez les groupes pédagogiques et optimisez la répartition des ressources humaines pour un enseignement de qualité.",
      imageUrl: "assets/ondoarding/Gemini_Generated_Image_i1nxjyi1nxjyi1nx.png",
    ),
    _OnboardData(
      title: "Système d'Évaluation Avancé",
      subtitle: "Enregistrez les notes, calculez automatiquement les moyennes trimestrielles et annuelles, générez des bulletins personnalisés et établissez des classements par mérite. Un système complet pour suivre et évaluer les progrès de chaque élève.",
      imageUrl: "assets/ondoarding/Gemini_Generated_Image_q2quvq2quvq2quvq.png",
    ),
    _OnboardData(
      title: "Fonctionnement 100% Hors Ligne",
      subtitle: "Travaillez en toute autonomie sans dépendre d'une connexion internet. Toutes vos données sont stockées localement de manière sécurisée sur votre appareil. Synchronisez quand vous le souhaitez et gardez le contrôle total de vos informations scolaires.",
      imageUrl: "assets/ondoarding/Gemini_Generated_Image_wqpapvwqpapvwqpa.png",
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.blue.shade50, Colors.white],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
            
              
              // PageView
              Expanded(
                child: PageView.builder(
                  controller: _controller,
                  itemCount: pages.length,
                  onPageChanged: (index) {
                    setState(() => _currentPage = index);
                  },
                  itemBuilder: (_, index) {
                    final page = pages[index];
                    return _OnboardPage(
                      title: page.title,
                      subtitle: page.subtitle,
                      imageUrl: page.imageUrl,
                      pages: pages,
                    );
                  },
                ),
              ),

              // Dots indicator
              Container(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    pages.length,
                    (index) => AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin: const EdgeInsets.symmetric(horizontal: 6),
                      height: 10,
                      width: _currentPage == index ? 30 : 10,
                      decoration: BoxDecoration(
                        color: _currentPage == index ? Colors.blue.shade600 : Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(5),
                      ),
                    ),
                  ),
                ),
              ),

              // Bouton Suivant / Commencer
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    if (_currentPage > 0)
                      Container(
                        height: 50,
                        width: 50,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(25),
                        ),
                        child: IconButton(
                          onPressed: () {
                            _controller.previousPage(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                            );
                          },
                          icon: Icon(
                            Icons.arrow_back_ios_new,
                            color: Colors.grey.shade600,
                            size: 18,
                          ),
                        ),
                      ),
                    
                    const Spacer(),
                    
                    // Bouton principal
                    Container(
                      height: 50,
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.blue.shade600, Colors.blue.shade700],
                        ),
                        borderRadius: BorderRadius.circular(25),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.blue.shade200,
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: TextButton(
                        onPressed: () {
                          if (_currentPage == pages.length - 1) {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const CreateSchoolPage(),
                              ),
                            );
                          } else {
                            _controller.nextPage(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                            );
                          }
                        },
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _currentPage == pages.length - 1 ? "Commencer" : "Suivant",
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(
                              Icons.arrow_forward_ios,
                              color: Colors.white,
                              size: 16,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OnboardPage extends StatelessWidget {
  final String title;
  final String subtitle;
  final String imageUrl;
  final List<_OnboardData> pages;

  const _OnboardPage({
    required this.title,
    required this.subtitle,
    required this.imageUrl,
    required this.pages,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;
    
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: isTablet ? 24 : 16),
      child: isTablet ? _buildTabletLayout() : _buildMobileLayout(),
    );
  }
  
  Widget _buildTabletLayout() {
    return Row(
      children: [
        // Image à gauche
        Expanded(
          flex: 5,
          child: Container(
            height: 500,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.asset(
                imageUrl,
                fit: BoxFit.cover,
              ),
            ),
          ),
        ),
        
        const SizedBox(width: 32),
        
        // Texte à droite
        Expanded(
          flex: 6,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  "Étape ${(pages.indexWhere((p) => p.title == title) + 1)}/5",
                  style: TextStyle(
                    color: Colors.blue.shade600,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: Colors.grey.shade900,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade600,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
  
  Widget _buildMobileLayout() {
    return Column(
      children: [
        const SizedBox(height: 20),
        // Image en haut
        Container(
          height: 280,
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.asset(
              imageUrl,
              fit: BoxFit.cover,
              width: double.infinity,
            ),
          ),
        ),
        
        const SizedBox(height: 32),
        
        // Texte en bas
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    "Étape ${(pages.indexWhere((p) => p.title == title) + 1)}/5",
                    style: TextStyle(
                      color: Colors.blue.shade600,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Colors.grey.shade900,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _OnboardData {
  final String title;
  final String subtitle;
  final String imageUrl;

  _OnboardData({
    required this.title,
    required this.subtitle,
    required this.imageUrl,
  });
}
