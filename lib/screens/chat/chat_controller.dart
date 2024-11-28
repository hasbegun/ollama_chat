import 'dart:convert';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/widgets.dart';
import 'package:logging/logging.dart';
import 'package:ollama_dart/ollama_dart.dart';

import '../../async_result.dart';
import '../../db.dart';
import '../../model.dart';

Conversation emptyConversationWith(String model) => Conversation(
      lastUpdate: DateTime.now(),
      model: model,
      title: 'Chat',
      messages: [],
    );

class ChatController {
  final _log = Logger('ChatController');
  final OllamaClient _client;
  final ConversationService _conversationService;

  final promptFieldController = TextEditingController();
  ScrollController scrollController = ScrollController();

  ValueNotifier<XFile?> selectedImage = ValueNotifier(null);
  final ValueNotifier<Model?> model;
  final ValueNotifier<Conversation> conversation;
  final ValueNotifier<(String, String)> lastReply = ValueNotifier(('', ''));
  final ValueNotifier<bool> loading = ValueNotifier(false);
  final ValueNotifier<AsyncData<List<Conversation>>> conversations =
      ValueNotifier(const Data([]));

  ChatController({
    required OllamaClient client,
    required this.model,
    required ConversationService conversationService,
    Conversation? initialConversation,
  })  : _client = client,
        _conversationService = conversationService,
        conversation = ValueNotifier(
          initialConversation ??
              emptyConversationWith(model.value?.model ?? '/'),
        );

  Future<void> loadHistory() async {
    conversations.value = const Pending();
    try {
      conversations.value =
          Data(await _conversationService.loadConversations());
    } catch (err) {
      _log.severe('ERROR !!! loadHistory $err');
    }
  }

  Future<void> chat() async {
    if (model.value == null) return;

    final name = model.value!.model;
    final question = promptFieldController.text;
    final image = selectedImage.value;

    if (name!.isEmpty || question.isEmpty) return;

    loading.value = true;
    String? b64Image;

    if (image != null) {
      b64Image = base64Encode(await image.readAsBytes()); // Encode image
    }

    lastReply.value = (question, '');

    // Add the user's question and image to the conversation
    final newMessages = [
      ...conversation.value.messages,
      (question, b64Image ?? ''), // Include the image's Base64 if present
    ];
    conversation.value = conversation.value.copyWith(newMessages: newMessages);

    final generateChatCompletionRequest = GenerateChatCompletionRequest(
      model: name,
      messages: [
        for (final qa in conversation.value.messages) ...[
          Message(role: MessageRole.user, content: qa.$1),
          Message(role: MessageRole.assistant, content: qa.$2),
        ],
        Message(
          role: MessageRole.user,
          content: question,
          images: b64Image != null ? [b64Image] : null, // Attach the image
        ),
      ],
    );

    try {
      final streamResponse = _client.generateChatCompletionStream(
        request: generateChatCompletionRequest,
      );

      String responseText = '';

      await for (final chunk in streamResponse) {
        responseText += chunk.message.content ?? '';

        // Update the conversation with the response
        conversation.value = conversation.value.copyWith(
          newMessages: [
            ...newMessages,
            (question, responseText),
          ],
        );

        lastReply.value = (question, responseText); // Update the live reply
        scrollToEnd();
      }

      _conversationService.saveConversation(conversation.value);
      loadHistory();
    } catch (e) {
      _log.severe('Error during chat: $e');
    } finally {
      loading.value = false;
      promptFieldController.clear();
      selectedImage.value = null; // Clear the selected image after submission
    }
  }

  void scrollToEnd() {
    if (scrollController.hasClients) {
      scrollController.animateTo(
        scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.decelerate,
      );
    }
  }

  Future<void> addImage(XFile? image) async {
    selectedImage.value = image;
  }

  void deleteImage() {
    selectedImage.value = null;
  }

  void selectConversation(Conversation value) {
    conversation.value = value;
  }

  void newConversation() {
    conversation.value = emptyConversationWith(model.value?.model ?? '/');
  }

  Future<void> deleteConversation(Conversation deletecConversation) async {
    conversation.value = emptyConversationWith(model.value?.model ?? '/');
    await _conversationService.deleteConversation(deletecConversation);
    loadHistory();
  }
}
