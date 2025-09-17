import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_constants.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final User? user = FirebaseAuth.instance.currentUser;
  
  @override
  Widget build(BuildContext context) {
    final String userName = user?.displayName ?? 'User';
    final String firstName = userName.split(' ').first;
    
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // App Bar
            SliverAppBar(
              backgroundColor: Colors.white,
              elevation: 0,
              floating: true,
              leadingWidth: 200,
              leading: Padding(
                padding: const EdgeInsets.only(left: 16),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: const Color(0xFFE3F2FD),
                      backgroundImage: user?.photoURL != null
                          ? NetworkImage(user!.photoURL!)
                          : null,
                      child: user?.photoURL == null
                          ? Text(
                              firstName[0].toUpperCase(),
                              style: const TextStyle(
                                color: Color(0xFF2196F3),
                                fontWeight: FontWeight.bold,
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'NewsWise',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.notifications_outlined),
                  color: const Color(0xFF424242),
                  onPressed: () {},
                ),
                IconButton(
                  icon: const Icon(Icons.account_circle_outlined),
                  color: const Color(0xFF424242),
                  onPressed: () {
                    context.push(AppConstants.profileRoute);
                  },
                ),
                const SizedBox(width: 8),
              ],
            ),
            
            // Content
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Welcome Section
                  Container(
                    color: Colors.white,
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Welcome back, $firstName!',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1A1A1A),
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Stay informed and verify content instantly',
                          style: TextStyle(
                            fontSize: 14,
                            color: Color(0xFF757575),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 12),
                  
                  // Feature Cards
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: _buildFeatureCard(
                            context,
                            'Check News / Post',
                            'Verify content credibility',
                            const Color(0xFFFFF3E0),
                            Icons.fact_check_outlined,
                            () => context.push(AppConstants.analysisRoute),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildFeatureCard(
                            context,
                            'Learn Skills',
                            'Media literacy modules',
                            const Color(0xFFFFEDE7),
                            Icons.school_outlined,
                            () => context.push(AppConstants.educationRoute),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // For You Section
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Text(
                      'For you',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF1A1A1A),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Info Cards
                  _buildInfoCard(
                    'Tip: Verify sources before sharing',
                    '3 min read',
                    Icons.lightbulb_outline,
                    const Color(0xFFE3F2FD),
                    const Color(0xFF2196F3),
                  ),
                  
                  _buildInfoCard(
                    'Community Update: New forum rules',
                    '2 min read',
                    Icons.people_outline,
                    const Color(0xFFE8F5E9),
                    const Color(0xFF4CAF50),
                  ),
                  
                  _buildInfoCard(
                    'Suggested Learning: Spotting fake news',
                    '4 min read',
                    Icons.school_outlined,
                    const Color(0xFFF3E5F5),
                    const Color(0xFF9C27B0),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Featured Article
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        // Article Image
                        Container(
                          height: 180,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFEDE7),
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(16),
                              topRight: Radius.circular(16),
                            ),
                          ),
                          child: Center(
                            child: Icon(
                              Icons.article_outlined,
                              size: 80,
                              color: const Color(0xFFFF9800),
                            ),
                          ),
                        ),
                        
                        // Article Content
                        Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Featured',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF757575),
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'The impact of misinformation',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1A1A1A),
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Learn how misinformation affects society and how to combat it.',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFF757575),
                                  height: 1.5,
                                ),
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: () {},
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF2196F3),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  elevation: 0,
                                ),
                                child: const Text(
                                  'Read More',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildFeatureCard(
    BuildContext context,
    String title,
    String subtitle,
    Color backgroundColor,
    IconData icon,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.8),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                size: 32,
                color: const Color(0xFF424242),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1A1A1A),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF757575),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildInfoCard(
    String title,
    String time,
    IconData icon,
    Color backgroundColor,
    Color iconColor,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: iconColor,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  time,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF757575),
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.arrow_forward_ios,
            size: 16,
            color: const Color(0xFF9E9E9E),
          ),
        ],
      ),
    );
  }
}