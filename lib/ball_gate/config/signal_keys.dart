import '../../mask/byte_mask.dart';

String appsflyerDevKey() {
  const v = [9, 240, 73, 129, 191, 178, 125, 248, 218, 201, 65, 66, 136, 72, 253, 231, 171, 144, 30, 57, 233, 134];
  return unmask(v);
}

String firebaseProjectNum() {
  const v = [124, 188, 42, 239, 250, 212, 1, 167, 142, 134, 0, 3];
  return unmask(v);
}
