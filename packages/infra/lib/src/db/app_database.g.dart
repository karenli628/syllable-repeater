// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $LessonRegistryTable extends LessonRegistry
    with TableInfo<$LessonRegistryTable, LessonRegistryData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LessonRegistryTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _packPathMeta =
      const VerificationMeta('packPath');
  @override
  late final GeneratedColumn<String> packPath = GeneratedColumn<String>(
      'pack_path', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
      'title', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _contentHashMeta =
      const VerificationMeta('contentHash');
  @override
  late final GeneratedColumn<String> contentHash = GeneratedColumn<String>(
      'content_hash', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns =>
      [id, packPath, title, contentHash, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'lesson_registry';
  @override
  VerificationContext validateIntegrity(Insertable<LessonRegistryData> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('pack_path')) {
      context.handle(_packPathMeta,
          packPath.isAcceptableOrUnknown(data['pack_path']!, _packPathMeta));
    } else if (isInserting) {
      context.missing(_packPathMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
          _titleMeta, title.isAcceptableOrUnknown(data['title']!, _titleMeta));
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('content_hash')) {
      context.handle(
          _contentHashMeta,
          contentHash.isAcceptableOrUnknown(
              data['content_hash']!, _contentHashMeta));
    } else if (isInserting) {
      context.missing(_contentHashMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LessonRegistryData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LessonRegistryData(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      packPath: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}pack_path'])!,
      title: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}title'])!,
      contentHash: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}content_hash'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  $LessonRegistryTable createAlias(String alias) {
    return $LessonRegistryTable(attachedDatabase, alias);
  }
}

class LessonRegistryData extends DataClass
    implements Insertable<LessonRegistryData> {
  final String id;
  final String packPath;
  final String title;
  final String contentHash;
  final int updatedAt;
  const LessonRegistryData(
      {required this.id,
      required this.packPath,
      required this.title,
      required this.contentHash,
      required this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['pack_path'] = Variable<String>(packPath);
    map['title'] = Variable<String>(title);
    map['content_hash'] = Variable<String>(contentHash);
    map['updated_at'] = Variable<int>(updatedAt);
    return map;
  }

  LessonRegistryCompanion toCompanion(bool nullToAbsent) {
    return LessonRegistryCompanion(
      id: Value(id),
      packPath: Value(packPath),
      title: Value(title),
      contentHash: Value(contentHash),
      updatedAt: Value(updatedAt),
    );
  }

  factory LessonRegistryData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LessonRegistryData(
      id: serializer.fromJson<String>(json['id']),
      packPath: serializer.fromJson<String>(json['packPath']),
      title: serializer.fromJson<String>(json['title']),
      contentHash: serializer.fromJson<String>(json['contentHash']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'packPath': serializer.toJson<String>(packPath),
      'title': serializer.toJson<String>(title),
      'contentHash': serializer.toJson<String>(contentHash),
      'updatedAt': serializer.toJson<int>(updatedAt),
    };
  }

  LessonRegistryData copyWith(
          {String? id,
          String? packPath,
          String? title,
          String? contentHash,
          int? updatedAt}) =>
      LessonRegistryData(
        id: id ?? this.id,
        packPath: packPath ?? this.packPath,
        title: title ?? this.title,
        contentHash: contentHash ?? this.contentHash,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  LessonRegistryData copyWithCompanion(LessonRegistryCompanion data) {
    return LessonRegistryData(
      id: data.id.present ? data.id.value : this.id,
      packPath: data.packPath.present ? data.packPath.value : this.packPath,
      title: data.title.present ? data.title.value : this.title,
      contentHash:
          data.contentHash.present ? data.contentHash.value : this.contentHash,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LessonRegistryData(')
          ..write('id: $id, ')
          ..write('packPath: $packPath, ')
          ..write('title: $title, ')
          ..write('contentHash: $contentHash, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, packPath, title, contentHash, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LessonRegistryData &&
          other.id == this.id &&
          other.packPath == this.packPath &&
          other.title == this.title &&
          other.contentHash == this.contentHash &&
          other.updatedAt == this.updatedAt);
}

class LessonRegistryCompanion extends UpdateCompanion<LessonRegistryData> {
  final Value<String> id;
  final Value<String> packPath;
  final Value<String> title;
  final Value<String> contentHash;
  final Value<int> updatedAt;
  final Value<int> rowid;
  const LessonRegistryCompanion({
    this.id = const Value.absent(),
    this.packPath = const Value.absent(),
    this.title = const Value.absent(),
    this.contentHash = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LessonRegistryCompanion.insert({
    required String id,
    required String packPath,
    required String title,
    required String contentHash,
    required int updatedAt,
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        packPath = Value(packPath),
        title = Value(title),
        contentHash = Value(contentHash),
        updatedAt = Value(updatedAt);
  static Insertable<LessonRegistryData> custom({
    Expression<String>? id,
    Expression<String>? packPath,
    Expression<String>? title,
    Expression<String>? contentHash,
    Expression<int>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (packPath != null) 'pack_path': packPath,
      if (title != null) 'title': title,
      if (contentHash != null) 'content_hash': contentHash,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LessonRegistryCompanion copyWith(
      {Value<String>? id,
      Value<String>? packPath,
      Value<String>? title,
      Value<String>? contentHash,
      Value<int>? updatedAt,
      Value<int>? rowid}) {
    return LessonRegistryCompanion(
      id: id ?? this.id,
      packPath: packPath ?? this.packPath,
      title: title ?? this.title,
      contentHash: contentHash ?? this.contentHash,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (packPath.present) {
      map['pack_path'] = Variable<String>(packPath.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (contentHash.present) {
      map['content_hash'] = Variable<String>(contentHash.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LessonRegistryCompanion(')
          ..write('id: $id, ')
          ..write('packPath: $packPath, ')
          ..write('title: $title, ')
          ..write('contentHash: $contentHash, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PracticeGroupsTable extends PracticeGroups
    with TableInfo<$PracticeGroupsTable, PracticeGroup> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PracticeGroupsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _profileIdMeta =
      const VerificationMeta('profileId');
  @override
  late final GeneratedColumn<String> profileId = GeneratedColumn<String>(
      'profile_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _courseIdMeta =
      const VerificationMeta('courseId');
  @override
  late final GeneratedColumn<String> courseId = GeneratedColumn<String>(
      'course_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _lessonIdMeta =
      const VerificationMeta('lessonId');
  @override
  late final GeneratedColumn<String> lessonId = GeneratedColumn<String>(
      'lesson_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _configJsonMeta =
      const VerificationMeta('configJson');
  @override
  late final GeneratedColumn<String> configJson = GeneratedColumn<String>(
      'config_json', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
      'status', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('ACTIVE'));
  static const VerificationMeta _archivedAtMeta =
      const VerificationMeta('archivedAt');
  @override
  late final GeneratedColumn<int> archivedAt = GeneratedColumn<int>(
      'archived_at', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        profileId,
        courseId,
        lessonId,
        name,
        configJson,
        status,
        archivedAt,
        updatedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'practice_group';
  @override
  VerificationContext validateIntegrity(Insertable<PracticeGroup> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('profile_id')) {
      context.handle(_profileIdMeta,
          profileId.isAcceptableOrUnknown(data['profile_id']!, _profileIdMeta));
    } else if (isInserting) {
      context.missing(_profileIdMeta);
    }
    if (data.containsKey('course_id')) {
      context.handle(_courseIdMeta,
          courseId.isAcceptableOrUnknown(data['course_id']!, _courseIdMeta));
    } else if (isInserting) {
      context.missing(_courseIdMeta);
    }
    if (data.containsKey('lesson_id')) {
      context.handle(_lessonIdMeta,
          lessonId.isAcceptableOrUnknown(data['lesson_id']!, _lessonIdMeta));
    } else if (isInserting) {
      context.missing(_lessonIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('config_json')) {
      context.handle(
          _configJsonMeta,
          configJson.isAcceptableOrUnknown(
              data['config_json']!, _configJsonMeta));
    } else if (isInserting) {
      context.missing(_configJsonMeta);
    }
    if (data.containsKey('status')) {
      context.handle(_statusMeta,
          status.isAcceptableOrUnknown(data['status']!, _statusMeta));
    }
    if (data.containsKey('archived_at')) {
      context.handle(
          _archivedAtMeta,
          archivedAt.isAcceptableOrUnknown(
              data['archived_at']!, _archivedAtMeta));
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PracticeGroup map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PracticeGroup(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      profileId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}profile_id'])!,
      courseId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}course_id'])!,
      lessonId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}lesson_id'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      configJson: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}config_json'])!,
      status: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}status'])!,
      archivedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}archived_at']),
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  $PracticeGroupsTable createAlias(String alias) {
    return $PracticeGroupsTable(attachedDatabase, alias);
  }
}

class PracticeGroup extends DataClass implements Insertable<PracticeGroup> {
  final String id;
  final String profileId;
  final String courseId;
  final String lessonId;
  final String name;
  final String configJson;

  /// ACTIVE | ARCHIVED | EXPIRED（狀態機見 backend-design §3.1.3）。
  final String status;

  /// M8：168h 恢復期限起算點。
  final int? archivedAt;

  /// M6：upsert 比較鍵（較新覆寫）。
  final int updatedAt;
  const PracticeGroup(
      {required this.id,
      required this.profileId,
      required this.courseId,
      required this.lessonId,
      required this.name,
      required this.configJson,
      required this.status,
      this.archivedAt,
      required this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['profile_id'] = Variable<String>(profileId);
    map['course_id'] = Variable<String>(courseId);
    map['lesson_id'] = Variable<String>(lessonId);
    map['name'] = Variable<String>(name);
    map['config_json'] = Variable<String>(configJson);
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || archivedAt != null) {
      map['archived_at'] = Variable<int>(archivedAt);
    }
    map['updated_at'] = Variable<int>(updatedAt);
    return map;
  }

  PracticeGroupsCompanion toCompanion(bool nullToAbsent) {
    return PracticeGroupsCompanion(
      id: Value(id),
      profileId: Value(profileId),
      courseId: Value(courseId),
      lessonId: Value(lessonId),
      name: Value(name),
      configJson: Value(configJson),
      status: Value(status),
      archivedAt: archivedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(archivedAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory PracticeGroup.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PracticeGroup(
      id: serializer.fromJson<String>(json['id']),
      profileId: serializer.fromJson<String>(json['profileId']),
      courseId: serializer.fromJson<String>(json['courseId']),
      lessonId: serializer.fromJson<String>(json['lessonId']),
      name: serializer.fromJson<String>(json['name']),
      configJson: serializer.fromJson<String>(json['configJson']),
      status: serializer.fromJson<String>(json['status']),
      archivedAt: serializer.fromJson<int?>(json['archivedAt']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'profileId': serializer.toJson<String>(profileId),
      'courseId': serializer.toJson<String>(courseId),
      'lessonId': serializer.toJson<String>(lessonId),
      'name': serializer.toJson<String>(name),
      'configJson': serializer.toJson<String>(configJson),
      'status': serializer.toJson<String>(status),
      'archivedAt': serializer.toJson<int?>(archivedAt),
      'updatedAt': serializer.toJson<int>(updatedAt),
    };
  }

  PracticeGroup copyWith(
          {String? id,
          String? profileId,
          String? courseId,
          String? lessonId,
          String? name,
          String? configJson,
          String? status,
          Value<int?> archivedAt = const Value.absent(),
          int? updatedAt}) =>
      PracticeGroup(
        id: id ?? this.id,
        profileId: profileId ?? this.profileId,
        courseId: courseId ?? this.courseId,
        lessonId: lessonId ?? this.lessonId,
        name: name ?? this.name,
        configJson: configJson ?? this.configJson,
        status: status ?? this.status,
        archivedAt: archivedAt.present ? archivedAt.value : this.archivedAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  PracticeGroup copyWithCompanion(PracticeGroupsCompanion data) {
    return PracticeGroup(
      id: data.id.present ? data.id.value : this.id,
      profileId: data.profileId.present ? data.profileId.value : this.profileId,
      courseId: data.courseId.present ? data.courseId.value : this.courseId,
      lessonId: data.lessonId.present ? data.lessonId.value : this.lessonId,
      name: data.name.present ? data.name.value : this.name,
      configJson:
          data.configJson.present ? data.configJson.value : this.configJson,
      status: data.status.present ? data.status.value : this.status,
      archivedAt:
          data.archivedAt.present ? data.archivedAt.value : this.archivedAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PracticeGroup(')
          ..write('id: $id, ')
          ..write('profileId: $profileId, ')
          ..write('courseId: $courseId, ')
          ..write('lessonId: $lessonId, ')
          ..write('name: $name, ')
          ..write('configJson: $configJson, ')
          ..write('status: $status, ')
          ..write('archivedAt: $archivedAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, profileId, courseId, lessonId, name,
      configJson, status, archivedAt, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PracticeGroup &&
          other.id == this.id &&
          other.profileId == this.profileId &&
          other.courseId == this.courseId &&
          other.lessonId == this.lessonId &&
          other.name == this.name &&
          other.configJson == this.configJson &&
          other.status == this.status &&
          other.archivedAt == this.archivedAt &&
          other.updatedAt == this.updatedAt);
}

class PracticeGroupsCompanion extends UpdateCompanion<PracticeGroup> {
  final Value<String> id;
  final Value<String> profileId;
  final Value<String> courseId;
  final Value<String> lessonId;
  final Value<String> name;
  final Value<String> configJson;
  final Value<String> status;
  final Value<int?> archivedAt;
  final Value<int> updatedAt;
  final Value<int> rowid;
  const PracticeGroupsCompanion({
    this.id = const Value.absent(),
    this.profileId = const Value.absent(),
    this.courseId = const Value.absent(),
    this.lessonId = const Value.absent(),
    this.name = const Value.absent(),
    this.configJson = const Value.absent(),
    this.status = const Value.absent(),
    this.archivedAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PracticeGroupsCompanion.insert({
    required String id,
    required String profileId,
    required String courseId,
    required String lessonId,
    required String name,
    required String configJson,
    this.status = const Value.absent(),
    this.archivedAt = const Value.absent(),
    required int updatedAt,
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        profileId = Value(profileId),
        courseId = Value(courseId),
        lessonId = Value(lessonId),
        name = Value(name),
        configJson = Value(configJson),
        updatedAt = Value(updatedAt);
  static Insertable<PracticeGroup> custom({
    Expression<String>? id,
    Expression<String>? profileId,
    Expression<String>? courseId,
    Expression<String>? lessonId,
    Expression<String>? name,
    Expression<String>? configJson,
    Expression<String>? status,
    Expression<int>? archivedAt,
    Expression<int>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (profileId != null) 'profile_id': profileId,
      if (courseId != null) 'course_id': courseId,
      if (lessonId != null) 'lesson_id': lessonId,
      if (name != null) 'name': name,
      if (configJson != null) 'config_json': configJson,
      if (status != null) 'status': status,
      if (archivedAt != null) 'archived_at': archivedAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PracticeGroupsCompanion copyWith(
      {Value<String>? id,
      Value<String>? profileId,
      Value<String>? courseId,
      Value<String>? lessonId,
      Value<String>? name,
      Value<String>? configJson,
      Value<String>? status,
      Value<int?>? archivedAt,
      Value<int>? updatedAt,
      Value<int>? rowid}) {
    return PracticeGroupsCompanion(
      id: id ?? this.id,
      profileId: profileId ?? this.profileId,
      courseId: courseId ?? this.courseId,
      lessonId: lessonId ?? this.lessonId,
      name: name ?? this.name,
      configJson: configJson ?? this.configJson,
      status: status ?? this.status,
      archivedAt: archivedAt ?? this.archivedAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (profileId.present) {
      map['profile_id'] = Variable<String>(profileId.value);
    }
    if (courseId.present) {
      map['course_id'] = Variable<String>(courseId.value);
    }
    if (lessonId.present) {
      map['lesson_id'] = Variable<String>(lessonId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (configJson.present) {
      map['config_json'] = Variable<String>(configJson.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (archivedAt.present) {
      map['archived_at'] = Variable<int>(archivedAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PracticeGroupsCompanion(')
          ..write('id: $id, ')
          ..write('profileId: $profileId, ')
          ..write('courseId: $courseId, ')
          ..write('lessonId: $lessonId, ')
          ..write('name: $name, ')
          ..write('configJson: $configJson, ')
          ..write('status: $status, ')
          ..write('archivedAt: $archivedAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SrsStatesTable extends SrsStates
    with TableInfo<$SrsStatesTable, SrsState> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SrsStatesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _groupIdMeta =
      const VerificationMeta('groupId');
  @override
  late final GeneratedColumn<String> groupId = GeneratedColumn<String>(
      'group_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _intervalIndexMeta =
      const VerificationMeta('intervalIndex');
  @override
  late final GeneratedColumn<int> intervalIndex = GeneratedColumn<int>(
      'interval_index', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _nextDueMeta =
      const VerificationMeta('nextDue');
  @override
  late final GeneratedColumn<int> nextDue = GeneratedColumn<int>(
      'next_due', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _difficultyMeta =
      const VerificationMeta('difficulty');
  @override
  late final GeneratedColumn<String> difficulty = GeneratedColumn<String>(
      'difficulty', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('NORMAL'));
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns =>
      [groupId, intervalIndex, nextDue, difficulty, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'srs_state';
  @override
  VerificationContext validateIntegrity(Insertable<SrsState> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('group_id')) {
      context.handle(_groupIdMeta,
          groupId.isAcceptableOrUnknown(data['group_id']!, _groupIdMeta));
    } else if (isInserting) {
      context.missing(_groupIdMeta);
    }
    if (data.containsKey('interval_index')) {
      context.handle(
          _intervalIndexMeta,
          intervalIndex.isAcceptableOrUnknown(
              data['interval_index']!, _intervalIndexMeta));
    }
    if (data.containsKey('next_due')) {
      context.handle(_nextDueMeta,
          nextDue.isAcceptableOrUnknown(data['next_due']!, _nextDueMeta));
    } else if (isInserting) {
      context.missing(_nextDueMeta);
    }
    if (data.containsKey('difficulty')) {
      context.handle(
          _difficultyMeta,
          difficulty.isAcceptableOrUnknown(
              data['difficulty']!, _difficultyMeta));
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {groupId};
  @override
  SrsState map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SrsState(
      groupId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}group_id'])!,
      intervalIndex: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}interval_index'])!,
      nextDue: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}next_due'])!,
      difficulty: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}difficulty'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  $SrsStatesTable createAlias(String alias) {
    return $SrsStatesTable(attachedDatabase, alias);
  }
}

class SrsState extends DataClass implements Insertable<SrsState> {
  final String groupId;
  final int intervalIndex;
  final int nextDue;

  /// HARD | NORMAL | EASY。
  final String difficulty;
  final int updatedAt;
  const SrsState(
      {required this.groupId,
      required this.intervalIndex,
      required this.nextDue,
      required this.difficulty,
      required this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['group_id'] = Variable<String>(groupId);
    map['interval_index'] = Variable<int>(intervalIndex);
    map['next_due'] = Variable<int>(nextDue);
    map['difficulty'] = Variable<String>(difficulty);
    map['updated_at'] = Variable<int>(updatedAt);
    return map;
  }

  SrsStatesCompanion toCompanion(bool nullToAbsent) {
    return SrsStatesCompanion(
      groupId: Value(groupId),
      intervalIndex: Value(intervalIndex),
      nextDue: Value(nextDue),
      difficulty: Value(difficulty),
      updatedAt: Value(updatedAt),
    );
  }

  factory SrsState.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SrsState(
      groupId: serializer.fromJson<String>(json['groupId']),
      intervalIndex: serializer.fromJson<int>(json['intervalIndex']),
      nextDue: serializer.fromJson<int>(json['nextDue']),
      difficulty: serializer.fromJson<String>(json['difficulty']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'groupId': serializer.toJson<String>(groupId),
      'intervalIndex': serializer.toJson<int>(intervalIndex),
      'nextDue': serializer.toJson<int>(nextDue),
      'difficulty': serializer.toJson<String>(difficulty),
      'updatedAt': serializer.toJson<int>(updatedAt),
    };
  }

  SrsState copyWith(
          {String? groupId,
          int? intervalIndex,
          int? nextDue,
          String? difficulty,
          int? updatedAt}) =>
      SrsState(
        groupId: groupId ?? this.groupId,
        intervalIndex: intervalIndex ?? this.intervalIndex,
        nextDue: nextDue ?? this.nextDue,
        difficulty: difficulty ?? this.difficulty,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  SrsState copyWithCompanion(SrsStatesCompanion data) {
    return SrsState(
      groupId: data.groupId.present ? data.groupId.value : this.groupId,
      intervalIndex: data.intervalIndex.present
          ? data.intervalIndex.value
          : this.intervalIndex,
      nextDue: data.nextDue.present ? data.nextDue.value : this.nextDue,
      difficulty:
          data.difficulty.present ? data.difficulty.value : this.difficulty,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SrsState(')
          ..write('groupId: $groupId, ')
          ..write('intervalIndex: $intervalIndex, ')
          ..write('nextDue: $nextDue, ')
          ..write('difficulty: $difficulty, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(groupId, intervalIndex, nextDue, difficulty, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SrsState &&
          other.groupId == this.groupId &&
          other.intervalIndex == this.intervalIndex &&
          other.nextDue == this.nextDue &&
          other.difficulty == this.difficulty &&
          other.updatedAt == this.updatedAt);
}

class SrsStatesCompanion extends UpdateCompanion<SrsState> {
  final Value<String> groupId;
  final Value<int> intervalIndex;
  final Value<int> nextDue;
  final Value<String> difficulty;
  final Value<int> updatedAt;
  final Value<int> rowid;
  const SrsStatesCompanion({
    this.groupId = const Value.absent(),
    this.intervalIndex = const Value.absent(),
    this.nextDue = const Value.absent(),
    this.difficulty = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SrsStatesCompanion.insert({
    required String groupId,
    this.intervalIndex = const Value.absent(),
    required int nextDue,
    this.difficulty = const Value.absent(),
    required int updatedAt,
    this.rowid = const Value.absent(),
  })  : groupId = Value(groupId),
        nextDue = Value(nextDue),
        updatedAt = Value(updatedAt);
  static Insertable<SrsState> custom({
    Expression<String>? groupId,
    Expression<int>? intervalIndex,
    Expression<int>? nextDue,
    Expression<String>? difficulty,
    Expression<int>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (groupId != null) 'group_id': groupId,
      if (intervalIndex != null) 'interval_index': intervalIndex,
      if (nextDue != null) 'next_due': nextDue,
      if (difficulty != null) 'difficulty': difficulty,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SrsStatesCompanion copyWith(
      {Value<String>? groupId,
      Value<int>? intervalIndex,
      Value<int>? nextDue,
      Value<String>? difficulty,
      Value<int>? updatedAt,
      Value<int>? rowid}) {
    return SrsStatesCompanion(
      groupId: groupId ?? this.groupId,
      intervalIndex: intervalIndex ?? this.intervalIndex,
      nextDue: nextDue ?? this.nextDue,
      difficulty: difficulty ?? this.difficulty,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (groupId.present) {
      map['group_id'] = Variable<String>(groupId.value);
    }
    if (intervalIndex.present) {
      map['interval_index'] = Variable<int>(intervalIndex.value);
    }
    if (nextDue.present) {
      map['next_due'] = Variable<int>(nextDue.value);
    }
    if (difficulty.present) {
      map['difficulty'] = Variable<String>(difficulty.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SrsStatesCompanion(')
          ..write('groupId: $groupId, ')
          ..write('intervalIndex: $intervalIndex, ')
          ..write('nextDue: $nextDue, ')
          ..write('difficulty: $difficulty, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AttemptsTable extends Attempts with TableInfo<$AttemptsTable, Attempt> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AttemptsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _groupIdMeta =
      const VerificationMeta('groupId');
  @override
  late final GeneratedColumn<String> groupId = GeneratedColumn<String>(
      'group_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _stepIndexMeta =
      const VerificationMeta('stepIndex');
  @override
  late final GeneratedColumn<int> stepIndex = GeneratedColumn<int>(
      'step_index', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _rhythmDeltaMeta =
      const VerificationMeta('rhythmDelta');
  @override
  late final GeneratedColumn<double> rhythmDelta = GeneratedColumn<double>(
      'rhythm_delta', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _intonationDeltaMeta =
      const VerificationMeta('intonationDelta');
  @override
  late final GeneratedColumn<double> intonationDelta = GeneratedColumn<double>(
      'intonation_delta', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _overlayJsonMeta =
      const VerificationMeta('overlayJson');
  @override
  late final GeneratedColumn<String> overlayJson = GeneratedColumn<String>(
      'overlay_json', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
      'created_at', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        groupId,
        stepIndex,
        rhythmDelta,
        intonationDelta,
        overlayJson,
        createdAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'attempt';
  @override
  VerificationContext validateIntegrity(Insertable<Attempt> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('group_id')) {
      context.handle(_groupIdMeta,
          groupId.isAcceptableOrUnknown(data['group_id']!, _groupIdMeta));
    } else if (isInserting) {
      context.missing(_groupIdMeta);
    }
    if (data.containsKey('step_index')) {
      context.handle(_stepIndexMeta,
          stepIndex.isAcceptableOrUnknown(data['step_index']!, _stepIndexMeta));
    } else if (isInserting) {
      context.missing(_stepIndexMeta);
    }
    if (data.containsKey('rhythm_delta')) {
      context.handle(
          _rhythmDeltaMeta,
          rhythmDelta.isAcceptableOrUnknown(
              data['rhythm_delta']!, _rhythmDeltaMeta));
    } else if (isInserting) {
      context.missing(_rhythmDeltaMeta);
    }
    if (data.containsKey('intonation_delta')) {
      context.handle(
          _intonationDeltaMeta,
          intonationDelta.isAcceptableOrUnknown(
              data['intonation_delta']!, _intonationDeltaMeta));
    } else if (isInserting) {
      context.missing(_intonationDeltaMeta);
    }
    if (data.containsKey('overlay_json')) {
      context.handle(
          _overlayJsonMeta,
          overlayJson.isAcceptableOrUnknown(
              data['overlay_json']!, _overlayJsonMeta));
    } else if (isInserting) {
      context.missing(_overlayJsonMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Attempt map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Attempt(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      groupId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}group_id'])!,
      stepIndex: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}step_index'])!,
      rhythmDelta: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}rhythm_delta'])!,
      intonationDelta: attachedDatabase.typeMapping.read(
          DriftSqlType.double, data['${effectivePrefix}intonation_delta'])!,
      overlayJson: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}overlay_json'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}created_at'])!,
    );
  }

  @override
  $AttemptsTable createAlias(String alias) {
    return $AttemptsTable(attachedDatabase, alias);
  }
}

class Attempt extends DataClass implements Insertable<Attempt> {
  final String id;
  final String groupId;
  final int stepIndex;
  final double rhythmDelta;
  final double intonationDelta;
  final String overlayJson;
  final int createdAt;
  const Attempt(
      {required this.id,
      required this.groupId,
      required this.stepIndex,
      required this.rhythmDelta,
      required this.intonationDelta,
      required this.overlayJson,
      required this.createdAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['group_id'] = Variable<String>(groupId);
    map['step_index'] = Variable<int>(stepIndex);
    map['rhythm_delta'] = Variable<double>(rhythmDelta);
    map['intonation_delta'] = Variable<double>(intonationDelta);
    map['overlay_json'] = Variable<String>(overlayJson);
    map['created_at'] = Variable<int>(createdAt);
    return map;
  }

  AttemptsCompanion toCompanion(bool nullToAbsent) {
    return AttemptsCompanion(
      id: Value(id),
      groupId: Value(groupId),
      stepIndex: Value(stepIndex),
      rhythmDelta: Value(rhythmDelta),
      intonationDelta: Value(intonationDelta),
      overlayJson: Value(overlayJson),
      createdAt: Value(createdAt),
    );
  }

  factory Attempt.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Attempt(
      id: serializer.fromJson<String>(json['id']),
      groupId: serializer.fromJson<String>(json['groupId']),
      stepIndex: serializer.fromJson<int>(json['stepIndex']),
      rhythmDelta: serializer.fromJson<double>(json['rhythmDelta']),
      intonationDelta: serializer.fromJson<double>(json['intonationDelta']),
      overlayJson: serializer.fromJson<String>(json['overlayJson']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'groupId': serializer.toJson<String>(groupId),
      'stepIndex': serializer.toJson<int>(stepIndex),
      'rhythmDelta': serializer.toJson<double>(rhythmDelta),
      'intonationDelta': serializer.toJson<double>(intonationDelta),
      'overlayJson': serializer.toJson<String>(overlayJson),
      'createdAt': serializer.toJson<int>(createdAt),
    };
  }

  Attempt copyWith(
          {String? id,
          String? groupId,
          int? stepIndex,
          double? rhythmDelta,
          double? intonationDelta,
          String? overlayJson,
          int? createdAt}) =>
      Attempt(
        id: id ?? this.id,
        groupId: groupId ?? this.groupId,
        stepIndex: stepIndex ?? this.stepIndex,
        rhythmDelta: rhythmDelta ?? this.rhythmDelta,
        intonationDelta: intonationDelta ?? this.intonationDelta,
        overlayJson: overlayJson ?? this.overlayJson,
        createdAt: createdAt ?? this.createdAt,
      );
  Attempt copyWithCompanion(AttemptsCompanion data) {
    return Attempt(
      id: data.id.present ? data.id.value : this.id,
      groupId: data.groupId.present ? data.groupId.value : this.groupId,
      stepIndex: data.stepIndex.present ? data.stepIndex.value : this.stepIndex,
      rhythmDelta:
          data.rhythmDelta.present ? data.rhythmDelta.value : this.rhythmDelta,
      intonationDelta: data.intonationDelta.present
          ? data.intonationDelta.value
          : this.intonationDelta,
      overlayJson:
          data.overlayJson.present ? data.overlayJson.value : this.overlayJson,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Attempt(')
          ..write('id: $id, ')
          ..write('groupId: $groupId, ')
          ..write('stepIndex: $stepIndex, ')
          ..write('rhythmDelta: $rhythmDelta, ')
          ..write('intonationDelta: $intonationDelta, ')
          ..write('overlayJson: $overlayJson, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, groupId, stepIndex, rhythmDelta,
      intonationDelta, overlayJson, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Attempt &&
          other.id == this.id &&
          other.groupId == this.groupId &&
          other.stepIndex == this.stepIndex &&
          other.rhythmDelta == this.rhythmDelta &&
          other.intonationDelta == this.intonationDelta &&
          other.overlayJson == this.overlayJson &&
          other.createdAt == this.createdAt);
}

class AttemptsCompanion extends UpdateCompanion<Attempt> {
  final Value<String> id;
  final Value<String> groupId;
  final Value<int> stepIndex;
  final Value<double> rhythmDelta;
  final Value<double> intonationDelta;
  final Value<String> overlayJson;
  final Value<int> createdAt;
  final Value<int> rowid;
  const AttemptsCompanion({
    this.id = const Value.absent(),
    this.groupId = const Value.absent(),
    this.stepIndex = const Value.absent(),
    this.rhythmDelta = const Value.absent(),
    this.intonationDelta = const Value.absent(),
    this.overlayJson = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AttemptsCompanion.insert({
    required String id,
    required String groupId,
    required int stepIndex,
    required double rhythmDelta,
    required double intonationDelta,
    required String overlayJson,
    required int createdAt,
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        groupId = Value(groupId),
        stepIndex = Value(stepIndex),
        rhythmDelta = Value(rhythmDelta),
        intonationDelta = Value(intonationDelta),
        overlayJson = Value(overlayJson),
        createdAt = Value(createdAt);
  static Insertable<Attempt> custom({
    Expression<String>? id,
    Expression<String>? groupId,
    Expression<int>? stepIndex,
    Expression<double>? rhythmDelta,
    Expression<double>? intonationDelta,
    Expression<String>? overlayJson,
    Expression<int>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (groupId != null) 'group_id': groupId,
      if (stepIndex != null) 'step_index': stepIndex,
      if (rhythmDelta != null) 'rhythm_delta': rhythmDelta,
      if (intonationDelta != null) 'intonation_delta': intonationDelta,
      if (overlayJson != null) 'overlay_json': overlayJson,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AttemptsCompanion copyWith(
      {Value<String>? id,
      Value<String>? groupId,
      Value<int>? stepIndex,
      Value<double>? rhythmDelta,
      Value<double>? intonationDelta,
      Value<String>? overlayJson,
      Value<int>? createdAt,
      Value<int>? rowid}) {
    return AttemptsCompanion(
      id: id ?? this.id,
      groupId: groupId ?? this.groupId,
      stepIndex: stepIndex ?? this.stepIndex,
      rhythmDelta: rhythmDelta ?? this.rhythmDelta,
      intonationDelta: intonationDelta ?? this.intonationDelta,
      overlayJson: overlayJson ?? this.overlayJson,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (groupId.present) {
      map['group_id'] = Variable<String>(groupId.value);
    }
    if (stepIndex.present) {
      map['step_index'] = Variable<int>(stepIndex.value);
    }
    if (rhythmDelta.present) {
      map['rhythm_delta'] = Variable<double>(rhythmDelta.value);
    }
    if (intonationDelta.present) {
      map['intonation_delta'] = Variable<double>(intonationDelta.value);
    }
    if (overlayJson.present) {
      map['overlay_json'] = Variable<String>(overlayJson.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AttemptsCompanion(')
          ..write('id: $id, ')
          ..write('groupId: $groupId, ')
          ..write('stepIndex: $stepIndex, ')
          ..write('rhythmDelta: $rhythmDelta, ')
          ..write('intonationDelta: $intonationDelta, ')
          ..write('overlayJson: $overlayJson, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AppSettingsTable extends AppSettings
    with TableInfo<$AppSettingsTable, AppSetting> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AppSettingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
      'key', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
      'value', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'app_settings';
  @override
  VerificationContext validateIntegrity(Insertable<AppSetting> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
          _keyMeta, key.isAcceptableOrUnknown(data['key']!, _keyMeta));
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
          _valueMeta, value.isAcceptableOrUnknown(data['value']!, _valueMeta));
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  AppSetting map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AppSetting(
      key: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}key'])!,
      value: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}value'])!,
    );
  }

  @override
  $AppSettingsTable createAlias(String alias) {
    return $AppSettingsTable(attachedDatabase, alias);
  }
}

class AppSetting extends DataClass implements Insertable<AppSetting> {
  final String key;
  final String value;
  const AppSetting({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  AppSettingsCompanion toCompanion(bool nullToAbsent) {
    return AppSettingsCompanion(
      key: Value(key),
      value: Value(value),
    );
  }

  factory AppSetting.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AppSetting(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
    };
  }

  AppSetting copyWith({String? key, String? value}) => AppSetting(
        key: key ?? this.key,
        value: value ?? this.value,
      );
  AppSetting copyWithCompanion(AppSettingsCompanion data) {
    return AppSetting(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AppSetting(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AppSetting &&
          other.key == this.key &&
          other.value == this.value);
}

class AppSettingsCompanion extends UpdateCompanion<AppSetting> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const AppSettingsCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AppSettingsCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  })  : key = Value(key),
        value = Value(value);
  static Insertable<AppSetting> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AppSettingsCompanion copyWith(
      {Value<String>? key, Value<String>? value, Value<int>? rowid}) {
    return AppSettingsCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AppSettingsCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $LessonRegistryTable lessonRegistry = $LessonRegistryTable(this);
  late final $PracticeGroupsTable practiceGroups = $PracticeGroupsTable(this);
  late final $SrsStatesTable srsStates = $SrsStatesTable(this);
  late final $AttemptsTable attempts = $AttemptsTable(this);
  late final $AppSettingsTable appSettings = $AppSettingsTable(this);
  late final Index idxPgSyncKey = Index('idx_pg_sync_key',
      'CREATE INDEX idx_pg_sync_key ON practice_group (profile_id, course_id, lesson_id)');
  late final Index idxPgStatus = Index(
      'idx_pg_status', 'CREATE INDEX idx_pg_status ON practice_group (status)');
  late final Index idxSrsDue =
      Index('idx_srs_due', 'CREATE INDEX idx_srs_due ON srs_state (next_due)');
  late final Index idxAttemptGroup = Index('idx_attempt_group',
      'CREATE INDEX idx_attempt_group ON attempt (group_id, created_at)');
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
        lessonRegistry,
        practiceGroups,
        srsStates,
        attempts,
        appSettings,
        idxPgSyncKey,
        idxPgStatus,
        idxSrsDue,
        idxAttemptGroup
      ];
}

typedef $$LessonRegistryTableCreateCompanionBuilder = LessonRegistryCompanion
    Function({
  required String id,
  required String packPath,
  required String title,
  required String contentHash,
  required int updatedAt,
  Value<int> rowid,
});
typedef $$LessonRegistryTableUpdateCompanionBuilder = LessonRegistryCompanion
    Function({
  Value<String> id,
  Value<String> packPath,
  Value<String> title,
  Value<String> contentHash,
  Value<int> updatedAt,
  Value<int> rowid,
});

class $$LessonRegistryTableFilterComposer
    extends Composer<_$AppDatabase, $LessonRegistryTable> {
  $$LessonRegistryTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get packPath => $composableBuilder(
      column: $table.packPath, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get contentHash => $composableBuilder(
      column: $table.contentHash, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));
}

class $$LessonRegistryTableOrderingComposer
    extends Composer<_$AppDatabase, $LessonRegistryTable> {
  $$LessonRegistryTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get packPath => $composableBuilder(
      column: $table.packPath, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get contentHash => $composableBuilder(
      column: $table.contentHash, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));
}

class $$LessonRegistryTableAnnotationComposer
    extends Composer<_$AppDatabase, $LessonRegistryTable> {
  $$LessonRegistryTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get packPath =>
      $composableBuilder(column: $table.packPath, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get contentHash => $composableBuilder(
      column: $table.contentHash, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$LessonRegistryTableTableManager extends RootTableManager<
    _$AppDatabase,
    $LessonRegistryTable,
    LessonRegistryData,
    $$LessonRegistryTableFilterComposer,
    $$LessonRegistryTableOrderingComposer,
    $$LessonRegistryTableAnnotationComposer,
    $$LessonRegistryTableCreateCompanionBuilder,
    $$LessonRegistryTableUpdateCompanionBuilder,
    (
      LessonRegistryData,
      BaseReferences<_$AppDatabase, $LessonRegistryTable, LessonRegistryData>
    ),
    LessonRegistryData,
    PrefetchHooks Function()> {
  $$LessonRegistryTableTableManager(
      _$AppDatabase db, $LessonRegistryTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LessonRegistryTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LessonRegistryTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LessonRegistryTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> packPath = const Value.absent(),
            Value<String> title = const Value.absent(),
            Value<String> contentHash = const Value.absent(),
            Value<int> updatedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              LessonRegistryCompanion(
            id: id,
            packPath: packPath,
            title: title,
            contentHash: contentHash,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String packPath,
            required String title,
            required String contentHash,
            required int updatedAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              LessonRegistryCompanion.insert(
            id: id,
            packPath: packPath,
            title: title,
            contentHash: contentHash,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$LessonRegistryTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $LessonRegistryTable,
    LessonRegistryData,
    $$LessonRegistryTableFilterComposer,
    $$LessonRegistryTableOrderingComposer,
    $$LessonRegistryTableAnnotationComposer,
    $$LessonRegistryTableCreateCompanionBuilder,
    $$LessonRegistryTableUpdateCompanionBuilder,
    (
      LessonRegistryData,
      BaseReferences<_$AppDatabase, $LessonRegistryTable, LessonRegistryData>
    ),
    LessonRegistryData,
    PrefetchHooks Function()>;
typedef $$PracticeGroupsTableCreateCompanionBuilder = PracticeGroupsCompanion
    Function({
  required String id,
  required String profileId,
  required String courseId,
  required String lessonId,
  required String name,
  required String configJson,
  Value<String> status,
  Value<int?> archivedAt,
  required int updatedAt,
  Value<int> rowid,
});
typedef $$PracticeGroupsTableUpdateCompanionBuilder = PracticeGroupsCompanion
    Function({
  Value<String> id,
  Value<String> profileId,
  Value<String> courseId,
  Value<String> lessonId,
  Value<String> name,
  Value<String> configJson,
  Value<String> status,
  Value<int?> archivedAt,
  Value<int> updatedAt,
  Value<int> rowid,
});

class $$PracticeGroupsTableFilterComposer
    extends Composer<_$AppDatabase, $PracticeGroupsTable> {
  $$PracticeGroupsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get profileId => $composableBuilder(
      column: $table.profileId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get courseId => $composableBuilder(
      column: $table.courseId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get lessonId => $composableBuilder(
      column: $table.lessonId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get configJson => $composableBuilder(
      column: $table.configJson, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get archivedAt => $composableBuilder(
      column: $table.archivedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));
}

class $$PracticeGroupsTableOrderingComposer
    extends Composer<_$AppDatabase, $PracticeGroupsTable> {
  $$PracticeGroupsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get profileId => $composableBuilder(
      column: $table.profileId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get courseId => $composableBuilder(
      column: $table.courseId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get lessonId => $composableBuilder(
      column: $table.lessonId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get configJson => $composableBuilder(
      column: $table.configJson, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get archivedAt => $composableBuilder(
      column: $table.archivedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));
}

class $$PracticeGroupsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PracticeGroupsTable> {
  $$PracticeGroupsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get profileId =>
      $composableBuilder(column: $table.profileId, builder: (column) => column);

  GeneratedColumn<String> get courseId =>
      $composableBuilder(column: $table.courseId, builder: (column) => column);

  GeneratedColumn<String> get lessonId =>
      $composableBuilder(column: $table.lessonId, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get configJson => $composableBuilder(
      column: $table.configJson, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<int> get archivedAt => $composableBuilder(
      column: $table.archivedAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$PracticeGroupsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $PracticeGroupsTable,
    PracticeGroup,
    $$PracticeGroupsTableFilterComposer,
    $$PracticeGroupsTableOrderingComposer,
    $$PracticeGroupsTableAnnotationComposer,
    $$PracticeGroupsTableCreateCompanionBuilder,
    $$PracticeGroupsTableUpdateCompanionBuilder,
    (
      PracticeGroup,
      BaseReferences<_$AppDatabase, $PracticeGroupsTable, PracticeGroup>
    ),
    PracticeGroup,
    PrefetchHooks Function()> {
  $$PracticeGroupsTableTableManager(
      _$AppDatabase db, $PracticeGroupsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PracticeGroupsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PracticeGroupsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PracticeGroupsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> profileId = const Value.absent(),
            Value<String> courseId = const Value.absent(),
            Value<String> lessonId = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<String> configJson = const Value.absent(),
            Value<String> status = const Value.absent(),
            Value<int?> archivedAt = const Value.absent(),
            Value<int> updatedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              PracticeGroupsCompanion(
            id: id,
            profileId: profileId,
            courseId: courseId,
            lessonId: lessonId,
            name: name,
            configJson: configJson,
            status: status,
            archivedAt: archivedAt,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String profileId,
            required String courseId,
            required String lessonId,
            required String name,
            required String configJson,
            Value<String> status = const Value.absent(),
            Value<int?> archivedAt = const Value.absent(),
            required int updatedAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              PracticeGroupsCompanion.insert(
            id: id,
            profileId: profileId,
            courseId: courseId,
            lessonId: lessonId,
            name: name,
            configJson: configJson,
            status: status,
            archivedAt: archivedAt,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$PracticeGroupsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $PracticeGroupsTable,
    PracticeGroup,
    $$PracticeGroupsTableFilterComposer,
    $$PracticeGroupsTableOrderingComposer,
    $$PracticeGroupsTableAnnotationComposer,
    $$PracticeGroupsTableCreateCompanionBuilder,
    $$PracticeGroupsTableUpdateCompanionBuilder,
    (
      PracticeGroup,
      BaseReferences<_$AppDatabase, $PracticeGroupsTable, PracticeGroup>
    ),
    PracticeGroup,
    PrefetchHooks Function()>;
typedef $$SrsStatesTableCreateCompanionBuilder = SrsStatesCompanion Function({
  required String groupId,
  Value<int> intervalIndex,
  required int nextDue,
  Value<String> difficulty,
  required int updatedAt,
  Value<int> rowid,
});
typedef $$SrsStatesTableUpdateCompanionBuilder = SrsStatesCompanion Function({
  Value<String> groupId,
  Value<int> intervalIndex,
  Value<int> nextDue,
  Value<String> difficulty,
  Value<int> updatedAt,
  Value<int> rowid,
});

class $$SrsStatesTableFilterComposer
    extends Composer<_$AppDatabase, $SrsStatesTable> {
  $$SrsStatesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get groupId => $composableBuilder(
      column: $table.groupId, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get intervalIndex => $composableBuilder(
      column: $table.intervalIndex, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get nextDue => $composableBuilder(
      column: $table.nextDue, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get difficulty => $composableBuilder(
      column: $table.difficulty, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));
}

class $$SrsStatesTableOrderingComposer
    extends Composer<_$AppDatabase, $SrsStatesTable> {
  $$SrsStatesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get groupId => $composableBuilder(
      column: $table.groupId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get intervalIndex => $composableBuilder(
      column: $table.intervalIndex,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get nextDue => $composableBuilder(
      column: $table.nextDue, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get difficulty => $composableBuilder(
      column: $table.difficulty, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));
}

class $$SrsStatesTableAnnotationComposer
    extends Composer<_$AppDatabase, $SrsStatesTable> {
  $$SrsStatesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get groupId =>
      $composableBuilder(column: $table.groupId, builder: (column) => column);

  GeneratedColumn<int> get intervalIndex => $composableBuilder(
      column: $table.intervalIndex, builder: (column) => column);

  GeneratedColumn<int> get nextDue =>
      $composableBuilder(column: $table.nextDue, builder: (column) => column);

  GeneratedColumn<String> get difficulty => $composableBuilder(
      column: $table.difficulty, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$SrsStatesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $SrsStatesTable,
    SrsState,
    $$SrsStatesTableFilterComposer,
    $$SrsStatesTableOrderingComposer,
    $$SrsStatesTableAnnotationComposer,
    $$SrsStatesTableCreateCompanionBuilder,
    $$SrsStatesTableUpdateCompanionBuilder,
    (SrsState, BaseReferences<_$AppDatabase, $SrsStatesTable, SrsState>),
    SrsState,
    PrefetchHooks Function()> {
  $$SrsStatesTableTableManager(_$AppDatabase db, $SrsStatesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SrsStatesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SrsStatesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SrsStatesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> groupId = const Value.absent(),
            Value<int> intervalIndex = const Value.absent(),
            Value<int> nextDue = const Value.absent(),
            Value<String> difficulty = const Value.absent(),
            Value<int> updatedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              SrsStatesCompanion(
            groupId: groupId,
            intervalIndex: intervalIndex,
            nextDue: nextDue,
            difficulty: difficulty,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String groupId,
            Value<int> intervalIndex = const Value.absent(),
            required int nextDue,
            Value<String> difficulty = const Value.absent(),
            required int updatedAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              SrsStatesCompanion.insert(
            groupId: groupId,
            intervalIndex: intervalIndex,
            nextDue: nextDue,
            difficulty: difficulty,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$SrsStatesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $SrsStatesTable,
    SrsState,
    $$SrsStatesTableFilterComposer,
    $$SrsStatesTableOrderingComposer,
    $$SrsStatesTableAnnotationComposer,
    $$SrsStatesTableCreateCompanionBuilder,
    $$SrsStatesTableUpdateCompanionBuilder,
    (SrsState, BaseReferences<_$AppDatabase, $SrsStatesTable, SrsState>),
    SrsState,
    PrefetchHooks Function()>;
typedef $$AttemptsTableCreateCompanionBuilder = AttemptsCompanion Function({
  required String id,
  required String groupId,
  required int stepIndex,
  required double rhythmDelta,
  required double intonationDelta,
  required String overlayJson,
  required int createdAt,
  Value<int> rowid,
});
typedef $$AttemptsTableUpdateCompanionBuilder = AttemptsCompanion Function({
  Value<String> id,
  Value<String> groupId,
  Value<int> stepIndex,
  Value<double> rhythmDelta,
  Value<double> intonationDelta,
  Value<String> overlayJson,
  Value<int> createdAt,
  Value<int> rowid,
});

class $$AttemptsTableFilterComposer
    extends Composer<_$AppDatabase, $AttemptsTable> {
  $$AttemptsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get groupId => $composableBuilder(
      column: $table.groupId, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get stepIndex => $composableBuilder(
      column: $table.stepIndex, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get rhythmDelta => $composableBuilder(
      column: $table.rhythmDelta, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get intonationDelta => $composableBuilder(
      column: $table.intonationDelta,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get overlayJson => $composableBuilder(
      column: $table.overlayJson, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));
}

class $$AttemptsTableOrderingComposer
    extends Composer<_$AppDatabase, $AttemptsTable> {
  $$AttemptsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get groupId => $composableBuilder(
      column: $table.groupId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get stepIndex => $composableBuilder(
      column: $table.stepIndex, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get rhythmDelta => $composableBuilder(
      column: $table.rhythmDelta, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get intonationDelta => $composableBuilder(
      column: $table.intonationDelta,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get overlayJson => $composableBuilder(
      column: $table.overlayJson, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));
}

class $$AttemptsTableAnnotationComposer
    extends Composer<_$AppDatabase, $AttemptsTable> {
  $$AttemptsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get groupId =>
      $composableBuilder(column: $table.groupId, builder: (column) => column);

  GeneratedColumn<int> get stepIndex =>
      $composableBuilder(column: $table.stepIndex, builder: (column) => column);

  GeneratedColumn<double> get rhythmDelta => $composableBuilder(
      column: $table.rhythmDelta, builder: (column) => column);

  GeneratedColumn<double> get intonationDelta => $composableBuilder(
      column: $table.intonationDelta, builder: (column) => column);

  GeneratedColumn<String> get overlayJson => $composableBuilder(
      column: $table.overlayJson, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$AttemptsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $AttemptsTable,
    Attempt,
    $$AttemptsTableFilterComposer,
    $$AttemptsTableOrderingComposer,
    $$AttemptsTableAnnotationComposer,
    $$AttemptsTableCreateCompanionBuilder,
    $$AttemptsTableUpdateCompanionBuilder,
    (Attempt, BaseReferences<_$AppDatabase, $AttemptsTable, Attempt>),
    Attempt,
    PrefetchHooks Function()> {
  $$AttemptsTableTableManager(_$AppDatabase db, $AttemptsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AttemptsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AttemptsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AttemptsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> groupId = const Value.absent(),
            Value<int> stepIndex = const Value.absent(),
            Value<double> rhythmDelta = const Value.absent(),
            Value<double> intonationDelta = const Value.absent(),
            Value<String> overlayJson = const Value.absent(),
            Value<int> createdAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              AttemptsCompanion(
            id: id,
            groupId: groupId,
            stepIndex: stepIndex,
            rhythmDelta: rhythmDelta,
            intonationDelta: intonationDelta,
            overlayJson: overlayJson,
            createdAt: createdAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String groupId,
            required int stepIndex,
            required double rhythmDelta,
            required double intonationDelta,
            required String overlayJson,
            required int createdAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              AttemptsCompanion.insert(
            id: id,
            groupId: groupId,
            stepIndex: stepIndex,
            rhythmDelta: rhythmDelta,
            intonationDelta: intonationDelta,
            overlayJson: overlayJson,
            createdAt: createdAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$AttemptsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $AttemptsTable,
    Attempt,
    $$AttemptsTableFilterComposer,
    $$AttemptsTableOrderingComposer,
    $$AttemptsTableAnnotationComposer,
    $$AttemptsTableCreateCompanionBuilder,
    $$AttemptsTableUpdateCompanionBuilder,
    (Attempt, BaseReferences<_$AppDatabase, $AttemptsTable, Attempt>),
    Attempt,
    PrefetchHooks Function()>;
typedef $$AppSettingsTableCreateCompanionBuilder = AppSettingsCompanion
    Function({
  required String key,
  required String value,
  Value<int> rowid,
});
typedef $$AppSettingsTableUpdateCompanionBuilder = AppSettingsCompanion
    Function({
  Value<String> key,
  Value<String> value,
  Value<int> rowid,
});

class $$AppSettingsTableFilterComposer
    extends Composer<_$AppDatabase, $AppSettingsTable> {
  $$AppSettingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
      column: $table.key, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get value => $composableBuilder(
      column: $table.value, builder: (column) => ColumnFilters(column));
}

class $$AppSettingsTableOrderingComposer
    extends Composer<_$AppDatabase, $AppSettingsTable> {
  $$AppSettingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
      column: $table.key, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get value => $composableBuilder(
      column: $table.value, builder: (column) => ColumnOrderings(column));
}

class $$AppSettingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $AppSettingsTable> {
  $$AppSettingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$AppSettingsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $AppSettingsTable,
    AppSetting,
    $$AppSettingsTableFilterComposer,
    $$AppSettingsTableOrderingComposer,
    $$AppSettingsTableAnnotationComposer,
    $$AppSettingsTableCreateCompanionBuilder,
    $$AppSettingsTableUpdateCompanionBuilder,
    (AppSetting, BaseReferences<_$AppDatabase, $AppSettingsTable, AppSetting>),
    AppSetting,
    PrefetchHooks Function()> {
  $$AppSettingsTableTableManager(_$AppDatabase db, $AppSettingsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AppSettingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AppSettingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AppSettingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> key = const Value.absent(),
            Value<String> value = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              AppSettingsCompanion(
            key: key,
            value: value,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String key,
            required String value,
            Value<int> rowid = const Value.absent(),
          }) =>
              AppSettingsCompanion.insert(
            key: key,
            value: value,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$AppSettingsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $AppSettingsTable,
    AppSetting,
    $$AppSettingsTableFilterComposer,
    $$AppSettingsTableOrderingComposer,
    $$AppSettingsTableAnnotationComposer,
    $$AppSettingsTableCreateCompanionBuilder,
    $$AppSettingsTableUpdateCompanionBuilder,
    (AppSetting, BaseReferences<_$AppDatabase, $AppSettingsTable, AppSetting>),
    AppSetting,
    PrefetchHooks Function()>;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$LessonRegistryTableTableManager get lessonRegistry =>
      $$LessonRegistryTableTableManager(_db, _db.lessonRegistry);
  $$PracticeGroupsTableTableManager get practiceGroups =>
      $$PracticeGroupsTableTableManager(_db, _db.practiceGroups);
  $$SrsStatesTableTableManager get srsStates =>
      $$SrsStatesTableTableManager(_db, _db.srsStates);
  $$AttemptsTableTableManager get attempts =>
      $$AttemptsTableTableManager(_db, _db.attempts);
  $$AppSettingsTableTableManager get appSettings =>
      $$AppSettingsTableTableManager(_db, _db.appSettings);
}
