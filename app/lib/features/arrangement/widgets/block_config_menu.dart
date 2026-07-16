// AI-Generate
import 'package:domain/domain.dart';
import 'package:flutter/material.dart';

typedef BlockConfigChanged = void Function(int repeatN, double silenceFactor);

/// 積木設定浮層內容（frontend-design 功能點 13、REQ-15/AT-15-04～06）。
///
/// 兩個 stepper 共用同一份暫存值；每次調整立即回傳，超出 Domain 邊界時
/// 直接 disabled，讓已輸入值不會因錯誤而被清空。
class BlockConfigMenu extends StatefulWidget {
  const BlockConfigMenu({
    super.key,
    required this.initialRepeatN,
    required this.initialSilenceFactor,
    required this.onChanged,
    this.title = '積木設定',
    this.keyPrefix = 'block',
    this.resetRepeatN = PracticeBlock.defaultRepeatN,
    this.resetSilenceFactor = PracticeBlock.defaultSilenceFactor,
    this.previewLabel = '預覽積木',
    this.onPreview,
    this.onReset,
  });

  final int initialRepeatN;
  final double initialSilenceFactor;
  final BlockConfigChanged onChanged;
  final String title;
  final String keyPrefix;
  final int resetRepeatN;
  final double resetSilenceFactor;
  final String previewLabel;
  final VoidCallback? onPreview;
  final VoidCallback? onReset;

  @override
  State<BlockConfigMenu> createState() => _BlockConfigMenuState();
}

class _BlockConfigMenuState extends State<BlockConfigMenu> {
  late int _repeatN = widget.initialRepeatN;
  late double _silenceFactor = widget.initialSilenceFactor;

  void _update({int? repeatN, double? silenceFactor}) {
    setState(() {
      _repeatN = repeatN ?? _repeatN;
      _silenceFactor = silenceFactor ?? _silenceFactor;
    });
    widget.onChanged(_repeatN, _silenceFactor);
  }

  void _reset() {
    setState(() {
      _repeatN = widget.resetRepeatN;
      _silenceFactor = widget.resetSilenceFactor;
    });
    if (widget.onReset != null) {
      widget.onReset!();
    } else {
      widget.onChanged(_repeatN, _silenceFactor);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canRepeatDown = _repeatN > PracticeBlock.minRepeatN;
    final canRepeatUp = _repeatN < PracticeBlock.maxRepeatN;
    final canSilenceDown = _silenceFactor > PracticeBlock.minSilenceFactor;
    final canSilenceUp = _silenceFactor < PracticeBlock.maxSilenceFactor;

    return Column(
      key: ValueKey('${widget.keyPrefix}-config-menu'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        _StepperRow(
          label: '重複次數',
          valueKey: ValueKey('${widget.keyPrefix}-repeat-value'),
          value: '$_repeatN 次',
          decrementKey: ValueKey('${widget.keyPrefix}-repeat-decrement'),
          incrementKey: ValueKey('${widget.keyPrefix}-repeat-increment'),
          canDecrement: canRepeatDown,
          canIncrement: canRepeatUp,
          onDecrement: () => _update(repeatN: _repeatN - 1),
          onIncrement: () => _update(repeatN: _repeatN + 1),
          decrementTooltip: '重複次數 -1',
          incrementTooltip: '重複次數 +1',
        ),
        const SizedBox(height: 8),
        _StepperRow(
          label: '靜音比例',
          valueKey: ValueKey('${widget.keyPrefix}-silence-value'),
          value: _silenceFactor.toStringAsFixed(1),
          decrementKey: ValueKey('${widget.keyPrefix}-silence-decrement'),
          incrementKey: ValueKey('${widget.keyPrefix}-silence-increment'),
          canDecrement: canSilenceDown,
          canIncrement: canSilenceUp,
          onDecrement: () => _update(
            silenceFactor: (_silenceFactor - PracticeBlock.silenceFactorStep)
                .clamp(
                  PracticeBlock.minSilenceFactor,
                  PracticeBlock.maxSilenceFactor,
                )
                .toDouble(),
          ),
          onIncrement: () => _update(
            silenceFactor: (_silenceFactor + PracticeBlock.silenceFactorStep)
                .clamp(
                  PracticeBlock.minSilenceFactor,
                  PracticeBlock.maxSilenceFactor,
                )
                .toDouble(),
          ),
          decrementTooltip: '靜音比例 -0.5',
          incrementTooltip: '靜音比例 +0.5',
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              key: ValueKey('${widget.keyPrefix}-config-reset'),
              onPressed: _reset,
              child: const Text('重置'),
            ),
            if (widget.onPreview != null)
              OutlinedButton.icon(
                key: ValueKey('${widget.keyPrefix}-preview'),
                onPressed: widget.onPreview,
                icon: const Icon(Icons.play_arrow),
                label: Text(widget.previewLabel),
              ),
          ],
        ),
      ],
    );
  }
}

class _StepperRow extends StatelessWidget {
  const _StepperRow({
    required this.label,
    required this.valueKey,
    required this.value,
    required this.decrementKey,
    required this.incrementKey,
    required this.canDecrement,
    required this.canIncrement,
    required this.onDecrement,
    required this.onIncrement,
    required this.decrementTooltip,
    required this.incrementTooltip,
  });

  final String label;
  final Key valueKey;
  final String value;
  final Key decrementKey;
  final Key incrementKey;
  final bool canDecrement;
  final bool canIncrement;
  final VoidCallback onDecrement;
  final VoidCallback onIncrement;
  final String decrementTooltip;
  final String incrementTooltip;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(label)),
        IconButton(
          key: decrementKey,
          tooltip: decrementTooltip,
          onPressed: canDecrement ? onDecrement : null,
          icon: const Icon(Icons.remove),
        ),
        SizedBox(
          width: 64,
          child: Center(key: valueKey, child: Text(value)),
        ),
        IconButton(
          key: incrementKey,
          tooltip: incrementTooltip,
          onPressed: canIncrement ? onIncrement : null,
          icon: const Icon(Icons.add),
        ),
      ],
    );
  }
}
