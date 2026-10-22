import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:image_picker/image_picker.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import 'services/rahi_ai_service.dart';
import 'services/user_session.dart' as user_session;
import 'app_theme.dart';

class RahiChatScreen extends StatefulWidget {
  const RahiChatScreen({super.key});

  @override
  State<RahiChatScreen> createState() => _RahiChatScreenState();
}

class _RahiChatScreenState extends State<RahiChatScreen> {
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();
  final _aiService = RahiAiService();
  final _imagePicker = ImagePicker();
  final _speech = stt.SpeechToText();
  final List<_ChatMessage> _messages = [
    const _ChatMessage(
      text:
          'Hi, I am Raahi. I understand the Raahi app and can guide you through '
          'GPS tracking, emergency alerts, contacts, and your digital tourist ID. '
          'What do you need help with?',
      isUser: false,
    ),
  ];
  bool _isSending = false;
  bool _isListening = false;
  String _assistantMode = 'Travel safety';
  static const _assistantModes = [
    'Travel safety',
    'Emergency guidance',
    'First aid',
    'Route help',
    'Food & plant safety',
    'Tourist information',
  ];
  String? _selectedImageBase64;
  String? _selectedImageMimeType;
  String? _selectedImagePath;

  Future<void> _send() async {
    final text = _inputController.text.trim();
    if ((text.isEmpty && _selectedImageBase64 == null) || _isSending) return;

    _inputController.clear();
    final imageBase64 = _selectedImageBase64;
    final imageMimeType = _selectedImageMimeType;
    final imagePath = _selectedImagePath;
    _selectedImageBase64 = null;
    _selectedImageMimeType = null;
    _selectedImagePath = null;
    setState(() {
      _messages.add(
        _ChatMessage(
          text: text.isEmpty ? 'Please analyze this photo for safety.' : text,
          isUser: true,
          imagePath: imagePath,
        ),
      );
      _isSending = true;
    });
    _scrollToBottom();

    try {
      final history = _messages
          .where((message) => message.text.isNotEmpty)
          .map(
            (message) => {
              'role': message.isUser ? 'user' : 'assistant',
              'content': message.text,
            },
          )
          .toList();
      final user = user_session.UserSession.getCurrentUser();
      final answer = await _aiService.sendMessage(
        messages: history,
        context: {
          'screen': 'Raahi assistant',
          'user_name': user?.fullName ?? '',
          'user_type': user?.userType ?? 'Tourist',
          'assistant_mode': _assistantMode,
        },
        imageBase64: imageBase64,
        imageMimeType: imageMimeType,
      );
      if (!mounted) return;
      setState(() => _messages.add(_ChatMessage(text: answer, isUser: false)));
    } catch (error) {
      if (!mounted) return;
      setState(
        () => _messages.add(
          _ChatMessage(
            text: 'Raahi could not complete that request.\n\n$error',
            isUser: false,
            isError: true,
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
        _scrollToBottom();
      }
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    final image = await _imagePicker.pickImage(
      source: source,
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 82,
    );
    if (image == null) return;
    final bytes = await image.readAsBytes();
    final extension = image.path.toLowerCase().split('.').last;
    final mimeType = extension == 'png' ? 'image/png' : 'image/jpeg';
    setState(() {
      _selectedImageBase64 = base64Encode(bytes);
      _selectedImageMimeType = mimeType;
      _selectedImagePath = image.path;
    });
  }

  Future<void> _showImageOptions() async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Take a photo'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleListening() async {
    if (_isListening) {
      await _speech.stop();
      if (mounted) setState(() => _isListening = false);
      return;
    }
    final available = await _speech.initialize();
    if (!available || !mounted) return;
    setState(() => _isListening = true);
    await _speech.listen(
      onResult: (result) {
        if (mounted) {
          setState(() => _inputController.text = result.recognizedWords);
        }
      },
    );
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: AppColors.tealSoft,
              child: Icon(
                Icons.auto_awesome_rounded,
                size: 18,
                color: AppColors.teal,
              ),
            ),
            SizedBox(width: 10),
            Text('Raahi AI'),
          ],
        ),
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            color: AppColors.tealSoft,
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: 18,
                  color: AppColors.teal,
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Raahi provides general guidance. It does not replace emergency services or medical professionals.',
                    style: TextStyle(fontSize: 12, color: AppColors.ink),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 12),
              itemCount: _messages.length + (_isSending ? 1 : 0),
              itemBuilder: (_, index) {
                if (index == _messages.length) {
                  return const _TypingBubble();
                }
                return _MessageBubble(message: _messages[index]);
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    height: 40,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: _assistantModes.map((mode) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(mode),
                            selected: _assistantMode == mode,
                            onSelected: (_) =>
                                setState(() => _assistantMode = mode),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 6),
                  if (_selectedImagePath != null)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Chip(
                          avatar: const Icon(Icons.image_outlined, size: 18),
                          label: const Text('Photo attached'),
                          onDeleted: () => setState(() {
                            _selectedImageBase64 = null;
                            _selectedImageMimeType = null;
                            _selectedImagePath = null;
                          }),
                        ),
                      ),
                    ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      IconButton(
                        onPressed: _isSending ? null : _showImageOptions,
                        icon: const Icon(Icons.add_a_photo_outlined),
                        tooltip: 'Analyze a photo',
                      ),
                      Expanded(
                        child: TextField(
                          controller: _inputController,
                          minLines: 1,
                          maxLines: 4,
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => _send(),
                          decoration: InputDecoration(
                            hintText: 'Ask Raahi anything...',
                            filled: true,
                            fillColor: AppColors.canvas,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(22),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 12,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: _isSending ? null : _toggleListening,
                        icon: Icon(
                          _isListening ? Icons.mic : Icons.mic_none,
                          color: _isListening ? AppColors.danger : null,
                        ),
                        tooltip: 'Speak',
                      ),
                      const SizedBox(width: 2),
                      IconButton.filled(
                        onPressed: _isSending ? null : _send,
                        icon: const Icon(Icons.arrow_upward_rounded),
                        tooltip: 'Send',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _speech.stop();
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}

class _ChatMessage {
  final String text;
  final bool isUser;
  final bool isError;
  final String? imagePath;

  const _ChatMessage({
    required this.text,
    required this.isUser,
    this.isError = false,
    this.imagePath,
  });
}

class _MessageBubble extends StatelessWidget {
  final _ChatMessage message;

  const _MessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final color = message.isUser
        ? AppColors.teal
        : message.isError
        ? const Color(0xFFFFF1F2)
        : AppColors.canvas;
    final textColor = message.isUser
        ? Colors.white
        : message.isError
        ? const Color(0xFF9F1239)
        : AppColors.ink;

    return Align(
      alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 340),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(18).copyWith(
            bottomRight: message.isUser ? const Radius.circular(4) : null,
            bottomLeft: message.isUser ? null : const Radius.circular(4),
          ),
        ),
        child: message.isUser
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (message.imagePath != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(
                        File(message.imagePath!),
                        width: 220,
                        height: 160,
                        fit: BoxFit.cover,
                      ),
                    ),
                  if (message.imagePath != null) const SizedBox(height: 8),
                  Text(
                    message.text,
                    style: TextStyle(color: textColor, height: 1.35),
                  ),
                ],
              )
            : MarkdownBody(
                data: message.text,
                selectable: true,
                styleSheet: MarkdownStyleSheet(
                  p: TextStyle(color: textColor, height: 1.35),
                  strong: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.w700,
                    height: 1.35,
                  ),
                  listBullet: TextStyle(color: textColor, height: 1.35),
                  h1: TextStyle(
                    color: textColor,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                  h2: TextStyle(
                    color: textColor,
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                  ),
                  h3: TextStyle(
                    color: textColor,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
      ),
    );
  }
}

class _TypingBubble extends StatelessWidget {
  const _TypingBubble();

  @override
  Widget build(BuildContext context) {
    return const Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: EdgeInsets.only(bottom: 12),
        child: Text(
          'Raahi is thinking...',
          style: TextStyle(color: AppColors.muted, fontStyle: FontStyle.italic),
        ),
      ),
    );
  }
}
