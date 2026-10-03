import 'package:flutter_bloc/flutter_bloc.dart';

class ChatState {
  final int peers;

  ChatState({required this.peers});
}

class ChatCubit extends Cubit<ChatState> {
  new(super.initialState);
}
