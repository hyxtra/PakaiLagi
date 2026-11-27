import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pakailagi/models/chat_message.dart';
import 'package:pakailagi/models/cloud_pickup_request.dart';
import 'package:pakailagi/models/item.dart';
import 'package:pakailagi/models/item_model.dart';
import 'package:pakailagi/providers/chat_provider.dart';
import 'package:pakailagi/providers/cloud_item_provider.dart';
import 'package:pakailagi/screens/chat_screen.dart';
import 'package:pakailagi/screens/inbox_screen.dart';
import 'package:pakailagi/services/firebase_auth_service.dart';
import 'package:pakailagi/theme/app_palette.dart';
import 'package:pakailagi/widgets/transaction_progress.dart';

// PNG 1x1 transparan valid agar Image.memory di PhotoPlaceholder ter-render.
final _samplePngBase64 = base64Encode(Uint8List.fromList([
  0x89,
  0x50,
  0x4E,
  0x47,
  0x0D,
  0x0A,
  0x1A,
  0x0A,
  0x00,
  0x00,
  0x00,
  0x0D,
  0x49,
  0x48,
  0x44,
  0x52,
  0x00,
  0x00,
  0x00,
  0x01,
  0x00,
  0x00,
  0x00,
  0x01,
  0x08,
  0x06,
  0x00,
  0x00,
  0x00,
  0x1F,
  0x15,
  0xC4,
  0x89,
  0x00,
  0x00,
  0x00,
  0x0A,
  0x49,
  0x44,
  0x41,
  0x54,
  0x78,
  0x9C,
  0x63,
  0x00,
  0x01,
  0x00,
  0x00,
  0x05,
  0x00,
  0x01,
  0x0D,
  0x0A,
  0x2D,
  0xB4,
  0x00,
  0x00,
  0x00,
  0x00,
  0x49,
  0x45,
  0x4E,
  0x44,
  0xAE,
  0x42,
  0x60,
  0x82,
]));

