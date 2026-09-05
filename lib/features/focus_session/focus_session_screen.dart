import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:go_router/go_router.dart';
import 'package:project_app_lock/data/lock_session_model.dart';
import 'package:project_app_lock/data/study_content_model.dart';
import 'package:project_app_lock/dependency/dependency_manager.dart';
import 'package:project_app_lock/features/focus_session/focus_session_store.dart';
import 'package:project_app_lock/features/focus_session/study_attempt_store.dart';

class FocusSessionScreen extends StatefulWidget {
  const FocusSessionScreen({super.key});

  @override
  State<FocusSessionScreen> createState() => _FocusSessionScreenState();
}

class _FocusSessionScreenState extends State<FocusSessionScreen> {
  late final FocusSessionStore _focusStore;
  late final StudyAttemptStore _attemptStore;
  final TextEditingController _responseController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _focusStore = sl<FocusSessionStore>()..initialize();
    _attemptStore = sl<StudyAttemptStore>()..initialize();
    _responseController.addListener(
      () => _attemptStore.setResponseDraft(_responseController.text),
    );
  }

  @override
  void dispose() {
    _responseController.dispose();
    super.dispose();
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return hours > 0 ? '$hours:$minutes:$seconds' : '$minutes:$seconds';
  }

  Future<void> _completeLegacy() async {
    if (await _focusStore.completeActiveTask() && mounted) {
      context.goNamed('tasks');
    }
  }

  Future<void> _completeStudy() async {
    if (await _attemptStore.completeAndUnlock() && mounted) {
      context.goNamed('tasks');
    }
  }

  @override
  Widget build(BuildContext context) => Observer(
    builder: (context) {
      final session = _focusStore.activeSession;
      if (session == null) {
        return _focusStore.lastSessionExpired
            ? const _ExpiredSession()
            : const _NoSession();
      }
      final isTaskScreenLocked = session.policy?.lockToTaskScreen ?? false;
      final canPop = session.policy?.backButtonEnabled ?? true;
      return PopScope(
        canPop: canPop,
        child: Scaffold(
          appBar: AppBar(
            title: Text(session.taskTitle),
            automaticallyImplyLeading: !isTaskScreenLocked,
          ),
          body: SafeArea(
            child: CustomScrollView(
              slivers: <Widget>[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: _SessionHeader(
                      remaining: _focusStore.remaining,
                      total: session.endsAt.difference(session.startedAt),
                      formattedRemaining: _formatDuration(
                        _focusStore.remaining,
                      ),
                      packageCount: session.packageIds.length,
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                  sliver: SliverToBoxAdapter(
                    child: _AttemptBody(
                      attemptStore: _attemptStore,
                      responseController: _responseController,
                      onLegacyComplete: _completeLegacy,
                      onStudyComplete: _completeStudy,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

class _AttemptBody extends StatelessWidget {
  const _AttemptBody({
    required this.attemptStore,
    required this.responseController,
    required this.onLegacyComplete,
    required this.onStudyComplete,
  });

  final StudyAttemptStore attemptStore;
  final TextEditingController responseController;
  final VoidCallback onLegacyComplete;
  final VoidCallback onStudyComplete;

  @override
  Widget build(BuildContext context) => Observer(
    builder: (context) {
      if (attemptStore.isLoading) return const _LoadingBody();
      if (attemptStore.errorMessage != null) {
        return _StudyMessage(
          icon: Icons.error_outline,
          message: attemptStore.errorMessage!,
          action: attemptStore.hasInvalidProgress
              ? FilledButton.icon(
                  onPressed: attemptStore.focusSessionStore.isBusy
                      ? null
                      : () {
                          attemptStore.focusSessionStore.endActiveSession();
                        },
                  icon: const Icon(Icons.lock_open_outlined),
                  label: const Text('End session and unlock'),
                )
              : TextButton(
                  onPressed: attemptStore.initialize,
                  child: const Text('Try again'),
                ),
        );
      }
      if (attemptStore.isLegacySession ||
          attemptStore.focusSessionStore.needsUnlockRetry) {
        return _LegacyCompletion(
          isBusy: attemptStore.focusSessionStore.isBusy,
          needsUnlockRetry: attemptStore.focusSessionStore.needsUnlockRetry,
          onComplete: onLegacyComplete,
          onRetry: attemptStore.focusSessionStore.retryUnlock,
        );
      }
      final content = attemptStore.studyContent;
      if (content == null) {
        return const _StudyMessage(
          icon: Icons.menu_book_outlined,
          message: 'This session has no study content to restore.',
        );
      }
      if (attemptStore.isSummary) {
        return _StudySummary(
          correctCount: attemptStore.correctCount,
          needsReviewCount: attemptStore.needsReviewCount,
          isBusy:
              attemptStore.isSaving || attemptStore.focusSessionStore.isBusy,
          canComplete: attemptStore.canComplete,
          onComplete: onStudyComplete,
        );
      }
      final item = attemptStore.currentItem;
      if (item == null) {
        return const _StudyMessage(
          icon: Icons.error_outline,
          message: 'Could not find the current study item.',
        );
      }
      final response = attemptStore.currentResponse;
      if (responseController.text.isEmpty &&
          attemptStore.responseDraft.isNotEmpty) {
        responseController.value = TextEditingValue(
          text: attemptStore.responseDraft,
          selection: TextSelection.collapsed(
            offset: attemptStore.responseDraft.length,
          ),
        );
      }
      return _StudyItemCard(
        format: content.format,
        item: item,
        itemNumber: attemptStore.currentItemIndex + 1,
        totalItems: content.items.length,
        responseController: responseController,
        isRevealed: response?.isRevealed ?? false,
        isSaving: attemptStore.isSaving,
        canReveal: attemptStore.canReveal,
        canAssess: attemptStore.canAssess,
        onReveal: attemptStore.revealAnswer,
        onCorrect: () => attemptStore.assess(StudyAssessment.correct),
        onNeedsReview: () => attemptStore.assess(StudyAssessment.needsReview),
      );
    },
  );
}

class _StudyItemCard extends StatelessWidget {
  const _StudyItemCard({
    required this.format,
    required this.item,
    required this.itemNumber,
    required this.totalItems,
    required this.responseController,
    required this.isRevealed,
    required this.isSaving,
    required this.canReveal,
    required this.canAssess,
    required this.onReveal,
    required this.onCorrect,
    required this.onNeedsReview,
  });

  final StudyFormat format;
  final StudyItemModel item;
  final int itemNumber;
  final int totalItems;
  final TextEditingController responseController;
  final bool isRevealed;
  final bool isSaving;
  final bool canReveal;
  final bool canAssess;
  final Future<bool> Function() onReveal;
  final Future<bool> Function() onCorrect;
  final Future<bool> Function() onNeedsReview;

  @override
  Widget build(BuildContext context) {
    final isQuiz = format == StudyFormat.quiz;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        LinearProgressIndicator(value: itemNumber / totalItems),
        const SizedBox(height: 8),
        Text(
          '${isQuiz ? 'Question' : 'Card'} $itemNumber of $totalItems',
          style: Theme.of(context).textTheme.labelLarge,
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(
                  isQuiz ? 'Question' : 'Front',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  item.prompt,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: responseController,
                  enabled: !isRevealed && !isSaving,
                  minLines: 2,
                  maxLines: 4,
                  decoration: InputDecoration(
                    labelText: isQuiz ? 'Your answer' : 'Your recall',
                    hintText: 'Type your response before revealing the answer',
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                if (!isRevealed)
                  FilledButton(
                    onPressed: canReveal
                        ? () {
                            onReveal();
                          }
                        : null,
                    child: isSaving
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(),
                          )
                        : const Text('Reveal answer'),
                  )
                else ...<Widget>[
                  Text(
                    isQuiz ? 'Expected answer' : 'Back',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    item.answer,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'How did you do?',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: <Widget>[
                      FilledButton.tonalIcon(
                        onPressed: canAssess
                            ? () {
                                onNeedsReview();
                              }
                            : null,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Needs review'),
                      ),
                      FilledButton.icon(
                        onPressed: canAssess
                            ? () {
                                onCorrect();
                              }
                            : null,
                        icon: const Icon(Icons.check),
                        label: const Text('Correct'),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _StudySummary extends StatelessWidget {
  const _StudySummary({
    required this.correctCount,
    required this.needsReviewCount,
    required this.isBusy,
    required this.canComplete,
    required this.onComplete,
  });
  final int correctCount;
  final int needsReviewCount;
  final bool isBusy;
  final bool canComplete;
  final VoidCallback onComplete;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Icon(
            Icons.emoji_events_outlined,
            size: 48,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 16),
          Text(
            'Study complete',
            style: Theme.of(context).textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            '$correctCount correct · $needsReviewCount needs review',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: canComplete && !isBusy ? onComplete : null,
            icon: const Icon(Icons.lock_open_outlined),
            label: const Text('Complete task and unlock'),
          ),
        ],
      ),
    ),
  );
}

class _LegacyCompletion extends StatelessWidget {
  const _LegacyCompletion({
    required this.isBusy,
    required this.needsUnlockRetry,
    required this.onComplete,
    required this.onRetry,
  });
  final bool isBusy;
  final bool needsUnlockRetry;
  final VoidCallback onComplete;
  final Future<bool> Function() onRetry;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const Icon(Icons.lock_clock_outlined, size: 48),
          const SizedBox(height: 16),
          Text(
            needsUnlockRetry
                ? 'Unlocking needs to be retried.'
                : 'Finish this legacy focus session to unlock.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: isBusy
                ? null
                : needsUnlockRetry
                ? () {
                    onRetry();
                  }
                : onComplete,
            icon: Icon(needsUnlockRetry ? Icons.refresh : Icons.task_alt),
            label: Text(
              needsUnlockRetry ? 'Retry unlock' : 'Complete task and unlock',
            ),
          ),
        ],
      ),
    ),
  );
}

class _SessionHeader extends StatelessWidget {
  const _SessionHeader({
    required this.remaining,
    required this.total,
    required this.formattedRemaining,
    required this.packageCount,
  });
  final Duration remaining;
  final Duration total;
  final String formattedRemaining;
  final int packageCount;

  @override
  Widget build(BuildContext context) {
    final progress = total.inMilliseconds <= 0
        ? 0.0
        : (remaining.inMilliseconds / total.inMilliseconds).clamp(0.0, 1.0);
    return Row(
      children: <Widget>[
        SizedBox.square(
          dimension: 88,
          child: Stack(
            alignment: Alignment.center,
            children: <Widget>[
              CircularProgressIndicator(value: progress, strokeWidth: 8),
              Text(
                formattedRemaining,
                style: Theme.of(context).textTheme.labelLarge,
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            '$packageCount app${packageCount == 1 ? '' : 's'} locked',
          ),
        ),
      ],
    );
  }
}

class _NoSession extends StatelessWidget {
  const _NoSession();
  @override
  Widget build(BuildContext context) => const Scaffold(
    body: _StudyMessage(
      icon: Icons.timer_off_outlined,
      message: 'There is no active focus session.',
    ),
  );
}

class _ExpiredSession extends StatelessWidget {
  const _ExpiredSession();
  @override
  Widget build(BuildContext context) => const Scaffold(
    body: _StudyMessage(
      icon: Icons.timer_off_outlined,
      message: 'Time expired. Your task was not marked complete.',
    ),
  );
}

class _LoadingBody extends StatelessWidget {
  const _LoadingBody();
  @override
  Widget build(BuildContext context) => const Center(
    child: Padding(
      padding: EdgeInsets.all(32),
      child: CircularProgressIndicator(),
    ),
  );
}

class _StudyMessage extends StatelessWidget {
  const _StudyMessage({required this.icon, required this.message, this.action});
  final IconData icon;
  final String message;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 48),
          const SizedBox(height: 16),
          Text(message, textAlign: TextAlign.center),
          if (action != null) ...<Widget>[const SizedBox(height: 8), action!],
        ],
      ),
    ),
  );
}
