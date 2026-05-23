import '../../ball_vault/ball_cipher.dart';

// TODO: fill with dart run tool/encode_creds.dart output
const List<int> _privacyMask = <int>[];
const List<int> _supportMask = <int>[];

String get brandPrivacyUrl =>
    _privacyMask.isEmpty ? '' : reveal(_privacyMask);

String get brandSupportUrl =>
    _supportMask.isEmpty ? '' : reveal(_supportMask);
