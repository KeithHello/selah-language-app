import 'package:flutter/widgets.dart';

/// 只构建访问过的 index，未访问页面先占位，访问后保持常驻。
///
/// 保持 IndexedStack 的状态保持语义：页面首次构建后 Element 不销毁，
/// 滚动、草稿、播放状态不因切换丢失；未访问的 tab 不参与首帧构建，
/// 降低进入时的首帧工作量。
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
  late final Set<int> _visited = {
    widget.index.clamp(0, widget.children.length - 1),
  };

  @override
  void didUpdateWidget(covariant SelahLazyIndexedStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    _visited.add(widget.index.clamp(0, widget.children.length - 1));
  }

  @override
  Widget build(BuildContext context) {
    return IndexedStack(
      index: widget.index,
      children: [
        for (var i = 0; i < widget.children.length; i++)
          _visited.contains(i)
              ? widget.children[i]
              : const SizedBox.shrink(),
      ],
    );
  }
}
