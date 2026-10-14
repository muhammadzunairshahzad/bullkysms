import '../homepage_bin.dart';

class IndividualSms {
  final String number;
  final String message;
  final int simSlot;
  final SmsStatus status;
  final String? error;

  IndividualSms({
    required this.number,
    required this.message,
    required this.simSlot,
    this.status = SmsStatus.pending,
    this.error,
  });

  IndividualSms copyWith({
    String? number,
    String? message,
    int? simSlot,
    SmsStatus? status,
    String? error,
  }) {
    return IndividualSms(
      number: number ?? this.number,
      message: message ?? this.message,
      simSlot: simSlot ?? this.simSlot,
      status: status ?? this.status,
      error: error ?? this.error,
    );
  }
}
