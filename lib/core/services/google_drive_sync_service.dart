import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sadhana/data/datasources/local_storage_datasource.dart';
import 'package:sadhana/data/models/mandala_resource_model.dart';
import 'package:sadhana/data/models/resource_folder_model.dart';
import 'package:sadhana/data/repositories/sadhana_repository.dart';

class DriveSyncStatus {
  const DriveSyncStatus({
    required this.enabled,
    required this.connected,
    required this.accountEmail,
    required this.folderId,
    required this.lastSyncAt,
  });

  final bool enabled;
  final bool connected;
  final String? accountEmail;
  final String folderId;
  final String lastSyncAt;
}

class DriveSyncReport {
  const DriveSyncReport({
    required this.uploadedResources,
    required this.downloadedResources,
    required this.backupUploaded,
  });

  final int uploadedResources;
  final int downloadedResources;
  final bool backupUploaded;
}

class GoogleDriveSyncService {
  GoogleDriveSyncService(this._datasource, this._repository);

  final LocalStorageDatasource _datasource;
  final SadhanaRepository _repository;

  static const _enabledKey = 'drive_sync_enabled';
  static const _accountEmailKey = 'drive_sync_account_email';
  static const _folderIdKey = 'drive_sync_folder_id';
  static const _lastSyncAtKey = 'drive_sync_last_sync_at';
  static const _resourceFileIdByResourceKey = 'drive_sync_resource_file_ids';

  GoogleSignIn? _googleSignIn;

  Future<DriveSyncStatus> getStatus() async {
    final enabled = _datasource.getSetting(_enabledKey) == true;
    final folderId = (_datasource.getSetting(_folderIdKey) as String? ?? '')
        .trim();
    final lastSyncAt = (_datasource.getSetting(_lastSyncAtKey) as String? ?? '')
        .trim();
    final accountEmail = (_datasource.getSetting(_accountEmailKey) as String?)
        ?.trim();
    final connected = accountEmail != null && accountEmail.isNotEmpty;
    return DriveSyncStatus(
      enabled: enabled,
      connected: connected,
      accountEmail: connected ? accountEmail : null,
      folderId: folderId,
      lastSyncAt: lastSyncAt,
    );
  }

  Future<void> setEnabled(bool enabled) async {
    await _datasource.saveSetting(_enabledKey, enabled);
  }

  Future<void> setFolderId(String folderId) async {
    await _datasource.saveSetting(_folderIdKey, folderId.trim());
  }

  Future<String?> connect() async {
    final googleSignIn = _googleSignInOrThrow();
    final account = await googleSignIn.signIn();
    if (account == null) return null;
    await _datasource.saveSetting(_accountEmailKey, account.email);
    return account.email;
  }

  Future<void> disconnect() async {
    final googleSignIn = _googleSignIn;
    if (googleSignIn != null) {
      await googleSignIn.signOut();
    }
    await _datasource.deleteSetting(_accountEmailKey);
    await _datasource.deleteSetting(_resourceFileIdByResourceKey);
  }

  Future<DriveSyncReport> syncNow() async {
    final status = await getStatus();
    if (!status.enabled) {
      throw StateError('La sincronización con Drive está desactivada.');
    }
    if (status.folderId.isEmpty) {
      throw StateError('Debes configurar un folderId de Google Drive.');
    }

    final googleSignIn = _googleSignInOrThrow();
    final account =
        await googleSignIn.signInSilently() ?? await googleSignIn.signIn();
    if (account == null) {
      throw StateError('No se pudo iniciar sesión con Google.');
    }
    await _datasource.saveSetting(_accountEmailKey, account.email);

    final client = await googleSignIn.authenticatedClient();
    if (client == null) {
      throw StateError('No se pudo autenticar cliente de Google Drive.');
    }
    final api = drive.DriveApi(client);

    final resourcesRootId = await _ensureSubfolder(
      api: api,
      parentId: status.folderId,
      name: 'resources_sync',
    );
    final backupUploaded = await _uploadBackupJson(
      api: api,
      parentId: status.folderId,
    );
    final uploaded = await _pushLocalResources(
      api: api,
      resourcesRootId: resourcesRootId,
    );
    final downloaded = await _pullRemoteResources(
      api: api,
      resourcesRootId: resourcesRootId,
    );

    await _datasource.saveSetting(
      _lastSyncAtKey,
      DateTime.now().toIso8601String(),
    );
    return DriveSyncReport(
      uploadedResources: uploaded,
      downloadedResources: downloaded,
      backupUploaded: backupUploaded,
    );
  }

