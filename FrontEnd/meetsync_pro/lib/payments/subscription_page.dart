import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SubscriptionPage extends StatefulWidget {
  const SubscriptionPage({super.key});

  @override
  State<SubscriptionPage> createState() => _SubscriptionPageState();
}

class _SubscriptionPageState extends State<SubscriptionPage> {
  final user = FirebaseAuth.instance.currentUser;
  String? selectedPaymentMethod;
  String? selectedPlan;
  bool isLoading = false;
  bool hasActiveSubscription = false;
  bool isTrialPeriod = false;
  DateTime? subscriptionEndDate;
  DateTime? trialEndDate;
  Duration remainingTime = Duration.zero;
  Duration remainingTrialTime = Duration.zero;
  late Timer timer;

  final List<Map<String, dynamic>> subscriptionPlans = [
    {
      'name': 'Monthly',
      'price': '\$9.99',
      'duration': 'per month',
      'value': 'monthly',
      'features': [
        'Unlimited bookings',
        'Basic analytics',
        'Email support',
        '1 calendar integration'
      ],
      'popular': false,
    },
    {
      'name': 'Professional',
      'price': '\$24.99',
      'duration': 'per quarter',
      'value': 'quarterly',
      'features': [
        'All Monthly features',
        'Priority support',
        '3 calendar integrations',
        'Advanced analytics',
        'Save 15%'
      ],
      'popular': true,
    },
    {
      'name': 'Enterprise',
      'price': '\$89.99',
      'duration': 'per year',
      'value': 'yearly',
      'features': [
        'All Professional features',
        'Unlimited integrations',
        'Dedicated account manager',
        'Save 25%'
      ],
      'popular': false,
    },
  ];

  final List<Map<String, dynamic>> paymentMethods = [
    {
      'name': 'Credit/Debit Card',
      'value': 'stripe',
      'icon': Icons.credit_card,
      'color': Colors.blue,
    },
    {
      'name': 'PayPal',
      'value': 'paypal',
      'icon': Icons.payment,
      'color': Colors.blue[800],
    },
  ];

