import 'package:supabase_flutter/supabase_flutter.dart';

class RahiAiService {
  Future<String> sendMessage({
    required List<Map<String, String>> messages,
    required Map<String, dynamic> context,
    String? imageBase64,
    String? imageMimeType,
  }) async {
    try {
      final response = await Supabase.instance.client.functions.invoke(
        'rahi-chat',
        body: {
          'messages': messages,
          'context': context,
          if (imageBase64 != null) 'image_base64': imageBase64,
          if (imageMimeType != null) 'image_mime_type': imageMimeType,
        },
      );

      final data = response.data;
      if (data is! Map || data['message'] is! String) {
        final error = data is Map ? data['error'] : null;
        throw Exception(error ?? 'Raahi could not answer right now.');
      }
      return (data['message'] as String).trim();
    } on FunctionException catch (error) {
      final details = error.details;
      final message = details is Map && details['error'] is String
          ? details['error'] as String
          : details?.toString() ??
                error.reasonPhrase ??
                'Unknown function error';
      throw Exception('Raahi service (${error.status}): $message');
    }
  }
}