  Future<String> downloadBackupJsonFromDrive() async {
    final status = await getStatus();
    if (!status.enabled) {
      throw StateError('La sincronización con Drive está desactivada.');
    }
    if (status.folderId.isEmpty) {
      throw StateError('Debes configurar un folderId de Google Drive.');
    }
    final googleSignIn = _googleSignInOrThrow();
    final account =
        await googleSignIn.signInSilently() ?? await googleSignIn.signIn();
    if (account == null) {
      throw StateError('No se pudo iniciar sesión con Google.');
    }
    final client = await googleSignIn.authenticatedClient();
    if (client == null) {
      throw StateError('No se pudo autenticar cliente de Google Drive.');
    }
    final api = drive.DriveApi(client);
    final backup = await _findFileByName(
      api: api,
      parentId: status.folderId,
      name: 'sadhana_backup.json',
    );
    if (backup == null || backup.id == null) {
      throw StateError('No se encontró backup en la carpeta de Drive.');
    }
    final result = await api.files.get(
      backup.id!,
      downloadOptions: drive.DownloadOptions.fullMedia,
    );
    if (result is! drive.Media) {
      throw StateError('No se pudo descargar backup desde Drive.');
    }
    final bytes = <int>[];
    await for (final chunk in result.stream) {
      bytes.addAll(chunk);
    }
    return utf8.decode(bytes);
  }

  Future<bool> _uploadBackupJson({
    required drive.DriveApi api,
    required String parentId,
  }) async {
    final backupJson = await _repository.exportBackupJson();
    final backupName = 'sadhana_backup.json';
    final existing = await _findFileByName(
      api: api,
      parentId: parentId,
      name: backupName,
    );
    final metadata = drive.File()
      ..name = backupName
      ..parents = [parentId]
      ..mimeType = 'application/json';
    final payload = utf8.encode(backupJson);
    final media = drive.Media(
      Stream<List<int>>.fromIterable([payload]),
      payload.length,
      contentType: 'application/json',
    );
    if (existing == null) {
      await api.files.create(metadata, uploadMedia: media);
    } else {
      await api.files.update(metadata, existing.id!, uploadMedia: media);
    }
    return true;
  }

  Future<int> _pushLocalResources({
    required drive.DriveApi api,
    required String resourcesRootId,
  }) async {
    final map = _readResourceFileIdMap();
    var uploaded = 0;
    final folderCache = <String, String>{};
    final items = _repository.getMandalaResources();
    for (final resource in items) {
      final sourcePath = (resource.filePath ?? '').trim();
      if (sourcePath.isEmpty || _isWebUrl(sourcePath)) continue;
      final sourceFile = File(sourcePath);
      if (!await sourceFile.exists()) continue;

      final remoteFolderId = await _remoteFolderForLocalFolder(
        api: api,
        resourcesRootId: resourcesRootId,
        localFolderId: resource.folderId,
        cache: folderCache,
      );

      final extension = p.extension(sourcePath);
      final name = '${resource.id}__${_sanitizeName(resource.title)}$extension';
      final media = drive.Media(
        sourceFile.openRead(),
        await sourceFile.length(),
      );
      final metadata = drive.File()
        ..name = name
        ..parents = [remoteFolderId]
        ..appProperties = {
          'resourceId': resource.id,
          'folderId': resource.folderId,
          'title': resource.title,
          'type': resource.type.name,
        };
      final knownFileId = map[resource.id];
      if (knownFileId == null || knownFileId.trim().isEmpty) {
        final created = await api.files.create(metadata, uploadMedia: media);
        if (created.id != null && created.id!.isNotEmpty) {
          map[resource.id] = created.id!;
          uploaded++;
        }
      } else {
        await api.files.update(metadata, knownFileId, uploadMedia: media);
        uploaded++;
      }
    }
    await _saveResourceFileIdMap(map);
    return uploaded;
  }

