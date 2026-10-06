import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:peernet/dto/peer_data.dart';
import 'package:peernet/services/peernet.dart';

class ChatState {
  final int peerCount;

  ChatState({required this.peerCount});
}

class ChatCubit extends Cubit<ChatState> {
  final Peernet peernet;
  late final StreamSubscription<List<PeerData>> _subscription;

  ChatCubit(this.peernet)
    : super(ChatState(peerCount: peernet.getPeerCount())) {
    _subscription = peernet.getPeerStream().listen((peerList) {
      setState(peerCount: peerList.length);
    });
  }

  void setState({int? peerCount}) {
    emit(ChatState(peerCount: peerCount ?? state.peerCount));
  }

  @override
  Future<void> close() {
    _subscription.cancel();
    return super.close();
  }
}
