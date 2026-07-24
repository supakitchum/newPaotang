<?php

namespace App\Modules\CustomerNotifications\Services;

use App\Jobs\FanoutRewardResultCustomerNotificationsJob;
use App\Models\AffiliateAccount;
use App\Models\AffiliatePayout;
use App\Models\RewardResult;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;

class CustomerNotificationDomainEventService
{
    private const RESULT_FANOUT_CHUNK_SIZE = 250;

    private const WALLET_SUPPRESSED_REFERENCE_TYPES = [
        'activity_claim',
        'affiliate_payout',
        'order',
        'order_cancel',
        'order_refund',
        'refund',
        'reward_claim',
        'topup',
        'topup_webhook',
    ];

    public function __construct(private readonly CustomerNotificationService $notifications)
    {
    }

    /** @param array<string, mixed> $payload */
    public function orderUpdated(array $payload): void
    {
        $tenantId = $this->text($payload['tenant_id'] ?? null);
        $customerId = $this->text($payload['customer_id'] ?? null);
        $orderId = $this->text($payload['order_id'] ?? null);
        $status = strtolower($this->text($payload['status'] ?? null));
        $paymentStatus = strtolower($this->text($payload['payment_status'] ?? null));

        if ($paymentStatus === 'refunded') {
            $status = 'refunded';
        } elseif ($paymentStatus === 'paid') {
            $status = 'paid';
        }

        $template = match ($status) {
            'pending_payment' => [
                'event_key' => 'order.waiting_payment',
                'title' => ['th-TH' => 'รอชำระเงินค่าสลาก', 'en-US' => 'Lottery payment required'],
                'body' => ['th-TH' => 'กรุณาชำระเงินเพื่อดำเนินรายการซื้อสลากให้เสร็จสมบูรณ์', 'en-US' => 'Complete payment to finish your lottery purchase.'],
                'action_key' => 'checkout_pending',
            ],
            'paid' => [
                'event_key' => 'order.paid',
                'title' => ['th-TH' => 'ซื้อสลากสำเร็จ', 'en-US' => 'Lottery purchase complete'],
                'body' => ['th-TH' => 'สลากของคุณพร้อมดูแล้วในเมนูสลากฯ ของฉัน', 'en-US' => 'Your tickets are ready in My Tickets.'],
                'action_key' => 'tickets',
            ],
            'failed' => [
                'event_key' => 'order.failed',
                'title' => ['th-TH' => 'รายการซื้อสลากไม่สำเร็จ', 'en-US' => 'Lottery purchase failed'],
                'body' => ['th-TH' => 'รายการซื้อสลากไม่สำเร็จ กรุณาตรวจสอบและลองใหม่อีกครั้ง', 'en-US' => 'Your lottery purchase could not be completed. Please review and try again.'],
                'action_key' => 'order',
            ],
            'cancelled' => [
                'event_key' => 'order.cancelled',
                'title' => ['th-TH' => 'ยกเลิกรายการซื้อสลากแล้ว', 'en-US' => 'Lottery purchase cancelled'],
                'body' => ['th-TH' => 'รายการซื้อสลากนี้ถูกยกเลิกแล้ว', 'en-US' => 'This lottery purchase has been cancelled.'],
                'action_key' => 'order',
            ],
            'expired' => [
                'event_key' => 'order.expired',
                'title' => ['th-TH' => 'รายการซื้อสลากหมดอายุ', 'en-US' => 'Lottery purchase expired'],
                'body' => ['th-TH' => 'รายการซื้อสลากหมดอายุก่อนชำระเงิน กรุณาเลือกสลากใหม่', 'en-US' => 'The purchase expired before payment. Please select tickets again.'],
                'action_key' => 'order',
            ],
            'refunded' => [
                'event_key' => 'order.refunded',
                'title' => ['th-TH' => 'คืนเงินรายการซื้อสลากแล้ว', 'en-US' => 'Lottery purchase refunded'],
                'body' => ['th-TH' => 'ระบบดำเนินการคืนเงินสำหรับรายการซื้อสลากแล้ว', 'en-US' => 'The refund for this lottery purchase has been processed.'],
                'action_key' => 'order',
            ],
            default => null,
        };

        if ($template === null) {
            return;
        }

        $this->notify(
            $tenantId,
            $customerId,
            $template['event_key'],
            [
                'category' => 'order',
                'title' => $template['title'],
                'body' => $template['body'],
                'icon_key' => 'ticket',
                'action_key' => $template['action_key'],
                'action_entity_id' => in_array($template['action_key'], ['order', 'checkout_pending'], true) ? $orderId : null,
                'subject_type' => 'order',
                'subject_id' => $orderId,
            ],
            'order:'.$orderId.':'.$status,
            ['status' => $status, 'game_id' => $this->nullableText($payload['game_id'] ?? null)],
        );
    }

