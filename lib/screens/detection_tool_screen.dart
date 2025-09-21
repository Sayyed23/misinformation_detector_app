import 'package:flutter/material.dart';

class DetectionToolScreen extends StatelessWidget {
  const DetectionToolScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC), // secondary-50
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8FAFC),
        elevation: 1,
        title: const Text(
          'Check News / Post',
          style: TextStyle(
            color: Color(0xFF0F172A), // secondary-900
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back,
              color: Color(0xFF334155)), // secondary-700
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline, color: Color(0xFF334155)),
            onPressed: () {},
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9), // secondary-100
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Paste text, links, or upload media to check the credibility of the information.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF475569), // secondary-600
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              maxLines: 5,
              decoration: InputDecoration(
                hintText: 'Paste text here',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      BorderSide(color: Color(0xFFCBD5E1)), // secondary-300
                ),
                hintStyle:
                    const TextStyle(color: Color(0xFF94A3B8)), // secondary-400
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              decoration: InputDecoration(
                hintText: 'Paste link here',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      BorderSide(color: Color(0xFFCBD5E1)), // secondary-300
                ),
                hintStyle:
                    const TextStyle(color: Color(0xFF94A3B8)), // secondary-400
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.upload_file, color: Color(0xFF334155)),
              label: const Text('Upload Media',
                  style: TextStyle(color: Color(0xFF334155))),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE2E8F0), // secondary-200
                foregroundColor: const Color(0xFF334155), // secondary-700
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0284C7), // primary-600
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: const Text('Check Credibility',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 32),
            // Result Section (mocked)
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                image: const DecorationImage(
                  image: NetworkImage(
                      'https://lh3.googleusercontent.com/aida-public/AB6AXuBl_ZMKJTyXqzfDcL1wIihp9vogLHa6IqnUSpK1N8iPgV_SAUM5ahsKOz_QPef4vAF8xA6FLtY2wFRi3zWVeFLTH6WGKcqJn7pK2TLTllEwHijJm1AQ4pjlpyuYDiP0PUN4wk-XhU-IzuYOs7AnrdL4Or7fk5p9n3gus9rqZhUDtQxuIkZhFm5BCveMkOshX57lsbrzpu_fB_ZL2njybh8rWjLmjHraw7-nFOpKnL2XRHVz3ooLZvPw-HA6vbFzOLM6qzJfQQbGf_I'),
                  fit: BoxFit.cover,
                ),
              ),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.6),
                      Colors.transparent,
                    ],
                  ),
                ),
                padding: const EdgeInsets.all(16),
                alignment: Alignment.bottomLeft,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text('Credibility Score: 85%',
                        style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.white)),
                    SizedBox(height: 4),
                    Text('High Credibility',
                        style:
                            TextStyle(fontSize: 18, color: Colors.greenAccent)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            // Explanation
            Align(
              alignment: Alignment.centerLeft,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text('Explanation',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A))),
                  SizedBox(height: 8),
                  Text(
                    'This news article has a high credibility score based on the following factors: The information is consistent with other reputable sources, the author is a known expert in the field, and the article cites its sources.',
                    style: TextStyle(color: Color(0xFF475569)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // Source Evidence
            Align(
              alignment: Alignment.centerLeft,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Source Evidence',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A))),
                  const SizedBox(height: 8),
                  _EvidenceItem(
                      icon: Icons.newspaper, label: 'Reputable News Outlet'),
                  _EvidenceItem(icon: Icons.person, label: 'Expert Author'),
                  _EvidenceItem(icon: Icons.link, label: 'Citations'),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // Further Reading
            Align(
              alignment: Alignment.centerLeft,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Further Reading',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A))),
                  const SizedBox(height: 8),
                  _EvidenceItem(icon: Icons.article, label: 'Related Articles'),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // Report Button
            ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF87171), // red-400
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: const Text('Report as Misinformation',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
      // Optional: Add a bottom navigation bar if needed
    );
  }
}

class _EvidenceItem extends StatelessWidget {
  final IconData icon;
  final String label;

  const _EvidenceItem({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFE0F2FE), // primary-100
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Icon(icon, color: const Color(0xFF0EA5E9)), // primary-500
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 16,
                color: Color(0xFF64748B), // secondary-500
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
