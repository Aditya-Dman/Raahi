import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'services/supabase_data_service.dart';
import 'services/supabase_auth_service.dart';
import 'services/blockchain_service.dart';

class DigitalIDScreen extends StatefulWidget {
  const DigitalIDScreen({super.key});

  @override
  State<DigitalIDScreen> createState() => _DigitalIDScreenState();
}

class _DigitalIDScreenState extends State<DigitalIDScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _digitalIDData;
  Map<String, dynamic>? _blockchainStats;

  @override
  void initState() {
    super.initState();
    _loadDigitalID();
  }

  Future<void> _loadDigitalID() async {
    try {
      print('Loading digital ID...');
      final authService = SupabaseAuthService();
      final currentUser = await authService.getCurrentUser();
      print('Current user: ${currentUser?.id}');

      if (currentUser != null) {
        final dataService = SupabaseDataService();

        // Try to get digital ID from blockchain table first
        try {
          print('Checking for existing digital ID...');
          final digitalIDData = await dataService.getDigitalID(currentUser.id);
          if (digitalIDData != null) {
            print('Found existing digital ID');
            final blockchainService = BlockchainService();
            final blockchainStats = blockchainService.getNetworkStats();

            setState(() {
              _digitalIDData = digitalIDData;
              _blockchainStats = blockchainStats;
              _isLoading = false;
            });
            return;
          } else {
            print('No existing digital ID found');
          }
        } catch (e) {
          print('Digital ID table not available yet: $e');
        }

        // Fallback: check if user has completed KYC
        print('Checking KYC data...');
        final kycData = await dataService.getKYCData(currentUser.id);
        print('KYC data found: ${kycData != null}');

        if (kycData != null) {
          print('Generating demo digital ID...');
          // Generate demo digital ID for presentation
          final blockchainService = BlockchainService();
          final demoDigitalID = blockchainService.createDigitalIDRecord(
            userId: currentUser.id,
            kycData: kycData,
            status: kycData['status'] ?? 'pending',
          );
          final blockchainStats = blockchainService.getNetworkStats();

          setState(() {
            _digitalIDData = {...kycData, ...demoDigitalID};
            _blockchainStats = blockchainStats;
            _isLoading = false;
          });
          print('Digital ID loaded successfully');
        } else {
          print('No KYC data found, showing no ID view');
          setState(() {
            _isLoading = false;
          });
        }
      } else {
        // No current user found
        print('No current user found');
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading digital ID: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label copied to clipboard'),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Digital Tourist ID'),
        backgroundColor: const Color(0xFFD2B48C),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _digitalIDData == null
          ? _buildNoIDView()
          : _buildDigitalIDView(),
    );
  }

  Widget _buildNoIDView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.credit_card_off, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No Digital ID Found',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Complete your KYC verification to get your blockchain-based digital tourist ID',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildDigitalIDView() {
    final status = _digitalIDData!['status'] ?? 'pending';
    final isVerified = status == 'verified';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Digital ID Card
          _buildDigitalIDCard(),
          const SizedBox(height: 20),

          // Blockchain Information
          _buildBlockchainInfo(),
          const SizedBox(height: 20),

          // Network Status
          _buildNetworkStatus(),
          const SizedBox(height: 20),

          // Verification Details
          if (isVerified) _buildVerificationDetails(),
        ],
      ),
    );
  }

  Widget _buildDigitalIDCard() {
    final status = _digitalIDData!['status'] ?? 'pending';
    final isVerified = status == 'verified';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isVerified
              ? [const Color(0xFF10B981), const Color(0xFF059669)]
              : [const Color(0xFFFFB74D), const Color(0xFFFF9800)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color:
                (isVerified ? const Color(0xFF10B981) : const Color(0xFFFFB74D))
                    .withOpacity(0.3),
            blurRadius: 15,
            spreadRadius: 2,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'DIGITAL TOURIST ID',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isVerified ? Icons.verified : Icons.pending,
                      color: Colors.white,
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      status.toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Name
          Text(
            '${_digitalIDData!['first_name']} ${_digitalIDData!['last_name']}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),

          // Nationality
          Text(
            'Nationality: ${_digitalIDData!['nationality']}',
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 16),

          // Digital ID Hash
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white.withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Blockchain ID Hash',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                GestureDetector(
                  onTap: () => _copyToClipboard(
                    _digitalIDData!['digital_id_hash'] ?? 'N/A',
                    'Digital ID Hash',
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _digitalIDData!['digital_id_hash'] ?? 'N/A',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontFamily: 'monospace',
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const Icon(Icons.copy, color: Colors.white70, size: 16),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Network Info
          Row(
            children: [
              Expanded(
                child: _buildInfoChip(
                  'Network',
                  _digitalIDData!['blockchain_network'] ?? 'Raahi-Chain',
                  Icons.hub,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildInfoChip(
                  'Block',
                  '#${_digitalIDData!['block_number'] ?? 'N/A'}',
                  Icons.view_in_ar_outlined,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        children: [
          Icon(icon, color: Colors.white70, size: 16),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 10),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildBlockchainInfo() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.link, color: Color(0xFFD2B48C)),
                SizedBox(width: 8),
                Text(
                  'Blockchain Details',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),

            _buildDetailRow(
              'Transaction ID',
              _digitalIDData!['blockchain_txn_id'] ?? 'N/A',
              copyable: true,
            ),
            _buildDetailRow(
              'Smart Contract',
              _digitalIDData!['smart_contract_address'] ?? 'N/A',
              copyable: true,
            ),
            _buildDetailRow(
              'Created At',
              _formatDateTime(_digitalIDData!['submitted_at']),
            ),
            _buildDetailRow(
              'Last Updated',
              _formatDateTime(_digitalIDData!['updated_at']),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNetworkStatus() {
    if (_blockchainStats == null) return const SizedBox();

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.network_check, color: Color(0xFF10B981)),
                SizedBox(width: 8),
                Text(
                  'Network Status',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Spacer(),
                Icon(Icons.circle, color: Color(0xFF10B981), size: 12),
                SizedBox(width: 4),
                Text(
                  'ONLINE',
                  style: TextStyle(
                    color: Color(0xFF10B981),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    'Total Blocks',
                    _blockchainStats!['total_blocks'].toString(),
                    Icons.view_in_ar_outlined,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    'Active Nodes',
                    _blockchainStats!['active_nodes'].toString(),
                    Icons.hub,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    'Digital IDs',
                    _blockchainStats!['total_digital_ids'].toString(),
                    Icons.credit_card,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    'Block Time',
                    _blockchainStats!['avg_block_time'],
                    Icons.timer,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFD2B48C).withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFD2B48C).withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: const Color(0xFFD2B48C), size: 20),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          Text(
            label,
            style: TextStyle(fontSize: 10, color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildVerificationDetails() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.verified_user, color: Color(0xFF10B981)),
                SizedBox(width: 8),
                Text(
                  'Verification Status',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: const Color(0xFF10B981).withOpacity(0.3),
                ),
              ),
              child: const Row(
                children: [
                  Icon(Icons.check_circle, color: Color(0xFF10B981)),
                  SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Identity Verified',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF10B981),
                          ),
                        ),
                        Text(
                          'Your digital tourist ID has been verified on the blockchain',
                          style: TextStyle(fontSize: 12),
                        ),
                      ],
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

  Widget _buildDetailRow(String label, String value, {bool copyable = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: copyable ? () => _copyToClipboard(value, label) : null,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      value,
                      style: TextStyle(
                        fontSize: 12,
                        fontFamily: copyable ? 'monospace' : null,
                      ),
                    ),
                  ),
                  if (copyable) ...[
                    const SizedBox(width: 4),
                    Icon(Icons.copy, size: 14, color: Colors.grey[500]),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(String? dateTimeStr) {
    if (dateTimeStr == null) return 'N/A';
    try {
      final dateTime = DateTime.parse(dateTimeStr);
      return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return 'Invalid date';
    }
  }
}
