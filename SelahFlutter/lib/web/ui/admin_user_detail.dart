import 'package:flutter/material.dart';
import '../../design/selah_colors.dart';
import '../../design/selah_spacing.dart';
import '../../design/selah_typography.dart';
import '../data/learning_gateway.dart';
import '../domain/admin_membership.dart';
import '../domain/learning_models.dart';

String _actionLabel(String action) => switch (action) {
      'grant_membership' => '赠送会员',
      'compensate_membership' => '客服补偿',
      'revoke_grant' => '撤销误赠',
      'replay_order' => '补发已购权益',
      'record_manual_payment' => '登记人工收款',
      _ => '会员操作',
    };

class AdminUserDetailDialog extends StatefulWidget {
  const AdminUserDetailDialog({
    required this.gateway,
    required this.user,
    super.key,
  });

  final LearningGateway gateway;
  final AdminUserItem user;

  @override
  State<AdminUserDetailDialog> createState() => _AdminUserDetailDialogState();
}

class _AdminUserDetailDialogState extends State<AdminUserDetailDialog> {
  bool _loading = true;
  AdminUserDetailData? _detail;
  String _selectedAction = 'grant_membership';
  int _selectedMonths = 1;
  final TextEditingController _customMonthsController =
      TextEditingController(text: '1');
  final TextEditingController _reasonController = TextEditingController();
  final TextEditingController _orderController = TextEditingController();
  final TextEditingController _membershipController = TextEditingController();
  final TextEditingController _transactionController = TextEditingController();
  final TextEditingController _channelController = TextEditingController(text: 'manual');
  bool _submitting = false;

  bool get isGrantAction =>
      _selectedAction == 'grant_membership' ||
      _selectedAction == 'compensate_membership';

  @override
  void initState() {
    super.initState();
    _loadDetail();
  }