    /** @param array<string, mixed> $payload */
    public function topupUpdated(array $payload): void
    {
        $tenantId = $this->text($payload['tenant_id'] ?? null);
        $customerId = $this->text($payload['customer_id'] ?? null);
        $topupId = $this->text($payload['topup_id'] ?? null);
        $topup = is_array($payload['topup'] ?? null) ? $payload['topup'] : [];
        $status = strtolower($this->text(
            $payload['notification_status']
                ?? $payload['source_status']
                ?? $payload['status']
                ?? $topup['notification_status']
                ?? $topup['source_status']
                ?? $topup['status']
                ?? null,
        ));

        $transition = match ($status) {
            'pending', 'processing', 'pending_payment', 'pending_review' => 'submitted',
            'succeeded' => 'succeeded',
            'approved' => 'approved',
            'failed' => 'failed',
            'rejected' => 'rejected',
            'cancelled' => 'cancelled',
            'expired' => 'expired',
            'reversed' => 'reversed',
            default => null,
        };

        $template = match ($transition) {
            'submitted' => [
                'title' => ['th-TH' => 'รับคำขอเติมเงินแล้ว', 'en-US' => 'Top-up request received'],
                'body' => ['th-TH' => 'ระบบรับคำขอเติมเงินแล้ว คุณสามารถติดตามสถานะได้ที่รายละเอียดรายการ', 'en-US' => 'Your top-up request was received. Track it from the request detail.'],
            ],
            'succeeded', 'approved' => [
                'title' => ['th-TH' => 'เติมเงินสำเร็จ', 'en-US' => 'Top-up complete'],
                'body' => ['th-TH' => 'รายการเติมเงินได้รับการอนุมัติและยอดเงินเข้ากระเป๋าแล้ว', 'en-US' => 'Your top-up was approved and the wallet balance was updated.'],
            ],
            'failed' => [
                'title' => ['th-TH' => 'รายการเติมเงินไม่สำเร็จ', 'en-US' => 'Top-up failed'],
                'body' => ['th-TH' => 'ระบบไม่สามารถดำเนินรายการเติมเงินได้ กรุณาดูรายละเอียดรายการ', 'en-US' => 'The top-up could not be completed. Review the request detail.'],
            ],
            'rejected' => [
                'title' => ['th-TH' => 'รายการเติมเงินไม่ผ่านการตรวจสอบ', 'en-US' => 'Top-up not approved'],
                'body' => ['th-TH' => 'รายการเติมเงินไม่ผ่านการตรวจสอบ กรุณาดูรายละเอียดรายการ', 'en-US' => 'Your top-up was not approved. Review the request detail.'],
            ],
            'cancelled' => [
                'title' => ['th-TH' => 'ยกเลิกรายการเติมเงินแล้ว', 'en-US' => 'Top-up cancelled'],
                'body' => ['th-TH' => 'รายการเติมเงินนี้ถูกยกเลิกแล้ว', 'en-US' => 'This top-up request has been cancelled.'],
            ],
            'expired' => [
                'title' => ['th-TH' => 'รายการเติมเงินหมดอายุ', 'en-US' => 'Top-up expired'],
                'body' => ['th-TH' => 'รายการเติมเงินหมดอายุก่อนชำระเงิน กรุณาสร้างรายการใหม่', 'en-US' => 'This top-up expired before payment. Please create a new request.'],
            ],
            'reversed' => [
                'title' => ['th-TH' => 'รายการเติมเงินถูกย้อนกลับ', 'en-US' => 'Top-up reversed'],
                'body' => ['th-TH' => 'ระบบย้อนกลับรายการเติมเงินแล้ว กรุณาดูรายละเอียดรายการ', 'en-US' => 'The top-up was reversed. Review the request detail.'],
            ],
            default => null,
        };

        if ($template === null) {
            return;
        }

        $this->notify(
            $tenantId,
            $customerId,
            'topup.'.$transition,
            [
                'category' => 'topup',
                'title' => $template['title'],
                'body' => $template['body'],
                'icon_key' => 'topup',
                'action_key' => 'topup',
                'action_entity_id' => $topupId,
                'subject_type' => 'topup',
                'subject_id' => $topupId,
            ],
            'topup:'.$topupId.':'.$transition,
            ['status' => $transition, 'source_status' => $status],
        );
    }

