import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:logger/logger.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_web_socket/shelf_web_socket.dart';

import 'dto/peer_data.dart';
import 'pubspec.dart';

const String version = Pubspec.version;

enum Messages { PING, PONG, GetInfo }

class PeerRegistry {
  final _logger = Logger(printer: PrettyPrinter());
  final List<PeerData> localPeers = [];
}

class PeerEngine {
  final _logger = Logger(printer: PrettyPrinter());

  final int websocketPort;
  final int discoveryPort;
  RawDatagramSocket? _udpSocket;

  late final _handler = webSocketHandler((ws, protocol) {
    ws.stream.listen((msg) async {
      _logger.i("[PeerNet]: New message: $msg");

      if (msg == Messages.GetInfo.name) {
        ws.sink.add(
          json.encode(PeerData(ip: "", port: 0, version: version).toJson()),
        );
      } else {
        ws.sink.add("Echo: $msg");
      }
    });
  });

  PeerEngine({this.websocketPort = 7834, this.discoveryPort = 7835});

  Stream<PeerData> discoverLocalPeers() async* {
    _logger.i("[PeerNet]: Broadcasting discovery message...");

    // Get all local IPv4 addresses to filter out self
    final interfaces = await NetworkInterface.list(
      type: InternetAddressType.IPv4,
      includeLoopback: false,
    );
    final localIps = interfaces
        .expand((interface) => interface.addresses)
        .map((addr) => addr.address)
        .toSet();

    final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
    socket.broadcastEnabled = true;

    // Broadcast discovery message to the whole network
    final data = Messages.PING.name.codeUnits;
    socket.send(data, InternetAddress('255.255.255.255'), discoveryPort);

    // Close the scanning socket after a short period
    final timer = Timer(const Duration(seconds: 5), () => socket.close());

    try {
      await for (final event in socket) {
        if (event == RawSocketEvent.read) {
          try {
            final dg = socket.receive();

            if (dg != null) {
              final remoteIp = dg.address.address;

              // Filter out messages from this device
              if (localIps.contains(remoteIp)) {
                continue;
              }

              final data = String.fromCharCodes(dg.data);
              try {
                final peerData = PeerData.fromJson(jsonDecode(data));

                if (data == Messages.PONG.name) {
                  _logger.i("[PeerNet]: Found peer at $remoteIp");

                  yield peerData;
                }
              } catch (e) {
                _logger.e("[PeerNet]: Error while parsing inbound message: $e");
              }
            }
          } catch (e) {
            _logger.i("[PeerNet]: Error while parsing inbound message: $e");
          }
        }
      }
    } finally {
      timer.cancel();
      socket.close();
    }
  }

  Future<void> startLocalPeerDiscoveryServer() async {
    _logger.i("[PeerNet]: Starting discovery server");

    try {
      // Get all local IPv4 addresses to filter out self
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
      );
      final localIps = interfaces
          .expand((interface) => interface.addresses)
          .map((addr) => addr.address)
          .toSet();

      _udpSocket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        discoveryPort,
      );
      _udpSocket?.listen((event) {
        if (event == RawSocketEvent.read) {
          final dg = _udpSocket?.receive();
          if (dg != null) {
            _logger.i("[PeerNet]: Found peer: ${dg.address.address}");

            // Filter out messages from this device
            if (localIps.contains(dg.address.address)) {
              _logger.i("[PeerNet]: Filtering out self: ${dg.address.address}");
              return;
            }

            final message = String.fromCharCodes(dg.data);
            if (message == Messages.PING.name) {
              _logger.i("[PeerNet]: Ponging to ${dg.address.address}");
              _udpSocket?.send(
                Messages.PONG.name.codeUnits,
                dg.address,
                websocketPort,
              );
            } else if (message == Messages.PONG.name) {
              _logger.i("[PeerNet]: Ponged from ${dg.address.address}");

              // requestPeerData(ip: dg.address.address);
            }
          }
        }
      });
    } catch (e) {
      _logger.e("[PeerNet]: Failed to start discovery server: $e");
    }
  }

  Future<void> startWebsocketServer() async {
    await shelf_io.serve(_handler, InternetAddress.anyIPv4, discoveryPort);
  }
}

class Peernet {
  final _logger = Logger(printer: PrettyPrinter());
  final PeerRegistry registry;
  final PeerEngine engine;

  Function(PeerData)? onNewPeer;

  Peernet(
    int discoveryPort,
    int websocketPort,
    PeerRegistry? registry,
    PeerEngine? engine,
  ) : registry = registry ?? PeerRegistry(),
      engine =
          engine ??
          PeerEngine(
            discoveryPort: discoveryPort,
            websocketPort: websocketPort,
          );

  Future<void> init() async {
    // Start websocket server
    await engine.startWebsocketServer();

    // Start LAN discovery server
    await engine.startLocalPeerDiscoveryServer();

    // Find peers in LAN
    await discoverLocalPeers();

    // Find peers bootstrap nodes
    await discoverBootstrapPeers();
  }

  Future<void> discoverLocalPeers() async {
    await for (var peer in engine.discoverLocalPeers()) {
      onNewPeer?.call(peer);
    }
  }

  Future<void> discoverBootstrapPeers() async {}
}