  Future<void> _loadDetail() async {
    setState(() => _loading = true);
    try {
      final res = await widget.gateway.invoke(
        'admin-users',
        {'userId': widget.user.userId},
      );
      if (mounted) {
        setState(() {
          _detail = AdminUserDetailData.fromJson(res);
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submitAction() async {
    final reason = _reasonController.text.trim();
    if (reason.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请填写操作原因')),
      );
      return;
    }
    if (_selectedAction == 'replay_order' && _orderController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请填写已核实订单号')),
      );
      return;
    }
    if (_selectedAction == 'revoke_grant' && _membershipController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请填写要撤销的会员记录 ID')),
      );
      return;
    }
    if (_selectedAction == 'record_manual_payment' &&
        _transactionController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请填写唯一交易编号')),
      );
      return;
    }
    final customMonths = int.tryParse(_customMonthsController.text.trim());
    if (isGrantAction && (customMonths == null || customMonths < 1 || customMonths > 12)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('会员时长必须是 1—12 个月')),
      );
      return;
    }
    if (isGrantAction) {
      _selectedMonths = customMonths!;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('确认${_actionLabel(_selectedAction)}'),
        content: Text(
          '目标用户：${widget.user.emailMasked}\n'
          '${isGrantAction ? '会员时长：$_selectedMonths 个月\n' : ''}'
          '操作原因：$reason\n\n'
          '提交后会由服务端重新校验权限、版本和预算。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('返回修改'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('继续提交'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _submitting = true);
    try {
      final body = <String, dynamic>{
        'action': _selectedAction,
        'targetUserId': widget.user.userId,
        'months': _selectedMonths,
        'reason': reason,
        'clientRequestId': newId(),
        if (_orderController.text.trim().isNotEmpty)
          'orderId': _orderController.text.trim(),
        if (_membershipController.text.trim().isNotEmpty)
          'membershipId': _membershipController.text.trim(),
        if (_channelController.text.trim().isNotEmpty)
          'channel': _channelController.text.trim(),
        if (_transactionController.text.trim().isNotEmpty)
          'transactionId': _transactionController.text.trim(),
        if (_selectedAction == 'record_manual_payment') 'amountFenCny': 3990,
      };
      await widget.gateway.invoke('admin-membership-actions', body);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('操作已提交：${_actionLabel(_selectedAction)}')),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('操作失败: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  void dispose() {
    _reasonController.dispose();
    _customMonthsController.dispose();
    _orderController.dispose();
    _membershipController.dispose();
    _transactionController.dispose();
    _channelController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isGrant = _selectedAction == 'grant_membership' ||
        _selectedAction == 'compensate_membership';
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540),
        child: Padding(
          padding: const EdgeInsets.all(SelahSpacing.xl),
          child: _loading
              ? const SizedBox(height: 200, child: Center(child: CircularProgressIndicator()))
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('用户会员管理', style: SelahTypography.headlineLarge()),
                    const SizedBox(height: SelahSpacing.sm),
                    Text('用户: ${widget.user.emailMasked} (${widget.user.userId})',
                        style: SelahTypography.bodyMedium(color: SelahColors.textSecondary)),
                    const SizedBox(height: SelahSpacing.sm),
                    Text(
                      '当前：${widget.user.plan} · ${widget.user.status}${widget.user.expiresAt == null ? '' : ' · 有效至 ${widget.user.expiresAt!.toLocal().toString().substring(0, 10)}'}',
                      style: SelahTypography.bodyMedium(),
                    ),
                    const SizedBox(height: SelahSpacing.lg),
                    if (_detail != null) ...[
                      _DetailSummary(detail: _detail!),
                      const SizedBox(height: SelahSpacing.lg),
                    ],
                    DropdownButtonFormField<String>(
                      initialValue: _selectedAction,
                      decoration: const InputDecoration(
                        labelText: '操作类型',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'grant_membership',
                          child: Text('赠送会员'),
                        ),
                        DropdownMenuItem(
                          value: 'compensate_membership',
                          child: Text('客服补偿'),
                        ),
                        DropdownMenuItem(
                          value: 'revoke_grant',
                          child: Text('撤销误赠'),
                        ),
                        DropdownMenuItem(
                          value: 'replay_order',
                          child: Text('补发已购权益'),
                        ),
                        DropdownMenuItem(
                          value: 'record_manual_payment',
                          child: Text('登记人工收款'),
                        ),
                      ],
                      onChanged: _submitting
                          ? null
                          : (value) {
                              if (value != null) {
                                setState(() => _selectedAction = value);
                              }
                            },
                    ),
                    if (isGrant) ...[
                      const SizedBox(height: SelahSpacing.md),
                      const Text('会员时长：'),
                      const SizedBox(height: SelahSpacing.xs),
                      SegmentedButton<int>(
                        segments: const [
                          ButtonSegment(value: 1, label: Text('1 个月')),
                          ButtonSegment(value: 3, label: Text('3 个月')),
                          ButtonSegment(value: 6, label: Text('6 个月')),
                        ],
                        selected: {_selectedMonths},
                        onSelectionChanged: (set) => setState(() {
                          _selectedMonths = set.first;
                          _customMonthsController.text = '$_selectedMonths';
                        }),
                      ),
                      const SizedBox(height: SelahSpacing.sm),
                      TextField(
                        controller: _customMonthsController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: '自定义月数（1—12）',
                          helperText: '快捷项之外可输入任意 1—12 个月',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                    if (_selectedAction == 'revoke_grant') ...[
                      const SizedBox(height: SelahSpacing.md),
                      TextField(
                        controller: _membershipController,
                        decoration: const InputDecoration(
                          labelText: '会员记录 ID（必填）',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                    if (_selectedAction == 'replay_order') ...[
                      const SizedBox(height: SelahSpacing.md),
                      TextField(
                        controller: _orderController,
                        decoration: const InputDecoration(
                          labelText: '已核实订单 ID（必填）',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                    if (_selectedAction == 'record_manual_payment') ...[
                      const SizedBox(height: SelahSpacing.md),
                      TextField(
                        controller: _channelController,
                        decoration: const InputDecoration(
                          labelText: '收款渠道',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: SelahSpacing.sm),
                      TextField(
                        controller: _transactionController,
                        decoration: const InputDecoration(
                          labelText: '唯一交易编号（必填）',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: SelahSpacing.xs),
                      const Text('金额固定为 3990 分（39.9 元），服务端会再次核验。'),
                    ],
                    const SizedBox(height: SelahSpacing.md),
                    TextField(
                      controller: _reasonController,
                      decoration: const InputDecoration(
                        labelText: '操作原因（必填）',
                        hintText: '如：客服补偿、内测赠送、活动兑现、订单补发等',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: SelahSpacing.lg),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('取消'),
                        ),
                        const SizedBox(width: SelahSpacing.sm),
                        FilledButton(
                          onPressed: _submitting ? null : _submitAction,
                          child: _submitting
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Text('确认操作'),
                        ),
                      ],
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _DetailSummary extends StatelessWidget {
  const _DetailSummary({required this.detail});

  final AdminUserDetailData detail;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(SelahSpacing.md),
      decoration: BoxDecoration(
        color: SelahColors.cardSoft,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: SelahColors.border),
      ),
      child: Wrap(
        spacing: SelahSpacing.lg,
        runSpacing: SelahSpacing.sm,
        children: [
          Text('会员时间线：${detail.periods.length} 段'),
          Text('关联订单：${detail.orders.length} 笔'),
          Text('操作记录：${detail.auditLogs.length} 条'),
        ],
      ),
    );
  }
}