    /** @param array<string, mixed> $payload */
    public function walletUpdated(array $payload): void
    {
        $referenceType = strtolower($this->text($payload['reference_type'] ?? null));
        if (in_array($referenceType, self::WALLET_SUPPRESSED_REFERENCE_TYPES, true)) {
            return;
        }

        $tenantId = $this->text($payload['tenant_id'] ?? null);
        $customerId = $this->text($payload['customer_id'] ?? null);
        $ledgerId = $this->text($payload['ledger_id'] ?? null);
        $entryType = strtolower($this->text($payload['entry_type'] ?? null));
        $amount = (int) ($payload['amount'] ?? 0);
        $isDebit = in_array($entryType, ['debit', 'hold'], true) || $amount < 0;
        $transition = $isDebit ? 'debited' : 'credited';

        $this->notify(
            $tenantId,
            $customerId,
            'wallet.'.$transition,
            [
                'category' => 'wallet',
                'title' => $isDebit
                    ? ['th-TH' => 'มีรายการเงินออกจากกระเป๋า', 'en-US' => 'Wallet debit recorded']
                    : ['th-TH' => 'มีรายการเงินเข้ากระเป๋า', 'en-US' => 'Wallet credit recorded'],
                'body' => ['th-TH' => 'ตรวจสอบรายละเอียดและยอดคงเหลือได้ที่กระเป๋าของฉัน', 'en-US' => 'Review the transaction and current balance in My Wallet.'],
                'icon_key' => 'wallet',
                'action_key' => 'wallet',
                'subject_type' => 'wallet_ledger',
                'subject_id' => $ledgerId,
            ],
            'wallet-ledger:'.$ledgerId,
            ['entry_type' => $entryType, 'reference_type' => $referenceType],
        );
    }

    /** @param array<string, mixed> $payload */
    public function rewardClaimUpdated(array $payload): void
    {
        $claim = is_array($payload['claim'] ?? null) ? $payload['claim'] : [];
        $tenantId = $this->text($payload['tenant_id'] ?? $claim['tenant_id'] ?? null);
        $customerId = $this->text($payload['customer_id'] ?? ($claim['customer']['id'] ?? null));
        $claimId = $this->text($payload['claim_id'] ?? $claim['id'] ?? null);
        $status = strtolower($this->text($claim['status'] ?? $payload['status'] ?? null));
        $template = $this->claimTemplate($status, false);

        if ($template === null) {
            return;
        }

        $this->notify(
            $tenantId,
            $customerId,
            'reward_claim.'.$status,
            [
                'category' => 'reward',
                'title' => $template['title'],
                'body' => $template['body'],
                'icon_key' => 'reward',
                'action_key' => 'reward_claim',
                'action_entity_id' => $claimId,
                'subject_type' => 'reward_claim',
                'subject_id' => $claimId,
            ],
            'reward-claim:'.$claimId.':'.$status,
            ['status' => $status],
        );
    }

    /** @param array<string, mixed> $payload */
    public function activityClaimUpdated(array $payload): void
    {
        $claim = is_array($payload['claim'] ?? null) ? $payload['claim'] : [];
        $tenantId = $this->text($payload['tenant_id'] ?? $claim['tenant_id'] ?? null);
        $customerId = $this->text($payload['customer_id'] ?? $claim['customer_id'] ?? ($claim['customer']['id'] ?? null));
        $claimId = $this->text($payload['claim_id'] ?? $claim['id'] ?? null);
        $status = strtolower($this->text($claim['status'] ?? $payload['status'] ?? null));
        $template = $this->claimTemplate($status, true);

        if ($template === null) {
            return;
        }

        $this->notify(
            $tenantId,
            $customerId,
            'activity_claim.'.$status,
            [
                'category' => 'activity',
                'title' => $template['title'],
                'body' => $template['body'],
                'icon_key' => 'activity',
                'action_key' => 'activity_claim',
                'action_entity_id' => $claimId,
                'subject_type' => 'activity_claim',
                'subject_id' => $claimId,
            ],
            'activity-claim:'.$claimId.':'.$status,
            ['status' => $status],
        );
    }

    public function activityEntrySubmitted(
        string $tenantId,
        string $customerId,
        string $entryId,
        string $activityId,
        string $activitySlug,
    ): void {
        $this->notify(
            $tenantId,
            $customerId,
            'activity.entry.submitted',
            [
                'category' => 'activity',
                'title' => ['th-TH' => 'ส่งสิทธิ์ร่วมกิจกรรมแล้ว', 'en-US' => 'Activity entry submitted'],
                'body' => ['th-TH' => 'ระบบบันทึกการเข้าร่วมกิจกรรมของคุณแล้ว', 'en-US' => 'Your activity entry has been recorded.'],
                'icon_key' => 'activity',
                'action_key' => 'activity',
                'action_entity_id' => $activitySlug,
                'subject_type' => 'tenant_activity_entry',
                'subject_id' => $entryId,
            ],
            'activity-entry:'.$entryId.':submitted',
            ['activity_id' => $activityId],
        );
    }

