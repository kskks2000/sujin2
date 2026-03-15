import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/tms_formatters.dart';

class OrderEditorDialog extends StatefulWidget {
  const OrderEditorDialog({
    super.key,
    required this.client,
    required this.masters,
    this.existingOrder,
  });

  final ApiClient client;
  final Map<String, dynamic> masters;
  final Map<String, dynamic>? existingOrder;

  bool get isEdit => existingOrder != null;

  @override
  State<OrderEditorDialog> createState() => _OrderEditorDialogState();
}

class _OrderEditorDialogState extends State<OrderEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  final _referenceController = TextEditingController();
  final _cargoController = TextEditingController(text: '일반 화물');
  final _weightController = TextEditingController(text: '1000');
  final _volumeController = TextEditingController(text: '10');
  final _quantityController = TextEditingController(text: '1');
  final _palletController = TextEditingController(text: '0');
  final _notesController = TextEditingController();

  late String _customerOrgId;
  late String _shipperOrgId;
  late String _billToOrgId;
  late String _pickupLocationId;
  late String _deliveryLocationId;
  String _requestedMode = 'road';
  String _serviceLevel = 'standard';
  String _status = 'planned';
  int _priority = 3;
  DateTime? _pickupAt;
  DateTime? _deliveryAt;
  bool _saving = false;
  String? _errorMessage;

  List<Map<String, dynamic>> get _organizations =>
      _normalizeOptions(widget.masters['organizations']);

  List<Map<String, dynamic>> get _locations =>
      _normalizeOptions(widget.masters['locations']);

  @override
  void initState() {
    super.initState();
    _hydrateInitialValues();
  }

  @override
  void dispose() {
    _referenceController.dispose();
    _cargoController.dispose();
    _weightController.dispose();
    _volumeController.dispose();
    _quantityController.dispose();
    _palletController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _hydrateInitialValues() {
    final organizations = _organizations;
    final locations = _locations;
    final existing = widget.existingOrder;

    final defaultCustomer = _findOptionId(organizations, 'SUJIN_WAREHOUSE') ??
        (organizations.isNotEmpty ? '${organizations.first['id']}' : '');
    final defaultShipper = _findOptionId(organizations, 'SUJIN_SHIPPER') ??
        (organizations.isNotEmpty ? '${organizations.first['id']}' : '');
    final defaultBillTo =
        _findOptionId(organizations, 'SUJIN_BILLTO') ?? defaultCustomer;
    final defaultPickup = _findOptionId(locations, 'ICHEON_DC') ??
        (locations.isNotEmpty ? '${locations.first['id']}' : '');
    final defaultDelivery = _findOptionId(locations, 'BUSAN_HUB') ??
        (locations.isNotEmpty ? '${locations.last['id']}' : '');

    _customerOrgId = '${existing?['customer_org_id'] ?? defaultCustomer}';
    _shipperOrgId = '${existing?['shipper_org_id'] ?? defaultShipper}';
    _billToOrgId = '${existing?['bill_to_org_id'] ?? defaultBillTo}';
    _requestedMode = '${existing?['requested_mode'] ?? 'road'}';
    _serviceLevel = '${existing?['service_level'] ?? 'standard'}';
    _status = '${existing?['status'] ?? 'planned'}';
    _priority = existing?['priority'] as int? ?? 3;
    _referenceController.text = '${existing?['customer_reference'] ?? ''}';
    _notesController.text = '${existing?['notes'] ?? ''}';

    final lines = _normalizeOptions(existing?['lines']);
    if (lines.isNotEmpty) {
      final firstLine = lines.first;
      _cargoController.text = '${firstLine['description'] ?? '일반 화물'}';
      _weightController.text =
          '${firstLine['weight_kg'] ?? existing?['total_weight_kg'] ?? 0}';
      _volumeController.text =
          '${firstLine['volume_m3'] ?? existing?['total_volume_m3'] ?? 0}';
      _quantityController.text = '${firstLine['quantity'] ?? 1}';
      _palletController.text = '${firstLine['pallet_count'] ?? 0}';
    } else if (existing != null) {
      _weightController.text = '${existing['total_weight_kg'] ?? 0}';
      _volumeController.text = '${existing['total_volume_m3'] ?? 0}';
    }

    final stops = _normalizeOptions(existing?['stops']);
    final pickupStop = _findStop(stops, 'pickup');
    final deliveryStop = _findStop(stops, 'delivery');

    _pickupLocationId = '${pickupStop?['location_id'] ?? defaultPickup}';
    _deliveryLocationId = '${deliveryStop?['location_id'] ?? defaultDelivery}';
    _pickupAt = _parseDateTime(
      pickupStop?['planned_arrival_from'] ?? existing?['planned_pickup_from'],
    );
    _deliveryAt = _parseDateTime(
      deliveryStop?['planned_arrival_to'] ?? existing?['planned_delivery_to'],
    );

    final now = DateTime.now();
    _pickupAt ??= DateTime(now.year, now.month, now.day, now.hour + 1);
    _deliveryAt ??= _pickupAt!.add(const Duration(hours: 10));
  }

  @override
  Widget build(BuildContext context) {
    final organizations = _organizations;
    final locations = _locations;

    return Container(
      constraints: const BoxConstraints(maxWidth: 980),
      decoration: BoxDecoration(
        color: AppTheme.shell,
        borderRadius: BorderRadius.circular(32),
      ),
      padding: const EdgeInsets.all(24),
      child: organizations.isEmpty || locations.isEmpty
          ? _MissingMasterData(onClose: () => Navigator.of(context).pop())
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.isEdit ? '운송오더 상세 / 수정' : '운송오더 등록',
                            style: Theme.of(context).textTheme.headlineMedium,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            widget.isEdit
                                ? '오더번호 ${widget.existingOrder?['order_no'] ?? '-'}를 수정할 수 있습니다.'
                                : '고객, 상차지, 하차지, 예정 시간을 입력하면 바로 오더가 생성됩니다.',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed:
                          _saving ? null : () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Flexible(
                  child: SingleChildScrollView(
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _SectionTitle(
                            title: '기본 정보',
                            subtitle: '고객사와 청구처, 운송 우선순위를 설정합니다.',
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: [
                              _fieldBox(
                                _DropdownField(
                                  label: '고객사',
                                  value: _customerOrgId,
                                  items: organizations,
                                  onChanged: (value) {
                                    if (value == null) return;
                                    setState(() => _customerOrgId = value);
                                  },
                                ),
                              ),
                              _fieldBox(
                                _DropdownField(
                                  label: '출하처',
                                  value: _shipperOrgId,
                                  items: organizations,
                                  onChanged: (value) {
                                    if (value == null) return;
                                    setState(() => _shipperOrgId = value);
                                  },
                                ),
                              ),
                              _fieldBox(
                                _DropdownField(
                                  label: '청구처',
                                  value: _billToOrgId,
                                  items: organizations,
                                  onChanged: (value) {
                                    if (value == null) return;
                                    setState(() => _billToOrgId = value);
                                  },
                                ),
                              ),
                              _fieldBox(
                                TextFormField(
                                  controller: _referenceController,
                                  decoration: const InputDecoration(
                                    labelText: '고객 참조번호',
                                  ),
                                ),
                              ),
                              _fieldBox(
                                DropdownButtonFormField<int>(
                                  value: _priority,
                                  decoration: const InputDecoration(
                                    labelText: '우선순위',
                                  ),
                                  items: const [1, 2, 3, 4, 5]
                                      .map(
                                        (value) => DropdownMenuItem(
                                          value: value,
                                          child: Text('우선순위 $value'),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (value) {
                                    if (value == null) return;
                                    setState(() => _priority = value);
                                  },
                                ),
                              ),
                              _fieldBox(
                                DropdownButtonFormField<String>(
                                  value: _status,
                                  decoration: const InputDecoration(
                                    labelText: '오더 상태',
                                  ),
                                  items: const [
                                    DropdownMenuItem(
                                        value: 'draft', child: Text('초안')),
                                    DropdownMenuItem(
                                        value: 'planned', child: Text('계획')),
                                    DropdownMenuItem(
                                        value: 'confirmed', child: Text('확정')),
                                    DropdownMenuItem(
                                      value: 'in_transit',
                                      child: Text('운송중'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'delivered',
                                      child: Text('배송완료'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'cancelled',
                                      child: Text('취소'),
                                    ),
                                  ],
                                  onChanged: (value) {
                                    if (value == null) return;
                                    setState(() => _status = value);
                                  },
                                ),
                              ),
                              _fieldBox(
                                DropdownButtonFormField<String>(
                                  value: _requestedMode,
                                  decoration: const InputDecoration(
                                    labelText: '운송 모드',
                                  ),
                                  items: const [
                                    DropdownMenuItem(
                                        value: 'road', child: Text('도로')),
                                    DropdownMenuItem(
                                        value: 'rail', child: Text('철도')),
                                    DropdownMenuItem(
                                        value: 'sea', child: Text('해상')),
                                    DropdownMenuItem(
                                        value: 'air', child: Text('항공')),
                                    DropdownMenuItem(
                                      value: 'intermodal',
                                      child: Text('복합운송'),
                                    ),
                                  ],
                                  onChanged: (value) {
                                    if (value == null) return;
                                    setState(() => _requestedMode = value);
                                  },
                                ),
                              ),
                              _fieldBox(
                                DropdownButtonFormField<String>(
                                  value: _serviceLevel,
                                  decoration: const InputDecoration(
                                    labelText: '서비스 레벨',
                                  ),
                                  items: const [
                                    DropdownMenuItem(
                                      value: 'standard',
                                      child: Text('표준'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'express',
                                      child: Text('급행'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'same_day',
                                      child: Text('당일'),
                                    ),
                                  ],
                                  onChanged: (value) {
                                    if (value == null) return;
                                    setState(() => _serviceLevel = value);
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          _SectionTitle(
                            title: '운행 일정',
                            subtitle: '상차지와 하차지, 예정 시간을 입력합니다.',
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: [
                              _fieldBox(
                                _DropdownField(
                                  label: '상차지',
                                  value: _pickupLocationId,
                                  items: locations,
                                  onChanged: (value) {
                                    if (value == null) return;
                                    setState(() => _pickupLocationId = value);
                                  },
                                ),
                              ),
                              _fieldBox(
                                _DropdownField(
                                  label: '하차지',
                                  value: _deliveryLocationId,
                                  items: locations,
                                  onChanged: (value) {
                                    if (value == null) return;
                                    setState(() => _deliveryLocationId = value);
                                  },
                                ),
                              ),
                              _fieldBox(
                                _DateTimeField(
                                  label: '상차 예정',
                                  value: _pickupAt,
                                  onTap: () => _pickDateTime(isPickup: true),
                                ),
                              ),
                              _fieldBox(
                                _DateTimeField(
                                  label: '하차 예정',
                                  value: _deliveryAt,
                                  onTap: () => _pickDateTime(isPickup: false),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          _SectionTitle(
                            title: '화물 정보',
                            subtitle: '기본 화물 라인을 함께 등록합니다.',
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: [
                              _fieldBox(
                                TextFormField(
                                  controller: _cargoController,
                                  decoration: const InputDecoration(
                                    labelText: '화물 설명',
                                  ),
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) {
                                      return '화물 설명을 입력해 주세요.';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                              _fieldBox(
                                TextFormField(
                                  controller: _quantityController,
                                  decoration:
                                      const InputDecoration(labelText: '수량'),
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                          decimal: true),
                                  validator: (value) {
                                    final parsed = double.tryParse(value ?? '');
                                    if (parsed == null || parsed <= 0) {
                                      return '수량을 입력해 주세요.';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                              _fieldBox(
                                TextFormField(
                                  controller: _weightController,
                                  decoration: const InputDecoration(
                                    labelText: '총중량(kg)',
                                  ),
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                          decimal: true),
                                  validator: (value) {
                                    final parsed = double.tryParse(value ?? '');
                                    if (parsed == null || parsed < 0) {
                                      return '중량을 확인해 주세요.';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                              _fieldBox(
                                TextFormField(
                                  controller: _volumeController,
                                  decoration: const InputDecoration(
                                    labelText: '체적(m³)',
                                  ),
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                          decimal: true),
                                  validator: (value) {
                                    final parsed = double.tryParse(value ?? '');
                                    if (parsed == null || parsed < 0) {
                                      return '체적을 확인해 주세요.';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                              _fieldBox(
                                TextFormField(
                                  controller: _palletController,
                                  decoration: const InputDecoration(
                                    labelText: '파렛트 수량',
                                  ),
                                  keyboardType: TextInputType.number,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _notesController,
                            minLines: 3,
                            maxLines: 4,
                            decoration: const InputDecoration(
                              labelText: '비고',
                              alignLabelWithHint: true,
                            ),
                          ),
                          if (_errorMessage != null) ...[
                            const SizedBox(height: 16),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFCE8E6),
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: Text(
                                _errorMessage!,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(
                                      color: const Color(0xFFB3261E),
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed:
                            _saving ? null : () => Navigator.of(context).pop(),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                        child: const Text('닫기'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _saving ? null : _submit,
                        icon: _saving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.check_rounded),
                        label: Text(widget.isEdit ? '수정 저장' : '오더 등록'),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppTheme.copper,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
    );
  }

  Widget _fieldBox(Widget child) => SizedBox(width: 280, child: child);

  Future<void> _pickDateTime({required bool isPickup}) async {
    final initial = isPickup
        ? (_pickupAt ?? DateTime.now())
        : (_deliveryAt ??
            (_pickupAt ?? DateTime.now()).add(const Duration(hours: 8)));
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2025, 1, 1),
      lastDate: DateTime(2030, 12, 31),
    );
    if (date == null || !mounted) {
      return;
    }
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null) {
      return;
    }

    final picked = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );

    setState(() {
      if (isPickup) {
        _pickupAt = picked;
        _deliveryAt ??= picked.add(const Duration(hours: 8));
      } else {
        _deliveryAt = picked;
      }
    });
  }

  Future<void> _submit() async {
    final valid = _formKey.currentState?.validate() ?? false;
    if (!valid) {
      return;
    }
    if (_pickupAt == null || _deliveryAt == null) {
      setState(() {
        _errorMessage = '상차 예정과 하차 예정 시간을 모두 선택해 주세요.';
      });
      return;
    }
    if (_deliveryAt!.isBefore(_pickupAt!)) {
      setState(() {
        _errorMessage = '하차 예정 시간은 상차 예정 시간보다 늦어야 합니다.';
      });
      return;
    }

    setState(() {
      _saving = true;
      _errorMessage = null;
    });

    final weight = double.tryParse(_weightController.text.trim()) ?? 0;
    final volume = double.tryParse(_volumeController.text.trim()) ?? 0;
    final quantity = double.tryParse(_quantityController.text.trim()) ?? 1;
    final pallets = int.tryParse(_palletController.text.trim()) ?? 0;
    final pickupIso = _toApiTimestamp(_pickupAt!);
    final deliveryIso = _toApiTimestamp(_deliveryAt!);

    final payload = {
      'customer_org_id': _customerOrgId,
      'shipper_org_id': _shipperOrgId,
      'bill_to_org_id': _billToOrgId,
      'requested_mode': _requestedMode,
      'service_level': _serviceLevel,
      'status': _status,
      'priority': _priority,
      'customer_reference': _referenceController.text.trim().isEmpty
          ? null
          : _referenceController.text.trim(),
      'planned_pickup_from': pickupIso,
      'planned_pickup_to': pickupIso,
      'planned_delivery_from': deliveryIso,
      'planned_delivery_to': deliveryIso,
      'total_weight_kg': weight,
      'total_volume_m3': volume,
      'notes': _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
      'metadata': widget.existingOrder?['metadata'] ?? <String, dynamic>{},
      'lines': [
        {
          'description': _cargoController.text.trim(),
          'quantity': quantity,
          'weight_kg': weight,
          'volume_m3': volume,
          'pallet_count': pallets,
          'sku': null,
          'package_type': 'box',
          'metadata': <String, dynamic>{},
        },
      ],
      'stops': [
        {
          'location_id': _pickupLocationId,
          'stop_type': 'pickup',
          'planned_arrival_from': pickupIso,
          'planned_arrival_to': pickupIso,
          'contact_name': null,
          'contact_phone': null,
          'notes': widget.isEdit ? '상세 화면에서 수정' : '운송오더 등록 화면에서 생성',
        },
        {
          'location_id': _deliveryLocationId,
          'stop_type': 'delivery',
          'planned_arrival_from': deliveryIso,
          'planned_arrival_to': deliveryIso,
          'contact_name': null,
          'contact_phone': null,
          'notes': widget.isEdit ? '상세 화면에서 수정' : '운송오더 등록 화면에서 생성',
        },
      ],
    };

    try {
      final saved = widget.isEdit
          ? await widget.client
              .updateOrder('${widget.existingOrder?['id']}', payload)
          : await widget.client.createOrder(payload);
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(saved);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = error.toString().replaceFirst('Exception: ', '');
        _saving = false;
      });
      return;
    }

    if (mounted) {
      setState(() {
        _saving = false;
      });
    }
  }

  List<Map<String, dynamic>> _normalizeOptions(dynamic raw) {
    final items = raw as List? ?? const [];
    return items
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  String? _findOptionId(List<Map<String, dynamic>> items, String code) {
    for (final item in items) {
      if ('${item['code']}' == code) {
        return '${item['id']}';
      }
    }
    return null;
  }

  Map<String, dynamic>? _findStop(
      List<Map<String, dynamic>> stops, String stopType) {
    for (final stop in stops) {
      if ('${stop['stop_type']}' == stopType) {
        return stop;
      }
    }
    return null;
  }

  DateTime? _parseDateTime(dynamic value) {
    final raw = value?.toString();
    if (raw == null || raw.isEmpty || raw == 'null') {
      return null;
    }
    return DateTime.tryParse(raw)?.toLocal();
  }

  String _toApiTimestamp(DateTime value) {
    final offset = value.timeZoneOffset;
    final sign = offset.isNegative ? '-' : '+';
    final hours = offset.inHours.abs().toString().padLeft(2, '0');
    final minutes = (offset.inMinutes.abs() % 60).toString().padLeft(2, '0');
    final local = DateFormat("yyyy-MM-dd'T'HH:mm:ss").format(value);
    return '$local$sign$hours:$minutes';
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
  final String value;
  final List<Map<String, dynamic>> items;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      value: value.isEmpty ? null : value,
      decoration: InputDecoration(labelText: label),
      items: items
          .map(
            (item) => DropdownMenuItem(
              value: '${item['id']}',
              child: Text(TmsFormatters.entity('${item['name']}')),
            ),
          )
          .toList(),
      onChanged: onChanged,
    );
  }
}

class _DateTimeField extends StatelessWidget {
  const _DateTimeField({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final DateTime? value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: const Icon(Icons.schedule_rounded),
        ),
        child: Text(
          value == null
              ? '일시를 선택해 주세요'
              : DateFormat('M월 d일 HH:mm').format(value!),
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: value == null ? AppTheme.muted : AppTheme.ink,
                fontWeight: value == null ? FontWeight.w500 : FontWeight.w700,
              ),
        ),
      ),
    );
  }
}

class _MissingMasterData extends StatelessWidget {
  const _MissingMasterData({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('마스터 데이터가 없습니다', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 10),
          Text(
            '운송오더 등록에 필요한 거래처 또는 거점 데이터가 로드되지 않았습니다.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 20),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(
              onPressed: onClose,
              child: const Text('닫기'),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 4),
        Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
      ],
    );
  }
}
