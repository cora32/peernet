import 'package:json_annotation/json_annotation.dart';

part 'peer_data.g.dart';

@JsonSerializable()
class PeerData {
  final String version;
  final String ip;
  final int port;

  PeerData({required this.version, required this.ip, required this.port});

  factory PeerData.fromJson(Map<String, dynamic> json) =>
      _$PeerDataFromJson(json);

  Map<String, dynamic> toJson() => _$PeerDataToJson(this);
}
