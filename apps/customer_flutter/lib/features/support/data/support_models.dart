class SupportCategory {
  const SupportCategory({
    required this.id,
    required this.code,
    required this.name,
    required this.iconKey,
  });

  factory SupportCategory.fromJson(Map<String, dynamic> json) {
    return SupportCategory(
      id: '${json['id'] ?? ''}',
      code: '${json['code'] ?? ''}',
      name: '${json['name'] ?? ''}',
      iconKey: '${json['icon_key'] ?? ''}',
    );
  }

  final String id;
  final String code;
  final String name;
  final String iconKey;
}

class SupportFaq {
  const SupportFaq({
    required this.id,
    required this.categoryId,
    required this.question,
    required this.answer,
  });

  factory SupportFaq.fromJson(Map<String, dynamic> json) {
    return SupportFaq(
      id: '${json['id'] ?? ''}',
      categoryId: '${json['category_id'] ?? ''}',
      question: '${json['question'] ?? ''}',
      answer: '${json['answer'] ?? ''}',
    );
  }

  final String id;
  final String categoryId;
  final String question;
  final String answer;
}

class SupportAgent {
  const SupportAgent({required this.id, required this.name});

  factory SupportAgent.fromJson(Map<String, dynamic> json) {
    return SupportAgent(
      id: '${json['id'] ?? ''}',
      name: '${json['name'] ?? ''}',
    );
  }

  final String id;
  final String name;
}

class SupportRating {
  const SupportRating({required this.stars, required this.comment});

  factory SupportRating.fromJson(Map<String, dynamic> json) {
    return SupportRating(
      stars: (json['stars'] as num?)?.toInt() ?? 0,
      comment: '${json['comment'] ?? ''}',
    );
  }

  final int stars;
  final String comment;
}

class SupportTicket {
  const SupportTicket({
    required this.id,
    required this.publicNo,
    required this.categoryId,
    required this.categoryName,
    required this.subject,
    required this.status,
    required this.chatAvailable,
    required this.lastMessage,
    required this.unreadCount,
    required this.queuePosition,
    required this.openedAt,
    required this.updatedAt,
    required this.closedAt,
    required this.closedByName,
    required this.agent,
    required this.rating,
  });

  factory SupportTicket.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(Object? value) =>
        DateTime.tryParse('$value')?.toLocal();
    final agent = json['agent'];
    final rating = json['rating'];
    final category = json['category'];
    final closedBy = json['closed_by'];
    final status = '${json['status'] ?? ''}';
    final parsedAgent = agent is Map
        ? SupportAgent.fromJson(Map<String, dynamic>.from(agent))
        : null;
    return SupportTicket(
      id: '${json['id'] ?? ''}',
      publicNo: '${json['public_no'] ?? ''}',
      categoryId: '${json['category_id'] ?? ''}',
      categoryName: category is Map ? '${category['name'] ?? ''}' : '',
      subject: '${json['subject'] ?? ''}',
      status: status,
      chatAvailable: json['chat_available'] is bool
          ? json['chat_available'] as bool
          : status != 'queued' && status != 'closed' && parsedAgent != null,
      lastMessage: '${json['last_message_preview'] ?? ''}',
      unreadCount: (json['unread_count'] as num?)?.toInt() ?? 0,
      queuePosition: (json['queue_position'] as num?)?.toInt(),
      openedAt: parseDate(json['opened_at'] ?? json['queued_at']),
      updatedAt: parseDate(json['last_message_at']),
      closedAt: parseDate(json['closed_at']),
      closedByName: closedBy is Map ? '${closedBy['name'] ?? ''}' : '',
      agent: parsedAgent,
      rating: rating is Map
          ? SupportRating.fromJson(Map<String, dynamic>.from(rating))
          : null,
    );
  }

  final String id;
  final String publicNo;
  final String categoryId;
  final String categoryName;
  final String subject;
  final String status;
  final bool chatAvailable;
  final String lastMessage;
  final int unreadCount;
  final int? queuePosition;
  final DateTime? openedAt;
  final DateTime? updatedAt;
  final DateTime? closedAt;
  final String closedByName;
  final SupportAgent? agent;
  final SupportRating? rating;

  bool get isClosed => status == 'closed';
  bool get isQueued => status == 'queued';
}

class SupportAttachment {
  const SupportAttachment({
    required this.id,
    required this.url,
    required this.width,
    required this.height,
  });

