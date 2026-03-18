class DemoPayloads {
  static Map<String, dynamic> dashboardSnapshot() {
    return {
      'metrics': [
        {'label': 'Open Orders', 'value': 3, 'accent': 'amber'},
        {'label': 'Active Shipments', 'value': 2, 'accent': 'teal'},
        {'label': 'Active Dispatches', 'value': 2, 'accent': 'crimson'},
        {'label': 'AR Total', 'value': 2505000, 'accent': 'copper'},
      ],
      'order_statuses': [
        {'status': 'delivered', 'count': 1},
        {'status': 'in_transit', 'count': 1},
        {'status': 'planned', 'count': 1},
        {'status': 'confirmed', 'count': 1},
        {'status': 'cancelled', 'count': 1},
      ],
      'shipment_statuses': [
        {'status': 'delivered', 'count': 1},
        {'status': 'in_transit', 'count': 1},
        {'status': 'dispatched', 'count': 1},
      ],
      'dispatch_statuses': [
        {'status': 'completed', 'count': 1},
        {'status': 'in_transit', 'count': 1},
        {'status': 'accepted', 'count': 1},
      ],
      'recent_events': [
        {
          'shipment_no': 'SHP-SAMPLE-0002',
          'event_type': 'gps_ping',
          'occurred_at': DateTime.now().toIso8601String(),
          'message': 'Mid-route ping with reefer unit stable',
        },
        {
          'shipment_no': 'SHP-SAMPLE-0001',
          'event_type': 'delivered',
          'occurred_at': DateTime.now()
              .subtract(const Duration(hours: 8))
              .toIso8601String(),
          'message': 'POD completed',
        },
      ],
      'dispatch_board': [
        {
          'shipment_no': 'SHP-SAMPLE-0002',
          'shipment_status': 'in_transit',
          'order_no': 'ORD-SAMPLE-0002 외 1건',
          'shipper_name': 'Sujin Electronics Hwaseong Plant',
          'carrier_name': 'Sujin Transport',
          'dispatch_no': 'DSP-SAMPLE-0002',
          'dispatch_status': 'in_transit',
          'driver_name': 'Park Jiyoon',
          'vehicle_plate_no': '81A5678',
          'next_stop_name': 'Busan Hub',
          'next_eta_from':
              DateTime.now().add(const Duration(hours: 12)).toIso8601String(),
          'next_eta_to':
              DateTime.now().add(const Duration(hours: 14)).toIso8601String(),
        },
      ],
    };
  }

  static Map<String, dynamic> orders() {
    return {
      'total': 5,
      'items': [
        {
          'id': '1',
          'order_no': 'ORD-SAMPLE-0001',
          'status': 'delivered',
          'priority': 1,
          'customer_reference': 'SO-DEL-0001',
          'customer_name': 'Sujin Electronics Hwaseong Plant',
          'planned_pickup_from': DateTime.now()
              .subtract(const Duration(days: 2))
              .toIso8601String(),
          'planned_delivery_to': DateTime.now()
              .subtract(const Duration(days: 1))
              .toIso8601String(),
          'total_weight_kg': 1840.5,
          'total_volume_m3': 14.2,
        },
        {
          'id': '2',
          'order_no': 'ORD-SAMPLE-0002',
          'status': 'in_transit',
          'priority': 1,
          'customer_reference': 'SO-TRN-0002',
          'customer_name': 'Sujin Central Warehouse',
          'planned_pickup_from': DateTime.now().toIso8601String(),
          'planned_delivery_to':
              DateTime.now().add(const Duration(days: 1)).toIso8601String(),
          'total_weight_kg': 920,
          'total_volume_m3': 10.5,
        },
      ],
    };
  }

  static Map<String, dynamic> shipments() {
    return {
      'total': 3,
      'items': [
        {
          'id': '1',
          'shipment_no': 'SHP-SAMPLE-0002',
          'status': 'in_transit',
          'order_no': 'ORD-SAMPLE-0002',
          'order_summary': 'ORD-SAMPLE-0002 외 1건',
          'order_count': 2,
          'order_ids': ['2', '3'],
          'order_nos': ['ORD-SAMPLE-0002', 'ORD-SAMPLE-0003'],
          'carrier_name': 'Sujin Transport',
          'planned_pickup_at': DateTime.now().toIso8601String(),
          'planned_delivery_at':
              DateTime.now().add(const Duration(days: 1)).toIso8601String(),
          'total_weight_kg': 920,
          'total_distance_km': 398.4,
        },
        {
          'id': '2',
          'shipment_no': 'SHP-SAMPLE-0003',
          'status': 'dispatched',
          'order_no': 'ORD-SAMPLE-0003',
          'order_summary': 'ORD-SAMPLE-0003',
          'order_count': 1,
          'order_ids': ['3'],
          'order_nos': ['ORD-SAMPLE-0003'],
          'carrier_name': 'Sujin Transport',
          'planned_pickup_at':
              DateTime.now().add(const Duration(days: 2)).toIso8601String(),
          'planned_delivery_at':
              DateTime.now().add(const Duration(days: 3)).toIso8601String(),
          'total_weight_kg': 2420,
          'total_distance_km': 431.8,
        },
      ],
    };
  }

  static Map<String, dynamic> loadPlans() {
    return {
      'total': 2,
      'items': [
        {
          'id': 'lp-1',
          'plan_no': 'LDP-SAMPLE-0001',
          'name': '냉동 상품 부산 허브 편성',
          'status': 'planned',
          'order_ids': ['2', '3'],
          'order_nos': ['ORD-SAMPLE-0002', 'ORD-SAMPLE-0003'],
          'order_count': 2,
          'order_summary': 'ORD-SAMPLE-0002 외 1건',
          'carrier_name': 'Sujin Transport',
          'equipment_type_name': 'Reefer',
          'planned_departure_at': DateTime.now()
              .add(const Duration(hours: 10))
              .toIso8601String(),
          'planned_arrival_at': DateTime.now()
              .add(const Duration(days: 1, hours: 5))
              .toIso8601String(),
          'total_weight_kg': 3340,
          'total_volume_m3': 32.4,
          'total_distance_km': 404.2,
        },
        {
          'id': 'lp-2',
          'plan_no': 'LDP-SAMPLE-0002',
          'name': '화성 출고 익일 간선 편성',
          'status': 'ready_for_allocation',
          'order_ids': ['4'],
          'order_nos': ['ORD-SAMPLE-0004'],
          'order_count': 1,
          'order_summary': 'ORD-SAMPLE-0004',
          'carrier_name': 'Sujin Transport',
          'equipment_type_name': 'Wing Body',
          'planned_departure_at': DateTime.now()
              .add(const Duration(days: 1, hours: 7))
              .toIso8601String(),
          'planned_arrival_at': DateTime.now()
              .add(const Duration(days: 2, hours: 2))
              .toIso8601String(),
          'total_weight_kg': 2420,
          'total_volume_m3': 21.9,
          'total_distance_km': 431.8,
        },
      ],
    };
  }

  static Map<String, dynamic> allocations() {
    return {
      'total': 2,
      'items': [
        {
          'id': 'alloc-1',
          'load_plan_id': 'lp-2',
          'plan_no': 'LDP-SAMPLE-0002',
          'load_plan_name': '화성 출고 익일 간선 편성',
          'load_plan_status': 'ready_for_allocation',
          'shipment_id': null,
          'shipment_no': null,
          'order_ids': ['4'],
          'order_nos': ['ORD-SAMPLE-0004'],
          'order_count': 1,
          'order_summary': 'ORD-SAMPLE-0004',
          'carrier_org_id': 'carrier-1',
          'carrier_name': 'Sujin Transport',
          'status': 'requested',
          'target_rate': 480000,
          'quoted_rate': null,
          'fuel_surcharge': 0,
          'total_weight_kg': 2420,
          'total_volume_m3': 21.9,
          'total_distance_km': 431.8,
          'allocated_at': DateTime.now()
              .subtract(const Duration(hours: 3))
              .toIso8601String(),
          'responded_at': null,
          'awarded_at': null,
          'notes': '익일 부산 허브행 편성',
        },
        {
          'id': 'alloc-2',
          'load_plan_id': 'lp-1',
          'plan_no': 'LDP-SAMPLE-0001',
          'load_plan_name': '냉동 상품 부산 허브 편성',
          'load_plan_status': 'dispatch_ready',
          'shipment_id': 'shp-1',
          'shipment_no': 'SHP-SAMPLE-0005',
          'order_ids': ['2', '3'],
          'order_nos': ['ORD-SAMPLE-0002', 'ORD-SAMPLE-0003'],
          'order_count': 2,
          'order_summary': 'ORD-SAMPLE-0002 외 1건',
          'carrier_org_id': 'carrier-1',
          'carrier_name': 'Sujin Transport',
          'status': 'awarded',
          'target_rate': 720000,
          'quoted_rate': 735000,
          'fuel_surcharge': 25000,
          'total_weight_kg': 3340,
          'total_volume_m3': 32.4,
          'total_distance_km': 404.2,
          'allocated_at': DateTime.now()
              .subtract(const Duration(days: 1, hours: 2))
              .toIso8601String(),
          'responded_at': DateTime.now()
              .subtract(const Duration(days: 1, hours: 1))
              .toIso8601String(),
          'awarded_at': DateTime.now()
              .subtract(const Duration(days: 1))
              .toIso8601String(),
          'notes': '냉동 전용 배정 확정',
        },
      ],
    };
  }

  static Map<String, dynamic> dispatches() {
    return {
      'total': 3,
      'items': [
        {
          'id': '1',
          'dispatch_no': 'DSP-SAMPLE-0002',
          'shipment_no': 'SHP-SAMPLE-0002',
          'status': 'in_transit',
          'driver_name': 'Park Jiyoon',
          'vehicle_plate_no': '81A5678',
          'assigned_at': DateTime.now()
              .subtract(const Duration(hours: 12))
              .toIso8601String(),
          'accepted_at': DateTime.now()
              .subtract(const Duration(hours: 11, minutes: 40))
              .toIso8601String(),
        },
        {
          'id': '2',
          'dispatch_no': 'DSP-SAMPLE-0003',
          'shipment_no': 'SHP-SAMPLE-0003',
          'status': 'accepted',
          'driver_name': 'Kim Minsoo',
          'vehicle_plate_no': '81A1234',
          'assigned_at':
              DateTime.now().add(const Duration(hours: 18)).toIso8601String(),
          'accepted_at': DateTime.now()
              .add(const Duration(hours: 18, minutes: 20))
              .toIso8601String(),
        },
      ],
    };
  }
}
