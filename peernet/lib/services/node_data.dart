import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';

import '../pubspec.dart';

class NodeConfig {
  static final instance = const NodeConfig._();

  const NodeConfig._();

  factory NodeConfig() => instance;

  static const DEFAULT_WS_PORT = 7834;
  static const DEFAULT_DISCOVERY_PORT = 7835;

  Future<SharedPreferences> get sp async =>
      await SharedPreferences.getInstance();

  Future<void> setName(String? name) async {
    await (await sp).setString("pn_name", name ?? Platform.localHostname);
  }

  Future<String> getName() async {
    final sp = await SharedPreferences.getInstance();

    return sp.getString("pn_name") ?? Platform.localHostname;
  }

  String getVersion() {
    return Pubspec.version;
  }

  Future<void> setWebsocketPort(int port) async {
    await (await sp).setInt("pn_ws_port", port);
  }

  Future<int> getWebsocketPort() async {
    return (await sp).getInt("pn_ws_port") ?? DEFAULT_WS_PORT;
  }

  Future<void> setDiscoveryPort(int port) async {
    await (await sp).setInt("pn_discovery_port", port);
  }

  Future<int> getDiscoveryPort() async {
    return (await sp).getInt("pn_discovery_port") ?? DEFAULT_DISCOVERY_PORT;
  }
}
