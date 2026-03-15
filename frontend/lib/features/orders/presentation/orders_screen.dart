import 'package:flutter/material.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/tms_formatters.dart';
import '../../../core/widgets/data_panel.dart';
import '../../../core/widgets/page_banner.dart';
import 'order_editor_dialog.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  late final ApiClient _client;
  late Future<_OrdersScreenData> _future;

  @override
  void initState() {
    super.initState();
    _client = ApiClient();
    _future = _loadData();
  }

  Future<_OrdersScreenData> _loadData() async {
    final responses = await Future.wait([
      _client.fetchOrders(),
      _client.fetchMasterSnapshot(),
    ]);

    return _OrdersScreenData(
      orders: responses[0],
      masters: responses[1],
    );
  }

  void _refresh() {
    setState(() {
      _future = _loadData();
    });
  }

  Future<void> _openCreateDialog(Map<String, dynamic> masters) async {
    final saved = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) {
        return Dialog(
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          backgroundColor: Colors.transparent,
          child: OrderEditorDialog(
            client: _client,
            masters: masters,
          ),
        );
      },
    );

    if (!mounted || saved == null) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('운송오더 ${saved['order_no']} 등록이 완료되었습니다.')),
    );
    _refresh();
  }

  Future<void> _openDetailDialog(
    String orderId,
    Map<String, dynamic> masters,
  ) async {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return const Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: Center(child: CircularProgressIndicator()),
        );
      },
    );

    Map<String, dynamic>? detail;
    Object? error;
    try {
      detail = await _client.fetchOrderDetail(orderId);
    } catch (exception) {
      error = exception;
    }

    if (!mounted) {
      return;
    }
    Navigator.of(context, rootNavigator: true).pop();

    if (error != null || detail == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error?.toString().replaceFirst('Exception: ', '') ??
                '오더 상세 정보를 불러오지 못했습니다.',
          ),
        ),
      );
      return;
    }

    final saved = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) {
        return Dialog(
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          backgroundColor: Colors.transparent,
          child: OrderEditorDialog(
            client: _client,
            masters: masters,
            existingOrder: detail,
          ),
        );
      },
    );

    if (!mounted || saved == null) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('운송오더 ${saved['order_no']} 수정이 완료되었습니다.')),
    );
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_OrdersScreenData>(
      future: _future,
      builder: (context, snapshot) {
        final data = snapshot.data;
        final items = (data?.orders['items'] as List?) ?? const [];
        final organizations =
            (data?.masters['organizations'] as List?) ?? const [];
        final locations = (data?.masters['locations'] as List?) ?? const [];
        final canCreate = organizations.isNotEmpty && locations.isNotEmpty;

        return ListView(
          children: [
            PageBanner(
              eyebrow: '오더 운영',
              title: '오더 관리',
              description: '오더 카드를 클릭하면 상세 화면이 열리고, 같은 화면에서 바로 수정까지 할 수 있습니다.',
              leading: const _SectionLead(
                icon: Icons.inventory_2_rounded,
                label: '오더 운영',
              ),
              details: [
                BannerDetail(label: '전체 오더', value: '${items.length}건'),
                BannerDetail(
                  label: '운송중',
                  value:
                      '${TmsFormatters.countMatching(items, 'status', 'in_transit')}건',
                ),
                BannerDetail(
                  label: '확정',
                  value:
                      '${TmsFormatters.countMatching(items, 'status', 'confirmed')}건',
                ),
                BannerDetail(
                  label: '배송완료',
                  value:
                      '${TmsFormatters.countMatching(items, 'status', 'delivered')}건',
                ),
              ],
            ),
            const SizedBox(height: 22),
            LayoutBuilder(
              builder: (context, constraints) {
                final stacked = constraints.maxWidth < 880;
                final searchField = const TextField(
                  decoration: InputDecoration(
                    hintText: '오더번호, 참조번호, 고객명을 검색해보세요',
                    prefixIcon: Icon(Icons.search_rounded),
                  ),
                );
                final createButton = FilledButton.icon(
                  onPressed:
                      canCreate ? () => _openCreateDialog(data!.masters) : null,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('운송오더 등록'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.copper,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 18,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                );

                if (stacked) {
                  return Column(
                    children: [
                      searchField,
                      const SizedBox(height: 12),
                      SizedBox(width: double.infinity, child: createButton),
                    ],
                  );
                }

                return Row(
                  children: [
                    Expanded(child: searchField),
                    const SizedBox(width: 12),
                    createButton,
                  ],
                );
              },
            ),
            const SizedBox(height: 20),
            DataPanel(
              title: '오더 대기열',
              subtitle: canCreate
                  ? '오더 카드를 클릭하면 상세/수정 화면이 열립니다.'
                  : '등록에 필요한 마스터 데이터가 아직 로드되지 않았습니다.',
              trailing: _CountChip(label: '총 ${items.length}건'),
              child: Column(
                children: [
                  for (final item in items) ...[
                    _OrderRow(
                      orderId: '${item['id']}',
                      orderNo: '${item['order_no']}',
                      status: '${item['status']}',
                      customer: '${item['customer_name']}',
                      reference: '${item['customer_reference']}',
                      weight: TmsFormatters.weight(item['total_weight_kg']),
                      volume: TmsFormatters.volume(item['total_volume_m3']),
                      pickupAt: TmsFormatters.dateTime(
                        item['planned_pickup_from'],
                      ),
                      deliveryAt: TmsFormatters.dateTime(
                        item['planned_delivery_to'],
                      ),
                      priority: '${item['priority']}',
                      onTap: canCreate
                          ? () =>
                              _openDetailDialog('${item['id']}', data!.masters)
                          : null,
                    ),
                    const SizedBox(height: 14),
                  ],
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _OrdersScreenData {
  const _OrdersScreenData({
    required this.orders,
    required this.masters,
  });

  final Map<String, dynamic> orders;
  final Map<String, dynamic> masters;
}

class _OrderRow extends StatelessWidget {
  const _OrderRow({
    required this.orderId,
    required this.orderNo,
    required this.status,
    required this.customer,
    required this.reference,
    required this.weight,
    required this.volume,
    required this.pickupAt,
    required this.deliveryAt,
    required this.priority,
    required this.onTap,
  });

  final String orderId;
  final String orderNo;
  final String status;
  final String customer;
  final String reference;
  final String weight;
  final String volume;
  final String pickupAt;
  final String deliveryAt;
  final String priority;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Ink(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.9),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppTheme.line),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 10,
                runSpacing: 10,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    orderNo,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  _StatusChip(
                    label: TmsFormatters.status(status),
                    color: _statusColor(status),
                  ),
                  _StatusChip(
                    label: '우선순위 $priority',
                    color: const Color(0xFFD97706),
                  ),
                  if (onTap != null)
                    _StatusChip(
                      label: '상세 보기',
                      color: AppTheme.copper,
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                TmsFormatters.entity(customer),
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppTheme.ink,
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                '참조번호  $reference',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _InfoCard(label: '총중량', value: weight),
                  _InfoCard(label: '체적', value: volume),
                  _InfoCard(label: '픽업 예정', value: pickupAt),
                  _InfoCard(label: '도착 예정', value: deliveryAt),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _statusColor(String value) {
    switch (value) {
      case 'delivered':
        return AppTheme.pine;
      case 'in_transit':
        return AppTheme.copper;
      case 'cancelled':
        return const Color(0xFFB84A3A);
      default:
        return const Color(0xFF425466);
    }
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 150),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.wheat.withOpacity(0.54),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.muted,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppTheme.ink,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.label,
    required this.color,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
            ),
      ),
    );
  }
}

class _CountChip extends StatelessWidget {
  const _CountChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.wheat.withOpacity(0.7),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppTheme.ink,
              fontWeight: FontWeight.w800,
            ),
      ),
    );
  }
}

class _SectionLead extends StatelessWidget {
  const _SectionLead({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.12),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Icon(icon, color: Colors.white),
        ),
        const SizedBox(width: 12),
        Text(
          label,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
        ),
      ],
    );
  }
}
