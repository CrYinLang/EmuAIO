//home_page.dart
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import 'train_model.dart';
import 'main.dart';

// 搜索结果数据类（统一所有查询类型的结果）
class SearchResult {
  final String model;
  final String number;
  final String bureau;
  final String bureauFullName;
  final String? depot;
  final String? manufacturer;
  final String? stationinfo;
  final String? remarks;
  final String? routeInfo;
  final double? score;
  final int? rank;
  final bool isAmbiguousMatch;
  final bool isCoupledTrain;
  final String queryTime;

  SearchResult({
    required this.model,
    required this.number,
    required this.bureau,
    required this.bureauFullName,
    this.depot,
    this.manufacturer,
    this.stationinfo,
    this.remarks,
    this.routeInfo,
    this.score,
    this.rank,
    this.isAmbiguousMatch = false,
    this.isCoupledTrain = false,
    required this.queryTime,
  });
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String prefix = 'G';
  final TextEditingController controller = TextEditingController();
  String searchType = 'trainCode';
  bool showRoutes = false;
  bool isLoading = false;
  String errorMsg = '';
  DateTime? lastSearchTime;

  // 本地数据
  List<Map<String, dynamic>> trainData = [];

  // 搜索结果（统一使用 SearchResult）
  final List<SearchResult> _searchResults = [];

  // 路局查询分页相关
  List<Map<String, dynamic>> _allBureauRecords = [];
  int _currentPage = 1;
  final int _pageSize = 7;
  int _totalResults = 0;

  int get _totalPages => (_totalResults / _pageSize).ceil();
  String? _currentBureauSearch;
  bool _loadingPage = false;

  // 页码输入控制器
  late TextEditingController _pageController;

