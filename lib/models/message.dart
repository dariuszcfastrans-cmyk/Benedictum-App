/// Model wiadomości w czacie Benedictum.
class Message {
  const Message({
    required this.id,
    required this.sender,
    required this.content,
    required this.timestamp,
  });

  final String id;
  final String sender;
  final String content;
  final DateTime timestamp;
}
