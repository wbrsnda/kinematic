
@JS()
library interop;

import 'dart:js_interop';
import 'dart:typed_data';

@JS('Blob')
extension type JSBlob._(JSObject it) {
  external JSPromise<JSArrayBuffer> arrayBuffer();
}

extension JSArrayBufferExt on JSArrayBuffer {
  ByteBuffer toByteBuffer() => this.toDart;
}
