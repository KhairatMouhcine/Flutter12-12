import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final user = FirebaseAuth.instance.currentUser;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0a0e27),
      appBar: AppBar(
        title: const Text(
          '🏠 Accueil',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF667eea), Color(0xFF764ba2)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      drawer: _buildDrawer(context),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0a0e27), Color(0xFF1a1f3a)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header de bienvenue
                _buildWelcomeHeader(),
                const SizedBox(height: 30),

                // Grille des fonctionnalités
                Expanded(
                  child: GridView.count(
                    crossAxisCount: 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    children: [
                      _buildFeatureCard(
                        icon: Icons.image_search,
                        title: 'Fruit Classifier',
                        subtitle: 'Classification IA',
                        color: const Color(0xFF667eea),
                        onTap: () =>
                            Navigator.pushNamed(context, "/fruitClasifier"),
                      ),
                      _buildFeatureCard(
                        icon: Icons.chat_bubble_outline,
                        title: 'Ollama Chat',
                        subtitle: 'Zero-Shot & CoT',
                        color: const Color(0xFF764ba2),
                        onTap: () => Navigator.pushNamed(context, "/chatbot"),
                      ),
                      _buildFeatureCard(
                        icon: Icons.school,
                        title: 'EMSI Chatbot',
                        subtitle: 'Fine-tuning + RAG',
                        color: const Color(0xFFf093fb),
                        onTap: () =>
                            Navigator.pushNamed(context, "/finetuning"),
                      ),
                      _buildFeatureCard(
                        icon: Icons.cloud,
                        title: 'Météo',
                        subtitle: 'Prévisions',
                        color: const Color(0xFF4facfe),
                        onTap: () => Navigator.pushNamed(context, "/meteo"),
                      ),
                      _buildFeatureCard(
                        icon: Icons.video_call,
                        title: 'Appel Vidéo',
                        subtitle: 'Communication',
                        color: const Color(0xFF00f2fe),
                        onTap: () => Navigator.pushNamed(context, "/callVideo"),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWelcomeHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF667eea), Color(0xFF764ba2), Color(0xFFf093fb)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF667eea).withOpacity(0.4),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: const CircleAvatar(
              radius: 35,
              backgroundImage: AssetImage('assets/images/avatar.png'),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Bienvenue 👋',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(height: 4),
                const Text(
                  'KHAIRAT MOUHCINE',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  user?.email ?? 'mouhcine.khairat@example.com',
                  style: const TextStyle(color: Colors.white60, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1a1f3a),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.3), width: 1),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.2),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [color, color.withOpacity(0.7)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: color.withOpacity(0.4),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(icon, color: Colors.white, size: 32),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(color: Colors.grey[500], fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDrawer(BuildContext context) {
    return Drawer(
      backgroundColor: const Color(0xFF0a0e27),
      child: Column(
        children: [
          // Header du Drawer
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: const CircleAvatar(
                    radius: 40,
                    backgroundImage: AssetImage('assets/images/avatar.png'),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'KHAIRAT MOUHCINE',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  user?.email ?? 'mouhcine.khairat@example.com',
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ],
            ),
          ),

          // Menu Items
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 10),
              children: [
                _buildDrawerItem(
                  icon: Icons.image_search,
                  title: 'Fruit Classifier',
                  color: const Color(0xFF667eea),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, "/fruitClasifier");
                  },
                ),
                _buildDrawerItem(
                  icon: Icons.chat_bubble_outline,
                  title: 'Ollama + Prompt',
                  color: const Color(0xFF764ba2),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, "/chatbot");
                  },
                ),
                _buildDrawerItem(
                  icon: Icons.school,
                  title: 'EMSI Chatbot Fine-tuning',
                  color: const Color(0xFFf093fb),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, "/finetuning");
                  },
                ),
                _buildDrawerItem(
                  icon: Icons.cloud,
                  title: 'Météo',
                  color: const Color(0xFF4facfe),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, "/meteo");
                  },
                ),
                _buildDrawerItem(
                  icon: Icons.video_call,
                  title: 'Appel Vidéo',
                  color: const Color(0xFF00f2fe),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, "/callVideo");
                  },
                ),

                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  child: Divider(color: Colors.white24),
                ),

                _buildDrawerItem(
                  icon: Icons.logout,
                  title: 'Déconnexion',
                  color: Colors.redAccent,
                  onTap: () async {
                    Navigator.pop(context);
                    await FirebaseAuth.instance.signOut();
                  },
                ),
              ],
            ),
          ),

          // Footer
          Container(
            padding: const EdgeInsets.all(16),
            child: Text(
              '© 2024 EMSI - Lab 3',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String title,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        title: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w500,
          ),
        ),
        trailing: Icon(
          Icons.arrow_forward_ios,
          color: Colors.grey[600],
          size: 16,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        onTap: onTap,
        hoverColor: color.withOpacity(0.1),
        splashColor: color.withOpacity(0.2),
      ),
    );
  }
}