void main() {
  group('buildTransactionStepsWithDates', () {
    final created = DateTime(2026, 11, 26, 10, 0);
    final decided = DateTime(2026, 11, 26, 12, 30);
    final completed = DateTime(2026, 11, 27, 8, 15);

    test(
        'pending request menunjukkan langkah Diajukan selesai dan Disetujui aktif',
        () {
      final req = CloudPickupRequest(
        id: 'item1_u2',
        itemId: 'item1',
        ownerId: 'u1',
        requesterId: 'u2',
        requesterName: 'Budi',
        method: 'Bertemu (COD)',
        status: 'pending',
        createdAt: created,
      );

      final steps = buildTransactionStepsWithDates(
        itemStatus: ItemStatus.available,
        request: req,
        isOwner: false,
        itemCreatedAt: created,
      );

      expect(steps.length, 4);
      expect(steps[0].state, StepProgressState.done);
      expect(steps[1].state, StepProgressState.active);
      expect(steps[2].state, StepProgressState.upcoming);
      expect(steps[3].state, StepProgressState.upcoming);
    });

    test(
        'accepted + reserved menunjukkan Serah Terima aktif dan Disetujui selesai',
        () {
      final req = CloudPickupRequest(
        id: 'item1_u2',
        itemId: 'item1',
        ownerId: 'u1',
        requesterId: 'u2',
        requesterName: 'Budi',
        method: 'Bertemu (COD)',
        status: 'accepted',
        createdAt: created,
        decidedAt: decided,
      );

      final steps = buildTransactionStepsWithDates(
        itemStatus: ItemStatus.reserved,
        request: req,
        isOwner: false,
      );

      expect(steps[0].state, StepProgressState.done);
      expect(steps[1].state, StepProgressState.done);
      expect(steps[1].timestamp, decided);
      expect(steps[2].state, StepProgressState.active);
      expect(steps[3].state, StepProgressState.upcoming);
    });

    test(
        'completed menunjukkan seluruh 4 langkah selesai beserta waktu selesai',
        () {
      final req = CloudPickupRequest(
        id: 'item1_u2',
        itemId: 'item1',
        ownerId: 'u1',
        requesterId: 'u2',
        requesterName: 'Budi',
        method: 'Bertemu (COD)',
        status: 'accepted',
        createdAt: created,
        decidedAt: decided,
      );

      final steps = buildTransactionStepsWithDates(
        itemStatus: ItemStatus.completed,
        request: req,
        isOwner: true,
        itemCreatedAt: created,
        completedAt: completed,
      );

      expect(steps.every((s) => s.state == StepProgressState.done), isTrue);
      expect(steps[3].timestamp, completed);
    });

    test('rejected menghasilkan 2 langkah dengan status ditolak', () {
      final req = CloudPickupRequest(
        id: 'item1_u2',
        itemId: 'item1',
        ownerId: 'u1',
        requesterId: 'u2',
        requesterName: 'Budi',
        method: 'Bertemu (COD)',
        status: 'rejected',
        createdAt: created,
        decidedAt: decided,
      );

      final steps = buildTransactionStepsWithDates(
        itemStatus: ItemStatus.available,
        request: req,
        isOwner: false,
      );

      expect(steps.length, 2);
      expect(steps[0].state, StepProgressState.done);
      expect(steps[1].state, StepProgressState.rejected);
    });
  });

  group('ChatThread helpers', () {
    test('peerNameFor dan unreadFor sesuai peran pemilik vs peminta', () {
      const thread = ChatThread(
        chatId: 'item1_req1',
        itemId: 'item1',
        itemTitle: 'Meja Belajar',
        ownerId: 'owner1',
        ownerName: 'Ani',
        requesterId: 'req1',
        requesterName: 'Budi',
        lastMessage: 'Halo kak',
        lastSenderId: 'req1',
        ownerUnread: 2,
        requesterUnread: 0,
      );

      expect(thread.peerNameFor('owner1'), 'Budi');
      expect(thread.peerNameFor('req1'), 'Ani');
      expect(thread.unreadFor('owner1'), 2);
      expect(thread.unreadFor('req1'), 0);
    });
  });

  testWidgets(
      'InboxScreen menampilkan percakapan, thumbnail barang, dan badge unread',
      (tester) async {
    final items = [
      ItemModel(
        id: 'item1',
        title: 'Jaket Hangat',
        category: 'Pakaian',
        description: 'Masih tebal',
        imageBase64: _samplePngBase64,
        donorId: 'owner1',
        ownerName: 'Ani',
      ),
    ];
    const threads = [
      ChatThread(
        chatId: 'item1_req1',
        itemId: 'item1',
        itemTitle: 'Jaket Hangat',
        ownerId: 'owner1',
        ownerName: 'Ani',
        requesterId: 'req1',
        requesterName: 'Budi',
        lastMessage: 'Masih ada kak?',
        lastSenderId: 'req1',
        ownerUnread: 3,
        requesterUnread: 0,
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentFirebaseUidProvider.overrideWithValue('owner1'),
          chatThreadsProvider.overrideWith((_) => Stream.value(threads)),
          cloudItemsStreamProvider.overrideWith((_) => Stream.value(items)),
        ],
        child: MaterialApp(
          theme: ThemeData(extensions: const [AppPalette.light]),
          home: const Scaffold(body: InboxScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Pesan'), findsOneWidget);
    expect(find.text('Budi'), findsOneWidget);
    expect(find.text('Jaket Hangat'), findsOneWidget);
    expect(find.text('Masih ada kak?'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
  });

  testWidgets(
      'ChatScreen menampilkan kartu barang ala Shopee beserta sampul & pesan',
      (tester) async {
    final item = ItemModel(
      id: 'item1',
      title: 'Kemeja Flanel Kotak',
      category: 'Pakaian',
      description: 'Kondisi mulus',
      kelurahan: 'Melati',
      kota: 'Jakarta Selatan',
      condition: ItemCondition.veryGood,
      listingType: ListingType.tebusMurah,
      price: 25000,
      status: 'reserved',
      imageBase64: _samplePngBase64,
      donorId: 'owner1',
      ownerName: 'Ani',
    );
    const thread = ChatThread(
      chatId: 'item1_req1',
      itemId: 'item1',
      itemTitle: 'Kemeja Flanel Kotak',
      ownerId: 'owner1',
      ownerName: 'Ani',
      requesterId: 'req1',
      requesterName: 'Budi',
      lastMessage: 'Halo kak, masih ada?',
      lastSenderId: 'req1',
    );
    const messages = [
      ChatMessage(
        id: 'm1',
        senderId: 'req1',
        senderName: 'Budi',
        fromMe: true,
        time: '09:41',
        text: 'Halo kak, masih ada?',
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentFirebaseUidProvider.overrideWithValue('req1'),
          cloudItemByIdProvider('item1')
              .overrideWith((_) => Stream.value(item)),
          cloudItemsStreamProvider.overrideWith((_) => Stream.value([item])),
          myCloudItemsStreamProvider
              .overrideWith((_) => Stream.value(const [])),
          chatThreadByIdProvider('item1_req1')
              .overrideWith((_) => Stream.value(thread)),
          chatMessagesProvider('item1_req1')
              .overrideWith((_) => Stream.value(messages)),
        ],
        child: MaterialApp(
          theme: ThemeData(extensions: const [AppPalette.light]),
          home: const ChatScreen(
            itemId: 'item1',
            peerName: 'Ani',
            chatId: 'item1_req1',
            requesterId: 'req1',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Kamu menanyakan barang ini'), findsOneWidget);
    expect(find.text('Kemeja Flanel Kotak'), findsWidgets);
    expect(find.textContaining('Rp25.000'), findsOneWidget);
    expect(find.text('DISETUJUI'), findsOneWidget);
    expect(find.text('Halo kak, masih ada?'), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
  });
}
