import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:logger/logger.dart';
import 'package:peernet/services/node_data.dart';
import 'package:peernet/services/peer_registry.dart';
import 'package:peernet/services/udp_discoverer.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_web_socket/shelf_web_socket.dart';

import '../dto/peer_data.dart';

enum Messages { PING, PONG, GetInfo }

class PeerEngine {
  final _logger = Logger(printer: PrettyPrinter());
  late final UDPDiscoverer _udpDiscoverer;

  final NodeConfig _config;
  final PeerRegistry _peerRegistry;

  PeerEngine(this._config, this._peerRegistry)
      : _udpDiscoverer = UDPDiscoverer(_config, _peerRegistry);

  late final _handler = webSocketHandler((ws, protocol) {
    ws.stream.listen((msg) async {
      _logger.i("[PeerEngine]: New message: $msg");

      if (msg == Messages.GetInfo.name) {
        ws.sink.add(
          jsonEncode(
            PeerData(
              ip: "",
              version: _config.getVersion(),
              discoveryPort: await _config.getDiscoveryPort(),
              websocketPort: await _config.getWebsocketPort(),
              name: await _config.getName(),
            ).toJson(),
          ),
        );
      } else {
        ws.sink.add("Echo: $msg");
      }
    });
  });

  Future<void> init() async {
    // SharedPrefs init
    await SharedPreferences.getInstance();
  }

  Future<void> startWebsocketServer() async {
    await shelf_io.serve(
      _handler,
      InternetAddress.anyIPv4,
      await _config.getWebsocketPort(),
    );
  }

  Future<void> startLocalPeerDiscoveryServer() async {
    await _udpDiscoverer.startLocalPeerDiscoveryServer();
  }

  Stream<PeerData> discoverLocalPeers() async* {
    yield* _udpDiscoverer.discoverLocalPeers();
  }
}

class Peernet {
  final _logger = Logger(printer: PrettyPrinter());
  final PeerRegistry registry;
  final PeerEngine engine;

  Function(PeerData)? onNewPeer;

  Peernet(NodeConfig? config, PeerRegistry? registry, PeerEngine? engine)
      : registry = registry ?? PeerRegistry(),
        engine = engine ?? PeerEngine(
          config ?? NodeConfig(),
          registry ?? PeerRegistry(),
        );

  Future<void> init() async {
    await engine.init();

    // Start websocket server
    await engine.startWebsocketServer();

    // Start LAN discovery server
    await engine.startLocalPeerDiscoveryServer();

    // Find peers in LAN in the background (unawaited so it doesn't block window creation)
    unawaited(discoverLocalPeers());

    // Find peers bootstrap nodes
    unawaited(discoverBootstrapPeers());
  }

  Future<void> discoverLocalPeers() async {
    await for (var peer in engine.discoverLocalPeers()) {
      onNewPeer?.call(peer);
    }
  }

  Future<void> discoverBootstrapPeers() async {}

  int getPeerCount() =>
      registry
          .getPeers()
          .length;

  Stream<List<PeerData>> getPeerStream() => registry.getPeerStream();
}