    public function activityAwardGranted(
        string $tenantId,
        string $customerId,
        string $awardId,
        string $activityId,
        string $activitySlug,
    ): void {
        $this->notify(
            $tenantId,
            $customerId,
            'activity.award.granted',
            [
                'category' => 'activity',
                'title' => ['th-TH' => 'คุณได้รับรางวัลจากกิจกรรม', 'en-US' => 'You received an activity reward'],
                'body' => ['th-TH' => 'ตรวจสอบรางวัลและดำเนินการรับรางวัลได้จากหน้ากิจกรรม', 'en-US' => 'Review the reward and claim options from the activity page.'],
                'icon_key' => 'reward',
                'action_key' => 'activity',
                'action_entity_id' => $activitySlug,
                'subject_type' => 'tenant_activity_award',
                'subject_id' => $awardId,
            ],
            'activity-award:'.$awardId.':granted',
            ['activity_id' => $activityId],
        );
    }

    public function affiliateRegistered(string $tenantId, string $customerId, string $affiliateId): void
    {
        $this->notify(
            $tenantId,
            $customerId,
            'affiliate.registration.completed',
            [
                'category' => 'affiliate',
                'title' => ['th-TH' => 'สมัครตัวแทนจำหน่ายสำเร็จ', 'en-US' => 'Affiliate registration complete'],
                'body' => ['th-TH' => 'บัญชีตัวแทนจำหน่ายของคุณพร้อมใช้งานแล้ว', 'en-US' => 'Your affiliate account is ready to use.'],
                'icon_key' => 'affiliate',
                'action_key' => 'affiliate',
                'subject_type' => 'affiliate_account',
                'subject_id' => $affiliateId,
            ],
            'affiliate:'.$affiliateId.':registered',
        );
    }

    public function affiliateStoreNameReviewed(string $tenantId, string $affiliateId, bool $approved, string $requestId): void
    {
        $customerId = $this->affiliateCustomerId($tenantId, $affiliateId);
        $this->notify(
            $tenantId,
            $customerId,
            $approved ? 'affiliate.store_name.approved' : 'affiliate.store_name.rejected',
            [
                'category' => 'affiliate',
                'title' => $approved
                    ? ['th-TH' => 'อนุมัติชื่อร้านแล้ว', 'en-US' => 'Store name approved']
                    : ['th-TH' => 'ชื่อร้านไม่ผ่านการอนุมัติ', 'en-US' => 'Store name was not approved'],
                'body' => $approved
                    ? ['th-TH' => 'ชื่อร้านของคุณพร้อมแสดงในหน้าร้านค้าแล้ว', 'en-US' => 'Your store name is now visible in the store directory.']
                    : ['th-TH' => 'กรุณาตรวจสอบหมายเหตุและส่งชื่อร้านใหม่', 'en-US' => 'Review the note and submit a new store name.'],
                'icon_key' => 'affiliate',
                'action_key' => 'affiliate',
                'subject_type' => 'affiliate_store_name_request',
                'subject_id' => $requestId,
            ],
            'affiliate-store-name:'.$requestId.':'.($approved ? 'approved' : 'rejected'),
        );
    }

    public function affiliateTierChanged(
        string $tenantId,
        string $affiliateId,
        string $previousTier,
        string $newTier,
        string $campaignId,
    ): void {
        $customerId = $this->affiliateCustomerId($tenantId, $affiliateId);
        $this->notify(
            $tenantId,
            $customerId,
            'affiliate.tier.changed',
            [
                'category' => 'affiliate',
                'title' => ['th-TH' => 'ระดับตัวแทนจำหน่ายเปลี่ยนแล้ว', 'en-US' => 'Affiliate tier updated'],
                'body' => [
                    'th-TH' => 'ระดับของคุณเปลี่ยนจาก '.$previousTier.' เป็น '.$newTier.' และมีผลกับรายการใหม่ทันที',
                    'en-US' => 'Your tier changed from '.$previousTier.' to '.$newTier.' and now applies to new orders.',
                ],
                'icon_key' => 'affiliate',
                'action_key' => 'affiliate',
                'subject_type' => 'affiliate_tier_campaign',
                'subject_id' => $campaignId,
            ],
            'affiliate-tier:'.$campaignId.':'.$affiliateId.':'.$newTier,
        );
    }

