import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/i18n/customer_localizations.dart';
import '../../../core/i18n/app_locale.dart';
import '../../../core/realtime/customer_realtime_client.dart';
import '../../../core/utils/api_errors.dart';
import '../../../core/utils/idempotency_key.dart';
import '../../../shared/widgets/app_shell.dart';
import '../../../shared/widgets/customer_page_body.dart';
import '../data/support_models.dart';
import '../data/support_repository.dart';

class SupportHomeScreen extends ConsumerStatefulWidget {
  const SupportHomeScreen({super.key});

  @override
  ConsumerState<SupportHomeScreen> createState() => _SupportHomeScreenState();
}

class _SupportHomeScreenState extends ConsumerState<SupportHomeScreen> {
  final _search = TextEditingController();
  SupportBootstrap? _bootstrap;
  List<SupportFaq> _faqs = const [];
  String _categoryId = '';
  String? _expandedFaqId;
  final Map<String, bool> _faqFeedback = {};
  final Set<String> _faqFeedbackPending = {};
  bool _loading = true;
  bool _searching = false;
  Object? _error;
  Object? _faqError;
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repository = ref.read(supportRepositoryProvider);
      final results = await Future.wait([
        repository.bootstrap(),
        repository.faqs(),
      ]);
      if (!mounted) return;
      setState(() {
        _bootstrap = results[0] as SupportBootstrap;
        _faqs = results[1] as List<SupportFaq>;
      });
      ref.invalidate(supportUnreadCountProvider);
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _searchFaqs() {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), _loadFaqs);
  }

  Future<void> _loadFaqs() async {
    setState(() {
      _searching = true;
      _faqError = null;
    });
    try {
      final faqs = await ref
          .read(supportRepositoryProvider)
          .faqs(query: _search.text, categoryId: _categoryId);
      if (mounted) {
        setState(() {
          _faqs = faqs;
          _expandedFaqId = null;
        });
      }
    } catch (error) {
      if (mounted) setState(() => _faqError = error);
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _submitFaqFeedback(SupportFaq faq, bool helpful) async {
    if (_faqFeedbackPending.contains(faq.id)) return;
    setState(() => _faqFeedbackPending.add(faq.id));
    try {
      await ref
          .read(supportRepositoryProvider)
          .submitFaqFeedback(faq.id, helpful: helpful);
      if (mounted) setState(() => _faqFeedback[faq.id] = helpful);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.support('common.error'))),
        );
      }
    } finally {
      if (mounted) setState(() => _faqFeedbackPending.remove(faq.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return _SupportShell(
      title: l10n.support('home.title'),
      currentPath: '/support',
      backPath: '/profile',
      child: _loading
          ? const _SupportHomeSkeleton()
          : _error != null
          ? _isSupportUnavailable(_error!)
                ? const _SupportUnavailable()
                : _SupportError(onRetry: _load)
          : _buildContent(context, _bootstrap!),
    );
  }

  Widget _buildContent(BuildContext context, SupportBootstrap bootstrap) {
    final l10n = context.l10n;
    if (!bootstrap.enabled) {
      return _SupportEmpty(
        icon: Icons.support_agent_outlined,
        title: l10n.support('home.unavailable'),
      );
    }

    return Column(
      children: [
        Expanded(
          child: RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 120),
              children: [
                if (bootstrap.activeTicket != null) ...[
                  Text(
                    l10n.support('home.active_ticket'),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _SupportTicketCard(
                    ticket: bootstrap.activeTicket!,
                    onTap: () => context.go(
                      '/support/tickets/${bootstrap.activeTicket!.id}',
                    ),
                    actionLabel: l10n.support('home.resume'),
                  ),
                  const SizedBox(height: 22),
                ],
                _SupportSearchField(
                  controller: _search,
                  loading: _searching,
                  onChanged: (_) => _searchFaqs(),
                  onClear: () {
                    _search.clear();
                    _loadFaqs();
                  },
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 38,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      _SupportCategoryChip(
                        label: l10n.support('home.all_categories'),
                        selected: _categoryId.isEmpty,
                        onTap: () {
                          setState(() => _categoryId = '');
                          _loadFaqs();
                        },
                      ),
                      ...bootstrap.categories.map(
                        (category) => _SupportCategoryChip(
                          label: category.name,
                          selected: _categoryId == category.id,
                          onTap: () {
                            setState(() => _categoryId = category.id);
                            _loadFaqs();
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        l10n.support('home.faq_title'),
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                    if (_searching)
                      const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                if (_faqError != null)
                  _SupportInlineError(onRetry: _loadFaqs)
                else if (_faqs.isEmpty)
                  _SupportEmpty(
                    compact: true,
                    icon: Icons.search_off_rounded,
                    title: _search.text.trim().isEmpty
                        ? l10n.support('home.no_faq')
                        : l10n.support('home.no_search_result'),
                  )
                else
                  ..._faqs.map(
                    (faq) => _SupportFaqTile(
                      faq: faq,
                      expanded: _expandedFaqId == faq.id,
                      onTap: () => setState(
                        () => _expandedFaqId = _expandedFaqId == faq.id
                            ? null
                            : faq.id,
                      ),
                      feedback: _faqFeedback[faq.id],
                      feedbackPending: _faqFeedbackPending.contains(faq.id),
                      onFeedback: (helpful) => _submitFaqFeedback(faq, helpful),
                    ),
                  ),
                const SizedBox(height: 18),
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 2),
                  leading: Icon(
                    Icons.history_rounded,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  title: Text(
                    l10n.support('home.history'),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (bootstrap.historyCount > 0)
                        Text('${bootstrap.historyCount}'),
                      if (bootstrap.historyCount > 0 &&
                          bootstrap.unreadCount > 0)
                        const SizedBox(width: 8),
                      if (bootstrap.unreadCount > 0)
                        _SupportUnreadBadge(count: bootstrap.unreadCount),
                      const SizedBox(width: 6),
                      const Icon(Icons.chevron_right_rounded),
                    ],
                  ),
                  onTap: () => context.go('/support/tickets'),
                ),
              ],
            ),
          ),
        ),
        if (bootstrap.activeTicket == null)
          _SupportBottomAction(
            label: l10n.support('home.new_ticket'),
            icon: Icons.add_comment_outlined,
            onPressed: () => context.go('/support/new'),
          ),
      ],
    );
  }
}

class SupportNewTicketScreen extends ConsumerStatefulWidget {
  const SupportNewTicketScreen({super.key, this.referencedTicketId});

  final String? referencedTicketId;

  @override
  ConsumerState<SupportNewTicketScreen> createState() =>
      _SupportNewTicketScreenState();
}

class _SupportNewTicketScreenState
    extends ConsumerState<SupportNewTicketScreen> {
  final _subject = TextEditingController();
  final _detail = TextEditingController();
  final _picker = ImagePicker();
  SupportBootstrap? _bootstrap;
  List<SupportFaq> _faqs = const [];
  List<XFile> _attachments = const [];
  SupportCategory? _category;
  int _step = 0;
  bool _loading = true;
  bool _submitting = false;
  double? _submitProgress;
  String? _submitIdempotencyKey;
  Object? _error;
  Object? _faqError;
  bool _showValidation = false;

  @override
  void initState() {
    super.initState();
    _subject.addListener(_resetSubmissionKey);
    _detail.addListener(_resetSubmissionKey);
    Future.microtask(_load);
  }

  @override
  void dispose() {
    _subject.removeListener(_resetSubmissionKey);
    _detail.removeListener(_resetSubmissionKey);
    _subject.dispose();
    _detail.dispose();
    super.dispose();
  }

  void _resetSubmissionKey() {
    if (!_submitting) _submitIdempotencyKey = null;
    if (_showValidation && mounted) setState(() {});
  }

  Future<void> _load() async {
    try {
      final bootstrap = await ref.read(supportRepositoryProvider).bootstrap();
      if (bootstrap.activeTicket != null && mounted) {
        context.go('/support/tickets/${bootstrap.activeTicket!.id}');
        return;
      }
      if (mounted) setState(() => _bootstrap = bootstrap);
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _selectCategory(SupportCategory category) async {
    setState(() {
      _category = category;
      _step = 1;
      _loading = true;
      _faqError = null;
      _submitIdempotencyKey = null;
    });
    try {
      final faqs = await ref
          .read(supportRepositoryProvider)
          .faqs(categoryId: category.id);
      if (mounted) setState(() => _faqs = faqs);
    } catch (error) {
      if (mounted) {
        setState(() {
          _faqs = const [];
          _faqError = error;
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickImage() async {
    final limits = _bootstrap?.limits ?? const SupportLimits.defaults();
    final remaining = limits.attachmentsPerMessage - _attachments.length;
    if (remaining <= 0) return;
    final files = await _picker.pickMultiImage(
      imageQuality: 88,
      limit: remaining,
    );
    final accepted = <XFile>[];
    for (final file in files.take(remaining)) {
      if (await file.length() <= limits.attachmentBytes) accepted.add(file);
    }
    if (!mounted) return;
    if (accepted.length != files.take(remaining).length) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.l10n
                .support('new.attachment_too_large')
                .replaceAll(
                  '{size}',
                  '${(limits.attachmentBytes / (1024 * 1024)).floor()}',
                ),
          ),
        ),
      );
    }
    if (accepted.isNotEmpty) {
      setState(() {
        _attachments = [..._attachments, ...accepted];
        _submitIdempotencyKey = null;
      });
    }
  }

  Future<void> _submit() async {
    if (_subject.text.trim().isEmpty ||
        _detail.text.trim().isEmpty ||
        _submitting) {
      if (!_submitting) setState(() => _showValidation = true);
      return;
    }
    _submitIdempotencyKey ??= newIdempotencyKey('support-ticket');
    setState(() {
      _submitting = true;
      _submitProgress = 0;
    });
    try {
      final ticket = await ref
          .read(supportRepositoryProvider)
          .createTicket(
            categoryId: _category?.id ?? '',
            subject: _subject.text.trim(),
            message: _detail.text.trim(),
            referencedTicketId: widget.referencedTicketId,
            attachments: _attachments,
            idempotencyKey: _submitIdempotencyKey,
            onSendProgress: (sent, total) {
              if (!mounted || total <= 0) return;
              setState(() => _submitProgress = sent / total);
            },
          );
      _submitIdempotencyKey = null;
      ref.invalidate(supportUnreadCountProvider);
      if (mounted) context.go('/support/tickets/${ticket.id}');
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.support('common.error')),
            action: SnackBarAction(
              label: context.l10n.support('common.retry'),
              onPressed: _submit,
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
          _submitProgress = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return _SupportShell(
      title: l10n.support('new.title'),
      currentPath: '/support/new',
      backPath: _step == 0 ? '/support' : null,
      onBack: _step > 0 ? () => setState(() => _step--) : null,
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _isSupportUnavailable(_error!)
                ? const _SupportUnavailable()
                : _SupportError(onRetry: _load)
          : Column(
              children: [
                _SupportStepIndicator(step: _step),
                Expanded(child: _stepContent(context)),
                if (_submitting && _submitProgress != null)
                  LinearProgressIndicator(value: _submitProgress),
                _SupportBottomAction(
                  label: _step < 2
                      ? l10n.support(_step == 1 ? 'new.contact' : 'new.next')
                      : l10n.support('new.submit'),
                  loading: _submitting,
                  onPressed: _step == 0
                      ? null
                      : _step == 1
                      ? _faqError == null
                            ? () => setState(() => _step = 2)
                            : null
                      : _submit,
                ),
              ],
            ),
    );
  }

  Widget _stepContent(BuildContext context) {
    final l10n = context.l10n;
    if (_step == 0) {
      final categories = _bootstrap?.categories ?? const <SupportCategory>[];
      return ListView(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 28),
        children: [
          Text(
            l10n.support('new.step_category'),
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 14),
          ...categories.map(
            (category) => _SupportCategoryRow(
              category: category,
              onTap: () => _selectCategory(category),
            ),
          ),
        ],
      );
    }
    if (_step == 1) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 28),
        children: [
          Text(
            l10n.support('new.step_faq'),
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          if (_faqError != null)
            _SupportInlineError(
              onRetry: () {
                final category = _category;
                if (category != null) unawaited(_selectCategory(category));
              },
            )
          else if (_faqs.isEmpty)
            _SupportEmpty(
              compact: true,
              icon: Icons.contact_support_outlined,
              title: l10n.support('home.no_faq'),
            )
          else
            ..._faqs.map(
              (faq) => _SupportFaqTile(faq: faq, expanded: true, onTap: () {}),
            ),
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: () => context.go('/support'),
            child: Text(l10n.support('new.solved')),
          ),
        ],
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 32),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      children: [
        Text(
          l10n.support('new.step_detail'),
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 16),
        _SupportTextField(
          controller: _subject,
          label: l10n.support('new.subject'),
          hint: l10n.support('new.subject_hint'),
          maxLength: 120,
          errorText: _showValidation && _subject.text.trim().isEmpty
              ? l10n.support('new.subject_required')
              : null,
        ),
        const SizedBox(height: 14),
        _SupportTextField(
          controller: _detail,
          label: l10n.support('new.detail'),
          hint: l10n.support('new.detail_hint'),
          maxLength: 4000,
          minLines: 6,
          maxLines: 10,
          errorText: _showValidation && _detail.text.trim().isEmpty
              ? l10n.support('new.detail_required')
              : null,
        ),
        const SizedBox(height: 14),
        OutlinedButton.icon(
          onPressed:
              _attachments.length >=
                  (_bootstrap?.limits.attachmentsPerMessage ?? 4)
              ? null
              : _pickImage,
          icon: const Icon(Icons.add_photo_alternate_outlined),
          label: Text(l10n.support('new.attach')),
        ),
        if (_attachments.isNotEmpty) ...[
          const SizedBox(height: 12),
          SizedBox(
            height: 92,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _attachments.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final file = _attachments[index];
                return Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: _SupportXFilePreview(
                        file: file,
                        width: 92,
                        height: 92,
                      ),
                    ),
                    Positioned(
                      top: 3,
                      right: 3,
                      child: IconButton.filled(
                        onPressed: () => setState(() {
                          _attachments = [
                            ..._attachments.take(index),
                            ..._attachments.skip(index + 1),
                          ];
                          _submitIdempotencyKey = null;
                        }),
                        icon: const Icon(Icons.close, size: 16),
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ],
    );
  }
}

class SupportTicketHistoryScreen extends ConsumerStatefulWidget {
  const SupportTicketHistoryScreen({super.key});

  @override
  ConsumerState<SupportTicketHistoryScreen> createState() =>
      _SupportTicketHistoryScreenState();
}

class _SupportTicketHistoryScreenState
    extends ConsumerState<SupportTicketHistoryScreen> {
  int _tab = 0;
  bool _loading = true;
  bool _loadingMore = false;
  Object? _error;
  final Map<int, List<SupportTicket>> _itemsByTab = {
    0: <SupportTicket>[],
    1: <SupportTicket>[],
  };
  final Map<int, String?> _nextCursorByTab = {0: null, 1: null};
  Timer? _poll;
  CustomerRealtimeClient? _realtime;
  StreamSubscription<CustomerRealtimeEvent>? _realtimeSubscription;

  List<SupportTicket> get _items => _itemsByTab[_tab]!;

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      await _load();
      if (!mounted) return;
      final realtimeConfigured = await _connectRealtime();
      if (!mounted) return;
      _poll = Timer.periodic(
        Duration(seconds: realtimeConfigured ? 30 : 10),
        (_) => _load(),
      );
    });
  }

  @override
  void dispose() {
    _poll?.cancel();
    unawaited(_realtimeSubscription?.cancel() ?? Future<void>.value());
    unawaited(_realtime?.dispose() ?? Future<void>.value());
    super.dispose();
  }

  Future<bool> _connectRealtime() async {
    try {
      final binding = await ref
          .read(supportRepositoryProvider)
          .realtimeBinding('');
      if (binding == null) return false;
      if (!mounted) {
        await binding.client.dispose();
        return false;
      }
      _realtime = binding.client;
      _realtimeSubscription = binding.client.events.listen((event) {
        if (!event.name.startsWith('support.')) return;
        ref.invalidate(supportUnreadCountProvider);
        unawaited(_load());
      });
      await binding.client.connect(binding.channels);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _load() async {
    final tab = _tab;
    setState(() {
      _loading = _itemsByTab[tab]!.isEmpty;
      _error = null;
    });
    try {
      final page = await ref
          .read(supportRepositoryProvider)
          .tickets(closed: tab == 1);
      if (mounted) {
        setState(() {
          _itemsByTab[tab] = page.items;
          _nextCursorByTab[tab] = page.nextCursor;
        });
      }
    } catch (error) {
      if (!mounted) return;
      if (_itemsByTab[tab]!.isEmpty) {
        setState(() => _error = error);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.support('common.error'))),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadMore() async {
    final tab = _tab;
    final cursor = _nextCursorByTab[tab];
    if (_loading || _loadingMore || cursor == null) return;
    setState(() => _loadingMore = true);
    try {
      final page = await ref
          .read(supportRepositoryProvider)
          .tickets(closed: tab == 1, cursor: cursor);
      if (!mounted) return;
      final knownIds = _itemsByTab[tab]!.map((item) => item.id).toSet();
      setState(() {
        _itemsByTab[tab] = [
          ..._itemsByTab[tab]!,
          ...page.items.where((item) => !knownIds.contains(item.id)),
        ];
        _nextCursorByTab[tab] = page.nextCursor;
      });
    } catch (_) {
      // Keep the loaded page visible; reaching the end again retries.
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return _SupportShell(
      title: l10n.support('history.title'),
      currentPath: '/support/tickets',
      backPath: '/support',
      maxWidth: 960,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 8),
            child: SizedBox(
              width: double.infinity,
              child: SegmentedButton<int>(
                segments: [
                  ButtonSegment(
                    value: 0,
                    label: Text(l10n.support('history.active')),
                  ),
                  ButtonSegment(
                    value: 1,
                    label: Text(l10n.support('history.closed')),
                  ),
                ],
                selected: {_tab},
                showSelectedIcon: false,
                expandedInsets: EdgeInsets.zero,
                onSelectionChanged: (selection) {
                  setState(() => _tab = selection.first);
                  _load();
                },
              ),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                ? _isSupportUnavailable(_error!)
                      ? const _SupportUnavailable()
                      : _SupportError(onRetry: _load)
                : RefreshIndicator(
                    onRefresh: _load,
                    child: _items.isEmpty
                        ? ListView(
                            children: [
                              _SupportEmpty(
                                icon: Icons.forum_outlined,
                                title: l10n.support(
                                  _tab == 0
                                      ? 'history.empty_active'
                                      : 'history.empty_closed',
                                ),
                              ),
                            ],
                          )
                        : NotificationListener<ScrollNotification>(
                            onNotification: (notification) {
                              if (notification.metrics.extentAfter < 240) {
                                unawaited(_loadMore());
                              }
                              return false;
                            },
                            child: _SupportTicketCollection(
                              tickets: _items,
                              loadingMore: _loadingMore,
                              onTap: (ticket) =>
                                  context.go('/support/tickets/${ticket.id}'),
                            ),
                          ),
                  ),
          ),
          if (_tab == 0 && _items.isEmpty && !_loading)
            _SupportBottomAction(
              label: l10n.support('home.new_ticket'),
              onPressed: () => context.go('/support/new'),
            ),
        ],
      ),
    );
  }
}

class SupportTicketChatScreen extends ConsumerStatefulWidget {
  const SupportTicketChatScreen({required this.ticketId, super.key});

  final String ticketId;

  @override
  ConsumerState<SupportTicketChatScreen> createState() =>
      _SupportTicketChatScreenState();
}

class _SupportTicketChatScreenState
    extends ConsumerState<SupportTicketChatScreen> {
  final _composer = TextEditingController();
  final _scroll = ScrollController();
  final _picker = ImagePicker();
  SupportTicket? _ticket;
  List<SupportMessage> _messages = const [];
  bool _loading = true;
  bool _sending = false;
  bool _loadingOlder = false;
  Object? _error;
  List<XFile> _attachments = const [];
  int? _nextBeforeSequence;
  int _newMessageCount = 0;
  double? _uploadProgress;
  String? _sendIdempotencyKey;
  String? _closeIdempotencyKey;
  String? _ratingIdempotencyKey;
  _RatingValue? _pendingRating;
  bool _closing = false;
  bool _ratingSheetOpen = false;
  bool _ratingSubmitting = false;
  SupportLimits _limits = const SupportLimits.defaults();
  Timer? _poll;
  Timer? _realtimeStatusTimer;
  CustomerRealtimeClient? _realtime;
  StreamSubscription<CustomerRealtimeEvent>? _realtimeSubscription;
  CustomerRealtimeStatus _realtimeStatus = CustomerRealtimeStatus.idle;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_handleScroll);
    _composer.addListener(() {
      if (!_sending) _sendIdempotencyKey = null;
    });
    Future.microtask(() async {
      await _load();
      final realtimeConfigured = await _connectRealtime();
      _poll = Timer.periodic(
        Duration(seconds: realtimeConfigured ? 30 : 10),
        (_) => _refreshQuietly(),
      );
    });
  }

  @override
  void dispose() {
    _poll?.cancel();
    _realtimeStatusTimer?.cancel();
    unawaited(_realtimeSubscription?.cancel() ?? Future<void>.value());
    unawaited(_realtime?.dispose() ?? Future<void>.value());
    _composer.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<bool> _connectRealtime() async {
    try {
      final binding = await ref
          .read(supportRepositoryProvider)
          .realtimeBinding(widget.ticketId);
      if (binding == null) {
        if (mounted) {
          setState(() => _realtimeStatus = CustomerRealtimeStatus.unavailable);
        }
        return false;
      }
      if (!mounted) {
        await binding.client.dispose();
        return false;
      }
      _realtime = binding.client;
      _realtimeSubscription = binding.client.events.listen((event) {
        if (!event.name.startsWith('support.')) return;
        final eventTicketId = '${event.payload['ticket_id'] ?? ''}';
        if (eventTicketId.isNotEmpty && eventTicketId != widget.ticketId) {
          return;
        }
        unawaited(_refreshQuietly());
      });
      await binding.client.connect(binding.channels);
      _watchRealtimeStatus(binding.client);
      return true;
    } catch (_) {
      if (mounted) {
        setState(() => _realtimeStatus = CustomerRealtimeStatus.error);
      }
      return false;
    }
  }

  void _watchRealtimeStatus(CustomerRealtimeClient client) {
    _realtimeStatusTimer?.cancel();
    void syncStatus() {
      if (!mounted || _realtimeStatus == client.status) return;
      setState(() => _realtimeStatus = client.status);
    }

    syncStatus();
    _realtimeStatusTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => syncStatus(),
    );
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final bootstrap = await ref.read(supportRepositoryProvider).bootstrap();
      if (mounted) setState(() => _limits = bootstrap.limits);
      await _fetch();
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<int> _fetch({bool mergeExisting = false, bool markRead = true}) async {
    final repository = ref.read(supportRepositoryProvider);
    final existingIds = _messages.map((message) => message.id).toSet();
    final results = await Future.wait([
      repository.ticket(widget.ticketId),
      repository.messages(widget.ticketId),
    ]);
    if (!mounted) return 0;
    final ticket = results[0] as SupportTicket;
    final page = results[1] as SupportMessagePage;
    final merged = mergeExisting
        ? {
            for (final message in _messages) message.id: message,
            for (final message in page.items) message.id: message,
          }.values.toList()
        : [...page.items];
    merged.sort((a, b) => a.sequence.compareTo(b.sequence));
    final added = page.items
        .where((message) => !existingIds.contains(message.id))
        .length;
    setState(() {
      _ticket = ticket;
      _messages = merged;
      if (!mergeExisting || _nextBeforeSequence == null) {
        _nextBeforeSequence = page.nextBeforeSequence;
      }
    });
    if (markRead && _messages.isNotEmpty) {
      await repository.markRead(widget.ticketId, _messages.last.sequence);
      ref.invalidate(supportUnreadCountProvider);
    }
    return added;
  }

  Future<void> _refreshQuietly() async {
    if (_loading || _sending) return;
    try {
      final wasNearBottom = _nearBottom;
      final wasClosed = _ticket?.isClosed ?? false;
      final added = await _fetch(mergeExisting: true, markRead: wasNearBottom);
      if (added > 0 && wasNearBottom) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
      } else if (added > 0 && mounted) {
        setState(() => _newMessageCount += added);
      }
      if (!wasClosed && (_ticket?.isClosed ?? false) && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.support('chat.closed_notice'))),
        );
        if (_ticket?.rating == null) {
          unawaited(_showRating());
        }
      }
    } catch (_) {}
  }

  void _handleScroll() {
    if (!_scroll.hasClients) return;
    if (_scroll.offset <= 80) {
      unawaited(_loadOlder());
    }
    if (_newMessageCount > 0 && _nearBottom) {
      setState(() => _newMessageCount = 0);
      if (_messages.isNotEmpty) {
        unawaited(
          ref
              .read(supportRepositoryProvider)
              .markRead(widget.ticketId, _messages.last.sequence)
              .then((_) => ref.invalidate(supportUnreadCountProvider)),
        );
      }
    }
  }

  Future<void> _loadOlder() async {
    final before = _nextBeforeSequence;
    if (_loadingOlder || before == null || !_scroll.hasClients) return;
    _loadingOlder = true;
    final previousExtent = _scroll.position.maxScrollExtent;
    try {
      final page = await ref
          .read(supportRepositoryProvider)
          .messages(widget.ticketId, beforeSequence: before);
      if (!mounted) return;
      final existingIds = _messages.map((message) => message.id).toSet();
      setState(() {
        _messages = [
          ...page.items.where((message) => !existingIds.contains(message.id)),
          ..._messages,
        ];
        _nextBeforeSequence = page.nextBeforeSequence;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_scroll.hasClients) return;
        final delta = _scroll.position.maxScrollExtent - previousExtent;
        _scroll.jumpTo(
          (_scroll.offset + delta).clamp(0, _scroll.position.maxScrollExtent),
        );
      });
    } catch (_) {
      // Keep the current conversation visible; the user can scroll up to retry.
    } finally {
      _loadingOlder = false;
    }
  }

  Future<void> _send() async {
    final body = _composer.text.trim();
    if (_sending || (body.isEmpty && _attachments.isEmpty)) return;
    _sendIdempotencyKey ??= newIdempotencyKey('support-message');
    setState(() {
      _sending = true;
      _uploadProgress = 0;
    });
    try {
      await ref
          .read(supportRepositoryProvider)
          .sendMessage(
            widget.ticketId,
            body: body,
            attachments: _attachments,
            idempotencyKey: _sendIdempotencyKey,
            onSendProgress: (sent, total) {
              if (!mounted || total <= 0) return;
              setState(() => _uploadProgress = sent / total);
            },
          );
      _composer.clear();
      setState(() {
        _attachments = const [];
        _sendIdempotencyKey = null;
      });
      await _fetch();
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.support('common.error')),
            action: SnackBarAction(
              label: context.l10n.support('common.retry'),
              onPressed: _send,
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _sending = false;
          _uploadProgress = null;
        });
      }
    }
  }

  Future<void> _closeTicket() async {
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _SupportConfirmSheet(
        title: context.l10n.support('chat.close_ticket'),
        message: context.l10n.support('chat.close_confirm'),
      ),
    );
    if (confirmed != true) return;
    await _performClose();
  }

  Future<void> _performClose() async {
    if (_closing) return;
    _closeIdempotencyKey ??= newIdempotencyKey('support-close');
    setState(() => _closing = true);
    try {
      final ticket = await ref
          .read(supportRepositoryProvider)
          .close(widget.ticketId, idempotencyKey: _closeIdempotencyKey);
      _closeIdempotencyKey = null;
      if (!mounted) return;
      setState(() => _ticket = ticket);
      ref.invalidate(supportUnreadCountProvider);
      await _showRating();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.support('common.error')),
            action: SnackBarAction(
              label: context.l10n.support('common.retry'),
              onPressed: _performClose,
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _closing = false);
    }
  }

  Future<void> _showRating() async {
    if (_ratingSheetOpen || _ratingSubmitting || _ticket?.rating != null) {
      return;
    }
    setState(() => _ratingSheetOpen = true);
    _RatingValue? result;
    try {
      result = await showModalBottomSheet<_RatingValue>(
        context: context,
        isScrollControlled: true,
        builder: (context) => const _SupportRatingSheet(),
      );
    } finally {
      if (mounted) setState(() => _ratingSheetOpen = false);
    }
    if (result == null) return;
    _pendingRating = result;
    _ratingIdempotencyKey ??= newIdempotencyKey('support-rating');
    await _submitRating();
  }

  Future<void> _submitRating() async {
    final pending = _pendingRating;
    if (pending == null || _ratingSubmitting) return;
    setState(() => _ratingSubmitting = true);
    try {
      final rating = await ref
          .read(supportRepositoryProvider)
          .rate(
            widget.ticketId,
            stars: pending.stars,
            comment: pending.comment,
            idempotencyKey: _ratingIdempotencyKey,
          );
      _pendingRating = null;
      _ratingIdempotencyKey = null;
      if (!mounted) return;
      setState(() {
        final ticket = _ticket;
        if (ticket != null) {
          _ticket = SupportTicket(
            id: ticket.id,
            publicNo: ticket.publicNo,
            categoryId: ticket.categoryId,
            categoryName: ticket.categoryName,
            subject: ticket.subject,
            status: ticket.status,
            lastMessage: ticket.lastMessage,
            unreadCount: ticket.unreadCount,
            queuePosition: ticket.queuePosition,
            openedAt: ticket.openedAt,
            updatedAt: ticket.updatedAt,
            closedAt: ticket.closedAt,
            closedByName: ticket.closedByName,
            agent: ticket.agent,
            rating: rating,
          );
        }
      });
      ref.invalidate(supportUnreadCountProvider);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.support('common.error')),
            action: SnackBarAction(
              label: context.l10n.support('common.retry'),
              onPressed: _submitRating,
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _ratingSubmitting = false);
    }
  }

  bool get _nearBottom {
    if (!_scroll.hasClients) return true;
    return _scroll.position.maxScrollExtent - _scroll.offset < 160;
  }

  void _scrollToBottom() {
    if (!_scroll.hasClients) return;
    _scroll.animateTo(
      _scroll.position.maxScrollExtent,
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final ticketNo = _ticket?.publicNo.replaceFirst('SUP-', '') ?? '';
    return _SupportShell(
      title: context.l10n
          .support('chat.title')
          .replaceAll('{number}', ticketNo),
      currentPath: '/support/tickets/${widget.ticketId}',
      backPath: '/support',
      maxWidth: 840,
      actions: [
        if (_ticket?.isClosed == false)
          PopupMenuButton<String>(
            onSelected: (_) => _closeTicket(),
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'close',
                child: Text(context.l10n.support('chat.close_ticket')),
              ),
            ],
          ),
      ],
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _isSupportUnavailable(_error!)
                ? const _SupportUnavailable()
                : _SupportError(onRetry: _load)
          : Column(
              children: [
                _SupportQueueBanner(ticket: _ticket!),
                if (_realtimeStatus != CustomerRealtimeStatus.connected)
                  _SupportConnectionBanner(status: _realtimeStatus),
                Expanded(
                  child: Stack(
                    children: [
                      ListView.builder(
                        controller: _scroll,
                        padding: const EdgeInsets.fromLTRB(14, 16, 14, 18),
                        itemCount: _messages.length + (_loadingOlder ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (_loadingOlder && index == 0) {
                            return const Padding(
                              padding: EdgeInsets.only(bottom: 12),
                              child: Center(
                                child: SizedBox.square(
                                  dimension: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              ),
                            );
                          }
                          final messageIndex = index - (_loadingOlder ? 1 : 0);
                          final message = _messages[messageIndex];
                          final previous = messageIndex > 0
                              ? _messages[messageIndex - 1]
                              : null;
                          final currentDate = message.createdAt;
                          final previousDate = previous?.createdAt;
                          final showDate =
                              currentDate != null &&
                              (previousDate == null ||
                                  !DateUtils.isSameDay(
                                    previousDate,
                                    currentDate,
                                  ));
                          return Column(
                            children: [
                              if (showDate)
                                _SupportDateSeparator(date: currentDate),
                              _SupportMessageBubble(message: message),
                            ],
                          );
                        },
                      ),
                      if (_newMessageCount > 0)
                        Positioned(
                          left: 14,
                          right: 14,
                          bottom: 12,
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: FilledButton.icon(
                              onPressed: () {
                                setState(() => _newMessageCount = 0);
                                _scrollToBottom();
                              },
                              icon: const Icon(Icons.arrow_downward_rounded),
                              label: Text(
                                context.l10n
                                    .support('chat.new_messages')
                                    .replaceAll('{count}', '$_newMessageCount'),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                if (_ticket!.isClosed)
                  _SupportClosedPanel(
                    ticket: _ticket!,
                    onRate: _showRating,
                    onNew: () =>
                        context.go('/support/new?reference=${_ticket!.id}'),
                  )
                else
                  _SupportComposer(
                    controller: _composer,
                    attachments: _attachments,
                    sending: _sending,
                    uploadProgress: _uploadProgress,
                    maxAttachments: _limits.attachmentsPerMessage,
                    onAttach: () async {
                      final remaining =
                          _limits.attachmentsPerMessage - _attachments.length;
                      if (remaining <= 0) return;
                      final files = await _picker.pickMultiImage(
                        imageQuality: 88,
                        limit: remaining,
                      );
                      final accepted = <XFile>[];
                      for (final file in files.take(remaining)) {
                        if (await file.length() <= _limits.attachmentBytes) {
                          accepted.add(file);
                        }
                      }
                      if (!context.mounted) return;
                      if (accepted.length != files.take(remaining).length) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              context.l10n
                                  .support('new.attachment_too_large')
                                  .replaceAll(
                                    '{size}',
                                    '${(_limits.attachmentBytes / (1024 * 1024)).floor()}',
                                  ),
                            ),
                          ),
                        );
                      }
                      if (accepted.isNotEmpty) {
                        setState(() {
                          _attachments = [..._attachments, ...accepted];
                          _sendIdempotencyKey = null;
                        });
                      }
                    },
                    onRemoveAttachment: (index) => setState(() {
                      _attachments = [
                        ..._attachments.take(index),
                        ..._attachments.skip(index + 1),
                      ];
                      _sendIdempotencyKey = null;
                    }),
                    onSend: _send,
                  ),
              ],
            ),
    );
  }
}

class _SupportShell extends StatelessWidget {
  const _SupportShell({
    required this.title,
    required this.currentPath,
    required this.child,
    this.backPath,
    this.onBack,
    this.actions = const [],
    this.maxWidth = 680,
  });

  final String title;
  final String currentPath;
  final String? backPath;
  final VoidCallback? onBack;
  final List<Widget> actions;
  final double maxWidth;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AppShell(
      title: title,
      currentPath: currentPath,
      backPath: backPath,
      onBack: onBack,
      sensitive: true,
      showBottomNavigation: false,
      compactHeader: true,
      heroContent: const SizedBox.shrink(),
      heroMinHeight: customerReferenceCompactHeroHeight,
      heroSheetOverlap: 0,
      heroContentTopGap: 0,
      actions: actions,
      child: Material(
        color: Colors.white,
        child: CustomerPageBody(
          maxWidth: maxWidth,
          top: 0,
          bottom: 0,
          mobileHorizontal: 0,
          wideHorizontal: 0,
          minViewportHeight: true,
          child: child,
        ),
      ),
    );
  }
}