  @override
  void initState() {
    super.initState();
    _checkSubscriptionStatus();
    timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _updateTimers();
    });
  }

  void _updateTimers() {
    setState(() {
      if (subscriptionEndDate != null) {
        remainingTime = subscriptionEndDate!.difference(DateTime.now());
        if (remainingTime.isNegative) {
          remainingTime = Duration.zero;
          hasActiveSubscription = false;
        }
      }
      
      if (trialEndDate != null) {
        remainingTrialTime = trialEndDate!.difference(DateTime.now());
        if (remainingTrialTime.isNegative) {
          remainingTrialTime = Duration.zero;
          isTrialPeriod = false;
        }
      }
    });
  }

  @override
  void dispose() {
    timer.cancel();
    super.dispose();
  }

  Future<void> _checkSubscriptionStatus() async {
    if (user == null) return;

    // Check account creation date for trial period
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user!.uid)
        .get();
        
    if (userDoc.exists) {
      final createdAt = (userDoc.data()?['createdAt'] as Timestamp?)?.toDate();
      if (createdAt != null) {
        final trialEnd = createdAt.add(const Duration(days: 30));
        setState(() {
          trialEndDate = trialEnd;
          isTrialPeriod = DateTime.now().isBefore(trialEnd);
          remainingTrialTime = trialEnd.difference(DateTime.now());
        });
      }
    }

    // Check active subscription
    final subDoc = await FirebaseFirestore.instance
        .collection('subscriptions')
        .doc(user!.uid)
        .get();

    if (subDoc.exists && subDoc.data()?['status'] == 'active') {
      final endDate = (subDoc.data()?['endDate'] as Timestamp).toDate();
      setState(() {
        hasActiveSubscription = DateTime.now().isBefore(endDate);
        subscriptionEndDate = endDate;
        remainingTime = endDate.difference(DateTime.now());
      });
    }
  }

  Future<void> _processPayment() async {
    if (hasActiveSubscription) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You already have an active subscription'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (selectedPlan == null || selectedPaymentMethod == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a plan and payment method'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      // Simulate payment processing
      await Future.delayed(const Duration(seconds: 2));

      await _saveSubscription();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Payment processed successfully!'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.green,
        ),
      );
      await _checkSubscriptionStatus();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Payment failed: ${e.toString()}'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  DateTime _calculateEndDate() {
    final now = DateTime.now();
    switch (selectedPlan) {
      case 'monthly':
        return now.add(const Duration(days: 30));
      case 'quarterly':
        return now.add(const Duration(days: 90));
      case 'yearly':
        return now.add(const Duration(days: 365));
      default:
        return now.add(const Duration(days: 30));
    }
  }

  Future<void> _saveSubscription() async {
    await FirebaseFirestore.instance.collection('subscriptions').doc(user!.uid).set({
      'plan': selectedPlan,
      'paymentMethod': selectedPaymentMethod,
      'status': 'active',
      'startDate': FieldValue.serverTimestamp(),
      'endDate': _calculateEndDate(),
      'lastPayment': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Widget _buildPlanCard(Map<String, dynamic> plan) {
    final isSelected = selectedPlan == plan['value'];
    return Card(
      elevation: 4,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isSelected ? Theme.of(context).primaryColor : Colors.grey[300]!,
          width: isSelected ? 2 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: hasActiveSubscription
            ? null
            : () => setState(() => selectedPlan = plan['value']),
        child: Opacity(
          opacity: hasActiveSubscription ? 0.6 : 1.0,
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (plan['popular'] == true)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Theme.of(context).primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'MOST POPULAR',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).primaryColor,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    if (plan['popular'] == true) const SizedBox(height: 8),
                    Text(
                      plan['name'],
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: isSelected ? Theme.of(context).primaryColor : Colors.black,
                      ),
                    ),
                    const SizedBox(height: 8),
                    RichText(
                      text: TextSpan(
                        text: plan['price'],
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                        children: [
                          TextSpan(
                            text: ' ${plan['duration']}',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.normal,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Divider(height: 1),
                    const SizedBox(height: 16),
                    ...plan['features'].map<Widget>((feature) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          Icon(Icons.check_circle, color: Colors.green[400], size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              feature,
                              style: const TextStyle(fontSize: 14),
                            ),
                          ),
                        ],
                      ),
                    )).toList(),
                    const SizedBox(height: 16),
                    if (isSelected)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: Theme.of(context).primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Icon(
                            Icons.check_circle,
                            color: Theme.of(context).primaryColor,
                            size: 24,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if (hasActiveSubscription)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: Colors.black.withOpacity(0.1),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentMethodTile(Map<String, dynamic> method) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: selectedPaymentMethod == method['value']
              ? Theme.of(context).primaryColor
              : Colors.grey[300]!,
          width: selectedPaymentMethod == method['value'] ? 2 : 1,
        ),
      ),
      child: Opacity(
        opacity: hasActiveSubscription ? 0.6 : 1.0,
        child: ListTile(
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: method['color'].withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              method['icon'],
              color: method['color'],
              size: 24,
            ),
          ),
          title: Text(
            method['name'],
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          trailing: Radio<String>(
            value: method['value'],
            groupValue: selectedPaymentMethod,
            onChanged: hasActiveSubscription
                ? null
                : (value) => setState(() => selectedPaymentMethod = value),
            activeColor: Theme.of(context).primaryColor,
          ),
          onTap: hasActiveSubscription
              ? null
              : () => setState(() => selectedPaymentMethod = method['value']),
        ),
      ),
    );
  }

  Widget _buildSubscriptionTimer() {
    final days = remainingTime.inDays;
    final hours = remainingTime.inHours.remainder(24);
    final minutes = remainingTime.inMinutes.remainder(60);
    final seconds = remainingTime.inSeconds.remainder(60);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Active Subscription',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Your current subscription is active. You can renew after it expires.',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildTimeUnit(days.toString(), 'Days'),
              _buildTimeUnit(hours.toString().padLeft(2, '0'), 'Hours'),
              _buildTimeUnit(minutes.toString().padLeft(2, '0'), 'Minutes'),
              _buildTimeUnit(seconds.toString().padLeft(2, '0'), 'Seconds'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTrialTimer() {
    final days = remainingTrialTime.inDays;
    final hours = remainingTrialTime.inHours.remainder(24);
    final minutes = remainingTrialTime.inMinutes.remainder(60);
    final seconds = remainingTrialTime.inSeconds.remainder(60);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Free Trial Period',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.blue,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'You are currently in your 30-day free trial period. Subscribe anytime during the trial.',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildTimeUnit(days.toString(), 'Days', Colors.blue),
              _buildTimeUnit(hours.toString().padLeft(2, '0'), 'Hours', Colors.blue),
              _buildTimeUnit(minutes.toString().padLeft(2, '0'), 'Minutes', Colors.blue),
              _buildTimeUnit(seconds.toString().padLeft(2, '0'), 'Seconds', Colors.blue),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTimeUnit(String value, String label, [Color? color]) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: color ?? Theme.of(context).primaryColor,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Upgrade Your Plan'),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (hasActiveSubscription) ...[
              _buildSubscriptionTimer(),
              const SizedBox(height: 24),
            ] else if (isTrialPeriod) ...[
              _buildTrialTimer(),
              const SizedBox(height: 24),
            ],
            const Text(
              'Choose Your Plan',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Select the plan that works best for you',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 24),
            ...subscriptionPlans.map((plan) => _buildPlanCard(plan)),
            const SizedBox(height: 32),
            const Text(
              'Payment Method',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'How would you like to pay?',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 16),
            ...paymentMethods.map((method) => _buildPaymentMethodTile(method)),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: isLoading
                    ? null
                    : hasActiveSubscription
                        ? () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                    'You already have an active subscription'),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        : _processPayment,
                style: ElevatedButton.styleFrom(
                  backgroundColor: hasActiveSubscription
                      ? Colors.grey
                      : Theme.of(context).primaryColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 0,
                ),
                child: isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Text(
                        hasActiveSubscription
                            ? 'Subscription Active'
                            : isTrialPeriod
                                ? 'Subscribe Now (Trial Active)'
                                : 'Continue with Payment',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 16),
            const Center(
              child: Text(
                'Secure payment processing',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.lock, size: 14, color: Colors.grey),
                  SizedBox(width: 4),
                  Text(
                    '256-bit SSL encryption',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
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
}