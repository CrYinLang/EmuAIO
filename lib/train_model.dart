// train_model.dart - 列车图标模型映射相关逻辑
class TrainModelUtils {
  static final List<String> _bureauFullNames = [
    '北京铁路局',
    '上海铁路局',
    '广州铁路局',
    '郑州铁路局',
    '西安铁路局',
    '成都铁路局',
    '沈阳铁路局',
    '哈尔滨铁路局',
    '呼和浩特铁路局',
    '太原铁路局',
    '济南铁路局',
    '南昌铁路局',
    '兰州铁路局',
    '乌鲁木齐铁路局',
    '青藏铁路局',
    '昆明铁路局',
    '南宁铁路局',
    '武汉铁路局',
    '广东城际',
  ];

  static List<String> getBureauFullNames() {
    return List<String>.from(_bureauFullNames);
  }

  // 获取列车图标模型名称（保持不变）
  static String getTrainIconModel(String model, String number) {
    String modelC = model.trim();
    String cleanedNumber = number.trim();

    if (modelC == 'CRH6A') {
      int? num = int.tryParse(cleanedNumber.replaceAll(RegExp(r'[^0-9]'), ''));
      if (num != null) {
        if ((num >= 401 && num <= 408) || (num >= 602 && num <= 610) ||
            num == 420 || num == 421) {
          return 'CRH6-2';
        }
      }
    }

    if (modelC == 'CRH3A-A') {
      int? num = int.tryParse(cleanedNumber.replaceAll(RegExp(r'[^0-9]'), ''));
      if (num != null) {
        if ((num >= 511 && num <= 521)) {
          return 'CRH3A-A-GKCJ';
        }
      }
    }

    if (modelC == 'CRH3A-A') {
      int? num = int.tryParse(cleanedNumber.replaceAll(RegExp(r'[^0-9]'), ''));
      if (num != null) {
        if ((num >= 524 && num <= 528)) {
          return 'CRH3A-A-ZKCJ';
        }
      }
    }

    if (modelC == 'CRH1B') {
      int? num = int.tryParse(cleanedNumber.replaceAll(RegExp(r'[^0-9]'), ''));
      if (num != null) {
        if ((num >= 1076 && num <= 1080)) {
          return 'CRH1E';
        }
      }
    }

    if (modelC == 'CRH1E') {
      int? num = int.tryParse(cleanedNumber.replaceAll(RegExp(r'[^0-9]'), ''));
      if (num != null) {
        if ((num >= 1229 && num <= 1233)) {
          return 'CRH1E-NG';
        }
      }
    }


    if (modelC == 'CRH6F-A') return 'CRH6A';

    if (modelC.contains('CRH6F')) {
      return 'CRH6F';
    }

    // 列车图标模型映射规则
    if (modelC == 'CRH3A' && cleanedNumber == '0302') return 'CRH3A-YC';
    if (modelC == 'CRH3A' && cleanedNumber == '0502') return 'CRH3A-YC';
    if (modelC == 'CRH380AL' || modelC == 'CRH380AN') return 'CRH380A';
    if (modelC == 'CRH2B') return 'CRH2BE';
    if (modelC == 'CRH2E') return 'CRH2BE';
    if (modelC == 'CRH380BL') return 'CRH380B';
    if (modelC == 'CRH380BG') return 'CRH380B';
    if (modelC == 'CRH2A' && cleanedNumber == '2460') return 'CRH2A-2460';
    if (modelC == 'CRH2C' && cleanedNumber == '2150') return 'CRH380A';
    if (modelC == 'CRH6F' && cleanedNumber == '0001') return 'CRH6-2';
    if (modelC == 'CR400BF' && cleanedNumber == '0031') return 'CR400BF-0031';
    if (modelC == 'CR400BF-G' && cleanedNumber == '0051') return 'CR400BF-0031';
    if (modelC == 'CR400BF-C' && cleanedNumber == '5162') return 'CR400BF-C-5162';
    if (modelC == 'CR400BF-J' && cleanedNumber == '0001') return 'CR400BF-J-0001';
    if (modelC == 'CR400BF-J' && cleanedNumber == '0003') return 'CR400BF-J-0003';
    if (modelC == 'CR400BF-Z' && cleanedNumber == '0524') return 'CR400BF-Z-0524';

    if (modelC == 'CRH6A-A') return 'CRH6A';
    if (modelC == 'CRH6A-AZ') return 'CRH6A';

    if (modelC == 'CR400AF-Z' || modelC == 'CR400AF-AZ' || modelC == 'CR400AF-BZ' ||
        modelC == 'CR400AF-S' || modelC == 'CR400AF-AS' || modelC == 'CR400AF-BS' ||
        modelC == 'CR400AF-AE' || modelC == 'CR400AF-C') {
      return 'CR400AF-SZE';
    }
    if (modelC == 'CR400BF-S' || modelC == 'CR400BF-AS' || modelC == 'CR400BF-BS' ||
        modelC == 'CR400BF-GS') {
      return 'CR400BF-S';
    }
    if (modelC == 'CR400BF-Z' || modelC == 'CR400BF-AZ' || modelC == 'CR400BF-BZ' ||
        modelC == 'CR400BF-GZ') {
      return 'CR400BF-Z';
    }
    if (modelC == 'CR400AF-A' || modelC == 'CR400AF-B' || modelC == 'CR400AF-G') {
      return 'CR400AF';
    }
    if (modelC == 'CR400BF-A' || modelC == 'CR400BF-B' || modelC == 'CR400BF-G') {
      return 'CR400BF';
    }

    if (modelC == 'CRH380A') {
      int? num = int.tryParse(cleanedNumber.replaceAll(RegExp(r'[^0-9]'), ''));
      if (num != null && num >= 251 && num <= 259) {
        return 'CRH380AD';
      }
    }

    if (modelC == 'CRH6A-A') {
      int? num = int.tryParse(cleanedNumber.replaceAll(RegExp(r'[^0-9]'), ''));
      if (num != null) {
        if ((num >= 220 && num <= 223) || (num >= 230 && num <= 231)) {
          return 'CRH6A-A-XCKX-1';
        }
        if (num >= 228 && num <= 229) return 'CRH6A-A-SLCJ';
        if (num == 524) return 'CRH6F';
      }
    }

    return modelC;
  }
}