import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:provider/provider.dart';

import '../screens/chat/chat_controller.dart';

const imageTypes = XTypeGroup(
    label: 'images',
    extensions: ['jpg', 'jpeg', 'png', 'svg', 'webp'],
    uniformTypeIdentifiers: ['public.image']);

const allFilesTypeGroup = XTypeGroup(
  label: 'all files',
  uniformTypeIdentifiers: ['public.data'], // For general binary files on iOS
);

class PromptField extends StatefulWidget {
  const PromptField({super.key});

  @override
  PromptFieldState createState() => PromptFieldState();
}

class PromptFieldState extends State<PromptField> {
  bool minimized = true;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final controller = context.read<ChatController>();

    return Container(
      padding: const EdgeInsets.all(8.0),
      color: theme.cardColor,
      child: ListenableBuilder(
        listenable: Listenable.merge(
          [controller.promptFieldController, controller.selectedImage],
        ),
        builder: (context, _) {
          final selectedImage = controller.selectedImage.value;
          final maxLines = minimized ? 1 : 12;
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: minimized
                    ? CrossAxisAlignment.center
                    : CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextField(
                        controller: controller.promptFieldController,
                        maxLines: maxLines,
                        decoration: InputDecoration(
                          label: Text(AppLocalizations.of(context)!.yourPrompt),
                          border: const OutlineInputBorder(),
                          suffixIcon: _PromptActionBar(
                            minimized: minimized,
                            onFileContentAdded: () =>
                                setState(() => minimized = false),
                          ),
                          floatingLabelBehavior: FloatingLabelBehavior.never,
                        ),
                        onEditingComplete: () async {
                          await controller.chat();
                          controller.deleteImage();
                        }),
                  ),
                  IconButton(
                    onPressed: () => setState(() => minimized = !minimized),
                    icon: const Icon(Icons.arrow_drop_down),
                  ),
                ],
              ),
              if (selectedImage != null)
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Row(
                    children: [
                      InkWell(
                        child: Image.file(File(selectedImage.path), height: 64),
                        onTap: () => showImage(
                          context: context,
                          path: selectedImage.path,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(left: 12.0),
                        child: Text(selectedImage.path),
                      ),
                      IconButton(
                        onPressed: controller.deleteImage,
                        icon: const Icon(Icons.delete),
                      ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

Future<void> showImage({required BuildContext context, required String path}) =>
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Image.file(File(path)),
      ),
    );

class _PromptActionBar extends StatelessWidget {
  final bool minimized;

  final VoidCallback onFileContentAdded;

  const _PromptActionBar({
    required this.minimized,
    required this.onFileContentAdded,
  });

  @override
  Widget build(BuildContext context) {
    final controller = context.read<ChatController>();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.add_photo_alternate),
          tooltip: AppLocalizations.of(context)?.addImage,
          onPressed: () async {
            final selectedImage =
                await openFile(acceptedTypeGroups: [imageTypes]);
            controller.addImage(selectedImage);
          },
        ),
        IconButton(
          icon: const Icon(Icons.post_add),
          tooltip: AppLocalizations.of(context)?.insertFile,
          onPressed: () async {
            // final file = await openFile();
            final file =
                await openFile(acceptedTypeGroups: [allFilesTypeGroup]);
            final fileContent = await file?.readAsString();
            if (fileContent != null) {
              controller.promptFieldController.text =
                  '${controller.promptFieldController.text}\n$fileContent';
              onFileContentAdded();
            }
          },
        ),
        if (controller.promptFieldController.text.isNotEmpty)
          IconButton(
            onPressed: () async {
              controller.chat();
              controller.deleteImage();
            },
            icon: const Icon(Icons.send),
          ),
      ],
    );
  }
}