  factory SupportAttachment.fromJson(Map<String, dynamic> json) {
    return SupportAttachment(
      id: '${json['id'] ?? ''}',
      url: '${json['url'] ?? ''}',
      width: (json['width'] as num?)?.toInt(),
      height: (json['height'] as num?)?.toInt(),
    );
  }

  final String id;
  final String url;
  final int? width;
  final int? height;
}

class SupportMessage {
  const SupportMessage({
    required this.id,
    required this.sequence,
    required this.senderType,
    required this.senderName,
    required this.body,
    required this.attachments,
    required this.createdAt,
    required this.readByCounterpart,
  });

  factory SupportMessage.fromJson(Map<String, dynamic> json) {
    final sender = json['sender'];
    final attachments = json['attachments'];
    return SupportMessage(
      id: '${json['id'] ?? ''}',
      sequence: (json['sequence'] as num?)?.toInt() ?? 0,
      senderType: '${json['sender_type'] ?? ''}',
      senderName: sender is Map ? '${sender['name'] ?? ''}' : '',
      body: '${json['body'] ?? ''}',
      attachments: attachments is List
          ? attachments
                .whereType<Map>()
                .map(
                  (item) => SupportAttachment.fromJson(
                    Map<String, dynamic>.from(item),
                  ),
                )
                .toList(growable: false)
          : const [],
      createdAt: DateTime.tryParse('${json['created_at'] ?? ''}')?.toLocal(),
      readByCounterpart: json['read_by_counterpart'] is bool
          ? json['read_by_counterpart'] as bool
          : null,
    );
  }

  final String id;
  final int sequence;
  final String senderType;
  final String senderName;
  final String body;
  final List<SupportAttachment> attachments;
  final DateTime? createdAt;
  final bool? readByCounterpart;
}

class SupportBootstrap {
  const SupportBootstrap({
    required this.enabled,
    required this.categories,
    required this.activeTicket,
    required this.historyCount,
    required this.unreadCount,
    required this.limits,
  });

  factory SupportBootstrap.fromJson(Map<String, dynamic> json) {
    final categories = json['categories'];
    final ticket = json['active_ticket'];
    final limits = json['limits'];
    return SupportBootstrap(
      enabled: json['enabled'] != false,
      categories: categories is List
          ? categories
                .whereType<Map>()
                .map(
                  (item) =>
                      SupportCategory.fromJson(Map<String, dynamic>.from(item)),
                )
                .toList(growable: false)
          : const [],
      activeTicket: ticket is Map
          ? SupportTicket.fromJson(Map<String, dynamic>.from(ticket))
          : null,
      historyCount: (json['history_count'] as num?)?.toInt() ?? 0,
      unreadCount: (json['unread_count'] as num?)?.toInt() ?? 0,
      limits: limits is Map
          ? SupportLimits.fromJson(Map<String, dynamic>.from(limits))
          : const SupportLimits.defaults(),
    );
  }

  final bool enabled;
  final List<SupportCategory> categories;
  final SupportTicket? activeTicket;
  final int historyCount;
  final int unreadCount;
  final SupportLimits limits;
}

class SupportLimits {
  const SupportLimits({
    required this.attachmentsPerMessage,
    required this.attachmentBytes,
  });

  const SupportLimits.defaults()
    : attachmentsPerMessage = 4,
      attachmentBytes = 8 * 1024 * 1024;

  factory SupportLimits.fromJson(Map<String, dynamic> json) {
    return SupportLimits(
      attachmentsPerMessage:
          ((json['attachments_per_message'] as num?)?.toInt() ?? 4)
              .clamp(1, 4)
              .toInt(),
      attachmentBytes:
          ((json['attachment_bytes'] as num?)?.toInt() ?? 8 * 1024 * 1024)
              .clamp(1024, 8 * 1024 * 1024)
              .toInt(),
    );
  }

  final int attachmentsPerMessage;
  final int attachmentBytes;
}

class SupportTicketPage {
  const SupportTicketPage({required this.items, required this.nextCursor});

  final List<SupportTicket> items;
  final String? nextCursor;
}

class SupportMessagePage {
  const SupportMessagePage({
    required this.items,
    required this.nextBeforeSequence,
  });

  final List<SupportMessage> items;
  final int? nextBeforeSequence;
}
