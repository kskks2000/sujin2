import 'package:flutter/material.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/tms_formatters.dart';
import '../../../core/widgets/data_panel.dart';
import '../../../core/widgets/page_banner.dart';

class DispatchScreen extends StatelessWidget {
  const DispatchScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final client = ApiClient();

    return FutureBuilder<Map<String, dynamic>>(
      future: client.fetchDispatches(),
      builder: (context, snapshot) {
        final items = (snapshot.data?['items'] as List?) ?? const [];

        return ListView(
          children: [
            PageBanner(
              eyebrow: '배차 보드',
              title: '배차 운영',
              description: '기사, 차량, 배차 상태를 하나의 보드로 묶어 현장 대응이 빠르게 이어지도록 구성했습니다.',
              leading: const _SectionLead(
                icon: Icons.alt_route_rounded,
                label: '배차 운영',
              ),
              details: [
                BannerDetail(label: '전체 배차', value: '${items.length}건'),
                BannerDetail(
                  label: '수락',
                  value:
                      '${TmsFormatters.countMatching(items, 'status', 'accepted')}건',
                ),
                BannerDetail(
                  label: '운송중',
                  value:
                      '${TmsFormatters.countMatching(items, 'status', 'in_transit')}건',
                ),
                BannerDetail(
                  label: '완료',
                  value:
                      '${TmsFormatters.countMatching(items, 'status', 'completed')}건',
                ),
              ],
            ),
            const SizedBox(height: 20),
            DataPanel(
              title: '배차 레인',
              subtitle: '운영 상태별 배차 정보를 확인하는 실행 보드',
              trailing: _CountChip(label: '총 ${items.length}건'),
              child: Column(
                children: [
                  for (final item in items) ...[
                    _DispatchLane(
                      dispatchNo: '${item['dispatch_no']}',
                      shipmentNo: '${item['shipment_no']}',
                      status: '${item['status']}',
                      driver: '${item['driver_name']}',
                      vehicle: '${item['vehicle_plate_no']}',
                      assignedAt: TmsFormatters.dateTime(item['assigned_at']),
                      acceptedAt: TmsFormatters.dateTime(item['accepted_at']),
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

class _DispatchLane extends StatelessWidget {
  const _DispatchLane({
    required this.dispatchNo,
    required this.shipmentNo,
    required this.status,
    required this.driver,
    required this.vehicle,
    required this.assignedAt,
    required this.acceptedAt,
  });

  final String dispatchNo;
  final String shipmentNo;
  final String status;
  final String driver;
  final String vehicle;
  final String assignedAt;
  final String acceptedAt;

  @override
  Widget build(BuildContext context) {
    return Container(
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
                dispatchNo,
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
            '출하번호  $shipmentNo',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppTheme.ink,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            '기사  ${TmsFormatters.entity(driver)} · 차량  $vehicle',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _InfoCard(label: '배차 지시', value: assignedAt),
              _InfoCard(label: '기사 수락', value: acceptedAt),
            ],
          ),
        ],
      ),
    );
  }

  Color _statusColor(String value) {
    switch (value) {
      case 'completed':
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
      constraints: const BoxConstraints(minWidth: 180),
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
