/// Geohash (base32) แบบเดียวกับที่ GeoFire / geofire-common ใช้
/// ใช้ค้นหาช่างตามรัศมีใน Firestore (ทิกเก็ตกระจายงาน)
const _base32 = '0123456789bcdefghjkmnpqrstuvwxyz';

String encodeGeohash(double lat, double lng, {int precision = 10}) {
  var latMin = -90.0, latMax = 90.0;
  var lngMin = -180.0, lngMax = 180.0;
  final out = StringBuffer();
  var bit = 0, ch = 0;
  var evenBit = true;

  while (out.length < precision) {
    if (evenBit) {
      final mid = (lngMin + lngMax) / 2;
      if (lng >= mid) {
        ch = (ch << 1) | 1;
        lngMin = mid;
      } else {
        ch = ch << 1;
        lngMax = mid;
      }
    } else {
      final mid = (latMin + latMax) / 2;
      if (lat >= mid) {
        ch = (ch << 1) | 1;
        latMin = mid;
      } else {
        ch = ch << 1;
        latMax = mid;
      }
    }
    evenBit = !evenBit;
    if (++bit == 5) {
      out.write(_base32[ch]);
      bit = 0;
      ch = 0;
    }
  }
  return out.toString();
}
