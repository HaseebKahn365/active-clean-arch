import 'package:equatable/equatable.dart';

class Backup extends Equatable {
  final String id;
  final String url;
  final DateTime timestamp;
  final String fileName;

  const Backup({required this.id, required this.url, required this.timestamp, required this.fileName});

  @override
  List<Object?> get props => [id, url, timestamp, fileName];
}
