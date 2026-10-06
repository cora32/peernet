// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'peer_data.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PeerData _$PeerDataFromJson(Map<String, dynamic> json) => PeerData(
  ip: json['ip'] as String,
  discoveryPort: (json['discovery_port'] as num).toInt(),
  websocketPort: (json['websocket_port'] as num).toInt(),
  version: json['version'] as String,
  name: json['name'] as String,
);

Map<String, dynamic> _$PeerDataToJson(PeerData instance) => <String, dynamic>{
  'ip': instance.ip,
  'discovery_port': instance.discoveryPort,
  'websocket_port': instance.websocketPort,
  'version': instance.version,
  'name': instance.name,
};
