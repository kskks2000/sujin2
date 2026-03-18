import 'package:flutter/material.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/tms_formatters.dart';
import '../../../core/widgets/data_panel.dart';
import '../../../core/widgets/page_banner.dart';

class AllocationsScreen extends StatefulWidget {
  const AllocationsScreen({super.key});

  @override
  State<AllocationsScreen> createState() => _AllocationsScreenState();
}

class _AllocationsScreenState extends State<AllocationsScreen> {
  late final ApiClient _client;
  late Future<_AllocationWorkspaceData> _future;

  final TextEditingController _targetRateController = TextEditingController();
  final TextEditingController _quotedRateController = TextEditingController();
  final TextEditingController _fuelController = TextEditingController(text: '0');
  final TextEditingController _notesController = TextEditingController();

  String? _selectedPlanId;
  String? _selectedCarrierId;
  bool _submitting = false;
  String? _awardingAllocationId;

  @override
  void initState() {
    super.initState();
    _client = ApiClient();
    _future = _loadData();
  }

  @override
  void dispose() {
    _targetRateController.dispose();
    _quotedRateController.dispose();
    _fuelController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<_AllocationWorkspaceData> _loadData() async {
    final responses = await Future.wait([
      _client.fetchLoadPlans(status: 'ready_for_allocation'),
      _client.fetchAllocations(),
      _client.fetchMasterSnapshot(),
    ]);
    return _AllocationWorkspaceData(
      readyPlans: responses[0],
      allocations: responses[1],
      masters: responses[2],
    );
  }

  void _refresh() {
    setState(() {
      _future = _loadData();
    });
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  List<Map<String, dynamic>> _carrierOrganizations(Map<String, dynamic> masters) {
    final carriers = (masters['carrier_organizations'] as List?) ?? const [];
    final organizations = (masters['organizations'] as List?) ?? const [];
    final source = carriers.isNotEmpty ? carriers : organizations;
    return source.whereType<Map<String, dynamic>>().toList();
  }

  String? _preferredCarrierId(Map<String, dynamic> masters) {
    final carriers = _carrierOrganizations(masters);
    if (carriers.isEmpty) {
      return null;
    }
    return '${carriers.first['id']}';
  }

  double? _parseNumber(TextEditingController controller) {
    final value = controller.text.trim();
    if (value.isEmpty) {
      return null;
    }
    return double.tryParse(value.replaceAll(',', ''));
  }

  Future<void> _createAllocation(
    Map<String, dynamic>? selectedPlan,
    Map<String, dynamic> masters,
  ) async {
    if (selectedPlan == null) {
      _showMessage('배정할 편성안을 먼저 선택해주세요.');
      return;
    }
    final carrierId = _selectedCarrierId ?? _preferredCarrierId(masters);
    if (carrierId == null || carrierId.isEmpty) {
      _showMessage('배정 대상 운송사를 선택해주세요.');
      return;
    }

    setState(() {
      _submitting = true;
    });

    try {
      await _client.createAllocation({
        'load_plan_id': '${selectedPlan['id']}',
        'carrier_org_id': carrierId,
        'target_rate': _parseNumber(_targetRateController),
        'quoted_rate': _parseNumber(_quotedRateController),
        'fuel_surcharge': _parseNumber(_fuelController) ?? 0,
        'notes': _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
        'metadata': {
          'source': 'allocations_screen',
        },
      });
      if (!mounted) {
        return;
      }
      _showMessage('배정 요청을 등록했습니다.');
      _targetRateController.clear();
      _quotedRateController.clear();
      _fuelController.text = '0';
      _notesController.clear();
      _refresh();
    } catch (exception) {
      if (!mounted) {
        return;
      }
      _showMessage(exception.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }

  Future<void> _awardAllocation(Map<String, dynamic> allocation) async {
    setState(() {
      _awardingAllocationId = '${allocation['id']}';
    });
    try {
      final fuelSurcharge = allocation['fuel_surcharge'];
      await _client.awardAllocation('${allocation['id']}', {
        'quoted_rate': allocation['quoted_rate'],
        'fuel_surcharge': fuelSurcharge is num
            ? fuelSurcharge.toDouble()
            : double.tryParse('$fuelSurcharge'),
        'notes': allocation['notes'],
        'create_shipment': true,
        'shipment_status': 'planning',
      });
      if (!mounted) {
        return;
      }
      _showMessage('배정을 확정했고 출하를 생성했습니다.');
      _refresh();
    } catch (exception) {
      if (!mounted) {
        return;
      }
      _showMessage(exception.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() {
          _awardingAllocationId = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_AllocationWorkspaceData>(
      future: _future,
      builder: (context, snapshot) {
        final data = snapshot.data;
        final readyPlans = ((data?.readyPlans['items'] as List?) ?? const [])
            .whereType<Map<String, dynamic>>()
            .toList();
        final allocations = ((data?.allocations['items'] as List?) ?? const [])
            .whereType<Map<String, dynamic>>()
            .toList();
        final effectiveSelectedPlanId = _selectedPlanId ??
            (readyPlans.isNotEmpty ? '${readyPlans.first['id']}' : null);
        final selectedPlan = effectiveSelectedPlanId == null
            ? null
            : readyPlans.cast<Map<String, dynamic>?>().firstWhere(
                  (item) => '${item?['id']}' == effectiveSelectedPlanId,
                  orElse: () => readyPlans.isNotEmpty ? readyPlans.first : null,
                );
        final selectedCarrierId =
            _selectedCarrierId ?? (data == null ? null : _preferredCarrierId(data.masters));

        return ListView(
          children: [
            PageBanner(
              eyebrow: '배정 운영',
              title: '편성 후 배정 처리',
              description:
                  '편성 완료된 상차조합을 배정 큐로 넘기고, 운송사 요청과 배정 확정 단계를 출하/배차와 분리해 운영합니다.',
              leading: const _SectionLead(
                icon: Icons.assignment_ind_rounded,
                label: '배정 운영',
              ),
              details: [
                BannerDetail(label: '배정 대기', value: '${readyPlans.length}건'),
                BannerDetail(
                  label: '요청',
                  value:
                      '${TmsFormatters.countMatching(allocations, 'status', 'requested')}건',
                ),
                BannerDetail(
                  label: '확정',
                  value:
                      '${TmsFormatters.countMatching(allocations, 'status', 'awarded')}건',
                ),
                BannerDetail(
                  label: '출하 생성',
                  value:
                      '${allocations.where((item) => '${item['shipment_no']}'.isNotEmpty && item['shipment_no'] != 'null').length}건',
                ),
              ],
            ),
            const SizedBox(height: 22),
            LayoutBuilder(
              builder: (context, constraints) {
                final stacked = constraints.maxWidth < 1180;
                final queuePanel = DataPanel(
                  title: '배정 대기 편성안',
                  subtitle: '편성 팀에서 넘긴 상차조합을 여기서 운송사 배정 대상으로 선택합니다.',
                  trailing: _CountChip(label: '총 ${readyPlans.length}건'),
                  child: readyPlans.isEmpty
                      ? const _EmptyState(
                          title: '배정 대기 편성안이 없습니다.',
                          body: '편성 화면에서 편성안을 배정준비로 넘기면 여기로 모입니다.',
                        )
                      : Column(
                          children: [
                            for (final plan in readyPlans) ...[
                              _ReadyPlanCard(
                                plan: plan,
                                selected:
                                    '${plan['id']}' == '${selectedPlan?['id']}',
                                onTap: () {
                                  setState(() {
                                    _selectedPlanId = '${plan['id']}';
                                  });
                                },
                              ),
                              const SizedBox(height: 12),
                            ],
                          ],
                        ),
                );

                final requestPanel = DataPanel(
                  title: '배정 요청 등록',
                  subtitle:
                      '선택한 편성안에 대해 목표 운임과 제안 운임을 기록하고 배정을 요청합니다.',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (selectedPlan == null)
                        const _EmptyState(
                          title: '선택된 편성안이 없습니다.',
                          body: '왼쪽에서 배정할 편성안을 선택해주세요.',
                        )
                      else ...[
                        _PlanSummaryCard(plan: selectedPlan),
                        const SizedBox(height: 16),
                        _DropdownField(
                          label: '운송사',
                          value: selectedCarrierId,
                          items: (data == null
                                  ? const <Map<String, dynamic>>[]
                                  : _carrierOrganizations(data.masters))
                              .map(
                                (item) => DropdownMenuItem<String>(
                                  value: '${item['id']}',
                                  child: Text(
                                    TmsFormatters.entity('${item['name']}'),
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            setState(() {
                              _selectedCarrierId = value;
                            });
                          },
                        ),
                        const SizedBox(height: 14),
                        LayoutBuilder(
                          builder: (context, innerConstraints) {
                            final stackedInner = innerConstraints.maxWidth < 760;
                            final targetField = TextField(
                              controller: _targetRateController,
                              keyboardType: const TextInputType.numberWithOptions(
                                decimal: true,
                              ),
                              decoration: const InputDecoration(
                                labelText: '목표 운임',
                                hintText: '예: 480000',
                              ),
                            );
                            final quoteField = TextField(
                              controller: _quotedRateController,
                              keyboardType: const TextInputType.numberWithOptions(
                                decimal: true,
                              ),
                              decoration: const InputDecoration(
                                labelText: '제안 운임',
                                hintText: '예: 495000',
                              ),
                            );
                            if (stackedInner) {
                              return Column(
                                children: [
                                  targetField,
                                  const SizedBox(height: 14),
                                  quoteField,
                                ],
                              );
                            }
                            return Row(
                              children: [
                                Expanded(child: targetField),
                                const SizedBox(width: 12),
                                Expanded(child: quoteField),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          controller: _fuelController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: '유류할증',
                            hintText: '예: 25000',
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          controller: _notesController,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            labelText: '배정 메모',
                            hintText: '회신 요청사항, 시간 제약, 냉동/윙바디 조건 등을 기록합니다.',
                          ),
                        ),
                        const SizedBox(height: 18),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: _submitting || data == null
                                ? null
                                : () => _createAllocation(selectedPlan, data.masters),
                            icon: _submitting
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.send_rounded),
                            label: Text(_submitting ? '배정 요청 중...' : '배정 요청 등록'),
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
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '배정 확정 시 출하가 자동 생성되어 이후 출하/배차 화면으로 이어집니다.',
                          style: Theme.of(
                            context,
                          ).textTheme.bodySmall?.copyWith(color: AppTheme.muted),
                        ),
                      ],
                    ],
                  ),
                );

                final allocationsPanel = DataPanel(
                  title: '배정 요청 보드',
                  subtitle: '요청, 확정, 출하 생성까지 배정 단계의 상태를 한 곳에서 확인합니다.',
                  trailing: _CountChip(label: '총 ${allocations.length}건'),
                  child: allocations.isEmpty
                      ? const _EmptyState(
                          title: '등록된 배정 요청이 없습니다.',
                          body: '왼쪽의 편성안을 선택해 첫 배정 요청을 등록해보세요.',
                        )
                      : Column(
                          children: [
                            for (final allocation in allocations) ...[
                              _AllocationCard(
                                allocation: allocation,
                                awarding:
                                    _awardingAllocationId == '${allocation['id']}',
                                onAward: () => _awardAllocation(allocation),
                              ),
                              const SizedBox(height: 14),
                            ],
                          ],
                        ),
                );

                if (stacked) {
                  return Column(
                    children: [
                      queuePanel,
                      const SizedBox(height: 18),
                      requestPanel,
                      const SizedBox(height: 18),
                      allocationsPanel,
                    ],
                  );
                }

                return Column(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 10, child: queuePanel),
                        const SizedBox(width: 18),
                        Expanded(flex: 12, child: requestPanel),
                      ],
                    ),
                    const SizedBox(height: 18),
                    allocationsPanel,
                  ],
                );
              },
            ),
          ],
        );
      },
    );
  }
}

class _AllocationWorkspaceData {
  const _AllocationWorkspaceData({
    required this.readyPlans,
    required this.allocations,
    required this.masters,
  });

  final Map<String, dynamic> readyPlans;
  final Map<String, dynamic> allocations;
  final Map<String, dynamic> masters;
}

class _ReadyPlanCard extends StatelessWidget {
  const _ReadyPlanCard({
    required this.plan,
    required this.selected,
    required this.onTap,
  });

  final Map<String, dynamic> plan;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFFF8F3E6)
              : Colors.white.withOpacity(0.9),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: selected ? AppTheme.copper : AppTheme.line,
            width: selected ? 1.3 : 1,
          ),
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
                  '${plan['plan_no']}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                _StatusChip(
                  label: TmsFormatters.status('${plan['status']}'),
                  color: AppTheme.copper,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${plan['name']}',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppTheme.ink,
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              '대상 오더  ${plan['order_summary']}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _InfoCard(
                  label: '중량',
                  value: TmsFormatters.weight(plan['total_weight_kg']),
                ),
                _InfoCard(
                  label: '부피',
                  value: TmsFormatters.volume(plan['total_volume_m3']),
                ),
                _InfoCard(
                  label: '거리',
                  value: TmsFormatters.distance(plan['total_distance_km']),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PlanSummaryCard extends StatelessWidget {
  const _PlanSummaryCard({required this.plan});

  final Map<String, dynamic> plan;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.wheat.withOpacity(0.44),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${plan['plan_no']}',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            '${plan['name']}',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: AppTheme.ink,
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            '오더  ${plan['order_summary']}',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _InfoCard(
                label: '출발 예정',
                value: TmsFormatters.dateTime(plan['planned_departure_at']),
              ),
              _InfoCard(
                label: '도착 예정',
                value: TmsFormatters.dateTime(plan['planned_arrival_at']),
              ),
              _InfoCard(
                label: '중량',
                value: TmsFormatters.weight(plan['total_weight_kg']),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AllocationCard extends StatelessWidget {
  const _AllocationCard({
    required this.allocation,
    required this.awarding,
    required this.onAward,
  });

  final Map<String, dynamic> allocation;
  final bool awarding;
  final VoidCallback onAward;

  @override
  Widget build(BuildContext context) {
    final status = '${allocation['status']}';
    final shipmentNo = allocation['shipment_no'];
    final hasShipment = shipmentNo != null && '$shipmentNo'.isNotEmpty && '$shipmentNo' != 'null';

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
                '${allocation['plan_no']}',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              _StatusChip(
                label: TmsFormatters.status(status),
                color: _statusColor(status),
              ),
              if (hasShipment)
                _StatusChip(
                  label: '출하 ${allocation['shipment_no']}',
                  color: AppTheme.pine,
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '${allocation['load_plan_name']}',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: AppTheme.ink,
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            '운송사  ${TmsFormatters.entity('${allocation['carrier_name'] ?? '미지정'}')}  ·  오더  ${allocation['order_summary']}',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _InfoCard(
                label: '목표 운임',
                value: TmsFormatters.money(allocation['target_rate']),
              ),
              _InfoCard(
                label: '제안 운임',
                value: TmsFormatters.money(allocation['quoted_rate']),
              ),
              _InfoCard(
                label: '유류할증',
                value: TmsFormatters.money(allocation['fuel_surcharge']),
              ),
              _InfoCard(
                label: '요청 시각',
                value: TmsFormatters.dateTime(allocation['allocated_at']),
              ),
            ],
          ),
          if ('${allocation['notes'] ?? ''}'.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              '${allocation['notes']}',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppTheme.muted),
            ),
          ],
          const SizedBox(height: 16),
          if (status == 'requested' || status == 'quoted')
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.icon(
                onPressed: awarding ? null : onAward,
                icon: awarding
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.verified_rounded),
                label: Text(awarding ? '배정 확정 중...' : '배정 확정 후 출하 생성'),
              ),
            )
          else
            Text(
              hasShipment
                  ? '배정 확정 후 출하가 생성되어 다음 단계로 전달됐습니다.'
                  : '배정 상태가 확정되어 추가 요청은 막혀 있습니다.',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppTheme.muted),
            ),
        ],
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'requested':
        return AppTheme.copper;
      case 'awarded':
        return AppTheme.pine;
      case 'quoted':
        return const Color(0xFF2B6CB0);
      default:
        return const Color(0xFF425466);
    }
  }
}

class _DropdownField extends StatelessWidget {
  const _DropdownField({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String label;
  final String? value;
  final List<DropdownMenuItem<String>> items;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      value: items.any((item) => item.value == value) ? value : null,
      decoration: InputDecoration(labelText: label),
      items: items,
      onChanged: items.isEmpty ? null : onChanged,
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 160),
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

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppTheme.wheat.withOpacity(0.34),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppTheme.muted),
          ),
        ],
      ),
    );
  }
}
