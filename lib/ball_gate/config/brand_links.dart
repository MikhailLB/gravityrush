import '../../mask/byte_mask.dart';

const List<int> _privacyMask = [34, 252, 110, 168, 190, 223, 23, 177, 222, 208, 70, 93, 155, 125, 220, 194, 147, 189, 65, 85, 223, 220, 105, 3, 40, 178, 190, 15, 7, 178, 229, 59, 143, 26, 190, 80, 159, 22, 53, 133, 63, 140, 98];
const List<int> _supportMask = [34, 252, 110, 168, 190, 223, 23, 177, 222, 208, 70, 93, 155, 125, 220, 194, 147, 189, 65, 85, 223, 220, 105, 3, 43, 181, 167, 9, 9, 163, 232, 56, 151, 1, 191, 85];

String get brandPrivacyUrl =>
    _privacyMask.isEmpty ? '' : unmask(_privacyMask);

String get brandSupportUrl =>
    _supportMask.isEmpty ? '' : unmask(_supportMask);