  Future<int> _pullRemoteResources({
    required drive.DriveApi api,
    required String resourcesRootId,
  }) async {
    final map = _readResourceFileIdMap();
    final remoteFolders = await api.files.list(
      q: "'$resourcesRootId' in parents and mimeType='application/vnd.google-apps.folder' and trashed=false",
      $fields: 'files(id,name)',
      spaces: 'drive',
    );

    final docs = await getApplicationDocumentsDirectory();
    var downloaded = 0;
    for (final folder in remoteFolders.files ?? const <drive.File>[]) {
      final remoteFolderId = folder.id;
      final localFolderId = (folder.name ?? '').trim();
      if (remoteFolderId == null || localFolderId.isEmpty) continue;

      final localFolderExists = _repository.getResourceFolders().any(
        (f) => f.id == localFolderId,
      );
      if (!localFolderExists) {
        await _repository.saveResourceFolder(
          // Se crea carpeta mínima para no perder recursos remotos.
          // El usuario puede renombrarla luego.
          // ignore: prefer_const_constructors
          ResourceFolderModel(
            id: localFolderId,
            name: 'Drive $localFolderId',
            circle: 0,
            createdAt: DateTime.now().toIso8601String(),
          ),
        );
      }

      final remoteFiles = await api.files.list(
        q: "'$remoteFolderId' in parents and mimeType!='application/vnd.google-apps.folder' and trashed=false",
        $fields: 'files(id,name,mimeType,appProperties,modifiedTime)',
        spaces: 'drive',
      );
      for (final file in remoteFiles.files ?? const <drive.File>[]) {
        final fileId = file.id;
        if (fileId == null || fileId.trim().isEmpty) continue;
        final appProps = file.appProperties ?? const <String, String>{};
        final resourceId = (appProps['resourceId'] ?? fileId).trim();
        final resourceTitle = (appProps['title'] ?? file.name ?? 'Recurso')
            .trim();
        final resourceType = _parseType(
          appProps['type'],
          file.name ?? '',
          file.mimeType ?? '',
        );

        final targetDir = Directory(
          p.join(docs.path, 'resources', 'drive_sync', localFolderId),
        );
        if (!await targetDir.exists()) {
          await targetDir.create(recursive: true);
        }
        final safeName = (file.name ?? fileId).replaceAll('/', '_');
        final localPath = p.join(targetDir.path, '${fileId}_$safeName');
        final media = await api.files.get(
          fileId,
          downloadOptions: drive.DownloadOptions.fullMedia,
        );
        if (media is drive.Media) {
          final sink = File(localPath).openWrite();
          await media.stream.pipe(sink);
          await sink.close();
        } else {
          continue;
        }

        final existing = _repository.getMandalaResourceById(resourceId);
        final createdAt =
            file.modifiedTime?.toIso8601String() ??
            DateTime.now().toIso8601String();
        final model = existing == null
            ? MandalaResourceModel(
                id: resourceId,
                cycleId: localFolderId,
                folderId: localFolderId,
                title: resourceTitle,
                type: resourceType,
                createdAt: createdAt,
                filePath: localPath,
                inlineText: null,
              )
            : existing.copyWith(
                folderId: localFolderId,
                title: resourceTitle,
                type: resourceType,
                filePath: localPath,
              );
        await _repository.saveMandalaResource(model);
        map[resourceId] = fileId;
        downloaded++;
      }
    }

    await _saveResourceFileIdMap(map);
    return downloaded;
  }

  Future<String> _ensureSubfolder({
    required drive.DriveApi api,
    required String parentId,
    required String name,
  }) async {
    final existing = await _findFolderByName(
      api: api,
      parentId: parentId,
      name: name,
    );
    if (existing != null && existing.id != null) return existing.id!;
    final created = await api.files.create(
      drive.File()
        ..name = name
        ..parents = [parentId]
        ..mimeType = 'application/vnd.google-apps.folder',
    );
    if (created.id == null || created.id!.isEmpty) {
      throw StateError('No se pudo crear carpeta remota "$name".');
    }
    return created.id!;
  }

