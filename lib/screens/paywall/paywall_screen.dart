import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import '../../config/revenuecat_config.dart';
import '../../config/theme_constants.dart';
import '../../providers/subscription_provider.dart';

class PaywallScreen extends ConsumerStatefulWidget {
  const PaywallScreen({super.key});

  @override
  ConsumerState<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends ConsumerState<PaywallScreen> {
  bool _purchasing = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    final offerings = ref.watch(revenueCatOfferingsProvider);
    final isConfigured = RevenueCatConfig.isConfigured;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Upgrade to Pro'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const Text(
                  'Unlock Full Features',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: AppColors.brandText,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Unlimited tasks, custom themes, templates, image upload, cloud sync & more.',
                  style: TextStyle(
                    fontSize: 16,
                    color: AppColors.brandTextMuted,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(
                      _error!,
                      style: const TextStyle(color: AppColors.brandError),
                    ),
                  ),
                if (isConfigured)
                  offerings.when(
                    loading: () => const CircularProgressIndicator(),
                    error: (_, __) => _buildStaticPricing(),
                    data: (o) => o != null && o.current != null
                        ? _buildRevenueCatOfferings(o.current!)
                        : _buildStaticPricing(),
                  )
                else
                  _buildStaticPricing(),
                const SizedBox(height: 32),
                _buildFeatureComparison(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRevenueCatOfferings(Offering offering) {
    final packages = offering.availablePackages;
    if (packages.isEmpty) return _buildStaticPricing();

    return Wrap(
      spacing: 16,
      runSpacing: 16,
      alignment: WrapAlignment.center,
      children: packages.map((pkg) {
        final product = pkg.storeProduct;
        final isPopular = pkg.packageType == PackageType.annual;
        return _PricingCard(
          title: _packageTitle(pkg.packageType),
          price: product.priceString,
          subtitle: _packageSubtitle(pkg.packageType, product.priceString),
          isPopular: isPopular,
          isLoading: _purchasing,
          onTap: () => _purchase(pkg),
        );
      }).toList(),
    );
  }

  Widget _buildStaticPricing() {
    return Wrap(
      spacing: 16,
      runSpacing: 16,
      alignment: WrapAlignment.center,
      children: [
        _PricingCard(
          title: 'Monthly',
          price: '\u00A34.99',
          subtitle: 'per month',
          isPopular: false,
          isLoading: _purchasing,
          onTap: RevenueCatConfig.isConfigured ? () {} : null,
        ),
        _PricingCard(
          title: 'Annual',
          price: '\u00A334.99',
          subtitle: '\u00A32.92/mo \u2014 save 42%',
          isPopular: true,
          isLoading: _purchasing,
          onTap: RevenueCatConfig.isConfigured ? () {} : null,
        ),
        _PricingCard(
          title: 'Lifetime',
          price: '\u00A389.99',
          subtitle: 'one-time payment',
          isPopular: false,
          isLoading: _purchasing,
          onTap: RevenueCatConfig.isConfigured ? () {} : null,
        ),
      ],
    );
  }

  Widget _buildFeatureComparison() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.brandBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'What you get with Pro',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.brandText,
            ),
          ),
          const SizedBox(height: 16),
          ..._features.map((f) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    Icon(
                      f.freeIncluded ? Icons.check_circle : Icons.lock_open,
                      color: f.freeIncluded
                          ? AppColors.brandSuccess
                          : AppColors.brandPrimary,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        f.label,
                        style: TextStyle(
                          color: AppColors.brandText,
                          fontWeight: f.freeIncluded
                              ? FontWeight.normal
                              : FontWeight.w600,
                        ),
                      ),
                    ),
                    Text(
                      f.freeIncluded ? 'Free + Pro' : 'Pro only',
                      style: TextStyle(
                        fontSize: 12,
                        color: f.freeIncluded
                            ? AppColors.brandTextMuted
                            : AppColors.brandPrimary,
                        fontWeight: f.freeIncluded
                            ? FontWeight.normal
                            : FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Future<void> _purchase(Package package) async {
    if (_purchasing) return;
    setState(() {
      _purchasing = true;
      _error = null;
    });

    try {
      final result = await Purchases.purchasePackage(package);
      final isPro = result
              .entitlements.all[RevenueCatConfig.entitlementId]?.isActive ??
          false;
      if (isPro && mounted) {
        ref.invalidate(subscriptionPlanProvider);
        ref.invalidate(subscriptionProvider);
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Welcome to Pro!')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'Purchase failed. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _purchasing = false);
    }
  }

  String _packageTitle(PackageType type) {
    switch (type) {
      case PackageType.monthly:
        return 'Monthly';
      case PackageType.annual:
        return 'Annual';
      case PackageType.lifetime:
        return 'Lifetime';
      default:
        return type.name;
    }
  }

  String _packageSubtitle(PackageType type, String price) {
    switch (type) {
      case PackageType.monthly:
        return 'per month';
      case PackageType.annual:
        return 'save 42%';
      case PackageType.lifetime:
        return 'one-time payment';
      default:
        return '';
    }
  }
}

final _features = [
  _Feature('3 display modes (horizontal, multi-row, auto-pan)', true),
  _Feature('Preset themes', true),
  _Feature('Up to 5 tasks', true),
  _Feature('Unlimited tasks', false),
  _Feature('Custom themes & colours', false),
  _Feature('Templates & schedules', false),
  _Feature('Image upload for tasks', false),
  _Feature('Cloud sync & backup', false),
  _Feature('Realtime display updates', false),
  _Feature('Multi-classroom support', false),
];

class _Feature {
  final String label;
  final bool freeIncluded;
  const _Feature(this.label, this.freeIncluded);
}

class _PricingCard extends StatelessWidget {
  final String title;
  final String price;
  final String subtitle;
  final bool isPopular;
  final bool isLoading;
  final VoidCallback? onTap;

  const _PricingCard({
    required this.title,
    required this.price,
    required this.subtitle,
    required this.isPopular,
    required this.isLoading,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 240,
      child: Card(
        elevation: isPopular ? 4 : 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: isPopular
              ? const BorderSide(color: AppColors.brandPrimary, width: 2)
              : BorderSide(color: AppColors.brandBorder),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              if (isPopular)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.brandPrimary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'Most Popular',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              if (isPopular) const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.brandText,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                price,
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: AppColors.brandPrimaryDark,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.brandTextMuted,
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: isLoading ? null : onTap,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isPopular
                        ? AppColors.brandPrimary
                        : AppColors.brandBgSubtle,
                    foregroundColor:
                        isPopular ? Colors.white : AppColors.brandPrimaryDark,
                  ),
                  child: isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          onTap != null ? 'Choose Plan' : 'Coming Soon',
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
