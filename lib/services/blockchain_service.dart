import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';

class BlockchainService {
  static final BlockchainService _instance = BlockchainService._internal();
  factory BlockchainService() => _instance;
  BlockchainService._internal();

  /// Generate a mock blockchain hash for digital ID
  String generateDigitalIDHash(Map<String, dynamic> kycData) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final dataString = jsonEncode(kycData) + timestamp.toString();
    final bytes = utf8.encode(dataString);
    final hash = sha256.convert(bytes);
    return hash.toString();
  }

  /// Generate a mock transaction ID
  String generateTransactionID() {
    final random = Random();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return 'TXN$timestamp${random.nextInt(9999).toString().padLeft(4, '0')}';
  }

  /// Generate mock block number
  int generateBlockNumber() {
    final random = Random();
    return 750000 + random.nextInt(50000); // Realistic block numbers
  }

  /// Create a digital ID record for blockchain
  Map<String, dynamic> createDigitalIDRecord({
    required String userId,
    required Map<String, dynamic> kycData,
    required String status,
  }) {
    final idHash = generateDigitalIDHash(kycData);
    final txnId = generateTransactionID();
    final blockNumber = generateBlockNumber();
    final timestamp = DateTime.now();

    return {
      'digital_id_hash': idHash,
      'transaction_id': txnId,
      'block_number': blockNumber,
      'user_id': userId,
      'status': status,
      'created_at': timestamp.toIso8601String(),
      'is_verified': status == 'verified',
      'network': 'Raahi-Chain', // Mock blockchain network
      'smart_contract': '0x742d35Cc6642C03dD33b45c7c5D4', // Mock contract
      'gas_fee': '0.00${Random().nextInt(9) + 1}', // Mock gas fee
      'confirmation_count': Random().nextInt(50) + 12, // Mock confirmations
      'metadata': {
        'issuer': 'India Tourism Authority',
        'validity_period': _calculateValidityPeriod(kycData),
        'tourist_category': _determineTouristCategory(kycData),
        'risk_level': 'LOW',
      },
    };
  }

  /// Mock blockchain verification
  Map<String, dynamic> verifyDigitalID(String digitalIDHash) {
    return {
      'is_valid': true,
      'verification_timestamp': DateTime.now().toIso8601String(),
      'block_confirmations': Random().nextInt(100) + 50,
      'network_status': 'ACTIVE',
      'last_updated': DateTime.now()
          .subtract(Duration(minutes: Random().nextInt(60)))
          .toIso8601String(),
    };
  }

  /// Generate QR code data for digital ID
  String generateQRCodeData(Map<String, dynamic> digitalIDRecord) {
    return jsonEncode({
      'id_hash': digitalIDRecord['digital_id_hash'],
      'txn_id': digitalIDRecord['transaction_id'],
      'user_id': digitalIDRecord['user_id'],
      'network': digitalIDRecord['network'],
      'verify_url':
          'https://raahi-chain.gov.in/verify/${digitalIDRecord['digital_id_hash']}',
    });
  }

  /// Calculate validity period based on travel data
  String _calculateValidityPeriod(Map<String, dynamic> kycData) {
    // For demo - show 30 days from now
    final validUntil = DateTime.now().add(const Duration(days: 30));
    return validUntil.toIso8601String();
  }

  /// Determine tourist category
  String _determineTouristCategory(Map<String, dynamic> kycData) {
    final nationality = kycData['nationality']?.toString().toLowerCase() ?? '';
    if (nationality == 'india' || nationality == 'indian') {
      return 'DOMESTIC';
    }
    return 'INTERNATIONAL';
  }

  /// Mock smart contract interaction
  Future<Map<String, dynamic>> deployTouristContract(String userId) async {
    // Simulate network delay
    await Future.delayed(const Duration(seconds: 2));

    return {
      'contract_address': '0x${_generateHexString(40)}',
      'deployment_txn': generateTransactionID(),
      'gas_used': '${21000 + Random().nextInt(50000)}',
      'status': 'SUCCESS',
      'block_number': generateBlockNumber(),
    };
  }

  /// Generate random hex string
  String _generateHexString(int length) {
    const chars = '0123456789abcdef';
    final random = Random();
    return List.generate(
      length,
      (index) => chars[random.nextInt(chars.length)],
    ).join();
  }

  /// Get blockchain network stats (for demo)
  Map<String, dynamic> getNetworkStats() {
    return {
      'network_name': 'Raahi-Chain',
      'total_blocks': generateBlockNumber(),
      'active_nodes': Random().nextInt(500) + 100,
      'total_digital_ids': Random().nextInt(10000) + 5000,
      'avg_block_time': '15 seconds',
      'network_hash_rate': '${Random().nextInt(100) + 50} TH/s',
      'last_block_time': DateTime.now()
          .subtract(Duration(seconds: Random().nextInt(30)))
          .toIso8601String(),
    };
  }
}
