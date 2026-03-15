import 'package:flutter/material.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/tms_formatters.dart';
import '../../../core/widgets/brand_logo.dart';
import '../../../core/widgets/data_panel.dart';
import '../../../core/widgets/metric_card.dart';
import '../../../core/widgets/page_banner.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final client = ApiClient();

    return FutureBuilder<Map<String, dynamic>>(
      future: client.fetchDashboardSnapshot(),
      builder: (context, snapshot) {
        final data = snapshot.data;
        final metrics = (data?['metrics'] as List?) ?? const [];
        final orderStatuses = (data?['order_statuses'] as List?) ?? const [];
        final recentEvents = (data?['recent_events'] as List?) ?? const [];
        final dispatchBoard = (data?['dispatch_board'] as List?) ?? const [];

        return ListView(
          children: [
            PageBanner(
              eyebrow: '오늘의 운영',
              title: '오늘의 수진 TMS 운송 흐름을 한눈에 확인하세요',
              description:
                  '오더, 출하, 배차, 위치 이벤트를 한 화면에 모아 수진 TMS의 현재 움직임을 차분하고 선명하게 보여줍니다.',
              leading: const BrandLogo(onDark: true, subtitle: '스마트 운송 운영 플랫폼'),
              details: [
                const BannerDetail(label: '테넌트', value: 'SUJIN'),
                BannerDetail(
                  label: '상태',
                  value: snapshot.connectionState == ConnectionState.waiting
                      ? '데이터 동기화 중'
                      : '실시간 연결 정상',
                ),
                const BannerDetail(label: '운영 스택', value: 'Flutter + FastAPI'),
                BannerDetail(
                  label: '최근 반영',
                  value: TmsFormatters.dateTime(
                    DateTime.now().toIso8601String(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                for (final metric in metrics)
                  SizedBox(
                    width: 220,
                    child: MetricCard(
                      label: TmsFormatters.metricLabel('${metric['label']}'),
                      value: TmsFormatters.metricValue(
                        '${metric['label']}',
                        metric['value'],
                      ),
                      background: _accent(metric['accent'] as String?),
                      foreground: Colors.white,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 22),
            LayoutBuilder(
              builder: (context, constraints) {
                final stacked = constraints.maxWidth < 1120;
                final statusPanel = DataPanel(
                  title: '오더 현황',
                  subtitle: '진행 중인 오더와 완료 오더의 상태 비중',
                  child: Column(
                    children: [
                      for (final row in orderStatuses) ...[
                        _StatusRow(
                          label: '${row['status']}',
                          count: '${row['count']}',
                        ),
                        const SizedBox(height: 14),
                      ],
                    ],
                  ),
                );

                final eventPanel = DataPanel(
                  title: '최근 이동 이벤트',
                  subtitle: '차량과 출하에서 발생한 최신 추적 이벤트',
                  child: Column(
                    children: [
                      for (final row in recentEvents) ...[
                        _EventRow(
                          shipmentNo: '${row['shipment_no']}',
                          eventType: '${row['event_type']}',
                          message: '${row['message'] ?? ''}',
                          occurredAt: '${row['occurred_at']}',
                        ),
                        const SizedBox(height: 18),
                      ],
                    ],
                  ),
                );

                final board = DataPanel(
                  title: '배차 보드',
                  subtitle: '다음 정차지와 배차 상태를 한 번에 확인',
                  child: Column(
                    children: [
                      for (final row in dispatchBoard) ...[
                        _BoardRow(row: Map<String, dynamic>.from(row as Map)),
                        const SizedBox(height: 14),
                      ],
                    ],
                  ),
                );

                if (stacked) {
                  return Column(
                    children: [
                      statusPanel,
                      const SizedBox(height: 16),
                      eventPanel,
                      const SizedBox(height: 16),
                      board,
                    ],
                  );
                }

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 2,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: statusPanel),
                          const SizedBox(width: 16),
                          Expanded(child: eventPanel),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(child: board),
                  ],
                );
              },
            ),
          ],
        );
      },
    );
  }

  Color _accent(String? accent) {
    switch (accent) {
      case 'teal':
        return AppTheme.pine;
      case 'crimson':
        return const Color(0xFFDA7A12);
      case 'copper':
        return AppTheme.copper;
      default:
        return const Color(0xFF2F6B95);
    }
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({required this.label, required this.count});

  final String label;
  final String count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppTheme.wheat.withOpacity(0.58),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              TmsFormatters.status(label),
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              count,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: AppTheme.ink,
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EventRow extends StatelessWidget {
  const _EventRow({
    required this.shipmentNo,
    required this.eventType,
    required this.message,
    required this.occurredAt,
  });

  final String shipmentNo;
  final String eventType;
  final String message;
  final String occurredAt;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 14,
          height: 14,
          margin: const EdgeInsets.only(top: 6),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF0F5D91), Color(0xFF0F9F8F)],
            ),
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$shipmentNo · ${TmsFormatters.eventType(eventType)}',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              Text(
                TmsFormatters.message(message),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Text(
          TmsFormatters.dateTime(occurredAt),
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _BoardRow extends StatelessWidget {
  const _BoardRow({required this.row});

  final Map<String, dynamic> row;

  @override
  Widget build(BuildContext context) {
    final eta = TmsFormatters.dateRange(
      row['next_eta_from'],
      row['next_eta_to'],
    );

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.88),
        borderRadius: BorderRadius.circular(22),
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
                '${row['shipment_no']}',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              _Pill(
                label: TmsFormatters.status('${row['shipment_status']}'),
                color: AppTheme.pine,
              ),
              _Pill(
                label: TmsFormatters.status('${row['dispatch_status'] ?? '-'}'),
                color: AppTheme.copper,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '${TmsFormatters.entity('${row['shipper_name']}')} → ${TmsFormatters.entity('${row['next_stop_name'] ?? 'No next stop'}')}',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppTheme.ink,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            '기사 ${TmsFormatters.entity('${row['driver_name'] ?? '-'}')} · 차량 ${row['vehicle_plate_no'] ?? '-'}',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 4),
          Text(
            eta == '-' ? '다음 도착 예정 정보 없음' : '다음 도착 예정  $eta',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.color});

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
