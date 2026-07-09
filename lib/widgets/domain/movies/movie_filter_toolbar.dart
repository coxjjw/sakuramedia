import 'package:flutter/material.dart';
import 'package:sakuramedia/features/movies/presentation/controllers/listing/movie_filter_state.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_button.dart';
import 'package:sakuramedia/widgets/base/actions/app_text_button.dart';
import 'package:sakuramedia/widgets/domain/movies/movie_filter_sections.dart';

class MovieFilterToolbar extends StatefulWidget {
  const MovieFilterToolbar({
    super.key,
    required this.filterState,
    required this.onChanged,
    required this.onReset,
    this.yearOptions = const <MovieFilterYearOption>[],
    this.isYearOptionsLoading = false,
    this.yearOptionsErrorMessage,
    this.onYearOptionsRetry,
    this.onOpened,
  });

  final MovieFilterState filterState;
  final ValueChanged<MovieFilterState> onChanged;
  final VoidCallback onReset;
  final List<MovieFilterYearOption> yearOptions;
  final bool isYearOptionsLoading;
  final String? yearOptionsErrorMessage;
  final VoidCallback? onYearOptionsRetry;
  final VoidCallback? onOpened;

  @override
  State<MovieFilterToolbar> createState() => _MovieFilterToolbarState();
}

class _MovieFilterToolbarState extends State<MovieFilterToolbar> {
  final LayerLink _layerLink = LayerLink();
  final GlobalKey _triggerKey = GlobalKey();
  OverlayEntry? _overlayEntry;
  bool _isOpen = false;
  bool _overlayRebuildScheduled = false;
  Size _triggerSize = const Size(160, 36);
  Offset _triggerOffsetInOverlay = Offset.zero;

  @override
  void didUpdateWidget(covariant MovieFilterToolbar oldWidget) {
    super.didUpdateWidget(oldWidget);
    _scheduleOverlayRebuild();
  }

  @override
  void dispose() {
    _removeOverlay(updateState: false);
    super.dispose();
  }

  void _togglePanel() {
    if (_isOpen) {
      _removeOverlay();
    } else {
      _showOverlay();
    }
  }

  void _showOverlay() {
    widget.onOpened?.call();
    _updateTriggerMetrics();
    _isOpen = true;
    _overlayEntry = OverlayEntry(
      builder: (overlayContext) => _buildOverlay(overlayContext),
    );
    Overlay.of(context).insert(_overlayEntry!);
    if (mounted) {
      setState(() {});
    }
  }

