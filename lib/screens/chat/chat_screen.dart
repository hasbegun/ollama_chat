import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:provider/provider.dart';

import '../../markdown/code_element_builder.dart';
import '../../markdown/highlighter.dart';
import '../../model_controller.dart';
import '../../theme.dart';
import '../../themes.dart';
import '../../widgets/chat_history/chat_history_view.dart';
import '../../widgets/model_drawer.dart';
import '../../widgets/model_info_view.dart';
import '../../widgets/prompt_field.dart';

import 'chat_controller.dart';

class ChatScreen extends StatelessWidget {
  const ChatScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final modelController = context.read<ModelController>();
    final chatController = context.read<ChatController>();

    return Scaffold(
      appBar: const MainAppBar(),
      drawer: const ModelMenuDrawer(),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ChatHistoryView(
            onChatSelection: (conversation) async {
              modelController.selectModelNamed(conversation.model);
              chatController.selectConversation(conversation);
            },
            onDeleteChat: chatController.deleteConversation,
            onNewChat: chatController.newConversation,
          ),
          Expanded(
            child: ListenableBuilder(
              listenable: Listenable.merge([
                chatController.loading,
                chatController.conversation,
              ]),
              builder: (context, _) {
                final loading = chatController.loading.value;
                final messages = chatController.conversation.value.messages;
                final model = chatController.conversation.value.model;
                final date = chatController.conversation.value.formattedDate;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (messages.isNotEmpty)
                      Container(
                        constraints: const BoxConstraints.tightForFinite(),
                        margin: const EdgeInsets.all(8.0),
                        padding: const EdgeInsets.all(8.0),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: theme.canvasColor,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(model),
                            Text(date),
                          ],
                        ),
                      ),

                    // Expanded(
                    //   child: loading
                    //       ? const Center(
                    //           child: CircularProgressIndicator(),
                    //         )
                    //       : ListView(
                    //           controller: chatController.scrollController,
                    //           children: [
                    //             for (final qa in messages) QAView(qa: qa),
                    //           ],
                    //         ),
                    // ),

                    Expanded(
                      child: loading
                          ?
                      // const Center(
                      //   child: CircularProgressIndicator(),
                      // )
                      ValueListenableBuilder(
                              valueListenable: chatController.lastReply,
                              builder: (context, reply, _) => loading &&
                                      chatController.lastReply.value.$2.isEmpty
                                  ? const Center(
                                      child: CircularProgressIndicator(),
                                    )
                                  : const ChatInteractionView(),
                            )
                          : ListView(
                              controller: chatController.scrollController,
                              children: [
                                for (final qa in messages) QAView(qa: qa),
                              ],
                            ),
                    ),

                    const PromptField(),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class MainAppBar extends StatelessWidget implements PreferredSizeWidget {
  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  const MainAppBar({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.read<ModelController>();

    return AppBar(
      scrolledUnderElevation: 0,
      leading: IconButton(
        onPressed: Scaffold.of(context).openDrawer,
        icon: const Icon(Icons.menu),
      ),
      title: Row(
        children: [
          Image.asset('assets/app_icons/tete_32.png', width: 32),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Text(
              'Ollama-Chat',
              style: TextStyle(color: Colors.blueGrey.shade700),
            ),
          ),
          ValueListenableBuilder(
            valueListenable: controller.currentModel,
            builder: (final context, currentModel, _) => currentModel != null
                ? Row(
                    children: [
                      Text(
                        currentModel.model ?? '/',
                        style: const TextStyle(color: Colors.blueGrey),
                      ),
                      IconButton(
                        onPressed: () => showDialog(
                          context: context,
                          builder: (final context) =>
                              ModelInfoView(model: currentModel),
                        ),
                        icon: const Icon(Icons.info),
                      ),
                    ],
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
      centerTitle: false,
      actions: const [ThemeButton()],
    );
  }
}

/* Dynamic Display Logic in QAView
  Images:
    The condition checks if the response starts with /9j/, which is the Base64 header for JPEG images. If true, it decodes and displays the image.
  Server Text/Markdown:
    If the content is not an image, it is rendered as plain text or Markdown using MarkdownBody.

Example of How Messages Are Stored:
A message with an image:
  ('What is this?', '/9j/4AAQSkZJRgABAQEAAAAAAAD/...')
A message with only text:
('What is the capital of France?', 'The capital of France is Paris.')
 */
class QAView extends StatelessWidget {
  final (String, String) qa;

  const QAView({super.key, required this.qa});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final imageWidth = screenWidth * 0.7;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Display the user question
          ChatHeader(question: qa.$1),
          const Divider(),

          // Display the image if present
          if (qa.$2.isNotEmpty &&
              qa.$2.startsWith('/9j/')) // Base64 JPEG header
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Image.memory(
                base64Decode(qa.$2), // Decode the Base64 image
                fit: BoxFit.contain,
                width: imageWidth, // Adjust width to 70% of screen width
              ),
            ),

          // Display the server response or Markdown content
          if (qa.$2.isNotEmpty &&
              !_isBase64Image(qa.$2)) // Ensure it's not an image
            DecoratedBox(
              decoration: BoxDecoration(
                color: theme.canvasColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Markdown(
                data: qa.$2,
                selectable: true,
                syntaxHighlighter: MdHightLighter(editorHighlighterStyle),
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.all(14),
                styleSheetTheme: MarkdownStyleSheetBaseTheme.material,
                inlineSyntaxes: const [],
                extensionSet: md.ExtensionSet.gitHubWeb,
                shrinkWrap: true,
                builders: {'code': CodeElementBuilder()},
                onSelectionChanged: (_, __, ___) {},
              ),
            ),
        ],
      ),
    );
  }

  bool _isBase64Image(String data) {
    try {
      // Validate the header for Base64 JPEG/PNG images
      if (data.startsWith('/9j/') || data.startsWith('iVBORw0')) {
        base64Decode(data); // Try decoding to confirm it's valid Base64
        return true;
      }
    } catch (_) {
      return false; // Not valid Base64 or not an image
    }
    return false;
  }
}

class ChatHeader extends StatelessWidget {
  final String question;

  const ChatHeader({super.key, required this.question});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Padding(
          padding: EdgeInsets.only(right: 12),
          child: Icon(Icons.chat, color: Colors.blueGrey),
          // const SizedBox(width: 8),
        ),
        Flexible(
          child: Text(
            question,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  // Updated property
                  fontWeight: FontWeight.bold,
                ),
          ),
        ),
      ],
    );
  }
}

class ChatInteractionView extends StatelessWidget {
  const ChatInteractionView({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.read<ChatController>();
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: ValueListenableBuilder(
        valueListenable: controller.lastReply,
        builder: (context, qa, _) => SingleChildScrollView(
          controller: controller.scrollController,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ChatHeader(question: qa.$1),
              const Divider(),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: theme.appBarTheme.backgroundColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Markdown(
                  data: qa.$2.isEmpty ? '' : qa.$2,
                  /*selectable: true,*/
                  syntaxHighlighter: MdHightLighter(editorHighlighterStyle),
                  padding: const EdgeInsets.all(42),
                  styleSheetTheme: MarkdownStyleSheetBaseTheme.material,
                  inlineSyntaxes: const [],
                  extensionSet: md.ExtensionSet.gitHubWeb,
                  onSelectionChanged: (_, __, ___) {},
                  shrinkWrap: true,
                  builders: {'code': CodeElementBuilder()},
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
