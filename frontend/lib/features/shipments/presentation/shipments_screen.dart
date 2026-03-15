import 'package:flutter/material.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/tms_formatters.dart';
import '../../../core/widgets/data_panel.dart';
import '../../../core/widgets/page_banner.dart';

class ShipmentsScreen extends StatelessWidget {
  const ShipmentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final client = ApiClient();

    return FutureBuilder<Map<String, dynamic>>(
      future: client.fetchShipments(),
      builder: (context, snapshot) {
        final items = (snapshot.data?['items'] as List?) ?? const [];

        return ListView(
          children: [
            PageBanner(
              eyebrow: '출하 흐름',
              title: '출하 실행',
              description:
                  '운송중인 출하와 예정 출하의 도착 예정, 운송사, 거리 정보를 정리해 실행 현황을 또렷하게 보여줍니다.',
              leading: const _SectionLead(
                icon: Icons.local_shipping_rounded,
                label: '출하 실행',
              ),
              details: [
                BannerDetail(label: '전체 출하', value: '${items.length}건'),
                BannerDetail(
                  label: '운송중',
                  value:
                      '${TmsFormatters.countMatching(items, 'status', 'in_transit')}건',
                ),
                BannerDetail(
                  label: '배차완료',
                  value:
                      '${TmsFormatters.countMatching(items, 'status', 'dispatched')}건',
                ),
                BannerDetail(
                  label: '배송완료',
                  value:
                      '${TmsFormatters.countMatching(items, 'status', 'delivered')}건',
                ),
              ],
            ),
            const SizedBox(height: 20),
            DataPanel(
              title: '운행 스트림',
              subtitle: '실제 PostgreSQL 샘플 데이터로 구성한 출하 실행 목록',
              trailing: _CountChip(label: '총 ${items.length}건'),
              child: Column(
                children: [
                  for (final item in items) ...[
                    _ShipmentCard(
                      shipmentNo: '${item['shipment_no']}',
                      orderNo: '${item['order_no']}',
                      status: '${item['status']}',
                      carrier: '${item['carrier_name']}',
                      pickupAt: TmsFormatters.dateTime(
                        item['planned_pickup_at'],
                      ),
                      eta: TmsFormatters.dateTime(item['planned_delivery_at']),
                      distance: TmsFormatters.distance(
                        item['total_distance_km'],
                      ),
                      weight: TmsFormatters.weight(item['total_weight_kg']),
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

class _ShipmentCard extends StatelessWidget {
  const _ShipmentCard({
    required this.shipmentNo,
    required this.orderNo,
    required this.status,
    required this.carrier,
    required this.pickupAt,
    required this.eta,
    required this.distance,
    required this.weight,
  });

  final String shipmentNo;
  final String orderNo;
  final String status;
  final String carrier;
  final String pickupAt;
  final String eta;
  final String distance;
  final String weight;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
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
                shipmentNo,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              _StatusChip(
                label: TmsFormatters.status(status),
                color: _statusColor(status),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '오더  $orderNo',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppTheme.ink,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            '운송사  ${TmsFormatters.entity(carrier)}',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _InfoCard(label: '픽업 예정', value: pickupAt),
              _InfoCard(label: '도착 예정', value: eta),
              _InfoCard(label: '총거리', value: distance),
              _InfoCard(label: '총중량', value: weight),
            ],
          ),
        ],
      ),
    );
  }

  Color _statusColor(String value) {
    switch (value) {
      case 'delivered':
        return AppTheme.pine;
      case 'in_transit':
        return AppTheme.copper;
      default:
        return const Color(0xFF425466);
    }
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.label, required this.value});

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
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppTheme.muted),
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
  const _StatusChip({required this.label, required this.color});

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
  const _SectionLead({required this.icon, required this.label});

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
