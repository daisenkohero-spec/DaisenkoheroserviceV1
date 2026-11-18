import 'dart:js_interop';

@JS('location.reload')
external void _locationReload();

void reloadPage() => _locationReload();
