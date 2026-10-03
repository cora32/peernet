import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:peernet/peernet.dart';
import 'package:peernet_demo/shared/logger.dart';

import 'cubits/chat_cubit.dart';

Future<void> main(List<String> args) async {
  int websocketPort = 7834;
  int discoveryPort = 7835;

  for (final arg in args) {
    if (arg.startsWith('--ws-port=')) {
      websocketPort = int.tryParse(arg.split('=')[1]) ?? websocketPort;
    } else if (arg.startsWith('--udp-port=')) {
      discoveryPort = int.tryParse(arg.split('=')[1]) ?? discoveryPort;
    }
  }

  logger.i(
    'Using WebSocket Port: $websocketPort, Discovery Port: $discoveryPort',
  );

  // Initialize Peernet with these ports
  final peernet = Peernet(discoveryPort, websocketPort, null, null);
  await peernet.init();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => ChatCubit(ChatState(peers: 0)),
      child: MaterialApp(
        title: 'Peernet Demo',
        theme: ThemeData(colorScheme: .fromSeed(seedColor: Colors.deepPurple)),
        home: BlocBuilder<ChatCubit, ChatState>(
          builder: (context, state) {
            return ChatWidget(state: state);
          },
        ),
      ),
    );
  }
}

class ChatWidget extends StatelessWidget {
  final ChatState state;

  const ChatWidget({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // info
        InfoPaneWidget(peers: state.peers),
        // chat
        Expanded(child: MessagesWidget()),
        // send field
        SendFieldWidget(),
      ],
    );
  }
}

// info

class InfoPaneWidget extends StatelessWidget {
  final int peers;

  const InfoPaneWidget({super.key, required this.peers});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [Text("Peers: $peers")],
    );
  }
}

// chat
class MessagesWidget extends StatelessWidget {
  const MessagesWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return const Placeholder();
  }
}

// text field
class SendFieldWidget extends StatelessWidget {
  const SendFieldWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return const Placeholder();
  }
}
