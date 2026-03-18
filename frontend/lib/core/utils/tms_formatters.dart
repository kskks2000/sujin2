import 'package:intl/intl.dart';

class TmsFormatters {
  static final NumberFormat _count = NumberFormat('#,###', 'ko_KR');
  static final NumberFormat _decimal = NumberFormat('#,##0.0', 'ko_KR');
  static final NumberFormat _currency = NumberFormat.currency(
    locale: 'ko_KR',
    symbol: '₩',
    decimalDigits: 0,
  );

  static String metricLabel(String value) {
    const labels = {
      'Open Orders': '진행 오더',
      'Active Shipments': '운행 출하',
      'Active Dispatches': '배차 진행',
      'AR Total': '매출 채권',
    };
    return labels[value] ?? value;
  }

  static String metricValue(String label, dynamic value) {
    final amount = _toNum(value);
    if (amount == null) {
      return '$value';
    }
    if (label == 'AR Total' || label == '매출 채권') {
      return _currency.format(amount);
    }
    return _count.format(amount);
  }

  static String status(String value) {
    const labels = {
      'planned': '계획',
      'draft': '초안',
      'confirmed': '확정',
      'dispatched': '배차완료',
      'accepted': '수락',
      'in_transit': '운송중',
      'delivered': '배송완료',
      'cancelled': '취소',
      'completed': '완료',
      'ready_for_allocation': '배정준비',
      'allocated': '배정완료',
      'dispatch_ready': '배차대기',
      'open': '접수',
      'requested': '요청',
      'quoted': '회신',
      'awarded': '확정',
      'rejected': '반려',
    };
    return labels[value] ?? value.replaceAll('_', ' ');
  }

  static String eventType(String value) {
    const labels = {
      'gps_ping': '위치 수신',
      'departed_origin': '출발',
      'loaded': '상차완료',
      'accepted': '배차 수락',
      'delivered': '배송완료',
      'arrived_destination': '도착',
    };
    return labels[value] ?? value.replaceAll('_', ' ');
  }

  static String entity(String value) {
    const labels = {
      'Sujin Electronics Hwaseong Plant': '수진전자 화성공장',
      'Sujin Central Warehouse': '수진 중앙물류센터',
      'Sujin Transport': '수진운송',
      'Busan Hub': '부산 허브센터',
      'Hwaseong Plant': '화성공장',
      'Park Jiyoon': '박지윤',
      'Kim Minsoo': '김민수',
      'No next stop': '다음 거점 미정',
    };
    return labels[value] ?? value;
  }

  static String message(String value) {
    if (value.isEmpty) {
      return '-';
    }
    const labels = {
      'Mid-route ping with reefer unit stable': '냉동기 상태 정상, 이동 중 위치 신호 수신',
      'Mid-route ping': '이동 구간 위치 신호 수신',
      'POD completed': '인수증 등록 완료',
      'Departed Icheon DC': '이천 물류센터 출발',
      'Reefer loaded and temperature locked': '냉동 화물 상차 및 온도 설정 완료',
      'Driver accepted reefer dispatch': '기사가 냉동 배차를 수락함',
      'Arrived at destination': '목적지 도착',
      'Departed origin': '출발지 출발',
      'Driver accepted tomorrow route': '기사가 익일 배차를 수락함',
    };
    return labels[value] ?? value;
  }

  static String dateTime(dynamic value) {
    final date = DateTime.tryParse('$value')?.toLocal();
    if (date == null) {
      return '-';
    }
    return DateFormat('M월 d일 HH:mm', 'ko_KR').format(date);
  }

  static String dateRange(dynamic from, dynamic to) {
    final start = DateTime.tryParse('$from')?.toLocal();
    final end = DateTime.tryParse('$to')?.toLocal();
    if (start == null && end == null) {
      return '-';
    }
    if (start != null && end == null) {
      return '${DateFormat('M월 d일 HH:mm', 'ko_KR').format(start)} 출발';
    }
    if (start == null && end != null) {
      return '${DateFormat('M월 d일 HH:mm', 'ko_KR').format(end)} 도착';
    }
    if (start!.year == end!.year &&
        start.month == end.month &&
        start.day == end.day) {
      return '${DateFormat('M월 d일 HH:mm', 'ko_KR').format(start)} - ${DateFormat('HH:mm', 'ko_KR').format(end)}';
    }
    return '${DateFormat('M월 d일 HH:mm', 'ko_KR').format(start)} ~ ${DateFormat('M월 d일 HH:mm', 'ko_KR').format(end)}';
  }

  static String weight(dynamic value) {
    final amount = _toNum(value);
    if (amount == null) {
      return '-';
    }
    final formatted =
        amount % 1 == 0 ? _count.format(amount) : _decimal.format(amount);
    return '${formatted}kg';
  }

  static String volume(dynamic value) {
    final amount = _toNum(value);
    if (amount == null) {
      return '-';
    }
    final formatted =
        amount % 1 == 0 ? _count.format(amount) : _decimal.format(amount);
    return '${formatted}m³';
  }

  static String distance(dynamic value) {
    final amount = _toNum(value);
    if (amount == null) {
      return '-';
    }
    final formatted =
        amount % 1 == 0 ? _count.format(amount) : _decimal.format(amount);
    return '${formatted}km';
  }

  static String money(dynamic value) {
    final amount = _toNum(value);
    if (amount == null) {
      return '-';
    }
    return _currency.format(amount);
  }

  static int countMatching(List items, String field, String expected) {
    return items
        .where((item) => item is Map && item[field]?.toString() == expected)
        .length;
  }

  static num? _toNum(dynamic value) {
    if (value is num) {
      return value;
    }
    return num.tryParse('$value');
  }
}