class _SupportSearchField extends StatelessWidget {
  const _SupportSearchField({
    required this.controller,
    required this.loading,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final bool loading;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF3F7FB),
        borderRadius: BorderRadius.circular(8),
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        decoration: InputDecoration(
          border: InputBorder.none,
          prefixIcon: const Icon(Icons.search_rounded),
          hintText: context.l10n.support('home.search_hint'),
          suffixIcon: loading
              ? const Padding(
                  padding: EdgeInsets.all(14),
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : controller.text.isEmpty
              ? null
              : IconButton(
                  onPressed: onClear,
                  icon: const Icon(Icons.close_rounded),
                ),
        ),
      ),
    );
  }
}

class _SupportCategoryChip extends StatelessWidget {
  const _SupportCategoryChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
        showCheckmark: false,
      ),
    );
  }
}

class _SupportFaqTile extends StatelessWidget {
  const _SupportFaqTile({
    required this.faq,
    required this.expanded,
    required this.onTap,
    this.feedback,
    this.feedbackPending = false,
    this.onFeedback,
  });

  final SupportFaq faq;
  final bool expanded;
  final VoidCallback onTap;
  final bool? feedback;
  final bool feedbackPending;
  final ValueChanged<bool>? onFeedback;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFE7EDF4))),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      faq.question,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  Icon(
                    expanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                  ),
                ],
              ),
              if (expanded) ...[
                const SizedBox(height: 10),
                Text(
                  faq.answer,
                  style: const TextStyle(
                    color: Color(0xFF5F6B7A),
                    height: 1.55,
                  ),
                ),
                if (onFeedback != null) ...[
                  const SizedBox(height: 14),
                  Text(
                    context.l10n.support('home.faq_helpful'),
                    style: const TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      OutlinedButton.icon(
                        onPressed: feedbackPending
                            ? null
                            : () => onFeedback!(true),
                        icon: Icon(
                          feedback == true
                              ? Icons.thumb_up_rounded
                              : Icons.thumb_up_outlined,
                          size: 17,
                        ),
                        label: Text(context.l10n.support('home.helpful_yes')),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: feedbackPending
                            ? null
                            : () => onFeedback!(false),
                        icon: Icon(
                          feedback == false
                              ? Icons.thumb_down_rounded
                              : Icons.thumb_down_outlined,
                          size: 17,
                        ),
                        label: Text(context.l10n.support('home.helpful_no')),
                      ),
                    ],
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SupportCategoryRow extends StatelessWidget {
  const _SupportCategoryRow({required this.category, required this.onTap});

  final SupportCategory category;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      leading: CircleAvatar(
        backgroundColor: Theme.of(
          context,
        ).colorScheme.primary.withValues(alpha: .1),
        foregroundColor: Theme.of(context).colorScheme.primary,
        child: const Icon(Icons.help_outline_rounded),
      ),
      title: Text(
        category.name,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: onTap,
    );
  }
}

class _SupportTicketCollection extends StatelessWidget {
  const _SupportTicketCollection({
    required this.tickets,
    required this.loadingMore,
    required this.onTap,
  });

  final List<SupportTicket> tickets;
  final bool loadingMore;
  final ValueChanged<SupportTicket> onTap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 760;
        final horizontal = constraints.maxWidth < 380
            ? 12.0
            : wide
            ? 24.0
            : 18.0;
        if (!wide) {
          return ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(horizontal, 8, horizontal, 110),
            itemCount: tickets.length + (loadingMore ? 1 : 0),
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              if (index == tickets.length) {
                return const Padding(
                  padding: EdgeInsets.all(12),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              final ticket = tickets[index];
              return _SupportTicketCard(
                ticket: ticket,
                onTap: () => onTap(ticket),
              );
            },
          );
        }

        const spacing = 12.0;
        final cardWidth =
            (constraints.maxWidth - (horizontal * 2) - spacing) / 2;
        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(horizontal, 8, horizontal, 110),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: [
                  for (final ticket in tickets)
                    SizedBox(
                      width: cardWidth,
                      child: _SupportTicketCard(
                        ticket: ticket,
                        onTap: () => onTap(ticket),
                      ),
                    ),
                ],
              ),
              if (loadingMore)
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: Center(child: CircularProgressIndicator()),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _SupportTicketCard extends StatelessWidget {
  const _SupportTicketCard({
    required this.ticket,
    required this.onTap,
    this.actionLabel,
  });

  final SupportTicket ticket;
  final VoidCallback onTap;
  final String? actionLabel;

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(context, ticket.status);
    return Material(
      color: const Color(0xFFFFFFFF),
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: Color(0xFFE2E8F0)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      ticket.publicNo,
                      style: const TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 13,
                      ),
                    ),
                  ),
                  _SupportStatusChip(ticket: ticket, color: color),
                ],
              ),
              if (ticket.categoryName.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  ticket.categoryName,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Text(
                ticket.subject,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              if (ticket.lastMessage.isNotEmpty) ...[
                const SizedBox(height: 5),
                Text(
                  ticket.lastMessage,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Color(0xFF64748B)),
                ),
              ],
              const SizedBox(height: 10),
              LayoutBuilder(
                builder: (context, constraints) {
                  final metadata = <Widget>[
                    if (ticket.unreadCount > 0)
                      _SupportUnreadBadge(count: ticket.unreadCount),
                    if (ticket.updatedAt != null)
                      Text(
                        DateFormat.yMMMd(
                          localeTag(context.l10n.locale),
                        ).add_Hm().format(ticket.updatedAt!),
                        style: const TextStyle(
                          color: Color(0xFF8491A3),
                          fontSize: 11,
                        ),
                      ),
                    if (ticket.isClosed && ticket.rating == null)
                      Text(
                        context.l10n.support('history.awaiting_rating'),
                        style: const TextStyle(
                          color: Color(0xFFF59E0B),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      )
                    else if (ticket.rating != null)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.star_rounded,
                            color: Color(0xFFFFB800),
                            size: 16,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            '${ticket.rating!.stars}/5',
                            style: const TextStyle(fontSize: 11),
                          ),
                        ],
                      ),
                  ];
                  final navigation = Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (actionLabel != null)
                        Text(
                          actionLabel!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      const Icon(Icons.chevron_right_rounded),
                    ],
                  );
                  final metadataWrap = Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: metadata,
                  );
                  if (actionLabel != null && constraints.maxWidth < 420) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        metadataWrap,
                        const SizedBox(height: 6),
                        Align(
                          alignment: Alignment.centerRight,
                          child: navigation,
                        ),
                      ],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(child: metadataWrap),
                      const SizedBox(width: 8),
                      navigation,
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SupportStatusChip extends StatelessWidget {
  const _SupportStatusChip({required this.ticket, required this.color});

  final SupportTicket ticket;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        context.l10n.support('status.${ticket.status}'),
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _SupportUnreadBadge extends StatelessWidget {
  const _SupportUnreadBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
      padding: const EdgeInsets.symmetric(horizontal: 5),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary,
        borderRadius: BorderRadius.circular(10),
      ),
      alignment: Alignment.center,
      child: Text(
        count > 99 ? '99+' : '$count',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _SupportStepIndicator extends StatelessWidget {
  const _SupportStepIndicator({required this.step});

  final int step;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 2),
      child: Row(
        children: List.generate(3, (index) {
          final active = index <= step;
          return Expanded(
            child: Container(
              height: 4,
              margin: EdgeInsets.only(right: index == 2 ? 0 : 6),
              decoration: BoxDecoration(
                color: active
                    ? Theme.of(context).colorScheme.primary
                    : const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _SupportTextField extends StatelessWidget {
  const _SupportTextField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.maxLength,
    this.minLines = 1,
    this.maxLines = 1,
    this.errorText,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final int maxLength;
  final int minLines;
  final int maxLines;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      minLines: minLines,
      maxLines: maxLines,
      maxLength: maxLength,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        errorText: errorText,
        alignLabelWithHint: minLines > 1,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}

class _SupportQueueBanner extends StatelessWidget {
  const _SupportQueueBanner({required this.ticket});

  final SupportTicket ticket;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final queued = ticket.isQueued;
    final message = ticket.isClosed
        ? ticket.closedByName.isEmpty
              ? l10n.support('status.closed')
              : l10n
                    .support('chat.closed_by')
                    .replaceAll('{name}', ticket.closedByName)
        : queued
        ? ticket.queuePosition != null && ticket.queuePosition! > 1
              ? l10n
                    .support('chat.queue_ahead')
                    .replaceAll('{count}', '${ticket.queuePosition! - 1}')
              : l10n.support('chat.queue')
        : l10n
              .support('chat.assigned')
              .replaceAll('{name}', ticket.agent?.name ?? '');
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
      color: const Color(0xFFEEF7FF),
      child: Row(
        children: [
          Icon(
            ticket.isClosed
                ? Icons.task_alt_rounded
                : queued
                ? Icons.schedule_rounded
                : Icons.support_agent_rounded,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(message)),
          if ((ticket.isClosed ? ticket.closedAt : ticket.openedAt) != null)
            Text(
              DateFormat.Hm(
                localeTag(l10n.locale),
              ).format(ticket.isClosed ? ticket.closedAt! : ticket.openedAt!),
              style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
            ),
        ],
      ),
    );
  }
}

class _SupportMessageBubble extends StatelessWidget {
  const _SupportMessageBubble({required this.message});

  final SupportMessage message;

  @override
  Widget build(BuildContext context) {
    if (message.senderType == 'system') {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Center(
          child: Text(
            message.body,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFF8491A3), fontSize: 12),
          ),
        ),
      );
    }
    final mine = message.senderType == 'customer';
    final primary = Theme.of(context).colorScheme.primary;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 460),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(
          color: mine ? primary : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(12),
            topRight: const Radius.circular(12),
            bottomLeft: Radius.circular(mine ? 12 : 3),
            bottomRight: Radius.circular(mine ? 3 : 12),
          ),
        ),
        child: Column(
          crossAxisAlignment: mine
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            if (!mine && message.senderName.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  message.senderName,
                  style: TextStyle(
                    color: primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ...message.attachments.map(
              (attachment) => Padding(
                padding: const EdgeInsets.only(bottom: 7),
                child: GestureDetector(
                  onTap: () => _showAttachment(context, attachment),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(7),
                    child: Image.network(
                      attachment.url,
                      width: 260,
                      height: 190,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
            ),
            if (message.body.isNotEmpty)
              Text(
                message.body,
                style: TextStyle(
                  color: mine ? Colors.white : const Color(0xFF1E293B),
                  height: 1.4,
                ),
              ),
            if (message.createdAt != null) ...[
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    DateFormat.Hm(
                      localeTag(context.l10n.locale),
                    ).format(message.createdAt!),
                    style: TextStyle(
                      color: mine ? Colors.white70 : const Color(0xFF94A3B8),
                      fontSize: 10,
                    ),
                  ),
                  if (mine && message.readByCounterpart != null) ...[
                    const SizedBox(width: 3),
                    Icon(
                      message.readByCounterpart!
                          ? Icons.done_all_rounded
                          : Icons.done_rounded,
                      color: Colors.white70,
                      size: 14,
                    ),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _showAttachment(
    BuildContext context,
    SupportAttachment attachment,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (context) => Dialog.fullscreen(
        backgroundColor: Colors.black,
        child: Stack(
          children: [
            Positioned.fill(
              child: InteractiveViewer(
                child: Center(child: Image.network(attachment.url)),
              ),
            ),
            Positioned(
              top: MediaQuery.paddingOf(context).top + 8,
              left: 8,
              child: IconButton.filled(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded),
              ),
            ),
            Positioned(
              top: MediaQuery.paddingOf(context).top + 8,
              right: 8,
              child: IconButton.filled(
                onPressed: () => launchUrl(
                  Uri.parse(attachment.url),
                  mode: LaunchMode.externalApplication,
                ),
                icon: const Icon(Icons.download_rounded),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SupportComposer extends StatelessWidget {
  const _SupportComposer({
    required this.controller,
    required this.attachments,
    required this.sending,
    required this.uploadProgress,
    required this.maxAttachments,
    required this.onAttach,
    required this.onRemoveAttachment,
    required this.onSend,
  });

  final TextEditingController controller;
  final List<XFile> attachments;
  final bool sending;
  final double? uploadProgress;
  final int maxAttachments;
  final VoidCallback onAttach;
  final ValueChanged<int> onRemoveAttachment;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 8,
      color: Colors.white,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (attachments.isNotEmpty)
                SizedBox(
                  height: 58,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: attachments.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, index) => Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: _SupportXFilePreview(
                            file: attachments[index],
                            width: 58,
                            height: 58,
                          ),
                        ),
                        Positioned(
                          top: 2,
                          right: 2,
                          child: InkWell(
                            onTap: () => onRemoveAttachment(index),
                            child: const CircleAvatar(
                              radius: 10,
                              backgroundColor: Colors.black54,
                              child: Icon(
                                Icons.close_rounded,
                                color: Colors.white,
                                size: 14,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              if (sending && uploadProgress != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: LinearProgressIndicator(value: uploadProgress),
                ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  IconButton(
                    tooltip: context.l10n.support('new.attach'),
                    onPressed: sending || attachments.length >= maxAttachments
                        ? null
                        : onAttach,
                    icon: const Icon(Icons.attach_file_rounded),
                  ),
                  Expanded(
                    child: Focus(
                      onKeyEvent: (node, event) {
                        if (event is! KeyDownEvent ||
                            event.logicalKey != LogicalKeyboardKey.enter) {
                          return KeyEventResult.ignored;
                        }
                        final keyboard = HardwareKeyboard.instance;
                        final composing = controller.value.composing;
                        if (keyboard.isShiftPressed ||
                            keyboard.isControlPressed ||
                            keyboard.isAltPressed ||
                            keyboard.isMetaPressed ||
                            (composing.isValid && !composing.isCollapsed)) {
                          return KeyEventResult.ignored;
                        }
                        if (!sending) onSend();
                        return KeyEventResult.handled;
                      },
                      child: TextField(
                        key: const ValueKey('support-chat-composer'),
                        controller: controller,
                        minLines: 1,
                        maxLines: 5,
                        maxLength: 4000,
                        keyboardType: TextInputType.multiline,
                        textInputAction: TextInputAction.newline,
                        buildCounter:
                            (
                              context, {
                              required currentLength,
                              required isFocused,
                              required maxLength,
                            }) => null,
                        decoration: InputDecoration(
                          hintText: context.l10n.support('chat.message_hint'),
                          filled: true,
                          fillColor: const Color(0xFFF3F7FB),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  IconButton.filled(
                    tooltip: context.l10n.support('common.send'),
                    onPressed: sending ? null : onSend,
                    icon: sending
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.send_rounded),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SupportClosedPanel extends StatelessWidget {
  const _SupportClosedPanel({
    required this.ticket,
    required this.onRate,
    required this.onNew,
  });

  final SupportTicket ticket;
  final VoidCallback onRate;
  final VoidCallback onNew;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 14),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              context.l10n.support('chat.closed'),
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 8),
            Text(
              ticket.subject,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            if (ticket.closedByName.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                context.l10n
                    .support('chat.closed_by')
                    .replaceAll('{name}', ticket.closedByName),
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
              ),
            ],
            if (ticket.closedAt != null)
              Text(
                context.l10n
                    .support('chat.closed_at')
                    .replaceAll(
                      '{date}',
                      DateFormat.yMMMd(
                        localeTag(context.l10n.locale),
                      ).add_Hm().format(ticket.closedAt!),
                    ),
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
              ),
            const SizedBox(height: 10),
            if (ticket.rating == null)
              FilledButton.icon(
                onPressed: onRate,
                icon: const Icon(Icons.star_outline_rounded),
                label: Text(context.l10n.support('rating.title')),
              )
            else
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  5,
                  (index) => Icon(
                    index < ticket.rating!.stars
                        ? Icons.star_rounded
                        : Icons.star_border_rounded,
                    color: const Color(0xFFFFB800),
                  ),
                ),
              ),
            TextButton(
              onPressed: onNew,
              child: Text(context.l10n.support('chat.open_new')),
            ),
          ],
        ),
      ),
    );
  }
}

class _SupportConfirmSheet extends StatelessWidget {
  const _SupportConfirmSheet({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          18 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(message),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(title),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(context.l10n.support('common.cancel')),
            ),
          ],
        ),
      ),
    );
  }
}

class _SupportRatingSheet extends StatefulWidget {
  const _SupportRatingSheet();

  @override
  State<_SupportRatingSheet> createState() => _SupportRatingSheetState();
}

class _SupportRatingSheetState extends State<_SupportRatingSheet> {
  final _comment = TextEditingController();
  int _stars = 0;

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * .9,
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            20,
            20,
            20,
            18 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                context.l10n.support('rating.title'),
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 5),
              Text(context.l10n.support('rating.subtitle')),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  5,
                  (index) => IconButton(
                    onPressed: () => setState(() => _stars = index + 1),
                    iconSize: 38,
                    color: const Color(0xFFFFB800),
                    icon: Icon(
                      index < _stars
                          ? Icons.star_rounded
                          : Icons.star_border_rounded,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _comment,
                minLines: 3,
                maxLines: 5,
                maxLength: 500,
                decoration: InputDecoration(
                  hintText: context.l10n.support('rating.comment'),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _stars == 0
                    ? null
                    : () => Navigator.pop(
                        context,
                        _RatingValue(stars: _stars, comment: _comment.text),
                      ),
                child: Text(context.l10n.support('rating.submit')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RatingValue {
  const _RatingValue({required this.stars, required this.comment});

  final int stars;
  final String comment;
}

class _SupportHomeSkeleton extends StatelessWidget {
  const _SupportHomeSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 28),
      children: const [
        _SupportSkeletonBox(width: 150, height: 20),
        SizedBox(height: 12),
        _SupportSkeletonBox(height: 104),
        SizedBox(height: 22),
        _SupportSkeletonBox(height: 48),
        SizedBox(height: 14),
        Row(
          children: [
            _SupportSkeletonBox(width: 76, height: 34),
            SizedBox(width: 8),
            _SupportSkeletonBox(width: 104, height: 34),
            SizedBox(width: 8),
            _SupportSkeletonBox(width: 92, height: 34),
          ],
        ),
        SizedBox(height: 24),
        _SupportSkeletonBox(width: 170, height: 20),
        SizedBox(height: 12),
        _SupportSkeletonBox(height: 64),
        SizedBox(height: 8),
        _SupportSkeletonBox(height: 64),
        SizedBox(height: 8),
        _SupportSkeletonBox(height: 64),
      ],
    );
  }
}

class _SupportSkeletonBox extends StatelessWidget {
  const _SupportSkeletonBox({
    this.width = double.infinity,
    required this.height,
  });

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFE9EEF5),
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }
}

class _SupportBottomAction extends StatelessWidget {
  const _SupportBottomAction({
    required this.label,
    required this.onPressed,
    this.icon,
    this.loading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 8,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 14),
          child: SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton.icon(
              onPressed: loading ? null : onPressed,
              icon: loading
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Icon(icon ?? Icons.arrow_forward_rounded),
              label: Text(label),
            ),
          ),
        ),
      ),
    );
  }
}

class _SupportConnectionBanner extends StatelessWidget {
  const _SupportConnectionBanner({required this.status});

  final CustomerRealtimeStatus status;

  @override
  Widget build(BuildContext context) {
    final reconnecting =
        status == CustomerRealtimeStatus.connecting ||
        status == CustomerRealtimeStatus.authenticating ||
        status == CustomerRealtimeStatus.reconnecting;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      color: const Color(0xFFFFF8E6),
      child: Row(
        children: [
          Icon(
            reconnecting ? Icons.sync_rounded : Icons.cloud_off_outlined,
            size: 17,
            color: const Color(0xFF9A6700),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              context.l10n.support(
                reconnecting
                    ? 'chat.realtime_reconnecting'
                    : 'chat.realtime_fallback',
              ),
              style: const TextStyle(color: Color(0xFF6F4E00), fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class _SupportInlineError extends StatelessWidget {
  const _SupportInlineError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3F2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: Color(0xFFB42318)),
          const SizedBox(width: 10),
          Expanded(child: Text(context.l10n.support('common.error'))),
          TextButton(
            onPressed: onRetry,
            child: Text(context.l10n.support('common.retry')),
          ),
        ],
      ),
    );
  }
}

class _SupportUnavailable extends StatelessWidget {
  const _SupportUnavailable();

  @override
  Widget build(BuildContext context) {
    return _SupportEmpty(
      icon: Icons.support_agent_outlined,
      title: context.l10n.support('home.unavailable'),
    );
  }
}

class _SupportError extends StatelessWidget {
  const _SupportError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return _SupportEmpty(
      icon: Icons.cloud_off_outlined,
      title: context.l10n.support('common.error'),
      action: FilledButton(
        onPressed: onRetry,
        child: Text(context.l10n.support('common.retry')),
      ),
    );
  }
}

bool _isSupportUnavailable(Object error) {
  return ApiErrorInfo.fromObject(error).code == 'support_unavailable';
}

class _SupportXFilePreview extends StatelessWidget {
  const _SupportXFilePreview({
    required this.file,
    required this.width,
    required this.height,
  });

  final XFile file;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List>(
      future: file.readAsBytes(),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          return Image.memory(
            snapshot.data!,
            width: width,
            height: height,
            fit: BoxFit.cover,
            gaplessPlayback: true,
          );
        }
        return Container(
          width: width,
          height: height,
          color: const Color(0xFFF1F5F9),
          alignment: Alignment.center,
          child: snapshot.hasError
              ? const Icon(Icons.broken_image_outlined)
              : const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
        );
      },
    );
  }
}

class _SupportDateSeparator extends StatelessWidget {
  const _SupportDateSeparator({required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        DateFormat.yMMMMd(localeTag(context.l10n.locale)).format(date),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: const Color(0xFF64748B),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _SupportEmpty extends StatelessWidget {
  const _SupportEmpty({
    required this.icon,
    required this.title,
    this.action,
    this.compact = false,
  });

  final IconData icon;
  final String title;
  final Widget? action;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(
        vertical: compact ? 28 : 100,
        horizontal: 24,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: compact ? 40 : 56,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          if (action != null) ...[const SizedBox(height: 16), action!],
        ],
      ),
    );
  }
}

Color _statusColor(BuildContext context, String status) {
  return switch (status) {
    'closed' => const Color(0xFF64748B),
    'waiting_customer' => const Color(0xFFE29300),
    'assigned' || 'in_progress' => const Color(0xFF0B9B64),
    _ => Theme.of(context).colorScheme.primary,
  };
}
