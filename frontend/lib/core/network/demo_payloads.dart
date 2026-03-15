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
          'order_no': 'ORD-SAMPLE-0002',
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
