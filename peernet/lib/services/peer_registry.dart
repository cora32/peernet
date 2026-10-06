import 'dart:async';

import 'package:logger/logger.dart';

import '../dto/peer_data.dart';

class PeerRegistry {
  static final instance = PeerRegistry._();

  PeerRegistry._();

  factory PeerRegistry() => instance;

  final _logger = Logger(printer: PrettyPrinter());
  final List<PeerData> localPeers = [];

  final _streamController = StreamController<List<PeerData>>.broadcast();

  Stream<List<PeerData>> get stream => _streamController.stream;

  void add(PeerData peerData) {
    _logger.i("[PeerRegistry]: Adding peer: $peerData");
    localPeers.add(peerData);

    _streamController.add(List.unmodifiable(localPeers));
  }

  List<PeerData> getPeers() {
    return List.unmodifiable(localPeers);
  }

  Stream<List<PeerData>> getPeerStream() => stream;
}
