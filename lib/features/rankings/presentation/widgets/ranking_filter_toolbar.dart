import 'package:flutter/material.dart';
import 'package:sakuramedia/features/rankings/data/ranking_board_dto.dart';
import 'package:sakuramedia/features/rankings/data/ranking_sort.dart';
import 'package:sakuramedia/features/rankings/data/ranking_source_dto.dart';
import 'package:sakuramedia/features/rankings/presentation/widgets/ranking_filter_sections.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_text_button.dart';

class RankingFilterToolbar extends StatefulWidget {
  const RankingFilterToolbar({
    super.key,
    required this.sources,
    required this.selectedSource,
    required this.boards,
    required this.selectedBoard,
    required this.selectedPeriod,
    required this.onSourceChanged,
    required this.onBoardChanged,
    required this.onPeriodChanged,
    required this.isLoading,
    required this.selectedSortField,
    required this.selectedSortDirection,
    required this.onSortChanged,
  });

  final List<RankingSourceDto> sources;
  final RankingSourceDto? selectedSource;
  final List<RankingBoardDto> boards;
  final RankingBoardDto? selectedBoard;
  final String? selectedPeriod;
  final ValueChanged<RankingSourceDto> onSourceChanged;
  final ValueChanged<RankingBoardDto> onBoardChanged;
  final ValueChanged<String> onPeriodChanged;
  final bool isLoading;
  final RankingSortField? selectedSortField;
  final SortDirection selectedSortDirection;
  final void Function(RankingSortField? field, SortDirection direction) onSortChanged;

  @override
  State<RankingFilterToolbar> createState() => _RankingFilterToolbarState();
}

class _RankingFilterToolbarState extends State<RankingFilterToolbar> {
  final LayerLink _layerLink = LayerLink();
  final GlobalKey _triggerKey = GlobalKey();
  OverlayEntry? _overlayEntry;
  bool _isOpen = false;
  bool _overlayRebuildScheduled = false;
  Size _triggerSize = const Size(220, 36);
  Offset _triggerOffsetInOverlay = Offset.zero;

  @override
  void didUpdateWidget(covariant RankingFilterToolbar oldWidget) {
    super.didUpdateWidget(oldWidget);
    _scheduleOverlayRebuild();
  }

  @override
  void dispose() {
    _removeOverlay(updateState: false);
    super.dispose();
  }

  void _togglePanel() {
    if (widget.isLoading) {
      return;
    }
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
    final desiredWidth = _triggerSize.width + 520;
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
              key: const Key('rankings-filter-panel'),
              width: panelWidth,
              padding: EdgeInsets.all(context.appSpacing.lg),
              decoration: BoxDecoration(
                color: context.appColors.surfaceCard,
                borderRadius: context.appRadius.mdBorder,
                border: Border.all(color: context.appColors.borderSubtle),
                boxShadow: context.appShadows.panel,
              ),
              child: RankingFilterSectionGroup(
                sources: widget.sources,
                selectedSource: widget.selectedSource,
                boards: widget.boards,
                selectedBoard: widget.selectedBoard,
                selectedPeriod: widget.selectedPeriod,
                onSourceChanged: widget.onSourceChanged,
                onBoardChanged: widget.onBoardChanged,
                onPeriodChanged: widget.onPeriodChanged,
                selectedSortField: widget.selectedSortField,
                selectedSortDirection: widget.selectedSortDirection,
                onSortChanged: widget.onSortChanged,
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final label = _buildTriggerLabel();
    return CompositedTransformTarget(
      link: _layerLink,
      child: AppTextButton(
        key: _triggerKey,
        label: label,
        labelKey: const Key('rankings-filter-trigger-label'),
        icon: const Icon(Icons.filter_alt_outlined),
        trailingIcon: Icon(_isOpen ? Icons.expand_less : Icons.expand_more),
        size: AppTextButtonSize.small,
        isSelected: _isOpen,
        onPressed: _togglePanel,
      ),
    );
  }

  String _buildTriggerLabel() {
    final sourceLabel = widget.selectedSource?.name ?? '全部来源';
    final boardLabel = widget.selectedBoard?.name ?? '全部榜单';
    final periodLabel =
        widget.selectedPeriod == null
            ? '默认周期'
            : rankingPeriodLabel(widget.selectedPeriod!);
    return '$sourceLabel / $boardLabel / $periodLabel';
  }
}