  @override
  void initState() {
    super.initState();
    _loadConfig();
    _pageController = TextEditingController(text: '1');
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadConfig() async {
    try {
      final String dataString = await rootBundle.loadString('assets/data.json');
      final Map<String, dynamic> dataJson = json.decode(dataString);

      final loadedData = <Map<String, dynamic>>[];
      for (var model in dataJson.keys) {
        for (var record in dataJson[model]) {
          var r = Map<String, dynamic>.from(record);
          r['type_code'] = model;
          loadedData.add(r);
        }
      }

      if (mounted) {
        setState(() {
          trainData = loadedData;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          errorMsg = '加载数据失败: $e';
        });
      }
    }
  }

  // ==================== 工具函数 ====================
  String cleanString(String input) {
    return input.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toUpperCase();
  }

  String? extractLastFour(String? text) {
    if (text == null || text.isEmpty) return null;
    final digits = text.replaceAll(RegExp(r'[^0-9]'), '');
    return digits.length >= 4 ? digits.substring(digits.length - 4) : null;
  }

  double calculateMatchScore(String input, String trainNumber, String modelCode) {
    final cleanedInput = cleanString(input);
    final cleanedTrainNumber = cleanString(trainNumber);
    final cleanedModelCode = cleanString(modelCode);

    final fullTrainNumber = '$cleanedModelCode$cleanedTrainNumber';
    if (cleanedInput == fullTrainNumber) return 1.0;

    double numberScore = 0.0;
    if (cleanedTrainNumber.isNotEmpty) {
      if (cleanedInput.endsWith(cleanedTrainNumber)) {
        numberScore = 1.0;
      } else if (cleanedTrainNumber.length >= 4) {
        String trainLastFour = cleanedTrainNumber.substring(cleanedTrainNumber.length - 4);
        if (cleanedInput.contains(trainLastFour)) {
          numberScore = 0.8;
        }
      }
    }

    double modelScore = 0.0;
    if (cleanedInput.startsWith(cleanedModelCode)) {
      modelScore = 1.0;
    } else if (cleanedModelCode.startsWith(cleanedInput)) {
      modelScore = cleanedInput.length / cleanedModelCode.length;
    } else {
      int commonPrefix = 0;
      int minLength = min(cleanedInput.length, cleanedModelCode.length);
      int i = 0;
      while (i < minLength && cleanedInput[i] == cleanedModelCode[i]) {
        commonPrefix++;
        i++;
      }
      if (commonPrefix >= 4) {
        modelScore = commonPrefix / cleanedModelCode.length;
      } else if (commonPrefix >= 2) {
        modelScore = commonPrefix / cleanedModelCode.length * 0.6;
      }
    }

    double finalScore = 0.0;
    if (numberScore > 0 && modelScore > 0) {
      finalScore = numberScore * 0.7 + modelScore * 0.3;
    } else if (numberScore > 0) {
      finalScore = numberScore * 0.5;
    } else if (modelScore > 0) {
      finalScore = modelScore * 0.4;
    }

    return finalScore.clamp(0.0, 1.0);
  }

  String _getBureauFullName(String bureauCode) {
    List<String> allBureauNames = TrainModelUtils.getBureauFullNames();
    for (String fullName in allBureauNames) {
      if (fullName.contains(bureauCode) || bureauCode.contains(fullName)) {
        return fullName;
      }
    }
    return bureauCode;
  }

  List<String> _getCommonBureauCodes() {
    List<String> allBureauNames = TrainModelUtils.getBureauFullNames();
    return allBureauNames.map((name) => name.substring(0, 2)).toSet().toList();
  }

  void _handleBureauChipTap(String bureauName) {
    controller.text = bureauName;
    _performSearch();
  }

  void _resetPagination() {
    _currentPage = 1;
    _totalResults = 0;
    _currentBureauSearch = null;
    _allBureauRecords = [];
    _loadingPage = false;
    _pageController.text = '1';
  }

  // ==================== 路局查询 ====================
  Future<void> _searchByBureau(String bureauInput) async {
    if (bureauInput.isEmpty) return;

    setState(() {
      isLoading = true;
      errorMsg = '';
      _searchResults.clear();
      _resetPagination();
    });

    final bureauPattern = bureauInput.trim().toLowerCase();
    final List<Map<String, dynamic>> matchedRecords = [];

    for (var record in trainData) {
      final bureau = (record['配属路局'] ?? '').toString().trim();
      if (bureau.isNotEmpty) {
        final bureauFullName = _getBureauFullName(bureau);
        if (bureau.toLowerCase().contains(bureauPattern) ||
            bureauFullName.toLowerCase().contains(bureauPattern)) {
          matchedRecords.add(record);
        }
      }
    }

    if (matchedRecords.isEmpty) {
      setState(() {
        isLoading = false;
        errorMsg = '未找到匹配的路局';
      });
      return;
    }

    matchedRecords.sort((a, b) {
      final modelA = a['type_code'] ?? '';
      final modelB = b['type_code'] ?? '';
      if (modelA != modelB) return modelA.compareTo(modelB);
      return (a['车组号'] ?? '').compareTo(b['车组号'] ?? '');
    });

    _allBureauRecords = matchedRecords;
    _totalResults = matchedRecords.length;
    _currentBureauSearch = bureauInput;

    _loadBureauPage(1);
  }

  void _loadBureauPage(int page) {
    if (_allBureauRecords.isEmpty || page < 1 || page > _totalPages) return;

    setState(() => _loadingPage = true);

    final start = (page - 1) * _pageSize;
    final end = min(page * _pageSize, _allBureauRecords.length);
    final pageRecords = _allBureauRecords.sublist(start, end);

    final queryTime = DateTime.now().toLocal().toString().substring(0, 19);
    final newResults = pageRecords.map((record) {
      final bureau = (record['配属路局'] ?? '').toString().trim();
      return SearchResult(
        model: record['type_code'] ?? '',
        number: record['车组号'] ?? '',
        bureau: bureau,
        bureauFullName: _getBureauFullName(bureau),
        depot: record['配属动车所']?.toString(),
        manufacturer: record['生产厂家']?.toString(),
        remarks: record['备注']?.toString(),
        routeInfo: null,
        score: null,
        rank: null,
        queryTime: queryTime,
      );
    }).toList();

    setState(() {
      _searchResults.clear();
      _searchResults.addAll(newResults);
      _currentPage = page;
      _pageController.text = page.toString();
      _loadingPage = false;
      isLoading = false;
    });
  }

  void _goToPage(int page) {
    if (page == _currentPage || _loadingPage || page < 1 || page > _totalPages) {
      _pageController.text = _currentPage.toString();
      return;
    }
    _loadBureauPage(page);
  }

  // =================== 获取始发终到站 ==================

  Future<String?> _getStationInfo(String code) async {
    try {
      // 获取当前日期（格式：20260214）
      final now = DateTime.now();
      final formattedDate = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';

      // 构建API URL
      print(code);
      final apiUrl = 'https://search.12306.cn/search/v1/train/search?keyword=$code&date=$formattedDate';

      final headers = {'User-Agent': 'Mozilla/5.0'};
      final response = await http.get(Uri.parse(apiUrl), headers: headers).timeout(Duration(seconds: 10));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        print(data);

        if (data['status'] == true && data['data'] != null) {
          final List<dynamic> trainData = data['data'];

          // 遍历所有车次数据
          for (var train in trainData) {
            final stationTrainCode = train['station_train_code']?.toString().trim() ?? '';
            final fromStation = train['from_station']?.toString().trim() ?? '';
            final toStation = train['to_station']?.toString().trim() ?? '';

            print('$fromStation ~ $toStation');

            // 精确匹配车次
            if (stationTrainCode == code && fromStation.isNotEmpty && toStation.isNotEmpty) {
              return '$fromStation ~ $toStation';
            }
          }
        }
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  // ==================== 主搜索逻辑 ====================
  Future<void> _performSearch() async {
    if (isLoading) return;

    final input = controller.text.trim();
    if (input.isEmpty) {
      setState(() => errorMsg = '请输入查询内容');
      return;
    }

    bool needCooldown = false;

    if (searchType == 'trainCode') {
      needCooldown = true; // 车次查询始终需要
    } else if (searchType == 'trainId' && showRoutes) {
      needCooldown = true; // 只有勾选交路才需要
    }

    setState(() {
      isLoading = true;
      errorMsg = '';
      _searchResults.clear();
      _resetPagination();
    });

    try {
      
      final headers = {'User-Agent': 'Mozilla/5.0'};
      final queryTime = DateTime.now().toLocal().toString().substring(0, 19);

      if (searchType == 'bureau') {
        await _searchByBureau(input);
      }

      // ==================== 车次查询 ====================
      else if (searchType == 'trainCode') {
        if (!RegExp(r'^[1-9]\d{0,3}$').hasMatch(input)) {
          setState(() => errorMsg = '车次数字格式错误（1-4位数字，不能以0开头）');
          return;
        }

        if (input == '9178' || input == '9169') {
          setState(() {
            errorMsg = '?你什么意思阿';
          });
          return;
        }

        final fullCode = prefix + input;

        final settings = Provider.of<AppSettings>(context, listen: false);
        http.Response? resp;

        if (settings.dataSource == TrainDataSource.railGo){setState(() => errorMsg = 'RAILGO数据源已停用!请切换数据源!');}

        if (settings.dataSource == TrainDataSource.railRe) {
          resp = await http.get(
            Uri.parse('https://api.rail.re/train/${fullCode.toUpperCase()}'),
            headers: headers,
          );
        } else if (settings.dataSource == TrainDataSource.railGo) {
          resp = await http.get(
            Uri.parse('https://emu.data.railgo.zenglingkun.cn/train/${fullCode.toUpperCase()}'),
            headers: headers,
          );
        } else {
          http.Response? resp12306;
          resp12306 = await http.get(
            Uri.parse(
                'https://mobile.12306.cn/wxxcx/openplatform-inner/miniprogram/wifiapps/appFrontEnd/v2/lounge/open-smooth-common/trainStyleBatch/getCarDetail?carCode=&trainCode=${fullCode.toUpperCase()}&runningDay=0&reqType=form'),
            headers: headers,
          );
          if (resp12306.statusCode == 200) {
            try {
              Map<String, dynamic> data = json.decode(resp12306.body);

              if (data['content'] == null) {
                setState(() => errorMsg = '返回数据格式错误\n当前数据源: ${settings.dataSource.toString().split('.').last}');
                return;
              }

              if (data['content'] is! Map || data['content']['data'] == null) {
                setState(() => errorMsg = '车次不存在!\n是城际还是动集?是的话切换数据源\n当前数据源: ${settings.dataSource.toString().split('.').last}');
                return;
              }

              // 最后获取 carCode
              String? carCode = data['content']['data']['carCode'] as String?;

              if (carCode == null || carCode.isEmpty) {
                setState(() => errorMsg = '车次不存在!\n当前数据源: ${settings.dataSource.toString().split('.').last}');
              } else {
                String responseBody = '[{"DateTime":"${DateTime.now()}","emu_no":"$carCode","train_no":"${fullCode.toUpperCase()}"}]';
                resp = http.Response(responseBody, 200);
              }
            } catch (e) {
              setState(() => errorMsg = '解析返回数据失败: $e\n当前数据源: ${settings.dataSource.toString().split('.').last}');
            }
          }
        }

        if (resp == null) {
          setState(() => errorMsg = '请求失败，请检查网络连接或数据源设置\n当前数据源: ${settings.dataSource.toString().split('.').last}');
          return;
        }

        final List data = json.decode(resp.body);
        if (resp.body.isEmpty || resp.body == '[]' || data.isEmpty) {
          setState(() => errorMsg = '未查询到车次,请尝试:\n1.前往12306查询今日是否运行\n2.切换数据源查询\n当前数据源: ${settings.dataSource.toString().split('.').last}');
          return;
        }

        final List<dynamic> filteredData = [];
        for (var i = 0; i < data.length; i++) {
          final item = data[i];
          final emuNo = item['emu_no']?.toString().trim() ?? '';

          if (emuNo.contains('CR200')) {
            setState(() {
              isLoading = false;
              errorMsg = '不支持CR200J动集的交路查询!\n相关结果: ${item['emu_no']}';
            });
            return;
          }
          filteredData.add(item);
        }

        if (filteredData.isEmpty) {
          setState(() => errorMsg = '没有可用的动车组数据\n当前数据源: ${settings.dataSource.toString().split('.').last}');
          return;
        }

        if (settings.dataSource == TrainDataSource.railRe) {
          DateTime? latestDate;
          for (var item in filteredData) {
            final emuDate = item['date']?.toString().trim() ?? '';
            if (emuDate.isEmpty) continue;

            DateTime? emuDateOnly;
            if (emuDate.contains(' ')) {
              final datePart = emuDate.split(' ')[0];
              emuDateOnly = DateTime.parse(datePart);
            } else {
              emuDateOnly = DateTime.parse(emuDate);
            }

            if (latestDate == null || emuDateOnly.isAfter(latestDate)) {
              latestDate = emuDateOnly;
            }
          }

          if (latestDate == null) {
            setState(() {
              isLoading = false;
              errorMsg = '无法解析车次日期\n当前数据源: ${settings.dataSource.toString().split('.').last}';
            });
            return;
          }

          // 3. 检查最新日期是否在2天内
          final now = DateTime.now();
          final currentDateOnly = DateTime(now.year, now.month, now.day);
          final latestDateAtMidnight = DateTime(
              latestDate.year, latestDate.month, latestDate.day);

          final difference = latestDateAtMidnight.difference(currentDateOnly);
          final absDays = difference.inDays.abs();

          if (absDays > 2) {
            setState(() {
              isLoading = false;
              errorMsg ='车次过期! 可能调图后删除列车\n或者上游API无数据!\n可切换第二数据源尝试\n或者是车次有误\n当前数据源: ${settings.dataSource.toString().split('.').last}';
            });
            return;
          }
        }

        // 4. 重联判断（使用原始过滤后的数据）
        final first = filteredData[0];
        final second = filteredData.length > 1 ? filteredData[1] : null;

        final firstDate = first['date']?.toString();
        final secondDate = second?['date']?.toString();

        bool sameRun = false;
        if (second != null &&
            firstDate != null &&
            secondDate != null &&
            firstDate == secondDate) {
          sameRun = true;
        }

        // 收集 emu_no（支持重联）
        final List<String> emuNos = [];

        final firstEmu = first['emu_no']?.toString().trim();
        if (firstEmu != null && firstEmu.isNotEmpty) {
          emuNos.add(firstEmu);
        }

        if (sameRun) {
          final secondEmu = second?['emu_no']?.toString().trim();
          if (secondEmu != null && secondEmu.isNotEmpty) {
            emuNos.add(secondEmu);
          }
        }

        final uniqueEmuNos = emuNos.toSet().toList();

        if (uniqueEmuNos.isEmpty) {
          setState(() => errorMsg = 'API未返回车组号\n当前数据源: ${settings.dataSource.toString().split('.').last}');
          return;
        }

        // 查询交路（一次即可，重联共用）
        String routeInfo = '';
        final routeEmu = uniqueEmuNos.first;
        http.Response? emuResp;

        if (settings.dataEmuSource == TrainEmuDataSource.moeFactory) {
          // ==================== moeFactory 数据源 ====================
          final postUrl = 'https://rail.moefactory.com/api/emuSerialNumber/query';

          // 构建POST请求体
          final Map<String, String> requestBody = {
            'keyword': routeEmu,
          };

          // 发送POST请求
          emuResp = await http.post(
            Uri.parse(postUrl),
            body: requestBody,
          ).timeout(Duration(seconds: 10));

          if (emuResp.statusCode == 200 &&
              emuResp.body.isNotEmpty) {

            final Map<String, dynamic> response = json.decode(emuResp.body);

            // 检查响应code
            if (response['code'] == 200) {
              // 获取data数组
              final List<dynamic> data = response['data'] ?? [];

              if (data.isNotEmpty) {
                // 取第一条数据
                final item = data[0];
                final trainNo = item['trainNumber']?.toString().trim() ?? '';
                final date = item['date']?.toString().trim() ?? '';

                if (trainNo.isNotEmpty) {
                  routeInfo = '正在担当: $date\n本务车次: $trainNo';
                }
              }
            }
          }
        } else if (settings.dataEmuSource == TrainEmuDataSource.railGo) {
          if (settings.dataSource == TrainDataSource.railGo){setState(() => errorMsg = 'RAILGO数据源已停用!请切换数据源!');}
          // ==================== railGo 数据源 ====================
          emuResp = await http.get(
            Uri.parse('https://emu.data.railgo.zenglingkun.cn/emu/$routeEmu'),
            headers: headers,
          ).timeout(Duration(seconds: 10));

          if (emuResp.statusCode == 200 &&
              emuResp.body.isNotEmpty &&
              emuResp.body != '[]') {
            final emuData = json.decode(emuResp.body);
            if (emuData.isNotEmpty) {
              final item = emuData[0];
              final trainNo = item['train_no']?.toString().trim() ?? '';
              final date = item['date']?.toString() ?? '';

              if (trainNo.isNotEmpty) {
                routeInfo = '正在担当: $date\n本务车次: $trainNo';
              }
            }
          }

        } else {
          // ==================== rail.re 数据源 ====================
          emuResp = await http.get(
            Uri.parse('https://api.rail.re/emu/$routeEmu'),
            headers: headers,
          ).timeout(Duration(seconds: 10));

          if (emuResp.statusCode == 200 &&
              emuResp.body.isNotEmpty &&
              emuResp.body != '[]') {
            final emuData = json.decode(emuResp.body);
            if (emuData.isNotEmpty) {
              final item = emuData[0];
              final trainNo = item['train_no']?.toString().trim() ?? '';
              final date = item['date']?.toString() ?? '';

              if (trainNo.isNotEmpty) {
                routeInfo = '正在担当: $date\n本务车次: $trainNo';
              }
            }
          }
        }

        // 对每一个 emu_no 做本地匹配（重联 = 多次）
        for (final emuNo in uniqueEmuNos) {
          final cleanedEmuNo = cleanString(emuNo);

          List<Map<String, dynamic>> exactMatches = trainData
              .where((r) =>
          cleanString('${r['type_code']}${r['车组号']}') ==
              cleanedEmuNo)
              .toList();

          if (exactMatches.isEmpty) {
            final lastFour = extractLastFour(emuNo);
            if (lastFour != null) {
              exactMatches = trainData
                  .where(
                      (r) => extractLastFour(r['车组号']) == lastFour)
                  .toList();
            }
          }

          if (exactMatches.isEmpty) {
            continue;
          }

          for (final record in exactMatches) {
            final bureau =
            (record['配属路局'] ?? '').toString().trim();

            final stationinfo = await _getStationInfo(fullCode);

            _searchResults.add(
              SearchResult(
                model: record['type_code'] ?? '',
                number: record['车组号'] ?? '',
                bureau: bureau,
                bureauFullName: _getBureauFullName(bureau),
                depot: record['配属动车所']?.toString(),
                manufacturer: record['生产厂家']?.toString(),
                stationinfo: stationinfo,
                remarks: record['备注']?.toString(),
                routeInfo: routeInfo.isNotEmpty ? routeInfo : null,
                score: 1.0,
                isAmbiguousMatch: exactMatches.length > 1,
                isCoupledTrain: uniqueEmuNos.length > 1,
                queryTime: queryTime,
              ),
            );
          }
        }
      }

      // ==================== 车号查询 ====================
      else if (searchType == 'trainId') {
        final cleanedInput = cleanString(input);
        if (cleanedInput.length < 4) {
          setState(() => errorMsg = '请输入至少4位有效字符');
          return;
        }

        final inputDigits = cleanedInput.replaceAll(RegExp(r'[^0-9]'), '');
        final hasFourDigits = inputDigits.length >= 4;

        // ================= 本地匹配 =================
        List<Map<String, dynamic>> matches = trainData.where((record) {
          final trainNum = cleanString(record['车组号'] ?? '');
          return trainNum.contains(cleanedInput) ||
              cleanedInput.contains(trainNum);
        }).toList();

        if (matches.isEmpty) {
          setState(() => errorMsg = '本地未找到匹配车组');
          return;
        }

        // ================= 评分 =================
        final scored = <Map<String, dynamic>, double>{};
        for (var record in matches) {
          final model = record['type_code'] ?? '';
          final number = record['车组号'] ?? '';
          final score = calculateMatchScore(input, number, model);

          if (hasFourDigits) {
            final inputLastFour =
            inputDigits.substring(inputDigits.length - 4);
            final recordLastFour = extractLastFour(number);
            if (recordLastFour != inputLastFour) continue;
          }

          scored[record] = score;
        }

        if (scored.isEmpty) {
          setState(() =>
          errorMsg = hasFourDigits ? '未找到末四位匹配的车组' : '未找到匹配车组');
          return;
        }

        final sortedEntries = scored.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
        final topScore = sortedEntries.first.value;

        List<Map<String, dynamic>> bestRecords;
        if (topScore >= 0.9) {
          bestRecords = sortedEntries
              .where((e) => e.value >= topScore - 0.05)
              .map((e) => e.key)
              .toList();
        } else {
          bestRecords = sortedEntries.take(5).map((e) => e.key).toList();
        }

        // ================= 交路查询准备 =================
        final Map<String, Map<String, dynamic>> emuToRecord = {};
        for (var record in bestRecords) {
          final emuNo = cleanString('${record['type_code']}${record['车组号']}');
          emuToRecord[emuNo] = record;
        }

        final Map<String, String?> routeMap = {};

        // ================= 并行查交路（仅当 showRoutes） =================
        if (showRoutes) {
          final headers = {'User-Agent': 'Mozilla/5.0'};

          await Future.wait(emuToRecord.keys.map((emuNo) async {
            try {
              final settings = Provider.of<AppSettings>(context, listen: false);
              http.Response? resp;

              if (settings.dataEmuSource == TrainEmuDataSource.moeFactory) {
                // ==================== moeFactory 数据源 ====================
                final postUrl = 'https://rail.moefactory.com/api/emuSerialNumber/query';

                // 构建POST请求体
                final Map<String, String> requestBody = {
                  'keyword': emuNo,
                };

                // 发送POST请求
                resp = await http.post(
                  Uri.parse(postUrl),
                  headers: {
                    ...headers,
                    'Content-Type': 'application/x-www-form-urlencoded',
                  },
                  body: requestBody,
                ).timeout(Duration(seconds: 10));

                if (resp.statusCode == 200 && resp.body.isNotEmpty) {
                  final Map<String, dynamic> response = json.decode(resp.body);

                  // 检查响应code
                  if (response['code'] == 200) {
                    // 获取data数组
                    final List<dynamic> data = response['data'] ?? [];

                    if (data.isNotEmpty) {
                      // 取第一条数据
                      final item = data[0];
                      final trainNo = item['trainNumber']?.toString().trim() ?? '';
                      final date = item['date']?.toString().trim() ?? '';

                      if (trainNo.isNotEmpty) {
                        routeMap[emuNo] = '正在担当: $date\n本务车次: $trainNo';
                        return;
                      }
                    }
                  }
                }
              }
              else if (settings.dataEmuSource == TrainEmuDataSource.railGo) {
                if (settings.dataSource == TrainDataSource.railGo){setState(() => errorMsg = 'RAILGO数据源已停用!请切换数据源!');}
                // ==================== railGo 数据源 ====================
                resp = await http.get(
                  Uri.parse('https://emu.data.railgo.zenglingkun.cn/emu/$emuNo'),
                  headers: headers,
                ).timeout(Duration(seconds: 10));

                if (resp.statusCode == 200 &&
                    resp.body.isNotEmpty &&
                    resp.body != '[]') {
                  final emuData = json.decode(resp.body);
                  if (emuData.isNotEmpty) {
                    final item = emuData[0];
                    final trainNo = item['train_no']?.toString().trim() ?? '';
                    final date = item['date']?.toString() ?? '';

                    if (trainNo.isNotEmpty) {
                      routeMap[emuNo] = '正在担当: $date\n本务车次: $trainNo';
                      return;
                    }
                  }
                }
              }
              else {
                // ==================== rail.re 数据源 ====================
                resp = await http.get(
                  Uri.parse('https://api.rail.re/emu/$emuNo'),
                  headers: headers,
                ).timeout(Duration(seconds: 10));

                if (resp.statusCode == 200 &&
                    resp.body.isNotEmpty &&
                    resp.body != '[]') {
                  final emuData = json.decode(resp.body);
                  if (emuData.isNotEmpty) {
                    final item = emuData[0];
                    final trainNo = item['train_no']?.toString().trim() ?? '';
                    final date = item['date']?.toString() ?? '';

                    if (trainNo.isNotEmpty) {
                      routeMap[emuNo] = '正在担当: $date\n本务车次: $trainNo';
                      return;
                    }
                  }
                }
              }
            } catch (_) {
            }

            routeMap[emuNo] = null;
          }));
        }

        // ================= 构建结果 =================
        for (int i = 0; i < bestRecords.length; i++) {
          final record = bestRecords[i];
          final bureau = (record['配属路局'] ?? '').toString().trim();
          final emuNo = cleanString('${record['type_code']}${record['车组号']}');

          _searchResults.add(
            SearchResult(
              model: record['type_code'] ?? '',
              number: record['车组号'] ?? '',
              bureau: bureau,
              bureauFullName: _getBureauFullName(bureau),
              depot: record['配属动车所']?.toString(),
              manufacturer: record['生产厂家']?.toString(),
              remarks: record['备注']?.toString(),
              score: scored[record],
              rank: i + 1,
              routeInfo: showRoutes ? routeMap[emuNo] : null,
              queryTime: queryTime,
            ),
          );
        }
      }

      if (needCooldown) {
        lastSearchTime = DateTime.now();
      }
    } catch (e) {
      setState(() => errorMsg = '查询失败: $e');
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  // ==================== UI 组件 ====================
  Widget _buildTrainIcon(String model, String number) {
    return TrainIconWidget(model: model, number: number, size: 32);
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 80, child: Text('$label:', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500))),
          const SizedBox(width: 8),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 14))),
        ],
      ),
    );
  }

  Widget _buildResultCard(SearchResult result) {
    final settings = Provider.of<AppSettings>(context, listen: false);

    return Card(
      elevation: 4,
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _buildTrainIcon(result.model, result.number),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${result.model}-${result.number}',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      if (searchType == 'bureau')
                        Text(result.bureauFullName,
                            style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withAlpha(150))),
                      if (result.isCoupledTrain)
                        Text('可能为重联列车',
                            style: TextStyle(
                              fontSize: 11,
                              color: Theme.of(context).colorScheme.primary,
                              fontStyle: FontStyle.italic,
                            )),

                      if (result.isAmbiguousMatch)
                        Text('存在多个匹配结果，请核对车号',
                            style: TextStyle(
                              fontSize: 11,
                              color: Theme.of(context).colorScheme.error,
                              fontStyle: FontStyle.italic,
                            )),
                      if (result.score != null) ...[
                        const SizedBox(height: 4),
                        Row(children: [
                          Container(
                            width: 60, height: 6,
                            decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(3)),
                            child: FractionallySizedBox(
                              alignment: Alignment.centerLeft,
                              widthFactor: result.score!.clamp(0.0, 1.0),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: result.score! >= 0.8 ? Colors.green : result.score! >= 0.5 ? Colors.orange : Colors.red,
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text('${(result.score! * 100).toInt()}%',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold,
                                  color: result.score! >= 0.8 ? Colors.green : result.score! >= 0.6 ? Colors.orange : Colors.red)),
                          if (result.rank != null) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary.withAlpha(20), borderRadius: BorderRadius.circular(4)),
                              child: Text('#${result.rank!}',
                                  style: TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ]),
                      ],
                    ],
                  ),
                ),
                if (settings.showBureauIcons)
                  BureauIconWidget(bureau: result.bureau, size: 32)
                else
                  const SizedBox(width: 32, height: 32),
              ],
            ),
            const SizedBox(height: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (result.bureau.isNotEmpty && searchType != 'bureau')
                  _buildInfoRow('配属路局', result.bureauFullName),
                if (result.depot != null && result.depot!.isNotEmpty) _buildInfoRow('配属动车所', result.depot!),
                if (result.manufacturer != null && result.manufacturer!.isNotEmpty) _buildInfoRow('生产厂家', result.manufacturer!),
                if (result.stationinfo != null) _buildInfoRow('运行交路', result.stationinfo!),
                if (result.remarks != null && result.remarks!.isNotEmpty) _buildInfoRow('备注', result.remarks!),
              ],
            ),
            if (result.routeInfo != null && result.routeInfo!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary.withAlpha(20), borderRadius: BorderRadius.circular(6)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: result.routeInfo!.split('\n').map((line) => Text(line,
                      style: TextStyle(fontSize: 14, color: Theme.of(context).colorScheme.onSurface.withAlpha(200)))).toList(),
                ),
              ),
            ],
            const SizedBox(height: 8),
            Text('查询时间: ${result.queryTime}',
                style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withAlpha(150))),
          ],
        ),
      ),
    );
  }

  Widget _buildPaginationControls() {
    if (_totalPages <= 1) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(icon: const Icon(Icons.chevron_left), onPressed: _currentPage > 1 && !_loadingPage ? () => _goToPage(_currentPage - 1) : null),
          const SizedBox(width: 12),
          SizedBox(
            width: 60,
            child: TextField(
              controller: _pageController,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)), contentPadding: const EdgeInsets.symmetric(vertical: 8)),
              onSubmitted: (v) async {
                final p = int.tryParse(v);
                if (p != null && p >= 1 && p <= _totalPages) {
                  _goToPage(p);
                } else {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (_pageController.text != _currentPage.toString()) {
                      _pageController.text = _currentPage.toString();
                    }
                  });
                }
              },
            ),
          ),
          const SizedBox(width: 8),
          Text('/ $_totalPages 页（共 $_totalResults 条）', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(width: 12),
          IconButton(icon: const Icon(Icons.chevron_right), onPressed: _currentPage < _totalPages && !_loadingPage ? () => _goToPage(_currentPage + 1) : null),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final int displayedCount = _searchResults.length;
    final int totalCount =
    searchType == 'bureau' ? _totalResults : displayedCount;

    return Scaffold(
      appBar: AppBar(title: const Text('EmuAIO'), centerTitle: true),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              if (searchType == 'trainCode')
                DropdownButton<String>(
                  value: prefix,
                  items: ['G', 'D', 'C']
                      .map((v) => DropdownMenuItem(
                      value: v,
                      child: Text(v,
                          style: const TextStyle(fontSize: 18))))
                      .toList(),
                  onChanged: (v) => setState(() => prefix = v!),
                ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: controller,
                  keyboardType: TextInputType.text,
                  inputFormatters: searchType == 'trainCode'
                      ? [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(4),
                    TextInputFormatter.withFunction((old, newV) =>
                    newV.text.startsWith('0') &&
                        newV.text.length > 1
                        ? old
                        : newV)
                  ]
                      : [],
                  decoration: InputDecoration(
                    labelText: searchType == 'trainCode'
                        ? '输入车次数字（1-4位）'
                        : searchType == 'trainId'
                        ? '输入车号'
                        : '输入路局名称',
                    hintText: searchType == 'trainCode'
                        ? '如: 31'
                        : searchType == 'trainId'
                        ? '如: CR400AF-AZ-2311'
                        : '如: 上局 或 上海铁路局',
                    border: const OutlineInputBorder(),
                    filled: true,
                  ),
                  onSubmitted: (_) => _performSearch(),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: isLoading ? null : _performSearch,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(80, 56),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(isLoading ? '查询中...' : '查询'),
              ),
            ]),
            const SizedBox(height: 20),

            SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                    value: 'trainCode',
                    label: Text('车次查询'),
                    icon: Icon(Icons.numbers)),
                ButtonSegment(
                    value: 'trainId',
                    label: Text('车号查询'),
                    icon: Icon(Icons.confirmation_number)),
                ButtonSegment(
                    value: 'bureau',
                    label: Text('路局查询'),
                    icon: Icon(Icons.business)),
              ],
              selected: {searchType},
              onSelectionChanged: (s) => setState(() {
                searchType = s.first;
                controller.clear();
                _searchResults.clear();
                errorMsg = '';
                _resetPagination();
              }),
              style: SegmentedButton.styleFrom(
                backgroundColor:
                Theme.of(context).colorScheme.surfaceContainerHighest,
                selectedBackgroundColor:
                Theme.of(context).colorScheme.primary,
                selectedForegroundColor:
                Theme.of(context).colorScheme.onPrimary,
              ),
            ),

            const SizedBox(height: 20),

            if (searchType == 'trainId')
              Card(
                elevation: 1,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                      color: Theme.of(context)
                          .colorScheme
                          .outlineVariant),
                ),
                child: Column(children: [
                  CheckboxListTile(
                    title: const Text('显示交路信息'),
                    subtitle: const Text('启用后将应用3秒冷却时间'),
                    value: showRoutes,
                    onChanged: (v) => setState(() => showRoutes = v!),
                    dense: true,
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                  const Padding(
                    padding:
                    EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Text('不显示交路信息时无冷却时间限制',
                        style: TextStyle(fontSize: 12)),
                  ),
                ]),
              ),

            const SizedBox(height: 20),

            if (isLoading && _searchResults.isEmpty)
              const Center(child: CircularProgressIndicator()),

            if (errorMsg.isNotEmpty)
              Card(
                color: Theme.of(context).colorScheme.errorContainer,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(children: [
                    const Icon(Icons.error_outline),
                    const SizedBox(width: 12),
                    Expanded(child: Text(errorMsg)),
                    IconButton(
                        onPressed: () =>
                            setState(() => errorMsg = ''),
                        icon: const Icon(Icons.close)),
                  ]),
                ),
              ),

            if (_searchResults.isNotEmpty) ...[
              Container(
                padding:
                const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.info_outline, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      searchType == 'bureau'
                          ? '$_currentBureauSearch 共 $totalCount 条（当前 $displayedCount 条）'
                          : '共找到 $totalCount 条结果',
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              if (searchType == 'bureau') _buildPaginationControls(),

              for (final result in _searchResults)
                _buildResultCard(result),

              if (_loadingPage)
                const Center(child: CircularProgressIndicator()),
            ],

            const SizedBox(height: 40),

            if (!isLoading &&
                errorMsg.isEmpty &&
                _searchResults.isEmpty)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Column(children: [
                  Icon(
                      searchType == 'bureau'
                          ? Icons.business
                          : Icons.train_outlined,
                      size: 64),
                  const SizedBox(height: 16),
                  Text(
                    searchType == 'trainCode'
                        ? '请输入车次数字进行查询\n（例如：25）'
                        : searchType == 'trainId'
                        ? '请输入车号进行查询'
                        : '请输入路局名称或点击下方简称查询',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 16),
                  ),
                  if (searchType == 'trainCode') ...[
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: ['G', 'D', 'C']
                          .map((p) => Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4),
                        child: FilterChip(
                            label: Text(p),
                            selected: prefix == p,
                            onSelected: (s) => s
                                ? setState(() => prefix = p)
                                : null),
                      ))
                          .toList(),
                    ),
                  ],
                  if (searchType == 'bureau') ...[
                    const SizedBox(height: 20),
                    const Text('支持的路局简称:'),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      alignment: WrapAlignment.center,
                      children: _getCommonBureauCodes().map((code) {
                        final full = _getBureauFullName(code);
                        return GestureDetector(
                          onTap: () => _handleBureauChipTap(code),
                          child: Chip(label: Text(full)),
                        );
                      }).toList(),
                    ),
                  ],
                ]),
              ),
          ],
        ),
      ),
    );
  }
}