  void _scheduleOverlayRebuild() {
    if (!_isOpen || _overlayEntry == null || _overlayRebuildScheduled) {
      return;
    }
    _overlayRebuildScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _overlayRebuildScheduled = false;
      if (!mounted || !_isOpen) {
        return;
      }
      _overlayEntry?.markNeedsBuild();
    });
  }

  void _updateTriggerMetrics() {
    final triggerBox =
        _triggerKey.currentContext?.findRenderObject() as RenderBox?;
    if (triggerBox != null) {
      _triggerSize = triggerBox.size;
    }
  }

  RenderBox? _updateTriggerMetricsForOverlay(BuildContext overlayContext) {
    final triggerBox =
        _triggerKey.currentContext?.findRenderObject() as RenderBox?;
    final overlayState = Overlay.maybeOf(overlayContext);
    final overlayBox = overlayState?.context.findRenderObject() as RenderBox?;

    if (triggerBox != null) {
      _triggerSize = triggerBox.size;
    }
    if (triggerBox != null && overlayBox != null) {
      _triggerOffsetInOverlay = triggerBox.localToGlobal(
        Offset.zero,
        ancestor: overlayBox,
      );
    }
    return overlayBox;
  }

  void _removeOverlay({bool updateState = true}) {
    _overlayEntry?.remove();
    _overlayEntry = null;
    _overlayRebuildScheduled = false;
    if (updateState && _isOpen && mounted) {
      setState(() {
        _isOpen = false;
      });
      return;
    }
    _isOpen = false;
  }

  Widget _buildOverlay(BuildContext overlayContext) {
    final overlayBox = _updateTriggerMetricsForOverlay(overlayContext);
    final mediaQuery = MediaQuery.of(overlayContext);
    final overlayWidth = overlayBox?.size.width ?? mediaQuery.size.width;
    final desiredWidth = _triggerSize.width + 260;
    final panelWidth =
        desiredWidth.clamp(_triggerSize.width, overlayWidth).toDouble();
    final leftSpace = _triggerOffsetInOverlay.dx;
    final rightAlignedOffset =
        -((panelWidth - _triggerSize.width).clamp(0, leftSpace)).toDouble();
    const panelVerticalGap = 8.0;
    final overlayHeight = overlayBox?.size.height ?? mediaQuery.size.height;
    final panelTop =
        _triggerOffsetInOverlay.dy + _triggerSize.height + panelVerticalGap;
    final bottomMargin = mediaQuery.padding.bottom + context.appSpacing.lg;
    final safeOverlayHeight =
        (overlayHeight - bottomMargin).clamp(1.0, overlayHeight).toDouble();
    final availablePanelHeight = safeOverlayHeight - panelTop;
    final maxPanelHeight =
        availablePanelHeight > 0 ? availablePanelHeight : safeOverlayHeight;

    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: _removeOverlay,
            child: const SizedBox.expand(),
          ),
        ),
        CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: Offset(
            rightAlignedOffset,
            _triggerSize.height + panelVerticalGap,
          ),
          child: Material(
            color: Colors.transparent,
            child: Container(
              key: const Key('movies-filter-panel'),
              width: panelWidth,
              constraints: BoxConstraints(maxHeight: maxPanelHeight),
              padding: EdgeInsets.all(context.appSpacing.lg),
              decoration: BoxDecoration(
                color: context.appColors.surfaceCard,
                borderRadius: context.appRadius.mdBorder,
                border: Border.all(color: context.appColors.borderSubtle),
                boxShadow: context.appShadows.panel,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Flexible(
                    child: SingleChildScrollView(
                      key: const Key('movies-filter-scroll-view'),
                      child: MovieFilterSectionGroup(
                        filterState: widget.filterState,
                        onChanged: widget.onChanged,
                        yearOptions: widget.yearOptions,
                        isYearOptionsLoading: widget.isYearOptionsLoading,
                        yearOptionsErrorMessage: widget.yearOptionsErrorMessage,
                        onYearOptionsRetry: widget.onYearOptionsRetry,
                      ),
                    ),
                  ),
                  SizedBox(height: context.appSpacing.lg),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        widget.filterState.isDefault ? '当前使用默认筛选' : '筛选已即时生效',
                        style: resolveAppTextStyle(
                          context,
                          size: AppTextSize.s12,
                          weight: AppTextWeight.regular,
                          tone: AppTextTone.muted,
                        ),
                      ),
                      AppButton(
                        label: '重置',
                        size: AppButtonSize.xSmall,
                        variant: AppButtonVariant.secondary,
                        onPressed:
                            widget.filterState.isDefault
                                ? null
                                : widget.onReset,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDefaultSelection = widget.filterState.isDefault;
    final isPresetSelection = MovieFilterPreset.values.any(
      widget.filterState.matchesPreset,
    );
    final isCustomSelection = !isDefaultSelection && !isPresetSelection;

    return Wrap(
      spacing: context.appSpacing.sm,
      runSpacing: context.appSpacing.sm,
      children: [
        CompositedTransformTarget(
          link: _layerLink,
          child: AppTextButton(
            key: _triggerKey,
            label: widget.filterState.triggerLabel,
            labelKey: const Key('movies-filter-trigger-label'),
            icon: const Icon(Icons.filter_alt_outlined),
            trailingIcon: Icon(_isOpen ? Icons.expand_less : Icons.expand_more),
            size: AppTextButtonSize.small,
            isSelected: isDefaultSelection || isCustomSelection,
            onPressed: _togglePanel,
          ),
        ),
        for (final preset in MovieFilterPreset.values)
          AppTextButton(
            key: Key('movies-filter-preset-${preset.key}'),
            label: preset.label,
            size: AppTextButtonSize.small,
            isSelected: widget.filterState.matchesPreset(preset),
            onPressed: () => widget.onChanged(preset.filterState),
          ),
      ],
    );
  }
}