    public function affiliateTierCampaignMilestone(
        string $tenantId,
        string $affiliateId,
        string $campaignId,
        string $campaignName,
        string $milestone,
    ): void {
        $customerId = $this->affiliateCustomerId($tenantId, $affiliateId);
        $endingSoon = $milestone === 'ending_soon';
        $this->notify(
            $tenantId,
            $customerId,
            $endingSoon ? 'affiliate.tier_campaign.ending_soon' : 'affiliate.tier_campaign.started',
            [
                'category' => 'affiliate',
                'title' => $endingSoon
                    ? ['th-TH' => 'กิจกรรมเลื่อนระดับใกล้สิ้นสุด', 'en-US' => 'Tier campaign ending soon']
                    : ['th-TH' => 'กิจกรรมประเมินระดับเริ่มแล้ว', 'en-US' => 'Tier campaign started'],
                'body' => $endingSoon
                    ? ['th-TH' => $campaignName.' จะสิ้นสุดภายใน 24 ชั่วโมง ตรวจสอบยอดขายล่าสุดได้แล้ว', 'en-US' => $campaignName.' ends within 24 hours. Review your latest progress.']
                    : ['th-TH' => $campaignName.' เริ่มแล้ว ยอดสลากที่ขายได้ในช่วงกิจกรรมจะถูกนำมาประเมินระดับ', 'en-US' => $campaignName.' has started. Tickets sold during the campaign count toward your tier result.'],
                'icon_key' => 'affiliate',
                'action_key' => 'affiliate',
                'subject_type' => 'affiliate_tier_campaign',
                'subject_id' => $campaignId,
            ],
            'affiliate-tier-campaign:'.$campaignId.':'.$affiliateId.':'.$milestone,
            ['campaign_name' => $campaignName, 'milestone' => $milestone],
        );
    }

    public function affiliateCommissionAvailable(string $tenantId, string $affiliateId, string $commissionId): void
    {
        $customerId = $this->affiliateCustomerId($tenantId, $affiliateId);
        $this->notify(
            $tenantId,
            $customerId,
            'affiliate.commission.available',
            [
                'category' => 'affiliate',
                'title' => ['th-TH' => 'ได้รับค่าคอมมิชชันใหม่', 'en-US' => 'New commission available'],
                'body' => ['th-TH' => 'มีค่าคอมมิชชันใหม่ในบัญชีตัวแทนจำหน่ายของคุณ', 'en-US' => 'A new commission is available in your affiliate account.'],
                'icon_key' => 'affiliate',
                'action_key' => 'affiliate',
                'subject_type' => 'commission_transaction',
                'subject_id' => $commissionId,
            ],
            'affiliate-commission:'.$commissionId.':available',
        );
    }

    public function affiliatePayoutUpdated(string $tenantId, string $payoutId): void
    {
        try {
            $payout = AffiliatePayout::query()
                ->where('tenant_id', $tenantId)
                ->whereKey($payoutId)
                ->first();
            if ($payout === null) {
                return;
            }

            $customerId = $this->affiliateCustomerId($tenantId, (string) $payout->affiliate_account_id);
            $status = strtolower((string) $payout->status);
            $template = match ($status) {
                'pending', 'submitted' => [
                    'event_key' => 'affiliate.payout.submitted',
                    'title' => ['th-TH' => 'ส่งคำขอถอนเงินแล้ว', 'en-US' => 'Affiliate payout submitted'],
                    'body' => ['th-TH' => 'ระบบรับคำขอถอนเงินตัวแทนจำหน่ายแล้ว', 'en-US' => 'Your affiliate payout request was received.'],
                ],
                'approved' => [
                    'event_key' => 'affiliate.payout.approved',
                    'title' => ['th-TH' => 'อนุมัติคำขอถอนเงินแล้ว', 'en-US' => 'Affiliate payout approved'],
                    'body' => ['th-TH' => 'คำขอถอนเงินตัวแทนจำหน่ายได้รับการอนุมัติแล้ว', 'en-US' => 'Your affiliate payout request was approved.'],
                ],
                'rejected' => [
                    'event_key' => 'affiliate.payout.rejected',
                    'title' => ['th-TH' => 'คำขอถอนเงินไม่ผ่านการอนุมัติ', 'en-US' => 'Affiliate payout rejected'],
                    'body' => ['th-TH' => 'กรุณาตรวจสอบรายละเอียดคำขอถอนเงินของคุณ', 'en-US' => 'Review the details of your affiliate payout request.'],
                ],
                'cancelled' => [
                    'event_key' => 'affiliate.payout.cancelled',
                    'title' => ['th-TH' => 'ยกเลิกคำขอถอนเงินแล้ว', 'en-US' => 'Affiliate payout cancelled'],
                    'body' => ['th-TH' => 'คำขอถอนเงินตัวแทนจำหน่ายถูกยกเลิกแล้ว', 'en-US' => 'Your affiliate payout request was cancelled.'],
                ],
                'paid' => [
                    'event_key' => 'affiliate.payout.paid',
                    'title' => ['th-TH' => 'จ่ายเงินตัวแทนจำหน่ายแล้ว', 'en-US' => 'Affiliate payout paid'],
                    'body' => ['th-TH' => 'ระบบดำเนินการจ่ายเงินตามคำขอถอนแล้ว', 'en-US' => 'Your affiliate payout has been paid.'],
                ],
                default => null,
            };

            if ($template === null) {
                return;
            }

            $this->notify(
                $tenantId,
                $customerId,
                $template['event_key'],
                [
                    'category' => 'affiliate',
                    'title' => $template['title'],
                    'body' => $template['body'],
                    'icon_key' => 'affiliate',
                    'action_key' => 'affiliate',
                    'subject_type' => 'affiliate_payout',
                    'subject_id' => $payoutId,
                ],
                'affiliate-payout:'.$payoutId.':'.$status,
                ['status' => $status],
            );
        } catch (\Throwable $exception) {
            $this->logFailure('affiliate.payout.updated', $payoutId, $exception);
        }
    }

