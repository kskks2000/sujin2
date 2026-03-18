import 'package:flutter/material.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/tms_formatters.dart';
import '../../../core/widgets/data_panel.dart';
import '../../../core/widgets/page_banner.dart';

class LoadPlansScreen extends StatefulWidget {
  const LoadPlansScreen({super.key});

  @override
  State<LoadPlansScreen> createState() => _LoadPlansScreenState();
}

class _LoadPlansScreenState extends State<LoadPlansScreen> {
  static const _blockedOrderStatuses = {'delivered', 'cancelled'};

  late final ApiClient _client;
  late Future<_LoadPlansScreenData> _future;
  final TextEditingController _nameController = TextEditingController(
    text: _defaultPlanName(),
  );
  final TextEditingController _notesController = TextEditingController();
  final Set<String> _selectedOrderIds = <String>{};

  String? _selectedCarrierId;
  String? _selectedEquipmentTypeId;
  String _transportMode = 'road';
  String _serviceLevel = 'standard';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _client = ApiClient();
    _future = _loadData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<_LoadPlansScreenData> _loadData() async {
    final responses = await Future.wait([
      _client.fetchLoadPlans(),
      _client.fetchOrders(),
      _client.fetchMasterSnapshot(),
    ]);

    return _LoadPlansScreenData(
      loadPlans: responses[0],
      orders: responses[1],
      masters: responses[2],
    );
  }

  void _refresh() {
    setState(() {
      _future = _loadData();
    });
  }

  void _resetDraft() {
    _nameController.text = _defaultPlanName();
    _notesController.clear();
    _selectedOrderIds.clear();
    _selectedCarrierId = null;
    _selectedEquipmentTypeId = null;
    _transportMode = 'road';
    _serviceLevel = 'standard';
  }

