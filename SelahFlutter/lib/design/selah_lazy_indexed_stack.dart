import 'package:flutter/widgets.dart';

/// 只构建访问过的 index，未访问页面先占位，访问后保持常驻。
///
/// 保持 IndexedStack 的状态保持语义：页面首次构建后 Element 不销毁，
/// 滚动、草稿、播放状态不因切换丢失；未访问的 tab 不参与首帧构建，
/// 降低进入时的首帧工作量。
///
/// 隐藏页面统一包在关闭的 TickerMode 里：AnimationController 与多帧
/// 图片（GIF/WebP）都会暂停，避免后台 Tab 持续消耗解码与栅格资源。
class SelahLazyIndexedStack extends StatefulWidget {
  const SelahLazyIndexedStack({
    super.key,
    required this.index,
    required this.children,
  });

  final int index;
  final List<Widget> children;

  @override
  State<SelahLazyIndexedStack> createState() => _SelahLazyIndexedStackState();
}

class _SelahLazyIndexedStackState extends State<SelahLazyIndexedStack> {
  late final Set<int> _visited;
  late final List<Widget?> _cachedChildren;

  int get _activeIndex => widget.index.clamp(0, widget.children.length - 1);

  @override
  void initState() {
    super.initState();
    _visited = {_activeIndex};
    _cachedChildren = [
      for (var i = 0; i < widget.children.length; i++)
        if (i == _activeIndex) widget.children[i] else null,
    ];
  }

  @override
  void didUpdateWidget(covariant SelahLazyIndexedStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_cachedChildren.length > widget.children.length) {
      _cachedChildren.removeRange(
        widget.children.length,
        _cachedChildren.length,
      );
      _visited.removeWhere((index) => index >= widget.children.length);
    } else {
      _cachedChildren.addAll(
        List<Widget?>.filled(
          widget.children.length - _cachedChildren.length,
          null,
        ),
      );
    }
    _visited.add(_activeIndex);
    _cachedChildren[_activeIndex] = widget.children[_activeIndex];
  }

  @override
  Widget build(BuildContext context) {
    return IndexedStack(
      index: _activeIndex,
      children: [
        for (var i = 0; i < widget.children.length; i++)
          _visited.contains(i)
              ? TickerMode(
                  enabled: i == _activeIndex,
                  child: i == _activeIndex
                      ? widget.children[i]
                      : _cachedChildren[i] ?? const SizedBox.shrink(),
                )
              : const SizedBox.shrink(),
      ],
    );
  }
}
