import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class LegalPageScaffold extends StatelessWidget {
  final String title;
  final Widget child;
  final BuildContext parentContext;

  const LegalPageScaffold({
    Key? key,
    required this.title,
    required this.child,
    required this.parentContext,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Breadcrumb navigation
            GestureDetector(
              onTap: () => Navigator.pop(parentContext),
              child: Row(
                children: const [
                  Icon(Icons.home, size: 16),
                  SizedBox(width: 4),
                  Text('Back to App'),
                ],
              ),
            ),
            const SizedBox(height: 24),
            child,
          ],
        ),
      ),
    );
  }
}

class PrivacyPolicyPage extends StatelessWidget {
  final BuildContext parentContext;

  const PrivacyPolicyPage({Key? key, required this.parentContext}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return LegalPageScaffold(
      title: 'Privacy Policy',
      parentContext: parentContext,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'MeetSync Pro Privacy Policy',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Last Updated: ${DateFormat('MMMM d, y').format(DateTime.now())}',
            style: const TextStyle(
              fontSize: 14,
              color: Colors.red,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            '1. Information We Collect',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'We collect information you provide directly when you register for an account, including:\n'
            '- Name and contact information\n'
            '- Professional details\n'
            '- Calendar and scheduling preferences\n'
            '- Payment information (processed securely by Stripe)',
          ),
          SizedBox(height: 24),
          Text(
            '2. How We Use Your Information',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'We use the information we collect to:\n'
            '- Provide and improve our services\n'
            '- Process transactions and send notifications\n'
            '- Personalize your experience\n'
            '- Communicate with you about your account\n'
            '- Comply with legal obligations',
          ),
          SizedBox(height: 24),
          Text(
            '3. Data Security',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'We implement industry-standard security measures including:\n'
            '- End-to-end encryption\n'
            '- Secure authentication protocols\n'
            '- Regular security audits\n'
            '- GDPR-compliant data practices',
          ),
          SizedBox(height: 24),
          Text(
            '4. Third-Party Services',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'We integrate with third-party services including:\n'
            '- Google Calendar\n'
            '- Microsoft Teams\n'
            '- Stripe for payments\n'
            '- Twilio for notifications\n'
            'These services have their own privacy policies which we recommend reviewing.',
          ),
          SizedBox(height: 24),
          Text(
            '5. Your Rights',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'You have the right to:\n'
            '- Access your personal data\n'
            '- Request correction or deletion\n'
            '- Object to processing\n'
            '- Request data portability\n'
            '- Withdraw consent\n\n'
            'To exercise these rights, contact us at privacy@meetsyncpro.com',
          ),
          SizedBox(height: 24),
          Text(
            '6. Changes to This Policy',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'We may update this policy periodically. We will notify you of significant changes through the app or via email.',
          ),
        ],
      ),
    );
  }
}

class TermsAndConditionsPage extends StatelessWidget {
  final BuildContext parentContext;

  const TermsAndConditionsPage({Key? key, required this.parentContext}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return LegalPageScaffold(
      title: 'Terms & Conditions',
      parentContext: parentContext,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'MeetSync Pro Terms of Service',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Last Updated: ${DateFormat('MMMM d, y').format(DateTime.now())}',
            style: const TextStyle(
              fontSize: 14,
              color: Colors.red,
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(height: 24),
          Text(
            '1. Acceptance of Terms',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'By accessing or using MeetSync Pro, you agree to be bound by these Terms. If you disagree, you may not use our services.',
          ),
          SizedBox(height: 24),
          Text(
            '2. Account Registration',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'You must:\n'
            '- Provide accurate registration information\n'
            '- Maintain confidentiality of your credentials\n'
            '- Be at least 18 years old\n'
            '- Not create multiple accounts without permission',
          ),
          SizedBox(height: 24),
          Text(
            '3. Subscription and Payments',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
          Text(
            '- Free trial automatically converts to paid subscription unless canceled\n'
            '- Payments are non-refundable\n'
            '- We may change pricing with 30 days notice\n'
            '- You are responsible for any taxes',
          ),
          SizedBox(height: 24),
          Text(
            '4. User Conduct',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'You agree not to:\n'
            '- Use the service for illegal purposes\n'
            '- Harass other users\n'
            '- Attempt to disrupt our systems\n'
            '- Share content that violates others\' rights\n'
            '- Use bots or automated systems without permission',
          ),
          SizedBox(height: 24),
          Text(
            '5. Intellectual Property',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'All rights in the MeetSync Pro platform remain our property. You may not:\n'
            '- Reverse engineer our software\n'
            '- Use our branding without permission\n'
            '- Resell or redistribute our services',
          ),
          SizedBox(height: 24),
          Text(
            '6. Limitation of Liability',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'We are not liable for:\n'
            '- Indirect or consequential damages\n'
            '- Meeting scheduling errors\n'
            '- Third-party service interruptions\n'
            '- Unauthorized account access due to your negligence',
          ),
          SizedBox(height: 24),
          Text(
            '7. Termination',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'We may terminate accounts that violate these Terms. You may cancel your subscription at any time.',
          ),
          SizedBox(height: 24),
          Text(
            '8. Governing Law',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'These Terms are governed by the laws of [Your Jurisdiction]. Disputes will be resolved in [Your Jurisdiction] courts.',
          ),
        ],
      ),
    );
  }
}