// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'db.dart';

// ignore_for_file: type=lint
class $LedgersTable extends Ledgers with TableInfo<$LedgersTable, Ledger> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LedgersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _currencyMeta = const VerificationMeta(
    'currency',
  );
  @override
  late final GeneratedColumn<String> currency = GeneratedColumn<String>(
    'currency',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('CNY'),
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('personal'),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _syncIdMeta = const VerificationMeta('syncId');
  @override
  late final GeneratedColumn<String> syncId = GeneratedColumn<String>(
    'sync_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _myRoleMeta = const VerificationMeta('myRole');
  @override
  late final GeneratedColumn<String> myRole = GeneratedColumn<String>(
    'my_role',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('owner'),
  );
  static const VerificationMeta _memberCountMeta = const VerificationMeta(
    'memberCount',
  );
  @override
  late final GeneratedColumn<int> memberCount = GeneratedColumn<int>(
    'member_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _isSharedMeta = const VerificationMeta(
    'isShared',
  );
  @override
  late final GeneratedColumn<bool> isShared = GeneratedColumn<bool>(
    'is_shared',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_shared" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _ownerUserIdMeta = const VerificationMeta(
    'ownerUserId',
  );
  @override
  late final GeneratedColumn<String> ownerUserId = GeneratedColumn<String>(
    'owner_user_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _monthStartDayMeta = const VerificationMeta(
    'monthStartDay',
  );
  @override
  late final GeneratedColumn<int> monthStartDay = GeneratedColumn<int>(
    'month_start_day',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _storageModeMeta = const VerificationMeta(
    'storageMode',
  );
  @override
  late final GeneratedColumn<String> storageMode = GeneratedColumn<String>(
    'storage_mode',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('local'),
  );
  static const VerificationMeta _aaEnabledMeta = const VerificationMeta(
    'aaEnabled',
  );
  @override
  late final GeneratedColumn<bool> aaEnabled = GeneratedColumn<bool>(
    'aa_enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("aa_enabled" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    currency,
    type,
    createdAt,
    syncId,
    myRole,
    memberCount,
    isShared,
    ownerUserId,
    monthStartDay,
    storageMode,
    aaEnabled,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'ledgers';
  @override
  VerificationContext validateIntegrity(
    Insertable<Ledger> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('currency')) {
      context.handle(
        _currencyMeta,
        currency.isAcceptableOrUnknown(data['currency']!, _currencyMeta),
      );
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('sync_id')) {
      context.handle(
        _syncIdMeta,
        syncId.isAcceptableOrUnknown(data['sync_id']!, _syncIdMeta),
      );
    }
    if (data.containsKey('my_role')) {
      context.handle(
        _myRoleMeta,
        myRole.isAcceptableOrUnknown(data['my_role']!, _myRoleMeta),
      );
    }
    if (data.containsKey('member_count')) {
      context.handle(
        _memberCountMeta,
        memberCount.isAcceptableOrUnknown(
          data['member_count']!,
          _memberCountMeta,
        ),
      );
    }
    if (data.containsKey('is_shared')) {
      context.handle(
        _isSharedMeta,
        isShared.isAcceptableOrUnknown(data['is_shared']!, _isSharedMeta),
      );
    }
    if (data.containsKey('owner_user_id')) {
      context.handle(
        _ownerUserIdMeta,
        ownerUserId.isAcceptableOrUnknown(
          data['owner_user_id']!,
          _ownerUserIdMeta,
        ),
      );
    }
    if (data.containsKey('month_start_day')) {
      context.handle(
        _monthStartDayMeta,
        monthStartDay.isAcceptableOrUnknown(
          data['month_start_day']!,
          _monthStartDayMeta,
        ),
      );
    }
    if (data.containsKey('storage_mode')) {
      context.handle(
        _storageModeMeta,
        storageMode.isAcceptableOrUnknown(
          data['storage_mode']!,
          _storageModeMeta,
        ),
      );
    }
    if (data.containsKey('aa_enabled')) {
      context.handle(
        _aaEnabledMeta,
        aaEnabled.isAcceptableOrUnknown(data['aa_enabled']!, _aaEnabledMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Ledger map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Ledger(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      currency: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}currency'],
      )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      syncId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sync_id'],
      ),
      myRole: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}my_role'],
      )!,
      memberCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}member_count'],
      )!,
      isShared: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_shared'],
      )!,
      ownerUserId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}owner_user_id'],
      ),
      monthStartDay: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}month_start_day'],
      )!,
      storageMode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}storage_mode'],
      )!,
      aaEnabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}aa_enabled'],
      )!,
    );
  }

  @override
  $LedgersTable createAlias(String alias) {
    return $LedgersTable(attachedDatabase, alias);
  }
}

class Ledger extends DataClass implements Insertable<Ledger> {
  final int id;
  final String name;
  final String currency;
  final String type;
  final DateTime createdAt;
  final String? syncId;
  final String myRole;
  final int memberCount;
  final bool isShared;
  final String? ownerUserId;
  final int monthStartDay;

  /// 账本归属(账本级"本地 / 云端"分离,由本字段决定,而非登录状态)。
  /// 'local' = 纯本地账本,永不被被动同步推上云;'cloud' = Spitout Cloud 云端账本,
  /// 走三路被动闸门(fullPush / triggerAutoSync / Phase2)。快照式备份
  /// (supabase/webdav/s3)是整库文件级操作,不属于账本级同步,本地账本一律标 local。
  /// 默认值 'local':新建账本默认本地归属,数据主权零风险。
  final String storageMode;

  /// AA 分摊开关。关闭后入口隐藏、历史数据不展示不参与统计;重开数据仍在。
  /// 必须跨设备同步(随 ledger 同通道下发)。
  final bool aaEnabled;
  const Ledger({
    required this.id,
    required this.name,
    required this.currency,
    required this.type,
    required this.createdAt,
    this.syncId,
    required this.myRole,
    required this.memberCount,
    required this.isShared,
    this.ownerUserId,
    required this.monthStartDay,
    required this.storageMode,
    required this.aaEnabled,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    map['currency'] = Variable<String>(currency);
    map['type'] = Variable<String>(type);
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || syncId != null) {
      map['sync_id'] = Variable<String>(syncId);
    }
    map['my_role'] = Variable<String>(myRole);
    map['member_count'] = Variable<int>(memberCount);
    map['is_shared'] = Variable<bool>(isShared);
    if (!nullToAbsent || ownerUserId != null) {
      map['owner_user_id'] = Variable<String>(ownerUserId);
    }
    map['month_start_day'] = Variable<int>(monthStartDay);
    map['storage_mode'] = Variable<String>(storageMode);
    map['aa_enabled'] = Variable<bool>(aaEnabled);
    return map;
  }

  LedgersCompanion toCompanion(bool nullToAbsent) {
    return LedgersCompanion(
      id: Value(id),
      name: Value(name),
      currency: Value(currency),
      type: Value(type),
      createdAt: Value(createdAt),
      syncId: syncId == null && nullToAbsent
          ? const Value.absent()
          : Value(syncId),
      myRole: Value(myRole),
      memberCount: Value(memberCount),
      isShared: Value(isShared),
      ownerUserId: ownerUserId == null && nullToAbsent
          ? const Value.absent()
          : Value(ownerUserId),
      monthStartDay: Value(monthStartDay),
      storageMode: Value(storageMode),
      aaEnabled: Value(aaEnabled),
    );
  }

  factory Ledger.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Ledger(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      currency: serializer.fromJson<String>(json['currency']),
      type: serializer.fromJson<String>(json['type']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      syncId: serializer.fromJson<String?>(json['syncId']),
      myRole: serializer.fromJson<String>(json['myRole']),
      memberCount: serializer.fromJson<int>(json['memberCount']),
      isShared: serializer.fromJson<bool>(json['isShared']),
      ownerUserId: serializer.fromJson<String?>(json['ownerUserId']),
      monthStartDay: serializer.fromJson<int>(json['monthStartDay']),
      storageMode: serializer.fromJson<String>(json['storageMode']),
      aaEnabled: serializer.fromJson<bool>(json['aaEnabled']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'currency': serializer.toJson<String>(currency),
      'type': serializer.toJson<String>(type),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'syncId': serializer.toJson<String?>(syncId),
      'myRole': serializer.toJson<String>(myRole),
      'memberCount': serializer.toJson<int>(memberCount),
      'isShared': serializer.toJson<bool>(isShared),
      'ownerUserId': serializer.toJson<String?>(ownerUserId),
      'monthStartDay': serializer.toJson<int>(monthStartDay),
      'storageMode': serializer.toJson<String>(storageMode),
      'aaEnabled': serializer.toJson<bool>(aaEnabled),
    };
  }

  Ledger copyWith({
    int? id,
    String? name,
    String? currency,
    String? type,
    DateTime? createdAt,
    Value<String?> syncId = const Value.absent(),
    String? myRole,
    int? memberCount,
    bool? isShared,
    Value<String?> ownerUserId = const Value.absent(),
    int? monthStartDay,
    String? storageMode,
    bool? aaEnabled,
  }) => Ledger(
    id: id ?? this.id,
    name: name ?? this.name,
    currency: currency ?? this.currency,
    type: type ?? this.type,
    createdAt: createdAt ?? this.createdAt,
    syncId: syncId.present ? syncId.value : this.syncId,
    myRole: myRole ?? this.myRole,
    memberCount: memberCount ?? this.memberCount,
    isShared: isShared ?? this.isShared,
    ownerUserId: ownerUserId.present ? ownerUserId.value : this.ownerUserId,
    monthStartDay: monthStartDay ?? this.monthStartDay,
    storageMode: storageMode ?? this.storageMode,
    aaEnabled: aaEnabled ?? this.aaEnabled,
  );
  Ledger copyWithCompanion(LedgersCompanion data) {
    return Ledger(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      currency: data.currency.present ? data.currency.value : this.currency,
      type: data.type.present ? data.type.value : this.type,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      syncId: data.syncId.present ? data.syncId.value : this.syncId,
      myRole: data.myRole.present ? data.myRole.value : this.myRole,
      memberCount: data.memberCount.present
          ? data.memberCount.value
          : this.memberCount,
      isShared: data.isShared.present ? data.isShared.value : this.isShared,
      ownerUserId: data.ownerUserId.present
          ? data.ownerUserId.value
          : this.ownerUserId,
      monthStartDay: data.monthStartDay.present
          ? data.monthStartDay.value
          : this.monthStartDay,
      storageMode: data.storageMode.present
          ? data.storageMode.value
          : this.storageMode,
      aaEnabled: data.aaEnabled.present ? data.aaEnabled.value : this.aaEnabled,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Ledger(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('currency: $currency, ')
          ..write('type: $type, ')
          ..write('createdAt: $createdAt, ')
          ..write('syncId: $syncId, ')
          ..write('myRole: $myRole, ')
          ..write('memberCount: $memberCount, ')
          ..write('isShared: $isShared, ')
          ..write('ownerUserId: $ownerUserId, ')
          ..write('monthStartDay: $monthStartDay, ')
          ..write('storageMode: $storageMode, ')
          ..write('aaEnabled: $aaEnabled')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    currency,
    type,
    createdAt,
    syncId,
    myRole,
    memberCount,
    isShared,
    ownerUserId,
    monthStartDay,
    storageMode,
    aaEnabled,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Ledger &&
          other.id == this.id &&
          other.name == this.name &&
          other.currency == this.currency &&
          other.type == this.type &&
          other.createdAt == this.createdAt &&
          other.syncId == this.syncId &&
          other.myRole == this.myRole &&
          other.memberCount == this.memberCount &&
          other.isShared == this.isShared &&
          other.ownerUserId == this.ownerUserId &&
          other.monthStartDay == this.monthStartDay &&
          other.storageMode == this.storageMode &&
          other.aaEnabled == this.aaEnabled);
}

class LedgersCompanion extends UpdateCompanion<Ledger> {
  final Value<int> id;
  final Value<String> name;
  final Value<String> currency;
  final Value<String> type;
  final Value<DateTime> createdAt;
  final Value<String?> syncId;
  final Value<String> myRole;
  final Value<int> memberCount;
  final Value<bool> isShared;
  final Value<String?> ownerUserId;
  final Value<int> monthStartDay;
  final Value<String> storageMode;
  final Value<bool> aaEnabled;
  const LedgersCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.currency = const Value.absent(),
    this.type = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.syncId = const Value.absent(),
    this.myRole = const Value.absent(),
    this.memberCount = const Value.absent(),
    this.isShared = const Value.absent(),
    this.ownerUserId = const Value.absent(),
    this.monthStartDay = const Value.absent(),
    this.storageMode = const Value.absent(),
    this.aaEnabled = const Value.absent(),
  });
  LedgersCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    this.currency = const Value.absent(),
    this.type = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.syncId = const Value.absent(),
    this.myRole = const Value.absent(),
    this.memberCount = const Value.absent(),
    this.isShared = const Value.absent(),
    this.ownerUserId = const Value.absent(),
    this.monthStartDay = const Value.absent(),
    this.storageMode = const Value.absent(),
    this.aaEnabled = const Value.absent(),
  }) : name = Value(name);
  static Insertable<Ledger> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<String>? currency,
    Expression<String>? type,
    Expression<DateTime>? createdAt,
    Expression<String>? syncId,
    Expression<String>? myRole,
    Expression<int>? memberCount,
    Expression<bool>? isShared,
    Expression<String>? ownerUserId,
    Expression<int>? monthStartDay,
    Expression<String>? storageMode,
    Expression<bool>? aaEnabled,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (currency != null) 'currency': currency,
      if (type != null) 'type': type,
      if (createdAt != null) 'created_at': createdAt,
      if (syncId != null) 'sync_id': syncId,
      if (myRole != null) 'my_role': myRole,
      if (memberCount != null) 'member_count': memberCount,
      if (isShared != null) 'is_shared': isShared,
      if (ownerUserId != null) 'owner_user_id': ownerUserId,
      if (monthStartDay != null) 'month_start_day': monthStartDay,
      if (storageMode != null) 'storage_mode': storageMode,
      if (aaEnabled != null) 'aa_enabled': aaEnabled,
    });
  }

  LedgersCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<String>? currency,
    Value<String>? type,
    Value<DateTime>? createdAt,
    Value<String?>? syncId,
    Value<String>? myRole,
    Value<int>? memberCount,
    Value<bool>? isShared,
    Value<String?>? ownerUserId,
    Value<int>? monthStartDay,
    Value<String>? storageMode,
    Value<bool>? aaEnabled,
  }) {
    return LedgersCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      currency: currency ?? this.currency,
      type: type ?? this.type,
      createdAt: createdAt ?? this.createdAt,
      syncId: syncId ?? this.syncId,
      myRole: myRole ?? this.myRole,
      memberCount: memberCount ?? this.memberCount,
      isShared: isShared ?? this.isShared,
      ownerUserId: ownerUserId ?? this.ownerUserId,
      monthStartDay: monthStartDay ?? this.monthStartDay,
      storageMode: storageMode ?? this.storageMode,
      aaEnabled: aaEnabled ?? this.aaEnabled,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (currency.present) {
      map['currency'] = Variable<String>(currency.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (syncId.present) {
      map['sync_id'] = Variable<String>(syncId.value);
    }
    if (myRole.present) {
      map['my_role'] = Variable<String>(myRole.value);
    }
    if (memberCount.present) {
      map['member_count'] = Variable<int>(memberCount.value);
    }
    if (isShared.present) {
      map['is_shared'] = Variable<bool>(isShared.value);
    }
    if (ownerUserId.present) {
      map['owner_user_id'] = Variable<String>(ownerUserId.value);
    }
    if (monthStartDay.present) {
      map['month_start_day'] = Variable<int>(monthStartDay.value);
    }
    if (storageMode.present) {
      map['storage_mode'] = Variable<String>(storageMode.value);
    }
    if (aaEnabled.present) {
      map['aa_enabled'] = Variable<bool>(aaEnabled.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LedgersCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('currency: $currency, ')
          ..write('type: $type, ')
          ..write('createdAt: $createdAt, ')
          ..write('syncId: $syncId, ')
          ..write('myRole: $myRole, ')
          ..write('memberCount: $memberCount, ')
          ..write('isShared: $isShared, ')
          ..write('ownerUserId: $ownerUserId, ')
          ..write('monthStartDay: $monthStartDay, ')
          ..write('storageMode: $storageMode, ')
          ..write('aaEnabled: $aaEnabled')
          ..write(')'))
        .toString();
  }
}

class $CategoriesTable extends Categories
    with TableInfo<$CategoriesTable, Category> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CategoriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _iconMeta = const VerificationMeta('icon');
  @override
  late final GeneratedColumn<String> icon = GeneratedColumn<String>(
    'icon',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _parentIdMeta = const VerificationMeta(
    'parentId',
  );
  @override
  late final GeneratedColumn<int> parentId = GeneratedColumn<int>(
    'parent_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _levelMeta = const VerificationMeta('level');
  @override
  late final GeneratedColumn<int> level = GeneratedColumn<int>(
    'level',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _syncIdMeta = const VerificationMeta('syncId');
  @override
  late final GeneratedColumn<String> syncId = GeneratedColumn<String>(
    'sync_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    kind,
    icon,
    sortOrder,
    parentId,
    level,
    syncId,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'categories';
  @override
  VerificationContext validateIntegrity(
    Insertable<Category> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('icon')) {
      context.handle(
        _iconMeta,
        icon.isAcceptableOrUnknown(data['icon']!, _iconMeta),
      );
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    }
    if (data.containsKey('parent_id')) {
      context.handle(
        _parentIdMeta,
        parentId.isAcceptableOrUnknown(data['parent_id']!, _parentIdMeta),
      );
    }
    if (data.containsKey('level')) {
      context.handle(
        _levelMeta,
        level.isAcceptableOrUnknown(data['level']!, _levelMeta),
      );
    }
    if (data.containsKey('sync_id')) {
      context.handle(
        _syncIdMeta,
        syncId.isAcceptableOrUnknown(data['sync_id']!, _syncIdMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Category map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Category(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      icon: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}icon'],
      ),
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
      parentId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}parent_id'],
      ),
      level: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}level'],
      )!,
      syncId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sync_id'],
      ),
    );
  }

  @override
  $CategoriesTable createAlias(String alias) {
    return $CategoriesTable(attachedDatabase, alias);
  }
}

class Category extends DataClass implements Insertable<Category> {
  final int id;
  final String name;
  final String kind;
  final String? icon;
  final int sortOrder;
  final int? parentId;
  final int level;
  final String? syncId;
  const Category({
    required this.id,
    required this.name,
    required this.kind,
    this.icon,
    required this.sortOrder,
    this.parentId,
    required this.level,
    this.syncId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    map['kind'] = Variable<String>(kind);
    if (!nullToAbsent || icon != null) {
      map['icon'] = Variable<String>(icon);
    }
    map['sort_order'] = Variable<int>(sortOrder);
    if (!nullToAbsent || parentId != null) {
      map['parent_id'] = Variable<int>(parentId);
    }
    map['level'] = Variable<int>(level);
    if (!nullToAbsent || syncId != null) {
      map['sync_id'] = Variable<String>(syncId);
    }
    return map;
  }

  CategoriesCompanion toCompanion(bool nullToAbsent) {
    return CategoriesCompanion(
      id: Value(id),
      name: Value(name),
      kind: Value(kind),
      icon: icon == null && nullToAbsent ? const Value.absent() : Value(icon),
      sortOrder: Value(sortOrder),
      parentId: parentId == null && nullToAbsent
          ? const Value.absent()
          : Value(parentId),
      level: Value(level),
      syncId: syncId == null && nullToAbsent
          ? const Value.absent()
          : Value(syncId),
    );
  }

  factory Category.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Category(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      kind: serializer.fromJson<String>(json['kind']),
      icon: serializer.fromJson<String?>(json['icon']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      parentId: serializer.fromJson<int?>(json['parentId']),
      level: serializer.fromJson<int>(json['level']),
      syncId: serializer.fromJson<String?>(json['syncId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'kind': serializer.toJson<String>(kind),
      'icon': serializer.toJson<String?>(icon),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'parentId': serializer.toJson<int?>(parentId),
      'level': serializer.toJson<int>(level),
      'syncId': serializer.toJson<String?>(syncId),
    };
  }

  Category copyWith({
    int? id,
    String? name,
    String? kind,
    Value<String?> icon = const Value.absent(),
    int? sortOrder,
    Value<int?> parentId = const Value.absent(),
    int? level,
    Value<String?> syncId = const Value.absent(),
  }) => Category(
    id: id ?? this.id,
    name: name ?? this.name,
    kind: kind ?? this.kind,
    icon: icon.present ? icon.value : this.icon,
    sortOrder: sortOrder ?? this.sortOrder,
    parentId: parentId.present ? parentId.value : this.parentId,
    level: level ?? this.level,
    syncId: syncId.present ? syncId.value : this.syncId,
  );
  Category copyWithCompanion(CategoriesCompanion data) {
    return Category(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      kind: data.kind.present ? data.kind.value : this.kind,
      icon: data.icon.present ? data.icon.value : this.icon,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      parentId: data.parentId.present ? data.parentId.value : this.parentId,
      level: data.level.present ? data.level.value : this.level,
      syncId: data.syncId.present ? data.syncId.value : this.syncId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Category(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('kind: $kind, ')
          ..write('icon: $icon, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('parentId: $parentId, ')
          ..write('level: $level, ')
          ..write('syncId: $syncId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, name, kind, icon, sortOrder, parentId, level, syncId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Category &&
          other.id == this.id &&
          other.name == this.name &&
          other.kind == this.kind &&
          other.icon == this.icon &&
          other.sortOrder == this.sortOrder &&
          other.parentId == this.parentId &&
          other.level == this.level &&
          other.syncId == this.syncId);
}

class CategoriesCompanion extends UpdateCompanion<Category> {
  final Value<int> id;
  final Value<String> name;
  final Value<String> kind;
  final Value<String?> icon;
  final Value<int> sortOrder;
  final Value<int?> parentId;
  final Value<int> level;
  final Value<String?> syncId;
  const CategoriesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.kind = const Value.absent(),
    this.icon = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.parentId = const Value.absent(),
    this.level = const Value.absent(),
    this.syncId = const Value.absent(),
  });
  CategoriesCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    required String kind,
    this.icon = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.parentId = const Value.absent(),
    this.level = const Value.absent(),
    this.syncId = const Value.absent(),
  }) : name = Value(name),
       kind = Value(kind);
  static Insertable<Category> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<String>? kind,
    Expression<String>? icon,
    Expression<int>? sortOrder,
    Expression<int>? parentId,
    Expression<int>? level,
    Expression<String>? syncId,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (kind != null) 'kind': kind,
      if (icon != null) 'icon': icon,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (parentId != null) 'parent_id': parentId,
      if (level != null) 'level': level,
      if (syncId != null) 'sync_id': syncId,
    });
  }

  CategoriesCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<String>? kind,
    Value<String?>? icon,
    Value<int>? sortOrder,
    Value<int?>? parentId,
    Value<int>? level,
    Value<String?>? syncId,
  }) {
    return CategoriesCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      kind: kind ?? this.kind,
      icon: icon ?? this.icon,
      sortOrder: sortOrder ?? this.sortOrder,
      parentId: parentId ?? this.parentId,
      level: level ?? this.level,
      syncId: syncId ?? this.syncId,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (icon.present) {
      map['icon'] = Variable<String>(icon.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (parentId.present) {
      map['parent_id'] = Variable<int>(parentId.value);
    }
    if (level.present) {
      map['level'] = Variable<int>(level.value);
    }
    if (syncId.present) {
      map['sync_id'] = Variable<String>(syncId.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CategoriesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('kind: $kind, ')
          ..write('icon: $icon, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('parentId: $parentId, ')
          ..write('level: $level, ')
          ..write('syncId: $syncId')
          ..write(')'))
        .toString();
  }
}

class $RecurringTransactionsTable extends RecurringTransactions
    with TableInfo<$RecurringTransactionsTable, RecurringTransaction> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RecurringTransactionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _ledgerIdMeta = const VerificationMeta(
    'ledgerId',
  );
  @override
  late final GeneratedColumn<int> ledgerId = GeneratedColumn<int>(
    'ledger_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES ledgers (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _amountMeta = const VerificationMeta('amount');
  @override
  late final GeneratedColumn<int> amount = GeneratedColumn<int>(
    'amount',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _currencyCodeMeta = const VerificationMeta(
    'currencyCode',
  );
  @override
  late final GeneratedColumn<String> currencyCode = GeneratedColumn<String>(
    'currency_code',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _categoryIdMeta = const VerificationMeta(
    'categoryId',
  );
  @override
  late final GeneratedColumn<int> categoryId = GeneratedColumn<int>(
    'category_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _frequencyMeta = const VerificationMeta(
    'frequency',
  );
  @override
  late final GeneratedColumn<String> frequency = GeneratedColumn<String>(
    'frequency',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _intervalMeta = const VerificationMeta(
    'interval',
  );
  @override
  late final GeneratedColumn<int> interval = GeneratedColumn<int>(
    'interval',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _dayOfMonthMeta = const VerificationMeta(
    'dayOfMonth',
  );
  @override
  late final GeneratedColumn<int> dayOfMonth = GeneratedColumn<int>(
    'day_of_month',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _dayOfWeekMeta = const VerificationMeta(
    'dayOfWeek',
  );
  @override
  late final GeneratedColumn<int> dayOfWeek = GeneratedColumn<int>(
    'day_of_week',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _monthOfYearMeta = const VerificationMeta(
    'monthOfYear',
  );
  @override
  late final GeneratedColumn<int> monthOfYear = GeneratedColumn<int>(
    'month_of_year',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _startDateMeta = const VerificationMeta(
    'startDate',
  );
  @override
  late final GeneratedColumn<DateTime> startDate = GeneratedColumn<DateTime>(
    'start_date',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _endDateMeta = const VerificationMeta(
    'endDate',
  );
  @override
  late final GeneratedColumn<DateTime> endDate = GeneratedColumn<DateTime>(
    'end_date',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastGeneratedDateMeta = const VerificationMeta(
    'lastGeneratedDate',
  );
  @override
  late final GeneratedColumn<DateTime> lastGeneratedDate =
      GeneratedColumn<DateTime>(
        'last_generated_date',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _enabledMeta = const VerificationMeta(
    'enabled',
  );
  @override
  late final GeneratedColumn<bool> enabled = GeneratedColumn<bool>(
    'enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("enabled" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    ledgerId,
    type,
    amount,
    currencyCode,
    categoryId,
    note,
    frequency,
    interval,
    dayOfMonth,
    dayOfWeek,
    monthOfYear,
    startDate,
    endDate,
    lastGeneratedDate,
    enabled,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'recurring_transactions';
  @override
  VerificationContext validateIntegrity(
    Insertable<RecurringTransaction> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('ledger_id')) {
      context.handle(
        _ledgerIdMeta,
        ledgerId.isAcceptableOrUnknown(data['ledger_id']!, _ledgerIdMeta),
      );
    } else if (isInserting) {
      context.missing(_ledgerIdMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('amount')) {
      context.handle(
        _amountMeta,
        amount.isAcceptableOrUnknown(data['amount']!, _amountMeta),
      );
    } else if (isInserting) {
      context.missing(_amountMeta);
    }
    if (data.containsKey('currency_code')) {
      context.handle(
        _currencyCodeMeta,
        currencyCode.isAcceptableOrUnknown(
          data['currency_code']!,
          _currencyCodeMeta,
        ),
      );
    }
    if (data.containsKey('category_id')) {
      context.handle(
        _categoryIdMeta,
        categoryId.isAcceptableOrUnknown(data['category_id']!, _categoryIdMeta),
      );
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    if (data.containsKey('frequency')) {
      context.handle(
        _frequencyMeta,
        frequency.isAcceptableOrUnknown(data['frequency']!, _frequencyMeta),
      );
    } else if (isInserting) {
      context.missing(_frequencyMeta);
    }
    if (data.containsKey('interval')) {
      context.handle(
        _intervalMeta,
        interval.isAcceptableOrUnknown(data['interval']!, _intervalMeta),
      );
    }
    if (data.containsKey('day_of_month')) {
      context.handle(
        _dayOfMonthMeta,
        dayOfMonth.isAcceptableOrUnknown(
          data['day_of_month']!,
          _dayOfMonthMeta,
        ),
      );
    }
    if (data.containsKey('day_of_week')) {
      context.handle(
        _dayOfWeekMeta,
        dayOfWeek.isAcceptableOrUnknown(data['day_of_week']!, _dayOfWeekMeta),
      );
    }
    if (data.containsKey('month_of_year')) {
      context.handle(
        _monthOfYearMeta,
        monthOfYear.isAcceptableOrUnknown(
          data['month_of_year']!,
          _monthOfYearMeta,
        ),
      );
    }
    if (data.containsKey('start_date')) {
      context.handle(
        _startDateMeta,
        startDate.isAcceptableOrUnknown(data['start_date']!, _startDateMeta),
      );
    } else if (isInserting) {
      context.missing(_startDateMeta);
    }
    if (data.containsKey('end_date')) {
      context.handle(
        _endDateMeta,
        endDate.isAcceptableOrUnknown(data['end_date']!, _endDateMeta),
      );
    }
    if (data.containsKey('last_generated_date')) {
      context.handle(
        _lastGeneratedDateMeta,
        lastGeneratedDate.isAcceptableOrUnknown(
          data['last_generated_date']!,
          _lastGeneratedDateMeta,
        ),
      );
    }
    if (data.containsKey('enabled')) {
      context.handle(
        _enabledMeta,
        enabled.isAcceptableOrUnknown(data['enabled']!, _enabledMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  RecurringTransaction map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RecurringTransaction(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      ledgerId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}ledger_id'],
      )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      amount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}amount'],
      )!,
      currencyCode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}currency_code'],
      ),
      categoryId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}category_id'],
      ),
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      ),
      frequency: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}frequency'],
      )!,
      interval: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}interval'],
      )!,
      dayOfMonth: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}day_of_month'],
      ),
      dayOfWeek: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}day_of_week'],
      ),
      monthOfYear: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}month_of_year'],
      ),
      startDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}start_date'],
      )!,
      endDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}end_date'],
      ),
      lastGeneratedDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_generated_date'],
      ),
      enabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}enabled'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $RecurringTransactionsTable createAlias(String alias) {
    return $RecurringTransactionsTable(attachedDatabase, alias);
  }
}

