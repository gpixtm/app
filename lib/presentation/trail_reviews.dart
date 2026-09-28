import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../application/app_controller.dart';
import '../domain/models.dart';
import '../domain/shared_trails.dart';
import 'design.dart';
import 'localization.dart';

/// Stars of an average rating, halves included.
class RatingStars extends StatelessWidget {
  const RatingStars(this.rating, {this.size = 18, super.key});
  final double rating;
  final double size;
  @override
  Widget build(BuildContext context) => Semantics(
    label: context.l10n.averageRating(
      NumberFormat('0.#', context.l10n.localeName).format(rating),
    ),
    excludeSemantics: true,
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var star = 1; star <= 5; star++)
          Icon(
            rating >= star
                ? Icons.star_rounded
                : rating >= star - .5
                ? Icons.star_half_rounded
                : Icons.star_outline_rounded,
            size: size,
            color: const Color(0xffe0a100),
          ),
      ],
    ),
  );
}

/// Average and count of a shared trail's reviews, compact enough for lists.
class RatingSummary extends StatelessWidget {
  const RatingSummary({required this.count, this.average, super.key});
  final int count;
  final double? average;
  @override
  Widget build(BuildContext context) {
    final value = average;
    if (count == 0 || value == null) return Text(context.l10n.noReviewsYet);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          NumberFormat('0.0', context.l10n.localeName).format(value),
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(width: 4),
        RatingStars(value),
        const SizedBox(width: 6),
        Text(context.l10n.reviewCount(count)),
      ],
    );
  }
}

/// Reviews of the trail shown in the map panel. Anyone reads them, offline
/// from the last copy; only walkers who recorded the whole trail write one.
class TrailReviewsSection extends StatelessWidget {
  const TrailReviewsSection(this.app, this.trail, {super.key});
  final AppController app;
  final Trail trail;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final reviews = app.reviews?.trailId == trail.sharedId ? app.reviews : null;
    final shared = app.sharedFor(trail);
    return Column(
      key: const ValueKey('trail-reviews'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 28),
        Row(
          children: [
            Expanded(
              child: Text(
                l10n.reviews,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            if (app.reviewsLoading)
              const SizedBox.square(
                dimension: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
          ],
        ),
        if (shared?.author case final author?)
          Text(
            l10n.sharedBy(author),
            style: const TextStyle(fontSize: 12, color: Color(0xff627068)),
          ),
        const SizedBox(height: 6),
        if (reviews == null)
          if (app.reviewsError case final error?)
            Text(context.message(error))
          else if (shared != null)
            RatingSummary(count: shared.reviews, average: shared.average)
          else
            const SizedBox.shrink()
        else ...[
          RatingSummary(count: reviews.count, average: reviews.average),
          if (reviews.cached)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                l10n.reviewsOffline,
                style: const TextStyle(fontSize: 12),
              ),
            ),
          const SizedBox(height: 8),
          if (reviews.canReview)
            FilledButton.tonalIcon(
              onPressed: app.busy || reviews.cached
                  ? null
                  : () => _edit(context, reviews.mine),
              icon: const Icon(Icons.rate_review_outlined),
              label: Text(
                reviews.mine == null ? l10n.writeReview : l10n.editReview,
              ),
            )
          else ...[
            Text(l10n.reviewCompletionRequired),
            if (reviews.completion case final completion?)
              Text(
                l10n.reviewProgress((completion * 100).floor()),
                style: const TextStyle(fontSize: 12),
              ),
          ],
          for (final review in reviews.reviews) _ReviewTile(review),
          if (reviews.mine != null && !reviews.cached)
            TextButton.icon(
              onPressed: app.busy ? null : () => _delete(context),
              icon: const Icon(Icons.delete_outline),
              label: Text(l10n.deleteMyReview),
            ),
        ],
      ],
    );
  }

  Future<void> _edit(BuildContext context, TrailReview? current) async {
    final result = await showDialog<(int, String)>(
      context: context,
      builder: (_) => ReviewDialog(current: current),
    );
    if (result case (final rating, final comment)) {
      await app.saveReview(rating, comment);
    }
  }

  Future<void> _delete(BuildContext context) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(context.l10n.deleteReviewQuestion),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: Text(context.l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: Text(context.l10n.delete),
          ),
        ],
      ),
    );
    if (yes == true) await app.deleteReview();
  }
}

class _ReviewTile extends StatelessWidget {
  const _ReviewTile(this.review);
  final TrailReview review;
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final author = review.mine ? l10n.you : review.author ?? l10n.formerWalker;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              RatingStars(review.rating.toDouble(), size: 15),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '$author · ${DateFormat.yMMMd(l10n.localeName).format(review.updatedAt.toLocal())}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xff627068),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          if (review.comment.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(review.comment),
            ),
        ],
      ),
    );
  }
}

/// Stars and optional comment; returns them, or null when cancelled.
class ReviewDialog extends StatefulWidget {
  const ReviewDialog({this.current, super.key});
  final TrailReview? current;
  @override
  State<ReviewDialog> createState() => _ReviewDialogState();
}

class _ReviewDialogState extends State<ReviewDialog> {
  late int rating = widget.current?.rating ?? 0;
  late final comment = TextEditingController(text: widget.current?.comment);
  @override
  void dispose() {
    comment.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.reviewDialogTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var star = 1; star <= 5; star++)
                  IconButton(
                    tooltip: l10n.giveRating(star),
                    isSelected: star <= rating,
                    onPressed: () => setState(() => rating = star),
                    icon: const Icon(
                      Icons.star_outline_rounded,
                      color: Color(0xffe0a100),
                    ),
                    selectedIcon: const Icon(
                      Icons.star_rounded,
                      color: Color(0xffe0a100),
                    ),
                  ),
              ],
            ),
            TextField(
              controller: comment,
              maxLength: maximumReviewLength,
              minLines: 2,
              maxLines: 6,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(labelText: l10n.reviewComment),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: forest,
            minimumSize: const Size(48, 44),
          ),
          onPressed: rating == 0
              ? null
              : () => Navigator.pop(context, (rating, comment.text)),
          child: Text(l10n.publish),
        ),
      ],
    );
  }
}
