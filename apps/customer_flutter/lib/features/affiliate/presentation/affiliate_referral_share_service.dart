import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

final affiliateReferralShareServiceProvider =
    Provider<AffiliateReferralShareService>((_) {
      return const SharePlusAffiliateReferralShareService();
    });

abstract interface class AffiliateReferralShareService {
  Future<void> share({
    required String text,
    required String subject,
    Rect? sharePositionOrigin,
  });
}

class SharePlusAffiliateReferralShareService
    implements AffiliateReferralShareService {
  const SharePlusAffiliateReferralShareService();

  @override
  Future<void> share({
    required String text,
    required String subject,
    Rect? sharePositionOrigin,
  }) async {
    await SharePlus.instance.share(
      ShareParams(
        text: text,
        title: subject,
        subject: subject,
        sharePositionOrigin: sharePositionOrigin,
      ),
    );
  }
}
