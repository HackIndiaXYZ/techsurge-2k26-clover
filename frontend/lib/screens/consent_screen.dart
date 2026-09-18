import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';

class ConsentScreen extends StatelessWidget {
  const ConsentScreen({super.key});

  // Simulated / illustrative institution names — NOT real institutions
  static const String _fipName = 'Sahyadri Gramin Co-op Bank [Simulated — illustrative only]';
  static const String _aaName = 'Setu-AA Gateway [Simulated — illustrative only]';
  static const String _purpose =
      'Credify will access 24 months of transaction history '
      'to compute an alternative credit-worthiness signal '
      'for lender evaluation only. No data is shared with '
      'third parties outside this session.';
  static const String _dateRange = 'March 2023 – February 2025 (24 months)';

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, state, _) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Account Aggregator Consent',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'Inter',
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Simulated AA flow — illustrative only',
                style: TextStyle(
                  color: Color(0xFF6B7280),
                  fontSize: 12,
                  fontFamily: 'Inter',
                ),
              ),
              const SizedBox(height: 20),

              // Profile selector
              _SectionCard(
                title: 'Select Borrower Profile',
                icon: Icons.person_outline,
                child: DropdownButtonFormField<String>(
                  initialValue: state.selectedProfileId,
                  dropdownColor: const Color(0xFF1A1D2E),
                  style: const TextStyle(
                    color: Color(0xFFE5E7EB),
                    fontFamily: 'Inter',
                    fontSize: 14,
                  ),
                  decoration: InputDecoration(
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFF2D3148)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFF6366F1)),
                    ),
                    filled: true,
                    fillColor: const Color(0xFF12141F),
                  ),
                  items: state.availableProfileIds.map((id) {
                    return DropdownMenuItem(
                      value: id,
                      child: Text(id),
                    );
                  }).toList(),
                  onChanged: state.consentApproved
                      ? null
                      : (val) {
                          if (val != null) state.selectProfile(val);
                        },
                ),
              ),
              const SizedBox(height: 14),

              // Consent card
              _SectionCard(
                title: 'Consent Request Details',
                icon: Icons.assignment_outlined,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _ConsentRow(label: 'Financial Information Provider', value: _fipName),
                    const SizedBox(height: 10),
                    _ConsentRow(label: 'Account Aggregator', value: _aaName),
                    const SizedBox(height: 10),
                    _ConsentRow(label: 'Data Range Requested', value: _dateRange),
                    const SizedBox(height: 10),
                    _ConsentRow(label: 'Purpose', value: _purpose),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F1521),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF1E3A5F), width: 1),
                      ),
                      child: const Text(
                        '⚠ This is a simulated Account Aggregator flow. '
                        'The institution names above are entirely fictitious and '
                        'used for demonstration purposes only.',
                        style: TextStyle(
                          color: Color(0xFF60A5FA),
                          fontSize: 11,
                          height: 1.5,
                          fontFamily: 'Inter',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Consent action
              if (!state.consentApproved)
                SizedBox(
                  width: double.infinity,
                  child: state.consentLoading
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            child: Column(
                              children: [
                                CircularProgressIndicator(color: Color(0xFF10B981)),
                                SizedBox(height: 12),
                                Text(
                                  'Establishing secure data flow…',
                                  style: TextStyle(
                                    color: Color(0xFF9CA3AF),
                                    fontSize: 13,
                                    fontFamily: 'Inter',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : ElevatedButton.icon(
                          onPressed: () => state.approveConsent(),
                          icon: const Icon(Icons.verified_user_outlined),
                          label: const Text('Approve Consent & Share Data'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF10B981),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            textStyle: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              fontFamily: 'Inter',
                            ),
                          ),
                        ),
                )
              else
                _ConsentGrantedBadge(
                  profileId: state.selectedProfileId,
                  onRevoke: () => state.revokeConsent(),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;

  const _SectionCard({
    required this.title,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1D2E),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF2D3148), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFF6366F1), size: 18),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  color: Color(0xFFE5E7EB),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Inter',
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _ConsentRow extends StatelessWidget {
  final String label;
  final String value;

  const _ConsentRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF6B7280),
            fontSize: 11,
            fontFamily: 'Inter',
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: const TextStyle(
            color: Color(0xFFD1D5DB),
            fontSize: 13,
            height: 1.4,
            fontFamily: 'Inter',
          ),
        ),
      ],
    );
  }
}

class _ConsentGrantedBadge extends StatelessWidget {
  final String profileId;
  final VoidCallback onRevoke;

  const _ConsentGrantedBadge({
    required this.profileId,
    required this.onRevoke,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0D2618),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF10B981), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.check_circle_outline, color: Color(0xFF10B981), size: 22),
              SizedBox(width: 10),
              Text(
                'Consent Granted',
                style: TextStyle(
                  color: Color(0xFF10B981),
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'Inter',
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Data for profile "$profileId" is now available for lender assessment. '
            'Navigate to the Lender tab to run the Credify check.',
            style: const TextStyle(
              color: Color(0xFF9CA3AF),
              fontSize: 13,
              height: 1.5,
              fontFamily: 'Inter',
            ),
          ),
          const SizedBox(height: 14),
          TextButton.icon(
            onPressed: onRevoke,
            icon: const Icon(Icons.cancel_outlined, size: 16),
            label: const Text('Revoke Consent'),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFEF4444),
              padding: EdgeInsets.zero,
            ),
          ),
        ],
      ),
    );
  }
}