  Future<void> _createLoadPlan(_LoadPlansScreenData data) async {
    final selectableOrders = _candidateOrders(data.orders);
    final carrierId = _selectedCarrierId ?? _preferredCarrierId(data.masters);
    final equipmentTypeId =
        _selectedEquipmentTypeId ?? _preferredEquipmentTypeId(data.masters);
    final name = _nameController.text.trim();

    if (name.isEmpty) {
      _showMessage('편성안 이름을 입력해주세요.');
      return;
    }
    if (_selectedOrderIds.isEmpty) {
      _showMessage('편성할 오더를 한 건 이상 선택해주세요.');
      return;
    }
    if (selectableOrders.isEmpty) {
      _showMessage('편성 가능한 오더가 없습니다.');
      return;
    }

    final selectedOrders = selectableOrders
        .where((item) => _selectedOrderIds.contains('${item['id']}'))
        .toList();

    setState(() {
      _saving = true;
    });

    try {
      final saved = await _client.createLoadPlan({
        'name': name,
        'order_ids': selectedOrders.map((item) => '${item['id']}').toList(),
        'carrier_org_id': carrierId,
        'equipment_type_id': equipmentTypeId,
        'transport_mode': _transportMode,
        'service_level': _serviceLevel,
        'status': 'draft',
        'notes': _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
        'metadata': {
          'source': 'load_plans_screen',
          'selected_order_count': selectedOrders.length,
        },
      });

      if (!mounted) {
        return;
      }
      _showMessage('편성안 ${saved['plan_no']} 생성이 완료되었습니다.');
      setState(_resetDraft);
      _refresh();
    } catch (exception) {
      if (!mounted) {
        return;
      }
      _showMessage(exception.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  Future<void> _sendToAllocation(Map<String, dynamic> plan) async {
    final status = '${plan['status']}';
    if (!(status == 'draft' || status == 'planned')) {
      _showMessage('이 편성안은 이미 배정 단계에서 처리 중입니다.');
      return;
    }

    try {
      await _client.updateLoadPlanStatus('${plan['id']}', 'ready_for_allocation');
      if (!mounted) {
        return;
      }
      _showMessage('편성안 ${plan['plan_no']}을 배정 준비로 넘겼습니다.');
      _refresh();
    } catch (exception) {
      if (!mounted) {
        return;
      }
      _showMessage(exception.toString().replaceFirst('Exception: ', ''));
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  List<Map<String, dynamic>> _candidateOrders(Map<String, dynamic> orders) {
    final items = (orders['items'] as List?) ?? const [];
    return items
        .whereType<Map<String, dynamic>>()
        .where(
          (item) => !_blockedOrderStatuses.contains('${item['status']}'),
        )
        .toList();
  }

  String? _preferredCarrierId(Map<String, dynamic> masters) {
    final organizations = _carrierOrganizations(masters);
    for (final item in organizations) {
      if (item['code']?.toString().contains('CARRIER') ?? false) {
        return '${item['id']}';
      }
    }
    if (organizations.isEmpty) {
      return null;
    }
    return '${organizations.first['id']}';
  }

  List<Map<String, dynamic>> _carrierOrganizations(Map<String, dynamic> masters) {
    final carriers = (masters['carrier_organizations'] as List?) ?? const [];
    final organizations = (masters['organizations'] as List?) ?? const [];
    final source = carriers.isNotEmpty ? carriers : organizations;
    return source.whereType<Map<String, dynamic>>().toList();
  }

  String? _preferredEquipmentTypeId(Map<String, dynamic> masters) {
    final equipmentTypes = (masters['equipment_types'] as List?) ?? const [];
    for (final item in equipmentTypes) {
      if (item is Map && item['code']?.toString() == 'WING') {
        return '${item['id']}';
      }
    }
    if (equipmentTypes.isEmpty) {
      return null;
    }
    return '${(equipmentTypes.first as Map)['id']}';
  }

  num _selectedWeight(List<Map<String, dynamic>> selectedOrders) {
    return selectedOrders.fold<num>(
      0,
      (sum, item) => sum + _toNum(item['total_weight_kg']),
    );
  }

  num _selectedVolume(List<Map<String, dynamic>> selectedOrders) {
    return selectedOrders.fold<num>(
      0,
      (sum, item) => sum + _toNum(item['total_volume_m3']),
    );
  }

  num _toNum(dynamic value) {
    if (value is num) {
      return value;
    }
    return num.tryParse('$value') ?? 0;
  }

  static String _defaultPlanName() {
    final now = DateTime.now();
    return '상차 편성 ${now.month}/${now.day} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_LoadPlansScreenData>(
      future: _future,
      builder: (context, snapshot) {
        final data = snapshot.data;
        final plans = (data?.loadPlans['items'] as List?) ?? const [];
        final candidateOrders =
            data == null ? const <Map<String, dynamic>>[] : _candidateOrders(data.orders);
        final selectedOrders = candidateOrders
            .where((item) => _selectedOrderIds.contains('${item['id']}'))
            .toList();
        final selectedCarrierId =
            _selectedCarrierId ?? (data == null ? null : _preferredCarrierId(data.masters));
        final selectedEquipmentTypeId =
            _selectedEquipmentTypeId ??
            (data == null ? null : _preferredEquipmentTypeId(data.masters));

        return ListView(
          children: [
            PageBanner(
              eyebrow: '편성 운영',
              title: '편성(상차조합) 처리',
              description:
                  '오더를 묶어 상차 조합을 만들고, 중량과 CBM을 한 눈에 보면서 간선 편성안을 빠르게 준비할 수 있습니다.',
              leading: const _SectionLead(
                icon: Icons.hub_rounded,
                label: '편성 운영',
              ),
              details: [
                BannerDetail(label: '전체 편성안', value: '${plans.length}건'),
                BannerDetail(
                  label: '초안',
                  value:
                      '${TmsFormatters.countMatching(plans, 'status', 'draft')}건',
                ),
                BannerDetail(
                  label: '계획',
                  value:
                      '${TmsFormatters.countMatching(plans, 'status', 'planned')}건',
                ),
                BannerDetail(
                  label: '배정준비',
                  value:
                      '${TmsFormatters.countMatching(plans, 'status', 'ready_for_allocation')}건',
                ),
              ],
            ),
            const SizedBox(height: 22),
            LayoutBuilder(
              builder: (context, constraints) {
                final stacked = constraints.maxWidth < 1180;
                final board = DataPanel(
                  title: '편성안 보드',
                  subtitle: '현재 저장된 상차조합 계획과 준비 상태를 보여줍니다.',
                  trailing: _CountChip(label: '총 ${plans.length}건'),
                  child: plans.isEmpty
                      ? const _EmptyState(
                          title: '저장된 편성안이 없습니다.',
                          body: '오른쪽 패널에서 오더를 선택해 첫 편성안을 생성해보세요.',
                        )
                      : Column(
                          children: [
                            for (final item in plans.whereType<Map<String, dynamic>>()) ...[
                              _LoadPlanCard(
                                item: item,
                                onSendToAllocation: () => _sendToAllocation(item),
                              ),
                              const SizedBox(height: 14),
                            ],
                          ],
                        ),
                );
                final builder = DataPanel(
                  title: '새 편성안 만들기',
                  subtitle:
                      '편성 대상 오더를 선택하면 중량과 부피를 바로 합산해 초안 편성안을 생성합니다.',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: '편성안 이름',
                          hintText: '예: 부산 허브 익일 상차 편성',
                        ),
                      ),
                      const SizedBox(height: 14),
                      LayoutBuilder(
                        builder: (context, innerConstraints) {
                          final stackedInner = innerConstraints.maxWidth < 720;
                          final carrierField = _DropdownField(
                            label: '운송사',
                            value: selectedCarrierId,
                            items: (data == null
                                    ? const <Map<String, dynamic>>[]
                                    : _carrierOrganizations(data.masters))
                                .map(
                                  (item) => DropdownMenuItem<String>(
                                    value: '${item['id']}',
                                    child: Text(TmsFormatters.entity('${item['name']}')),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) {
                              setState(() {
                                _selectedCarrierId = value;
                              });
                            },
                          );
                          final equipmentField = _DropdownField(
                            label: '차종',
                            value: selectedEquipmentTypeId,
                            items: ((data?.masters['equipment_types'] as List?) ?? const [])
                                .whereType<Map<String, dynamic>>()
                                .map(
                                  (item) => DropdownMenuItem<String>(
                                    value: '${item['id']}',
                                    child: Text('${item['name']}'),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) {
                              setState(() {
                                _selectedEquipmentTypeId = value;
                              });
                            },
                          );

                          if (stackedInner) {
                            return Column(
                              children: [
                                carrierField,
                                const SizedBox(height: 14),
                                equipmentField,
                              ],
                            );
                          }

                          return Row(
                            children: [
                              Expanded(child: carrierField),
                              const SizedBox(width: 12),
                              Expanded(child: equipmentField),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 14),
                      LayoutBuilder(
                        builder: (context, innerConstraints) {
                          final stackedInner = innerConstraints.maxWidth < 720;
                          final modeField = _DropdownField(
                            label: '운송 모드',
                            value: _transportMode,
                            items: const [
                              DropdownMenuItem(value: 'road', child: Text('Road')),
                              DropdownMenuItem(
                                value: 'intermodal',
                                child: Text('Intermodal'),
                              ),
                              DropdownMenuItem(value: 'rail', child: Text('Rail')),
                            ],
                            onChanged: (value) {
                              if (value == null) {
                                return;
                              }
                              setState(() {
                                _transportMode = value;
                              });
                            },
                          );
                          final serviceField = _DropdownField(
                            label: '서비스 레벨',
                            value: _serviceLevel,
                            items: const [
                              DropdownMenuItem(
                                value: 'standard',
                                child: Text('Standard'),
                              ),
                              DropdownMenuItem(
                                value: 'express',
                                child: Text('Express'),
                              ),
                              DropdownMenuItem(
                                value: 'same_day',
                                child: Text('Same Day'),
                              ),
                            ],
                            onChanged: (value) {
                              if (value == null) {
                                return;
                              }
                              setState(() {
                                _serviceLevel = value;
                              });
                            },
                          );

                          if (stackedInner) {
                            return Column(
                              children: [
                                modeField,
                                const SizedBox(height: 14),
                                serviceField,
                              ],
                            );
                          }

                          return Row(
                            children: [
                              Expanded(child: modeField),
                              const SizedBox(width: 12),
                              Expanded(child: serviceField),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: _notesController,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: '메모',
                          hintText: '웨이브 편성 기준, 특이사항, 냉장/냉동 지시 등을 기록합니다.',
                        ),
                      ),
                      const SizedBox(height: 18),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          _SummaryTile(
                            label: '선택 오더',
                            value: '${selectedOrders.length}건',
                          ),
                          _SummaryTile(
                            label: '총중량',
                            value: TmsFormatters.weight(
                              _selectedWeight(selectedOrders),
                            ),
                          ),
                          _SummaryTile(
                            label: '총부피',
                            value: TmsFormatters.volume(
                              _selectedVolume(selectedOrders),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Text(
                        '편성 대상 오더',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '배송완료/취소를 제외한 오더만 편성 대상으로 보여줍니다.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppTheme.muted,
                            ),
                      ),
                      const SizedBox(height: 14),
                      if (candidateOrders.isEmpty)
                        const _EmptyState(
                          title: '편성 가능한 오더가 없습니다.',
                          body: '오더가 생성되면 여기에서 선택해 상차 조합을 만들 수 있습니다.',
                        )
                      else
                        Column(
                          children: [
                            for (final order in candidateOrders) ...[
                              _SelectableOrderCard(
                                order: order,
                                selected:
                                    _selectedOrderIds.contains('${order['id']}'),
                                onChanged: (selected) {
                                  setState(() {
                                    final orderId = '${order['id']}';
                                    if (selected) {
                                      _selectedOrderIds.add(orderId);
                                    } else {
                                      _selectedOrderIds.remove(orderId);
                                    }
                                  });
                                },
                              ),
                              const SizedBox(height: 10),
                            ],
                          ],
                        ),
                      const SizedBox(height: 18),
                      Text(
                        '출발/도착 계획 시각은 이후 배차 단계에서 더 정교하게 보강할 수 있도록 우선 초안 편성 중심으로 저장합니다.',
                        style: Theme.of(
                          context,
                        ).textTheme.bodySmall?.copyWith(color: AppTheme.muted),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _saving || data == null
                              ? null
                              : () => _createLoadPlan(data),
                          icon: _saving
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.hub_rounded),
                          label: Text(_saving ? '편성안 생성 중...' : '편성안 생성'),
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
                    ],
                  ),
                );

                if (stacked) {
                  return Column(
                    children: [
                      board,
                      const SizedBox(height: 18),
                      builder,
                    ],
                  );
                }

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 11, child: board),
                    const SizedBox(width: 18),
                    Expanded(flex: 12, child: builder),
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

class _LoadPlansScreenData {
  const _LoadPlansScreenData({
    required this.loadPlans,
    required this.orders,
    required this.masters,
  });

  final Map<String, dynamic> loadPlans;
  final Map<String, dynamic> orders;
  final Map<String, dynamic> masters;
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

class _LoadPlanCard extends StatelessWidget {
  const _LoadPlanCard({
    required this.item,
    required this.onSendToAllocation,
  });

  final Map<String, dynamic> item;
  final VoidCallback onSendToAllocation;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.88),
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
                '${item['plan_no']}',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              _StatusChip(
                label: TmsFormatters.status('${item['status']}'),
                color: _statusColor('${item['status']}'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '${item['name']}',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: AppTheme.ink,
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            '대상 오더  ${item['order_summary']}',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppTheme.ink,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            "운송사  ${TmsFormatters.entity('${item['carrier_name'] ?? '미지정'}')}  ·  차종  ${item['equipment_type_name'] ?? '미지정'}",
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _InfoCard(
                label: '출발 예정',
                value: TmsFormatters.dateTime(item['planned_departure_at']),
              ),
              _InfoCard(
                label: '도착 예정',
                value: TmsFormatters.dateTime(item['planned_arrival_at']),
              ),
              _InfoCard(
                label: '총중량',
                value: TmsFormatters.weight(item['total_weight_kg']),
              ),
              _InfoCard(
                label: '총부피',
                value: TmsFormatters.volume(item['total_volume_m3']),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if ('${item['status']}' == 'draft' || '${item['status']}' == 'planned')
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: onSendToAllocation,
                icon: const Icon(Icons.forward_to_inbox_rounded),
                label: const Text('배정준비로 넘기기'),
              ),
            )
          else
            Text(
              '${TmsFormatters.status('${item['status']}')} 단계에서 후속 처리가 이어집니다.',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppTheme.muted),
            ),
        ],
      ),
    );
  }

  Color _statusColor(String value) {
    switch (value) {
      case 'ready_for_allocation':
        return AppTheme.copper;
      case 'planned':
        return AppTheme.pine;
      default:
        return const Color(0xFF425466);
    }
  }
}

class _SelectableOrderCard extends StatelessWidget {
  const _SelectableOrderCard({
    required this.order,
    required this.selected,
    required this.onChanged,
  });

  final Map<String, dynamic> order;
  final bool selected;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: () => onChanged(!selected),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFFF8F3E6)
              : Colors.white.withOpacity(0.88),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: selected ? AppTheme.copper : AppTheme.line,
            width: selected ? 1.3 : 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Checkbox(
              value: selected,
              onChanged: (value) => onChanged(value ?? false),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      Text(
                        '${order['order_no']}',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      _StatusChip(
                        label: TmsFormatters.status('${order['status']}'),
                        color: const Color(0xFF425466),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    TmsFormatters.entity('${order['customer_name']}'),
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: AppTheme.ink,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '픽업  ${TmsFormatters.dateTime(order['planned_pickup_from'])}  ·  도착  ${TmsFormatters.dateTime(order['planned_delivery_to'])}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _MetricPill(
                        label: '중량',
                        value: TmsFormatters.weight(order['total_weight_kg']),
                      ),
                      _MetricPill(
                        label: '부피',
                        value: TmsFormatters.volume(order['total_volume_m3']),
                      ),
                      _MetricPill(
                        label: '우선순위',
                        value: '${order['priority']}',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricPill extends StatelessWidget {
  const _MetricPill({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.wheat.withOpacity(0.48),
        borderRadius: BorderRadius.circular(16),
      ),
      child: RichText(
        text: TextSpan(
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: AppTheme.ink),
          children: [
            TextSpan(
              text: '$label  ',
              style: TextStyle(color: AppTheme.muted),
            ),
            TextSpan(
              text: value,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 150),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.82),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
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
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppTheme.ink,
                  fontWeight: FontWeight.w800,
                ),
          ),
        ],
      ),
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
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.72),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppTheme.ink,
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 8),
          Text(body, style: Theme.of(context).textTheme.bodyMedium),
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
              fontWeight: FontWeight.w700,
            ),
      ),
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

class _CountChip extends StatelessWidget {
  const _CountChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.copper.withOpacity(0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: AppTheme.copper,
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
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.12),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Icon(icon, color: Colors.white),
        ),
        const SizedBox(width: 14),
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
