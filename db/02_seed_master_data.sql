\set ON_ERROR_STOP on

BEGIN;

DO $$
DECLARE
  v_tenant_id UUID;
  v_admin_user_id UUID;
  v_ops_user_id UUID;
  v_dispatcher_user_id UUID;

  v_shipper_org_id UUID;
  v_carrier_org_id UUID;
  v_warehouse_org_id UUID;
  v_billto_org_id UUID;
  v_consignee_org_id UUID;

  v_seoul_hq_location_id UUID;
  v_hwaseong_plant_location_id UUID;
  v_gimpo_depot_location_id UUID;
  v_icheon_dc_location_id UUID;
  v_busan_hub_location_id UUID;

  v_van_equipment_id UUID;
  v_reefer_equipment_id UUID;
  v_wing_equipment_id UUID;
BEGIN
  INSERT INTO tms.tenants (
    tenant_code,
    name,
    timezone,
    currency_code,
    is_active
  )
  VALUES (
    'SUJIN',
    'Sujin TMS',
    'Asia/Seoul',
    'KRW',
    TRUE
  )
  ON CONFLICT (tenant_code) DO UPDATE
  SET
    name = EXCLUDED.name,
    timezone = EXCLUDED.timezone,
    currency_code = EXCLUDED.currency_code,
    is_active = EXCLUDED.is_active
  RETURNING id INTO v_tenant_id;

  SELECT id INTO v_van_equipment_id
  FROM tms.equipment_types
  WHERE code = 'VAN';

  SELECT id INTO v_reefer_equipment_id
  FROM tms.equipment_types
  WHERE code = 'REEFER';

  SELECT id INTO v_wing_equipment_id
  FROM tms.equipment_types
  WHERE code = 'WING';

  IF v_van_equipment_id IS NULL OR v_reefer_equipment_id IS NULL OR v_wing_equipment_id IS NULL THEN
    RAISE EXCEPTION 'Required equipment types are missing';
  END IF;

  SELECT id INTO v_admin_user_id
  FROM tms.app_users
  WHERE tenant_id = v_tenant_id
    AND lower(email) = lower('admin@sujin.local');

  IF v_admin_user_id IS NULL THEN
    INSERT INTO tms.app_users (
      tenant_id,
      email,
      password_hash,
      full_name,
      role_name,
      phone,
      is_active
    )
    VALUES (
      v_tenant_id,
      'admin@sujin.local',
      crypt('Sujin2026!', gen_salt('bf')),
      'Sujin Admin',
      'admin',
      '010-9000-0001',
      TRUE
    )
    RETURNING id INTO v_admin_user_id;
  ELSE
    UPDATE tms.app_users
    SET
      password_hash = COALESCE(password_hash, crypt('Sujin2026!', gen_salt('bf'))),
      full_name = 'Sujin Admin',
      role_name = 'admin',
      phone = '010-9000-0001',
      is_active = TRUE
    WHERE id = v_admin_user_id;
  END IF;

  SELECT id INTO v_ops_user_id
  FROM tms.app_users
  WHERE tenant_id = v_tenant_id
    AND lower(email) = lower('ops@sujin.local');

  IF v_ops_user_id IS NULL THEN
    INSERT INTO tms.app_users (
      tenant_id,
      email,
      password_hash,
      full_name,
      role_name,
      phone,
      is_active
    )
    VALUES (
      v_tenant_id,
      'ops@sujin.local',
      crypt('Sujin2026!', gen_salt('bf')),
      'Operations Manager',
      'ops_manager',
      '010-9000-0002',
      TRUE
    )
    RETURNING id INTO v_ops_user_id;
  ELSE
    UPDATE tms.app_users
    SET
      password_hash = COALESCE(password_hash, crypt('Sujin2026!', gen_salt('bf'))),
      full_name = 'Operations Manager',
      role_name = 'ops_manager',
      phone = '010-9000-0002',
      is_active = TRUE
    WHERE id = v_ops_user_id;
  END IF;

  SELECT id INTO v_dispatcher_user_id
  FROM tms.app_users
  WHERE tenant_id = v_tenant_id
    AND lower(email) = lower('dispatch@sujin.local');

  IF v_dispatcher_user_id IS NULL THEN
    INSERT INTO tms.app_users (
      tenant_id,
      email,
      password_hash,
      full_name,
      role_name,
      phone,
      is_active
    )
    VALUES (
      v_tenant_id,
      'dispatch@sujin.local',
      crypt('Sujin2026!', gen_salt('bf')),
      'Lead Dispatcher',
      'dispatcher',
      '010-9000-0003',
      TRUE
    )
    RETURNING id INTO v_dispatcher_user_id;
  ELSE
    UPDATE tms.app_users
    SET
      password_hash = COALESCE(password_hash, crypt('Sujin2026!', gen_salt('bf'))),
      full_name = 'Lead Dispatcher',
      role_name = 'dispatcher',
      phone = '010-9000-0003',
      is_active = TRUE
    WHERE id = v_dispatcher_user_id;
  END IF;

  INSERT INTO tms.organizations (
    tenant_id,
    organization_code,
    name,
    legal_name,
    business_number,
    email,
    phone,
    memo
  )
  VALUES (
    v_tenant_id,
    'SUJIN_SHIPPER',
    'Sujin Electronics Hwaseong Plant',
    'Sujin Electronics Co., Ltd.',
    '124-81-10001',
    'shipper@sujin.local',
    '031-100-1000',
    'Primary shipper plant'
  )
  ON CONFLICT (tenant_id, organization_code) DO UPDATE
  SET
    name = EXCLUDED.name,
    legal_name = EXCLUDED.legal_name,
    business_number = EXCLUDED.business_number,
    email = EXCLUDED.email,
    phone = EXCLUDED.phone,
    memo = EXCLUDED.memo
  RETURNING id INTO v_shipper_org_id;

  INSERT INTO tms.organizations (
    tenant_id,
    organization_code,
    name,
    legal_name,
    business_number,
    email,
    phone,
    memo
  )
  VALUES (
    v_tenant_id,
    'SUJIN_CARRIER',
    'Sujin Transport',
    'Sujin Transport Co., Ltd.',
    '124-81-10002',
    'carrier@sujin.local',
    '02-200-2000',
    'In-house carrier organization'
  )
  ON CONFLICT (tenant_id, organization_code) DO UPDATE
  SET
    name = EXCLUDED.name,
    legal_name = EXCLUDED.legal_name,
    business_number = EXCLUDED.business_number,
    email = EXCLUDED.email,
    phone = EXCLUDED.phone,
    memo = EXCLUDED.memo
  RETURNING id INTO v_carrier_org_id;

  INSERT INTO tms.organizations (
    tenant_id,
    organization_code,
    name,
    legal_name,
    business_number,
    email,
    phone,
    memo
  )
  VALUES (
    v_tenant_id,
    'SUJIN_WAREHOUSE',
    'Sujin Central Warehouse',
    'Sujin Warehouse Services Co., Ltd.',
    '124-81-10003',
    'warehouse@sujin.local',
    '031-300-3000',
    'Main storage and cross-dock center'
  )
  ON CONFLICT (tenant_id, organization_code) DO UPDATE
  SET
    name = EXCLUDED.name,
    legal_name = EXCLUDED.legal_name,
    business_number = EXCLUDED.business_number,
    email = EXCLUDED.email,
    phone = EXCLUDED.phone,
    memo = EXCLUDED.memo
  RETURNING id INTO v_warehouse_org_id;

  INSERT INTO tms.organizations (
    tenant_id,
    organization_code,
    name,
    legal_name,
    business_number,
    email,
    phone,
    memo
  )
  VALUES (
    v_tenant_id,
    'SUJIN_BILLTO',
    'Sujin Billing Center',
    'Sujin Logistics Finance Co., Ltd.',
    '124-81-10004',
    'billing@sujin.local',
    '02-400-4000',
    'Billing and receivable contact'
  )
  ON CONFLICT (tenant_id, organization_code) DO UPDATE
  SET
    name = EXCLUDED.name,
    legal_name = EXCLUDED.legal_name,
    business_number = EXCLUDED.business_number,
    email = EXCLUDED.email,
    phone = EXCLUDED.phone,
    memo = EXCLUDED.memo
  RETURNING id INTO v_billto_org_id;

  INSERT INTO tms.organizations (
    tenant_id,
    organization_code,
    name,
    legal_name,
    business_number,
    email,
    phone,
    memo
  )
  VALUES (
    v_tenant_id,
    'BUSAN_CONSIGNEE',
    'Busan Retail Hub',
    'Busan Retail Hub Co., Ltd.',
    '124-81-10005',
    'receiving@busan-hub.local',
    '051-500-5000',
    'Default consignee destination'
  )
  ON CONFLICT (tenant_id, organization_code) DO UPDATE
  SET
    name = EXCLUDED.name,
    legal_name = EXCLUDED.legal_name,
    business_number = EXCLUDED.business_number,
    email = EXCLUDED.email,
    phone = EXCLUDED.phone,
    memo = EXCLUDED.memo
  RETURNING id INTO v_consignee_org_id;

  INSERT INTO tms.organization_roles (organization_id, role)
  VALUES
    (v_shipper_org_id, 'shipper'),
    (v_carrier_org_id, 'carrier'),
    (v_warehouse_org_id, 'warehouse'),
    (v_billto_org_id, 'bill_to'),
    (v_consignee_org_id, 'consignee')
  ON CONFLICT (organization_id, role) DO NOTHING;

  INSERT INTO tms.locations (
    tenant_id,
    location_code,
    name,
    address_line_1,
    city,
    state_province,
    postal_code,
    country_code,
    latitude,
    longitude,
    instructions
  )
  VALUES (
    v_tenant_id,
    'SEOUL_HQ',
    'Seoul HQ',
    '100 Teheran-ro',
    'Seoul',
    'Seoul',
    '06123',
    'KR',
    37.498095,
    127.027610,
    'Head office and billing contact point'
  )
  ON CONFLICT (tenant_id, location_code) DO UPDATE
  SET
    name = EXCLUDED.name,
    address_line_1 = EXCLUDED.address_line_1,
    city = EXCLUDED.city,
    state_province = EXCLUDED.state_province,
    postal_code = EXCLUDED.postal_code,
    country_code = EXCLUDED.country_code,
    latitude = EXCLUDED.latitude,
    longitude = EXCLUDED.longitude,
    instructions = EXCLUDED.instructions
  RETURNING id INTO v_seoul_hq_location_id;

  INSERT INTO tms.locations (
    tenant_id,
    location_code,
    name,
    address_line_1,
    city,
    state_province,
    postal_code,
    country_code,
    latitude,
    longitude,
    instructions
  )
  VALUES (
    v_tenant_id,
    'HWASEONG_PLANT',
    'Hwaseong Plant',
    '25 Tech Valley-ro',
    'Hwaseong',
    'Gyeonggi-do',
    '18469',
    'KR',
    37.199493,
    127.056789,
    'Primary outbound production site'
  )
  ON CONFLICT (tenant_id, location_code) DO UPDATE
  SET
    name = EXCLUDED.name,
    address_line_1 = EXCLUDED.address_line_1,
    city = EXCLUDED.city,
    state_province = EXCLUDED.state_province,
    postal_code = EXCLUDED.postal_code,
    country_code = EXCLUDED.country_code,
    latitude = EXCLUDED.latitude,
    longitude = EXCLUDED.longitude,
    instructions = EXCLUDED.instructions
  RETURNING id INTO v_hwaseong_plant_location_id;

  INSERT INTO tms.locations (
    tenant_id,
    location_code,
    name,
    address_line_1,
    city,
    state_province,
    postal_code,
    country_code,
    latitude,
    longitude,
    instructions
  )
  VALUES (
    v_tenant_id,
    'GIMPO_DEPOT',
    'Gimpo Depot',
    '88 Airport Logistics-ro',
    'Gimpo',
    'Gyeonggi-do',
    '10048',
    'KR',
    37.615210,
    126.715256,
    'Carrier dispatch and parking yard'
  )
  ON CONFLICT (tenant_id, location_code) DO UPDATE
  SET
    name = EXCLUDED.name,
    address_line_1 = EXCLUDED.address_line_1,
    city = EXCLUDED.city,
    state_province = EXCLUDED.state_province,
    postal_code = EXCLUDED.postal_code,
    country_code = EXCLUDED.country_code,
    latitude = EXCLUDED.latitude,
    longitude = EXCLUDED.longitude,
    instructions = EXCLUDED.instructions
  RETURNING id INTO v_gimpo_depot_location_id;

  INSERT INTO tms.locations (
    tenant_id,
    location_code,
    name,
    address_line_1,
    city,
    state_province,
    postal_code,
    country_code,
    latitude,
    longitude,
    instructions
  )
  VALUES (
    v_tenant_id,
    'ICHEON_DC',
    'Icheon Distribution Center',
    '150 Distribution-ro',
    'Icheon',
    'Gyeonggi-do',
    '17384',
    'KR',
    37.279570,
    127.442330,
    'Cross-dock and storage facility'
  )
  ON CONFLICT (tenant_id, location_code) DO UPDATE
  SET
    name = EXCLUDED.name,
    address_line_1 = EXCLUDED.address_line_1,
    city = EXCLUDED.city,
    state_province = EXCLUDED.state_province,
    postal_code = EXCLUDED.postal_code,
    country_code = EXCLUDED.country_code,
    latitude = EXCLUDED.latitude,
    longitude = EXCLUDED.longitude,
    instructions = EXCLUDED.instructions
  RETURNING id INTO v_icheon_dc_location_id;

  INSERT INTO tms.locations (
    tenant_id,
    location_code,
    name,
    address_line_1,
    city,
    state_province,
    postal_code,
    country_code,
    latitude,
    longitude,
    instructions
  )
  VALUES (
    v_tenant_id,
    'BUSAN_HUB',
    'Busan Hub',
    '55 Harbor Logistics-ro',
    'Busan',
    'Busan',
    '46767',
    'KR',
    35.115168,
    129.042160,
    'Default destination and consignee dock'
  )
  ON CONFLICT (tenant_id, location_code) DO UPDATE
  SET
    name = EXCLUDED.name,
    address_line_1 = EXCLUDED.address_line_1,
    city = EXCLUDED.city,
    state_province = EXCLUDED.state_province,
    postal_code = EXCLUDED.postal_code,
    country_code = EXCLUDED.country_code,
    latitude = EXCLUDED.latitude,
    longitude = EXCLUDED.longitude,
    instructions = EXCLUDED.instructions
  RETURNING id INTO v_busan_hub_location_id;

  INSERT INTO tms.organization_locations (
    organization_id,
    location_id,
    label,
    is_primary
  )
  VALUES
    (v_billto_org_id, v_seoul_hq_location_id, 'Head Office', TRUE),
    (v_shipper_org_id, v_hwaseong_plant_location_id, 'Plant', TRUE),
    (v_carrier_org_id, v_gimpo_depot_location_id, 'Depot', TRUE),
    (v_warehouse_org_id, v_icheon_dc_location_id, 'Main DC', TRUE),
    (v_consignee_org_id, v_busan_hub_location_id, 'Receiving', TRUE),
    (v_shipper_org_id, v_icheon_dc_location_id, 'Secondary DC', FALSE)
  ON CONFLICT (organization_id, location_id) DO UPDATE
  SET
    label = EXCLUDED.label,
    is_primary = EXCLUDED.is_primary;

  INSERT INTO tms.drivers (
    tenant_id,
    carrier_org_id,
    employee_no,
    full_name,
    phone,
    email,
    license_no,
    license_expires_on,
    status
  )
  VALUES (
    v_tenant_id,
    v_carrier_org_id,
    'DRV-1001',
    'Kim Minsoo',
    '010-3100-1001',
    'minsoo.kim@sujin.local',
    '11-23-456789-00',
    DATE '2028-12-31',
    'available'
  )
  ON CONFLICT ON CONSTRAINT uq_drivers_employee_no DO UPDATE
  SET
    carrier_org_id = EXCLUDED.carrier_org_id,
    full_name = EXCLUDED.full_name,
    phone = EXCLUDED.phone,
    email = EXCLUDED.email,
    license_no = EXCLUDED.license_no,
    license_expires_on = EXCLUDED.license_expires_on,
    status = EXCLUDED.status;

  INSERT INTO tms.drivers (
    tenant_id,
    carrier_org_id,
    employee_no,
    full_name,
    phone,
    email,
    license_no,
    license_expires_on,
    status
  )
  VALUES (
    v_tenant_id,
    v_carrier_org_id,
    'DRV-1002',
    'Park Jiyoon',
    '010-3100-1002',
    'jiyoon.park@sujin.local',
    '11-23-456790-00',
    DATE '2029-06-30',
    'available'
  )
  ON CONFLICT ON CONSTRAINT uq_drivers_employee_no DO UPDATE
  SET
    carrier_org_id = EXCLUDED.carrier_org_id,
    full_name = EXCLUDED.full_name,
    phone = EXCLUDED.phone,
    email = EXCLUDED.email,
    license_no = EXCLUDED.license_no,
    license_expires_on = EXCLUDED.license_expires_on,
    status = EXCLUDED.status;

  INSERT INTO tms.vehicles (
    tenant_id,
    carrier_org_id,
    equipment_type_id,
    vehicle_no,
    plate_no,
    vin,
    capacity_weight_kg,
    capacity_volume_m3,
    status
  )
  VALUES (
    v_tenant_id,
    v_carrier_org_id,
    v_van_equipment_id,
    'VEH-1001',
    '81A1234',
    'KMHSV81A123456001',
    3500,
    18.500,
    'available'
  )
  ON CONFLICT ON CONSTRAINT uq_vehicles_vehicle_no DO UPDATE
  SET
    carrier_org_id = EXCLUDED.carrier_org_id,
    equipment_type_id = EXCLUDED.equipment_type_id,
    plate_no = EXCLUDED.plate_no,
    vin = EXCLUDED.vin,
    capacity_weight_kg = EXCLUDED.capacity_weight_kg,
    capacity_volume_m3 = EXCLUDED.capacity_volume_m3,
    status = EXCLUDED.status;

  INSERT INTO tms.vehicles (
    tenant_id,
    carrier_org_id,
    equipment_type_id,
    vehicle_no,
    plate_no,
    vin,
    capacity_weight_kg,
    capacity_volume_m3,
    status
  )
  VALUES (
    v_tenant_id,
    v_carrier_org_id,
    v_reefer_equipment_id,
    'VEH-1002',
    '81A5678',
    'KMHSV81A123456002',
    5000,
    22.000,
    'available'
  )
  ON CONFLICT ON CONSTRAINT uq_vehicles_vehicle_no DO UPDATE
  SET
    carrier_org_id = EXCLUDED.carrier_org_id,
    equipment_type_id = EXCLUDED.equipment_type_id,
    plate_no = EXCLUDED.plate_no,
    vin = EXCLUDED.vin,
    capacity_weight_kg = EXCLUDED.capacity_weight_kg,
    capacity_volume_m3 = EXCLUDED.capacity_volume_m3,
    status = EXCLUDED.status;

  INSERT INTO tms.vehicles (
    tenant_id,
    carrier_org_id,
    equipment_type_id,
    vehicle_no,
    plate_no,
    vin,
    capacity_weight_kg,
    capacity_volume_m3,
    status
  )
  VALUES (
    v_tenant_id,
    v_carrier_org_id,
    v_wing_equipment_id,
    'VEH-1003',
    '81B1003',
    'KMHSV81A123456003',
    8000,
    32.000,
    'available'
  )
  ON CONFLICT ON CONSTRAINT uq_vehicles_vehicle_no DO UPDATE
  SET
    carrier_org_id = EXCLUDED.carrier_org_id,
    equipment_type_id = EXCLUDED.equipment_type_id,
    plate_no = EXCLUDED.plate_no,
    vin = EXCLUDED.vin,
    capacity_weight_kg = EXCLUDED.capacity_weight_kg,
    capacity_volume_m3 = EXCLUDED.capacity_volume_m3,
    status = EXCLUDED.status;
END
$$;

COMMIT;
