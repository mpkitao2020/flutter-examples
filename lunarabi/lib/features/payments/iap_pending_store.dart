import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

enum IapPendingStatus {
  waiting('waiting'),
  timedOut('timed_out');

  const IapPendingStatus(this.wireName);

  final String wireName;

  static IapPendingStatus parse(String? value) {
    return IapPendingStatus.values.firstWhere(
      (status) => status.wireName == value,
      orElse: () => IapPendingStatus.waiting,
    );
  }
}

class IapPendingRecord {
  const IapPendingRecord({
    required this.purchaseKey,
    required this.purchaseId,
    required this.productId,
    required this.platform,
    required this.verificationData,
    required this.waitingConfirm,
    required this.updatedAt,
    this.status = IapPendingStatus.waiting,
  });

  final String purchaseKey;
  final String? purchaseId;
  final String productId;
  final String platform;
  final String verificationData;
  final bool waitingConfirm;
  final DateTime updatedAt;
  final IapPendingStatus status;

  static String purchaseKeyFor({
    required String? purchaseId,
    required String platform,
    required String productId,
    required String verificationData,
  }) {
    return purchaseId ?? '$platform:$productId:$verificationData';
  }

  IapPendingRecord copyWith({
    bool? waitingConfirm,
    DateTime? updatedAt,
    IapPendingStatus? status,
  }) {
    return IapPendingRecord(
      purchaseKey: purchaseKey,
      purchaseId: purchaseId,
      productId: productId,
      platform: platform,
      verificationData: verificationData,
      waitingConfirm: waitingConfirm ?? this.waitingConfirm,
      updatedAt: updatedAt ?? this.updatedAt,
      status: status ?? this.status,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'purchaseKey': purchaseKey,
      'purchaseId': purchaseId,
      'productId': productId,
      'platform': platform,
      'verificationData': verificationData,
      'waitingConfirm': waitingConfirm,
      'updatedAt': updatedAt.toIso8601String(),
      'status': status.wireName,
    };
  }

  static IapPendingRecord fromJson(Map<String, dynamic> json) {
    return IapPendingRecord(
      purchaseKey: json['purchaseKey'] as String,
      purchaseId: json['purchaseId'] as String?,
      productId: json['productId'] as String,
      platform: json['platform'] as String,
      verificationData: json['verificationData'] as String,
      waitingConfirm: json['waitingConfirm'] as bool,
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      status: IapPendingStatus.parse(json['status'] as String?),
    );
  }
}

abstract interface class IapPendingStore {
  Future<void> upsert(IapPendingRecord record);
  Future<IapPendingRecord?> getByKey(String purchaseKey);
  Future<List<IapPendingRecord>> allWaiting();
  Future<void> remove(String purchaseKey);
}

class SecureIapPendingStore implements IapPendingStore {
  SecureIapPendingStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const storageKey = 'lunarabi.iap.pending';

  final FlutterSecureStorage _storage;

  @override
  Future<void> upsert(IapPendingRecord record) async {
    final records = await _readAll();
    records[record.purchaseKey] = record;
    await _writeAll(records);
  }

  @override
  Future<IapPendingRecord?> getByKey(String purchaseKey) async {
    return (await _readAll())[purchaseKey];
  }

  @override
  Future<List<IapPendingRecord>> allWaiting() async {
    return (await _readAll()).values
        .where((record) => record.waitingConfirm)
        .toList(growable: false);
  }

  @override
  Future<void> remove(String purchaseKey) async {
    final records = await _readAll();
    records.remove(purchaseKey);
    await _writeAll(records);
  }

  Future<Map<String, IapPendingRecord>> _readAll() async {
    final raw = await _storage.read(key: storageKey);
    if (raw == null || raw.isEmpty) return <String, IapPendingRecord>{};
    final decoded = jsonDecode(raw);
    if (decoded is! List) return <String, IapPendingRecord>{};
    final records = <String, IapPendingRecord>{};
    for (final item in decoded) {
      if (item is! Map) continue;
      final record = IapPendingRecord.fromJson(Map<String, dynamic>.from(item));
      records[record.purchaseKey] = record;
    }
    return records;
  }

  Future<void> _writeAll(Map<String, IapPendingRecord> records) {
    return _storage.write(
      key: storageKey,
      value: jsonEncode(
        records.values.map((record) => record.toJson()).toList(),
      ),
    );
  }
}
