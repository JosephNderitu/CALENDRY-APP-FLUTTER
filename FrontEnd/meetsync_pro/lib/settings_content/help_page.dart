import 'package:flutter/material.dart';

class HelpPage extends StatelessWidget {
  const HelpPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Help & Support'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Why Choose Us Section
            _buildSectionHeader('Why MeetSync Pro?'),
            const Text(
              'Unlike other scheduling tools, MeetSync Pro offers:',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 10),
            _buildFeatureBullet('✓ Smart scheduling with no double bookings'),
            _buildFeatureBullet('✓ Automated meeting reminders via WhatsApp and email'),
            _buildFeatureBullet('✓ Direct video conference links (Google Meet, Teams, Skype)'),
            _buildFeatureBullet('✓ Professional booking page with your branding'),
            _buildFeatureBullet('✓ Detailed analytics for premium users'),
            const Divider(height: 40),

            // Getting Started
            _buildSectionHeader('Getting Started'),
            _buildFaqItem(
              question: 'How do I schedule my first meeting?',
              answer: '1. Sign up for an account\n2. Set your availability in Settings\n3. Share your unique booking link\n4. Guests can book available slots instantly',
            ),
            _buildFaqItem(
              question: 'How do I integrate my calendar?',
              answer: 'Go to Settings > Calendar Integration and connect your Google Calendar. We\'ll automatically sync your availability.',
            ),
            const Divider(height: 40),

            // Common Issues
            _buildSectionHeader('Common Issues'),
            _buildFaqItem(
              question: 'Why can\'t guests see my available times?',
              answer: 'Check your availability settings and ensure you\'ve published your schedule. Also verify your calendar integration is working.',
            ),
            _buildFaqItem(
              question: 'How do I change my default meeting duration?',
              answer: 'Navigate to Settings > Meeting Preferences where you can set default durations from 15 minutes to 3 hours.',
            ),
            const Divider(height: 40),

            // Support Options
            _buildSectionHeader('Need More Help?'),
            _buildSupportOption(
              icon: Icons.email,
              title: 'Email Support',
              subtitle: 'Typically responds within 2 hours',
              action: 'support@meetsyncpro.com',
            ),
            _buildSupportOption(
              icon: Icons.phone,
              title: 'Phone Support',
              subtitle: 'Available 9AM-5PM (UTC)',
              action: '+1 (800) 555-0199',
            ),
            _buildSupportOption(
              icon: Icons.chat,
              title: 'Live Chat',
              subtitle: 'Click to start chatting now',
              action: 'Start Chat',
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
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

  Widget _buildFeatureBullet(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 3, right: 8),
            child: Icon(Icons.circle, size: 8, color: Colors.blue),
          ),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }

  Widget _buildFaqItem({required String question, required String answer}) {
    return ExpansionTile(
      title: Text(question, style: const TextStyle(fontWeight: FontWeight.w500)),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 16, 16),
          child: Text(answer),
        ),
      ],
    );
  }

  Widget _buildSupportOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required String action,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Icon(icon, color: Colors.blue),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: Text(action, style: const TextStyle(color: Colors.blue)),
        onTap: () {
          // Implement contact action
        },
      ),
    );
  }
}