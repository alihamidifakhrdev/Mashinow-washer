import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mashinow_washer/core/extensions/build_context.dart';
import 'package:mashinow_washer/core/extensions/string.dart';
import 'package:mashinow_washer/core/formatters/formatters.dart';
import 'package:mashinow_washer/core/models/api_models.dart';
import 'package:mashinow_washer/core/presentation/widgets/view_state.dart';
import 'package:mashinow_washer/features/dashboard/dashboard_providers.dart';

/// Customer ratings for the washer's car wash.
class RatingsPage extends ConsumerWidget {
  const RatingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final types = context.types;

    final carWashAsync = ref.watch(carWashProfileProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'نظرات مشتریان',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
        ),
        centerTitle: true,
      ),
      body: carWashAsync.when(
        loading: () => const PageLoading(),
        error: (error, _) => ViewState<CarWash>(
          loading: false,
          error: error,
          onRetry: () => ref.refresh(carWashProfileProvider.future),
          builder: (_) => const SizedBox.shrink(),
        ),
        data: (carWash) {
          final ratingsAsync = ref.watch(ratingsProvider(carWash.id));

          return ratingsAsync.when(
            loading: () => const PageLoading(),
            error: (error, _) => ViewState<List<CarWashRating>>(
              loading: false,
              error: error,
              onRetry: () => ref.refresh(ratingsProvider(carWash.id).future),
              builder: (_) => const SizedBox.shrink(),
            ),
            data: (ratings) {
              if (ratings.isEmpty) {
                return ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: const [
                    SizedBox(height: 100),
                    _NoRatings(),
                  ],
                );
              }

              final average = ratings.fold<int>(0, (sum, r) => sum + r.rating) /
                  ratings.length;

              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                children: [
                  // :: AVERAGE
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: colors.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          average.toStringAsFixed(1).toPersianDigits(),
                          style: types.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: const Color(0xfff59e0b),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.star_rounded,
                            color: Color(0xfff59e0b), size: 34),
                        const SizedBox(width: 8),
                        Text(
                          'از ${ratings.length.toString().toPersianDigits()} نظر',
                          style:
                              types.bodySmall?.copyWith(color: colors.outline),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // :: LIST
                  ...ratings.map(
                    (rating) => Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: colors.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              ...List.generate(5, (index) {
                                return Icon(
                                  index < rating.rating
                                      ? Icons.star_rounded
                                      : Icons.star_outline_rounded,
                                  size: 18,
                                  color: const Color(0xfff59e0b),
                                );
                              }),
                              const Spacer(),
                              Text(
                                Formatter.jalaliDate(rating.createdAt),
                                style: types.bodySmall
                                    ?.copyWith(color: colors.outline),
                              ),
                            ],
                          ),
                          if ((rating.comment ?? '').isNotEmpty) ...[
                            const SizedBox(height: 10),
                            Text(
                              rating.comment!,
                              style: types.bodyMedium?.copyWith(height: 1.7),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _NoRatings extends StatelessWidget {
  const _NoRatings();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final types = context.types;

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: colors.surfaceContainerHigh,
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.star_outline_rounded,
              size: 44, color: colors.outline),
        ),
        const SizedBox(height: 14),
        Text(
          'هنوز نظری ثبت نشده',
          style: types.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        Text(
          'بعد از هر رزرو، مشتری می‌تواند امتیاز و نظر خود را ثبت کند.',
          textAlign: TextAlign.center,
          style: types.bodySmall?.copyWith(color: colors.outline),
        ),
      ],
    );
  }
}
