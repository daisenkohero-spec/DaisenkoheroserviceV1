// โหลดหน้าเว็บใหม่ (เฉพาะเว็บ) — บนมือถือเป็น no-op
export 'page_reload_stub.dart'
    if (dart.library.js_interop) 'page_reload_web.dart';
