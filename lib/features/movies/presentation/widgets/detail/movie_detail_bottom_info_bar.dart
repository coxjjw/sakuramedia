import 'package:flutter/material.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/features/movies/presentation/widgets/detail/movie_detail_stat_row.dart';

enum MovieDetailBottomInfoBarVariant { desktopCard, mobileFullWidth }

class MovieDetailBottomInfoBar extends StatelessWidget {
  const MovieDetailBottomInfoBar({
    super.key,
    required this.items,
    required this.onTap,
    this.variant = MovieDetailBottomInfoBarVariant.desktopCard,
  });

  final List<MovieDetailStatItem> items;
  final VoidCallback onTap;
  final MovieDetailBottomInfoBarVariant variant;

  @override
  Widget build(BuildContext context) {
    final isMobile = variant == MovieDetailBottomInfoBarVariant.mobileFullWidth;
    final borderRadius =
        isMobile
            ? BorderRadius.vertical(top: context.appRadius.smBorder.topLeft)
            : context.appRadius.xsBorder;
    final decoration =
        isMobile
            ? BoxDecoration(
              borderRadius: borderRadius,
              boxShadow: context.appShadows.card,
            )
            : BoxDecoration(
              borderRadius: context.appRadius.smBorder,
              border: Border.all(color: context.appColors.borderSubtle),
            );

    return Material(
      key: const Key('movie-detail-fixed-info-bar'),
      color: context.appColors.surfaceCard,
      borderRadius: borderRadius,
      child: InkWell(
        onTap: onTap,
        borderRadius: borderRadius,
        child: Container(
          width: double.infinity,
          constraints: BoxConstraints(
            minHeight: context.appComponentTokens.movieDetailBottomBarMinHeight,
          ),
          padding: EdgeInsets.symmetric(
            horizontal: context.appSpacing.sm,
            vertical: 0,
          ),
          decoration: decoration,
          child: Row(
            children: [
              Expanded(child: MovieDetailStatRow(items: items)),
              SizedBox(width: context.appSpacing.sm),
              Container(
                width: 1,
                height: context.appComponentTokens.iconSizeXs,
                color: context.appColors.borderSubtle,
              ),
              SizedBox(width: context.appSpacing.sm),
              Icon(
                Icons.chevron_right_rounded,
                size: context.appComponentTokens.iconSizeSm,
                color: context.appTextPalette.muted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
