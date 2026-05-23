class BallReply {
  final bool granted;
  final String? destination;
  final String? note;
  final int? expiresAt;

  const BallReply._({required this.granted, this.destination, this.note, this.expiresAt});

  factory BallReply.fromMap(Map<String, dynamic> raw) {
    final granted = (raw['ok'] as bool?)      ??
                    (raw['granted'] as bool?)  ??
                    (raw['accepted'] as bool?) ?? false;

    final destination = raw['url'] as String?         ??
                        raw['link'] as String?        ??
                        raw['target'] as String?      ??
                        raw['destination'] as String?;

    final note = raw['message'] as String? ??
                 raw['note'] as String?    ??
                 raw['reason'] as String?;

    final dynamic ttl = raw['expires'] ?? raw['expires_at'] ?? raw['valid_until'];
    int? expires;
    if (ttl is int)         { expires = ttl; }
    else if (ttl is num)   { expires = ttl.toInt(); }
    else if (ttl is String) { expires = int.tryParse(ttl); }

    return BallReply._(granted: granted, destination: destination, note: note, expiresAt: expires);
  }

  factory BallReply.declined(String reason) =>
      BallReply._(granted: false, note: reason);
}