    public function pinChanged(string $tenantId, string $customerId, string $transitionId): void
    {
        $this->accountSecurityNotification(
            $tenantId,
            $customerId,
            'account.pin.changed',
            'pin-change:'.$transitionId,
            ['th-TH' => 'รหัส PIN ถูกเปลี่ยนแล้ว', 'en-US' => 'PIN changed'],
            ['th-TH' => 'รหัส PIN สำหรับเข้าใช้งานบัญชีของคุณถูกเปลี่ยนแล้ว', 'en-US' => 'The PIN used to access your account was changed.'],
        );
    }

    public function passwordChanged(string $tenantId, string $customerId, string $transitionId): void
    {
        $this->accountSecurityNotification(
            $tenantId,
            $customerId,
            'account.password.changed',
            'password-change:'.$transitionId,
            ['th-TH' => 'รหัสผ่านถูกเปลี่ยนแล้ว', 'en-US' => 'Password changed'],
            ['th-TH' => 'รหัสผ่านบัญชีของคุณถูกเปลี่ยนแล้ว', 'en-US' => 'Your account password was changed.'],
        );
    }

    public function biometricDeviceChanged(
        string $tenantId,
        string $customerId,
        string $deviceId,
        string $status,
        string $transitionId,
    ): void {
        $added = $status === 'active';
        $this->accountSecurityNotification(
            $tenantId,
            $customerId,
            $added ? 'account.biometric.added' : 'account.biometric.revoked',
            'biometric:'.$deviceId.':'.$status.':'.$transitionId,
            $added
                ? ['th-TH' => 'เพิ่มอุปกรณ์ไบโอเมตริกแล้ว', 'en-US' => 'Biometric device added']
                : ['th-TH' => 'ยกเลิกอุปกรณ์ไบโอเมตริกแล้ว', 'en-US' => 'Biometric device revoked'],
            $added
                ? ['th-TH' => 'บัญชีของคุณเปิดใช้งานการยืนยันด้วยไบโอเมตริกบนอุปกรณ์ใหม่', 'en-US' => 'Biometric verification was enabled on a new device.']
                : ['th-TH' => 'อุปกรณ์ไบโอเมตริกถูกยกเลิกจากบัญชีของคุณ', 'en-US' => 'A biometric device was revoked from your account.'],
        );
    }

    public function accountStatusChanged(
        string $tenantId,
        string $customerId,
        string $status,
        string $transitionId,
    ): void {
        if (! in_array($status, ['active', 'suspended'], true)) {
            return;
        }

        $suspended = $status === 'suspended';
        $this->notify(
            $tenantId,
            $customerId,
            $suspended ? 'account.suspended' : 'account.restored',
            [
                'category' => 'account',
                'title' => $suspended
                    ? ['th-TH' => 'บัญชีถูกระงับการใช้งาน', 'en-US' => 'Account suspended']
                    : ['th-TH' => 'บัญชีกลับมาใช้งานได้แล้ว', 'en-US' => 'Account restored'],
                'body' => $suspended
                    ? ['th-TH' => 'บัญชีของคุณถูกระงับการใช้งาน กรุณาติดต่อผู้ให้บริการหากต้องการความช่วยเหลือ', 'en-US' => 'Your account was suspended. Contact the service provider for assistance.']
                    : ['th-TH' => 'บัญชีของคุณกลับมาใช้งานได้ตามปกติแล้ว', 'en-US' => 'Your account is active again.'],
                'icon_key' => 'security',
                'action_key' => 'none',
                'subject_type' => 'customer',
                'subject_id' => $customerId,
            ],
            'account-status:'.$customerId.':'.$status.':'.$transitionId,
            ['status' => $status],
            allowInactiveCustomer: true,
        );
    }

