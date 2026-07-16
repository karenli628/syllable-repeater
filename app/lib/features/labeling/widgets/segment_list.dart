// AI-Generate
import 'package:domain/domain.dart';
import 'package:flutter/material.dart';

import '../../../shared/tokens.dart';
import '../labeling_controller.dart';

typedef SegmentDispositionChanged =
    void Function(int index, SegmentDisposition disposition);

/// 段落清單（frontend-design.md 功能點 10、AT-11-01/02）。
///
/// 清單只發出選取／試聽／刪除意圖；不可直接取得或修改 session 內的
/// mutable 狀態，實際變更仍由 LabelingController 委派 Domain。
class SegmentList extends StatelessWidget {
  const SegmentList({
    required this.segments,
    required this.selectedSegmentIndex,
    required this.previewingSegmentIndex,
    required this.previewStatus,
    required this.onSelect,
    required this.onPreview,
    required this.onStopPreview,
    required this.onRemoveBoundary,
    required this.onDispositionChanged,
    super.key,
  });

  final List<Segment> segments;
  final int? selectedSegmentIndex;
  final int? previewingSegmentIndex;
  final LabelingPreviewStatus previewStatus;
  final ValueChanged<int> onSelect;
  final ValueChanged<int> onPreview;
  final VoidCallback onStopPreview;
  final ValueChanged<int> onRemoveBoundary;
  final SegmentDispositionChanged onDispositionChanged;

  @override
  Widget build(BuildContext context) {
    if (segments.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AppTokens.spaceSm),
        child: Text('目前沒有自動切句，可在波形上新增標籤線。'),
      );
    }
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: segments.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final segment = segments[index];
        final selected = selectedSegmentIndex == index;
        final previewing = previewingSegmentIndex == index;
        return ListTile(
          dense: true,
          selected: selected,
          selectedTileColor: AppTokens.selectedHighlight.withValues(alpha: 0.2),
          onTap: () => onSelect(index),
          leading: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Checkbox(value: selected, onChanged: (_) => onSelect(index)),
              CircleAvatar(
                radius: 14,
                child: Text(
                  '${index + 1}',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
          title: Text(
            segment.text.isEmpty ? '（未辨識文字）' : segment.text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            '${segment.startMs}–${segment.endMs} ms · '
            '${segment.disposition == SegmentDisposition.kept ? '保留' : '捨棄'}',
          ),
          trailing: Wrap(
            spacing: AppTokens.spaceXs,
            children: [
              IconButton(
                tooltip:
                    previewing && previewStatus == LabelingPreviewStatus.playing
                    ? '暫停第 ${index + 1} 段'
                    : '試聽第 ${index + 1} 段',
                onPressed: () => onPreview(index),
                icon: Icon(
                  previewing && previewStatus == LabelingPreviewStatus.playing
                      ? Icons.pause
                      : Icons.play_arrow_outlined,
                ),
              ),
              IconButton(
                tooltip: '停止第 ${index + 1} 段試聽',
                onPressed: previewStatus == LabelingPreviewStatus.idle
                    ? null
                    : onStopPreview,
                icon: const Icon(Icons.stop),
              ),
              PopupMenuButton<SegmentDisposition>(
                tooltip: '第 ${index + 1} 段區間處置',
                initialValue: segment.disposition,
                onSelected: (disposition) =>
                    onDispositionChanged(index, disposition),
                itemBuilder: (context) => const [
                  PopupMenuItem(
                    value: SegmentDisposition.kept,
                    child: Text('保留此區間'),
                  ),
                  PopupMenuItem(
                    value: SegmentDisposition.discarded,
                    child: Text('捨棄此區間'),
                  ),
                ],
                icon: Icon(
                  segment.disposition == SegmentDisposition.kept
                      ? Icons.check_circle_outline
                      : Icons.block_outlined,
                ),
              ),
              if (index < segments.length - 1)
                IconButton(
                  tooltip: '刪除第 ${index + 1} 條標籤線',
                  onPressed: () => onRemoveBoundary(index),
                  icon: const Icon(Icons.close),
                ),
            ],
          ),
        );
      },
    );
  }
}
