import 'package:customer_flutter/features/support/data/support_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('support bootstrap parses localized categories and active ticket', () {
    final bootstrap = SupportBootstrap.fromJson({
      'enabled': true,
      'categories': [
        {
          'id': 'scat_general',
          'code': 'general',
          'name': 'ปัญหาทั่วไป',
          'icon_key': 'help',
        },
      ],
      'active_ticket': {
        'id': 'stic_01',
        'public_no': 'SUP-000001',
        'category_id': 'scat_general',
        'category': {'id': 'scat_general', 'name': 'ปัญหาทั่วไป'},
        'subject': 'ชำระเงินไม่สำเร็จ',
        'status': 'queued',
        'chat_available': false,
        'last_message_preview': 'กรุณาตรวจสอบรายการ',
        'unread_count': 2,
        'queue_position': 3,
        'opened_at': '2026-07-23T09:00:00+07:00',
      },
      'history_count': 4,
      'unread_count': 2,
      'limits': {'attachments_per_message': 3, 'attachment_bytes': 4194304},
    });

    expect(bootstrap.enabled, isTrue);
    expect(bootstrap.categories.single.name, 'ปัญหาทั่วไป');
    expect(bootstrap.activeTicket?.categoryName, 'ปัญหาทั่วไป');
    expect(bootstrap.activeTicket?.queuePosition, 3);
    expect(bootstrap.activeTicket?.isQueued, isTrue);
    expect(bootstrap.activeTicket?.chatAvailable, isFalse);
    expect(bootstrap.historyCount, 4);
    expect(bootstrap.unreadCount, 2);
    expect(bootstrap.limits.attachmentsPerMessage, 3);
    expect(bootstrap.limits.attachmentBytes, 4194304);
  });

  test('closed support ticket parses agent, closer, and one-time rating', () {
    final ticket = SupportTicket.fromJson({
      'id': 'stic_closed',
      'public_no': 'SUP-000002',
      'category_id': 'scat_order',
      'category': {'name': 'รายการสั่งซื้อ'},
      'subject': 'ต้องการตรวจสอบคำสั่งซื้อ',
      'status': 'closed',
      'chat_available': false,
      'last_message_preview': 'ดำเนินการเรียบร้อยแล้ว',
      'unread_count': 0,
      'opened_at': '2026-07-22T09:00:00+07:00',
      'last_message_at': '2026-07-22T10:00:00+07:00',
      'closed_at': '2026-07-22T10:01:00+07:00',
      'agent': {'id': 'adm_1', 'name': 'Support One'},
      'closed_by': {
        'id': 'adm_1',
        'name': 'Support One',
        'actor_type': 'admin',
      },
      'rating': {'stars': 5, 'comment': 'ช่วยเหลือดีมาก'},
    });

    expect(ticket.isClosed, isTrue);
    expect(ticket.chatAvailable, isFalse);
    expect(ticket.categoryName, 'รายการสั่งซื้อ');
    expect(ticket.agent?.name, 'Support One');
    expect(ticket.closedByName, 'Support One');
    expect(ticket.rating?.stars, 5);
    expect(ticket.rating?.comment, 'ช่วยเหลือดีมาก');
  });

  test(
    'support messages parse signed attachments and counterpart read state',
    () {
      final message = SupportMessage.fromJson({
        'id': 'smsg_01',
        'sequence': 8,
        'sender_type': 'customer',
        'sender': {'id': 'cus_1', 'name': 'Customer'},
        'body': 'แนบหลักฐาน',
        'read_by_counterpart': true,
        'attachments': [
          {
            'id': 'satt_01',
            'url': 'https://support.example.test/signed/image',
            'width': 1200,
            'height': 900,
          },
        ],
        'created_at': '2026-07-23T11:00:00+07:00',
      });

      expect(message.sequence, 8);
      expect(message.senderName, 'Customer');
      expect(message.readByCounterpart, isTrue);
      expect(message.attachments.single.id, 'satt_01');
      expect(message.attachments.single.width, 1200);
    },
  );

  test('support models safely fall back for optional response fields', () {
    final ticket = SupportTicket.fromJson({
      'id': 'stic_legacy',
      'status': 'assigned',
      'chat_available': true,
    });
    final message = SupportMessage.fromJson({
      'id': 'smsg_legacy',
      'sequence': 1,
    });

    expect(ticket.categoryName, isEmpty);
    expect(ticket.closedByName, isEmpty);
    expect(ticket.rating, isNull);
    expect(ticket.chatAvailable, isTrue);
    expect(message.attachments, isEmpty);
    expect(message.readByCounterpart, isNull);
  });
}
