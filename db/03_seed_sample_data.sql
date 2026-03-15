\set ON_ERROR_STOP on

BEGIN;

DO $$
DECLARE
  v_tenant_id UUID;
  v_shipper_org_id UUID;
  v_carrier_org_id UUID;
  v_warehouse_org_id UUID;
  v_billto_org_id UUID;
  v_hwaseong_location_id UUID;
  v_icheon_location_id UUID;
  v_busan_location_id UUID;
  v_dispatcher_user_id UUID;
  v_ops_user_id UUID;
  v_driver_1_id UUID;
  v_driver_2_id UUID;
  v_vehicle_1_id UUID;
  v_vehicle_2_id UUID;
  v_vehicle_3_id UUID;
BEGIN
  SELECT id INTO v_tenant_id
  FROM tms.tenants
  WHERE tenant_code = 'SUJIN';

  SELECT id INTO v_shipper_org_id
  FROM tms.organizations
  WHERE tenant_id = v_tenant_id
    AND organization_code = 'SUJIN_SHIPPER';

  SELECT id INTO v_carrier_org_id
  FROM tms.organizations
  WHERE tenant_id = v_tenant_id
    AND organization_code = 'SUJIN_CARRIER';

  SELECT id INTO v_warehouse_org_id
  FROM tms.organizations
  WHERE tenant_id = v_tenant_id
    AND organization_code = 'SUJIN_WAREHOUSE';

  SELECT id INTO v_billto_org_id
  FROM tms.organizations
  WHERE tenant_id = v_tenant_id
    AND organization_code = 'SUJIN_BILLTO';

  SELECT id INTO v_hwaseong_location_id
  FROM tms.locations
  WHERE tenant_id = v_tenant_id
    AND location_code = 'HWASEONG_PLANT';

  SELECT id INTO v_icheon_location_id
  FROM tms.locations
  WHERE tenant_id = v_tenant_id
    AND location_code = 'ICHEON_DC';

  SELECT id INTO v_busan_location_id
  FROM tms.locations
  WHERE tenant_id = v_tenant_id
    AND location_code = 'BUSAN_HUB';

  SELECT id INTO v_dispatcher_user_id
  FROM tms.app_users
  WHERE tenant_id = v_tenant_id
    AND lower(email) = lower('dispatch@sujin.local');

  SELECT id INTO v_ops_user_id
  FROM tms.app_users
  WHERE tenant_id = v_tenant_id
    AND lower(email) = lower('ops@sujin.local');

  SELECT id INTO v_driver_1_id
  FROM tms.drivers
  WHERE tenant_id = v_tenant_id
    AND employee_no = 'DRV-1001';

  SELECT id INTO v_driver_2_id
  FROM tms.drivers
  WHERE tenant_id = v_tenant_id
    AND employee_no = 'DRV-1002';

  SELECT id INTO v_vehicle_1_id
  FROM tms.vehicles
  WHERE tenant_id = v_tenant_id
    AND vehicle_no = 'VEH-1001';

  SELECT id INTO v_vehicle_2_id
  FROM tms.vehicles
  WHERE tenant_id = v_tenant_id
    AND vehicle_no = 'VEH-1002';

  SELECT id INTO v_vehicle_3_id
  FROM tms.vehicles
  WHERE tenant_id = v_tenant_id
    AND vehicle_no = 'VEH-1003';

  IF v_tenant_id IS NULL
     OR v_shipper_org_id IS NULL
     OR v_carrier_org_id IS NULL
     OR v_warehouse_org_id IS NULL
     OR v_billto_org_id IS NULL
     OR v_hwaseong_location_id IS NULL
     OR v_icheon_location_id IS NULL
     OR v_busan_location_id IS NULL
     OR v_dispatcher_user_id IS NULL
     OR v_ops_user_id IS NULL
     OR v_driver_1_id IS NULL
     OR v_driver_2_id IS NULL
     OR v_vehicle_1_id IS NULL
     OR v_vehicle_2_id IS NULL
     OR v_vehicle_3_id IS NULL THEN
    RAISE EXCEPTION 'Master seed is missing. Run db/02_seed_master_data.sql first.';
  END IF;

  INSERT INTO tms.transport_orders (
    id,
    tenant_id,
    order_no,
    customer_org_id,
    shipper_org_id,
    bill_to_org_id,
    requested_mode,
    service_level,
    status,
    priority,
    customer_reference,
    planned_pickup_from,
    planned_pickup_to,
    planned_delivery_from,
    planned_delivery_to,
    total_weight_kg,
    total_volume_m3,
    notes,
    metadata,
    created_by
  )
  VALUES
    (
      '00000000-0000-0000-0000-000000010001',
      v_tenant_id,
      'ORD-SAMPLE-0001',
      v_shipper_org_id,
      v_shipper_org_id,
      v_billto_org_id,
      'road',
      'express',
      'delivered',
      1,
      'SO-DEL-0001',
      ((CURRENT_DATE - 2) + TIME '08:00') AT TIME ZONE 'Asia/Seoul',
      ((CURRENT_DATE - 2) + TIME '10:00') AT TIME ZONE 'Asia/Seoul',
      ((CURRENT_DATE - 1) + TIME '14:00') AT TIME ZONE 'Asia/Seoul',
      ((CURRENT_DATE - 1) + TIME '18:00') AT TIME ZONE 'Asia/Seoul',
      1840.50,
      14.200,
      'Delivered electronics replenishment order',
      '{"scenario":"delivered","channel":"retail"}'::JSONB,
      v_ops_user_id
    ),
    (
      '00000000-0000-0000-0000-000000010002',
      v_tenant_id,
      'ORD-SAMPLE-0002',
      v_warehouse_org_id,
      v_shipper_org_id,
      v_billto_org_id,
      'road',
      'same_day',
      'in_transit',
      1,
      'SO-TRN-0002',
      (CURRENT_DATE + TIME '06:00') AT TIME ZONE 'Asia/Seoul',
      (CURRENT_DATE + TIME '07:00') AT TIME ZONE 'Asia/Seoul',
      ((CURRENT_DATE + 1) + TIME '09:00') AT TIME ZONE 'Asia/Seoul',
      ((CURRENT_DATE + 1) + TIME '12:00') AT TIME ZONE 'Asia/Seoul',
      920.00,
      10.500,
      'Cold-chain shipment currently moving to Busan',
      '{"scenario":"in_transit","temperature_controlled":true}'::JSONB,
      v_dispatcher_user_id
    ),
    (
      '00000000-0000-0000-0000-000000010003',
      v_tenant_id,
      'ORD-SAMPLE-0003',
      v_shipper_org_id,
      v_shipper_org_id,
      v_billto_org_id,
      'road',
      'standard',
      'planned',
      2,
      'SO-PLN-0003',
      ((CURRENT_DATE + 2) + TIME '08:30') AT TIME ZONE 'Asia/Seoul',
      ((CURRENT_DATE + 2) + TIME '10:00') AT TIME ZONE 'Asia/Seoul',
      ((CURRENT_DATE + 3) + TIME '15:00') AT TIME ZONE 'Asia/Seoul',
      ((CURRENT_DATE + 3) + TIME '18:00') AT TIME ZONE 'Asia/Seoul',
      2420.00,
      21.900,
      'Multi-stop replenishment through Icheon DC',
      '{"scenario":"planned","multi_stop":true}'::JSONB,
      v_ops_user_id
    ),
    (
      '00000000-0000-0000-0000-000000010004',
      v_tenant_id,
      'ORD-SAMPLE-0004',
      v_shipper_org_id,
      v_shipper_org_id,
      v_billto_org_id,
      'road',
      'standard',
      'confirmed',
      3,
      'SO-CFM-0004',
      ((CURRENT_DATE + 4) + TIME '09:00') AT TIME ZONE 'Asia/Seoul',
      ((CURRENT_DATE + 4) + TIME '11:00') AT TIME ZONE 'Asia/Seoul',
      ((CURRENT_DATE + 5) + TIME '13:00') AT TIME ZONE 'Asia/Seoul',
      ((CURRENT_DATE + 5) + TIME '17:00') AT TIME ZONE 'Asia/Seoul',
      780.00,
      6.300,
      'Confirmed order waiting for shipment creation',
      '{"scenario":"confirmed"}'::JSONB,
      v_dispatcher_user_id
    ),
    (
      '00000000-0000-0000-0000-000000010005',
      v_tenant_id,
      'ORD-SAMPLE-0005',
      v_shipper_org_id,
      v_shipper_org_id,
      v_billto_org_id,
      'road',
      'standard',
      'cancelled',
      4,
      'SO-CAN-0005',
      ((CURRENT_DATE + 6) + TIME '10:00') AT TIME ZONE 'Asia/Seoul',
      ((CURRENT_DATE + 6) + TIME '12:00') AT TIME ZONE 'Asia/Seoul',
      ((CURRENT_DATE + 7) + TIME '15:00') AT TIME ZONE 'Asia/Seoul',
      ((CURRENT_DATE + 7) + TIME '18:00') AT TIME ZONE 'Asia/Seoul',
      600.00,
      5.200,
      'Cancelled due to customer schedule change',
      '{"scenario":"cancelled"}'::JSONB,
      v_ops_user_id
    )
  ON CONFLICT (id) DO UPDATE
  SET
    tenant_id = EXCLUDED.tenant_id,
    order_no = EXCLUDED.order_no,
    customer_org_id = EXCLUDED.customer_org_id,
    shipper_org_id = EXCLUDED.shipper_org_id,
    bill_to_org_id = EXCLUDED.bill_to_org_id,
    requested_mode = EXCLUDED.requested_mode,
    service_level = EXCLUDED.service_level,
    status = EXCLUDED.status,
    priority = EXCLUDED.priority,
    customer_reference = EXCLUDED.customer_reference,
    planned_pickup_from = EXCLUDED.planned_pickup_from,
    planned_pickup_to = EXCLUDED.planned_pickup_to,
    planned_delivery_from = EXCLUDED.planned_delivery_from,
    planned_delivery_to = EXCLUDED.planned_delivery_to,
    total_weight_kg = EXCLUDED.total_weight_kg,
    total_volume_m3 = EXCLUDED.total_volume_m3,
    notes = EXCLUDED.notes,
    metadata = EXCLUDED.metadata,
    created_by = EXCLUDED.created_by;

  INSERT INTO tms.order_lines (
    id,
    order_id,
    line_no,
    sku,
    description,
    quantity,
    package_type,
    weight_kg,
    volume_m3,
    pallet_count,
    is_stackable,
    is_hazardous,
    metadata
  )
  VALUES
    ('00000000-0000-0000-0000-000000020001', '00000000-0000-0000-0000-000000010001', 1, 'TV-55-UHD', '55 inch UHD TV', 48, 'carton', 1180.00, 8.600, 8, TRUE, FALSE, '{"fragile":true}'::JSONB),
    ('00000000-0000-0000-0000-000000020002', '00000000-0000-0000-0000-000000010001', 2, 'SND-BAR-01', 'Premium soundbar set', 64, 'carton', 660.50, 5.600, 6, TRUE, FALSE, '{"fragile":true}'::JSONB),
    ('00000000-0000-0000-0000-000000020003', '00000000-0000-0000-0000-000000010002', 1, 'FOOD-FRZ-01', 'Frozen ready meal case', 120, 'case', 520.00, 6.200, 10, TRUE, FALSE, '{"temperature":"-18C"}'::JSONB),
    ('00000000-0000-0000-0000-000000020004', '00000000-0000-0000-0000-000000010002', 2, 'FOOD-ICE-02', 'Ice cream assortment', 80, 'case', 400.00, 4.300, 8, TRUE, FALSE, '{"temperature":"-18C"}'::JSONB),
    ('00000000-0000-0000-0000-000000020005', '00000000-0000-0000-0000-000000010003', 1, 'APPL-MIX-01', 'Small appliance mixed pallet', 90, 'pallet', 1420.00, 12.100, 12, TRUE, FALSE, '{"dc_crossdock":true}'::JSONB),
    ('00000000-0000-0000-0000-000000020006', '00000000-0000-0000-0000-000000010003', 2, 'FILTER-AIR-02', 'Air purifier filter pack', 240, 'box', 1000.00, 9.800, 9, TRUE, FALSE, '{"dc_crossdock":true}'::JSONB),
    ('00000000-0000-0000-0000-000000020007', '00000000-0000-0000-0000-000000010004', 1, 'MON-24-FHD', '24 inch monitor', 40, 'carton', 500.00, 4.100, 4, TRUE, FALSE, '{"launch_wave":2}'::JSONB),
    ('00000000-0000-0000-0000-000000020008', '00000000-0000-0000-0000-000000010004', 2, 'KB-MECH-01', 'Mechanical keyboard bundle', 120, 'carton', 280.00, 2.200, 2, TRUE, FALSE, '{"launch_wave":2}'::JSONB),
    ('00000000-0000-0000-0000-000000020009', '00000000-0000-0000-0000-000000010005', 1, 'ACC-USB-01', 'USB accessory pack', 150, 'box', 600.00, 5.200, 5, TRUE, FALSE, '{"cancel_reason":"schedule_change"}'::JSONB)
  ON CONFLICT (id) DO UPDATE
  SET
    order_id = EXCLUDED.order_id,
    line_no = EXCLUDED.line_no,
    sku = EXCLUDED.sku,
    description = EXCLUDED.description,
    quantity = EXCLUDED.quantity,
    package_type = EXCLUDED.package_type,
    weight_kg = EXCLUDED.weight_kg,
    volume_m3 = EXCLUDED.volume_m3,
    pallet_count = EXCLUDED.pallet_count,
    is_stackable = EXCLUDED.is_stackable,
    is_hazardous = EXCLUDED.is_hazardous,
    metadata = EXCLUDED.metadata;

  INSERT INTO tms.order_stops (
    id,
    order_id,
    stop_seq,
    stop_type,
    location_id,
    contact_name,
    contact_phone,
    planned_arrival_from,
    planned_arrival_to,
    notes
  )
  VALUES
    ('00000000-0000-0000-0000-000000030001', '00000000-0000-0000-0000-000000010001', 1, 'pickup', v_hwaseong_location_id, 'Plant Dock A', '031-100-2001', ((CURRENT_DATE - 2) + TIME '08:00') AT TIME ZONE 'Asia/Seoul', ((CURRENT_DATE - 2) + TIME '10:00') AT TIME ZONE 'Asia/Seoul', 'Load at outbound dock A'),
    ('00000000-0000-0000-0000-000000030002', '00000000-0000-0000-0000-000000010001', 2, 'delivery', v_busan_location_id, 'Busan Receiving', '051-500-5100', ((CURRENT_DATE - 1) + TIME '14:00') AT TIME ZONE 'Asia/Seoul', ((CURRENT_DATE - 1) + TIME '18:00') AT TIME ZONE 'Asia/Seoul', 'Retail replenishment window'),
    ('00000000-0000-0000-0000-000000030003', '00000000-0000-0000-0000-000000010002', 1, 'pickup', v_icheon_location_id, 'Icheon Cold Dock', '031-300-3100', (CURRENT_DATE + TIME '06:00') AT TIME ZONE 'Asia/Seoul', (CURRENT_DATE + TIME '07:00') AT TIME ZONE 'Asia/Seoul', 'Reefer pre-cool required'),
    ('00000000-0000-0000-0000-000000030004', '00000000-0000-0000-0000-000000010002', 2, 'delivery', v_busan_location_id, 'Busan Frozen Dock', '051-500-5200', ((CURRENT_DATE + 1) + TIME '09:00') AT TIME ZONE 'Asia/Seoul', ((CURRENT_DATE + 1) + TIME '12:00') AT TIME ZONE 'Asia/Seoul', 'Maintain -18C through unload'),
    ('00000000-0000-0000-0000-000000030005', '00000000-0000-0000-0000-000000010003', 1, 'pickup', v_hwaseong_location_id, 'Plant Dock B', '031-100-2002', ((CURRENT_DATE + 2) + TIME '08:30') AT TIME ZONE 'Asia/Seoul', ((CURRENT_DATE + 2) + TIME '10:00') AT TIME ZONE 'Asia/Seoul', 'Pickup appliances'),
    ('00000000-0000-0000-0000-000000030006', '00000000-0000-0000-0000-000000010003', 2, 'waypoint', v_icheon_location_id, 'Cross Dock Team', '031-300-3200', ((CURRENT_DATE + 2) + TIME '13:00') AT TIME ZONE 'Asia/Seoul', ((CURRENT_DATE + 2) + TIME '16:00') AT TIME ZONE 'Asia/Seoul', 'Cross-dock sort and consolidation'),
    ('00000000-0000-0000-0000-000000030007', '00000000-0000-0000-0000-000000010003', 3, 'delivery', v_busan_location_id, 'Busan Receiving', '051-500-5100', ((CURRENT_DATE + 3) + TIME '15:00') AT TIME ZONE 'Asia/Seoul', ((CURRENT_DATE + 3) + TIME '18:00') AT TIME ZONE 'Asia/Seoul', 'Final delivery'),
    ('00000000-0000-0000-0000-000000030008', '00000000-0000-0000-0000-000000010004', 1, 'pickup', v_hwaseong_location_id, 'Plant Dock C', '031-100-2003', ((CURRENT_DATE + 4) + TIME '09:00') AT TIME ZONE 'Asia/Seoul', ((CURRENT_DATE + 4) + TIME '11:00') AT TIME ZONE 'Asia/Seoul', 'Awaiting wave allocation'),
    ('00000000-0000-0000-0000-000000030009', '00000000-0000-0000-0000-000000010004', 2, 'delivery', v_busan_location_id, 'Busan Store Ops', '051-500-5300', ((CURRENT_DATE + 5) + TIME '13:00') AT TIME ZONE 'Asia/Seoul', ((CURRENT_DATE + 5) + TIME '17:00') AT TIME ZONE 'Asia/Seoul', 'Scheduled store launch receipt'),
    ('00000000-0000-0000-0000-000000030010', '00000000-0000-0000-0000-000000010005', 1, 'pickup', v_hwaseong_location_id, 'Plant Dock D', '031-100-2004', ((CURRENT_DATE + 6) + TIME '10:00') AT TIME ZONE 'Asia/Seoul', ((CURRENT_DATE + 6) + TIME '12:00') AT TIME ZONE 'Asia/Seoul', 'Cancelled pickup'),
    ('00000000-0000-0000-0000-000000030011', '00000000-0000-0000-0000-000000010005', 2, 'delivery', v_busan_location_id, 'Busan Store Ops', '051-500-5300', ((CURRENT_DATE + 7) + TIME '15:00') AT TIME ZONE 'Asia/Seoul', ((CURRENT_DATE + 7) + TIME '18:00') AT TIME ZONE 'Asia/Seoul', 'Cancelled delivery')
  ON CONFLICT (id) DO UPDATE
  SET
    order_id = EXCLUDED.order_id,
    stop_seq = EXCLUDED.stop_seq,
    stop_type = EXCLUDED.stop_type,
    location_id = EXCLUDED.location_id,
    contact_name = EXCLUDED.contact_name,
    contact_phone = EXCLUDED.contact_phone,
    planned_arrival_from = EXCLUDED.planned_arrival_from,
    planned_arrival_to = EXCLUDED.planned_arrival_to,
    notes = EXCLUDED.notes;

  INSERT INTO tms.shipments (
    id,
    tenant_id,
    shipment_no,
    order_id,
    carrier_org_id,
    transport_mode,
    service_level,
    equipment_type_id,
    status,
    planned_pickup_at,
    planned_delivery_at,
    actual_pickup_at,
    actual_delivery_at,
    total_weight_kg,
    total_volume_m3,
    total_distance_km,
    notes,
    metadata
  )
  VALUES
    (
      '00000000-0000-0000-0000-000000040001',
      v_tenant_id,
      'SHP-SAMPLE-0001',
      '00000000-0000-0000-0000-000000010001',
      v_carrier_org_id,
      'road',
      'express',
      (SELECT equipment_type_id FROM tms.vehicles WHERE id = v_vehicle_3_id),
      'delivered',
      ((CURRENT_DATE - 2) + TIME '08:00') AT TIME ZONE 'Asia/Seoul',
      ((CURRENT_DATE - 1) + TIME '17:00') AT TIME ZONE 'Asia/Seoul',
      ((CURRENT_DATE - 2) + TIME '08:22') AT TIME ZONE 'Asia/Seoul',
      ((CURRENT_DATE - 1) + TIME '16:28') AT TIME ZONE 'Asia/Seoul',
      1840.50,
      14.200,
      412.30,
      'Delivered on-time with full POD',
      '{"scenario":"delivered"}'::JSONB
    ),
    (
      '00000000-0000-0000-0000-000000040002',
      v_tenant_id,
      'SHP-SAMPLE-0002',
      '00000000-0000-0000-0000-000000010002',
      v_carrier_org_id,
      'road',
      'same_day',
      (SELECT equipment_type_id FROM tms.vehicles WHERE id = v_vehicle_2_id),
      'in_transit',
      (CURRENT_DATE + TIME '06:00') AT TIME ZONE 'Asia/Seoul',
      ((CURRENT_DATE + 1) + TIME '11:00') AT TIME ZONE 'Asia/Seoul',
      (CURRENT_DATE + TIME '06:18') AT TIME ZONE 'Asia/Seoul',
      NULL,
      920.00,
      10.500,
      398.40,
      'Reefer unit active and stable',
      '{"scenario":"in_transit","temperature":"-18C"}'::JSONB
    ),
    (
      '00000000-0000-0000-0000-000000040003',
      v_tenant_id,
      'SHP-SAMPLE-0003',
      '00000000-0000-0000-0000-000000010003',
      v_carrier_org_id,
      'road',
      'standard',
      (SELECT equipment_type_id FROM tms.vehicles WHERE id = v_vehicle_1_id),
      'dispatched',
      ((CURRENT_DATE + 2) + TIME '08:30') AT TIME ZONE 'Asia/Seoul',
      ((CURRENT_DATE + 3) + TIME '17:30') AT TIME ZONE 'Asia/Seoul',
      NULL,
      NULL,
      2420.00,
      21.900,
      431.80,
      'Ready for next-day departure after dispatch acceptance',
      '{"scenario":"planned_to_dispatch"}'::JSONB
    )
  ON CONFLICT (id) DO UPDATE
  SET
    tenant_id = EXCLUDED.tenant_id,
    shipment_no = EXCLUDED.shipment_no,
    order_id = EXCLUDED.order_id,
    carrier_org_id = EXCLUDED.carrier_org_id,
    transport_mode = EXCLUDED.transport_mode,
    service_level = EXCLUDED.service_level,
    equipment_type_id = EXCLUDED.equipment_type_id,
    status = EXCLUDED.status,
    planned_pickup_at = EXCLUDED.planned_pickup_at,
    planned_delivery_at = EXCLUDED.planned_delivery_at,
    actual_pickup_at = EXCLUDED.actual_pickup_at,
    actual_delivery_at = EXCLUDED.actual_delivery_at,
    total_weight_kg = EXCLUDED.total_weight_kg,
    total_volume_m3 = EXCLUDED.total_volume_m3,
    total_distance_km = EXCLUDED.total_distance_km,
    notes = EXCLUDED.notes,
    metadata = EXCLUDED.metadata;

  INSERT INTO tms.shipment_stops (
    id,
    shipment_id,
    order_stop_id,
    stop_seq,
    stop_type,
    location_id,
    status,
    appointment_from,
    appointment_to,
    arrived_at,
    departed_at,
    notes
  )
  VALUES
    ('00000000-0000-0000-0000-000000050001', '00000000-0000-0000-0000-000000040001', '00000000-0000-0000-0000-000000030001', 1, 'pickup', v_hwaseong_location_id, 'completed', ((CURRENT_DATE - 2) + TIME '08:00') AT TIME ZONE 'Asia/Seoul', ((CURRENT_DATE - 2) + TIME '10:00') AT TIME ZONE 'Asia/Seoul', ((CURRENT_DATE - 2) + TIME '08:05') AT TIME ZONE 'Asia/Seoul', ((CURRENT_DATE - 2) + TIME '09:02') AT TIME ZONE 'Asia/Seoul', 'Loaded and sealed'),
    ('00000000-0000-0000-0000-000000050002', '00000000-0000-0000-0000-000000040001', '00000000-0000-0000-0000-000000030002', 2, 'delivery', v_busan_location_id, 'completed', ((CURRENT_DATE - 1) + TIME '14:00') AT TIME ZONE 'Asia/Seoul', ((CURRENT_DATE - 1) + TIME '18:00') AT TIME ZONE 'Asia/Seoul', ((CURRENT_DATE - 1) + TIME '15:12') AT TIME ZONE 'Asia/Seoul', ((CURRENT_DATE - 1) + TIME '16:28') AT TIME ZONE 'Asia/Seoul', 'POD signed'),
    ('00000000-0000-0000-0000-000000050003', '00000000-0000-0000-0000-000000040002', '00000000-0000-0000-0000-000000030003', 1, 'pickup', v_icheon_location_id, 'completed', (CURRENT_DATE + TIME '06:00') AT TIME ZONE 'Asia/Seoul', (CURRENT_DATE + TIME '07:00') AT TIME ZONE 'Asia/Seoul', (CURRENT_DATE + TIME '05:58') AT TIME ZONE 'Asia/Seoul', (CURRENT_DATE + TIME '06:32') AT TIME ZONE 'Asia/Seoul', 'Reefer temperature verified'),
    ('00000000-0000-0000-0000-000000050004', '00000000-0000-0000-0000-000000040002', '00000000-0000-0000-0000-000000030004', 2, 'delivery', v_busan_location_id, 'planned', ((CURRENT_DATE + 1) + TIME '09:00') AT TIME ZONE 'Asia/Seoul', ((CURRENT_DATE + 1) + TIME '12:00') AT TIME ZONE 'Asia/Seoul', NULL, NULL, 'ETA maintained'),
    ('00000000-0000-0000-0000-000000050005', '00000000-0000-0000-0000-000000040003', '00000000-0000-0000-0000-000000030005', 1, 'pickup', v_hwaseong_location_id, 'planned', ((CURRENT_DATE + 2) + TIME '08:30') AT TIME ZONE 'Asia/Seoul', ((CURRENT_DATE + 2) + TIME '10:00') AT TIME ZONE 'Asia/Seoul', NULL, NULL, 'Awaiting truck arrival'),
    ('00000000-0000-0000-0000-000000050006', '00000000-0000-0000-0000-000000040003', '00000000-0000-0000-0000-000000030006', 2, 'waypoint', v_icheon_location_id, 'planned', ((CURRENT_DATE + 2) + TIME '13:00') AT TIME ZONE 'Asia/Seoul', ((CURRENT_DATE + 2) + TIME '16:00') AT TIME ZONE 'Asia/Seoul', NULL, NULL, 'Cross-dock planned'),
    ('00000000-0000-0000-0000-000000050007', '00000000-0000-0000-0000-000000040003', '00000000-0000-0000-0000-000000030007', 3, 'delivery', v_busan_location_id, 'planned', ((CURRENT_DATE + 3) + TIME '15:00') AT TIME ZONE 'Asia/Seoul', ((CURRENT_DATE + 3) + TIME '18:00') AT TIME ZONE 'Asia/Seoul', NULL, NULL, 'Final drop')
  ON CONFLICT (id) DO UPDATE
  SET
    shipment_id = EXCLUDED.shipment_id,
    order_stop_id = EXCLUDED.order_stop_id,
    stop_seq = EXCLUDED.stop_seq,
    stop_type = EXCLUDED.stop_type,
    location_id = EXCLUDED.location_id,
    status = EXCLUDED.status,
    appointment_from = EXCLUDED.appointment_from,
    appointment_to = EXCLUDED.appointment_to,
    arrived_at = EXCLUDED.arrived_at,
    departed_at = EXCLUDED.departed_at,
    notes = EXCLUDED.notes;

  INSERT INTO tms.dispatches (
    id,
    tenant_id,
    dispatch_no,
    shipment_id,
    carrier_org_id,
    driver_id,
    vehicle_id,
    status,
    assigned_by,
    assigned_at,
    accepted_at,
    departed_at,
    completed_at,
    rejection_reason,
    notes
  )
  VALUES
    (
      '00000000-0000-0000-0000-000000060001',
      v_tenant_id,
      'DSP-SAMPLE-0001',
      '00000000-0000-0000-0000-000000040001',
      v_carrier_org_id,
      v_driver_1_id,
      v_vehicle_3_id,
      'completed',
      v_dispatcher_user_id,
      ((CURRENT_DATE - 2) + TIME '07:20') AT TIME ZONE 'Asia/Seoul',
      ((CURRENT_DATE - 2) + TIME '07:32') AT TIME ZONE 'Asia/Seoul',
      ((CURRENT_DATE - 2) + TIME '09:05') AT TIME ZONE 'Asia/Seoul',
      ((CURRENT_DATE - 1) + TIME '16:35') AT TIME ZONE 'Asia/Seoul',
      NULL,
      'Completed with on-time delivery'
    ),
    (
      '00000000-0000-0000-0000-000000060002',
      v_tenant_id,
      'DSP-SAMPLE-0002',
      '00000000-0000-0000-0000-000000040002',
      v_carrier_org_id,
      v_driver_2_id,
      v_vehicle_2_id,
      'in_transit',
      v_dispatcher_user_id,
      ((CURRENT_DATE - 1) + TIME '18:00') AT TIME ZONE 'Asia/Seoul',
      ((CURRENT_DATE - 1) + TIME '18:18') AT TIME ZONE 'Asia/Seoul',
      (CURRENT_DATE + TIME '06:35') AT TIME ZONE 'Asia/Seoul',
      NULL,
      NULL,
      'Current active reefer dispatch'
    ),
    (
      '00000000-0000-0000-0000-000000060003',
      v_tenant_id,
      'DSP-SAMPLE-0003',
      '00000000-0000-0000-0000-000000040003',
      v_carrier_org_id,
      v_driver_1_id,
      v_vehicle_1_id,
      'accepted',
      v_dispatcher_user_id,
      ((CURRENT_DATE + 1) + TIME '17:30') AT TIME ZONE 'Asia/Seoul',
      ((CURRENT_DATE + 1) + TIME '17:55') AT TIME ZONE 'Asia/Seoul',
      NULL,
      NULL,
      NULL,
      'Accepted and staged for next route'
    )
  ON CONFLICT (id) DO UPDATE
  SET
    tenant_id = EXCLUDED.tenant_id,
    dispatch_no = EXCLUDED.dispatch_no,
    shipment_id = EXCLUDED.shipment_id,
    carrier_org_id = EXCLUDED.carrier_org_id,
    driver_id = EXCLUDED.driver_id,
    vehicle_id = EXCLUDED.vehicle_id,
    status = EXCLUDED.status,
    assigned_by = EXCLUDED.assigned_by,
    assigned_at = EXCLUDED.assigned_at,
    accepted_at = EXCLUDED.accepted_at,
    departed_at = EXCLUDED.departed_at,
    completed_at = EXCLUDED.completed_at,
    rejection_reason = EXCLUDED.rejection_reason,
    notes = EXCLUDED.notes;

  INSERT INTO tms.tracking_events (
    id,
    tenant_id,
    shipment_id,
    dispatch_id,
    stop_id,
    event_type,
    occurred_at,
    latitude,
    longitude,
    source,
    message,
    payload
  )
  VALUES
    ('00000000-0000-0000-0000-000000070001', v_tenant_id, '00000000-0000-0000-0000-000000040001', '00000000-0000-0000-0000-000000060001', '00000000-0000-0000-0000-000000050001', 'accepted', ((CURRENT_DATE - 2) + TIME '07:32') AT TIME ZONE 'Asia/Seoul', 37.199493, 127.056789, 'dispatch_app', 'Driver accepted job', '{"driver":"DRV-1001"}'::JSONB),
    ('00000000-0000-0000-0000-000000070002', v_tenant_id, '00000000-0000-0000-0000-000000040001', '00000000-0000-0000-0000-000000060001', '00000000-0000-0000-0000-000000050001', 'loaded', ((CURRENT_DATE - 2) + TIME '09:00') AT TIME ZONE 'Asia/Seoul', 37.199493, 127.056789, 'warehouse', 'Loading completed', '{"seal_no":"SEAL-101"}'::JSONB),
    ('00000000-0000-0000-0000-000000070003', v_tenant_id, '00000000-0000-0000-0000-000000040001', '00000000-0000-0000-0000-000000060001', NULL, 'departed_origin', ((CURRENT_DATE - 2) + TIME '09:05') AT TIME ZONE 'Asia/Seoul', 37.199493, 127.056789, 'telematics', 'Departed origin', '{"speed_kph":42}'::JSONB),
    ('00000000-0000-0000-0000-000000070004', v_tenant_id, '00000000-0000-0000-0000-000000040001', '00000000-0000-0000-0000-000000060001', '00000000-0000-0000-0000-000000050002', 'arrived_destination', ((CURRENT_DATE - 1) + TIME '15:12') AT TIME ZONE 'Asia/Seoul', 35.115168, 129.042160, 'telematics', 'Arrived at destination', '{"eta_delta_min":-48}'::JSONB),
    ('00000000-0000-0000-0000-000000070005', v_tenant_id, '00000000-0000-0000-0000-000000040001', '00000000-0000-0000-0000-000000060001', '00000000-0000-0000-0000-000000050002', 'delivered', ((CURRENT_DATE - 1) + TIME '16:28') AT TIME ZONE 'Asia/Seoul', 35.115168, 129.042160, 'dispatch_app', 'POD completed', '{"pod_signed_by":"Busan Receiving"}'::JSONB),
    ('00000000-0000-0000-0000-000000070006', v_tenant_id, '00000000-0000-0000-0000-000000040002', '00000000-0000-0000-0000-000000060002', '00000000-0000-0000-0000-000000050003', 'accepted', ((CURRENT_DATE - 1) + TIME '18:18') AT TIME ZONE 'Asia/Seoul', 37.279570, 127.442330, 'dispatch_app', 'Driver accepted reefer dispatch', '{"driver":"DRV-1002"}'::JSONB),
    ('00000000-0000-0000-0000-000000070007', v_tenant_id, '00000000-0000-0000-0000-000000040002', '00000000-0000-0000-0000-000000060002', '00000000-0000-0000-0000-000000050003', 'loaded', (CURRENT_DATE + TIME '06:30') AT TIME ZONE 'Asia/Seoul', 37.279570, 127.442330, 'warehouse', 'Reefer loaded and temperature locked', '{"setpoint_c":-18}'::JSONB),
    ('00000000-0000-0000-0000-000000070008', v_tenant_id, '00000000-0000-0000-0000-000000040002', '00000000-0000-0000-0000-000000060002', NULL, 'departed_origin', (CURRENT_DATE + TIME '06:35') AT TIME ZONE 'Asia/Seoul', 37.279570, 127.442330, 'telematics', 'Departed Icheon DC', '{"reefer_ok":true}'::JSONB),
    ('00000000-0000-0000-0000-000000070009', v_tenant_id, '00000000-0000-0000-0000-000000040002', '00000000-0000-0000-0000-000000060002', NULL, 'gps_ping', (CURRENT_DATE + TIME '12:00') AT TIME ZONE 'Asia/Seoul', 36.350412, 127.384548, 'telematics', 'Mid-route ping', '{"speed_kph":71,"temp_c":-18.5}'::JSONB),
    ('00000000-0000-0000-0000-000000070010', v_tenant_id, '00000000-0000-0000-0000-000000040003', '00000000-0000-0000-0000-000000060003', NULL, 'accepted', ((CURRENT_DATE + 1) + TIME '17:55') AT TIME ZONE 'Asia/Seoul', 37.615210, 126.715256, 'dispatch_app', 'Driver accepted tomorrow route', '{"driver":"DRV-1001"}'::JSONB)
  ON CONFLICT (id) DO UPDATE
  SET
    tenant_id = EXCLUDED.tenant_id,
    shipment_id = EXCLUDED.shipment_id,
    dispatch_id = EXCLUDED.dispatch_id,
    stop_id = EXCLUDED.stop_id,
    event_type = EXCLUDED.event_type,
    occurred_at = EXCLUDED.occurred_at,
    latitude = EXCLUDED.latitude,
    longitude = EXCLUDED.longitude,
    source = EXCLUDED.source,
    message = EXCLUDED.message,
    payload = EXCLUDED.payload;

  INSERT INTO tms.shipment_charges (
    id,
    tenant_id,
    shipment_id,
    order_id,
    direction,
    partner_org_id,
    charge_type,
    status,
    description,
    quantity,
    unit_price,
    amount,
    currency_code,
    metadata
  )
  VALUES
    ('00000000-0000-0000-0000-000000080001', v_tenant_id, '00000000-0000-0000-0000-000000040001', '00000000-0000-0000-0000-000000010001', 'receivable', v_billto_org_id, 'freight', 'invoiced', 'Express linehaul charge', 1, 1250000.00, 1250000.00, 'KRW', '{"invoice":"AR-0001"}'::JSONB),
    ('00000000-0000-0000-0000-000000080002', v_tenant_id, '00000000-0000-0000-0000-000000040001', '00000000-0000-0000-0000-000000010001', 'receivable', v_billto_org_id, 'fuel_surcharge', 'invoiced', 'Fuel surcharge', 1, 90000.00, 90000.00, 'KRW', '{}'::JSONB),
    ('00000000-0000-0000-0000-000000080003', v_tenant_id, '00000000-0000-0000-0000-000000040001', '00000000-0000-0000-0000-000000010001', 'receivable', v_billto_org_id, 'toll', 'invoiced', 'Expressway toll', 1, 35000.00, 35000.00, 'KRW', '{}'::JSONB),
    ('00000000-0000-0000-0000-000000080004', v_tenant_id, '00000000-0000-0000-0000-000000040001', '00000000-0000-0000-0000-000000010001', 'payable', v_carrier_org_id, 'freight', 'invoiced', 'Carrier linehaul payable', 1, 930000.00, 930000.00, 'KRW', '{"invoice":"AP-0001"}'::JSONB),
    ('00000000-0000-0000-0000-000000080005', v_tenant_id, '00000000-0000-0000-0000-000000040001', '00000000-0000-0000-0000-000000010001', 'payable', v_carrier_org_id, 'toll', 'invoiced', 'Carrier toll reimbursement', 1, 35000.00, 35000.00, 'KRW', '{}'::JSONB),
    ('00000000-0000-0000-0000-000000080006', v_tenant_id, '00000000-0000-0000-0000-000000040002', '00000000-0000-0000-0000-000000010002', 'receivable', v_billto_org_id, 'freight', 'approved', 'Cold-chain freight', 1, 980000.00, 980000.00, 'KRW', '{}'::JSONB),
    ('00000000-0000-0000-0000-000000080007', v_tenant_id, '00000000-0000-0000-0000-000000040002', '00000000-0000-0000-0000-000000010002', 'receivable', v_billto_org_id, 'accessorial', 'approved', 'Reefer surcharge', 1, 150000.00, 150000.00, 'KRW', '{"temp_setpoint":"-18C"}'::JSONB),
    ('00000000-0000-0000-0000-000000080008', v_tenant_id, '00000000-0000-0000-0000-000000040002', '00000000-0000-0000-0000-000000010002', 'payable', v_carrier_org_id, 'freight', 'pending', 'Carrier payable estimate', 1, 830000.00, 830000.00, 'KRW', '{}'::JSONB),
    ('00000000-0000-0000-0000-000000080009', v_tenant_id, '00000000-0000-0000-0000-000000040003', '00000000-0000-0000-0000-000000010003', 'receivable', v_billto_org_id, 'freight', 'pending', 'Planned multi-stop freight', 1, 1450000.00, 1450000.00, 'KRW', '{}'::JSONB),
    ('00000000-0000-0000-0000-000000080010', v_tenant_id, '00000000-0000-0000-0000-000000040003', '00000000-0000-0000-0000-000000010003', 'payable', v_carrier_org_id, 'freight', 'pending', 'Planned carrier payable', 1, 1180000.00, 1180000.00, 'KRW', '{}'::JSONB)
  ON CONFLICT (id) DO UPDATE
  SET
    tenant_id = EXCLUDED.tenant_id,
    shipment_id = EXCLUDED.shipment_id,
    order_id = EXCLUDED.order_id,
    direction = EXCLUDED.direction,
    partner_org_id = EXCLUDED.partner_org_id,
    charge_type = EXCLUDED.charge_type,
    status = EXCLUDED.status,
    description = EXCLUDED.description,
    quantity = EXCLUDED.quantity,
    unit_price = EXCLUDED.unit_price,
    amount = EXCLUDED.amount,
    currency_code = EXCLUDED.currency_code,
    metadata = EXCLUDED.metadata;

  INSERT INTO tms.invoices (
    id,
    tenant_id,
    invoice_no,
    direction,
    organization_id,
    shipment_id,
    status,
    issue_date,
    due_date,
    currency_code,
    subtotal_amount,
    tax_amount,
    total_amount,
    paid_at,
    notes
  )
  VALUES
    ('00000000-0000-0000-0000-000000090001', v_tenant_id, 'INV-SAMPLE-AR-0001', 'receivable', v_billto_org_id, '00000000-0000-0000-0000-000000040001', 'paid', CURRENT_DATE - 1, CURRENT_DATE + 13, 'KRW', 1375000.00, 0.00, 1375000.00, ((CURRENT_DATE - 1) + TIME '19:00') AT TIME ZONE 'Asia/Seoul', 'Delivered order AR invoice'),
    ('00000000-0000-0000-0000-000000090002', v_tenant_id, 'INV-SAMPLE-AP-0001', 'payable', v_carrier_org_id, '00000000-0000-0000-0000-000000040001', 'paid', CURRENT_DATE - 1, CURRENT_DATE + 7, 'KRW', 965000.00, 0.00, 965000.00, (CURRENT_DATE + TIME '10:00') AT TIME ZONE 'Asia/Seoul', 'Carrier settlement complete'),
    ('00000000-0000-0000-0000-000000090003', v_tenant_id, 'INV-SAMPLE-AR-0002', 'receivable', v_billto_org_id, '00000000-0000-0000-0000-000000040002', 'issued', CURRENT_DATE, CURRENT_DATE + 14, 'KRW', 1130000.00, 0.00, 1130000.00, NULL, 'Current in-transit AR invoice'),
    ('00000000-0000-0000-0000-000000090004', v_tenant_id, 'INV-SAMPLE-AP-0002', 'payable', v_carrier_org_id, '00000000-0000-0000-0000-000000040002', 'draft', CURRENT_DATE, CURRENT_DATE + 10, 'KRW', 830000.00, 0.00, 830000.00, NULL, 'Pending carrier payable for reefer move')
  ON CONFLICT (id) DO UPDATE
  SET
    tenant_id = EXCLUDED.tenant_id,
    invoice_no = EXCLUDED.invoice_no,
    direction = EXCLUDED.direction,
    organization_id = EXCLUDED.organization_id,
    shipment_id = EXCLUDED.shipment_id,
    status = EXCLUDED.status,
    issue_date = EXCLUDED.issue_date,
    due_date = EXCLUDED.due_date,
    currency_code = EXCLUDED.currency_code,
    subtotal_amount = EXCLUDED.subtotal_amount,
    tax_amount = EXCLUDED.tax_amount,
    total_amount = EXCLUDED.total_amount,
    paid_at = EXCLUDED.paid_at,
    notes = EXCLUDED.notes;

  INSERT INTO tms.invoice_lines (
    id,
    invoice_id,
    charge_id,
    line_no,
    description,
    quantity,
    unit_price,
    line_amount,
    tax_amount
  )
  VALUES
    ('00000000-0000-0000-0000-000000100001', '00000000-0000-0000-0000-000000090001', '00000000-0000-0000-0000-000000080001', 1, 'Express linehaul charge', 1, 1250000.00, 1250000.00, 0.00),
    ('00000000-0000-0000-0000-000000100002', '00000000-0000-0000-0000-000000090001', '00000000-0000-0000-0000-000000080002', 2, 'Fuel surcharge', 1, 90000.00, 90000.00, 0.00),
    ('00000000-0000-0000-0000-000000100003', '00000000-0000-0000-0000-000000090001', '00000000-0000-0000-0000-000000080003', 3, 'Expressway toll', 1, 35000.00, 35000.00, 0.00),
    ('00000000-0000-0000-0000-000000100004', '00000000-0000-0000-0000-000000090002', '00000000-0000-0000-0000-000000080004', 1, 'Carrier linehaul payable', 1, 930000.00, 930000.00, 0.00),
    ('00000000-0000-0000-0000-000000100005', '00000000-0000-0000-0000-000000090002', '00000000-0000-0000-0000-000000080005', 2, 'Carrier toll reimbursement', 1, 35000.00, 35000.00, 0.00),
    ('00000000-0000-0000-0000-000000100006', '00000000-0000-0000-0000-000000090003', '00000000-0000-0000-0000-000000080006', 1, 'Cold-chain freight', 1, 980000.00, 980000.00, 0.00),
    ('00000000-0000-0000-0000-000000100007', '00000000-0000-0000-0000-000000090003', '00000000-0000-0000-0000-000000080007', 2, 'Reefer surcharge', 1, 150000.00, 150000.00, 0.00),
    ('00000000-0000-0000-0000-000000100008', '00000000-0000-0000-0000-000000090004', '00000000-0000-0000-0000-000000080008', 1, 'Carrier payable estimate', 1, 830000.00, 830000.00, 0.00)
  ON CONFLICT (id) DO UPDATE
  SET
    invoice_id = EXCLUDED.invoice_id,
    charge_id = EXCLUDED.charge_id,
    line_no = EXCLUDED.line_no,
    description = EXCLUDED.description,
    quantity = EXCLUDED.quantity,
    unit_price = EXCLUDED.unit_price,
    line_amount = EXCLUDED.line_amount,
    tax_amount = EXCLUDED.tax_amount;

  INSERT INTO tms.documents (
    id,
    tenant_id,
    entity_type,
    entity_id,
    document_type,
    file_name,
    storage_uri,
    content_type,
    file_size_bytes,
    uploaded_by,
    metadata
  )
  VALUES
    ('00000000-0000-0000-0000-000000110001', v_tenant_id, 'shipment', '00000000-0000-0000-0000-000000040001', 'bol', 'bol-sample-0001.pdf', 's3://sujin-tms-samples/bol/bol-sample-0001.pdf', 'application/pdf', 214532, v_dispatcher_user_id, '{"category":"shipping"}'::JSONB),
    ('00000000-0000-0000-0000-000000110002', v_tenant_id, 'shipment', '00000000-0000-0000-0000-000000040001', 'pod', 'pod-sample-0001.pdf', 's3://sujin-tms-samples/pod/pod-sample-0001.pdf', 'application/pdf', 198420, v_dispatcher_user_id, '{"category":"delivery"}'::JSONB),
    ('00000000-0000-0000-0000-000000110003', v_tenant_id, 'shipment', '00000000-0000-0000-0000-000000040002', 'rate_confirmation', 'rate-confirmation-0002.pdf', 's3://sujin-tms-samples/rate/rate-confirmation-0002.pdf', 'application/pdf', 165880, v_ops_user_id, '{"category":"pricing"}'::JSONB),
    ('00000000-0000-0000-0000-000000110004', v_tenant_id, 'invoice', '00000000-0000-0000-0000-000000090001', 'invoice', 'invoice-ar-0001.pdf', 's3://sujin-tms-samples/invoices/invoice-ar-0001.pdf', 'application/pdf', 120040, v_ops_user_id, '{"direction":"receivable"}'::JSONB),
    ('00000000-0000-0000-0000-000000110005', v_tenant_id, 'invoice', '00000000-0000-0000-0000-000000090002', 'invoice', 'invoice-ap-0001.pdf', 's3://sujin-tms-samples/invoices/invoice-ap-0001.pdf', 'application/pdf', 118940, v_ops_user_id, '{"direction":"payable"}'::JSONB)
  ON CONFLICT (id) DO UPDATE
  SET
    tenant_id = EXCLUDED.tenant_id,
    entity_type = EXCLUDED.entity_type,
    entity_id = EXCLUDED.entity_id,
    document_type = EXCLUDED.document_type,
    file_name = EXCLUDED.file_name,
    storage_uri = EXCLUDED.storage_uri,
    content_type = EXCLUDED.content_type,
    file_size_bytes = EXCLUDED.file_size_bytes,
    uploaded_by = EXCLUDED.uploaded_by,
    metadata = EXCLUDED.metadata;
END
$$;

COMMIT;