    public function fanOutRewardResultChunk(
        string $rewardResultId,
        ?string $afterTenantId = null,
        ?string $afterCustomerId = null,
    ): void {
        $result = RewardResult::query()->whereKey($rewardResultId)->where('status', 'published')->first();
        if ($result === null) {
            return;
        }

        $query = DB::table('tickets')
            ->where('game_id', (string) $result->game_id)
            ->whereNotIn('status', ['cancelled', 'voided'])
            ->whereNotNull('tenant_id')
            ->whereNotNull('customer_id')
            ->select(['tenant_id', 'customer_id'])
            ->distinct();

        $cursorTenant = $this->text($afterTenantId);
        $cursorCustomer = $this->text($afterCustomerId);
        if ($cursorTenant !== '') {
            $query->where(function ($cursor) use ($cursorTenant, $cursorCustomer): void {
                $cursor->where('tenant_id', '>', $cursorTenant)
                    ->orWhere(function ($sameTenant) use ($cursorTenant, $cursorCustomer): void {
                        $sameTenant->where('tenant_id', $cursorTenant)
                            ->where('customer_id', '>', $cursorCustomer);
                    });
            });
        }

        $owners = $query
            ->orderBy('tenant_id')
            ->orderBy('customer_id')
            ->limit(self::RESULT_FANOUT_CHUNK_SIZE)
            ->get();

        foreach ($owners as $owner) {
            $this->rewardResultForCustomer(
                (string) $result->id,
                (string) $result->game_id,
                (int) $result->version,
                (string) $owner->tenant_id,
                (string) $owner->customer_id,
            );
        }

        if ($owners->count() === self::RESULT_FANOUT_CHUNK_SIZE) {
            $last = $owners->last();
            FanoutRewardResultCustomerNotificationsJob::dispatch(
                (string) $result->id,
                (string) $last->tenant_id,
                (string) $last->customer_id,
            )->afterCommit();
        }
    }

    private function rewardResultForCustomer(
        string $rewardResultId,
        string $gameId,
        int $version,
        string $tenantId,
        string $customerId,
    ): void {
        try {
            $winningTicketId = DB::table('winning_tickets')
                ->join('tickets', 'tickets.id', '=', 'winning_tickets.ticket_id')
                ->where('winning_tickets.reward_result_id', $rewardResultId)
                ->where('winning_tickets.tenant_id', $tenantId)
                ->where('tickets.customer_id', $customerId)
                ->orderBy('tickets.id')
                ->value('tickets.id');
            $winning = $winningTicketId !== null;
            $claimId = $winning
                ? DB::table('reward_claims')
                    ->where('tenant_id', $tenantId)
                    ->where('customer_id', $customerId)
                    ->where('game_id', $gameId)
                    ->whereNotIn('status', ['rejected', 'cancelled'])
                    ->orderByDesc('created_at')
                    ->value('id')
                : null;

            $this->notify(
                $tenantId,
                $customerId,
                $winning ? 'lottery.result.winning' : 'lottery.result.published',
                [
                    'category' => 'lottery',
                    'title' => $winning
                        ? ['th-TH' => 'ยินดีด้วย คุณถูกรางวัล', 'en-US' => 'Congratulations, you won']
                        : ['th-TH' => 'ประกาศผลสลากแล้ว', 'en-US' => 'Lottery result published'],
                    'body' => $winning
                        ? ['th-TH' => 'ตรวจสอบสลากที่ถูกรางวัลและขั้นตอนรับเงินรางวัลได้แล้ว', 'en-US' => 'Review your winning ticket and reward claim options.']
                        : ['th-TH' => 'ตรวจสอบผลสลากของงวดนี้ได้ที่สลากฯ ของฉัน', 'en-US' => 'Check this draw result from My Tickets.'],
                    'icon_key' => $winning ? 'reward' : 'ticket',
                    'action_key' => $claimId !== null ? 'reward_claim' : ($winning ? 'ticket' : 'tickets'),
                    'action_entity_id' => $claimId ?? ($winning ? (string) $winningTicketId : null),
                    'subject_type' => 'reward_result',
                    'subject_id' => $rewardResultId,
                ],
                'lottery-result:'.$gameId.':v'.$version.':'.($winning ? 'winning' : 'published'),
                ['game_id' => $gameId, 'reward_version' => $version, 'winning' => $winning],
            );
        } catch (\Throwable $exception) {
            $this->logFailure('lottery.result.published', $rewardResultId, $exception);
        }
    }

