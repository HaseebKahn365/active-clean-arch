import 'package:equatable/equatable.dart';

class CountRecord extends Equatable {
  final String id;
  final String activityId;
  final DateTime timestamp;
  final double value;

  const CountRecord({required this.id, required this.activityId, required this.timestamp, required this.value});

  @override
  List<Object?> get props => [id, activityId, timestamp, value];
}
