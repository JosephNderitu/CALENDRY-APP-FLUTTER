import 'package:flutter/material.dart';

class MeetingSchedulePage extends StatelessWidget {
  const MeetingSchedulePage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: Colors.grey[700], size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Schedule Meeting',
          style: TextStyle(
            color: Colors.grey[800],
            fontSize: 18,
            fontWeight: FontWeight.w500,
          ),
        ),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Text(
              'Choose Platform',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w600,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Select your preferred video conferencing platform',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
                height: 1.4,
              ),
            ),
            
            const SizedBox(height: 32),
            
            // Platform Options
            _buildPlatformOption(
              context: context,
              title: 'Microsoft Teams',
              subtitle: 'Enterprise meetings & collaboration',
              icon: Icons.groups,
              color: const Color(0xFF6264A7),
              onTap: () => _selectPlatform(context, 'teams'),
            ),
            
            const SizedBox(height: 16),
            
            _buildPlatformOption(
              context: context,
              title: 'Google Meet',
              subtitle: 'Simple & secure video meetings',
              icon: Icons.videocam,
              color: const Color(0xFF34A853),
              onTap: () => _selectPlatform(context, 'meet'),
            ),
            
            const SizedBox(height: 16),
            
            _buildPlatformOption(
              context: context,
              title: 'Zoom',
              subtitle: 'Popular video conferencing',
              icon: Icons.video_camera_front,
              color: const Color(0xFF2D8CFF),
              onTap: () => _selectPlatform(context, 'zoom'),
            ),
            
            const Spacer(),
            
            // Bottom note
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue[100]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue[600], size: 18),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'All platforms support instant meeting creation',
                      style: TextStyle(
                        color: Colors.blue[700],
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlatformOption({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 22),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[800],
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  color: Colors.grey[400],
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _selectPlatform(BuildContext context, String platform) {
    // Show subtle feedback
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${_getPlatformName(platform)} selected'),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
    
    // TODO: Navigate to meeting creation flow
    // Navigator.pushNamed(context, '/create-meeting', arguments: platform);
  }

  String _getPlatformName(String platform) {
    switch (platform) {
      case 'teams':
        return 'Microsoft Teams';
      case 'meet':
        return 'Google Meet';
      case 'zoom':
        return 'Zoom';
      default:
        return 'Platform';
    }
  }
}