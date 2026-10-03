// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'peer_data.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PeerData _$PeerDataFromJson(Map<String, dynamic> json) => PeerData(
  version: json['version'] as String,
  ip: json['ip'] as String,
  port: (json['port'] as num).toInt(),
);

Map<String, dynamic> _$PeerDataToJson(PeerData instance) => <String, dynamic>{
  'version': instance.version,
  'ip': instance.ip,
  'port': instance.port,
};
