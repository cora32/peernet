import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:logger/logger.dart';
import 'package:peernet/services/peer_registry.dart';
import 'package:peernet/services/peernet.dart';

import '../dto/peer_data.dart';
import '../dto/pong_response.dart';
import 'node_data.dart';

class UDPDiscoverer {
  final _logger = Logger(printer: PrettyPrinter());

  final NodeConfig config;
  final PeerRegistry _peerRegistry;

  RawDatagramSocket? _udpSocket;

  UDPDiscoverer(this.config, this._peerRegistry);

  /*
  * Broadcasts a discovery message to LAN and awaits pongs for 5 seconds.
  * This should only respond to peer pongs.
  * */
  Stream<PeerData> discoverLocalPeers() async* {
    _logger.i("[UDPDiscoverer]: Broadcasting discovery message...");

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
    final msg = PeernetMsg(
      type: Messages.PING,
      ip: localIps.first,
      discoveryPort: await config.getDiscoveryPort(),
      websocketPort: await config.getWebsocketPort(),
      version: config.getVersion(),
      name: await config.getName(),
    );
    final data = jsonEncode(msg).codeUnits;

    socket.send(
      data,
      InternetAddress('255.255.255.255'),
      await config.getDiscoveryPort(),
    );

    // Close the scanning socket after a short period
    final timer = Timer(const Duration(seconds: 5), () {
      _logger.i("[UDPDiscoverer]: Closing discovery socket");
      socket.close();
    });

    try {
      await for (final event in socket) {
        if (event == RawSocketEvent.read) {
          try {
            final dg = socket.receive();

            if (dg != null) {
              final remoteIp = dg.address.address;

              // Filter out messages from this device
              // if (localIps.contains(remoteIp)) {
              //   continue;
              // }

              try {
                final payload = String.fromCharCodes(dg.data);
                final data = PeernetMsg.fromJson(jsonDecode(payload));

                // Ignoring same instance
                if (data.name == await config.getName()) {
                  _logger.i(
                    "[UDPDiscoverer]: Ignoring self: ${data.name}; name: ${data.name}",
                  );
                  continue;
                }

                if (data.ip != dg.address.address) {
                  _logger.w(
                    "[UDPDiscoverer]: Fake response? $data from source: ${dg.address.address}",
                  );
                }

                // Peer discovered
                if (data.type == Messages.PONG) {
                  _logger.i(
                    "[UDPDiscoverer]: Broadcast ping located peer at $remoteIp",
                  );

                  _peerRegistry.add(
                    PeerData(
                      version: data.version,
                      ip: data.ip,
                      discoveryPort: data.discoveryPort,
                      websocketPort: data.websocketPort,
                      name: data.name,
                    ),
                  );

                  yield PeerData(
                    version: data.version,
                    ip: data.ip,
                    discoveryPort: data.discoveryPort,
                    websocketPort: data.websocketPort,
                    name: data.name,
                  );
                } else {
                  _logger.w(
                    "[UDPDiscoverer]: Unexpected message from $remoteIp: $data",
                  );
                }
              } catch (e) {
                _logger.e(
                  "[UDPDiscoverer]: Error while parsing inbound message: $e",
                );
              }
            }
          } catch (e) {
            _logger.i(
              "[UDPDiscoverer]: Error while parsing inbound message: $e",
            );
          }
        }
      }
    } finally {
      timer.cancel();
      socket.close();
    }
  }

  /*
  * Starts a local LAN discovery server. This should only respond to broadcast pings.
  * */
  Future<void> startLocalPeerDiscoveryServer() async {
    _logger.i("[UDPDiscoverer]: Starting discovery server");

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

      final discoveryPort = await config.getDiscoveryPort();
      _udpSocket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        discoveryPort,
      );
      _udpSocket?.listen((event) async {
        if (event == RawSocketEvent.read) {
          final dg = _udpSocket?.receive();
          if (dg != null) {
            // Filter out messages from this instance
            // if (localIps.contains(dg.address.address) &&
            //     dg.port == discoveryPort) {
            //   _logger.i(
            //     "[UDPDiscoverer]: Ignoring self: ${dg.address.address}:${dg.port};",
            //   );
            //   return;
            // }

            try {
              // Extract payload
              final payload = jsonDecode(String.fromCharCodes(dg.data));
              final data = PeernetMsg.fromJson(payload);

              _logger.i(
                "[UDPDiscoverer]: Server received message from: ${dg.address.address}:${dg.port}\n$payload",
              );

              if (data.type == Messages.PING) {
                _logger.i(
                  "[UDPDiscoverer]: Sending pong to ${data.name}, ${dg.address.address}...",
                );

                // Ignore self
                if (data.name != await config.getName()) {
                  // If somebody pings - they are a peer
                  _peerRegistry.add(
                    PeerData(
                      version: data.version,
                      ip: data.ip,
                      discoveryPort: data.discoveryPort,
                      websocketPort: data.websocketPort,
                      name: data.name,
                    ),
                  );

                  // Craft response payload
                  final pongResponse = PeernetMsg(
                    type: Messages.PONG,
                    ip: localIps.first,
                    discoveryPort: discoveryPort,
                    websocketPort: await config.getWebsocketPort(),
                    version: config.getVersion(),
                    name: await config.getName(),
                  );
                  final pongPayload = jsonEncode(pongResponse).codeUnits;

                  _udpSocket?.send(pongPayload, dg.address, dg.port);
                }
              } else {
                _logger.w(
                  "[UDPDiscoverer]: Unexpected message from ${dg.address.address}:${dg.port}: $payload",
                );
              }
            } catch (e) {
              _logger.e("[UDPDiscoverer]: Failed to parse inbound message: $e");
            }
          }
        }
      });
    } catch (e) {
      _logger.e("[UDPDiscoverer]: Failed to start discovery server: $e");
    }
  }
}