    /**
     * @return array{title: array<string, string>, body: array<string, string>}|null
     */
    private function claimTemplate(string $status, bool $activity): ?array
    {
        $subjectTh = $activity ? 'รางวัลกิจกรรม' : 'เงินรางวัลสลาก';
        $subjectEn = $activity ? 'activity reward' : 'lottery reward';

        return match ($status) {
            'submitted' => [
                'title' => ['th-TH' => 'ส่งคำขอรับ'.$subjectTh.'แล้ว', 'en-US' => ucfirst($subjectEn).' claim submitted'],
                'body' => ['th-TH' => 'ระบบรับคำขอของคุณแล้วและกำลังรอตรวจสอบ', 'en-US' => 'Your claim was received and is awaiting review.'],
            ],
            'under_review' => [
                'title' => ['th-TH' => 'กำลังตรวจสอบคำขอรับ'.$subjectTh, 'en-US' => ucfirst($subjectEn).' claim under review'],
                'body' => ['th-TH' => 'เจ้าหน้าที่กำลังตรวจสอบคำขอของคุณ', 'en-US' => 'Your claim is being reviewed.'],
            ],
            'approved' => [
                'title' => ['th-TH' => 'อนุมัติคำขอรับ'.$subjectTh.'แล้ว', 'en-US' => ucfirst($subjectEn).' claim approved'],
                'body' => ['th-TH' => 'คำขอของคุณได้รับการอนุมัติแล้ว', 'en-US' => 'Your claim was approved.'],
            ],
            'rejected' => [
                'title' => ['th-TH' => 'คำขอรับ'.$subjectTh.'ไม่ผ่านการอนุมัติ', 'en-US' => ucfirst($subjectEn).' claim rejected'],
                'body' => ['th-TH' => 'กรุณาตรวจสอบรายละเอียดและหมายเหตุของคำขอ', 'en-US' => 'Review the claim detail and note.'],
            ],
            'cancelled' => [
                'title' => ['th-TH' => 'ยกเลิกคำขอรับ'.$subjectTh.'แล้ว', 'en-US' => ucfirst($subjectEn).' claim cancelled'],
                'body' => ['th-TH' => 'คำขอนี้ถูกยกเลิกแล้ว', 'en-US' => 'This claim has been cancelled.'],
            ],
            'paid' => [
                'title' => ['th-TH' => 'จ่าย'.$subjectTh.'แล้ว', 'en-US' => ucfirst($subjectEn).' paid'],
                'body' => ['th-TH' => 'ระบบดำเนินการจ่ายเงินรางวัลตามคำขอแล้ว', 'en-US' => 'The reward payment has been processed.'],
            ],
            default => null,
        };
    }

    /** @param array<string, string> $title @param array<string, string> $body */
    private function accountSecurityNotification(
        string $tenantId,
        string $customerId,
        string $eventKey,
        string $dedupeKey,
        array $title,
        array $body,
    ): void {
        $this->notify(
            $tenantId,
            $customerId,
            $eventKey,
            [
                'category' => 'account',
                'title' => $title,
                'body' => $body,
                'icon_key' => 'security',
                'action_key' => 'none',
                'subject_type' => 'customer',
                'subject_id' => $customerId,
            ],
            $dedupeKey,
        );
    }

    private function affiliateCustomerId(string $tenantId, string $affiliateId): string
    {
        try {
            return (string) (AffiliateAccount::query()
                ->where('tenant_id', $tenantId)
                ->whereKey($affiliateId)
                ->value('customer_id') ?? '');
        } catch (\Throwable $exception) {
            $this->logFailure('affiliate.customer.resolve', $affiliateId, $exception);

            return '';
        }
    }

    /**
     * @param array<string, mixed> $content
     * @param array<string, mixed> $metadata
     */
    private function notify(
        string $tenantId,
        string $customerId,
        string $eventKey,
        array $content,
        string $dedupeKey,
        array $metadata = [],
        bool $allowInactiveCustomer = false,
    ): void {
        if ($tenantId === '' || $customerId === '' || $eventKey === '' || $dedupeKey === '') {
            return;
        }

        try {
            $this->notifications->createForCustomer(
                $tenantId,
                $customerId,
                $eventKey,
                $content,
                [
                    'dedupe_key' => $dedupeKey,
                    'metadata' => $metadata,
                    'allow_inactive_customer' => $allowInactiveCustomer,
                ],
            );
        } catch (\Throwable $exception) {
            $this->logFailure($eventKey, (string) ($content['subject_id'] ?? ''), $exception);
        }
    }

    private function logFailure(string $eventKey, string $subjectId, \Throwable $exception): void
    {
        try {
            Log::warning('Customer domain notification creation failed.', [
                'event_key' => $eventKey,
                'subject_id' => $subjectId,
                'exception' => $exception::class,
            ]);
        } catch (\Throwable) {
        }
    }

    private function text(mixed $value): string
    {
        return is_scalar($value) ? trim((string) $value) : '';
    }

    private function nullableText(mixed $value): ?string
    {
        $text = $this->text($value);

        return $text === '' ? null : $text;
    }
}
