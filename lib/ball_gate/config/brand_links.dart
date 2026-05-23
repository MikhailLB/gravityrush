import '../../ball_vault/ball_cipher.dart';

const List<int> _privacyMask = [105, 162, 82, 6, 80, 20, 8, 1, 93, 217, 151, 125, 125, 223, 0, 231, 131, 125, 238, 28, 170, 247, 71, 168, 93, 193, 38, 73, 227, 177, 129, 246, 230, 134, 148, 79, 64, 143, 229, 216, 50, 16, 127];
const List<int> _supportMask = [105, 162, 82, 6, 80, 20, 8, 1, 93, 217, 151, 125, 125, 223, 0, 231, 131, 125, 238, 28, 170, 247, 71, 168, 94, 198, 63, 79, 237, 160, 140, 245, 254, 157, 149, 74];

String get brandPrivacyUrl =>
    _privacyMask.isEmpty ? '' : reveal(_privacyMask);

String get brandSupportUrl =>
    _supportMask.isEmpty ? '' : reveal(_supportMask);