class RecurringTransaction extends DataClass
    implements Insertable<RecurringTransaction> {
  final int id;
  final int ledgerId;
  final String type;

  /// 周期模板金额,单位=最小货币单位(分),与 [Transactions.amount] 同口径。
  final int amount;

  /// 模板金额的原记账币种。
  ///
  /// 币种跟随金额而不是账本归属持久化，确保模板跨账本或账本更换本位币后，
  /// 后续生成的交易仍按创建模板时的币种交给统一交易写入链路折算。
  final String? currencyCode;
  final int? categoryId;
  final String? note;
  final String frequency;
  final int interval;
  final int? dayOfMonth;
  final int? dayOfWeek;
  final int? monthOfYear;
  final DateTime startDate;
  final DateTime? endDate;
  final DateTime? lastGeneratedDate;
  final bool enabled;
  final DateTime createdAt;
  final DateTime updatedAt;
  const RecurringTransaction({
    required this.id,
    required this.ledgerId,
    required this.type,
    required this.amount,
    this.currencyCode,
    this.categoryId,
    this.note,
    required this.frequency,
    required this.interval,
    this.dayOfMonth,
    this.dayOfWeek,
    this.monthOfYear,
    required this.startDate,
    this.endDate,
    this.lastGeneratedDate,
    required this.enabled,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['ledger_id'] = Variable<int>(ledgerId);
    map['type'] = Variable<String>(type);
    map['amount'] = Variable<int>(amount);
    if (!nullToAbsent || currencyCode != null) {
      map['currency_code'] = Variable<String>(currencyCode);
    }
    if (!nullToAbsent || categoryId != null) {
      map['category_id'] = Variable<int>(categoryId);
    }
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    map['frequency'] = Variable<String>(frequency);
    map['interval'] = Variable<int>(interval);
    if (!nullToAbsent || dayOfMonth != null) {
      map['day_of_month'] = Variable<int>(dayOfMonth);
    }
    if (!nullToAbsent || dayOfWeek != null) {
      map['day_of_week'] = Variable<int>(dayOfWeek);
    }
    if (!nullToAbsent || monthOfYear != null) {
      map['month_of_year'] = Variable<int>(monthOfYear);
    }
    map['start_date'] = Variable<DateTime>(startDate);
    if (!nullToAbsent || endDate != null) {
      map['end_date'] = Variable<DateTime>(endDate);
    }
    if (!nullToAbsent || lastGeneratedDate != null) {
      map['last_generated_date'] = Variable<DateTime>(lastGeneratedDate);
    }
    map['enabled'] = Variable<bool>(enabled);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  RecurringTransactionsCompanion toCompanion(bool nullToAbsent) {
    return RecurringTransactionsCompanion(
      id: Value(id),
      ledgerId: Value(ledgerId),
      type: Value(type),
      amount: Value(amount),
      currencyCode: currencyCode == null && nullToAbsent
          ? const Value.absent()
          : Value(currencyCode),
      categoryId: categoryId == null && nullToAbsent
          ? const Value.absent()
          : Value(categoryId),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
      frequency: Value(frequency),
      interval: Value(interval),
      dayOfMonth: dayOfMonth == null && nullToAbsent
          ? const Value.absent()
          : Value(dayOfMonth),
      dayOfWeek: dayOfWeek == null && nullToAbsent
          ? const Value.absent()
          : Value(dayOfWeek),
      monthOfYear: monthOfYear == null && nullToAbsent
          ? const Value.absent()
          : Value(monthOfYear),
      startDate: Value(startDate),
      endDate: endDate == null && nullToAbsent
          ? const Value.absent()
          : Value(endDate),
      lastGeneratedDate: lastGeneratedDate == null && nullToAbsent
          ? const Value.absent()
          : Value(lastGeneratedDate),
      enabled: Value(enabled),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory RecurringTransaction.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RecurringTransaction(
      id: serializer.fromJson<int>(json['id']),
      ledgerId: serializer.fromJson<int>(json['ledgerId']),
      type: serializer.fromJson<String>(json['type']),
      amount: serializer.fromJson<int>(json['amount']),
      currencyCode: serializer.fromJson<String?>(json['currencyCode']),
      categoryId: serializer.fromJson<int?>(json['categoryId']),
      note: serializer.fromJson<String?>(json['note']),
      frequency: serializer.fromJson<String>(json['frequency']),
      interval: serializer.fromJson<int>(json['interval']),
      dayOfMonth: serializer.fromJson<int?>(json['dayOfMonth']),
      dayOfWeek: serializer.fromJson<int?>(json['dayOfWeek']),
      monthOfYear: serializer.fromJson<int?>(json['monthOfYear']),
      startDate: serializer.fromJson<DateTime>(json['startDate']),
      endDate: serializer.fromJson<DateTime?>(json['endDate']),
      lastGeneratedDate: serializer.fromJson<DateTime?>(
        json['lastGeneratedDate'],
      ),
      enabled: serializer.fromJson<bool>(json['enabled']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'ledgerId': serializer.toJson<int>(ledgerId),
      'type': serializer.toJson<String>(type),
      'amount': serializer.toJson<int>(amount),
      'currencyCode': serializer.toJson<String?>(currencyCode),
      'categoryId': serializer.toJson<int?>(categoryId),
      'note': serializer.toJson<String?>(note),
      'frequency': serializer.toJson<String>(frequency),
      'interval': serializer.toJson<int>(interval),
      'dayOfMonth': serializer.toJson<int?>(dayOfMonth),
      'dayOfWeek': serializer.toJson<int?>(dayOfWeek),
      'monthOfYear': serializer.toJson<int?>(monthOfYear),
      'startDate': serializer.toJson<DateTime>(startDate),
      'endDate': serializer.toJson<DateTime?>(endDate),
      'lastGeneratedDate': serializer.toJson<DateTime?>(lastGeneratedDate),
      'enabled': serializer.toJson<bool>(enabled),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  RecurringTransaction copyWith({
    int? id,
    int? ledgerId,
    String? type,
    int? amount,
    Value<String?> currencyCode = const Value.absent(),
    Value<int?> categoryId = const Value.absent(),
    Value<String?> note = const Value.absent(),
    String? frequency,
    int? interval,
    Value<int?> dayOfMonth = const Value.absent(),
    Value<int?> dayOfWeek = const Value.absent(),
    Value<int?> monthOfYear = const Value.absent(),
    DateTime? startDate,
    Value<DateTime?> endDate = const Value.absent(),
    Value<DateTime?> lastGeneratedDate = const Value.absent(),
    bool? enabled,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => RecurringTransaction(
    id: id ?? this.id,
    ledgerId: ledgerId ?? this.ledgerId,
    type: type ?? this.type,
    amount: amount ?? this.amount,
    currencyCode: currencyCode.present ? currencyCode.value : this.currencyCode,
    categoryId: categoryId.present ? categoryId.value : this.categoryId,
    note: note.present ? note.value : this.note,
    frequency: frequency ?? this.frequency,
    interval: interval ?? this.interval,
    dayOfMonth: dayOfMonth.present ? dayOfMonth.value : this.dayOfMonth,
    dayOfWeek: dayOfWeek.present ? dayOfWeek.value : this.dayOfWeek,
    monthOfYear: monthOfYear.present ? monthOfYear.value : this.monthOfYear,
    startDate: startDate ?? this.startDate,
    endDate: endDate.present ? endDate.value : this.endDate,
    lastGeneratedDate: lastGeneratedDate.present
        ? lastGeneratedDate.value
        : this.lastGeneratedDate,
    enabled: enabled ?? this.enabled,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  RecurringTransaction copyWithCompanion(RecurringTransactionsCompanion data) {
    return RecurringTransaction(
      id: data.id.present ? data.id.value : this.id,
      ledgerId: data.ledgerId.present ? data.ledgerId.value : this.ledgerId,
      type: data.type.present ? data.type.value : this.type,
      amount: data.amount.present ? data.amount.value : this.amount,
      currencyCode: data.currencyCode.present
          ? data.currencyCode.value
          : this.currencyCode,
      categoryId: data.categoryId.present
          ? data.categoryId.value
          : this.categoryId,
      note: data.note.present ? data.note.value : this.note,
      frequency: data.frequency.present ? data.frequency.value : this.frequency,
      interval: data.interval.present ? data.interval.value : this.interval,
      dayOfMonth: data.dayOfMonth.present
          ? data.dayOfMonth.value
          : this.dayOfMonth,
      dayOfWeek: data.dayOfWeek.present ? data.dayOfWeek.value : this.dayOfWeek,
      monthOfYear: data.monthOfYear.present
          ? data.monthOfYear.value
          : this.monthOfYear,
      startDate: data.startDate.present ? data.startDate.value : this.startDate,
      endDate: data.endDate.present ? data.endDate.value : this.endDate,
      lastGeneratedDate: data.lastGeneratedDate.present
          ? data.lastGeneratedDate.value
          : this.lastGeneratedDate,
      enabled: data.enabled.present ? data.enabled.value : this.enabled,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RecurringTransaction(')
          ..write('id: $id, ')
          ..write('ledgerId: $ledgerId, ')
          ..write('type: $type, ')
          ..write('amount: $amount, ')
          ..write('currencyCode: $currencyCode, ')
          ..write('categoryId: $categoryId, ')
          ..write('note: $note, ')
          ..write('frequency: $frequency, ')
          ..write('interval: $interval, ')
          ..write('dayOfMonth: $dayOfMonth, ')
          ..write('dayOfWeek: $dayOfWeek, ')
          ..write('monthOfYear: $monthOfYear, ')
          ..write('startDate: $startDate, ')
          ..write('endDate: $endDate, ')
          ..write('lastGeneratedDate: $lastGeneratedDate, ')
          ..write('enabled: $enabled, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    ledgerId,
    type,
    amount,
    currencyCode,
    categoryId,
    note,
    frequency,
    interval,
    dayOfMonth,
    dayOfWeek,
    monthOfYear,
    startDate,
    endDate,
    lastGeneratedDate,
    enabled,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RecurringTransaction &&
          other.id == this.id &&
          other.ledgerId == this.ledgerId &&
          other.type == this.type &&
          other.amount == this.amount &&
          other.currencyCode == this.currencyCode &&
          other.categoryId == this.categoryId &&
          other.note == this.note &&
          other.frequency == this.frequency &&
          other.interval == this.interval &&
          other.dayOfMonth == this.dayOfMonth &&
          other.dayOfWeek == this.dayOfWeek &&
          other.monthOfYear == this.monthOfYear &&
          other.startDate == this.startDate &&
          other.endDate == this.endDate &&
          other.lastGeneratedDate == this.lastGeneratedDate &&
          other.enabled == this.enabled &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class RecurringTransactionsCompanion
    extends UpdateCompanion<RecurringTransaction> {
  final Value<int> id;
  final Value<int> ledgerId;
  final Value<String> type;
  final Value<int> amount;
  final Value<String?> currencyCode;
  final Value<int?> categoryId;
  final Value<String?> note;
  final Value<String> frequency;
  final Value<int> interval;
  final Value<int?> dayOfMonth;
  final Value<int?> dayOfWeek;
  final Value<int?> monthOfYear;
  final Value<DateTime> startDate;
  final Value<DateTime?> endDate;
  final Value<DateTime?> lastGeneratedDate;
  final Value<bool> enabled;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  const RecurringTransactionsCompanion({
    this.id = const Value.absent(),
    this.ledgerId = const Value.absent(),
    this.type = const Value.absent(),
    this.amount = const Value.absent(),
    this.currencyCode = const Value.absent(),
    this.categoryId = const Value.absent(),
    this.note = const Value.absent(),
    this.frequency = const Value.absent(),
    this.interval = const Value.absent(),
    this.dayOfMonth = const Value.absent(),
    this.dayOfWeek = const Value.absent(),
    this.monthOfYear = const Value.absent(),
    this.startDate = const Value.absent(),
    this.endDate = const Value.absent(),
    this.lastGeneratedDate = const Value.absent(),
    this.enabled = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  RecurringTransactionsCompanion.insert({
    this.id = const Value.absent(),
    required int ledgerId,
    required String type,
    required int amount,
    this.currencyCode = const Value.absent(),
    this.categoryId = const Value.absent(),
    this.note = const Value.absent(),
    required String frequency,
    this.interval = const Value.absent(),
    this.dayOfMonth = const Value.absent(),
    this.dayOfWeek = const Value.absent(),
    this.monthOfYear = const Value.absent(),
    required DateTime startDate,
    this.endDate = const Value.absent(),
    this.lastGeneratedDate = const Value.absent(),
    this.enabled = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  }) : ledgerId = Value(ledgerId),
       type = Value(type),
       amount = Value(amount),
       frequency = Value(frequency),
       startDate = Value(startDate);
  static Insertable<RecurringTransaction> custom({
    Expression<int>? id,
    Expression<int>? ledgerId,
    Expression<String>? type,
    Expression<int>? amount,
    Expression<String>? currencyCode,
    Expression<int>? categoryId,
    Expression<String>? note,
    Expression<String>? frequency,
    Expression<int>? interval,
    Expression<int>? dayOfMonth,
    Expression<int>? dayOfWeek,
    Expression<int>? monthOfYear,
    Expression<DateTime>? startDate,
    Expression<DateTime>? endDate,
    Expression<DateTime>? lastGeneratedDate,
    Expression<bool>? enabled,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (ledgerId != null) 'ledger_id': ledgerId,
      if (type != null) 'type': type,
      if (amount != null) 'amount': amount,
      if (currencyCode != null) 'currency_code': currencyCode,
      if (categoryId != null) 'category_id': categoryId,
      if (note != null) 'note': note,
      if (frequency != null) 'frequency': frequency,
      if (interval != null) 'interval': interval,
      if (dayOfMonth != null) 'day_of_month': dayOfMonth,
      if (dayOfWeek != null) 'day_of_week': dayOfWeek,
      if (monthOfYear != null) 'month_of_year': monthOfYear,
      if (startDate != null) 'start_date': startDate,
      if (endDate != null) 'end_date': endDate,
      if (lastGeneratedDate != null) 'last_generated_date': lastGeneratedDate,
      if (enabled != null) 'enabled': enabled,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  RecurringTransactionsCompanion copyWith({
    Value<int>? id,
    Value<int>? ledgerId,
    Value<String>? type,
    Value<int>? amount,
    Value<String?>? currencyCode,
    Value<int?>? categoryId,
    Value<String?>? note,
    Value<String>? frequency,
    Value<int>? interval,
    Value<int?>? dayOfMonth,
    Value<int?>? dayOfWeek,
    Value<int?>? monthOfYear,
    Value<DateTime>? startDate,
    Value<DateTime?>? endDate,
    Value<DateTime?>? lastGeneratedDate,
    Value<bool>? enabled,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
  }) {
    return RecurringTransactionsCompanion(
      id: id ?? this.id,
      ledgerId: ledgerId ?? this.ledgerId,
      type: type ?? this.type,
      amount: amount ?? this.amount,
      currencyCode: currencyCode ?? this.currencyCode,
      categoryId: categoryId ?? this.categoryId,
      note: note ?? this.note,
      frequency: frequency ?? this.frequency,
      interval: interval ?? this.interval,
      dayOfMonth: dayOfMonth ?? this.dayOfMonth,
      dayOfWeek: dayOfWeek ?? this.dayOfWeek,
      monthOfYear: monthOfYear ?? this.monthOfYear,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      lastGeneratedDate: lastGeneratedDate ?? this.lastGeneratedDate,
      enabled: enabled ?? this.enabled,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (ledgerId.present) {
      map['ledger_id'] = Variable<int>(ledgerId.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (amount.present) {
      map['amount'] = Variable<int>(amount.value);
    }
    if (currencyCode.present) {
      map['currency_code'] = Variable<String>(currencyCode.value);
    }
    if (categoryId.present) {
      map['category_id'] = Variable<int>(categoryId.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (frequency.present) {
      map['frequency'] = Variable<String>(frequency.value);
    }
    if (interval.present) {
      map['interval'] = Variable<int>(interval.value);
    }
    if (dayOfMonth.present) {
      map['day_of_month'] = Variable<int>(dayOfMonth.value);
    }
    if (dayOfWeek.present) {
      map['day_of_week'] = Variable<int>(dayOfWeek.value);
    }
    if (monthOfYear.present) {
      map['month_of_year'] = Variable<int>(monthOfYear.value);
    }
    if (startDate.present) {
      map['start_date'] = Variable<DateTime>(startDate.value);
    }
    if (endDate.present) {
      map['end_date'] = Variable<DateTime>(endDate.value);
    }
    if (lastGeneratedDate.present) {
      map['last_generated_date'] = Variable<DateTime>(lastGeneratedDate.value);
    }
    if (enabled.present) {
      map['enabled'] = Variable<bool>(enabled.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RecurringTransactionsCompanion(')
          ..write('id: $id, ')
          ..write('ledgerId: $ledgerId, ')
          ..write('type: $type, ')
          ..write('amount: $amount, ')
          ..write('currencyCode: $currencyCode, ')
          ..write('categoryId: $categoryId, ')
          ..write('note: $note, ')
          ..write('frequency: $frequency, ')
          ..write('interval: $interval, ')
          ..write('dayOfMonth: $dayOfMonth, ')
          ..write('dayOfWeek: $dayOfWeek, ')
          ..write('monthOfYear: $monthOfYear, ')
          ..write('startDate: $startDate, ')
          ..write('endDate: $endDate, ')
          ..write('lastGeneratedDate: $lastGeneratedDate, ')
          ..write('enabled: $enabled, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $TransactionsTable extends Transactions
    with TableInfo<$TransactionsTable, Transaction> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TransactionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _ledgerIdMeta = const VerificationMeta(
    'ledgerId',
  );
  @override
  late final GeneratedColumn<int> ledgerId = GeneratedColumn<int>(
    'ledger_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES ledgers (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _amountMeta = const VerificationMeta('amount');
  @override
  late final GeneratedColumn<int> amount = GeneratedColumn<int>(
    'amount',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _categoryIdMeta = const VerificationMeta(
    'categoryId',
  );
  @override
  late final GeneratedColumn<int> categoryId = GeneratedColumn<int>(
    'category_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES categories (id) ON DELETE SET NULL',
    ),
  );
  static const VerificationMeta _happenedAtMeta = const VerificationMeta(
    'happenedAt',
  );
  @override
  late final GeneratedColumn<DateTime> happenedAt = GeneratedColumn<DateTime>(
    'happened_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _recurringIdMeta = const VerificationMeta(
    'recurringId',
  );
  @override
  late final GeneratedColumn<int> recurringId = GeneratedColumn<int>(
    'recurring_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES recurring_transactions (id) ON DELETE SET NULL',
    ),
  );
  static const VerificationMeta _syncIdMeta = const VerificationMeta('syncId');
  @override
  late final GeneratedColumn<String> syncId = GeneratedColumn<String>(
    'sync_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdByUserIdMeta = const VerificationMeta(
    'createdByUserId',
  );
  @override
  late final GeneratedColumn<String> createdByUserId = GeneratedColumn<String>(
    'created_by_user_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastEditedByUserIdMeta =
      const VerificationMeta('lastEditedByUserId');
  @override
  late final GeneratedColumn<String> lastEditedByUserId =
      GeneratedColumn<String>(
        'last_edited_by_user_id',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _categorySyncIdOverrideMeta =
      const VerificationMeta('categorySyncIdOverride');
  @override
  late final GeneratedColumn<String> categorySyncIdOverride =
      GeneratedColumn<String>(
        'category_sync_id_override',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _excludeFromStatsMeta = const VerificationMeta(
    'excludeFromStats',
  );
  @override
  late final GeneratedColumn<bool> excludeFromStats = GeneratedColumn<bool>(
    'exclude_from_stats',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("exclude_from_stats" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _currencyCodeMeta = const VerificationMeta(
    'currencyCode',
  );
  @override
  late final GeneratedColumn<String> currencyCode = GeneratedColumn<String>(
    'currency_code',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _nativeAmountMeta = const VerificationMeta(
    'nativeAmount',
  );
  @override
  late final GeneratedColumn<int> nativeAmount = GeneratedColumn<int>(
    'native_amount',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _versionMeta = const VerificationMeta(
    'version',
  );
  @override
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
    'version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _lastEditedAtMeta = const VerificationMeta(
    'lastEditedAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastEditedAt = GeneratedColumn<DateTime>(
    'last_edited_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _paidByUserIdMeta = const VerificationMeta(
    'paidByUserId',
  );
  @override
  late final GeneratedColumn<String> paidByUserId = GeneratedColumn<String>(
    'paid_by_user_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _aaModeMeta = const VerificationMeta('aaMode');
  @override
  late final GeneratedColumn<int> aaMode = GeneratedColumn<int>(
    'aa_mode',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _aaParticipantsMeta = const VerificationMeta(
    'aaParticipants',
  );
  @override
  late final GeneratedColumn<String> aaParticipants = GeneratedColumn<String>(
    'aa_participants',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _aaSplitsMeta = const VerificationMeta(
    'aaSplits',
  );
  @override
  late final GeneratedColumn<String> aaSplits = GeneratedColumn<String>(
    'aa_splits',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    ledgerId,
    type,
    amount,
    categoryId,
    happenedAt,
    note,
    recurringId,
    syncId,
    createdByUserId,
    lastEditedByUserId,
    categorySyncIdOverride,
    excludeFromStats,
    currencyCode,
    nativeAmount,
    version,
    lastEditedAt,
    paidByUserId,
    aaMode,
    aaParticipants,
    aaSplits,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'transactions';
  @override
  VerificationContext validateIntegrity(
    Insertable<Transaction> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('ledger_id')) {
      context.handle(
        _ledgerIdMeta,
        ledgerId.isAcceptableOrUnknown(data['ledger_id']!, _ledgerIdMeta),
      );
    } else if (isInserting) {
      context.missing(_ledgerIdMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('amount')) {
      context.handle(
        _amountMeta,
        amount.isAcceptableOrUnknown(data['amount']!, _amountMeta),
      );
    } else if (isInserting) {
      context.missing(_amountMeta);
    }
    if (data.containsKey('category_id')) {
      context.handle(
        _categoryIdMeta,
        categoryId.isAcceptableOrUnknown(data['category_id']!, _categoryIdMeta),
      );
    }
    if (data.containsKey('happened_at')) {
      context.handle(
        _happenedAtMeta,
        happenedAt.isAcceptableOrUnknown(data['happened_at']!, _happenedAtMeta),
      );
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    if (data.containsKey('recurring_id')) {
      context.handle(
        _recurringIdMeta,
        recurringId.isAcceptableOrUnknown(
          data['recurring_id']!,
          _recurringIdMeta,
        ),
      );
    }
    if (data.containsKey('sync_id')) {
      context.handle(
        _syncIdMeta,
        syncId.isAcceptableOrUnknown(data['sync_id']!, _syncIdMeta),
      );
    }
    if (data.containsKey('created_by_user_id')) {
      context.handle(
        _createdByUserIdMeta,
        createdByUserId.isAcceptableOrUnknown(
          data['created_by_user_id']!,
          _createdByUserIdMeta,
        ),
      );
    }
    if (data.containsKey('last_edited_by_user_id')) {
      context.handle(
        _lastEditedByUserIdMeta,
        lastEditedByUserId.isAcceptableOrUnknown(
          data['last_edited_by_user_id']!,
          _lastEditedByUserIdMeta,
        ),
      );
    }
    if (data.containsKey('category_sync_id_override')) {
      context.handle(
        _categorySyncIdOverrideMeta,
        categorySyncIdOverride.isAcceptableOrUnknown(
          data['category_sync_id_override']!,
          _categorySyncIdOverrideMeta,
        ),
      );
    }
    if (data.containsKey('exclude_from_stats')) {
      context.handle(
        _excludeFromStatsMeta,
        excludeFromStats.isAcceptableOrUnknown(
          data['exclude_from_stats']!,
          _excludeFromStatsMeta,
        ),
      );
    }
    if (data.containsKey('currency_code')) {
      context.handle(
        _currencyCodeMeta,
        currencyCode.isAcceptableOrUnknown(
          data['currency_code']!,
          _currencyCodeMeta,
        ),
      );
    }
    if (data.containsKey('native_amount')) {
      context.handle(
        _nativeAmountMeta,
        nativeAmount.isAcceptableOrUnknown(
          data['native_amount']!,
          _nativeAmountMeta,
        ),
      );
    }
    if (data.containsKey('version')) {
      context.handle(
        _versionMeta,
        version.isAcceptableOrUnknown(data['version']!, _versionMeta),
      );
    }
    if (data.containsKey('last_edited_at')) {
      context.handle(
        _lastEditedAtMeta,
        lastEditedAt.isAcceptableOrUnknown(
          data['last_edited_at']!,
          _lastEditedAtMeta,
        ),
      );
    }
    if (data.containsKey('paid_by_user_id')) {
      context.handle(
        _paidByUserIdMeta,
        paidByUserId.isAcceptableOrUnknown(
          data['paid_by_user_id']!,
          _paidByUserIdMeta,
        ),
      );
    }
    if (data.containsKey('aa_mode')) {
      context.handle(
        _aaModeMeta,
        aaMode.isAcceptableOrUnknown(data['aa_mode']!, _aaModeMeta),
      );
    }
    if (data.containsKey('aa_participants')) {
      context.handle(
        _aaParticipantsMeta,
        aaParticipants.isAcceptableOrUnknown(
          data['aa_participants']!,
          _aaParticipantsMeta,
        ),
      );
    }
    if (data.containsKey('aa_splits')) {
      context.handle(
        _aaSplitsMeta,
        aaSplits.isAcceptableOrUnknown(data['aa_splits']!, _aaSplitsMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Transaction map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Transaction(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      ledgerId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}ledger_id'],
      )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      amount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}amount'],
      )!,
      categoryId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}category_id'],
      ),
      happenedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}happened_at'],
      )!,
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      ),
      recurringId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}recurring_id'],
      ),
      syncId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sync_id'],
      ),
      createdByUserId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_by_user_id'],
      ),
      lastEditedByUserId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_edited_by_user_id'],
      ),
      categorySyncIdOverride: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category_sync_id_override'],
      ),
      excludeFromStats: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}exclude_from_stats'],
      )!,
      currencyCode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}currency_code'],
      ),
      nativeAmount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}native_amount'],
      ),
      version: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}version'],
      )!,
      lastEditedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_edited_at'],
      ),
      paidByUserId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}paid_by_user_id'],
      ),
      aaMode: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}aa_mode'],
      ),
      aaParticipants: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}aa_participants'],
      ),
      aaSplits: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}aa_splits'],
      ),
    );
  }

  @override
  $TransactionsTable createAlias(String alias) {
    return $TransactionsTable(attachedDatabase, alias);
  }
}

class Transaction extends DataClass implements Insertable<Transaction> {
  final int id;
  final int ledgerId;
  final String type;

  /// 交易金额,单位=最小货币单位(分),整数存储保证财务精度。
  /// 输入/同步接口仍按"元"口径,落库前统一换算成整数分。
  final int amount;
  final int? categoryId;
  final DateTime happenedAt;
  final String? note;
  final int? recurringId;
  final String? syncId;
  final String? createdByUserId;
  final String? lastEditedByUserId;
  final String? categorySyncIdOverride;

  /// 不计入支出统计:true 时从支出统计/图表/月年汇总剔除,但仍计入
  /// 账单列表。
  final bool excludeFromStats;

  /// 交易级多币种:交易币种(ISO 大写)。
  /// 用户所选(默认账本本位币)。显式存让交易自包含(同步/统计不必每次 join)。
  final String? currencyCode;

  /// 折算到账本本位币的金额快照(按记账时汇率,保存即定,不随汇率重算)。
  /// 单币种/未折算 == amount(隐含汇率 1.0)。账本维度统计读本列(?? amount)。
  /// 单位同 [amount]:整数分。
  final int? nativeAmount;

  /// 编辑版本号。创建时为 1,每次 update +1。
  /// 用于记录详情 Bottom Sheet 的编辑历史区块展示,以及并发编辑检测。
  final int version;

  /// 最后编辑时间。创建时为 null(以此区分"创建"与"编辑"),
  /// 首次编辑后写入。列表项第二行的 HH:mm 与详情协作成员区块均读本字段
  /// (非 happenedAt,后者是"记账日期"语义)。
  final DateTime? lastEditedAt;

  /// 支出人 userId(交易级全局字段,谁垫付/支出,非 AA 专属)。
  /// 任何一笔账都有支出人:新建未手选时由写入层回填操作者(默认支出人 = 创建人),
  /// 手选后恒写手选值;编辑未手选不更新保持原值。DB 不做非空约束(nullable);
  /// 迁移时从 created_by_user_id 回填,展示层空串降级"未知"。
  final String? paidByUserId;

  /// AA 分摊模式:null/0=人均,1=不分摊,2=指定金额。
  /// null 视为人均(历史交易默认进人均统计)。
  final int? aaMode;

  /// AA 分摊参与人列表(JSON 数组,元素为 userId 或虚拟用户 syncId)。
  /// 空值在运行时展开为当前账本全部成员。
  final String? aaParticipants;

  /// AA 指定分摊金额(JSON 对象,key=参与人,value=金额字符串)。
  /// 仅 aaMode=2 时有意义。
  final String? aaSplits;
  const Transaction({
    required this.id,
    required this.ledgerId,
    required this.type,
    required this.amount,
    this.categoryId,
    required this.happenedAt,
    this.note,
    this.recurringId,
    this.syncId,
    this.createdByUserId,
    this.lastEditedByUserId,
    this.categorySyncIdOverride,
    required this.excludeFromStats,
    this.currencyCode,
    this.nativeAmount,
    required this.version,
    this.lastEditedAt,
    this.paidByUserId,
    this.aaMode,
    this.aaParticipants,
    this.aaSplits,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['ledger_id'] = Variable<int>(ledgerId);
    map['type'] = Variable<String>(type);
    map['amount'] = Variable<int>(amount);
    if (!nullToAbsent || categoryId != null) {
      map['category_id'] = Variable<int>(categoryId);
    }
    map['happened_at'] = Variable<DateTime>(happenedAt);
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    if (!nullToAbsent || recurringId != null) {
      map['recurring_id'] = Variable<int>(recurringId);
    }
    if (!nullToAbsent || syncId != null) {
      map['sync_id'] = Variable<String>(syncId);
    }
    if (!nullToAbsent || createdByUserId != null) {
      map['created_by_user_id'] = Variable<String>(createdByUserId);
    }
    if (!nullToAbsent || lastEditedByUserId != null) {
      map['last_edited_by_user_id'] = Variable<String>(lastEditedByUserId);
    }
    if (!nullToAbsent || categorySyncIdOverride != null) {
      map['category_sync_id_override'] = Variable<String>(
        categorySyncIdOverride,
      );
    }
    map['exclude_from_stats'] = Variable<bool>(excludeFromStats);
    if (!nullToAbsent || currencyCode != null) {
      map['currency_code'] = Variable<String>(currencyCode);
    }
    if (!nullToAbsent || nativeAmount != null) {
      map['native_amount'] = Variable<int>(nativeAmount);
    }
    map['version'] = Variable<int>(version);
    if (!nullToAbsent || lastEditedAt != null) {
      map['last_edited_at'] = Variable<DateTime>(lastEditedAt);
    }
    if (!nullToAbsent || paidByUserId != null) {
      map['paid_by_user_id'] = Variable<String>(paidByUserId);
    }
    if (!nullToAbsent || aaMode != null) {
      map['aa_mode'] = Variable<int>(aaMode);
    }
    if (!nullToAbsent || aaParticipants != null) {
      map['aa_participants'] = Variable<String>(aaParticipants);
    }
    if (!nullToAbsent || aaSplits != null) {
      map['aa_splits'] = Variable<String>(aaSplits);
    }
    return map;
  }

  TransactionsCompanion toCompanion(bool nullToAbsent) {
    return TransactionsCompanion(
      id: Value(id),
      ledgerId: Value(ledgerId),
      type: Value(type),
      amount: Value(amount),
      categoryId: categoryId == null && nullToAbsent
          ? const Value.absent()
          : Value(categoryId),
      happenedAt: Value(happenedAt),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
      recurringId: recurringId == null && nullToAbsent
          ? const Value.absent()
          : Value(recurringId),
      syncId: syncId == null && nullToAbsent
          ? const Value.absent()
          : Value(syncId),
      createdByUserId: createdByUserId == null && nullToAbsent
          ? const Value.absent()
          : Value(createdByUserId),
      lastEditedByUserId: lastEditedByUserId == null && nullToAbsent
          ? const Value.absent()
          : Value(lastEditedByUserId),
      categorySyncIdOverride: categorySyncIdOverride == null && nullToAbsent
          ? const Value.absent()
          : Value(categorySyncIdOverride),
      excludeFromStats: Value(excludeFromStats),
      currencyCode: currencyCode == null && nullToAbsent
          ? const Value.absent()
          : Value(currencyCode),
      nativeAmount: nativeAmount == null && nullToAbsent
          ? const Value.absent()
          : Value(nativeAmount),
      version: Value(version),
      lastEditedAt: lastEditedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastEditedAt),
      paidByUserId: paidByUserId == null && nullToAbsent
          ? const Value.absent()
          : Value(paidByUserId),
      aaMode: aaMode == null && nullToAbsent
          ? const Value.absent()
          : Value(aaMode),
      aaParticipants: aaParticipants == null && nullToAbsent
          ? const Value.absent()
          : Value(aaParticipants),
      aaSplits: aaSplits == null && nullToAbsent
          ? const Value.absent()
          : Value(aaSplits),
    );
  }

  factory Transaction.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Transaction(
      id: serializer.fromJson<int>(json['id']),
      ledgerId: serializer.fromJson<int>(json['ledgerId']),
      type: serializer.fromJson<String>(json['type']),
      amount: serializer.fromJson<int>(json['amount']),
      categoryId: serializer.fromJson<int?>(json['categoryId']),
      happenedAt: serializer.fromJson<DateTime>(json['happenedAt']),
      note: serializer.fromJson<String?>(json['note']),
      recurringId: serializer.fromJson<int?>(json['recurringId']),
      syncId: serializer.fromJson<String?>(json['syncId']),
      createdByUserId: serializer.fromJson<String?>(json['createdByUserId']),
      lastEditedByUserId: serializer.fromJson<String?>(
        json['lastEditedByUserId'],
      ),
      categorySyncIdOverride: serializer.fromJson<String?>(
        json['categorySyncIdOverride'],
      ),
      excludeFromStats: serializer.fromJson<bool>(json['excludeFromStats']),
      currencyCode: serializer.fromJson<String?>(json['currencyCode']),
      nativeAmount: serializer.fromJson<int?>(json['nativeAmount']),
      version: serializer.fromJson<int>(json['version']),
      lastEditedAt: serializer.fromJson<DateTime?>(json['lastEditedAt']),
      paidByUserId: serializer.fromJson<String?>(json['paidByUserId']),
      aaMode: serializer.fromJson<int?>(json['aaMode']),
      aaParticipants: serializer.fromJson<String?>(json['aaParticipants']),
      aaSplits: serializer.fromJson<String?>(json['aaSplits']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'ledgerId': serializer.toJson<int>(ledgerId),
      'type': serializer.toJson<String>(type),
      'amount': serializer.toJson<int>(amount),
      'categoryId': serializer.toJson<int?>(categoryId),
      'happenedAt': serializer.toJson<DateTime>(happenedAt),
      'note': serializer.toJson<String?>(note),
      'recurringId': serializer.toJson<int?>(recurringId),
      'syncId': serializer.toJson<String?>(syncId),
      'createdByUserId': serializer.toJson<String?>(createdByUserId),
      'lastEditedByUserId': serializer.toJson<String?>(lastEditedByUserId),
      'categorySyncIdOverride': serializer.toJson<String?>(
        categorySyncIdOverride,
      ),
      'excludeFromStats': serializer.toJson<bool>(excludeFromStats),
      'currencyCode': serializer.toJson<String?>(currencyCode),
      'nativeAmount': serializer.toJson<int?>(nativeAmount),
      'version': serializer.toJson<int>(version),
      'lastEditedAt': serializer.toJson<DateTime?>(lastEditedAt),
      'paidByUserId': serializer.toJson<String?>(paidByUserId),
      'aaMode': serializer.toJson<int?>(aaMode),
      'aaParticipants': serializer.toJson<String?>(aaParticipants),
      'aaSplits': serializer.toJson<String?>(aaSplits),
    };
  }

  Transaction copyWith({
    int? id,
    int? ledgerId,
    String? type,
    int? amount,
    Value<int?> categoryId = const Value.absent(),
    DateTime? happenedAt,
    Value<String?> note = const Value.absent(),
    Value<int?> recurringId = const Value.absent(),
    Value<String?> syncId = const Value.absent(),
    Value<String?> createdByUserId = const Value.absent(),
    Value<String?> lastEditedByUserId = const Value.absent(),
    Value<String?> categorySyncIdOverride = const Value.absent(),
    bool? excludeFromStats,
    Value<String?> currencyCode = const Value.absent(),
    Value<int?> nativeAmount = const Value.absent(),
    int? version,
    Value<DateTime?> lastEditedAt = const Value.absent(),
    Value<String?> paidByUserId = const Value.absent(),
    Value<int?> aaMode = const Value.absent(),
    Value<String?> aaParticipants = const Value.absent(),
    Value<String?> aaSplits = const Value.absent(),
  }) => Transaction(
    id: id ?? this.id,
    ledgerId: ledgerId ?? this.ledgerId,
    type: type ?? this.type,
    amount: amount ?? this.amount,
    categoryId: categoryId.present ? categoryId.value : this.categoryId,
    happenedAt: happenedAt ?? this.happenedAt,
    note: note.present ? note.value : this.note,
    recurringId: recurringId.present ? recurringId.value : this.recurringId,
    syncId: syncId.present ? syncId.value : this.syncId,
    createdByUserId: createdByUserId.present
        ? createdByUserId.value
        : this.createdByUserId,
    lastEditedByUserId: lastEditedByUserId.present
        ? lastEditedByUserId.value
        : this.lastEditedByUserId,
    categorySyncIdOverride: categorySyncIdOverride.present
        ? categorySyncIdOverride.value
        : this.categorySyncIdOverride,
    excludeFromStats: excludeFromStats ?? this.excludeFromStats,
    currencyCode: currencyCode.present ? currencyCode.value : this.currencyCode,
    nativeAmount: nativeAmount.present ? nativeAmount.value : this.nativeAmount,
    version: version ?? this.version,
    lastEditedAt: lastEditedAt.present ? lastEditedAt.value : this.lastEditedAt,
    paidByUserId: paidByUserId.present ? paidByUserId.value : this.paidByUserId,
    aaMode: aaMode.present ? aaMode.value : this.aaMode,
    aaParticipants: aaParticipants.present
        ? aaParticipants.value
        : this.aaParticipants,
    aaSplits: aaSplits.present ? aaSplits.value : this.aaSplits,
  );
  Transaction copyWithCompanion(TransactionsCompanion data) {
    return Transaction(
      id: data.id.present ? data.id.value : this.id,
      ledgerId: data.ledgerId.present ? data.ledgerId.value : this.ledgerId,
      type: data.type.present ? data.type.value : this.type,
      amount: data.amount.present ? data.amount.value : this.amount,
      categoryId: data.categoryId.present
          ? data.categoryId.value
          : this.categoryId,
      happenedAt: data.happenedAt.present
          ? data.happenedAt.value
          : this.happenedAt,
      note: data.note.present ? data.note.value : this.note,
      recurringId: data.recurringId.present
          ? data.recurringId.value
          : this.recurringId,
      syncId: data.syncId.present ? data.syncId.value : this.syncId,
      createdByUserId: data.createdByUserId.present
          ? data.createdByUserId.value
          : this.createdByUserId,
      lastEditedByUserId: data.lastEditedByUserId.present
          ? data.lastEditedByUserId.value
          : this.lastEditedByUserId,
      categorySyncIdOverride: data.categorySyncIdOverride.present
          ? data.categorySyncIdOverride.value
          : this.categorySyncIdOverride,
      excludeFromStats: data.excludeFromStats.present
          ? data.excludeFromStats.value
          : this.excludeFromStats,
      currencyCode: data.currencyCode.present
          ? data.currencyCode.value
          : this.currencyCode,
      nativeAmount: data.nativeAmount.present
          ? data.nativeAmount.value
          : this.nativeAmount,
      version: data.version.present ? data.version.value : this.version,
      lastEditedAt: data.lastEditedAt.present
          ? data.lastEditedAt.value
          : this.lastEditedAt,
      paidByUserId: data.paidByUserId.present
          ? data.paidByUserId.value
          : this.paidByUserId,
      aaMode: data.aaMode.present ? data.aaMode.value : this.aaMode,
      aaParticipants: data.aaParticipants.present
          ? data.aaParticipants.value
          : this.aaParticipants,
      aaSplits: data.aaSplits.present ? data.aaSplits.value : this.aaSplits,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Transaction(')
          ..write('id: $id, ')
          ..write('ledgerId: $ledgerId, ')
          ..write('type: $type, ')
          ..write('amount: $amount, ')
          ..write('categoryId: $categoryId, ')
          ..write('happenedAt: $happenedAt, ')
          ..write('note: $note, ')
          ..write('recurringId: $recurringId, ')
          ..write('syncId: $syncId, ')
          ..write('createdByUserId: $createdByUserId, ')
          ..write('lastEditedByUserId: $lastEditedByUserId, ')
          ..write('categorySyncIdOverride: $categorySyncIdOverride, ')
          ..write('excludeFromStats: $excludeFromStats, ')
          ..write('currencyCode: $currencyCode, ')
          ..write('nativeAmount: $nativeAmount, ')
          ..write('version: $version, ')
          ..write('lastEditedAt: $lastEditedAt, ')
          ..write('paidByUserId: $paidByUserId, ')
          ..write('aaMode: $aaMode, ')
          ..write('aaParticipants: $aaParticipants, ')
          ..write('aaSplits: $aaSplits')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    ledgerId,
    type,
    amount,
    categoryId,
    happenedAt,
    note,
    recurringId,
    syncId,
    createdByUserId,
    lastEditedByUserId,
    categorySyncIdOverride,
    excludeFromStats,
    currencyCode,
    nativeAmount,
    version,
    lastEditedAt,
    paidByUserId,
    aaMode,
    aaParticipants,
    aaSplits,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Transaction &&
          other.id == this.id &&
          other.ledgerId == this.ledgerId &&
          other.type == this.type &&
          other.amount == this.amount &&
          other.categoryId == this.categoryId &&
          other.happenedAt == this.happenedAt &&
          other.note == this.note &&
          other.recurringId == this.recurringId &&
          other.syncId == this.syncId &&
          other.createdByUserId == this.createdByUserId &&
          other.lastEditedByUserId == this.lastEditedByUserId &&
          other.categorySyncIdOverride == this.categorySyncIdOverride &&
          other.excludeFromStats == this.excludeFromStats &&
          other.currencyCode == this.currencyCode &&
          other.nativeAmount == this.nativeAmount &&
          other.version == this.version &&
          other.lastEditedAt == this.lastEditedAt &&
          other.paidByUserId == this.paidByUserId &&
          other.aaMode == this.aaMode &&
          other.aaParticipants == this.aaParticipants &&
          other.aaSplits == this.aaSplits);
}

class TransactionsCompanion extends UpdateCompanion<Transaction> {
  final Value<int> id;
  final Value<int> ledgerId;
  final Value<String> type;
  final Value<int> amount;
  final Value<int?> categoryId;
  final Value<DateTime> happenedAt;
  final Value<String?> note;
  final Value<int?> recurringId;
  final Value<String?> syncId;
  final Value<String?> createdByUserId;
  final Value<String?> lastEditedByUserId;
  final Value<String?> categorySyncIdOverride;
  final Value<bool> excludeFromStats;
  final Value<String?> currencyCode;
  final Value<int?> nativeAmount;
  final Value<int> version;
  final Value<DateTime?> lastEditedAt;
  final Value<String?> paidByUserId;
  final Value<int?> aaMode;
  final Value<String?> aaParticipants;
  final Value<String?> aaSplits;
  const TransactionsCompanion({
    this.id = const Value.absent(),
    this.ledgerId = const Value.absent(),
    this.type = const Value.absent(),
    this.amount = const Value.absent(),
    this.categoryId = const Value.absent(),
    this.happenedAt = const Value.absent(),
    this.note = const Value.absent(),
    this.recurringId = const Value.absent(),
    this.syncId = const Value.absent(),
    this.createdByUserId = const Value.absent(),
    this.lastEditedByUserId = const Value.absent(),
    this.categorySyncIdOverride = const Value.absent(),
    this.excludeFromStats = const Value.absent(),
    this.currencyCode = const Value.absent(),
    this.nativeAmount = const Value.absent(),
    this.version = const Value.absent(),
    this.lastEditedAt = const Value.absent(),
    this.paidByUserId = const Value.absent(),
    this.aaMode = const Value.absent(),
    this.aaParticipants = const Value.absent(),
    this.aaSplits = const Value.absent(),
  });
  TransactionsCompanion.insert({
    this.id = const Value.absent(),
    required int ledgerId,
    required String type,
    required int amount,
    this.categoryId = const Value.absent(),
    this.happenedAt = const Value.absent(),
    this.note = const Value.absent(),
    this.recurringId = const Value.absent(),
    this.syncId = const Value.absent(),
    this.createdByUserId = const Value.absent(),
    this.lastEditedByUserId = const Value.absent(),
    this.categorySyncIdOverride = const Value.absent(),
    this.excludeFromStats = const Value.absent(),
    this.currencyCode = const Value.absent(),
    this.nativeAmount = const Value.absent(),
    this.version = const Value.absent(),
    this.lastEditedAt = const Value.absent(),
    this.paidByUserId = const Value.absent(),
    this.aaMode = const Value.absent(),
    this.aaParticipants = const Value.absent(),
    this.aaSplits = const Value.absent(),
  }) : ledgerId = Value(ledgerId),
       type = Value(type),
       amount = Value(amount);
  static Insertable<Transaction> custom({
    Expression<int>? id,
    Expression<int>? ledgerId,
    Expression<String>? type,
    Expression<int>? amount,
    Expression<int>? categoryId,
    Expression<DateTime>? happenedAt,
    Expression<String>? note,
    Expression<int>? recurringId,
    Expression<String>? syncId,
    Expression<String>? createdByUserId,
    Expression<String>? lastEditedByUserId,
    Expression<String>? categorySyncIdOverride,
    Expression<bool>? excludeFromStats,
    Expression<String>? currencyCode,
    Expression<int>? nativeAmount,
    Expression<int>? version,
    Expression<DateTime>? lastEditedAt,
    Expression<String>? paidByUserId,
    Expression<int>? aaMode,
    Expression<String>? aaParticipants,
    Expression<String>? aaSplits,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (ledgerId != null) 'ledger_id': ledgerId,
      if (type != null) 'type': type,
      if (amount != null) 'amount': amount,
      if (categoryId != null) 'category_id': categoryId,
      if (happenedAt != null) 'happened_at': happenedAt,
      if (note != null) 'note': note,
      if (recurringId != null) 'recurring_id': recurringId,
      if (syncId != null) 'sync_id': syncId,
      if (createdByUserId != null) 'created_by_user_id': createdByUserId,
      if (lastEditedByUserId != null)
        'last_edited_by_user_id': lastEditedByUserId,
      if (categorySyncIdOverride != null)
        'category_sync_id_override': categorySyncIdOverride,
      if (excludeFromStats != null) 'exclude_from_stats': excludeFromStats,
      if (currencyCode != null) 'currency_code': currencyCode,
      if (nativeAmount != null) 'native_amount': nativeAmount,
      if (version != null) 'version': version,
      if (lastEditedAt != null) 'last_edited_at': lastEditedAt,
      if (paidByUserId != null) 'paid_by_user_id': paidByUserId,
      if (aaMode != null) 'aa_mode': aaMode,
      if (aaParticipants != null) 'aa_participants': aaParticipants,
      if (aaSplits != null) 'aa_splits': aaSplits,
    });
  }

  TransactionsCompanion copyWith({
    Value<int>? id,
    Value<int>? ledgerId,
    Value<String>? type,
    Value<int>? amount,
    Value<int?>? categoryId,
    Value<DateTime>? happenedAt,
    Value<String?>? note,
    Value<int?>? recurringId,
    Value<String?>? syncId,
    Value<String?>? createdByUserId,
    Value<String?>? lastEditedByUserId,
    Value<String?>? categorySyncIdOverride,
    Value<bool>? excludeFromStats,
    Value<String?>? currencyCode,
    Value<int?>? nativeAmount,
    Value<int>? version,
    Value<DateTime?>? lastEditedAt,
    Value<String?>? paidByUserId,
    Value<int?>? aaMode,
    Value<String?>? aaParticipants,
    Value<String?>? aaSplits,
  }) {
    return TransactionsCompanion(
      id: id ?? this.id,
      ledgerId: ledgerId ?? this.ledgerId,
      type: type ?? this.type,
      amount: amount ?? this.amount,
      categoryId: categoryId ?? this.categoryId,
      happenedAt: happenedAt ?? this.happenedAt,
      note: note ?? this.note,
      recurringId: recurringId ?? this.recurringId,
      syncId: syncId ?? this.syncId,
      createdByUserId: createdByUserId ?? this.createdByUserId,
      lastEditedByUserId: lastEditedByUserId ?? this.lastEditedByUserId,
      categorySyncIdOverride:
          categorySyncIdOverride ?? this.categorySyncIdOverride,
      excludeFromStats: excludeFromStats ?? this.excludeFromStats,
      currencyCode: currencyCode ?? this.currencyCode,
      nativeAmount: nativeAmount ?? this.nativeAmount,
      version: version ?? this.version,
      lastEditedAt: lastEditedAt ?? this.lastEditedAt,
      paidByUserId: paidByUserId ?? this.paidByUserId,
      aaMode: aaMode ?? this.aaMode,
      aaParticipants: aaParticipants ?? this.aaParticipants,
      aaSplits: aaSplits ?? this.aaSplits,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (ledgerId.present) {
      map['ledger_id'] = Variable<int>(ledgerId.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (amount.present) {
      map['amount'] = Variable<int>(amount.value);
    }
    if (categoryId.present) {
      map['category_id'] = Variable<int>(categoryId.value);
    }
    if (happenedAt.present) {
      map['happened_at'] = Variable<DateTime>(happenedAt.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (recurringId.present) {
      map['recurring_id'] = Variable<int>(recurringId.value);
    }
    if (syncId.present) {
      map['sync_id'] = Variable<String>(syncId.value);
    }
    if (createdByUserId.present) {
      map['created_by_user_id'] = Variable<String>(createdByUserId.value);
    }
    if (lastEditedByUserId.present) {
      map['last_edited_by_user_id'] = Variable<String>(
        lastEditedByUserId.value,
      );
    }
    if (categorySyncIdOverride.present) {
      map['category_sync_id_override'] = Variable<String>(
        categorySyncIdOverride.value,
      );
    }
    if (excludeFromStats.present) {
      map['exclude_from_stats'] = Variable<bool>(excludeFromStats.value);
    }
    if (currencyCode.present) {
      map['currency_code'] = Variable<String>(currencyCode.value);
    }
    if (nativeAmount.present) {
      map['native_amount'] = Variable<int>(nativeAmount.value);
    }
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (lastEditedAt.present) {
      map['last_edited_at'] = Variable<DateTime>(lastEditedAt.value);
    }
    if (paidByUserId.present) {
      map['paid_by_user_id'] = Variable<String>(paidByUserId.value);
    }
    if (aaMode.present) {
      map['aa_mode'] = Variable<int>(aaMode.value);
    }
    if (aaParticipants.present) {
      map['aa_participants'] = Variable<String>(aaParticipants.value);
    }
    if (aaSplits.present) {
      map['aa_splits'] = Variable<String>(aaSplits.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TransactionsCompanion(')
          ..write('id: $id, ')
          ..write('ledgerId: $ledgerId, ')
          ..write('type: $type, ')
          ..write('amount: $amount, ')
          ..write('categoryId: $categoryId, ')
          ..write('happenedAt: $happenedAt, ')
          ..write('note: $note, ')
          ..write('recurringId: $recurringId, ')
          ..write('syncId: $syncId, ')
          ..write('createdByUserId: $createdByUserId, ')
          ..write('lastEditedByUserId: $lastEditedByUserId, ')
          ..write('categorySyncIdOverride: $categorySyncIdOverride, ')
          ..write('excludeFromStats: $excludeFromStats, ')
          ..write('currencyCode: $currencyCode, ')
          ..write('nativeAmount: $nativeAmount, ')
          ..write('version: $version, ')
          ..write('lastEditedAt: $lastEditedAt, ')
          ..write('paidByUserId: $paidByUserId, ')
          ..write('aaMode: $aaMode, ')
          ..write('aaParticipants: $aaParticipants, ')
          ..write('aaSplits: $aaSplits')
          ..write(')'))
        .toString();
  }
}

class $RecordEditHistoriesTable extends RecordEditHistories
    with TableInfo<$RecordEditHistoriesTable, RecordEditHistory> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RecordEditHistoriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _recordIdMeta = const VerificationMeta(
    'recordId',
  );
  @override
  late final GeneratedColumn<int> recordId = GeneratedColumn<int>(
    'record_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES transactions (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _versionMeta = const VerificationMeta(
    'version',
  );
  @override
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
    'version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _operatorUserIdMeta = const VerificationMeta(
    'operatorUserId',
  );
  @override
  late final GeneratedColumn<String> operatorUserId = GeneratedColumn<String>(
    'operator_user_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _summaryMeta = const VerificationMeta(
    'summary',
  );
  @override
  late final GeneratedColumn<String> summary = GeneratedColumn<String>(
    'summary',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    recordId,
    version,
    operatorUserId,
    summary,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'record_edit_histories';
  @override
  VerificationContext validateIntegrity(
    Insertable<RecordEditHistory> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('record_id')) {
      context.handle(
        _recordIdMeta,
        recordId.isAcceptableOrUnknown(data['record_id']!, _recordIdMeta),
      );
    } else if (isInserting) {
      context.missing(_recordIdMeta);
    }
    if (data.containsKey('version')) {
      context.handle(
        _versionMeta,
        version.isAcceptableOrUnknown(data['version']!, _versionMeta),
      );
    } else if (isInserting) {
      context.missing(_versionMeta);
    }
    if (data.containsKey('operator_user_id')) {
      context.handle(
        _operatorUserIdMeta,
        operatorUserId.isAcceptableOrUnknown(
          data['operator_user_id']!,
          _operatorUserIdMeta,
        ),
      );
    }
    if (data.containsKey('summary')) {
      context.handle(
        _summaryMeta,
        summary.isAcceptableOrUnknown(data['summary']!, _summaryMeta),
      );
    } else if (isInserting) {
      context.missing(_summaryMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  RecordEditHistory map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RecordEditHistory(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      recordId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}record_id'],
      )!,
      version: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}version'],
      )!,
      operatorUserId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}operator_user_id'],
      ),
      summary: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}summary'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $RecordEditHistoriesTable createAlias(String alias) {
    return $RecordEditHistoriesTable(attachedDatabase, alias);
  }
}

class RecordEditHistory extends DataClass
    implements Insertable<RecordEditHistory> {
  final int id;
  final int recordId;
  final int version;
  final String? operatorUserId;
  final String summary;
  final DateTime createdAt;
  const RecordEditHistory({
    required this.id,
    required this.recordId,
    required this.version,
    this.operatorUserId,
    required this.summary,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['record_id'] = Variable<int>(recordId);
    map['version'] = Variable<int>(version);
    if (!nullToAbsent || operatorUserId != null) {
      map['operator_user_id'] = Variable<String>(operatorUserId);
    }
    map['summary'] = Variable<String>(summary);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  RecordEditHistoriesCompanion toCompanion(bool nullToAbsent) {
    return RecordEditHistoriesCompanion(
      id: Value(id),
      recordId: Value(recordId),
      version: Value(version),
      operatorUserId: operatorUserId == null && nullToAbsent
          ? const Value.absent()
          : Value(operatorUserId),
      summary: Value(summary),
      createdAt: Value(createdAt),
    );
  }

  factory RecordEditHistory.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RecordEditHistory(
      id: serializer.fromJson<int>(json['id']),
      recordId: serializer.fromJson<int>(json['recordId']),
      version: serializer.fromJson<int>(json['version']),
      operatorUserId: serializer.fromJson<String?>(json['operatorUserId']),
      summary: serializer.fromJson<String>(json['summary']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'recordId': serializer.toJson<int>(recordId),
      'version': serializer.toJson<int>(version),
      'operatorUserId': serializer.toJson<String?>(operatorUserId),
      'summary': serializer.toJson<String>(summary),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  RecordEditHistory copyWith({
    int? id,
    int? recordId,
    int? version,
    Value<String?> operatorUserId = const Value.absent(),
    String? summary,
    DateTime? createdAt,
  }) => RecordEditHistory(
    id: id ?? this.id,
    recordId: recordId ?? this.recordId,
    version: version ?? this.version,
    operatorUserId: operatorUserId.present
        ? operatorUserId.value
        : this.operatorUserId,
    summary: summary ?? this.summary,
    createdAt: createdAt ?? this.createdAt,
  );
  RecordEditHistory copyWithCompanion(RecordEditHistoriesCompanion data) {
    return RecordEditHistory(
      id: data.id.present ? data.id.value : this.id,
      recordId: data.recordId.present ? data.recordId.value : this.recordId,
      version: data.version.present ? data.version.value : this.version,
      operatorUserId: data.operatorUserId.present
          ? data.operatorUserId.value
          : this.operatorUserId,
      summary: data.summary.present ? data.summary.value : this.summary,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RecordEditHistory(')
          ..write('id: $id, ')
          ..write('recordId: $recordId, ')
          ..write('version: $version, ')
          ..write('operatorUserId: $operatorUserId, ')
          ..write('summary: $summary, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, recordId, version, operatorUserId, summary, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RecordEditHistory &&
          other.id == this.id &&
          other.recordId == this.recordId &&
          other.version == this.version &&
          other.operatorUserId == this.operatorUserId &&
          other.summary == this.summary &&
          other.createdAt == this.createdAt);
}

class RecordEditHistoriesCompanion extends UpdateCompanion<RecordEditHistory> {
  final Value<int> id;
  final Value<int> recordId;
  final Value<int> version;
  final Value<String?> operatorUserId;
  final Value<String> summary;
  final Value<DateTime> createdAt;
  const RecordEditHistoriesCompanion({
    this.id = const Value.absent(),
    this.recordId = const Value.absent(),
    this.version = const Value.absent(),
    this.operatorUserId = const Value.absent(),
    this.summary = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  RecordEditHistoriesCompanion.insert({
    this.id = const Value.absent(),
    required int recordId,
    required int version,
    this.operatorUserId = const Value.absent(),
    required String summary,
    this.createdAt = const Value.absent(),
  }) : recordId = Value(recordId),
       version = Value(version),
       summary = Value(summary);
  static Insertable<RecordEditHistory> custom({
    Expression<int>? id,
    Expression<int>? recordId,
    Expression<int>? version,
    Expression<String>? operatorUserId,
    Expression<String>? summary,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (recordId != null) 'record_id': recordId,
      if (version != null) 'version': version,
      if (operatorUserId != null) 'operator_user_id': operatorUserId,
      if (summary != null) 'summary': summary,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  RecordEditHistoriesCompanion copyWith({
    Value<int>? id,
    Value<int>? recordId,
    Value<int>? version,
    Value<String?>? operatorUserId,
    Value<String>? summary,
    Value<DateTime>? createdAt,
  }) {
    return RecordEditHistoriesCompanion(
      id: id ?? this.id,
      recordId: recordId ?? this.recordId,
      version: version ?? this.version,
      operatorUserId: operatorUserId ?? this.operatorUserId,
      summary: summary ?? this.summary,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (recordId.present) {
      map['record_id'] = Variable<int>(recordId.value);
    }
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (operatorUserId.present) {
      map['operator_user_id'] = Variable<String>(operatorUserId.value);
    }
    if (summary.present) {
      map['summary'] = Variable<String>(summary.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RecordEditHistoriesCompanion(')
          ..write('id: $id, ')
          ..write('recordId: $recordId, ')
          ..write('version: $version, ')
          ..write('operatorUserId: $operatorUserId, ')
          ..write('summary: $summary, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $LocalChangesTable extends LocalChanges
    with TableInfo<$LocalChangesTable, LocalChange> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalChangesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _entityTypeMeta = const VerificationMeta(
    'entityType',
  );
  @override
  late final GeneratedColumn<String> entityType = GeneratedColumn<String>(
    'entity_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _entityIdMeta = const VerificationMeta(
    'entityId',
  );
  @override
  late final GeneratedColumn<int> entityId = GeneratedColumn<int>(
    'entity_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _entitySyncIdMeta = const VerificationMeta(
    'entitySyncId',
  );
  @override
  late final GeneratedColumn<String> entitySyncId = GeneratedColumn<String>(
    'entity_sync_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _ledgerIdMeta = const VerificationMeta(
    'ledgerId',
  );
  @override
  late final GeneratedColumn<int> ledgerId = GeneratedColumn<int>(
    'ledger_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _actionMeta = const VerificationMeta('action');
  @override
  late final GeneratedColumn<String> action = GeneratedColumn<String>(
    'action',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadJsonMeta = const VerificationMeta(
    'payloadJson',
  );
  @override
  late final GeneratedColumn<String> payloadJson = GeneratedColumn<String>(
    'payload_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _pushedAtMeta = const VerificationMeta(
    'pushedAt',
  );
  @override
  late final GeneratedColumn<DateTime> pushedAt = GeneratedColumn<DateTime>(
    'pushed_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    entityType,
    entityId,
    entitySyncId,
    ledgerId,
    action,
    payloadJson,
    createdAt,
    pushedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_changes';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalChange> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('entity_type')) {
      context.handle(
        _entityTypeMeta,
        entityType.isAcceptableOrUnknown(data['entity_type']!, _entityTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_entityTypeMeta);
    }
    if (data.containsKey('entity_id')) {
      context.handle(
        _entityIdMeta,
        entityId.isAcceptableOrUnknown(data['entity_id']!, _entityIdMeta),
      );
    } else if (isInserting) {
      context.missing(_entityIdMeta);
    }
    if (data.containsKey('entity_sync_id')) {
      context.handle(
        _entitySyncIdMeta,
        entitySyncId.isAcceptableOrUnknown(
          data['entity_sync_id']!,
          _entitySyncIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_entitySyncIdMeta);
    }
    if (data.containsKey('ledger_id')) {
      context.handle(
        _ledgerIdMeta,
        ledgerId.isAcceptableOrUnknown(data['ledger_id']!, _ledgerIdMeta),
      );
    } else if (isInserting) {
      context.missing(_ledgerIdMeta);
    }
    if (data.containsKey('action')) {
      context.handle(
        _actionMeta,
        action.isAcceptableOrUnknown(data['action']!, _actionMeta),
      );
    } else if (isInserting) {
      context.missing(_actionMeta);
    }
    if (data.containsKey('payload_json')) {
      context.handle(
        _payloadJsonMeta,
        payloadJson.isAcceptableOrUnknown(
          data['payload_json']!,
          _payloadJsonMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('pushed_at')) {
      context.handle(
        _pushedAtMeta,
        pushedAt.isAcceptableOrUnknown(data['pushed_at']!, _pushedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LocalChange map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalChange(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      entityType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entity_type'],
      )!,
      entityId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}entity_id'],
      )!,
      entitySyncId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entity_sync_id'],
      )!,
      ledgerId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}ledger_id'],
      )!,
      action: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}action'],
      )!,
      payloadJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload_json'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      pushedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}pushed_at'],
      ),
    );
  }

  @override
  $LocalChangesTable createAlias(String alias) {
    return $LocalChangesTable(attachedDatabase, alias);
  }
}

class LocalChange extends DataClass implements Insertable<LocalChange> {
  final int id;
  final String entityType;
  final int entityId;
  final String entitySyncId;
  final int ledgerId;
  final String action;
  final String? payloadJson;
  final DateTime createdAt;
  final DateTime? pushedAt;
  const LocalChange({
    required this.id,
    required this.entityType,
    required this.entityId,
    required this.entitySyncId,
    required this.ledgerId,
    required this.action,
    this.payloadJson,
    required this.createdAt,
    this.pushedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['entity_type'] = Variable<String>(entityType);
    map['entity_id'] = Variable<int>(entityId);
    map['entity_sync_id'] = Variable<String>(entitySyncId);
    map['ledger_id'] = Variable<int>(ledgerId);
    map['action'] = Variable<String>(action);
    if (!nullToAbsent || payloadJson != null) {
      map['payload_json'] = Variable<String>(payloadJson);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || pushedAt != null) {
      map['pushed_at'] = Variable<DateTime>(pushedAt);
    }
    return map;
  }

  LocalChangesCompanion toCompanion(bool nullToAbsent) {
    return LocalChangesCompanion(
      id: Value(id),
      entityType: Value(entityType),
      entityId: Value(entityId),
      entitySyncId: Value(entitySyncId),
      ledgerId: Value(ledgerId),
      action: Value(action),
      payloadJson: payloadJson == null && nullToAbsent
          ? const Value.absent()
          : Value(payloadJson),
      createdAt: Value(createdAt),
      pushedAt: pushedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(pushedAt),
    );
  }

  factory LocalChange.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalChange(
      id: serializer.fromJson<int>(json['id']),
      entityType: serializer.fromJson<String>(json['entityType']),
      entityId: serializer.fromJson<int>(json['entityId']),
      entitySyncId: serializer.fromJson<String>(json['entitySyncId']),
      ledgerId: serializer.fromJson<int>(json['ledgerId']),
      action: serializer.fromJson<String>(json['action']),
      payloadJson: serializer.fromJson<String?>(json['payloadJson']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      pushedAt: serializer.fromJson<DateTime?>(json['pushedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'entityType': serializer.toJson<String>(entityType),
      'entityId': serializer.toJson<int>(entityId),
      'entitySyncId': serializer.toJson<String>(entitySyncId),
      'ledgerId': serializer.toJson<int>(ledgerId),
      'action': serializer.toJson<String>(action),
      'payloadJson': serializer.toJson<String?>(payloadJson),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'pushedAt': serializer.toJson<DateTime?>(pushedAt),
    };
  }

  LocalChange copyWith({
    int? id,
    String? entityType,
    int? entityId,
    String? entitySyncId,
    int? ledgerId,
    String? action,
    Value<String?> payloadJson = const Value.absent(),
    DateTime? createdAt,
    Value<DateTime?> pushedAt = const Value.absent(),
  }) => LocalChange(
    id: id ?? this.id,
    entityType: entityType ?? this.entityType,
    entityId: entityId ?? this.entityId,
    entitySyncId: entitySyncId ?? this.entitySyncId,
    ledgerId: ledgerId ?? this.ledgerId,
    action: action ?? this.action,
    payloadJson: payloadJson.present ? payloadJson.value : this.payloadJson,
    createdAt: createdAt ?? this.createdAt,
    pushedAt: pushedAt.present ? pushedAt.value : this.pushedAt,
  );
  LocalChange copyWithCompanion(LocalChangesCompanion data) {
    return LocalChange(
      id: data.id.present ? data.id.value : this.id,
      entityType: data.entityType.present
          ? data.entityType.value
          : this.entityType,
      entityId: data.entityId.present ? data.entityId.value : this.entityId,
      entitySyncId: data.entitySyncId.present
          ? data.entitySyncId.value
          : this.entitySyncId,
      ledgerId: data.ledgerId.present ? data.ledgerId.value : this.ledgerId,
      action: data.action.present ? data.action.value : this.action,
      payloadJson: data.payloadJson.present
          ? data.payloadJson.value
          : this.payloadJson,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      pushedAt: data.pushedAt.present ? data.pushedAt.value : this.pushedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalChange(')
          ..write('id: $id, ')
          ..write('entityType: $entityType, ')
          ..write('entityId: $entityId, ')
          ..write('entitySyncId: $entitySyncId, ')
          ..write('ledgerId: $ledgerId, ')
          ..write('action: $action, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('createdAt: $createdAt, ')
          ..write('pushedAt: $pushedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    entityType,
    entityId,
    entitySyncId,
    ledgerId,
    action,
    payloadJson,
    createdAt,
    pushedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalChange &&
          other.id == this.id &&
          other.entityType == this.entityType &&
          other.entityId == this.entityId &&
          other.entitySyncId == this.entitySyncId &&
          other.ledgerId == this.ledgerId &&
          other.action == this.action &&
          other.payloadJson == this.payloadJson &&
          other.createdAt == this.createdAt &&
          other.pushedAt == this.pushedAt);
}

class LocalChangesCompanion extends UpdateCompanion<LocalChange> {
  final Value<int> id;
  final Value<String> entityType;
  final Value<int> entityId;
  final Value<String> entitySyncId;
  final Value<int> ledgerId;
  final Value<String> action;
  final Value<String?> payloadJson;
  final Value<DateTime> createdAt;
  final Value<DateTime?> pushedAt;
  const LocalChangesCompanion({
    this.id = const Value.absent(),
    this.entityType = const Value.absent(),
    this.entityId = const Value.absent(),
    this.entitySyncId = const Value.absent(),
    this.ledgerId = const Value.absent(),
    this.action = const Value.absent(),
    this.payloadJson = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.pushedAt = const Value.absent(),
  });
  LocalChangesCompanion.insert({
    this.id = const Value.absent(),
    required String entityType,
    required int entityId,
    required String entitySyncId,
    required int ledgerId,
    required String action,
    this.payloadJson = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.pushedAt = const Value.absent(),
  }) : entityType = Value(entityType),
       entityId = Value(entityId),
       entitySyncId = Value(entitySyncId),
       ledgerId = Value(ledgerId),
       action = Value(action);
  static Insertable<LocalChange> custom({
    Expression<int>? id,
    Expression<String>? entityType,
    Expression<int>? entityId,
    Expression<String>? entitySyncId,
    Expression<int>? ledgerId,
    Expression<String>? action,
    Expression<String>? payloadJson,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? pushedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (entityType != null) 'entity_type': entityType,
      if (entityId != null) 'entity_id': entityId,
      if (entitySyncId != null) 'entity_sync_id': entitySyncId,
      if (ledgerId != null) 'ledger_id': ledgerId,
      if (action != null) 'action': action,
      if (payloadJson != null) 'payload_json': payloadJson,
      if (createdAt != null) 'created_at': createdAt,
      if (pushedAt != null) 'pushed_at': pushedAt,
    });
  }

  LocalChangesCompanion copyWith({
    Value<int>? id,
    Value<String>? entityType,
    Value<int>? entityId,
    Value<String>? entitySyncId,
    Value<int>? ledgerId,
    Value<String>? action,
    Value<String?>? payloadJson,
    Value<DateTime>? createdAt,
    Value<DateTime?>? pushedAt,
  }) {
    return LocalChangesCompanion(
      id: id ?? this.id,
      entityType: entityType ?? this.entityType,
      entityId: entityId ?? this.entityId,
      entitySyncId: entitySyncId ?? this.entitySyncId,
      ledgerId: ledgerId ?? this.ledgerId,
      action: action ?? this.action,
      payloadJson: payloadJson ?? this.payloadJson,
      createdAt: createdAt ?? this.createdAt,
      pushedAt: pushedAt ?? this.pushedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (entityType.present) {
      map['entity_type'] = Variable<String>(entityType.value);
    }
    if (entityId.present) {
      map['entity_id'] = Variable<int>(entityId.value);
    }
    if (entitySyncId.present) {
      map['entity_sync_id'] = Variable<String>(entitySyncId.value);
    }
    if (ledgerId.present) {
      map['ledger_id'] = Variable<int>(ledgerId.value);
    }
    if (action.present) {
      map['action'] = Variable<String>(action.value);
    }
    if (payloadJson.present) {
      map['payload_json'] = Variable<String>(payloadJson.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (pushedAt.present) {
      map['pushed_at'] = Variable<DateTime>(pushedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalChangesCompanion(')
          ..write('id: $id, ')
          ..write('entityType: $entityType, ')
          ..write('entityId: $entityId, ')
          ..write('entitySyncId: $entitySyncId, ')
          ..write('ledgerId: $ledgerId, ')
          ..write('action: $action, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('createdAt: $createdAt, ')
          ..write('pushedAt: $pushedAt')
          ..write(')'))
        .toString();
  }
}

class $SyncStateTable extends SyncState
    with TableInfo<$SyncStateTable, SyncStateData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncStateTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _deviceIdMeta = const VerificationMeta(
    'deviceId',
  );
  @override
  late final GeneratedColumn<String> deviceId = GeneratedColumn<String>(
    'device_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _providerTypeMeta = const VerificationMeta(
    'providerType',
  );
  @override
  late final GeneratedColumn<String> providerType = GeneratedColumn<String>(
    'provider_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('spitout_cloud'),
  );
  static const VerificationMeta _serverCursorMeta = const VerificationMeta(
    'serverCursor',
  );
  @override
  late final GeneratedColumn<int> serverCursor = GeneratedColumn<int>(
    'server_cursor',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _lastPushAtMeta = const VerificationMeta(
    'lastPushAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastPushAt = GeneratedColumn<DateTime>(
    'last_push_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastPullAtMeta = const VerificationMeta(
    'lastPullAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastPullAt = GeneratedColumn<DateTime>(
    'last_pull_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    deviceId,
    providerType,
    serverCursor,
    lastPushAt,
    lastPullAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_state';
  @override
  VerificationContext validateIntegrity(
    Insertable<SyncStateData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('device_id')) {
      context.handle(
        _deviceIdMeta,
        deviceId.isAcceptableOrUnknown(data['device_id']!, _deviceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_deviceIdMeta);
    }
    if (data.containsKey('provider_type')) {
      context.handle(
        _providerTypeMeta,
        providerType.isAcceptableOrUnknown(
          data['provider_type']!,
          _providerTypeMeta,
        ),
      );
    }
    if (data.containsKey('server_cursor')) {
      context.handle(
        _serverCursorMeta,
        serverCursor.isAcceptableOrUnknown(
          data['server_cursor']!,
          _serverCursorMeta,
        ),
      );
    }
    if (data.containsKey('last_push_at')) {
      context.handle(
        _lastPushAtMeta,
        lastPushAt.isAcceptableOrUnknown(
          data['last_push_at']!,
          _lastPushAtMeta,
        ),
      );
    }
    if (data.containsKey('last_pull_at')) {
      context.handle(
        _lastPullAtMeta,
        lastPullAt.isAcceptableOrUnknown(
          data['last_pull_at']!,
          _lastPullAtMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SyncStateData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncStateData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      deviceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}device_id'],
      )!,
      providerType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}provider_type'],
      )!,
      serverCursor: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}server_cursor'],
      )!,
      lastPushAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_push_at'],
      ),
      lastPullAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_pull_at'],
      ),
    );
  }

  @override
  $SyncStateTable createAlias(String alias) {
    return $SyncStateTable(attachedDatabase, alias);
  }
}

class SyncStateData extends DataClass implements Insertable<SyncStateData> {
  final int id;
  final String deviceId;
  final String providerType;
  final int serverCursor;
  final DateTime? lastPushAt;
  final DateTime? lastPullAt;
  const SyncStateData({
    required this.id,
    required this.deviceId,
    required this.providerType,
    required this.serverCursor,
    this.lastPushAt,
    this.lastPullAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['device_id'] = Variable<String>(deviceId);
    map['provider_type'] = Variable<String>(providerType);
    map['server_cursor'] = Variable<int>(serverCursor);
    if (!nullToAbsent || lastPushAt != null) {
      map['last_push_at'] = Variable<DateTime>(lastPushAt);
    }
    if (!nullToAbsent || lastPullAt != null) {
      map['last_pull_at'] = Variable<DateTime>(lastPullAt);
    }
    return map;
  }

  SyncStateCompanion toCompanion(bool nullToAbsent) {
    return SyncStateCompanion(
      id: Value(id),
      deviceId: Value(deviceId),
      providerType: Value(providerType),
      serverCursor: Value(serverCursor),
      lastPushAt: lastPushAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastPushAt),
      lastPullAt: lastPullAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastPullAt),
    );
  }

  factory SyncStateData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncStateData(
      id: serializer.fromJson<int>(json['id']),
      deviceId: serializer.fromJson<String>(json['deviceId']),
      providerType: serializer.fromJson<String>(json['providerType']),
      serverCursor: serializer.fromJson<int>(json['serverCursor']),
      lastPushAt: serializer.fromJson<DateTime?>(json['lastPushAt']),
      lastPullAt: serializer.fromJson<DateTime?>(json['lastPullAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'deviceId': serializer.toJson<String>(deviceId),
      'providerType': serializer.toJson<String>(providerType),
      'serverCursor': serializer.toJson<int>(serverCursor),
      'lastPushAt': serializer.toJson<DateTime?>(lastPushAt),
      'lastPullAt': serializer.toJson<DateTime?>(lastPullAt),
    };
  }

  SyncStateData copyWith({
    int? id,
    String? deviceId,
    String? providerType,
    int? serverCursor,
    Value<DateTime?> lastPushAt = const Value.absent(),
    Value<DateTime?> lastPullAt = const Value.absent(),
  }) => SyncStateData(
    id: id ?? this.id,
    deviceId: deviceId ?? this.deviceId,
    providerType: providerType ?? this.providerType,
    serverCursor: serverCursor ?? this.serverCursor,
    lastPushAt: lastPushAt.present ? lastPushAt.value : this.lastPushAt,
    lastPullAt: lastPullAt.present ? lastPullAt.value : this.lastPullAt,
  );
  SyncStateData copyWithCompanion(SyncStateCompanion data) {
    return SyncStateData(
      id: data.id.present ? data.id.value : this.id,
      deviceId: data.deviceId.present ? data.deviceId.value : this.deviceId,
      providerType: data.providerType.present
          ? data.providerType.value
          : this.providerType,
      serverCursor: data.serverCursor.present
          ? data.serverCursor.value
          : this.serverCursor,
      lastPushAt: data.lastPushAt.present
          ? data.lastPushAt.value
          : this.lastPushAt,
      lastPullAt: data.lastPullAt.present
          ? data.lastPullAt.value
          : this.lastPullAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncStateData(')
          ..write('id: $id, ')
          ..write('deviceId: $deviceId, ')
          ..write('providerType: $providerType, ')
          ..write('serverCursor: $serverCursor, ')
          ..write('lastPushAt: $lastPushAt, ')
          ..write('lastPullAt: $lastPullAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    deviceId,
    providerType,
    serverCursor,
    lastPushAt,
    lastPullAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncStateData &&
          other.id == this.id &&
          other.deviceId == this.deviceId &&
          other.providerType == this.providerType &&
          other.serverCursor == this.serverCursor &&
          other.lastPushAt == this.lastPushAt &&
          other.lastPullAt == this.lastPullAt);
}

class SyncStateCompanion extends UpdateCompanion<SyncStateData> {
  final Value<int> id;
  final Value<String> deviceId;
  final Value<String> providerType;
  final Value<int> serverCursor;
  final Value<DateTime?> lastPushAt;
  final Value<DateTime?> lastPullAt;
  const SyncStateCompanion({
    this.id = const Value.absent(),
    this.deviceId = const Value.absent(),
    this.providerType = const Value.absent(),
    this.serverCursor = const Value.absent(),
    this.lastPushAt = const Value.absent(),
    this.lastPullAt = const Value.absent(),
  });
  SyncStateCompanion.insert({
    this.id = const Value.absent(),
    required String deviceId,
    this.providerType = const Value.absent(),
    this.serverCursor = const Value.absent(),
    this.lastPushAt = const Value.absent(),
    this.lastPullAt = const Value.absent(),
  }) : deviceId = Value(deviceId);
  static Insertable<SyncStateData> custom({
    Expression<int>? id,
    Expression<String>? deviceId,
    Expression<String>? providerType,
    Expression<int>? serverCursor,
    Expression<DateTime>? lastPushAt,
    Expression<DateTime>? lastPullAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (deviceId != null) 'device_id': deviceId,
      if (providerType != null) 'provider_type': providerType,
      if (serverCursor != null) 'server_cursor': serverCursor,
      if (lastPushAt != null) 'last_push_at': lastPushAt,
      if (lastPullAt != null) 'last_pull_at': lastPullAt,
    });
  }

  SyncStateCompanion copyWith({
    Value<int>? id,
    Value<String>? deviceId,
    Value<String>? providerType,
    Value<int>? serverCursor,
    Value<DateTime?>? lastPushAt,
    Value<DateTime?>? lastPullAt,
  }) {
    return SyncStateCompanion(
      id: id ?? this.id,
      deviceId: deviceId ?? this.deviceId,
      providerType: providerType ?? this.providerType,
      serverCursor: serverCursor ?? this.serverCursor,
      lastPushAt: lastPushAt ?? this.lastPushAt,
      lastPullAt: lastPullAt ?? this.lastPullAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (deviceId.present) {
      map['device_id'] = Variable<String>(deviceId.value);
    }
    if (providerType.present) {
      map['provider_type'] = Variable<String>(providerType.value);
    }
    if (serverCursor.present) {
      map['server_cursor'] = Variable<int>(serverCursor.value);
    }
    if (lastPushAt.present) {
      map['last_push_at'] = Variable<DateTime>(lastPushAt.value);
    }
    if (lastPullAt.present) {
      map['last_pull_at'] = Variable<DateTime>(lastPullAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncStateCompanion(')
          ..write('id: $id, ')
          ..write('deviceId: $deviceId, ')
          ..write('providerType: $providerType, ')
          ..write('serverCursor: $serverCursor, ')
          ..write('lastPushAt: $lastPushAt, ')
          ..write('lastPullAt: $lastPullAt')
          ..write(')'))
        .toString();
  }
}

class $LedgerMembersTable extends LedgerMembers
    with TableInfo<$LedgerMembersTable, LedgerMember> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LedgerMembersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _ledgerSyncIdMeta = const VerificationMeta(
    'ledgerSyncId',
  );
  @override
  late final GeneratedColumn<String> ledgerSyncId = GeneratedColumn<String>(
    'ledger_sync_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
    'user_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _accountMeta = const VerificationMeta(
    'account',
  );
  @override
  late final GeneratedColumn<String> account = GeneratedColumn<String>(
    'account',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _displayNameMeta = const VerificationMeta(
    'displayName',
  );
  @override
  late final GeneratedColumn<String> displayName = GeneratedColumn<String>(
    'display_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _avatarUrlMeta = const VerificationMeta(
    'avatarUrl',
  );
  @override
  late final GeneratedColumn<String> avatarUrl = GeneratedColumn<String>(
    'avatar_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _roleMeta = const VerificationMeta('role');
  @override
  late final GeneratedColumn<String> role = GeneratedColumn<String>(
    'role',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _joinedAtMeta = const VerificationMeta(
    'joinedAt',
  );
  @override
  late final GeneratedColumn<DateTime> joinedAt = GeneratedColumn<DateTime>(
    'joined_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    ledgerSyncId,
    userId,
    account,
    displayName,
    avatarUrl,
    role,
    joinedAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'ledger_members';
  @override
  VerificationContext validateIntegrity(
    Insertable<LedgerMember> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('ledger_sync_id')) {
      context.handle(
        _ledgerSyncIdMeta,
        ledgerSyncId.isAcceptableOrUnknown(
          data['ledger_sync_id']!,
          _ledgerSyncIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_ledgerSyncIdMeta);
    }
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
      );
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('account')) {
      context.handle(
        _accountMeta,
        account.isAcceptableOrUnknown(data['account']!, _accountMeta),
      );
    }
    if (data.containsKey('display_name')) {
      context.handle(
        _displayNameMeta,
        displayName.isAcceptableOrUnknown(
          data['display_name']!,
          _displayNameMeta,
        ),
      );
    }
    if (data.containsKey('avatar_url')) {
      context.handle(
        _avatarUrlMeta,
        avatarUrl.isAcceptableOrUnknown(data['avatar_url']!, _avatarUrlMeta),
      );
    }
    if (data.containsKey('role')) {
      context.handle(
        _roleMeta,
        role.isAcceptableOrUnknown(data['role']!, _roleMeta),
      );
    } else if (isInserting) {
      context.missing(_roleMeta);
    }
    if (data.containsKey('joined_at')) {
      context.handle(
        _joinedAtMeta,
        joinedAt.isAcceptableOrUnknown(data['joined_at']!, _joinedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_joinedAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {ledgerSyncId, userId};
  @override
  LedgerMember map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LedgerMember(
      ledgerSyncId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}ledger_sync_id'],
      )!,
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_id'],
      )!,
      account: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}account'],
      ),
      displayName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}display_name'],
      ),
      avatarUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}avatar_url'],
      ),
      role: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}role'],
      )!,
      joinedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}joined_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $LedgerMembersTable createAlias(String alias) {
    return $LedgerMembersTable(attachedDatabase, alias);
  }
}

class LedgerMember extends DataClass implements Insertable<LedgerMember> {
  final String ledgerSyncId;
  final String userId;
  final String? account;
  final String? displayName;
  final String? avatarUrl;
  final String role;
  final DateTime joinedAt;
  final DateTime updatedAt;
  const LedgerMember({
    required this.ledgerSyncId,
    required this.userId,
    this.account,
    this.displayName,
    this.avatarUrl,
    required this.role,
    required this.joinedAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['ledger_sync_id'] = Variable<String>(ledgerSyncId);
    map['user_id'] = Variable<String>(userId);
    if (!nullToAbsent || account != null) {
      map['account'] = Variable<String>(account);
    }
    if (!nullToAbsent || displayName != null) {
      map['display_name'] = Variable<String>(displayName);
    }
    if (!nullToAbsent || avatarUrl != null) {
      map['avatar_url'] = Variable<String>(avatarUrl);
    }
    map['role'] = Variable<String>(role);
    map['joined_at'] = Variable<DateTime>(joinedAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  LedgerMembersCompanion toCompanion(bool nullToAbsent) {
    return LedgerMembersCompanion(
      ledgerSyncId: Value(ledgerSyncId),
      userId: Value(userId),
      account: account == null && nullToAbsent
          ? const Value.absent()
          : Value(account),
      displayName: displayName == null && nullToAbsent
          ? const Value.absent()
          : Value(displayName),
      avatarUrl: avatarUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(avatarUrl),
      role: Value(role),
      joinedAt: Value(joinedAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory LedgerMember.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LedgerMember(
      ledgerSyncId: serializer.fromJson<String>(json['ledgerSyncId']),
      userId: serializer.fromJson<String>(json['userId']),
      account: serializer.fromJson<String?>(json['account']),
      displayName: serializer.fromJson<String?>(json['displayName']),
      avatarUrl: serializer.fromJson<String?>(json['avatarUrl']),
      role: serializer.fromJson<String>(json['role']),
      joinedAt: serializer.fromJson<DateTime>(json['joinedAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'ledgerSyncId': serializer.toJson<String>(ledgerSyncId),
      'userId': serializer.toJson<String>(userId),
      'account': serializer.toJson<String?>(account),
      'displayName': serializer.toJson<String?>(displayName),
      'avatarUrl': serializer.toJson<String?>(avatarUrl),
      'role': serializer.toJson<String>(role),
      'joinedAt': serializer.toJson<DateTime>(joinedAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  LedgerMember copyWith({
    String? ledgerSyncId,
    String? userId,
    Value<String?> account = const Value.absent(),
    Value<String?> displayName = const Value.absent(),
    Value<String?> avatarUrl = const Value.absent(),
    String? role,
    DateTime? joinedAt,
    DateTime? updatedAt,
  }) => LedgerMember(
    ledgerSyncId: ledgerSyncId ?? this.ledgerSyncId,
    userId: userId ?? this.userId,
    account: account.present ? account.value : this.account,
    displayName: displayName.present ? displayName.value : this.displayName,
    avatarUrl: avatarUrl.present ? avatarUrl.value : this.avatarUrl,
    role: role ?? this.role,
    joinedAt: joinedAt ?? this.joinedAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  LedgerMember copyWithCompanion(LedgerMembersCompanion data) {
    return LedgerMember(
      ledgerSyncId: data.ledgerSyncId.present
          ? data.ledgerSyncId.value
          : this.ledgerSyncId,
      userId: data.userId.present ? data.userId.value : this.userId,
      account: data.account.present ? data.account.value : this.account,
      displayName: data.displayName.present
          ? data.displayName.value
          : this.displayName,
      avatarUrl: data.avatarUrl.present ? data.avatarUrl.value : this.avatarUrl,
      role: data.role.present ? data.role.value : this.role,
      joinedAt: data.joinedAt.present ? data.joinedAt.value : this.joinedAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LedgerMember(')
          ..write('ledgerSyncId: $ledgerSyncId, ')
          ..write('userId: $userId, ')
          ..write('account: $account, ')
          ..write('displayName: $displayName, ')
          ..write('avatarUrl: $avatarUrl, ')
          ..write('role: $role, ')
          ..write('joinedAt: $joinedAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    ledgerSyncId,
    userId,
    account,
    displayName,
    avatarUrl,
    role,
    joinedAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LedgerMember &&
          other.ledgerSyncId == this.ledgerSyncId &&
          other.userId == this.userId &&
          other.account == this.account &&
          other.displayName == this.displayName &&
          other.avatarUrl == this.avatarUrl &&
          other.role == this.role &&
          other.joinedAt == this.joinedAt &&
          other.updatedAt == this.updatedAt);
}

class LedgerMembersCompanion extends UpdateCompanion<LedgerMember> {
  final Value<String> ledgerSyncId;
  final Value<String> userId;
  final Value<String?> account;
  final Value<String?> displayName;
  final Value<String?> avatarUrl;
  final Value<String> role;
  final Value<DateTime> joinedAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const LedgerMembersCompanion({
    this.ledgerSyncId = const Value.absent(),
    this.userId = const Value.absent(),
    this.account = const Value.absent(),
    this.displayName = const Value.absent(),
    this.avatarUrl = const Value.absent(),
    this.role = const Value.absent(),
    this.joinedAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LedgerMembersCompanion.insert({
    required String ledgerSyncId,
    required String userId,
    this.account = const Value.absent(),
    this.displayName = const Value.absent(),
    this.avatarUrl = const Value.absent(),
    required String role,
    required DateTime joinedAt,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : ledgerSyncId = Value(ledgerSyncId),
       userId = Value(userId),
       role = Value(role),
       joinedAt = Value(joinedAt),
       updatedAt = Value(updatedAt);
  static Insertable<LedgerMember> custom({
    Expression<String>? ledgerSyncId,
    Expression<String>? userId,
    Expression<String>? account,
    Expression<String>? displayName,
    Expression<String>? avatarUrl,
    Expression<String>? role,
    Expression<DateTime>? joinedAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (ledgerSyncId != null) 'ledger_sync_id': ledgerSyncId,
      if (userId != null) 'user_id': userId,
      if (account != null) 'account': account,
      if (displayName != null) 'display_name': displayName,
      if (avatarUrl != null) 'avatar_url': avatarUrl,
      if (role != null) 'role': role,
      if (joinedAt != null) 'joined_at': joinedAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LedgerMembersCompanion copyWith({
    Value<String>? ledgerSyncId,
    Value<String>? userId,
    Value<String?>? account,
    Value<String?>? displayName,
    Value<String?>? avatarUrl,
    Value<String>? role,
    Value<DateTime>? joinedAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return LedgerMembersCompanion(
      ledgerSyncId: ledgerSyncId ?? this.ledgerSyncId,
      userId: userId ?? this.userId,
      account: account ?? this.account,
      displayName: displayName ?? this.displayName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      role: role ?? this.role,
      joinedAt: joinedAt ?? this.joinedAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (ledgerSyncId.present) {
      map['ledger_sync_id'] = Variable<String>(ledgerSyncId.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (account.present) {
      map['account'] = Variable<String>(account.value);
    }
    if (displayName.present) {
      map['display_name'] = Variable<String>(displayName.value);
    }
    if (avatarUrl.present) {
      map['avatar_url'] = Variable<String>(avatarUrl.value);
    }
    if (role.present) {
      map['role'] = Variable<String>(role.value);
    }
    if (joinedAt.present) {
      map['joined_at'] = Variable<DateTime>(joinedAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LedgerMembersCompanion(')
          ..write('ledgerSyncId: $ledgerSyncId, ')
          ..write('userId: $userId, ')
          ..write('account: $account, ')
          ..write('displayName: $displayName, ')
          ..write('avatarUrl: $avatarUrl, ')
          ..write('role: $role, ')
          ..write('joinedAt: $joinedAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SharedLedgerCategoriesTable extends SharedLedgerCategories
    with TableInfo<$SharedLedgerCategoriesTable, SharedLedgerCategory> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SharedLedgerCategoriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _ledgerSyncIdMeta = const VerificationMeta(
    'ledgerSyncId',
  );
  @override
  late final GeneratedColumn<String> ledgerSyncId = GeneratedColumn<String>(
    'ledger_sync_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _syncIdMeta = const VerificationMeta('syncId');
  @override
  late final GeneratedColumn<String> syncId = GeneratedColumn<String>(
    'sync_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _iconMeta = const VerificationMeta('icon');
  @override
  late final GeneratedColumn<String> icon = GeneratedColumn<String>(
    'icon',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _colorMeta = const VerificationMeta('color');
  @override
  late final GeneratedColumn<String> color = GeneratedColumn<String>(
    'color',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _levelMeta = const VerificationMeta('level');
  @override
  late final GeneratedColumn<int> level = GeneratedColumn<int>(
    'level',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _parentNameMeta = const VerificationMeta(
    'parentName',
  );
  @override
  late final GeneratedColumn<String> parentName = GeneratedColumn<String>(
    'parent_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _parentSyncIdMeta = const VerificationMeta(
    'parentSyncId',
  );
  @override
  late final GeneratedColumn<String> parentSyncId = GeneratedColumn<String>(
    'parent_sync_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    ledgerSyncId,
    syncId,
    name,
    kind,
    icon,
    color,
    sortOrder,
    level,
    parentName,
    parentSyncId,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'shared_ledger_categories';
  @override
  VerificationContext validateIntegrity(
    Insertable<SharedLedgerCategory> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('ledger_sync_id')) {
      context.handle(
        _ledgerSyncIdMeta,
        ledgerSyncId.isAcceptableOrUnknown(
          data['ledger_sync_id']!,
          _ledgerSyncIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_ledgerSyncIdMeta);
    }
    if (data.containsKey('sync_id')) {
      context.handle(
        _syncIdMeta,
        syncId.isAcceptableOrUnknown(data['sync_id']!, _syncIdMeta),
      );
    } else if (isInserting) {
      context.missing(_syncIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('icon')) {
      context.handle(
        _iconMeta,
        icon.isAcceptableOrUnknown(data['icon']!, _iconMeta),
      );
    }
    if (data.containsKey('color')) {
      context.handle(
        _colorMeta,
        color.isAcceptableOrUnknown(data['color']!, _colorMeta),
      );
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    }
    if (data.containsKey('level')) {
      context.handle(
        _levelMeta,
        level.isAcceptableOrUnknown(data['level']!, _levelMeta),
      );
    }
    if (data.containsKey('parent_name')) {
      context.handle(
        _parentNameMeta,
        parentName.isAcceptableOrUnknown(data['parent_name']!, _parentNameMeta),
      );
    }
    if (data.containsKey('parent_sync_id')) {
      context.handle(
        _parentSyncIdMeta,
        parentSyncId.isAcceptableOrUnknown(
          data['parent_sync_id']!,
          _parentSyncIdMeta,
        ),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {ledgerSyncId, syncId};
  @override
  SharedLedgerCategory map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SharedLedgerCategory(
      ledgerSyncId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}ledger_sync_id'],
      )!,
      syncId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sync_id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      icon: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}icon'],
      ),
      color: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}color'],
      ),
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
      level: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}level'],
      )!,
      parentName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}parent_name'],
      ),
      parentSyncId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}parent_sync_id'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $SharedLedgerCategoriesTable createAlias(String alias) {
    return $SharedLedgerCategoriesTable(attachedDatabase, alias);
  }
}

class SharedLedgerCategory extends DataClass
    implements Insertable<SharedLedgerCategory> {
  final String ledgerSyncId;
  final String syncId;
  final String name;
  final String kind;
  final String? icon;
  final String? color;
  final int sortOrder;
  final int level;
  final String? parentName;
  final String? parentSyncId;
  final DateTime updatedAt;
  const SharedLedgerCategory({
    required this.ledgerSyncId,
    required this.syncId,
    required this.name,
    required this.kind,
    this.icon,
    this.color,
    required this.sortOrder,
    required this.level,
    this.parentName,
    this.parentSyncId,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['ledger_sync_id'] = Variable<String>(ledgerSyncId);
    map['sync_id'] = Variable<String>(syncId);
    map['name'] = Variable<String>(name);
    map['kind'] = Variable<String>(kind);
    if (!nullToAbsent || icon != null) {
      map['icon'] = Variable<String>(icon);
    }
    if (!nullToAbsent || color != null) {
      map['color'] = Variable<String>(color);
    }
    map['sort_order'] = Variable<int>(sortOrder);
    map['level'] = Variable<int>(level);
    if (!nullToAbsent || parentName != null) {
      map['parent_name'] = Variable<String>(parentName);
    }
    if (!nullToAbsent || parentSyncId != null) {
      map['parent_sync_id'] = Variable<String>(parentSyncId);
    }
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  SharedLedgerCategoriesCompanion toCompanion(bool nullToAbsent) {
    return SharedLedgerCategoriesCompanion(
      ledgerSyncId: Value(ledgerSyncId),
      syncId: Value(syncId),
      name: Value(name),
      kind: Value(kind),
      icon: icon == null && nullToAbsent ? const Value.absent() : Value(icon),
      color: color == null && nullToAbsent
          ? const Value.absent()
          : Value(color),
      sortOrder: Value(sortOrder),
      level: Value(level),
      parentName: parentName == null && nullToAbsent
          ? const Value.absent()
          : Value(parentName),
      parentSyncId: parentSyncId == null && nullToAbsent
          ? const Value.absent()
          : Value(parentSyncId),
      updatedAt: Value(updatedAt),
    );
  }

  factory SharedLedgerCategory.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SharedLedgerCategory(
      ledgerSyncId: serializer.fromJson<String>(json['ledgerSyncId']),
      syncId: serializer.fromJson<String>(json['syncId']),
      name: serializer.fromJson<String>(json['name']),
      kind: serializer.fromJson<String>(json['kind']),
      icon: serializer.fromJson<String?>(json['icon']),
      color: serializer.fromJson<String?>(json['color']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      level: serializer.fromJson<int>(json['level']),
      parentName: serializer.fromJson<String?>(json['parentName']),
      parentSyncId: serializer.fromJson<String?>(json['parentSyncId']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'ledgerSyncId': serializer.toJson<String>(ledgerSyncId),
      'syncId': serializer.toJson<String>(syncId),
      'name': serializer.toJson<String>(name),
      'kind': serializer.toJson<String>(kind),
      'icon': serializer.toJson<String?>(icon),
      'color': serializer.toJson<String?>(color),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'level': serializer.toJson<int>(level),
      'parentName': serializer.toJson<String?>(parentName),
      'parentSyncId': serializer.toJson<String?>(parentSyncId),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  SharedLedgerCategory copyWith({
    String? ledgerSyncId,
    String? syncId,
    String? name,
    String? kind,
    Value<String?> icon = const Value.absent(),
    Value<String?> color = const Value.absent(),
    int? sortOrder,
    int? level,
    Value<String?> parentName = const Value.absent(),
    Value<String?> parentSyncId = const Value.absent(),
    DateTime? updatedAt,
  }) => SharedLedgerCategory(
    ledgerSyncId: ledgerSyncId ?? this.ledgerSyncId,
    syncId: syncId ?? this.syncId,
    name: name ?? this.name,
    kind: kind ?? this.kind,
    icon: icon.present ? icon.value : this.icon,
    color: color.present ? color.value : this.color,
    sortOrder: sortOrder ?? this.sortOrder,
    level: level ?? this.level,
    parentName: parentName.present ? parentName.value : this.parentName,
    parentSyncId: parentSyncId.present ? parentSyncId.value : this.parentSyncId,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  SharedLedgerCategory copyWithCompanion(SharedLedgerCategoriesCompanion data) {
    return SharedLedgerCategory(
      ledgerSyncId: data.ledgerSyncId.present
          ? data.ledgerSyncId.value
          : this.ledgerSyncId,
      syncId: data.syncId.present ? data.syncId.value : this.syncId,
      name: data.name.present ? data.name.value : this.name,
      kind: data.kind.present ? data.kind.value : this.kind,
      icon: data.icon.present ? data.icon.value : this.icon,
      color: data.color.present ? data.color.value : this.color,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      level: data.level.present ? data.level.value : this.level,
      parentName: data.parentName.present
          ? data.parentName.value
          : this.parentName,
      parentSyncId: data.parentSyncId.present
          ? data.parentSyncId.value
          : this.parentSyncId,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SharedLedgerCategory(')
          ..write('ledgerSyncId: $ledgerSyncId, ')
          ..write('syncId: $syncId, ')
          ..write('name: $name, ')
          ..write('kind: $kind, ')
          ..write('icon: $icon, ')
          ..write('color: $color, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('level: $level, ')
          ..write('parentName: $parentName, ')
          ..write('parentSyncId: $parentSyncId, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    ledgerSyncId,
    syncId,
    name,
    kind,
    icon,
    color,
    sortOrder,
    level,
    parentName,
    parentSyncId,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SharedLedgerCategory &&
          other.ledgerSyncId == this.ledgerSyncId &&
          other.syncId == this.syncId &&
          other.name == this.name &&
          other.kind == this.kind &&
          other.icon == this.icon &&
          other.color == this.color &&
          other.sortOrder == this.sortOrder &&
          other.level == this.level &&
          other.parentName == this.parentName &&
          other.parentSyncId == this.parentSyncId &&
          other.updatedAt == this.updatedAt);
}

class SharedLedgerCategoriesCompanion
    extends UpdateCompanion<SharedLedgerCategory> {
  final Value<String> ledgerSyncId;
  final Value<String> syncId;
  final Value<String> name;
  final Value<String> kind;
  final Value<String?> icon;
  final Value<String?> color;
  final Value<int> sortOrder;
  final Value<int> level;
  final Value<String?> parentName;
  final Value<String?> parentSyncId;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const SharedLedgerCategoriesCompanion({
    this.ledgerSyncId = const Value.absent(),
    this.syncId = const Value.absent(),
    this.name = const Value.absent(),
    this.kind = const Value.absent(),
    this.icon = const Value.absent(),
    this.color = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.level = const Value.absent(),
    this.parentName = const Value.absent(),
    this.parentSyncId = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SharedLedgerCategoriesCompanion.insert({
    required String ledgerSyncId,
    required String syncId,
    required String name,
    required String kind,
    this.icon = const Value.absent(),
    this.color = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.level = const Value.absent(),
    this.parentName = const Value.absent(),
    this.parentSyncId = const Value.absent(),
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : ledgerSyncId = Value(ledgerSyncId),
       syncId = Value(syncId),
       name = Value(name),
       kind = Value(kind),
       updatedAt = Value(updatedAt);
  static Insertable<SharedLedgerCategory> custom({
    Expression<String>? ledgerSyncId,
    Expression<String>? syncId,
    Expression<String>? name,
    Expression<String>? kind,
    Expression<String>? icon,
    Expression<String>? color,
    Expression<int>? sortOrder,
    Expression<int>? level,
    Expression<String>? parentName,
    Expression<String>? parentSyncId,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (ledgerSyncId != null) 'ledger_sync_id': ledgerSyncId,
      if (syncId != null) 'sync_id': syncId,
      if (name != null) 'name': name,
      if (kind != null) 'kind': kind,
      if (icon != null) 'icon': icon,
      if (color != null) 'color': color,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (level != null) 'level': level,
      if (parentName != null) 'parent_name': parentName,
      if (parentSyncId != null) 'parent_sync_id': parentSyncId,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SharedLedgerCategoriesCompanion copyWith({
    Value<String>? ledgerSyncId,
    Value<String>? syncId,
    Value<String>? name,
    Value<String>? kind,
    Value<String?>? icon,
    Value<String?>? color,
    Value<int>? sortOrder,
    Value<int>? level,
    Value<String?>? parentName,
    Value<String?>? parentSyncId,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return SharedLedgerCategoriesCompanion(
      ledgerSyncId: ledgerSyncId ?? this.ledgerSyncId,
      syncId: syncId ?? this.syncId,
      name: name ?? this.name,
      kind: kind ?? this.kind,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      sortOrder: sortOrder ?? this.sortOrder,
      level: level ?? this.level,
      parentName: parentName ?? this.parentName,
      parentSyncId: parentSyncId ?? this.parentSyncId,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (ledgerSyncId.present) {
      map['ledger_sync_id'] = Variable<String>(ledgerSyncId.value);
    }
    if (syncId.present) {
      map['sync_id'] = Variable<String>(syncId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (icon.present) {
      map['icon'] = Variable<String>(icon.value);
    }
    if (color.present) {
      map['color'] = Variable<String>(color.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (level.present) {
      map['level'] = Variable<int>(level.value);
    }
    if (parentName.present) {
      map['parent_name'] = Variable<String>(parentName.value);
    }
    if (parentSyncId.present) {
      map['parent_sync_id'] = Variable<String>(parentSyncId.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SharedLedgerCategoriesCompanion(')
          ..write('ledgerSyncId: $ledgerSyncId, ')
          ..write('syncId: $syncId, ')
          ..write('name: $name, ')
          ..write('kind: $kind, ')
          ..write('icon: $icon, ')
          ..write('color: $color, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('level: $level, ')
          ..write('parentName: $parentName, ')
          ..write('parentSyncId: $parentSyncId, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SyncPullErrorsTable extends SyncPullErrors
    with TableInfo<$SyncPullErrorsTable, SyncPullError> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncPullErrorsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _changeIdMeta = const VerificationMeta(
    'changeId',
  );
  @override
  late final GeneratedColumn<int> changeId = GeneratedColumn<int>(
    'change_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _ledgerExternalIdMeta = const VerificationMeta(
    'ledgerExternalId',
  );
  @override
  late final GeneratedColumn<String> ledgerExternalId = GeneratedColumn<String>(
    'ledger_external_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _entityTypeMeta = const VerificationMeta(
    'entityType',
  );
  @override
  late final GeneratedColumn<String> entityType = GeneratedColumn<String>(
    'entity_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _entitySyncIdMeta = const VerificationMeta(
    'entitySyncId',
  );
  @override
  late final GeneratedColumn<String> entitySyncId = GeneratedColumn<String>(
    'entity_sync_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _actionMeta = const VerificationMeta('action');
  @override
  late final GeneratedColumn<String> action = GeneratedColumn<String>(
    'action',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _rawChangeJsonMeta = const VerificationMeta(
    'rawChangeJson',
  );
  @override
  late final GeneratedColumn<String> rawChangeJson = GeneratedColumn<String>(
    'raw_change_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _errorClassMeta = const VerificationMeta(
    'errorClass',
  );
  @override
  late final GeneratedColumn<String> errorClass = GeneratedColumn<String>(
    'error_class',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _errorMessageMeta = const VerificationMeta(
    'errorMessage',
  );
  @override
  late final GeneratedColumn<String> errorMessage = GeneratedColumn<String>(
    'error_message',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _stackTraceMeta = const VerificationMeta(
    'stackTrace',
  );
  @override
  late final GeneratedColumn<String> stackTrace = GeneratedColumn<String>(
    'stack_trace',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _firstSeenAtMeta = const VerificationMeta(
    'firstSeenAt',
  );
  @override
  late final GeneratedColumn<DateTime> firstSeenAt = GeneratedColumn<DateTime>(
    'first_seen_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lastAttemptAtMeta = const VerificationMeta(
    'lastAttemptAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastAttemptAt =
      GeneratedColumn<DateTime>(
        'last_attempt_at',
        aliasedName,
        false,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _attemptCountMeta = const VerificationMeta(
    'attemptCount',
  );
  @override
  late final GeneratedColumn<int> attemptCount = GeneratedColumn<int>(
    'attempt_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _userActionMeta = const VerificationMeta(
    'userAction',
  );
  @override
  late final GeneratedColumn<String> userAction = GeneratedColumn<String>(
    'user_action',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _resolvedAtMeta = const VerificationMeta(
    'resolvedAt',
  );
  @override
  late final GeneratedColumn<DateTime> resolvedAt = GeneratedColumn<DateTime>(
    'resolved_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    changeId,
    ledgerExternalId,
    entityType,
    entitySyncId,
    action,
    rawChangeJson,
    errorClass,
    errorMessage,
    stackTrace,
    firstSeenAt,
    lastAttemptAt,
    attemptCount,
    userAction,
    resolvedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_pull_errors';
  @override
  VerificationContext validateIntegrity(
    Insertable<SyncPullError> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('change_id')) {
      context.handle(
        _changeIdMeta,
        changeId.isAcceptableOrUnknown(data['change_id']!, _changeIdMeta),
      );
    } else if (isInserting) {
      context.missing(_changeIdMeta);
    }
    if (data.containsKey('ledger_external_id')) {
      context.handle(
        _ledgerExternalIdMeta,
        ledgerExternalId.isAcceptableOrUnknown(
          data['ledger_external_id']!,
          _ledgerExternalIdMeta,
        ),
      );
    }
    if (data.containsKey('entity_type')) {
      context.handle(
        _entityTypeMeta,
        entityType.isAcceptableOrUnknown(data['entity_type']!, _entityTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_entityTypeMeta);
    }
    if (data.containsKey('entity_sync_id')) {
      context.handle(
        _entitySyncIdMeta,
        entitySyncId.isAcceptableOrUnknown(
          data['entity_sync_id']!,
          _entitySyncIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_entitySyncIdMeta);
    }
    if (data.containsKey('action')) {
      context.handle(
        _actionMeta,
        action.isAcceptableOrUnknown(data['action']!, _actionMeta),
      );
    } else if (isInserting) {
      context.missing(_actionMeta);
    }
    if (data.containsKey('raw_change_json')) {
      context.handle(
        _rawChangeJsonMeta,
        rawChangeJson.isAcceptableOrUnknown(
          data['raw_change_json']!,
          _rawChangeJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_rawChangeJsonMeta);
    }
    if (data.containsKey('error_class')) {
      context.handle(
        _errorClassMeta,
        errorClass.isAcceptableOrUnknown(data['error_class']!, _errorClassMeta),
      );
    }
    if (data.containsKey('error_message')) {
      context.handle(
        _errorMessageMeta,
        errorMessage.isAcceptableOrUnknown(
          data['error_message']!,
          _errorMessageMeta,
        ),
      );
    }
    if (data.containsKey('stack_trace')) {
      context.handle(
        _stackTraceMeta,
        stackTrace.isAcceptableOrUnknown(data['stack_trace']!, _stackTraceMeta),
      );
    }
    if (data.containsKey('first_seen_at')) {
      context.handle(
        _firstSeenAtMeta,
        firstSeenAt.isAcceptableOrUnknown(
          data['first_seen_at']!,
          _firstSeenAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_firstSeenAtMeta);
    }
    if (data.containsKey('last_attempt_at')) {
      context.handle(
        _lastAttemptAtMeta,
        lastAttemptAt.isAcceptableOrUnknown(
          data['last_attempt_at']!,
          _lastAttemptAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_lastAttemptAtMeta);
    }
    if (data.containsKey('attempt_count')) {
      context.handle(
        _attemptCountMeta,
        attemptCount.isAcceptableOrUnknown(
          data['attempt_count']!,
          _attemptCountMeta,
        ),
      );
    }
    if (data.containsKey('user_action')) {
      context.handle(
        _userActionMeta,
        userAction.isAcceptableOrUnknown(data['user_action']!, _userActionMeta),
      );
    }
    if (data.containsKey('resolved_at')) {
      context.handle(
        _resolvedAtMeta,
        resolvedAt.isAcceptableOrUnknown(data['resolved_at']!, _resolvedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SyncPullError map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncPullError(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      changeId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}change_id'],
      )!,
      ledgerExternalId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}ledger_external_id'],
      ),
      entityType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entity_type'],
      )!,
      entitySyncId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entity_sync_id'],
      )!,
      action: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}action'],
      )!,
      rawChangeJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}raw_change_json'],
      )!,
      errorClass: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}error_class'],
      ),
      errorMessage: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}error_message'],
      ),
      stackTrace: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}stack_trace'],
      ),
      firstSeenAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}first_seen_at'],
      )!,
      lastAttemptAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_attempt_at'],
      )!,
      attemptCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}attempt_count'],
      )!,
      userAction: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_action'],
      ),
      resolvedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}resolved_at'],
      ),
    );
  }

  @override
  $SyncPullErrorsTable createAlias(String alias) {
    return $SyncPullErrorsTable(attachedDatabase, alias);
  }
}

class SyncPullError extends DataClass implements Insertable<SyncPullError> {
  final int id;
  final int changeId;
  final String? ledgerExternalId;
  final String entityType;
  final String entitySyncId;
  final String action;
  final String rawChangeJson;
  final String? errorClass;
  final String? errorMessage;
  final String? stackTrace;
  final DateTime firstSeenAt;
  final DateTime lastAttemptAt;
  final int attemptCount;
  final String? userAction;
  final DateTime? resolvedAt;
  const SyncPullError({
    required this.id,
    required this.changeId,
    this.ledgerExternalId,
    required this.entityType,
    required this.entitySyncId,
    required this.action,
    required this.rawChangeJson,
    this.errorClass,
    this.errorMessage,
    this.stackTrace,
    required this.firstSeenAt,
    required this.lastAttemptAt,
    required this.attemptCount,
    this.userAction,
    this.resolvedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['change_id'] = Variable<int>(changeId);
    if (!nullToAbsent || ledgerExternalId != null) {
      map['ledger_external_id'] = Variable<String>(ledgerExternalId);
    }
    map['entity_type'] = Variable<String>(entityType);
    map['entity_sync_id'] = Variable<String>(entitySyncId);
    map['action'] = Variable<String>(action);
    map['raw_change_json'] = Variable<String>(rawChangeJson);
    if (!nullToAbsent || errorClass != null) {
      map['error_class'] = Variable<String>(errorClass);
    }
    if (!nullToAbsent || errorMessage != null) {
      map['error_message'] = Variable<String>(errorMessage);
    }
    if (!nullToAbsent || stackTrace != null) {
      map['stack_trace'] = Variable<String>(stackTrace);
    }
    map['first_seen_at'] = Variable<DateTime>(firstSeenAt);
    map['last_attempt_at'] = Variable<DateTime>(lastAttemptAt);
    map['attempt_count'] = Variable<int>(attemptCount);
    if (!nullToAbsent || userAction != null) {
      map['user_action'] = Variable<String>(userAction);
    }
    if (!nullToAbsent || resolvedAt != null) {
      map['resolved_at'] = Variable<DateTime>(resolvedAt);
    }
    return map;
  }

  SyncPullErrorsCompanion toCompanion(bool nullToAbsent) {
    return SyncPullErrorsCompanion(
      id: Value(id),
      changeId: Value(changeId),
      ledgerExternalId: ledgerExternalId == null && nullToAbsent
          ? const Value.absent()
          : Value(ledgerExternalId),
      entityType: Value(entityType),
      entitySyncId: Value(entitySyncId),
      action: Value(action),
      rawChangeJson: Value(rawChangeJson),
      errorClass: errorClass == null && nullToAbsent
          ? const Value.absent()
          : Value(errorClass),
      errorMessage: errorMessage == null && nullToAbsent
          ? const Value.absent()
          : Value(errorMessage),
      stackTrace: stackTrace == null && nullToAbsent
          ? const Value.absent()
          : Value(stackTrace),
      firstSeenAt: Value(firstSeenAt),
      lastAttemptAt: Value(lastAttemptAt),
      attemptCount: Value(attemptCount),
      userAction: userAction == null && nullToAbsent
          ? const Value.absent()
          : Value(userAction),
      resolvedAt: resolvedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(resolvedAt),
    );
  }

  factory SyncPullError.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncPullError(
      id: serializer.fromJson<int>(json['id']),
      changeId: serializer.fromJson<int>(json['changeId']),
      ledgerExternalId: serializer.fromJson<String?>(json['ledgerExternalId']),
      entityType: serializer.fromJson<String>(json['entityType']),
      entitySyncId: serializer.fromJson<String>(json['entitySyncId']),
      action: serializer.fromJson<String>(json['action']),
      rawChangeJson: serializer.fromJson<String>(json['rawChangeJson']),
      errorClass: serializer.fromJson<String?>(json['errorClass']),
      errorMessage: serializer.fromJson<String?>(json['errorMessage']),
      stackTrace: serializer.fromJson<String?>(json['stackTrace']),
      firstSeenAt: serializer.fromJson<DateTime>(json['firstSeenAt']),
      lastAttemptAt: serializer.fromJson<DateTime>(json['lastAttemptAt']),
      attemptCount: serializer.fromJson<int>(json['attemptCount']),
      userAction: serializer.fromJson<String?>(json['userAction']),
      resolvedAt: serializer.fromJson<DateTime?>(json['resolvedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'changeId': serializer.toJson<int>(changeId),
      'ledgerExternalId': serializer.toJson<String?>(ledgerExternalId),
      'entityType': serializer.toJson<String>(entityType),
      'entitySyncId': serializer.toJson<String>(entitySyncId),
      'action': serializer.toJson<String>(action),
      'rawChangeJson': serializer.toJson<String>(rawChangeJson),
      'errorClass': serializer.toJson<String?>(errorClass),
      'errorMessage': serializer.toJson<String?>(errorMessage),
      'stackTrace': serializer.toJson<String?>(stackTrace),
      'firstSeenAt': serializer.toJson<DateTime>(firstSeenAt),
      'lastAttemptAt': serializer.toJson<DateTime>(lastAttemptAt),
      'attemptCount': serializer.toJson<int>(attemptCount),
      'userAction': serializer.toJson<String?>(userAction),
      'resolvedAt': serializer.toJson<DateTime?>(resolvedAt),
    };
  }

  SyncPullError copyWith({
    int? id,
    int? changeId,
    Value<String?> ledgerExternalId = const Value.absent(),
    String? entityType,
    String? entitySyncId,
    String? action,
    String? rawChangeJson,
    Value<String?> errorClass = const Value.absent(),
    Value<String?> errorMessage = const Value.absent(),
    Value<String?> stackTrace = const Value.absent(),
    DateTime? firstSeenAt,
    DateTime? lastAttemptAt,
    int? attemptCount,
    Value<String?> userAction = const Value.absent(),
    Value<DateTime?> resolvedAt = const Value.absent(),
  }) => SyncPullError(
    id: id ?? this.id,
    changeId: changeId ?? this.changeId,
    ledgerExternalId: ledgerExternalId.present
        ? ledgerExternalId.value
        : this.ledgerExternalId,
    entityType: entityType ?? this.entityType,
    entitySyncId: entitySyncId ?? this.entitySyncId,
    action: action ?? this.action,
    rawChangeJson: rawChangeJson ?? this.rawChangeJson,
    errorClass: errorClass.present ? errorClass.value : this.errorClass,
    errorMessage: errorMessage.present ? errorMessage.value : this.errorMessage,
    stackTrace: stackTrace.present ? stackTrace.value : this.stackTrace,
    firstSeenAt: firstSeenAt ?? this.firstSeenAt,
    lastAttemptAt: lastAttemptAt ?? this.lastAttemptAt,
    attemptCount: attemptCount ?? this.attemptCount,
    userAction: userAction.present ? userAction.value : this.userAction,
    resolvedAt: resolvedAt.present ? resolvedAt.value : this.resolvedAt,
  );
  SyncPullError copyWithCompanion(SyncPullErrorsCompanion data) {
    return SyncPullError(
      id: data.id.present ? data.id.value : this.id,
      changeId: data.changeId.present ? data.changeId.value : this.changeId,
      ledgerExternalId: data.ledgerExternalId.present
          ? data.ledgerExternalId.value
          : this.ledgerExternalId,
      entityType: data.entityType.present
          ? data.entityType.value
          : this.entityType,
      entitySyncId: data.entitySyncId.present
          ? data.entitySyncId.value
          : this.entitySyncId,
      action: data.action.present ? data.action.value : this.action,
      rawChangeJson: data.rawChangeJson.present
          ? data.rawChangeJson.value
          : this.rawChangeJson,
      errorClass: data.errorClass.present
          ? data.errorClass.value
          : this.errorClass,
      errorMessage: data.errorMessage.present
          ? data.errorMessage.value
          : this.errorMessage,
      stackTrace: data.stackTrace.present
          ? data.stackTrace.value
          : this.stackTrace,
      firstSeenAt: data.firstSeenAt.present
          ? data.firstSeenAt.value
          : this.firstSeenAt,
      lastAttemptAt: data.lastAttemptAt.present
          ? data.lastAttemptAt.value
          : this.lastAttemptAt,
      attemptCount: data.attemptCount.present
          ? data.attemptCount.value
          : this.attemptCount,
      userAction: data.userAction.present
          ? data.userAction.value
          : this.userAction,
      resolvedAt: data.resolvedAt.present
          ? data.resolvedAt.value
          : this.resolvedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncPullError(')
          ..write('id: $id, ')
          ..write('changeId: $changeId, ')
          ..write('ledgerExternalId: $ledgerExternalId, ')
          ..write('entityType: $entityType, ')
          ..write('entitySyncId: $entitySyncId, ')
          ..write('action: $action, ')
          ..write('rawChangeJson: $rawChangeJson, ')
          ..write('errorClass: $errorClass, ')
          ..write('errorMessage: $errorMessage, ')
          ..write('stackTrace: $stackTrace, ')
          ..write('firstSeenAt: $firstSeenAt, ')
          ..write('lastAttemptAt: $lastAttemptAt, ')
          ..write('attemptCount: $attemptCount, ')
          ..write('userAction: $userAction, ')
          ..write('resolvedAt: $resolvedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    changeId,
    ledgerExternalId,
    entityType,
    entitySyncId,
    action,
    rawChangeJson,
    errorClass,
    errorMessage,
    stackTrace,
    firstSeenAt,
    lastAttemptAt,
    attemptCount,
    userAction,
    resolvedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncPullError &&
          other.id == this.id &&
          other.changeId == this.changeId &&
          other.ledgerExternalId == this.ledgerExternalId &&
          other.entityType == this.entityType &&
          other.entitySyncId == this.entitySyncId &&
          other.action == this.action &&
          other.rawChangeJson == this.rawChangeJson &&
          other.errorClass == this.errorClass &&
          other.errorMessage == this.errorMessage &&
          other.stackTrace == this.stackTrace &&
          other.firstSeenAt == this.firstSeenAt &&
          other.lastAttemptAt == this.lastAttemptAt &&
          other.attemptCount == this.attemptCount &&
          other.userAction == this.userAction &&
          other.resolvedAt == this.resolvedAt);
}

class SyncPullErrorsCompanion extends UpdateCompanion<SyncPullError> {
  final Value<int> id;
  final Value<int> changeId;
  final Value<String?> ledgerExternalId;
  final Value<String> entityType;
  final Value<String> entitySyncId;
  final Value<String> action;
  final Value<String> rawChangeJson;
  final Value<String?> errorClass;
  final Value<String?> errorMessage;
  final Value<String?> stackTrace;
  final Value<DateTime> firstSeenAt;
  final Value<DateTime> lastAttemptAt;
  final Value<int> attemptCount;
  final Value<String?> userAction;
  final Value<DateTime?> resolvedAt;
  const SyncPullErrorsCompanion({
    this.id = const Value.absent(),
    this.changeId = const Value.absent(),
    this.ledgerExternalId = const Value.absent(),
    this.entityType = const Value.absent(),
    this.entitySyncId = const Value.absent(),
    this.action = const Value.absent(),
    this.rawChangeJson = const Value.absent(),
    this.errorClass = const Value.absent(),
    this.errorMessage = const Value.absent(),
    this.stackTrace = const Value.absent(),
    this.firstSeenAt = const Value.absent(),
    this.lastAttemptAt = const Value.absent(),
    this.attemptCount = const Value.absent(),
    this.userAction = const Value.absent(),
    this.resolvedAt = const Value.absent(),
  });
  SyncPullErrorsCompanion.insert({
    this.id = const Value.absent(),
    required int changeId,
    this.ledgerExternalId = const Value.absent(),
    required String entityType,
    required String entitySyncId,
    required String action,
    required String rawChangeJson,
    this.errorClass = const Value.absent(),
    this.errorMessage = const Value.absent(),
    this.stackTrace = const Value.absent(),
    required DateTime firstSeenAt,
    required DateTime lastAttemptAt,
    this.attemptCount = const Value.absent(),
    this.userAction = const Value.absent(),
    this.resolvedAt = const Value.absent(),
  }) : changeId = Value(changeId),
       entityType = Value(entityType),
       entitySyncId = Value(entitySyncId),
       action = Value(action),
       rawChangeJson = Value(rawChangeJson),
       firstSeenAt = Value(firstSeenAt),
       lastAttemptAt = Value(lastAttemptAt);
  static Insertable<SyncPullError> custom({
    Expression<int>? id,
    Expression<int>? changeId,
    Expression<String>? ledgerExternalId,
    Expression<String>? entityType,
    Expression<String>? entitySyncId,
    Expression<String>? action,
    Expression<String>? rawChangeJson,
    Expression<String>? errorClass,
    Expression<String>? errorMessage,
    Expression<String>? stackTrace,
    Expression<DateTime>? firstSeenAt,
    Expression<DateTime>? lastAttemptAt,
    Expression<int>? attemptCount,
    Expression<String>? userAction,
    Expression<DateTime>? resolvedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (changeId != null) 'change_id': changeId,
      if (ledgerExternalId != null) 'ledger_external_id': ledgerExternalId,
      if (entityType != null) 'entity_type': entityType,
      if (entitySyncId != null) 'entity_sync_id': entitySyncId,
      if (action != null) 'action': action,
      if (rawChangeJson != null) 'raw_change_json': rawChangeJson,
      if (errorClass != null) 'error_class': errorClass,
      if (errorMessage != null) 'error_message': errorMessage,
      if (stackTrace != null) 'stack_trace': stackTrace,
      if (firstSeenAt != null) 'first_seen_at': firstSeenAt,
      if (lastAttemptAt != null) 'last_attempt_at': lastAttemptAt,
      if (attemptCount != null) 'attempt_count': attemptCount,
      if (userAction != null) 'user_action': userAction,
      if (resolvedAt != null) 'resolved_at': resolvedAt,
    });
  }

  SyncPullErrorsCompanion copyWith({
    Value<int>? id,
    Value<int>? changeId,
    Value<String?>? ledgerExternalId,
    Value<String>? entityType,
    Value<String>? entitySyncId,
    Value<String>? action,
    Value<String>? rawChangeJson,
    Value<String?>? errorClass,
    Value<String?>? errorMessage,
    Value<String?>? stackTrace,
    Value<DateTime>? firstSeenAt,
    Value<DateTime>? lastAttemptAt,
    Value<int>? attemptCount,
    Value<String?>? userAction,
    Value<DateTime?>? resolvedAt,
  }) {
    return SyncPullErrorsCompanion(
      id: id ?? this.id,
      changeId: changeId ?? this.changeId,
      ledgerExternalId: ledgerExternalId ?? this.ledgerExternalId,
      entityType: entityType ?? this.entityType,
      entitySyncId: entitySyncId ?? this.entitySyncId,
      action: action ?? this.action,
      rawChangeJson: rawChangeJson ?? this.rawChangeJson,
      errorClass: errorClass ?? this.errorClass,
      errorMessage: errorMessage ?? this.errorMessage,
      stackTrace: stackTrace ?? this.stackTrace,
      firstSeenAt: firstSeenAt ?? this.firstSeenAt,
      lastAttemptAt: lastAttemptAt ?? this.lastAttemptAt,
      attemptCount: attemptCount ?? this.attemptCount,
      userAction: userAction ?? this.userAction,
      resolvedAt: resolvedAt ?? this.resolvedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (changeId.present) {
      map['change_id'] = Variable<int>(changeId.value);
    }
    if (ledgerExternalId.present) {
      map['ledger_external_id'] = Variable<String>(ledgerExternalId.value);
    }
    if (entityType.present) {
      map['entity_type'] = Variable<String>(entityType.value);
    }
    if (entitySyncId.present) {
      map['entity_sync_id'] = Variable<String>(entitySyncId.value);
    }
    if (action.present) {
      map['action'] = Variable<String>(action.value);
    }
    if (rawChangeJson.present) {
      map['raw_change_json'] = Variable<String>(rawChangeJson.value);
    }
    if (errorClass.present) {
      map['error_class'] = Variable<String>(errorClass.value);
    }
    if (errorMessage.present) {
      map['error_message'] = Variable<String>(errorMessage.value);
    }
    if (stackTrace.present) {
      map['stack_trace'] = Variable<String>(stackTrace.value);
    }
    if (firstSeenAt.present) {
      map['first_seen_at'] = Variable<DateTime>(firstSeenAt.value);
    }
    if (lastAttemptAt.present) {
      map['last_attempt_at'] = Variable<DateTime>(lastAttemptAt.value);
    }
    if (attemptCount.present) {
      map['attempt_count'] = Variable<int>(attemptCount.value);
    }
    if (userAction.present) {
      map['user_action'] = Variable<String>(userAction.value);
    }
    if (resolvedAt.present) {
      map['resolved_at'] = Variable<DateTime>(resolvedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncPullErrorsCompanion(')
          ..write('id: $id, ')
          ..write('changeId: $changeId, ')
          ..write('ledgerExternalId: $ledgerExternalId, ')
          ..write('entityType: $entityType, ')
          ..write('entitySyncId: $entitySyncId, ')
          ..write('action: $action, ')
          ..write('rawChangeJson: $rawChangeJson, ')
          ..write('errorClass: $errorClass, ')
          ..write('errorMessage: $errorMessage, ')
          ..write('stackTrace: $stackTrace, ')
          ..write('firstSeenAt: $firstSeenAt, ')
          ..write('lastAttemptAt: $lastAttemptAt, ')
          ..write('attemptCount: $attemptCount, ')
          ..write('userAction: $userAction, ')
          ..write('resolvedAt: $resolvedAt')
          ..write(')'))
        .toString();
  }
}

class $ExchangeRatesTable extends ExchangeRates
    with TableInfo<$ExchangeRatesTable, ExchangeRate> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ExchangeRatesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _baseCurrencyMeta = const VerificationMeta(
    'baseCurrency',
  );
  @override
  late final GeneratedColumn<String> baseCurrency = GeneratedColumn<String>(
    'base_currency',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _quoteCurrencyMeta = const VerificationMeta(
    'quoteCurrency',
  );
  @override
  late final GeneratedColumn<String> quoteCurrency = GeneratedColumn<String>(
    'quote_currency',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _rateDateMeta = const VerificationMeta(
    'rateDate',
  );
  @override
  late final GeneratedColumn<String> rateDate = GeneratedColumn<String>(
    'rate_date',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _rateMeta = const VerificationMeta('rate');
  @override
  late final GeneratedColumn<String> rate = GeneratedColumn<String>(
    'rate',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceMeta = const VerificationMeta('source');
  @override
  late final GeneratedColumn<String> source = GeneratedColumn<String>(
    'source',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fetchedAtMeta = const VerificationMeta(
    'fetchedAt',
  );
  @override
  late final GeneratedColumn<DateTime> fetchedAt = GeneratedColumn<DateTime>(
    'fetched_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    baseCurrency,
    quoteCurrency,
    rateDate,
    rate,
    source,
    fetchedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'exchange_rates';
  @override
  VerificationContext validateIntegrity(
    Insertable<ExchangeRate> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('base_currency')) {
      context.handle(
        _baseCurrencyMeta,
        baseCurrency.isAcceptableOrUnknown(
          data['base_currency']!,
          _baseCurrencyMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_baseCurrencyMeta);
    }
    if (data.containsKey('quote_currency')) {
      context.handle(
        _quoteCurrencyMeta,
        quoteCurrency.isAcceptableOrUnknown(
          data['quote_currency']!,
          _quoteCurrencyMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_quoteCurrencyMeta);
    }
    if (data.containsKey('rate_date')) {
      context.handle(
        _rateDateMeta,
        rateDate.isAcceptableOrUnknown(data['rate_date']!, _rateDateMeta),
      );
    } else if (isInserting) {
      context.missing(_rateDateMeta);
    }
    if (data.containsKey('rate')) {
      context.handle(
        _rateMeta,
        rate.isAcceptableOrUnknown(data['rate']!, _rateMeta),
      );
    } else if (isInserting) {
      context.missing(_rateMeta);
    }
    if (data.containsKey('source')) {
      context.handle(
        _sourceMeta,
        source.isAcceptableOrUnknown(data['source']!, _sourceMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceMeta);
    }
    if (data.containsKey('fetched_at')) {
      context.handle(
        _fetchedAtMeta,
        fetchedAt.isAcceptableOrUnknown(data['fetched_at']!, _fetchedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_fetchedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {
    baseCurrency,
    quoteCurrency,
    rateDate,
  };
  @override
  ExchangeRate map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ExchangeRate(
      baseCurrency: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}base_currency'],
      )!,
      quoteCurrency: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}quote_currency'],
      )!,
      rateDate: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}rate_date'],
      )!,
      rate: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}rate'],
      )!,
      source: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source'],
      )!,
      fetchedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}fetched_at'],
      )!,
    );
  }

  @override
  $ExchangeRatesTable createAlias(String alias) {
    return $ExchangeRatesTable(attachedDatabase, alias);
  }
}

class ExchangeRate extends DataClass implements Insertable<ExchangeRate> {
  final String baseCurrency;
  final String quoteCurrency;
  final String rateDate;
  final String rate;
  final String source;
  final DateTime fetchedAt;
  const ExchangeRate({
    required this.baseCurrency,
    required this.quoteCurrency,
    required this.rateDate,
    required this.rate,
    required this.source,
    required this.fetchedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['base_currency'] = Variable<String>(baseCurrency);
    map['quote_currency'] = Variable<String>(quoteCurrency);
    map['rate_date'] = Variable<String>(rateDate);
    map['rate'] = Variable<String>(rate);
    map['source'] = Variable<String>(source);
    map['fetched_at'] = Variable<DateTime>(fetchedAt);
    return map;
  }

  ExchangeRatesCompanion toCompanion(bool nullToAbsent) {
    return ExchangeRatesCompanion(
      baseCurrency: Value(baseCurrency),
      quoteCurrency: Value(quoteCurrency),
      rateDate: Value(rateDate),
      rate: Value(rate),
      source: Value(source),
      fetchedAt: Value(fetchedAt),
    );
  }

  factory ExchangeRate.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ExchangeRate(
      baseCurrency: serializer.fromJson<String>(json['baseCurrency']),
      quoteCurrency: serializer.fromJson<String>(json['quoteCurrency']),
      rateDate: serializer.fromJson<String>(json['rateDate']),
      rate: serializer.fromJson<String>(json['rate']),
      source: serializer.fromJson<String>(json['source']),
      fetchedAt: serializer.fromJson<DateTime>(json['fetchedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'baseCurrency': serializer.toJson<String>(baseCurrency),
      'quoteCurrency': serializer.toJson<String>(quoteCurrency),
      'rateDate': serializer.toJson<String>(rateDate),
      'rate': serializer.toJson<String>(rate),
      'source': serializer.toJson<String>(source),
      'fetchedAt': serializer.toJson<DateTime>(fetchedAt),
    };
  }

  ExchangeRate copyWith({
    String? baseCurrency,
    String? quoteCurrency,
    String? rateDate,
    String? rate,
    String? source,
    DateTime? fetchedAt,
  }) => ExchangeRate(
    baseCurrency: baseCurrency ?? this.baseCurrency,
    quoteCurrency: quoteCurrency ?? this.quoteCurrency,
    rateDate: rateDate ?? this.rateDate,
    rate: rate ?? this.rate,
    source: source ?? this.source,
    fetchedAt: fetchedAt ?? this.fetchedAt,
  );
  ExchangeRate copyWithCompanion(ExchangeRatesCompanion data) {
    return ExchangeRate(
      baseCurrency: data.baseCurrency.present
          ? data.baseCurrency.value
          : this.baseCurrency,
      quoteCurrency: data.quoteCurrency.present
          ? data.quoteCurrency.value
          : this.quoteCurrency,
      rateDate: data.rateDate.present ? data.rateDate.value : this.rateDate,
      rate: data.rate.present ? data.rate.value : this.rate,
      source: data.source.present ? data.source.value : this.source,
      fetchedAt: data.fetchedAt.present ? data.fetchedAt.value : this.fetchedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ExchangeRate(')
          ..write('baseCurrency: $baseCurrency, ')
          ..write('quoteCurrency: $quoteCurrency, ')
          ..write('rateDate: $rateDate, ')
          ..write('rate: $rate, ')
          ..write('source: $source, ')
          ..write('fetchedAt: $fetchedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    baseCurrency,
    quoteCurrency,
    rateDate,
    rate,
    source,
    fetchedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ExchangeRate &&
          other.baseCurrency == this.baseCurrency &&
          other.quoteCurrency == this.quoteCurrency &&
          other.rateDate == this.rateDate &&
          other.rate == this.rate &&
          other.source == this.source &&
          other.fetchedAt == this.fetchedAt);
}

class ExchangeRatesCompanion extends UpdateCompanion<ExchangeRate> {
  final Value<String> baseCurrency;
  final Value<String> quoteCurrency;
  final Value<String> rateDate;
  final Value<String> rate;
  final Value<String> source;
  final Value<DateTime> fetchedAt;
  final Value<int> rowid;
  const ExchangeRatesCompanion({
    this.baseCurrency = const Value.absent(),
    this.quoteCurrency = const Value.absent(),
    this.rateDate = const Value.absent(),
    this.rate = const Value.absent(),
    this.source = const Value.absent(),
    this.fetchedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ExchangeRatesCompanion.insert({
    required String baseCurrency,
    required String quoteCurrency,
    required String rateDate,
    required String rate,
    required String source,
    required DateTime fetchedAt,
    this.rowid = const Value.absent(),
  }) : baseCurrency = Value(baseCurrency),
       quoteCurrency = Value(quoteCurrency),
       rateDate = Value(rateDate),
       rate = Value(rate),
       source = Value(source),
       fetchedAt = Value(fetchedAt);
  static Insertable<ExchangeRate> custom({
    Expression<String>? baseCurrency,
    Expression<String>? quoteCurrency,
    Expression<String>? rateDate,
    Expression<String>? rate,
    Expression<String>? source,
    Expression<DateTime>? fetchedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (baseCurrency != null) 'base_currency': baseCurrency,
      if (quoteCurrency != null) 'quote_currency': quoteCurrency,
      if (rateDate != null) 'rate_date': rateDate,
      if (rate != null) 'rate': rate,
      if (source != null) 'source': source,
      if (fetchedAt != null) 'fetched_at': fetchedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ExchangeRatesCompanion copyWith({
    Value<String>? baseCurrency,
    Value<String>? quoteCurrency,
    Value<String>? rateDate,
    Value<String>? rate,
    Value<String>? source,
    Value<DateTime>? fetchedAt,
    Value<int>? rowid,
  }) {
    return ExchangeRatesCompanion(
      baseCurrency: baseCurrency ?? this.baseCurrency,
      quoteCurrency: quoteCurrency ?? this.quoteCurrency,
      rateDate: rateDate ?? this.rateDate,
      rate: rate ?? this.rate,
      source: source ?? this.source,
      fetchedAt: fetchedAt ?? this.fetchedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (baseCurrency.present) {
      map['base_currency'] = Variable<String>(baseCurrency.value);
    }
    if (quoteCurrency.present) {
      map['quote_currency'] = Variable<String>(quoteCurrency.value);
    }
    if (rateDate.present) {
      map['rate_date'] = Variable<String>(rateDate.value);
    }
    if (rate.present) {
      map['rate'] = Variable<String>(rate.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(source.value);
    }
    if (fetchedAt.present) {
      map['fetched_at'] = Variable<DateTime>(fetchedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ExchangeRatesCompanion(')
          ..write('baseCurrency: $baseCurrency, ')
          ..write('quoteCurrency: $quoteCurrency, ')
          ..write('rateDate: $rateDate, ')
          ..write('rate: $rate, ')
          ..write('source: $source, ')
          ..write('fetchedAt: $fetchedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ExchangeRateOverridesTable extends ExchangeRateOverrides
    with TableInfo<$ExchangeRateOverridesTable, ExchangeRateOverride> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ExchangeRateOverridesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _syncIdMeta = const VerificationMeta('syncId');
  @override
  late final GeneratedColumn<String> syncId = GeneratedColumn<String>(
    'sync_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _baseCurrencyMeta = const VerificationMeta(
    'baseCurrency',
  );
  @override
  late final GeneratedColumn<String> baseCurrency = GeneratedColumn<String>(
    'base_currency',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _quoteCurrencyMeta = const VerificationMeta(
    'quoteCurrency',
  );
  @override
  late final GeneratedColumn<String> quoteCurrency = GeneratedColumn<String>(
    'quote_currency',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _rateMeta = const VerificationMeta('rate');
  @override
  late final GeneratedColumn<String> rate = GeneratedColumn<String>(
    'rate',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    syncId,
    baseCurrency,
    quoteCurrency,
    rate,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'exchange_rate_overrides';
  @override
  VerificationContext validateIntegrity(
    Insertable<ExchangeRateOverride> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('sync_id')) {
      context.handle(
        _syncIdMeta,
        syncId.isAcceptableOrUnknown(data['sync_id']!, _syncIdMeta),
      );
    }
    if (data.containsKey('base_currency')) {
      context.handle(
        _baseCurrencyMeta,
        baseCurrency.isAcceptableOrUnknown(
          data['base_currency']!,
          _baseCurrencyMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_baseCurrencyMeta);
    }
    if (data.containsKey('quote_currency')) {
      context.handle(
        _quoteCurrencyMeta,
        quoteCurrency.isAcceptableOrUnknown(
          data['quote_currency']!,
          _quoteCurrencyMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_quoteCurrencyMeta);
    }
    if (data.containsKey('rate')) {
      context.handle(
        _rateMeta,
        rate.isAcceptableOrUnknown(data['rate']!, _rateMeta),
      );
    } else if (isInserting) {
      context.missing(_rateMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ExchangeRateOverride map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ExchangeRateOverride(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      syncId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sync_id'],
      ),
      baseCurrency: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}base_currency'],
      )!,
      quoteCurrency: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}quote_currency'],
      )!,
      rate: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}rate'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      ),
    );
  }

  @override
  $ExchangeRateOverridesTable createAlias(String alias) {
    return $ExchangeRateOverridesTable(attachedDatabase, alias);
  }
}

class ExchangeRateOverride extends DataClass
    implements Insertable<ExchangeRateOverride> {
  final int id;
  final String? syncId;
  final String baseCurrency;
  final String quoteCurrency;
  final String rate;
  final DateTime? updatedAt;
  const ExchangeRateOverride({
    required this.id,
    this.syncId,
    required this.baseCurrency,
    required this.quoteCurrency,
    required this.rate,
    this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    if (!nullToAbsent || syncId != null) {
      map['sync_id'] = Variable<String>(syncId);
    }
    map['base_currency'] = Variable<String>(baseCurrency);
    map['quote_currency'] = Variable<String>(quoteCurrency);
    map['rate'] = Variable<String>(rate);
    if (!nullToAbsent || updatedAt != null) {
      map['updated_at'] = Variable<DateTime>(updatedAt);
    }
    return map;
  }

  ExchangeRateOverridesCompanion toCompanion(bool nullToAbsent) {
    return ExchangeRateOverridesCompanion(
      id: Value(id),
      syncId: syncId == null && nullToAbsent
          ? const Value.absent()
          : Value(syncId),
      baseCurrency: Value(baseCurrency),
      quoteCurrency: Value(quoteCurrency),
      rate: Value(rate),
      updatedAt: updatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(updatedAt),
    );
  }

  factory ExchangeRateOverride.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ExchangeRateOverride(
      id: serializer.fromJson<int>(json['id']),
      syncId: serializer.fromJson<String?>(json['syncId']),
      baseCurrency: serializer.fromJson<String>(json['baseCurrency']),
      quoteCurrency: serializer.fromJson<String>(json['quoteCurrency']),
      rate: serializer.fromJson<String>(json['rate']),
      updatedAt: serializer.fromJson<DateTime?>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'syncId': serializer.toJson<String?>(syncId),
      'baseCurrency': serializer.toJson<String>(baseCurrency),
      'quoteCurrency': serializer.toJson<String>(quoteCurrency),
      'rate': serializer.toJson<String>(rate),
      'updatedAt': serializer.toJson<DateTime?>(updatedAt),
    };
  }

  ExchangeRateOverride copyWith({
    int? id,
    Value<String?> syncId = const Value.absent(),
    String? baseCurrency,
    String? quoteCurrency,
    String? rate,
    Value<DateTime?> updatedAt = const Value.absent(),
  }) => ExchangeRateOverride(
    id: id ?? this.id,
    syncId: syncId.present ? syncId.value : this.syncId,
    baseCurrency: baseCurrency ?? this.baseCurrency,
    quoteCurrency: quoteCurrency ?? this.quoteCurrency,
    rate: rate ?? this.rate,
    updatedAt: updatedAt.present ? updatedAt.value : this.updatedAt,
  );
  ExchangeRateOverride copyWithCompanion(ExchangeRateOverridesCompanion data) {
    return ExchangeRateOverride(
      id: data.id.present ? data.id.value : this.id,
      syncId: data.syncId.present ? data.syncId.value : this.syncId,
      baseCurrency: data.baseCurrency.present
          ? data.baseCurrency.value
          : this.baseCurrency,
      quoteCurrency: data.quoteCurrency.present
          ? data.quoteCurrency.value
          : this.quoteCurrency,
      rate: data.rate.present ? data.rate.value : this.rate,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ExchangeRateOverride(')
          ..write('id: $id, ')
          ..write('syncId: $syncId, ')
          ..write('baseCurrency: $baseCurrency, ')
          ..write('quoteCurrency: $quoteCurrency, ')
          ..write('rate: $rate, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, syncId, baseCurrency, quoteCurrency, rate, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ExchangeRateOverride &&
          other.id == this.id &&
          other.syncId == this.syncId &&
          other.baseCurrency == this.baseCurrency &&
          other.quoteCurrency == this.quoteCurrency &&
          other.rate == this.rate &&
          other.updatedAt == this.updatedAt);
}

class ExchangeRateOverridesCompanion
    extends UpdateCompanion<ExchangeRateOverride> {
  final Value<int> id;
  final Value<String?> syncId;
  final Value<String> baseCurrency;
  final Value<String> quoteCurrency;
  final Value<String> rate;
  final Value<DateTime?> updatedAt;
  const ExchangeRateOverridesCompanion({
    this.id = const Value.absent(),
    this.syncId = const Value.absent(),
    this.baseCurrency = const Value.absent(),
    this.quoteCurrency = const Value.absent(),
    this.rate = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  ExchangeRateOverridesCompanion.insert({
    this.id = const Value.absent(),
    this.syncId = const Value.absent(),
    required String baseCurrency,
    required String quoteCurrency,
    required String rate,
    this.updatedAt = const Value.absent(),
  }) : baseCurrency = Value(baseCurrency),
       quoteCurrency = Value(quoteCurrency),
       rate = Value(rate);
  static Insertable<ExchangeRateOverride> custom({
    Expression<int>? id,
    Expression<String>? syncId,
    Expression<String>? baseCurrency,
    Expression<String>? quoteCurrency,
    Expression<String>? rate,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (syncId != null) 'sync_id': syncId,
      if (baseCurrency != null) 'base_currency': baseCurrency,
      if (quoteCurrency != null) 'quote_currency': quoteCurrency,
      if (rate != null) 'rate': rate,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  ExchangeRateOverridesCompanion copyWith({
    Value<int>? id,
    Value<String?>? syncId,
    Value<String>? baseCurrency,
    Value<String>? quoteCurrency,
    Value<String>? rate,
    Value<DateTime?>? updatedAt,
  }) {
    return ExchangeRateOverridesCompanion(
      id: id ?? this.id,
      syncId: syncId ?? this.syncId,
      baseCurrency: baseCurrency ?? this.baseCurrency,
      quoteCurrency: quoteCurrency ?? this.quoteCurrency,
      rate: rate ?? this.rate,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (syncId.present) {
      map['sync_id'] = Variable<String>(syncId.value);
    }
    if (baseCurrency.present) {
      map['base_currency'] = Variable<String>(baseCurrency.value);
    }
    if (quoteCurrency.present) {
      map['quote_currency'] = Variable<String>(quoteCurrency.value);
    }
    if (rate.present) {
      map['rate'] = Variable<String>(rate.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ExchangeRateOverridesCompanion(')
          ..write('id: $id, ')
          ..write('syncId: $syncId, ')
          ..write('baseCurrency: $baseCurrency, ')
          ..write('quoteCurrency: $quoteCurrency, ')
          ..write('rate: $rate, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $SnapshotDirtyLedgersTable extends SnapshotDirtyLedgers
    with TableInfo<$SnapshotDirtyLedgersTable, SnapshotDirtyLedger> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SnapshotDirtyLedgersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _ledgerIdMeta = const VerificationMeta(
    'ledgerId',
  );
  @override
  late final GeneratedColumn<int> ledgerId = GeneratedColumn<int>(
    'ledger_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _dirtyAtMeta = const VerificationMeta(
    'dirtyAt',
  );
  @override
  late final GeneratedColumn<DateTime> dirtyAt = GeneratedColumn<DateTime>(
    'dirty_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [ledgerId, dirtyAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'snapshot_dirty_ledgers';
  @override
  VerificationContext validateIntegrity(
    Insertable<SnapshotDirtyLedger> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('ledger_id')) {
      context.handle(
        _ledgerIdMeta,
        ledgerId.isAcceptableOrUnknown(data['ledger_id']!, _ledgerIdMeta),
      );
    }
    if (data.containsKey('dirty_at')) {
      context.handle(
        _dirtyAtMeta,
        dirtyAt.isAcceptableOrUnknown(data['dirty_at']!, _dirtyAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {ledgerId};
  @override
  SnapshotDirtyLedger map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SnapshotDirtyLedger(
      ledgerId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}ledger_id'],
      )!,
      dirtyAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}dirty_at'],
      )!,
    );
  }

  @override
  $SnapshotDirtyLedgersTable createAlias(String alias) {
    return $SnapshotDirtyLedgersTable(attachedDatabase, alias);
  }
}

class SnapshotDirtyLedger extends DataClass
    implements Insertable<SnapshotDirtyLedger> {
  /// 脏账本的本地 id(对应 ledgers.id)。主键,同账本只留一行。
  final int ledgerId;

  /// 首次标记脏的时间,用于排序与诊断。重复标记不更新(INSERT OR IGNORE)。
  final DateTime dirtyAt;
  const SnapshotDirtyLedger({required this.ledgerId, required this.dirtyAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['ledger_id'] = Variable<int>(ledgerId);
    map['dirty_at'] = Variable<DateTime>(dirtyAt);
    return map;
  }

  SnapshotDirtyLedgersCompanion toCompanion(bool nullToAbsent) {
    return SnapshotDirtyLedgersCompanion(
      ledgerId: Value(ledgerId),
      dirtyAt: Value(dirtyAt),
    );
  }

  factory SnapshotDirtyLedger.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SnapshotDirtyLedger(
      ledgerId: serializer.fromJson<int>(json['ledgerId']),
      dirtyAt: serializer.fromJson<DateTime>(json['dirtyAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'ledgerId': serializer.toJson<int>(ledgerId),
      'dirtyAt': serializer.toJson<DateTime>(dirtyAt),
    };
  }

  SnapshotDirtyLedger copyWith({int? ledgerId, DateTime? dirtyAt}) =>
      SnapshotDirtyLedger(
        ledgerId: ledgerId ?? this.ledgerId,
        dirtyAt: dirtyAt ?? this.dirtyAt,
      );
  SnapshotDirtyLedger copyWithCompanion(SnapshotDirtyLedgersCompanion data) {
    return SnapshotDirtyLedger(
      ledgerId: data.ledgerId.present ? data.ledgerId.value : this.ledgerId,
      dirtyAt: data.dirtyAt.present ? data.dirtyAt.value : this.dirtyAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SnapshotDirtyLedger(')
          ..write('ledgerId: $ledgerId, ')
          ..write('dirtyAt: $dirtyAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(ledgerId, dirtyAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SnapshotDirtyLedger &&
          other.ledgerId == this.ledgerId &&
          other.dirtyAt == this.dirtyAt);
}

class SnapshotDirtyLedgersCompanion
    extends UpdateCompanion<SnapshotDirtyLedger> {
  final Value<int> ledgerId;
  final Value<DateTime> dirtyAt;
  const SnapshotDirtyLedgersCompanion({
    this.ledgerId = const Value.absent(),
    this.dirtyAt = const Value.absent(),
  });
  SnapshotDirtyLedgersCompanion.insert({
    this.ledgerId = const Value.absent(),
    this.dirtyAt = const Value.absent(),
  });
  static Insertable<SnapshotDirtyLedger> custom({
    Expression<int>? ledgerId,
    Expression<DateTime>? dirtyAt,
  }) {
    return RawValuesInsertable({
      if (ledgerId != null) 'ledger_id': ledgerId,
      if (dirtyAt != null) 'dirty_at': dirtyAt,
    });
  }

  SnapshotDirtyLedgersCompanion copyWith({
    Value<int>? ledgerId,
    Value<DateTime>? dirtyAt,
  }) {
    return SnapshotDirtyLedgersCompanion(
      ledgerId: ledgerId ?? this.ledgerId,
      dirtyAt: dirtyAt ?? this.dirtyAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (ledgerId.present) {
      map['ledger_id'] = Variable<int>(ledgerId.value);
    }
    if (dirtyAt.present) {
      map['dirty_at'] = Variable<DateTime>(dirtyAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SnapshotDirtyLedgersCompanion(')
          ..write('ledgerId: $ledgerId, ')
          ..write('dirtyAt: $dirtyAt')
          ..write(')'))
        .toString();
  }
}

class $LedgerVirtualUsersTable extends LedgerVirtualUsers
    with TableInfo<$LedgerVirtualUsersTable, LedgerVirtualUser> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LedgerVirtualUsersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _ledgerIdMeta = const VerificationMeta(
    'ledgerId',
  );
  @override
  late final GeneratedColumn<int> ledgerId = GeneratedColumn<int>(
    'ledger_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _syncIdMeta = const VerificationMeta('syncId');
  @override
  late final GeneratedColumn<String> syncId = GeneratedColumn<String>(
    'sync_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    ledgerId,
    syncId,
    name,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'ledger_virtual_users';
  @override
  VerificationContext validateIntegrity(
    Insertable<LedgerVirtualUser> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('ledger_id')) {
      context.handle(
        _ledgerIdMeta,
        ledgerId.isAcceptableOrUnknown(data['ledger_id']!, _ledgerIdMeta),
      );
    } else if (isInserting) {
      context.missing(_ledgerIdMeta);
    }
    if (data.containsKey('sync_id')) {
      context.handle(
        _syncIdMeta,
        syncId.isAcceptableOrUnknown(data['sync_id']!, _syncIdMeta),
      );
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LedgerVirtualUser map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LedgerVirtualUser(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      ledgerId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}ledger_id'],
      )!,
      syncId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sync_id'],
      ),
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      ),
    );
  }

  @override
  $LedgerVirtualUsersTable createAlias(String alias) {
    return $LedgerVirtualUsersTable(attachedDatabase, alias);
  }
}

class LedgerVirtualUser extends DataClass
    implements Insertable<LedgerVirtualUser> {
  /// 本地主键。
  final int id;

  /// 所属账本(逻辑关联 ledgers.id,不做 SQL 外键)。
  final int ledgerId;

  /// 跨设备唯一标识(UUID),与 server 端 virtual_user 投影对齐。
  /// 本地新建时填 UUID;sync pull 时写回 server 下发的 syncId。
  final String? syncId;

  /// 虚拟用户昵称。
  final String name;

  /// 创建时间。
  final DateTime createdAt;

  /// 修改时间。
  final DateTime? updatedAt;
  const LedgerVirtualUser({
    required this.id,
    required this.ledgerId,
    this.syncId,
    required this.name,
    required this.createdAt,
    this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['ledger_id'] = Variable<int>(ledgerId);
    if (!nullToAbsent || syncId != null) {
      map['sync_id'] = Variable<String>(syncId);
    }
    map['name'] = Variable<String>(name);
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || updatedAt != null) {
      map['updated_at'] = Variable<DateTime>(updatedAt);
    }
    return map;
  }

  LedgerVirtualUsersCompanion toCompanion(bool nullToAbsent) {
    return LedgerVirtualUsersCompanion(
      id: Value(id),
      ledgerId: Value(ledgerId),
      syncId: syncId == null && nullToAbsent
          ? const Value.absent()
          : Value(syncId),
      name: Value(name),
      createdAt: Value(createdAt),
      updatedAt: updatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(updatedAt),
    );
  }

  factory LedgerVirtualUser.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LedgerVirtualUser(
      id: serializer.fromJson<int>(json['id']),
      ledgerId: serializer.fromJson<int>(json['ledgerId']),
      syncId: serializer.fromJson<String?>(json['syncId']),
      name: serializer.fromJson<String>(json['name']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime?>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'ledgerId': serializer.toJson<int>(ledgerId),
      'syncId': serializer.toJson<String?>(syncId),
      'name': serializer.toJson<String>(name),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime?>(updatedAt),
    };
  }

  LedgerVirtualUser copyWith({
    int? id,
    int? ledgerId,
    Value<String?> syncId = const Value.absent(),
    String? name,
    DateTime? createdAt,
    Value<DateTime?> updatedAt = const Value.absent(),
  }) => LedgerVirtualUser(
    id: id ?? this.id,
    ledgerId: ledgerId ?? this.ledgerId,
    syncId: syncId.present ? syncId.value : this.syncId,
    name: name ?? this.name,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt.present ? updatedAt.value : this.updatedAt,
  );
  LedgerVirtualUser copyWithCompanion(LedgerVirtualUsersCompanion data) {
    return LedgerVirtualUser(
      id: data.id.present ? data.id.value : this.id,
      ledgerId: data.ledgerId.present ? data.ledgerId.value : this.ledgerId,
      syncId: data.syncId.present ? data.syncId.value : this.syncId,
      name: data.name.present ? data.name.value : this.name,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LedgerVirtualUser(')
          ..write('id: $id, ')
          ..write('ledgerId: $ledgerId, ')
          ..write('syncId: $syncId, ')
          ..write('name: $name, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, ledgerId, syncId, name, createdAt, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LedgerVirtualUser &&
          other.id == this.id &&
          other.ledgerId == this.ledgerId &&
          other.syncId == this.syncId &&
          other.name == this.name &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class LedgerVirtualUsersCompanion extends UpdateCompanion<LedgerVirtualUser> {
  final Value<int> id;
  final Value<int> ledgerId;
  final Value<String?> syncId;
  final Value<String> name;
  final Value<DateTime> createdAt;
  final Value<DateTime?> updatedAt;
  const LedgerVirtualUsersCompanion({
    this.id = const Value.absent(),
    this.ledgerId = const Value.absent(),
    this.syncId = const Value.absent(),
    this.name = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  LedgerVirtualUsersCompanion.insert({
    this.id = const Value.absent(),
    required int ledgerId,
    this.syncId = const Value.absent(),
    required String name,
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  }) : ledgerId = Value(ledgerId),
       name = Value(name);
  static Insertable<LedgerVirtualUser> custom({
    Expression<int>? id,
    Expression<int>? ledgerId,
    Expression<String>? syncId,
    Expression<String>? name,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (ledgerId != null) 'ledger_id': ledgerId,
      if (syncId != null) 'sync_id': syncId,
      if (name != null) 'name': name,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  LedgerVirtualUsersCompanion copyWith({
    Value<int>? id,
    Value<int>? ledgerId,
    Value<String?>? syncId,
    Value<String>? name,
    Value<DateTime>? createdAt,
    Value<DateTime?>? updatedAt,
  }) {
    return LedgerVirtualUsersCompanion(
      id: id ?? this.id,
      ledgerId: ledgerId ?? this.ledgerId,
      syncId: syncId ?? this.syncId,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (ledgerId.present) {
      map['ledger_id'] = Variable<int>(ledgerId.value);
    }
    if (syncId.present) {
      map['sync_id'] = Variable<String>(syncId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LedgerVirtualUsersCompanion(')
          ..write('id: $id, ')
          ..write('ledgerId: $ledgerId, ')
          ..write('syncId: $syncId, ')
          ..write('name: $name, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

abstract class _$SpitoutDatabase extends GeneratedDatabase {
  _$SpitoutDatabase(QueryExecutor e) : super(e);
  $SpitoutDatabaseManager get managers => $SpitoutDatabaseManager(this);
  late final $LedgersTable ledgers = $LedgersTable(this);
  late final $CategoriesTable categories = $CategoriesTable(this);
  late final $RecurringTransactionsTable recurringTransactions =
      $RecurringTransactionsTable(this);
  late final $TransactionsTable transactions = $TransactionsTable(this);
  late final $RecordEditHistoriesTable recordEditHistories =
      $RecordEditHistoriesTable(this);
  late final $LocalChangesTable localChanges = $LocalChangesTable(this);
  late final $SyncStateTable syncState = $SyncStateTable(this);
  late final $LedgerMembersTable ledgerMembers = $LedgerMembersTable(this);
  late final $SharedLedgerCategoriesTable sharedLedgerCategories =
      $SharedLedgerCategoriesTable(this);
  late final $SyncPullErrorsTable syncPullErrors = $SyncPullErrorsTable(this);
  late final $ExchangeRatesTable exchangeRates = $ExchangeRatesTable(this);
  late final $ExchangeRateOverridesTable exchangeRateOverrides =
      $ExchangeRateOverridesTable(this);
  late final $SnapshotDirtyLedgersTable snapshotDirtyLedgers =
      $SnapshotDirtyLedgersTable(this);
  late final $LedgerVirtualUsersTable ledgerVirtualUsers =
      $LedgerVirtualUsersTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    ledgers,
    categories,
    recurringTransactions,
    transactions,
    recordEditHistories,
    localChanges,
    syncState,
    ledgerMembers,
    sharedLedgerCategories,
    syncPullErrors,
    exchangeRates,
    exchangeRateOverrides,
    snapshotDirtyLedgers,
    ledgerVirtualUsers,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'ledgers',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('recurring_transactions', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'ledgers',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('transactions', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'categories',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('transactions', kind: UpdateKind.update)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'recurring_transactions',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('transactions', kind: UpdateKind.update)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'transactions',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('record_edit_histories', kind: UpdateKind.delete)],
    ),
  ]);
}

typedef $$LedgersTableCreateCompanionBuilder =
    LedgersCompanion Function({
      Value<int> id,
      required String name,
      Value<String> currency,
      Value<String> type,
      Value<DateTime> createdAt,
      Value<String?> syncId,
      Value<String> myRole,
      Value<int> memberCount,
      Value<bool> isShared,
      Value<String?> ownerUserId,
      Value<int> monthStartDay,
      Value<String> storageMode,
      Value<bool> aaEnabled,
    });
typedef $$LedgersTableUpdateCompanionBuilder =
    LedgersCompanion Function({
      Value<int> id,
      Value<String> name,
      Value<String> currency,
      Value<String> type,
      Value<DateTime> createdAt,
      Value<String?> syncId,
      Value<String> myRole,
      Value<int> memberCount,
      Value<bool> isShared,
      Value<String?> ownerUserId,
      Value<int> monthStartDay,
      Value<String> storageMode,
      Value<bool> aaEnabled,
    });

final class $$LedgersTableReferences
    extends BaseReferences<_$SpitoutDatabase, $LedgersTable, Ledger> {
  $$LedgersTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<
    $RecurringTransactionsTable,
    List<RecurringTransaction>
  >
  _recurringTransactionsRefsTable(_$SpitoutDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.recurringTransactions,
        aliasName: 'ledgers__id__recurring_transactions__ledger_id',
      );

  $$RecurringTransactionsTableProcessedTableManager
  get recurringTransactionsRefs {
    final manager = $$RecurringTransactionsTableTableManager(
      $_db,
      $_db.recurringTransactions,
    ).filter((f) => f.ledgerId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _recurringTransactionsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$TransactionsTable, List<Transaction>>
  _transactionsRefsTable(_$SpitoutDatabase db) => MultiTypedResultKey.fromTable(
    db.transactions,
    aliasName: 'ledgers__id__transactions__ledger_id',
  );

  $$TransactionsTableProcessedTableManager get transactionsRefs {
    final manager = $$TransactionsTableTableManager(
      $_db,
      $_db.transactions,
    ).filter((f) => f.ledgerId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_transactionsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$LedgersTableFilterComposer
    extends Composer<_$SpitoutDatabase, $LedgersTable> {
  $$LedgersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get currency => $composableBuilder(
    column: $table.currency,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get syncId => $composableBuilder(
    column: $table.syncId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get myRole => $composableBuilder(
    column: $table.myRole,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get memberCount => $composableBuilder(
    column: $table.memberCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isShared => $composableBuilder(
    column: $table.isShared,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ownerUserId => $composableBuilder(
    column: $table.ownerUserId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get monthStartDay => $composableBuilder(
    column: $table.monthStartDay,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get storageMode => $composableBuilder(
    column: $table.storageMode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get aaEnabled => $composableBuilder(
    column: $table.aaEnabled,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> recurringTransactionsRefs(
    Expression<bool> Function($$RecurringTransactionsTableFilterComposer f) f,
  ) {
    final $$RecurringTransactionsTableFilterComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.recurringTransactions,
          getReferencedColumn: (t) => t.ledgerId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$RecurringTransactionsTableFilterComposer(
                $db: $db,
                $table: $db.recurringTransactions,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<bool> transactionsRefs(
    Expression<bool> Function($$TransactionsTableFilterComposer f) f,
  ) {
    final $$TransactionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.transactions,
      getReferencedColumn: (t) => t.ledgerId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TransactionsTableFilterComposer(
            $db: $db,
            $table: $db.transactions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$LedgersTableOrderingComposer
    extends Composer<_$SpitoutDatabase, $LedgersTable> {
  $$LedgersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get currency => $composableBuilder(
    column: $table.currency,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get syncId => $composableBuilder(
    column: $table.syncId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get myRole => $composableBuilder(
    column: $table.myRole,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get memberCount => $composableBuilder(
    column: $table.memberCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isShared => $composableBuilder(
    column: $table.isShared,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ownerUserId => $composableBuilder(
    column: $table.ownerUserId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get monthStartDay => $composableBuilder(
    column: $table.monthStartDay,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get storageMode => $composableBuilder(
    column: $table.storageMode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get aaEnabled => $composableBuilder(
    column: $table.aaEnabled,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LedgersTableAnnotationComposer
    extends Composer<_$SpitoutDatabase, $LedgersTable> {
  $$LedgersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get currency =>
      $composableBuilder(column: $table.currency, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get syncId =>
      $composableBuilder(column: $table.syncId, builder: (column) => column);

  GeneratedColumn<String> get myRole =>
      $composableBuilder(column: $table.myRole, builder: (column) => column);

  GeneratedColumn<int> get memberCount => $composableBuilder(
    column: $table.memberCount,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isShared =>
      $composableBuilder(column: $table.isShared, builder: (column) => column);

  GeneratedColumn<String> get ownerUserId => $composableBuilder(
    column: $table.ownerUserId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get monthStartDay => $composableBuilder(
    column: $table.monthStartDay,
    builder: (column) => column,
  );

  GeneratedColumn<String> get storageMode => $composableBuilder(
    column: $table.storageMode,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get aaEnabled =>
      $composableBuilder(column: $table.aaEnabled, builder: (column) => column);

  Expression<T> recurringTransactionsRefs<T extends Object>(
    Expression<T> Function($$RecurringTransactionsTableAnnotationComposer a) f,
  ) {
    final $$RecurringTransactionsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.recurringTransactions,
          getReferencedColumn: (t) => t.ledgerId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$RecurringTransactionsTableAnnotationComposer(
                $db: $db,
                $table: $db.recurringTransactions,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<T> transactionsRefs<T extends Object>(
    Expression<T> Function($$TransactionsTableAnnotationComposer a) f,
  ) {
    final $$TransactionsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.transactions,
      getReferencedColumn: (t) => t.ledgerId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TransactionsTableAnnotationComposer(
            $db: $db,
            $table: $db.transactions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$LedgersTableTableManager
    extends
        RootTableManager<
          _$SpitoutDatabase,
          $LedgersTable,
          Ledger,
          $$LedgersTableFilterComposer,
          $$LedgersTableOrderingComposer,
          $$LedgersTableAnnotationComposer,
          $$LedgersTableCreateCompanionBuilder,
          $$LedgersTableUpdateCompanionBuilder,
          (Ledger, $$LedgersTableReferences),
          Ledger,
          PrefetchHooks Function({
            bool recurringTransactionsRefs,
            bool transactionsRefs,
          })
        > {
  $$LedgersTableTableManager(_$SpitoutDatabase db, $LedgersTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LedgersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LedgersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LedgersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> currency = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<String?> syncId = const Value.absent(),
                Value<String> myRole = const Value.absent(),
                Value<int> memberCount = const Value.absent(),
                Value<bool> isShared = const Value.absent(),
                Value<String?> ownerUserId = const Value.absent(),
                Value<int> monthStartDay = const Value.absent(),
                Value<String> storageMode = const Value.absent(),
                Value<bool> aaEnabled = const Value.absent(),
              }) => LedgersCompanion(
                id: id,
                name: name,
                currency: currency,
                type: type,
                createdAt: createdAt,
                syncId: syncId,
                myRole: myRole,
                memberCount: memberCount,
                isShared: isShared,
                ownerUserId: ownerUserId,
                monthStartDay: monthStartDay,
                storageMode: storageMode,
                aaEnabled: aaEnabled,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                Value<String> currency = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<String?> syncId = const Value.absent(),
                Value<String> myRole = const Value.absent(),
                Value<int> memberCount = const Value.absent(),
                Value<bool> isShared = const Value.absent(),
                Value<String?> ownerUserId = const Value.absent(),
                Value<int> monthStartDay = const Value.absent(),
                Value<String> storageMode = const Value.absent(),
                Value<bool> aaEnabled = const Value.absent(),
              }) => LedgersCompanion.insert(
                id: id,
                name: name,
                currency: currency,
                type: type,
                createdAt: createdAt,
                syncId: syncId,
                myRole: myRole,
                memberCount: memberCount,
                isShared: isShared,
                ownerUserId: ownerUserId,
                monthStartDay: monthStartDay,
                storageMode: storageMode,
                aaEnabled: aaEnabled,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$LedgersTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({recurringTransactionsRefs = false, transactionsRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (recurringTransactionsRefs) db.recurringTransactions,
                    if (transactionsRefs) db.transactions,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (recurringTransactionsRefs)
                        await $_getPrefetchedData<
                          Ledger,
                          $LedgersTable,
                          RecurringTransaction
                        >(
                          currentTable: table,
                          referencedTable: $$LedgersTableReferences
                              ._recurringTransactionsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$LedgersTableReferences(
                                db,
                                table,
                                p0,
                              ).recurringTransactionsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.ledgerId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (transactionsRefs)
                        await $_getPrefetchedData<
                          Ledger,
                          $LedgersTable,
                          Transaction
                        >(
                          currentTable: table,
                          referencedTable: $$LedgersTableReferences
                              ._transactionsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$LedgersTableReferences(
                                db,
                                table,
                                p0,
                              ).transactionsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.ledgerId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$LedgersTableProcessedTableManager =
    ProcessedTableManager<
      _$SpitoutDatabase,
      $LedgersTable,
      Ledger,
      $$LedgersTableFilterComposer,
      $$LedgersTableOrderingComposer,
      $$LedgersTableAnnotationComposer,
      $$LedgersTableCreateCompanionBuilder,
      $$LedgersTableUpdateCompanionBuilder,
      (Ledger, $$LedgersTableReferences),
      Ledger,
      PrefetchHooks Function({
        bool recurringTransactionsRefs,
        bool transactionsRefs,
      })
    >;
typedef $$CategoriesTableCreateCompanionBuilder =
    CategoriesCompanion Function({
      Value<int> id,
      required String name,
      required String kind,
      Value<String?> icon,
      Value<int> sortOrder,
      Value<int?> parentId,
      Value<int> level,
      Value<String?> syncId,
    });
typedef $$CategoriesTableUpdateCompanionBuilder =
    CategoriesCompanion Function({
      Value<int> id,
      Value<String> name,
      Value<String> kind,
      Value<String?> icon,
      Value<int> sortOrder,
      Value<int?> parentId,
      Value<int> level,
      Value<String?> syncId,
    });

final class $$CategoriesTableReferences
    extends BaseReferences<_$SpitoutDatabase, $CategoriesTable, Category> {
  $$CategoriesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$TransactionsTable, List<Transaction>>
  _transactionsRefsTable(_$SpitoutDatabase db) => MultiTypedResultKey.fromTable(
    db.transactions,
    aliasName: 'categories__id__transactions__category_id',
  );

  $$TransactionsTableProcessedTableManager get transactionsRefs {
    final manager = $$TransactionsTableTableManager(
      $_db,
      $_db.transactions,
    ).filter((f) => f.categoryId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_transactionsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$CategoriesTableFilterComposer
    extends Composer<_$SpitoutDatabase, $CategoriesTable> {
  $$CategoriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get icon => $composableBuilder(
    column: $table.icon,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get parentId => $composableBuilder(
    column: $table.parentId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get level => $composableBuilder(
    column: $table.level,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get syncId => $composableBuilder(
    column: $table.syncId,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> transactionsRefs(
    Expression<bool> Function($$TransactionsTableFilterComposer f) f,
  ) {
    final $$TransactionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.transactions,
      getReferencedColumn: (t) => t.categoryId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TransactionsTableFilterComposer(
            $db: $db,
            $table: $db.transactions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$CategoriesTableOrderingComposer
    extends Composer<_$SpitoutDatabase, $CategoriesTable> {
  $$CategoriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get icon => $composableBuilder(
    column: $table.icon,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get parentId => $composableBuilder(
    column: $table.parentId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get level => $composableBuilder(
    column: $table.level,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get syncId => $composableBuilder(
    column: $table.syncId,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CategoriesTableAnnotationComposer
    extends Composer<_$SpitoutDatabase, $CategoriesTable> {
  $$CategoriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get icon =>
      $composableBuilder(column: $table.icon, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<int> get parentId =>
      $composableBuilder(column: $table.parentId, builder: (column) => column);

  GeneratedColumn<int> get level =>
      $composableBuilder(column: $table.level, builder: (column) => column);

  GeneratedColumn<String> get syncId =>
      $composableBuilder(column: $table.syncId, builder: (column) => column);

  Expression<T> transactionsRefs<T extends Object>(
    Expression<T> Function($$TransactionsTableAnnotationComposer a) f,
  ) {
    final $$TransactionsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.transactions,
      getReferencedColumn: (t) => t.categoryId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TransactionsTableAnnotationComposer(
            $db: $db,
            $table: $db.transactions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$CategoriesTableTableManager
    extends
        RootTableManager<
          _$SpitoutDatabase,
          $CategoriesTable,
          Category,
          $$CategoriesTableFilterComposer,
          $$CategoriesTableOrderingComposer,
          $$CategoriesTableAnnotationComposer,
          $$CategoriesTableCreateCompanionBuilder,
          $$CategoriesTableUpdateCompanionBuilder,
          (Category, $$CategoriesTableReferences),
          Category,
          PrefetchHooks Function({bool transactionsRefs})
        > {
  $$CategoriesTableTableManager(_$SpitoutDatabase db, $CategoriesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CategoriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CategoriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CategoriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String?> icon = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<int?> parentId = const Value.absent(),
                Value<int> level = const Value.absent(),
                Value<String?> syncId = const Value.absent(),
              }) => CategoriesCompanion(
                id: id,
                name: name,
                kind: kind,
                icon: icon,
                sortOrder: sortOrder,
                parentId: parentId,
                level: level,
                syncId: syncId,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                required String kind,
                Value<String?> icon = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<int?> parentId = const Value.absent(),
                Value<int> level = const Value.absent(),
                Value<String?> syncId = const Value.absent(),
              }) => CategoriesCompanion.insert(
                id: id,
                name: name,
                kind: kind,
                icon: icon,
                sortOrder: sortOrder,
                parentId: parentId,
                level: level,
                syncId: syncId,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$CategoriesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({transactionsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (transactionsRefs) db.transactions],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (transactionsRefs)
                    await $_getPrefetchedData<
                      Category,
                      $CategoriesTable,
                      Transaction
                    >(
                      currentTable: table,
                      referencedTable: $$CategoriesTableReferences
                          ._transactionsRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$CategoriesTableReferences(
                            db,
                            table,
                            p0,
                          ).transactionsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.categoryId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$CategoriesTableProcessedTableManager =
    ProcessedTableManager<
      _$SpitoutDatabase,
      $CategoriesTable,
      Category,
      $$CategoriesTableFilterComposer,
      $$CategoriesTableOrderingComposer,
      $$CategoriesTableAnnotationComposer,
      $$CategoriesTableCreateCompanionBuilder,
      $$CategoriesTableUpdateCompanionBuilder,
      (Category, $$CategoriesTableReferences),
      Category,
      PrefetchHooks Function({bool transactionsRefs})
    >;
typedef $$RecurringTransactionsTableCreateCompanionBuilder =
    RecurringTransactionsCompanion Function({
      Value<int> id,
      required int ledgerId,
      required String type,
      required int amount,
      Value<String?> currencyCode,
      Value<int?> categoryId,
      Value<String?> note,
      required String frequency,
      Value<int> interval,
      Value<int?> dayOfMonth,
      Value<int?> dayOfWeek,
      Value<int?> monthOfYear,
      required DateTime startDate,
      Value<DateTime?> endDate,
      Value<DateTime?> lastGeneratedDate,
      Value<bool> enabled,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
    });
typedef $$RecurringTransactionsTableUpdateCompanionBuilder =
    RecurringTransactionsCompanion Function({
      Value<int> id,
      Value<int> ledgerId,
      Value<String> type,
      Value<int> amount,
      Value<String?> currencyCode,
      Value<int?> categoryId,
      Value<String?> note,
      Value<String> frequency,
      Value<int> interval,
      Value<int?> dayOfMonth,
      Value<int?> dayOfWeek,
      Value<int?> monthOfYear,
      Value<DateTime> startDate,
      Value<DateTime?> endDate,
      Value<DateTime?> lastGeneratedDate,
      Value<bool> enabled,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
    });

final class $$RecurringTransactionsTableReferences
    extends
        BaseReferences<
          _$SpitoutDatabase,
          $RecurringTransactionsTable,
          RecurringTransaction
        > {
  $$RecurringTransactionsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $LedgersTable _ledgerIdTable(_$SpitoutDatabase db) =>
      db.ledgers.createAlias('recurring_transactions__ledger_id__ledgers__id');

  $$LedgersTableProcessedTableManager get ledgerId {
    final $_column = $_itemColumn<int>('ledger_id')!;

    final manager = $$LedgersTableTableManager(
      $_db,
      $_db.ledgers,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_ledgerIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$TransactionsTable, List<Transaction>>
  _transactionsRefsTable(_$SpitoutDatabase db) => MultiTypedResultKey.fromTable(
    db.transactions,
    aliasName: 'recurring_transactions__id__transactions__recurring_id',
  );

  $$TransactionsTableProcessedTableManager get transactionsRefs {
    final manager = $$TransactionsTableTableManager(
      $_db,
      $_db.transactions,
    ).filter((f) => f.recurringId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_transactionsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$RecurringTransactionsTableFilterComposer
    extends Composer<_$SpitoutDatabase, $RecurringTransactionsTable> {
  $$RecurringTransactionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get amount => $composableBuilder(
    column: $table.amount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get currencyCode => $composableBuilder(
    column: $table.currencyCode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get categoryId => $composableBuilder(
    column: $table.categoryId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get frequency => $composableBuilder(
    column: $table.frequency,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get interval => $composableBuilder(
    column: $table.interval,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get dayOfMonth => $composableBuilder(
    column: $table.dayOfMonth,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get dayOfWeek => $composableBuilder(
    column: $table.dayOfWeek,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get monthOfYear => $composableBuilder(
    column: $table.monthOfYear,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get startDate => $composableBuilder(
    column: $table.startDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get endDate => $composableBuilder(
    column: $table.endDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastGeneratedDate => $composableBuilder(
    column: $table.lastGeneratedDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get enabled => $composableBuilder(
    column: $table.enabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$LedgersTableFilterComposer get ledgerId {
    final $$LedgersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.ledgerId,
      referencedTable: $db.ledgers,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LedgersTableFilterComposer(
            $db: $db,
            $table: $db.ledgers,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> transactionsRefs(
    Expression<bool> Function($$TransactionsTableFilterComposer f) f,
  ) {
    final $$TransactionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.transactions,
      getReferencedColumn: (t) => t.recurringId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TransactionsTableFilterComposer(
            $db: $db,
            $table: $db.transactions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$RecurringTransactionsTableOrderingComposer
    extends Composer<_$SpitoutDatabase, $RecurringTransactionsTable> {
  $$RecurringTransactionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get amount => $composableBuilder(
    column: $table.amount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get currencyCode => $composableBuilder(
    column: $table.currencyCode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get categoryId => $composableBuilder(
    column: $table.categoryId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get frequency => $composableBuilder(
    column: $table.frequency,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get interval => $composableBuilder(
    column: $table.interval,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get dayOfMonth => $composableBuilder(
    column: $table.dayOfMonth,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get dayOfWeek => $composableBuilder(
    column: $table.dayOfWeek,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get monthOfYear => $composableBuilder(
    column: $table.monthOfYear,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get startDate => $composableBuilder(
    column: $table.startDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get endDate => $composableBuilder(
    column: $table.endDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastGeneratedDate => $composableBuilder(
    column: $table.lastGeneratedDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get enabled => $composableBuilder(
    column: $table.enabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$LedgersTableOrderingComposer get ledgerId {
    final $$LedgersTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.ledgerId,
      referencedTable: $db.ledgers,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LedgersTableOrderingComposer(
            $db: $db,
            $table: $db.ledgers,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$RecurringTransactionsTableAnnotationComposer
    extends Composer<_$SpitoutDatabase, $RecurringTransactionsTable> {
  $$RecurringTransactionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<int> get amount =>
      $composableBuilder(column: $table.amount, builder: (column) => column);

  GeneratedColumn<String> get currencyCode => $composableBuilder(
    column: $table.currencyCode,
    builder: (column) => column,
  );

  GeneratedColumn<int> get categoryId => $composableBuilder(
    column: $table.categoryId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<String> get frequency =>
      $composableBuilder(column: $table.frequency, builder: (column) => column);

  GeneratedColumn<int> get interval =>
      $composableBuilder(column: $table.interval, builder: (column) => column);

  GeneratedColumn<int> get dayOfMonth => $composableBuilder(
    column: $table.dayOfMonth,
    builder: (column) => column,
  );

  GeneratedColumn<int> get dayOfWeek =>
      $composableBuilder(column: $table.dayOfWeek, builder: (column) => column);

  GeneratedColumn<int> get monthOfYear => $composableBuilder(
    column: $table.monthOfYear,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get startDate =>
      $composableBuilder(column: $table.startDate, builder: (column) => column);

  GeneratedColumn<DateTime> get endDate =>
      $composableBuilder(column: $table.endDate, builder: (column) => column);

  GeneratedColumn<DateTime> get lastGeneratedDate => $composableBuilder(
    column: $table.lastGeneratedDate,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get enabled =>
      $composableBuilder(column: $table.enabled, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  $$LedgersTableAnnotationComposer get ledgerId {
    final $$LedgersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.ledgerId,
      referencedTable: $db.ledgers,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LedgersTableAnnotationComposer(
            $db: $db,
            $table: $db.ledgers,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> transactionsRefs<T extends Object>(
    Expression<T> Function($$TransactionsTableAnnotationComposer a) f,
  ) {
    final $$TransactionsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.transactions,
      getReferencedColumn: (t) => t.recurringId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TransactionsTableAnnotationComposer(
            $db: $db,
            $table: $db.transactions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$RecurringTransactionsTableTableManager
    extends
        RootTableManager<
          _$SpitoutDatabase,
          $RecurringTransactionsTable,
          RecurringTransaction,
          $$RecurringTransactionsTableFilterComposer,
          $$RecurringTransactionsTableOrderingComposer,
          $$RecurringTransactionsTableAnnotationComposer,
          $$RecurringTransactionsTableCreateCompanionBuilder,
          $$RecurringTransactionsTableUpdateCompanionBuilder,
          (RecurringTransaction, $$RecurringTransactionsTableReferences),
          RecurringTransaction,
          PrefetchHooks Function({bool ledgerId, bool transactionsRefs})
        > {
  $$RecurringTransactionsTableTableManager(
    _$SpitoutDatabase db,
    $RecurringTransactionsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RecurringTransactionsTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$RecurringTransactionsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$RecurringTransactionsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> ledgerId = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<int> amount = const Value.absent(),
                Value<String?> currencyCode = const Value.absent(),
                Value<int?> categoryId = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<String> frequency = const Value.absent(),
                Value<int> interval = const Value.absent(),
                Value<int?> dayOfMonth = const Value.absent(),
                Value<int?> dayOfWeek = const Value.absent(),
                Value<int?> monthOfYear = const Value.absent(),
                Value<DateTime> startDate = const Value.absent(),
                Value<DateTime?> endDate = const Value.absent(),
                Value<DateTime?> lastGeneratedDate = const Value.absent(),
                Value<bool> enabled = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => RecurringTransactionsCompanion(
                id: id,
                ledgerId: ledgerId,
                type: type,
                amount: amount,
                currencyCode: currencyCode,
                categoryId: categoryId,
                note: note,
                frequency: frequency,
                interval: interval,
                dayOfMonth: dayOfMonth,
                dayOfWeek: dayOfWeek,
                monthOfYear: monthOfYear,
                startDate: startDate,
                endDate: endDate,
                lastGeneratedDate: lastGeneratedDate,
                enabled: enabled,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int ledgerId,
                required String type,
                required int amount,
                Value<String?> currencyCode = const Value.absent(),
                Value<int?> categoryId = const Value.absent(),
                Value<String?> note = const Value.absent(),
                required String frequency,
                Value<int> interval = const Value.absent(),
                Value<int?> dayOfMonth = const Value.absent(),
                Value<int?> dayOfWeek = const Value.absent(),
                Value<int?> monthOfYear = const Value.absent(),
                required DateTime startDate,
                Value<DateTime?> endDate = const Value.absent(),
                Value<DateTime?> lastGeneratedDate = const Value.absent(),
                Value<bool> enabled = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => RecurringTransactionsCompanion.insert(
                id: id,
                ledgerId: ledgerId,
                type: type,
                amount: amount,
                currencyCode: currencyCode,
                categoryId: categoryId,
                note: note,
                frequency: frequency,
                interval: interval,
                dayOfMonth: dayOfMonth,
                dayOfWeek: dayOfWeek,
                monthOfYear: monthOfYear,
                startDate: startDate,
                endDate: endDate,
                lastGeneratedDate: lastGeneratedDate,
                enabled: enabled,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$RecurringTransactionsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({ledgerId = false, transactionsRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (transactionsRefs) db.transactions,
                  ],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (ledgerId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.ledgerId,
                                    referencedTable:
                                        $$RecurringTransactionsTableReferences
                                            ._ledgerIdTable(db),
                                    referencedColumn:
                                        $$RecurringTransactionsTableReferences
                                            ._ledgerIdTable(db)
                                            .id,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (transactionsRefs)
                        await $_getPrefetchedData<
                          RecurringTransaction,
                          $RecurringTransactionsTable,
                          Transaction
                        >(
                          currentTable: table,
                          referencedTable:
                              $$RecurringTransactionsTableReferences
                                  ._transactionsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$RecurringTransactionsTableReferences(
                                db,
                                table,
                                p0,
                              ).transactionsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.recurringId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$RecurringTransactionsTableProcessedTableManager =
    ProcessedTableManager<
      _$SpitoutDatabase,
      $RecurringTransactionsTable,
      RecurringTransaction,
      $$RecurringTransactionsTableFilterComposer,
      $$RecurringTransactionsTableOrderingComposer,
      $$RecurringTransactionsTableAnnotationComposer,
      $$RecurringTransactionsTableCreateCompanionBuilder,
      $$RecurringTransactionsTableUpdateCompanionBuilder,
      (RecurringTransaction, $$RecurringTransactionsTableReferences),
      RecurringTransaction,
      PrefetchHooks Function({bool ledgerId, bool transactionsRefs})
    >;
typedef $$TransactionsTableCreateCompanionBuilder =
    TransactionsCompanion Function({
      Value<int> id,
      required int ledgerId,
      required String type,
      required int amount,
      Value<int?> categoryId,
      Value<DateTime> happenedAt,
      Value<String?> note,
      Value<int?> recurringId,
      Value<String?> syncId,
      Value<String?> createdByUserId,
      Value<String?> lastEditedByUserId,
      Value<String?> categorySyncIdOverride,
      Value<bool> excludeFromStats,
      Value<String?> currencyCode,
      Value<int?> nativeAmount,
      Value<int> version,
      Value<DateTime?> lastEditedAt,
      Value<String?> paidByUserId,
      Value<int?> aaMode,
      Value<String?> aaParticipants,
      Value<String?> aaSplits,
    });
typedef $$TransactionsTableUpdateCompanionBuilder =
    TransactionsCompanion Function({
      Value<int> id,
      Value<int> ledgerId,
      Value<String> type,
      Value<int> amount,
      Value<int?> categoryId,
      Value<DateTime> happenedAt,
      Value<String?> note,
      Value<int?> recurringId,
      Value<String?> syncId,
      Value<String?> createdByUserId,
      Value<String?> lastEditedByUserId,
      Value<String?> categorySyncIdOverride,
      Value<bool> excludeFromStats,
      Value<String?> currencyCode,
      Value<int?> nativeAmount,
      Value<int> version,
      Value<DateTime?> lastEditedAt,
      Value<String?> paidByUserId,
      Value<int?> aaMode,
      Value<String?> aaParticipants,
      Value<String?> aaSplits,
    });

final class $$TransactionsTableReferences
    extends BaseReferences<_$SpitoutDatabase, $TransactionsTable, Transaction> {
  $$TransactionsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $LedgersTable _ledgerIdTable(_$SpitoutDatabase db) =>
      db.ledgers.createAlias('transactions__ledger_id__ledgers__id');

  $$LedgersTableProcessedTableManager get ledgerId {
    final $_column = $_itemColumn<int>('ledger_id')!;

    final manager = $$LedgersTableTableManager(
      $_db,
      $_db.ledgers,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_ledgerIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $CategoriesTable _categoryIdTable(_$SpitoutDatabase db) =>
      db.categories.createAlias('transactions__category_id__categories__id');

  $$CategoriesTableProcessedTableManager? get categoryId {
    final $_column = $_itemColumn<int>('category_id');
    if ($_column == null) return null;
    final manager = $$CategoriesTableTableManager(
      $_db,
      $_db.categories,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_categoryIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $RecurringTransactionsTable _recurringIdTable(_$SpitoutDatabase db) =>
      db.recurringTransactions.createAlias(
        'transactions__recurring_id__recurring_transactions__id',
      );

  $$RecurringTransactionsTableProcessedTableManager? get recurringId {
    final $_column = $_itemColumn<int>('recurring_id');
    if ($_column == null) return null;
    final manager = $$RecurringTransactionsTableTableManager(
      $_db,
      $_db.recurringTransactions,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_recurringIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$RecordEditHistoriesTable, List<RecordEditHistory>>
  _recordEditHistoriesRefsTable(_$SpitoutDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.recordEditHistories,
        aliasName: 'transactions__id__record_edit_histories__record_id',
      );

  $$RecordEditHistoriesTableProcessedTableManager get recordEditHistoriesRefs {
    final manager = $$RecordEditHistoriesTableTableManager(
      $_db,
      $_db.recordEditHistories,
    ).filter((f) => f.recordId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _recordEditHistoriesRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$TransactionsTableFilterComposer
    extends Composer<_$SpitoutDatabase, $TransactionsTable> {
  $$TransactionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get amount => $composableBuilder(
    column: $table.amount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get happenedAt => $composableBuilder(
    column: $table.happenedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get syncId => $composableBuilder(
    column: $table.syncId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createdByUserId => $composableBuilder(
    column: $table.createdByUserId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastEditedByUserId => $composableBuilder(
    column: $table.lastEditedByUserId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get categorySyncIdOverride => $composableBuilder(
    column: $table.categorySyncIdOverride,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get excludeFromStats => $composableBuilder(
    column: $table.excludeFromStats,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get currencyCode => $composableBuilder(
    column: $table.currencyCode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get nativeAmount => $composableBuilder(
    column: $table.nativeAmount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastEditedAt => $composableBuilder(
    column: $table.lastEditedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get paidByUserId => $composableBuilder(
    column: $table.paidByUserId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get aaMode => $composableBuilder(
    column: $table.aaMode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get aaParticipants => $composableBuilder(
    column: $table.aaParticipants,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get aaSplits => $composableBuilder(
    column: $table.aaSplits,
    builder: (column) => ColumnFilters(column),
  );

  $$LedgersTableFilterComposer get ledgerId {
    final $$LedgersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.ledgerId,
      referencedTable: $db.ledgers,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LedgersTableFilterComposer(
            $db: $db,
            $table: $db.ledgers,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$CategoriesTableFilterComposer get categoryId {
    final $$CategoriesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.categoryId,
      referencedTable: $db.categories,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CategoriesTableFilterComposer(
            $db: $db,
            $table: $db.categories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$RecurringTransactionsTableFilterComposer get recurringId {
    final $$RecurringTransactionsTableFilterComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.recurringId,
          referencedTable: $db.recurringTransactions,
          getReferencedColumn: (t) => t.id,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$RecurringTransactionsTableFilterComposer(
                $db: $db,
                $table: $db.recurringTransactions,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return composer;
  }

  Expression<bool> recordEditHistoriesRefs(
    Expression<bool> Function($$RecordEditHistoriesTableFilterComposer f) f,
  ) {
    final $$RecordEditHistoriesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.recordEditHistories,
      getReferencedColumn: (t) => t.recordId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RecordEditHistoriesTableFilterComposer(
            $db: $db,
            $table: $db.recordEditHistories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$TransactionsTableOrderingComposer
    extends Composer<_$SpitoutDatabase, $TransactionsTable> {
  $$TransactionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get amount => $composableBuilder(
    column: $table.amount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get happenedAt => $composableBuilder(
    column: $table.happenedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get syncId => $composableBuilder(
    column: $table.syncId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdByUserId => $composableBuilder(
    column: $table.createdByUserId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastEditedByUserId => $composableBuilder(
    column: $table.lastEditedByUserId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get categorySyncIdOverride => $composableBuilder(
    column: $table.categorySyncIdOverride,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get excludeFromStats => $composableBuilder(
    column: $table.excludeFromStats,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get currencyCode => $composableBuilder(
    column: $table.currencyCode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get nativeAmount => $composableBuilder(
    column: $table.nativeAmount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastEditedAt => $composableBuilder(
    column: $table.lastEditedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get paidByUserId => $composableBuilder(
    column: $table.paidByUserId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get aaMode => $composableBuilder(
    column: $table.aaMode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get aaParticipants => $composableBuilder(
    column: $table.aaParticipants,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get aaSplits => $composableBuilder(
    column: $table.aaSplits,
    builder: (column) => ColumnOrderings(column),
  );

  $$LedgersTableOrderingComposer get ledgerId {
    final $$LedgersTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.ledgerId,
      referencedTable: $db.ledgers,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LedgersTableOrderingComposer(
            $db: $db,
            $table: $db.ledgers,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$CategoriesTableOrderingComposer get categoryId {
    final $$CategoriesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.categoryId,
      referencedTable: $db.categories,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CategoriesTableOrderingComposer(
            $db: $db,
            $table: $db.categories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$RecurringTransactionsTableOrderingComposer get recurringId {
    final $$RecurringTransactionsTableOrderingComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.recurringId,
          referencedTable: $db.recurringTransactions,
          getReferencedColumn: (t) => t.id,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$RecurringTransactionsTableOrderingComposer(
                $db: $db,
                $table: $db.recurringTransactions,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return composer;
  }
}

class $$TransactionsTableAnnotationComposer
    extends Composer<_$SpitoutDatabase, $TransactionsTable> {
  $$TransactionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<int> get amount =>
      $composableBuilder(column: $table.amount, builder: (column) => column);

  GeneratedColumn<DateTime> get happenedAt => $composableBuilder(
    column: $table.happenedAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<String> get syncId =>
      $composableBuilder(column: $table.syncId, builder: (column) => column);

  GeneratedColumn<String> get createdByUserId => $composableBuilder(
    column: $table.createdByUserId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get lastEditedByUserId => $composableBuilder(
    column: $table.lastEditedByUserId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get categorySyncIdOverride => $composableBuilder(
    column: $table.categorySyncIdOverride,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get excludeFromStats => $composableBuilder(
    column: $table.excludeFromStats,
    builder: (column) => column,
  );

  GeneratedColumn<String> get currencyCode => $composableBuilder(
    column: $table.currencyCode,
    builder: (column) => column,
  );

  GeneratedColumn<int> get nativeAmount => $composableBuilder(
    column: $table.nativeAmount,
    builder: (column) => column,
  );

  GeneratedColumn<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<DateTime> get lastEditedAt => $composableBuilder(
    column: $table.lastEditedAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get paidByUserId => $composableBuilder(
    column: $table.paidByUserId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get aaMode =>
      $composableBuilder(column: $table.aaMode, builder: (column) => column);

  GeneratedColumn<String> get aaParticipants => $composableBuilder(
    column: $table.aaParticipants,
    builder: (column) => column,
  );

  GeneratedColumn<String> get aaSplits =>
      $composableBuilder(column: $table.aaSplits, builder: (column) => column);

  $$LedgersTableAnnotationComposer get ledgerId {
    final $$LedgersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.ledgerId,
      referencedTable: $db.ledgers,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LedgersTableAnnotationComposer(
            $db: $db,
            $table: $db.ledgers,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$CategoriesTableAnnotationComposer get categoryId {
    final $$CategoriesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.categoryId,
      referencedTable: $db.categories,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CategoriesTableAnnotationComposer(
            $db: $db,
            $table: $db.categories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$RecurringTransactionsTableAnnotationComposer get recurringId {
    final $$RecurringTransactionsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.recurringId,
          referencedTable: $db.recurringTransactions,
          getReferencedColumn: (t) => t.id,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$RecurringTransactionsTableAnnotationComposer(
                $db: $db,
                $table: $db.recurringTransactions,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return composer;
  }

  Expression<T> recordEditHistoriesRefs<T extends Object>(
    Expression<T> Function($$RecordEditHistoriesTableAnnotationComposer a) f,
  ) {
    final $$RecordEditHistoriesTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.recordEditHistories,
          getReferencedColumn: (t) => t.recordId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$RecordEditHistoriesTableAnnotationComposer(
                $db: $db,
                $table: $db.recordEditHistories,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$TransactionsTableTableManager
    extends
        RootTableManager<
          _$SpitoutDatabase,
          $TransactionsTable,
          Transaction,
          $$TransactionsTableFilterComposer,
          $$TransactionsTableOrderingComposer,
          $$TransactionsTableAnnotationComposer,
          $$TransactionsTableCreateCompanionBuilder,
          $$TransactionsTableUpdateCompanionBuilder,
          (Transaction, $$TransactionsTableReferences),
          Transaction,
          PrefetchHooks Function({
            bool ledgerId,
            bool categoryId,
            bool recurringId,
            bool recordEditHistoriesRefs,
          })
        > {
  $$TransactionsTableTableManager(
    _$SpitoutDatabase db,
    $TransactionsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TransactionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TransactionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TransactionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> ledgerId = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<int> amount = const Value.absent(),
                Value<int?> categoryId = const Value.absent(),
                Value<DateTime> happenedAt = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<int?> recurringId = const Value.absent(),
                Value<String?> syncId = const Value.absent(),
                Value<String?> createdByUserId = const Value.absent(),
                Value<String?> lastEditedByUserId = const Value.absent(),
                Value<String?> categorySyncIdOverride = const Value.absent(),
                Value<bool> excludeFromStats = const Value.absent(),
                Value<String?> currencyCode = const Value.absent(),
                Value<int?> nativeAmount = const Value.absent(),
                Value<int> version = const Value.absent(),
                Value<DateTime?> lastEditedAt = const Value.absent(),
                Value<String?> paidByUserId = const Value.absent(),
                Value<int?> aaMode = const Value.absent(),
                Value<String?> aaParticipants = const Value.absent(),
                Value<String?> aaSplits = const Value.absent(),
              }) => TransactionsCompanion(
                id: id,
                ledgerId: ledgerId,
                type: type,
                amount: amount,
                categoryId: categoryId,
                happenedAt: happenedAt,
                note: note,
                recurringId: recurringId,
                syncId: syncId,
                createdByUserId: createdByUserId,
                lastEditedByUserId: lastEditedByUserId,
                categorySyncIdOverride: categorySyncIdOverride,
                excludeFromStats: excludeFromStats,
                currencyCode: currencyCode,
                nativeAmount: nativeAmount,
                version: version,
                lastEditedAt: lastEditedAt,
                paidByUserId: paidByUserId,
                aaMode: aaMode,
                aaParticipants: aaParticipants,
                aaSplits: aaSplits,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int ledgerId,
                required String type,
                required int amount,
                Value<int?> categoryId = const Value.absent(),
                Value<DateTime> happenedAt = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<int?> recurringId = const Value.absent(),
                Value<String?> syncId = const Value.absent(),
                Value<String?> createdByUserId = const Value.absent(),
                Value<String?> lastEditedByUserId = const Value.absent(),
                Value<String?> categorySyncIdOverride = const Value.absent(),
                Value<bool> excludeFromStats = const Value.absent(),
                Value<String?> currencyCode = const Value.absent(),
                Value<int?> nativeAmount = const Value.absent(),
                Value<int> version = const Value.absent(),
                Value<DateTime?> lastEditedAt = const Value.absent(),
                Value<String?> paidByUserId = const Value.absent(),
                Value<int?> aaMode = const Value.absent(),
                Value<String?> aaParticipants = const Value.absent(),
                Value<String?> aaSplits = const Value.absent(),
              }) => TransactionsCompanion.insert(
                id: id,
                ledgerId: ledgerId,
                type: type,
                amount: amount,
                categoryId: categoryId,
                happenedAt: happenedAt,
                note: note,
                recurringId: recurringId,
                syncId: syncId,
                createdByUserId: createdByUserId,
                lastEditedByUserId: lastEditedByUserId,
                categorySyncIdOverride: categorySyncIdOverride,
                excludeFromStats: excludeFromStats,
                currencyCode: currencyCode,
                nativeAmount: nativeAmount,
                version: version,
                lastEditedAt: lastEditedAt,
                paidByUserId: paidByUserId,
                aaMode: aaMode,
                aaParticipants: aaParticipants,
                aaSplits: aaSplits,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$TransactionsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                ledgerId = false,
                categoryId = false,
                recurringId = false,
                recordEditHistoriesRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (recordEditHistoriesRefs) db.recordEditHistories,
                  ],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (ledgerId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.ledgerId,
                                    referencedTable:
                                        $$TransactionsTableReferences
                                            ._ledgerIdTable(db),
                                    referencedColumn:
                                        $$TransactionsTableReferences
                                            ._ledgerIdTable(db)
                                            .id,
                                  )
                                  as T;
                        }
                        if (categoryId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.categoryId,
                                    referencedTable:
                                        $$TransactionsTableReferences
                                            ._categoryIdTable(db),
                                    referencedColumn:
                                        $$TransactionsTableReferences
                                            ._categoryIdTable(db)
                                            .id,
                                  )
                                  as T;
                        }
                        if (recurringId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.recurringId,
                                    referencedTable:
                                        $$TransactionsTableReferences
                                            ._recurringIdTable(db),
                                    referencedColumn:
                                        $$TransactionsTableReferences
                                            ._recurringIdTable(db)
                                            .id,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (recordEditHistoriesRefs)
                        await $_getPrefetchedData<
                          Transaction,
                          $TransactionsTable,
                          RecordEditHistory
                        >(
                          currentTable: table,
                          referencedTable: $$TransactionsTableReferences
                              ._recordEditHistoriesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$TransactionsTableReferences(
                                db,
                                table,
                                p0,
                              ).recordEditHistoriesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.recordId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$TransactionsTableProcessedTableManager =
    ProcessedTableManager<
      _$SpitoutDatabase,
      $TransactionsTable,
      Transaction,
      $$TransactionsTableFilterComposer,
      $$TransactionsTableOrderingComposer,
      $$TransactionsTableAnnotationComposer,
      $$TransactionsTableCreateCompanionBuilder,
      $$TransactionsTableUpdateCompanionBuilder,
      (Transaction, $$TransactionsTableReferences),
      Transaction,
      PrefetchHooks Function({
        bool ledgerId,
        bool categoryId,
        bool recurringId,
        bool recordEditHistoriesRefs,
      })
    >;
typedef $$RecordEditHistoriesTableCreateCompanionBuilder =
    RecordEditHistoriesCompanion Function({
      Value<int> id,
      required int recordId,
      required int version,
      Value<String?> operatorUserId,
      required String summary,
      Value<DateTime> createdAt,
    });
typedef $$RecordEditHistoriesTableUpdateCompanionBuilder =
    RecordEditHistoriesCompanion Function({
      Value<int> id,
      Value<int> recordId,
      Value<int> version,
      Value<String?> operatorUserId,
      Value<String> summary,
      Value<DateTime> createdAt,
    });

final class $$RecordEditHistoriesTableReferences
    extends
        BaseReferences<
          _$SpitoutDatabase,
          $RecordEditHistoriesTable,
          RecordEditHistory
        > {
  $$RecordEditHistoriesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $TransactionsTable _recordIdTable(_$SpitoutDatabase db) => db
      .transactions
      .createAlias('record_edit_histories__record_id__transactions__id');

  $$TransactionsTableProcessedTableManager get recordId {
    final $_column = $_itemColumn<int>('record_id')!;

    final manager = $$TransactionsTableTableManager(
      $_db,
      $_db.transactions,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_recordIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$RecordEditHistoriesTableFilterComposer
    extends Composer<_$SpitoutDatabase, $RecordEditHistoriesTable> {
  $$RecordEditHistoriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get operatorUserId => $composableBuilder(
    column: $table.operatorUserId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get summary => $composableBuilder(
    column: $table.summary,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  $$TransactionsTableFilterComposer get recordId {
    final $$TransactionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.recordId,
      referencedTable: $db.transactions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TransactionsTableFilterComposer(
            $db: $db,
            $table: $db.transactions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$RecordEditHistoriesTableOrderingComposer
    extends Composer<_$SpitoutDatabase, $RecordEditHistoriesTable> {
  $$RecordEditHistoriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get operatorUserId => $composableBuilder(
    column: $table.operatorUserId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get summary => $composableBuilder(
    column: $table.summary,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$TransactionsTableOrderingComposer get recordId {
    final $$TransactionsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.recordId,
      referencedTable: $db.transactions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TransactionsTableOrderingComposer(
            $db: $db,
            $table: $db.transactions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$RecordEditHistoriesTableAnnotationComposer
    extends Composer<_$SpitoutDatabase, $RecordEditHistoriesTable> {
  $$RecordEditHistoriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<String> get operatorUserId => $composableBuilder(
    column: $table.operatorUserId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get summary =>
      $composableBuilder(column: $table.summary, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$TransactionsTableAnnotationComposer get recordId {
    final $$TransactionsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.recordId,
      referencedTable: $db.transactions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TransactionsTableAnnotationComposer(
            $db: $db,
            $table: $db.transactions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$RecordEditHistoriesTableTableManager
    extends
        RootTableManager<
          _$SpitoutDatabase,
          $RecordEditHistoriesTable,
          RecordEditHistory,
          $$RecordEditHistoriesTableFilterComposer,
          $$RecordEditHistoriesTableOrderingComposer,
          $$RecordEditHistoriesTableAnnotationComposer,
          $$RecordEditHistoriesTableCreateCompanionBuilder,
          $$RecordEditHistoriesTableUpdateCompanionBuilder,
          (RecordEditHistory, $$RecordEditHistoriesTableReferences),
          RecordEditHistory,
          PrefetchHooks Function({bool recordId})
        > {
  $$RecordEditHistoriesTableTableManager(
    _$SpitoutDatabase db,
    $RecordEditHistoriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RecordEditHistoriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RecordEditHistoriesTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$RecordEditHistoriesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> recordId = const Value.absent(),
                Value<int> version = const Value.absent(),
                Value<String?> operatorUserId = const Value.absent(),
                Value<String> summary = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => RecordEditHistoriesCompanion(
                id: id,
                recordId: recordId,
                version: version,
                operatorUserId: operatorUserId,
                summary: summary,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int recordId,
                required int version,
                Value<String?> operatorUserId = const Value.absent(),
                required String summary,
                Value<DateTime> createdAt = const Value.absent(),
              }) => RecordEditHistoriesCompanion.insert(
                id: id,
                recordId: recordId,
                version: version,
                operatorUserId: operatorUserId,
                summary: summary,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$RecordEditHistoriesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({recordId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (recordId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.recordId,
                                referencedTable:
                                    $$RecordEditHistoriesTableReferences
                                        ._recordIdTable(db),
                                referencedColumn:
                                    $$RecordEditHistoriesTableReferences
                                        ._recordIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$RecordEditHistoriesTableProcessedTableManager =
    ProcessedTableManager<
      _$SpitoutDatabase,
      $RecordEditHistoriesTable,
      RecordEditHistory,
      $$RecordEditHistoriesTableFilterComposer,
      $$RecordEditHistoriesTableOrderingComposer,
      $$RecordEditHistoriesTableAnnotationComposer,
      $$RecordEditHistoriesTableCreateCompanionBuilder,
      $$RecordEditHistoriesTableUpdateCompanionBuilder,
      (RecordEditHistory, $$RecordEditHistoriesTableReferences),
      RecordEditHistory,
      PrefetchHooks Function({bool recordId})
    >;
typedef $$LocalChangesTableCreateCompanionBuilder =
    LocalChangesCompanion Function({
      Value<int> id,
      required String entityType,
      required int entityId,
      required String entitySyncId,
      required int ledgerId,
      required String action,
      Value<String?> payloadJson,
      Value<DateTime> createdAt,
      Value<DateTime?> pushedAt,
    });
typedef $$LocalChangesTableUpdateCompanionBuilder =
    LocalChangesCompanion Function({
      Value<int> id,
      Value<String> entityType,
      Value<int> entityId,
      Value<String> entitySyncId,
      Value<int> ledgerId,
      Value<String> action,
      Value<String?> payloadJson,
      Value<DateTime> createdAt,
      Value<DateTime?> pushedAt,
    });

class $$LocalChangesTableFilterComposer
    extends Composer<_$SpitoutDatabase, $LocalChangesTable> {
  $$LocalChangesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get entityType => $composableBuilder(
    column: $table.entityType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get entityId => $composableBuilder(
    column: $table.entityId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get entitySyncId => $composableBuilder(
    column: $table.entitySyncId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get ledgerId => $composableBuilder(
    column: $table.ledgerId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get action => $composableBuilder(
    column: $table.action,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get pushedAt => $composableBuilder(
    column: $table.pushedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LocalChangesTableOrderingComposer
    extends Composer<_$SpitoutDatabase, $LocalChangesTable> {
  $$LocalChangesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get entityType => $composableBuilder(
    column: $table.entityType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get entityId => $composableBuilder(
    column: $table.entityId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get entitySyncId => $composableBuilder(
    column: $table.entitySyncId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get ledgerId => $composableBuilder(
    column: $table.ledgerId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get action => $composableBuilder(
    column: $table.action,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get pushedAt => $composableBuilder(
    column: $table.pushedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocalChangesTableAnnotationComposer
    extends Composer<_$SpitoutDatabase, $LocalChangesTable> {
  $$LocalChangesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get entityType => $composableBuilder(
    column: $table.entityType,
    builder: (column) => column,
  );

  GeneratedColumn<int> get entityId =>
      $composableBuilder(column: $table.entityId, builder: (column) => column);

  GeneratedColumn<String> get entitySyncId => $composableBuilder(
    column: $table.entitySyncId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get ledgerId =>
      $composableBuilder(column: $table.ledgerId, builder: (column) => column);

  GeneratedColumn<String> get action =>
      $composableBuilder(column: $table.action, builder: (column) => column);

  GeneratedColumn<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get pushedAt =>
      $composableBuilder(column: $table.pushedAt, builder: (column) => column);
}

class $$LocalChangesTableTableManager
    extends
        RootTableManager<
          _$SpitoutDatabase,
          $LocalChangesTable,
          LocalChange,
          $$LocalChangesTableFilterComposer,
          $$LocalChangesTableOrderingComposer,
          $$LocalChangesTableAnnotationComposer,
          $$LocalChangesTableCreateCompanionBuilder,
          $$LocalChangesTableUpdateCompanionBuilder,
          (
            LocalChange,
            BaseReferences<_$SpitoutDatabase, $LocalChangesTable, LocalChange>,
          ),
          LocalChange,
          PrefetchHooks Function()
        > {
  $$LocalChangesTableTableManager(
    _$SpitoutDatabase db,
    $LocalChangesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalChangesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalChangesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalChangesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> entityType = const Value.absent(),
                Value<int> entityId = const Value.absent(),
                Value<String> entitySyncId = const Value.absent(),
                Value<int> ledgerId = const Value.absent(),
                Value<String> action = const Value.absent(),
                Value<String?> payloadJson = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime?> pushedAt = const Value.absent(),
              }) => LocalChangesCompanion(
                id: id,
                entityType: entityType,
                entityId: entityId,
                entitySyncId: entitySyncId,
                ledgerId: ledgerId,
                action: action,
                payloadJson: payloadJson,
                createdAt: createdAt,
                pushedAt: pushedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String entityType,
                required int entityId,
                required String entitySyncId,
                required int ledgerId,
                required String action,
                Value<String?> payloadJson = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime?> pushedAt = const Value.absent(),
              }) => LocalChangesCompanion.insert(
                id: id,
                entityType: entityType,
                entityId: entityId,
                entitySyncId: entitySyncId,
                ledgerId: ledgerId,
                action: action,
                payloadJson: payloadJson,
                createdAt: createdAt,
                pushedAt: pushedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LocalChangesTableProcessedTableManager =
    ProcessedTableManager<
      _$SpitoutDatabase,
      $LocalChangesTable,
      LocalChange,
      $$LocalChangesTableFilterComposer,
      $$LocalChangesTableOrderingComposer,
      $$LocalChangesTableAnnotationComposer,
      $$LocalChangesTableCreateCompanionBuilder,
      $$LocalChangesTableUpdateCompanionBuilder,
      (
        LocalChange,
        BaseReferences<_$SpitoutDatabase, $LocalChangesTable, LocalChange>,
      ),
      LocalChange,
      PrefetchHooks Function()
    >;
typedef $$SyncStateTableCreateCompanionBuilder =
    SyncStateCompanion Function({
      Value<int> id,
      required String deviceId,
      Value<String> providerType,
      Value<int> serverCursor,
      Value<DateTime?> lastPushAt,
      Value<DateTime?> lastPullAt,
    });
typedef $$SyncStateTableUpdateCompanionBuilder =
    SyncStateCompanion Function({
      Value<int> id,
      Value<String> deviceId,
      Value<String> providerType,
      Value<int> serverCursor,
      Value<DateTime?> lastPushAt,
      Value<DateTime?> lastPullAt,
    });

class $$SyncStateTableFilterComposer
    extends Composer<_$SpitoutDatabase, $SyncStateTable> {
  $$SyncStateTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get providerType => $composableBuilder(
    column: $table.providerType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get serverCursor => $composableBuilder(
    column: $table.serverCursor,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastPushAt => $composableBuilder(
    column: $table.lastPushAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastPullAt => $composableBuilder(
    column: $table.lastPullAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SyncStateTableOrderingComposer
    extends Composer<_$SpitoutDatabase, $SyncStateTable> {
  $$SyncStateTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get providerType => $composableBuilder(
    column: $table.providerType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get serverCursor => $composableBuilder(
    column: $table.serverCursor,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastPushAt => $composableBuilder(
    column: $table.lastPushAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastPullAt => $composableBuilder(
    column: $table.lastPullAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SyncStateTableAnnotationComposer
    extends Composer<_$SpitoutDatabase, $SyncStateTable> {
  $$SyncStateTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get deviceId =>
      $composableBuilder(column: $table.deviceId, builder: (column) => column);

  GeneratedColumn<String> get providerType => $composableBuilder(
    column: $table.providerType,
    builder: (column) => column,
  );

  GeneratedColumn<int> get serverCursor => $composableBuilder(
    column: $table.serverCursor,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get lastPushAt => $composableBuilder(
    column: $table.lastPushAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get lastPullAt => $composableBuilder(
    column: $table.lastPullAt,
    builder: (column) => column,
  );
}

class $$SyncStateTableTableManager
    extends
        RootTableManager<
          _$SpitoutDatabase,
          $SyncStateTable,
          SyncStateData,
          $$SyncStateTableFilterComposer,
          $$SyncStateTableOrderingComposer,
          $$SyncStateTableAnnotationComposer,
          $$SyncStateTableCreateCompanionBuilder,
          $$SyncStateTableUpdateCompanionBuilder,
          (
            SyncStateData,
            BaseReferences<_$SpitoutDatabase, $SyncStateTable, SyncStateData>,
          ),
          SyncStateData,
          PrefetchHooks Function()
        > {
  $$SyncStateTableTableManager(_$SpitoutDatabase db, $SyncStateTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncStateTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncStateTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncStateTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> deviceId = const Value.absent(),
                Value<String> providerType = const Value.absent(),
                Value<int> serverCursor = const Value.absent(),
                Value<DateTime?> lastPushAt = const Value.absent(),
                Value<DateTime?> lastPullAt = const Value.absent(),
              }) => SyncStateCompanion(
                id: id,
                deviceId: deviceId,
                providerType: providerType,
                serverCursor: serverCursor,
                lastPushAt: lastPushAt,
                lastPullAt: lastPullAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String deviceId,
                Value<String> providerType = const Value.absent(),
                Value<int> serverCursor = const Value.absent(),
                Value<DateTime?> lastPushAt = const Value.absent(),
                Value<DateTime?> lastPullAt = const Value.absent(),
              }) => SyncStateCompanion.insert(
                id: id,
                deviceId: deviceId,
                providerType: providerType,
                serverCursor: serverCursor,
                lastPushAt: lastPushAt,
                lastPullAt: lastPullAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SyncStateTableProcessedTableManager =
    ProcessedTableManager<
      _$SpitoutDatabase,
      $SyncStateTable,
      SyncStateData,
      $$SyncStateTableFilterComposer,
      $$SyncStateTableOrderingComposer,
      $$SyncStateTableAnnotationComposer,
      $$SyncStateTableCreateCompanionBuilder,
      $$SyncStateTableUpdateCompanionBuilder,
      (
        SyncStateData,
        BaseReferences<_$SpitoutDatabase, $SyncStateTable, SyncStateData>,
      ),
      SyncStateData,
      PrefetchHooks Function()
    >;
typedef $$LedgerMembersTableCreateCompanionBuilder =
    LedgerMembersCompanion Function({
      required String ledgerSyncId,
      required String userId,
      Value<String?> account,
      Value<String?> displayName,
      Value<String?> avatarUrl,
      required String role,
      required DateTime joinedAt,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$LedgerMembersTableUpdateCompanionBuilder =
    LedgerMembersCompanion Function({
      Value<String> ledgerSyncId,
      Value<String> userId,
      Value<String?> account,
      Value<String?> displayName,
      Value<String?> avatarUrl,
      Value<String> role,
      Value<DateTime> joinedAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$LedgerMembersTableFilterComposer
    extends Composer<_$SpitoutDatabase, $LedgerMembersTable> {
  $$LedgerMembersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get ledgerSyncId => $composableBuilder(
    column: $table.ledgerSyncId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get account => $composableBuilder(
    column: $table.account,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get avatarUrl => $composableBuilder(
    column: $table.avatarUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get role => $composableBuilder(
    column: $table.role,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get joinedAt => $composableBuilder(
    column: $table.joinedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LedgerMembersTableOrderingComposer
    extends Composer<_$SpitoutDatabase, $LedgerMembersTable> {
  $$LedgerMembersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get ledgerSyncId => $composableBuilder(
    column: $table.ledgerSyncId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get account => $composableBuilder(
    column: $table.account,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get avatarUrl => $composableBuilder(
    column: $table.avatarUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get role => $composableBuilder(
    column: $table.role,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get joinedAt => $composableBuilder(
    column: $table.joinedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LedgerMembersTableAnnotationComposer
    extends Composer<_$SpitoutDatabase, $LedgerMembersTable> {
  $$LedgerMembersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get ledgerSyncId => $composableBuilder(
    column: $table.ledgerSyncId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<String> get account =>
      $composableBuilder(column: $table.account, builder: (column) => column);

  GeneratedColumn<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get avatarUrl =>
      $composableBuilder(column: $table.avatarUrl, builder: (column) => column);

  GeneratedColumn<String> get role =>
      $composableBuilder(column: $table.role, builder: (column) => column);

  GeneratedColumn<DateTime> get joinedAt =>
      $composableBuilder(column: $table.joinedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$LedgerMembersTableTableManager
    extends
        RootTableManager<
          _$SpitoutDatabase,
          $LedgerMembersTable,
          LedgerMember,
          $$LedgerMembersTableFilterComposer,
          $$LedgerMembersTableOrderingComposer,
          $$LedgerMembersTableAnnotationComposer,
          $$LedgerMembersTableCreateCompanionBuilder,
          $$LedgerMembersTableUpdateCompanionBuilder,
          (
            LedgerMember,
            BaseReferences<
              _$SpitoutDatabase,
              $LedgerMembersTable,
              LedgerMember
            >,
          ),
          LedgerMember,
          PrefetchHooks Function()
        > {
  $$LedgerMembersTableTableManager(
    _$SpitoutDatabase db,
    $LedgerMembersTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LedgerMembersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LedgerMembersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LedgerMembersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> ledgerSyncId = const Value.absent(),
                Value<String> userId = const Value.absent(),
                Value<String?> account = const Value.absent(),
                Value<String?> displayName = const Value.absent(),
                Value<String?> avatarUrl = const Value.absent(),
                Value<String> role = const Value.absent(),
                Value<DateTime> joinedAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LedgerMembersCompanion(
                ledgerSyncId: ledgerSyncId,
                userId: userId,
                account: account,
                displayName: displayName,
                avatarUrl: avatarUrl,
                role: role,
                joinedAt: joinedAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String ledgerSyncId,
                required String userId,
                Value<String?> account = const Value.absent(),
                Value<String?> displayName = const Value.absent(),
                Value<String?> avatarUrl = const Value.absent(),
                required String role,
                required DateTime joinedAt,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => LedgerMembersCompanion.insert(
                ledgerSyncId: ledgerSyncId,
                userId: userId,
                account: account,
                displayName: displayName,
                avatarUrl: avatarUrl,
                role: role,
                joinedAt: joinedAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LedgerMembersTableProcessedTableManager =
    ProcessedTableManager<
      _$SpitoutDatabase,
      $LedgerMembersTable,
      LedgerMember,
      $$LedgerMembersTableFilterComposer,
      $$LedgerMembersTableOrderingComposer,
      $$LedgerMembersTableAnnotationComposer,
      $$LedgerMembersTableCreateCompanionBuilder,
      $$LedgerMembersTableUpdateCompanionBuilder,
      (
        LedgerMember,
        BaseReferences<_$SpitoutDatabase, $LedgerMembersTable, LedgerMember>,
      ),
      LedgerMember,
      PrefetchHooks Function()
    >;
typedef $$SharedLedgerCategoriesTableCreateCompanionBuilder =
    SharedLedgerCategoriesCompanion Function({
      required String ledgerSyncId,
      required String syncId,
      required String name,
      required String kind,
      Value<String?> icon,
      Value<String?> color,
      Value<int> sortOrder,
      Value<int> level,
      Value<String?> parentName,
      Value<String?> parentSyncId,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$SharedLedgerCategoriesTableUpdateCompanionBuilder =
    SharedLedgerCategoriesCompanion Function({
      Value<String> ledgerSyncId,
      Value<String> syncId,
      Value<String> name,
      Value<String> kind,
      Value<String?> icon,
      Value<String?> color,
      Value<int> sortOrder,
      Value<int> level,
      Value<String?> parentName,
      Value<String?> parentSyncId,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$SharedLedgerCategoriesTableFilterComposer
    extends Composer<_$SpitoutDatabase, $SharedLedgerCategoriesTable> {
  $$SharedLedgerCategoriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get ledgerSyncId => $composableBuilder(
    column: $table.ledgerSyncId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get syncId => $composableBuilder(
    column: $table.syncId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get icon => $composableBuilder(
    column: $table.icon,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get color => $composableBuilder(
    column: $table.color,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get level => $composableBuilder(
    column: $table.level,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get parentName => $composableBuilder(
    column: $table.parentName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get parentSyncId => $composableBuilder(
    column: $table.parentSyncId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SharedLedgerCategoriesTableOrderingComposer
    extends Composer<_$SpitoutDatabase, $SharedLedgerCategoriesTable> {
  $$SharedLedgerCategoriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get ledgerSyncId => $composableBuilder(
    column: $table.ledgerSyncId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get syncId => $composableBuilder(
    column: $table.syncId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get icon => $composableBuilder(
    column: $table.icon,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get color => $composableBuilder(
    column: $table.color,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get level => $composableBuilder(
    column: $table.level,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get parentName => $composableBuilder(
    column: $table.parentName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get parentSyncId => $composableBuilder(
    column: $table.parentSyncId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SharedLedgerCategoriesTableAnnotationComposer
    extends Composer<_$SpitoutDatabase, $SharedLedgerCategoriesTable> {
  $$SharedLedgerCategoriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get ledgerSyncId => $composableBuilder(
    column: $table.ledgerSyncId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get syncId =>
      $composableBuilder(column: $table.syncId, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get icon =>
      $composableBuilder(column: $table.icon, builder: (column) => column);

  GeneratedColumn<String> get color =>
      $composableBuilder(column: $table.color, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<int> get level =>
      $composableBuilder(column: $table.level, builder: (column) => column);

  GeneratedColumn<String> get parentName => $composableBuilder(
    column: $table.parentName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get parentSyncId => $composableBuilder(
    column: $table.parentSyncId,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$SharedLedgerCategoriesTableTableManager
    extends
        RootTableManager<
          _$SpitoutDatabase,
          $SharedLedgerCategoriesTable,
          SharedLedgerCategory,
          $$SharedLedgerCategoriesTableFilterComposer,
          $$SharedLedgerCategoriesTableOrderingComposer,
          $$SharedLedgerCategoriesTableAnnotationComposer,
          $$SharedLedgerCategoriesTableCreateCompanionBuilder,
          $$SharedLedgerCategoriesTableUpdateCompanionBuilder,
          (
            SharedLedgerCategory,
            BaseReferences<
              _$SpitoutDatabase,
              $SharedLedgerCategoriesTable,
              SharedLedgerCategory
            >,
          ),
          SharedLedgerCategory,
          PrefetchHooks Function()
        > {
  $$SharedLedgerCategoriesTableTableManager(
    _$SpitoutDatabase db,
    $SharedLedgerCategoriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SharedLedgerCategoriesTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$SharedLedgerCategoriesTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$SharedLedgerCategoriesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> ledgerSyncId = const Value.absent(),
                Value<String> syncId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String?> icon = const Value.absent(),
                Value<String?> color = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<int> level = const Value.absent(),
                Value<String?> parentName = const Value.absent(),
                Value<String?> parentSyncId = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SharedLedgerCategoriesCompanion(
                ledgerSyncId: ledgerSyncId,
                syncId: syncId,
                name: name,
                kind: kind,
                icon: icon,
                color: color,
                sortOrder: sortOrder,
                level: level,
                parentName: parentName,
                parentSyncId: parentSyncId,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String ledgerSyncId,
                required String syncId,
                required String name,
                required String kind,
                Value<String?> icon = const Value.absent(),
                Value<String?> color = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<int> level = const Value.absent(),
                Value<String?> parentName = const Value.absent(),
                Value<String?> parentSyncId = const Value.absent(),
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => SharedLedgerCategoriesCompanion.insert(
                ledgerSyncId: ledgerSyncId,
                syncId: syncId,
                name: name,
                kind: kind,
                icon: icon,
                color: color,
                sortOrder: sortOrder,
                level: level,
                parentName: parentName,
                parentSyncId: parentSyncId,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SharedLedgerCategoriesTableProcessedTableManager =
    ProcessedTableManager<
      _$SpitoutDatabase,
      $SharedLedgerCategoriesTable,
      SharedLedgerCategory,
      $$SharedLedgerCategoriesTableFilterComposer,
      $$SharedLedgerCategoriesTableOrderingComposer,
      $$SharedLedgerCategoriesTableAnnotationComposer,
      $$SharedLedgerCategoriesTableCreateCompanionBuilder,
      $$SharedLedgerCategoriesTableUpdateCompanionBuilder,
      (
        SharedLedgerCategory,
        BaseReferences<
          _$SpitoutDatabase,
          $SharedLedgerCategoriesTable,
          SharedLedgerCategory
        >,
      ),
      SharedLedgerCategory,
      PrefetchHooks Function()
    >;
typedef $$SyncPullErrorsTableCreateCompanionBuilder =
    SyncPullErrorsCompanion Function({
      Value<int> id,
      required int changeId,
      Value<String?> ledgerExternalId,
      required String entityType,
      required String entitySyncId,
      required String action,
      required String rawChangeJson,
      Value<String?> errorClass,
      Value<String?> errorMessage,
      Value<String?> stackTrace,
      required DateTime firstSeenAt,
      required DateTime lastAttemptAt,
      Value<int> attemptCount,
      Value<String?> userAction,
      Value<DateTime?> resolvedAt,
    });
typedef $$SyncPullErrorsTableUpdateCompanionBuilder =
    SyncPullErrorsCompanion Function({
      Value<int> id,
      Value<int> changeId,
      Value<String?> ledgerExternalId,
      Value<String> entityType,
      Value<String> entitySyncId,
      Value<String> action,
      Value<String> rawChangeJson,
      Value<String?> errorClass,
      Value<String?> errorMessage,
      Value<String?> stackTrace,
      Value<DateTime> firstSeenAt,
      Value<DateTime> lastAttemptAt,
      Value<int> attemptCount,
      Value<String?> userAction,
      Value<DateTime?> resolvedAt,
    });

class $$SyncPullErrorsTableFilterComposer
    extends Composer<_$SpitoutDatabase, $SyncPullErrorsTable> {
  $$SyncPullErrorsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get changeId => $composableBuilder(
    column: $table.changeId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ledgerExternalId => $composableBuilder(
    column: $table.ledgerExternalId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get entityType => $composableBuilder(
    column: $table.entityType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get entitySyncId => $composableBuilder(
    column: $table.entitySyncId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get action => $composableBuilder(
    column: $table.action,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get rawChangeJson => $composableBuilder(
    column: $table.rawChangeJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get errorClass => $composableBuilder(
    column: $table.errorClass,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get errorMessage => $composableBuilder(
    column: $table.errorMessage,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get stackTrace => $composableBuilder(
    column: $table.stackTrace,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get firstSeenAt => $composableBuilder(
    column: $table.firstSeenAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastAttemptAt => $composableBuilder(
    column: $table.lastAttemptAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get attemptCount => $composableBuilder(
    column: $table.attemptCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get userAction => $composableBuilder(
    column: $table.userAction,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get resolvedAt => $composableBuilder(
    column: $table.resolvedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SyncPullErrorsTableOrderingComposer
    extends Composer<_$SpitoutDatabase, $SyncPullErrorsTable> {
  $$SyncPullErrorsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get changeId => $composableBuilder(
    column: $table.changeId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ledgerExternalId => $composableBuilder(
    column: $table.ledgerExternalId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get entityType => $composableBuilder(
    column: $table.entityType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get entitySyncId => $composableBuilder(
    column: $table.entitySyncId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get action => $composableBuilder(
    column: $table.action,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get rawChangeJson => $composableBuilder(
    column: $table.rawChangeJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get errorClass => $composableBuilder(
    column: $table.errorClass,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get errorMessage => $composableBuilder(
    column: $table.errorMessage,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get stackTrace => $composableBuilder(
    column: $table.stackTrace,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get firstSeenAt => $composableBuilder(
    column: $table.firstSeenAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastAttemptAt => $composableBuilder(
    column: $table.lastAttemptAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get attemptCount => $composableBuilder(
    column: $table.attemptCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get userAction => $composableBuilder(
    column: $table.userAction,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get resolvedAt => $composableBuilder(
    column: $table.resolvedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SyncPullErrorsTableAnnotationComposer
    extends Composer<_$SpitoutDatabase, $SyncPullErrorsTable> {
  $$SyncPullErrorsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get changeId =>
      $composableBuilder(column: $table.changeId, builder: (column) => column);

  GeneratedColumn<String> get ledgerExternalId => $composableBuilder(
    column: $table.ledgerExternalId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get entityType => $composableBuilder(
    column: $table.entityType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get entitySyncId => $composableBuilder(
    column: $table.entitySyncId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get action =>
      $composableBuilder(column: $table.action, builder: (column) => column);

  GeneratedColumn<String> get rawChangeJson => $composableBuilder(
    column: $table.rawChangeJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get errorClass => $composableBuilder(
    column: $table.errorClass,
    builder: (column) => column,
  );

  GeneratedColumn<String> get errorMessage => $composableBuilder(
    column: $table.errorMessage,
    builder: (column) => column,
  );

  GeneratedColumn<String> get stackTrace => $composableBuilder(
    column: $table.stackTrace,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get firstSeenAt => $composableBuilder(
    column: $table.firstSeenAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get lastAttemptAt => $composableBuilder(
    column: $table.lastAttemptAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get attemptCount => $composableBuilder(
    column: $table.attemptCount,
    builder: (column) => column,
  );

  GeneratedColumn<String> get userAction => $composableBuilder(
    column: $table.userAction,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get resolvedAt => $composableBuilder(
    column: $table.resolvedAt,
    builder: (column) => column,
  );
}

class $$SyncPullErrorsTableTableManager
    extends
        RootTableManager<
          _$SpitoutDatabase,
          $SyncPullErrorsTable,
          SyncPullError,
          $$SyncPullErrorsTableFilterComposer,
          $$SyncPullErrorsTableOrderingComposer,
          $$SyncPullErrorsTableAnnotationComposer,
          $$SyncPullErrorsTableCreateCompanionBuilder,
          $$SyncPullErrorsTableUpdateCompanionBuilder,
          (
            SyncPullError,
            BaseReferences<
              _$SpitoutDatabase,
              $SyncPullErrorsTable,
              SyncPullError
            >,
          ),
          SyncPullError,
          PrefetchHooks Function()
        > {
  $$SyncPullErrorsTableTableManager(
    _$SpitoutDatabase db,
    $SyncPullErrorsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncPullErrorsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncPullErrorsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncPullErrorsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> changeId = const Value.absent(),
                Value<String?> ledgerExternalId = const Value.absent(),
                Value<String> entityType = const Value.absent(),
                Value<String> entitySyncId = const Value.absent(),
                Value<String> action = const Value.absent(),
                Value<String> rawChangeJson = const Value.absent(),
                Value<String?> errorClass = const Value.absent(),
                Value<String?> errorMessage = const Value.absent(),
                Value<String?> stackTrace = const Value.absent(),
                Value<DateTime> firstSeenAt = const Value.absent(),
                Value<DateTime> lastAttemptAt = const Value.absent(),
                Value<int> attemptCount = const Value.absent(),
                Value<String?> userAction = const Value.absent(),
                Value<DateTime?> resolvedAt = const Value.absent(),
              }) => SyncPullErrorsCompanion(
                id: id,
                changeId: changeId,
                ledgerExternalId: ledgerExternalId,
                entityType: entityType,
                entitySyncId: entitySyncId,
                action: action,
                rawChangeJson: rawChangeJson,
                errorClass: errorClass,
                errorMessage: errorMessage,
                stackTrace: stackTrace,
                firstSeenAt: firstSeenAt,
                lastAttemptAt: lastAttemptAt,
                attemptCount: attemptCount,
                userAction: userAction,
                resolvedAt: resolvedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int changeId,
                Value<String?> ledgerExternalId = const Value.absent(),
                required String entityType,
                required String entitySyncId,
                required String action,
                required String rawChangeJson,
                Value<String?> errorClass = const Value.absent(),
                Value<String?> errorMessage = const Value.absent(),
                Value<String?> stackTrace = const Value.absent(),
                required DateTime firstSeenAt,
                required DateTime lastAttemptAt,
                Value<int> attemptCount = const Value.absent(),
                Value<String?> userAction = const Value.absent(),
                Value<DateTime?> resolvedAt = const Value.absent(),
              }) => SyncPullErrorsCompanion.insert(
                id: id,
                changeId: changeId,
                ledgerExternalId: ledgerExternalId,
                entityType: entityType,
                entitySyncId: entitySyncId,
                action: action,
                rawChangeJson: rawChangeJson,
                errorClass: errorClass,
                errorMessage: errorMessage,
                stackTrace: stackTrace,
                firstSeenAt: firstSeenAt,
                lastAttemptAt: lastAttemptAt,
                attemptCount: attemptCount,
                userAction: userAction,
                resolvedAt: resolvedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SyncPullErrorsTableProcessedTableManager =
    ProcessedTableManager<
      _$SpitoutDatabase,
      $SyncPullErrorsTable,
      SyncPullError,
      $$SyncPullErrorsTableFilterComposer,
      $$SyncPullErrorsTableOrderingComposer,
      $$SyncPullErrorsTableAnnotationComposer,
      $$SyncPullErrorsTableCreateCompanionBuilder,
      $$SyncPullErrorsTableUpdateCompanionBuilder,
      (
        SyncPullError,
        BaseReferences<_$SpitoutDatabase, $SyncPullErrorsTable, SyncPullError>,
      ),
      SyncPullError,
      PrefetchHooks Function()
    >;
typedef $$ExchangeRatesTableCreateCompanionBuilder =
    ExchangeRatesCompanion Function({
      required String baseCurrency,
      required String quoteCurrency,
      required String rateDate,
      required String rate,
      required String source,
      required DateTime fetchedAt,
      Value<int> rowid,
    });
typedef $$ExchangeRatesTableUpdateCompanionBuilder =
    ExchangeRatesCompanion Function({
      Value<String> baseCurrency,
      Value<String> quoteCurrency,
      Value<String> rateDate,
      Value<String> rate,
      Value<String> source,
      Value<DateTime> fetchedAt,
      Value<int> rowid,
    });

class $$ExchangeRatesTableFilterComposer
    extends Composer<_$SpitoutDatabase, $ExchangeRatesTable> {
  $$ExchangeRatesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get baseCurrency => $composableBuilder(
    column: $table.baseCurrency,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get quoteCurrency => $composableBuilder(
    column: $table.quoteCurrency,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get rateDate => $composableBuilder(
    column: $table.rateDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get rate => $composableBuilder(
    column: $table.rate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get fetchedAt => $composableBuilder(
    column: $table.fetchedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ExchangeRatesTableOrderingComposer
    extends Composer<_$SpitoutDatabase, $ExchangeRatesTable> {
  $$ExchangeRatesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get baseCurrency => $composableBuilder(
    column: $table.baseCurrency,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get quoteCurrency => $composableBuilder(
    column: $table.quoteCurrency,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get rateDate => $composableBuilder(
    column: $table.rateDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get rate => $composableBuilder(
    column: $table.rate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get fetchedAt => $composableBuilder(
    column: $table.fetchedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ExchangeRatesTableAnnotationComposer
    extends Composer<_$SpitoutDatabase, $ExchangeRatesTable> {
  $$ExchangeRatesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get baseCurrency => $composableBuilder(
    column: $table.baseCurrency,
    builder: (column) => column,
  );

  GeneratedColumn<String> get quoteCurrency => $composableBuilder(
    column: $table.quoteCurrency,
    builder: (column) => column,
  );

  GeneratedColumn<String> get rateDate =>
      $composableBuilder(column: $table.rateDate, builder: (column) => column);

  GeneratedColumn<String> get rate =>
      $composableBuilder(column: $table.rate, builder: (column) => column);

  GeneratedColumn<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<DateTime> get fetchedAt =>
      $composableBuilder(column: $table.fetchedAt, builder: (column) => column);
}

class $$ExchangeRatesTableTableManager
    extends
        RootTableManager<
          _$SpitoutDatabase,
          $ExchangeRatesTable,
          ExchangeRate,
          $$ExchangeRatesTableFilterComposer,
          $$ExchangeRatesTableOrderingComposer,
          $$ExchangeRatesTableAnnotationComposer,
          $$ExchangeRatesTableCreateCompanionBuilder,
          $$ExchangeRatesTableUpdateCompanionBuilder,
          (
            ExchangeRate,
            BaseReferences<
              _$SpitoutDatabase,
              $ExchangeRatesTable,
              ExchangeRate
            >,
          ),
          ExchangeRate,
          PrefetchHooks Function()
        > {
  $$ExchangeRatesTableTableManager(
    _$SpitoutDatabase db,
    $ExchangeRatesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ExchangeRatesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ExchangeRatesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ExchangeRatesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> baseCurrency = const Value.absent(),
                Value<String> quoteCurrency = const Value.absent(),
                Value<String> rateDate = const Value.absent(),
                Value<String> rate = const Value.absent(),
                Value<String> source = const Value.absent(),
                Value<DateTime> fetchedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ExchangeRatesCompanion(
                baseCurrency: baseCurrency,
                quoteCurrency: quoteCurrency,
                rateDate: rateDate,
                rate: rate,
                source: source,
                fetchedAt: fetchedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String baseCurrency,
                required String quoteCurrency,
                required String rateDate,
                required String rate,
                required String source,
                required DateTime fetchedAt,
                Value<int> rowid = const Value.absent(),
              }) => ExchangeRatesCompanion.insert(
                baseCurrency: baseCurrency,
                quoteCurrency: quoteCurrency,
                rateDate: rateDate,
                rate: rate,
                source: source,
                fetchedAt: fetchedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ExchangeRatesTableProcessedTableManager =
    ProcessedTableManager<
      _$SpitoutDatabase,
      $ExchangeRatesTable,
      ExchangeRate,
      $$ExchangeRatesTableFilterComposer,
      $$ExchangeRatesTableOrderingComposer,
      $$ExchangeRatesTableAnnotationComposer,
      $$ExchangeRatesTableCreateCompanionBuilder,
      $$ExchangeRatesTableUpdateCompanionBuilder,
      (
        ExchangeRate,
        BaseReferences<_$SpitoutDatabase, $ExchangeRatesTable, ExchangeRate>,
      ),
      ExchangeRate,
      PrefetchHooks Function()
    >;
typedef $$ExchangeRateOverridesTableCreateCompanionBuilder =
    ExchangeRateOverridesCompanion Function({
      Value<int> id,
      Value<String?> syncId,
      required String baseCurrency,
      required String quoteCurrency,
      required String rate,
      Value<DateTime?> updatedAt,
    });
typedef $$ExchangeRateOverridesTableUpdateCompanionBuilder =
    ExchangeRateOverridesCompanion Function({
      Value<int> id,
      Value<String?> syncId,
      Value<String> baseCurrency,
      Value<String> quoteCurrency,
      Value<String> rate,
      Value<DateTime?> updatedAt,
    });

class $$ExchangeRateOverridesTableFilterComposer
    extends Composer<_$SpitoutDatabase, $ExchangeRateOverridesTable> {
  $$ExchangeRateOverridesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get syncId => $composableBuilder(
    column: $table.syncId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get baseCurrency => $composableBuilder(
    column: $table.baseCurrency,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get quoteCurrency => $composableBuilder(
    column: $table.quoteCurrency,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get rate => $composableBuilder(
    column: $table.rate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ExchangeRateOverridesTableOrderingComposer
    extends Composer<_$SpitoutDatabase, $ExchangeRateOverridesTable> {
  $$ExchangeRateOverridesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get syncId => $composableBuilder(
    column: $table.syncId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get baseCurrency => $composableBuilder(
    column: $table.baseCurrency,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get quoteCurrency => $composableBuilder(
    column: $table.quoteCurrency,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get rate => $composableBuilder(
    column: $table.rate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ExchangeRateOverridesTableAnnotationComposer
    extends Composer<_$SpitoutDatabase, $ExchangeRateOverridesTable> {
  $$ExchangeRateOverridesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get syncId =>
      $composableBuilder(column: $table.syncId, builder: (column) => column);

  GeneratedColumn<String> get baseCurrency => $composableBuilder(
    column: $table.baseCurrency,
    builder: (column) => column,
  );

  GeneratedColumn<String> get quoteCurrency => $composableBuilder(
    column: $table.quoteCurrency,
    builder: (column) => column,
  );

  GeneratedColumn<String> get rate =>
      $composableBuilder(column: $table.rate, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$ExchangeRateOverridesTableTableManager
    extends
        RootTableManager<
          _$SpitoutDatabase,
          $ExchangeRateOverridesTable,
          ExchangeRateOverride,
          $$ExchangeRateOverridesTableFilterComposer,
          $$ExchangeRateOverridesTableOrderingComposer,
          $$ExchangeRateOverridesTableAnnotationComposer,
          $$ExchangeRateOverridesTableCreateCompanionBuilder,
          $$ExchangeRateOverridesTableUpdateCompanionBuilder,
          (
            ExchangeRateOverride,
            BaseReferences<
              _$SpitoutDatabase,
              $ExchangeRateOverridesTable,
              ExchangeRateOverride
            >,
          ),
          ExchangeRateOverride,
          PrefetchHooks Function()
        > {
  $$ExchangeRateOverridesTableTableManager(
    _$SpitoutDatabase db,
    $ExchangeRateOverridesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ExchangeRateOverridesTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$ExchangeRateOverridesTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$ExchangeRateOverridesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String?> syncId = const Value.absent(),
                Value<String> baseCurrency = const Value.absent(),
                Value<String> quoteCurrency = const Value.absent(),
                Value<String> rate = const Value.absent(),
                Value<DateTime?> updatedAt = const Value.absent(),
              }) => ExchangeRateOverridesCompanion(
                id: id,
                syncId: syncId,
                baseCurrency: baseCurrency,
                quoteCurrency: quoteCurrency,
                rate: rate,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String?> syncId = const Value.absent(),
                required String baseCurrency,
                required String quoteCurrency,
                required String rate,
                Value<DateTime?> updatedAt = const Value.absent(),
              }) => ExchangeRateOverridesCompanion.insert(
                id: id,
                syncId: syncId,
                baseCurrency: baseCurrency,
                quoteCurrency: quoteCurrency,
                rate: rate,
                updatedAt: updatedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ExchangeRateOverridesTableProcessedTableManager =
    ProcessedTableManager<
      _$SpitoutDatabase,
      $ExchangeRateOverridesTable,
      ExchangeRateOverride,
      $$ExchangeRateOverridesTableFilterComposer,
      $$ExchangeRateOverridesTableOrderingComposer,
      $$ExchangeRateOverridesTableAnnotationComposer,
      $$ExchangeRateOverridesTableCreateCompanionBuilder,
      $$ExchangeRateOverridesTableUpdateCompanionBuilder,
      (
        ExchangeRateOverride,
        BaseReferences<
          _$SpitoutDatabase,
          $ExchangeRateOverridesTable,
          ExchangeRateOverride
        >,
      ),
      ExchangeRateOverride,
      PrefetchHooks Function()
    >;
typedef $$SnapshotDirtyLedgersTableCreateCompanionBuilder =
    SnapshotDirtyLedgersCompanion Function({
      Value<int> ledgerId,
      Value<DateTime> dirtyAt,
    });
typedef $$SnapshotDirtyLedgersTableUpdateCompanionBuilder =
    SnapshotDirtyLedgersCompanion Function({
      Value<int> ledgerId,
      Value<DateTime> dirtyAt,
    });

class $$SnapshotDirtyLedgersTableFilterComposer
    extends Composer<_$SpitoutDatabase, $SnapshotDirtyLedgersTable> {
  $$SnapshotDirtyLedgersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get ledgerId => $composableBuilder(
    column: $table.ledgerId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get dirtyAt => $composableBuilder(
    column: $table.dirtyAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SnapshotDirtyLedgersTableOrderingComposer
    extends Composer<_$SpitoutDatabase, $SnapshotDirtyLedgersTable> {
  $$SnapshotDirtyLedgersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get ledgerId => $composableBuilder(
    column: $table.ledgerId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get dirtyAt => $composableBuilder(
    column: $table.dirtyAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SnapshotDirtyLedgersTableAnnotationComposer
    extends Composer<_$SpitoutDatabase, $SnapshotDirtyLedgersTable> {
  $$SnapshotDirtyLedgersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get ledgerId =>
      $composableBuilder(column: $table.ledgerId, builder: (column) => column);

  GeneratedColumn<DateTime> get dirtyAt =>
      $composableBuilder(column: $table.dirtyAt, builder: (column) => column);
}

class $$SnapshotDirtyLedgersTableTableManager
    extends
        RootTableManager<
          _$SpitoutDatabase,
          $SnapshotDirtyLedgersTable,
          SnapshotDirtyLedger,
          $$SnapshotDirtyLedgersTableFilterComposer,
          $$SnapshotDirtyLedgersTableOrderingComposer,
          $$SnapshotDirtyLedgersTableAnnotationComposer,
          $$SnapshotDirtyLedgersTableCreateCompanionBuilder,
          $$SnapshotDirtyLedgersTableUpdateCompanionBuilder,
          (
            SnapshotDirtyLedger,
            BaseReferences<
              _$SpitoutDatabase,
              $SnapshotDirtyLedgersTable,
              SnapshotDirtyLedger
            >,
          ),
          SnapshotDirtyLedger,
          PrefetchHooks Function()
        > {
  $$SnapshotDirtyLedgersTableTableManager(
    _$SpitoutDatabase db,
    $SnapshotDirtyLedgersTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SnapshotDirtyLedgersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SnapshotDirtyLedgersTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$SnapshotDirtyLedgersTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> ledgerId = const Value.absent(),
                Value<DateTime> dirtyAt = const Value.absent(),
              }) => SnapshotDirtyLedgersCompanion(
                ledgerId: ledgerId,
                dirtyAt: dirtyAt,
              ),
          createCompanionCallback:
              ({
                Value<int> ledgerId = const Value.absent(),
                Value<DateTime> dirtyAt = const Value.absent(),
              }) => SnapshotDirtyLedgersCompanion.insert(
                ledgerId: ledgerId,
                dirtyAt: dirtyAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SnapshotDirtyLedgersTableProcessedTableManager =
    ProcessedTableManager<
      _$SpitoutDatabase,
      $SnapshotDirtyLedgersTable,
      SnapshotDirtyLedger,
      $$SnapshotDirtyLedgersTableFilterComposer,
      $$SnapshotDirtyLedgersTableOrderingComposer,
      $$SnapshotDirtyLedgersTableAnnotationComposer,
      $$SnapshotDirtyLedgersTableCreateCompanionBuilder,
      $$SnapshotDirtyLedgersTableUpdateCompanionBuilder,
      (
        SnapshotDirtyLedger,
        BaseReferences<
          _$SpitoutDatabase,
          $SnapshotDirtyLedgersTable,
          SnapshotDirtyLedger
        >,
      ),
      SnapshotDirtyLedger,
      PrefetchHooks Function()
    >;
typedef $$LedgerVirtualUsersTableCreateCompanionBuilder =
    LedgerVirtualUsersCompanion Function({
      Value<int> id,
      required int ledgerId,
      Value<String?> syncId,
      required String name,
      Value<DateTime> createdAt,
      Value<DateTime?> updatedAt,
    });
typedef $$LedgerVirtualUsersTableUpdateCompanionBuilder =
    LedgerVirtualUsersCompanion Function({
      Value<int> id,
      Value<int> ledgerId,
      Value<String?> syncId,
      Value<String> name,
      Value<DateTime> createdAt,
      Value<DateTime?> updatedAt,
    });

class $$LedgerVirtualUsersTableFilterComposer
    extends Composer<_$SpitoutDatabase, $LedgerVirtualUsersTable> {
  $$LedgerVirtualUsersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get ledgerId => $composableBuilder(
    column: $table.ledgerId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get syncId => $composableBuilder(
    column: $table.syncId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LedgerVirtualUsersTableOrderingComposer
    extends Composer<_$SpitoutDatabase, $LedgerVirtualUsersTable> {
  $$LedgerVirtualUsersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get ledgerId => $composableBuilder(
    column: $table.ledgerId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get syncId => $composableBuilder(
    column: $table.syncId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LedgerVirtualUsersTableAnnotationComposer
    extends Composer<_$SpitoutDatabase, $LedgerVirtualUsersTable> {
  $$LedgerVirtualUsersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get ledgerId =>
      $composableBuilder(column: $table.ledgerId, builder: (column) => column);

  GeneratedColumn<String> get syncId =>
      $composableBuilder(column: $table.syncId, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$LedgerVirtualUsersTableTableManager
    extends
        RootTableManager<
          _$SpitoutDatabase,
          $LedgerVirtualUsersTable,
          LedgerVirtualUser,
          $$LedgerVirtualUsersTableFilterComposer,
          $$LedgerVirtualUsersTableOrderingComposer,
          $$LedgerVirtualUsersTableAnnotationComposer,
          $$LedgerVirtualUsersTableCreateCompanionBuilder,
          $$LedgerVirtualUsersTableUpdateCompanionBuilder,
          (
            LedgerVirtualUser,
            BaseReferences<
              _$SpitoutDatabase,
              $LedgerVirtualUsersTable,
              LedgerVirtualUser
            >,
          ),
          LedgerVirtualUser,
          PrefetchHooks Function()
        > {
  $$LedgerVirtualUsersTableTableManager(
    _$SpitoutDatabase db,
    $LedgerVirtualUsersTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LedgerVirtualUsersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LedgerVirtualUsersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LedgerVirtualUsersTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> ledgerId = const Value.absent(),
                Value<String?> syncId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime?> updatedAt = const Value.absent(),
              }) => LedgerVirtualUsersCompanion(
                id: id,
                ledgerId: ledgerId,
                syncId: syncId,
                name: name,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int ledgerId,
                Value<String?> syncId = const Value.absent(),
                required String name,
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime?> updatedAt = const Value.absent(),
              }) => LedgerVirtualUsersCompanion.insert(
                id: id,
                ledgerId: ledgerId,
                syncId: syncId,
                name: name,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LedgerVirtualUsersTableProcessedTableManager =
    ProcessedTableManager<
      _$SpitoutDatabase,
      $LedgerVirtualUsersTable,
      LedgerVirtualUser,
      $$LedgerVirtualUsersTableFilterComposer,
      $$LedgerVirtualUsersTableOrderingComposer,
      $$LedgerVirtualUsersTableAnnotationComposer,
      $$LedgerVirtualUsersTableCreateCompanionBuilder,
      $$LedgerVirtualUsersTableUpdateCompanionBuilder,
      (
        LedgerVirtualUser,
        BaseReferences<
          _$SpitoutDatabase,
          $LedgerVirtualUsersTable,
          LedgerVirtualUser
        >,
      ),
      LedgerVirtualUser,
      PrefetchHooks Function()
    >;

class $SpitoutDatabaseManager {
  final _$SpitoutDatabase _db;
  $SpitoutDatabaseManager(this._db);
  $$LedgersTableTableManager get ledgers =>
      $$LedgersTableTableManager(_db, _db.ledgers);
  $$CategoriesTableTableManager get categories =>
      $$CategoriesTableTableManager(_db, _db.categories);
  $$RecurringTransactionsTableTableManager get recurringTransactions =>
      $$RecurringTransactionsTableTableManager(_db, _db.recurringTransactions);
  $$TransactionsTableTableManager get transactions =>
      $$TransactionsTableTableManager(_db, _db.transactions);
  $$RecordEditHistoriesTableTableManager get recordEditHistories =>
      $$RecordEditHistoriesTableTableManager(_db, _db.recordEditHistories);
  $$LocalChangesTableTableManager get localChanges =>
      $$LocalChangesTableTableManager(_db, _db.localChanges);
  $$SyncStateTableTableManager get syncState =>
      $$SyncStateTableTableManager(_db, _db.syncState);
  $$LedgerMembersTableTableManager get ledgerMembers =>
      $$LedgerMembersTableTableManager(_db, _db.ledgerMembers);
  $$SharedLedgerCategoriesTableTableManager get sharedLedgerCategories =>
      $$SharedLedgerCategoriesTableTableManager(
        _db,
        _db.sharedLedgerCategories,
      );
  $$SyncPullErrorsTableTableManager get syncPullErrors =>
      $$SyncPullErrorsTableTableManager(_db, _db.syncPullErrors);
  $$ExchangeRatesTableTableManager get exchangeRates =>
      $$ExchangeRatesTableTableManager(_db, _db.exchangeRates);
  $$ExchangeRateOverridesTableTableManager get exchangeRateOverrides =>
      $$ExchangeRateOverridesTableTableManager(_db, _db.exchangeRateOverrides);
  $$SnapshotDirtyLedgersTableTableManager get snapshotDirtyLedgers =>
      $$SnapshotDirtyLedgersTableTableManager(_db, _db.snapshotDirtyLedgers);
  $$LedgerVirtualUsersTableTableManager get ledgerVirtualUsers =>
      $$LedgerVirtualUsersTableTableManager(_db, _db.ledgerVirtualUsers);
}
