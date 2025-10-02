import 'dart:convert';
import 'package:http/http.dart' as http;

class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;

  ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
  });
}

class AIChatService {
  // Your Chatbase Agent ID
  static const String _agentId = 'hsQKeM8HRconRfdAMHuSf';

  // Your Chatbase API Key
  static const String _apiKey = 'a3v3rsppdbyyzkixa2awi3kflgmxutpx';

  // Send message to Chatbase AI
  static Future<String> sendMessage(String message) async {
    // List of potential Chatbase API endpoints to try
    List<String> endpoints = [
      'https://www.chatbase.co/api/v1/chat',
      'https://api.chatbase.co/chat',
      'https://chatbase.co/api/chat',
      'https://www.chatbase.co/api/chat',
    ];

    for (String endpoint in endpoints) {
      try {
        print('Trying endpoint: $endpoint');

        final response = await http.post(
          Uri.parse(endpoint),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $_apiKey',
          },
          body: jsonEncode({
            'agentId': _agentId,
            'message': message,
            'stream': false,
          }),
        );

        print('Response Status: ${response.statusCode}');
        print('Response Body: ${response.body}');

        if (response.statusCode == 200) {
          final responseData = jsonDecode(response.body);
          // Try different possible response field names
          String? aiResponse =
              responseData['text'] ??
              responseData['message'] ??
              responseData['response'] ??
              responseData['answer'];

          if (aiResponse != null && aiResponse.isNotEmpty) {
            return aiResponse;
          }
        }

        // If this endpoint doesn't work, try the next one
        continue;
      } catch (e) {
        print('Error with endpoint $endpoint: $e');
        continue;
      }
    }

    // If all endpoints fail, use mock response
    print('All Chatbase endpoints failed, using mock response');
    return _getMockResponse(message);
  }

  // Mock response system for demonstration
  // Replace this with your actual AI service integration
  static String _getMockResponse(String message) {
    String lowerMessage = message.toLowerCase();

    if (lowerMessage.contains('emergency') ||
        lowerMessage.contains('help') ||
        lowerMessage.contains('sos')) {
      return 'If you\'re in an emergency, immediately use the SOS button in the Safety Emergency section. This will alert your emergency contacts and local authorities. Stay calm and follow the emergency procedures.';
    } else if (lowerMessage.contains('location') ||
        lowerMessage.contains('gps')) {
      return 'I can help you with location services! Make sure your GPS tracking is enabled in the GPS section. This helps with navigation and emergency response. Is there a specific location you need help with?';
    } else if (lowerMessage.contains('safety') ||
        lowerMessage.contains('secure')) {
      return 'Your safety is our priority! Keep your tracking enabled, check your safety score regularly, and make sure your emergency contacts are up to date. Avoid unfamiliar areas alone, especially at night.';
    } else if (lowerMessage.contains('travel') ||
        lowerMessage.contains('tourist')) {
      return 'As a tourist, remember to: Keep copies of important documents, inform someone of your itinerary, stay in well-lit public areas, and use the Raahi app to track your location. Enjoy your travels safely!';
    } else if (lowerMessage.contains('app') || lowerMessage.contains('raahi')) {
      return 'Raahi is your travel safety companion! Use the Overview to check your status, GPS for location tracking, Safety Emergency for SOS alerts, IoT for connected devices, and ID for your digital identification.';
    } else if (lowerMessage.contains('hello') ||
        lowerMessage.contains('hi') ||
        lowerMessage.contains('hey')) {
      return 'Hello! I\'m your AI travel assistant. I can help you with safety tips, app features, emergency procedures, and general travel advice. How can I assist you today?';
    } else if (lowerMessage.contains('thank') ||
        lowerMessage.contains('thanks')) {
      return 'You\'re welcome! I\'m here to help keep you safe during your travels. Feel free to ask me anything about the app or travel safety anytime!';
    } else {
      return 'I\'m here to help with travel safety, app features, and emergency guidance. Could you be more specific about what you need assistance with? I can help with emergencies, location services, safety tips, or app navigation.';
    }
  }

  // Method to get conversation starters/suggestions
  static List<String> getConversationStarters() {
    return [
      'How do I use the emergency features?',
      'What should I do if I feel unsafe?',
      'How does GPS tracking work?',
      'Tell me about the app features',
      'Travel safety tips for tourists',
      'How to update emergency contacts?',
    ];
  }
}
