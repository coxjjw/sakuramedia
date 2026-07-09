import 'package:flutter/material.dart';
import 'package:sakuramedia/features/actors/presentation/controllers/listing/actor_filter_state.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_button.dart';
import 'package:sakuramedia/widgets/base/actions/app_text_button.dart';
import 'package:sakuramedia/widgets/domain/actors/actor_filter_sections.dart';

class ActorFilterToolbar extends StatefulWidget {
  const ActorFilterToolbar({
    super.key,
    required this.filterState,
    required this.onChanged,
    required this.onReset,
  });

  final ActorFilterState filterState;
  final ValueChanged<ActorFilterState> onChanged;
  final VoidCallback onReset;

  @override
  State<ActorFilterToolbar> createState() => _ActorFilterToolbarState();
}

class _ActorFilterToolbarState extends State<ActorFilterToolbar> {
  final LayerLink _layerLink = LayerLink();
  final GlobalKey _triggerKey = GlobalKey();
  OverlayEntry? _overlayEntry;
  bool _isOpen = false;
  bool _overlayRebuildScheduled = false;
  Size _triggerSize = const Size(160, 36);
  Offset _triggerOffsetInOverlay = Offset.zero;

  @override
  void didUpdateWidget(covariant ActorFilterToolbar oldWidget) {
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
    final desiredWidth = _triggerSize.width + 180;
    final panelWidth =
        desiredWidth.clamp(_triggerSize.width, overlayWidth).toDouble();
    final leftSpace = _triggerOffsetInOverlay.dx;
    final rightAlignedOffset =
        -((panelWidth - _triggerSize.width).clamp(0, leftSpace)).toDouble();

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
          offset: Offset(rightAlignedOffset, _triggerSize.height + 8),
          child: Material(
            color: Colors.transparent,
            child: Container(
              key: const Key('actors-filter-panel'),
              width: panelWidth,
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
                  ActorFilterSectionGroup(
                    filterState: widget.filterState,
                    onChanged: widget.onChanged,
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
    return CompositedTransformTarget(
      link: _layerLink,
      child: AppTextButton(
        key: _triggerKey,
        label: widget.filterState.triggerLabel,
        labelKey: const Key('actors-filter-trigger-label'),
        icon: const Icon(Icons.filter_alt_outlined),
        trailingIcon: Icon(_isOpen ? Icons.expand_less : Icons.expand_more),
        size: AppTextButtonSize.small,
        isSelected: !widget.filterState.isDefault || _isOpen,
        onPressed: _togglePanel,
      ),
    );
  }
}