  Future<String> _remoteFolderForLocalFolder({
    required drive.DriveApi api,
    required String resourcesRootId,
    required String localFolderId,
    required Map<String, String> cache,
  }) async {
    final cached = cache[localFolderId];
    if (cached != null && cached.isNotEmpty) return cached;
    final remoteId = await _ensureSubfolder(
      api: api,
      parentId: resourcesRootId,
      name: localFolderId,
    );
    cache[localFolderId] = remoteId;
    return remoteId;
  }

  Future<drive.File?> _findFolderByName({
    required drive.DriveApi api,
    required String parentId,
    required String name,
  }) async {
    final escapedName = name.replaceAll("'", r"\'");
    final list = await api.files.list(
      q: "'$parentId' in parents and name='$escapedName' and mimeType='application/vnd.google-apps.folder' and trashed=false",
      $fields: 'files(id,name)',
      spaces: 'drive',
      pageSize: 1,
    );
    final files = list.files;
    if (files == null || files.isEmpty) return null;
    return files.first;
  }

  Future<drive.File?> _findFileByName({
    required drive.DriveApi api,
    required String parentId,
    required String name,
  }) async {
    final escapedName = name.replaceAll("'", r"\'");
    final list = await api.files.list(
      q: "'$parentId' in parents and name='$escapedName' and trashed=false",
      $fields: 'files(id,name)',
      spaces: 'drive',
      pageSize: 1,
    );
    final files = list.files;
    if (files == null || files.isEmpty) return null;
    return files.first;
  }

  GoogleSignIn _googleSignInOrThrow() {
    _googleSignIn ??= _buildGoogleSignIn();
    if (_googleSignIn == null) {
      throw StateError(
        'Google Drive en web requiere GOOGLE_WEB_CLIENT_ID configurado.',
      );
    }
    return _googleSignIn!;
  }

  GoogleSignIn? _buildGoogleSignIn() {
    if (!kIsWeb) {
      return GoogleSignIn(scopes: [drive.DriveApi.driveScope]);
    }
    const webClientId = String.fromEnvironment('GOOGLE_WEB_CLIENT_ID');
    final normalized = webClientId.trim();
    if (normalized.isEmpty) return null;
    return GoogleSignIn(
      clientId: normalized,
      scopes: [drive.DriveApi.driveScope],
    );
  }

  Map<String, String> _readResourceFileIdMap() {
    final raw = _datasource.getSetting(_resourceFileIdByResourceKey);
    if (raw is! Map) return <String, String>{};
    final out = <String, String>{};
    for (final entry in raw.entries) {
      final key = entry.key.toString().trim();
      final value = entry.value.toString().trim();
      if (key.isEmpty || value.isEmpty) continue;
      out[key] = value;
    }
    return out;
  }

  Future<void> _saveResourceFileIdMap(Map<String, String> map) async {
    final serializable = <String, dynamic>{
      for (final entry in map.entries) entry.key: entry.value,
    };
    await _datasource.saveSetting(_resourceFileIdByResourceKey, serializable);
  }

  bool _isWebUrl(String value) {
    final uri = Uri.tryParse(value);
    if (uri == null) return false;
    return uri.scheme == 'http' || uri.scheme == 'https';
  }

  String _sanitizeName(String value) {
    return value
        .trim()
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
        .replaceAll(RegExp(r'\s+'), ' ');
  }

  MandalaResourceType _parseType(
    String? rawType,
    String name,
    String mimeType,
  ) {
    final fromProp = (rawType ?? '').trim().toLowerCase();
    for (final type in MandalaResourceType.values) {
      if (type.name == fromProp) return type;
    }
    final ext = p.extension(name).toLowerCase();
    if (mimeType.startsWith('audio/') ||
        ['.mp3', '.wav', '.m4a', '.aac', '.ogg', '.flac'].contains(ext)) {
      return MandalaResourceType.audio;
    }
    if (mimeType.startsWith('image/') ||
        ['.jpg', '.jpeg', '.png', '.webp', '.gif'].contains(ext)) {
      return MandalaResourceType.image;
    }
    if (mimeType == 'application/pdf' || ext == '.pdf') {
      return MandalaResourceType.pdf;
    }
    if (mimeType.startsWith('text/') || ext == '.txt') {
      return MandalaResourceType.text;
    }
    return MandalaResourceType.other;
  }
}
