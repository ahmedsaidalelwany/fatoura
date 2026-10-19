import 'dart:io';

import 'package:equatable/equatable.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:fatoura/core/backup/backup_service.dart';

abstract class BackupState extends Equatable {
  const BackupState();
  @override
  List<Object?> get props => [];
}

class BackupInitial extends BackupState {}

class BackupLoading extends BackupState {}

class BackupCreatedSuccess extends BackupState {
  final String filePath;
  final String checksum;

  const BackupCreatedSuccess({required this.filePath, required this.checksum});

  @override
  List<Object?> get props => [filePath, checksum];
}

class RestoreSuccess extends BackupState {
  final String message;

  const RestoreSuccess(this.message);

  @override
  List<Object?> get props => [message];
}

class BackupError extends BackupState {
  final String message;

  const BackupError(this.message);

  @override
  List<Object?> get props => [message];
}

class BackupCubit extends Cubit<BackupState> {
  final BackupService backupService;

  BackupCubit(this.backupService) : super(BackupInitial());

  Future<void> createBackupToFile() async {
    emit(BackupLoading());
    try {
      final res = await backupService.createBackup();
      if (!res.success || res.backupJson == null) {
        emit(BackupError(res.message ?? 'Failed to create backup'));
        return;
      }

      final dateStr = DateFormat('yyyy-MM-dd_HH-mm').format(DateTime.now());
      final filename = 'Fatoura_Backup_$dateStr.fatoura.json';

      // Save to application documents or downloads folder
      final directory = await getApplicationDocumentsDirectory();
      final backupDir = Directory('${directory.path}/FatouraBackups');
      if (!await backupDir.exists()) {
        await backupDir.create(recursive: true);
      }

      final file = File('${backupDir.path}/$filename');
      await file.writeAsString(res.backupJson!);

      emit(
        BackupCreatedSuccess(filePath: file.path, checksum: res.checksum ?? ''),
      );
    } catch (e) {
      emit(BackupError(e.toString()));
    }
  }

  Future<void> restoreBackupFromFile() async {
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (files.isEmpty || files.first.path == null) {
        return; // User cancelled
      }

      emit(BackupLoading());
      final file = File(files.first.path!);
      final rawJson = await file.readAsString();

      final restoreRes = await backupService.restoreBackup(rawJson);
      if (restoreRes.success) {
        emit(
          RestoreSuccess(restoreRes.message ?? 'Backup restored successfully.'),
        );
      } else {
        emit(BackupError(restoreRes.message ?? 'Failed to restore backup'));
      }
    } catch (e) {
      emit(BackupError('Restoration error: $e'));
    }
  }
}
