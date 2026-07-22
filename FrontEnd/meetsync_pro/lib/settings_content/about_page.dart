import 'package:flutter/material.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('About MeetSync Pro'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // App Logo and Version
            Image.asset('assets/logo.png', height: 100),
            const SizedBox(height: 16),
            const Text(
              'MeetSync Pro',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            const Text(
              'Version 2.1.0',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),

            // Our Story
            _buildSection('Our Story'),
            const Text(
              'Founded in 2023, MeetSync Pro was created by professionals frustrated with existing scheduling tools. '
              'We built a solution that actually understands the needs of consultants, coaches, and busy teams.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),

            // What Makes Us Different
            _buildSection('Why Choose Us?'),
            _buildFeatureCard(
              icon: Icons.auto_awesome,
              title: 'Smart Automation',
              description: 'Our AI suggests optimal meeting times and prevents double-booking automatically',
            ),
            _buildFeatureCard(
              icon: Icons.integration_instructions,
              title: 'Deep Integrations',
              description: 'Works seamlessly with Google Calendar, Outlook, Teams, and Meet',
            ),
            _buildFeatureCard(
              icon: Icons.security,
              title: 'Enterprise Security',
              description: 'End-to-end encryption and GDPR compliance built in',
            ),
            const SizedBox(height: 24),

            // Team Behind
            _buildSection('The Team'),
            const Text(
              'We\'re a small team of scheduling enthusiasts and productivity geeks '
              'dedicated to making professional meeting management effortless.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),

            // Contact
            _buildSection('Contact Us'),
            const Text(
              'Have questions or feedback? We\'d love to hear from you!',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            _buildContactButton(
              icon: Icons.email,
              label: 'Email Us',
              onTap: () {}, // Add email action
            ),
            _buildContactButton(
              icon: Icons.language,
              label: 'Visit Website',
              onTap: () {}, // Add website action
            ),
            const SizedBox(height: 24),

            // Legal
            _buildSection('Legal'),
            TextButton(
              onPressed: () {}, // Add privacy policy navigation
              child: const Text('Privacy Policy'),
            ),
            TextButton(
              onPressed: () {}, // Add terms navigation
              child: const Text('Terms of Service'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.blue,
        ),
      ),
    );
  }

  Widget _buildFeatureCard({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon, size: 40, color: Colors.blue),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Text(description),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: OutlinedButton.icon(
        icon: Icon(icon),
        label: Text(label),
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(double.infinity, 48),
          side: const BorderSide(color: Colors.blue),
        ),
      ),
    );
  }
}