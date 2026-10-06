import 'package:json_annotation/json_annotation.dart';
import 'package:peernet/services/peernet.dart';

part 'pong_response.g.dart';

@JsonSerializable()
class PeernetMsg {
  final Messages type;
  final String ip;
  @JsonKey(name: "discovery_port")
  final int discoveryPort;
  @JsonKey(name: "websocket_port")
  final int websocketPort;
  final String version;
  final String name;

  PeernetMsg({
    required this.type,
    required this.ip,
    required this.discoveryPort,
    required this.websocketPort,
    required this.version,
    required this.name,
  });

  factory PeernetMsg.fromJson(Map<String, dynamic> json) =>
      _$PeernetMsgFromJson(json);

  Map<String, dynamic> toJson() => _$PeernetMsgToJson(this);
}
