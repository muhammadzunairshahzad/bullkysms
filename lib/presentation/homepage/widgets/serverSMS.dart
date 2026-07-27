class ServerSms {
  final String smsId;
  final String campaignName;
  final String mobile;
  final String smsText;
  String? sentTime;

  ServerSms({
    required this.smsId,
    required this.campaignName,
    required this.mobile,
    required this.smsText,
    this.sentTime,
  });

  factory ServerSms.fromJson(Map<String, dynamic> json) {
    return ServerSms(
      smsId: json['SMSID'].toString(),
      campaignName: json['CampaignName'] ?? '',
      mobile: json['Mobile'] ?? '',
      smsText: json['SMSText'] ?? '',
    );
  }

  Map<String, dynamic> toUpdateJson() {
    return {'SMSID': smsId, 'SentTime': sentTime ?? DateTime.now().toString()};
  }
}
