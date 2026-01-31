//gallery_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import 'train_model.dart';
import 'main.dart';

class GalleryPage extends StatefulWidget {
  const GalleryPage({super.key});

  @override
  State<GalleryPage> createState() => _GalleryPageState();
}

// 动车信息数据类
class TrainInfo {
  final String model;
  final String number;
  final String title;
  final Map<String, String> infoItems;
  final String? sectionTitle;

  TrainInfo({
    required this.model,
    required this.number,
    required this.title,
    required this.infoItems,
    this.sectionTitle,
  });

  String get iconModelName => TrainModelUtils.getTrainIconModel(model, number);
}

class _GalleryPageState extends State<GalleryPage> {
  int _currentTab = 0;

  // 导航栏配置
  static const _tabTitles = ['热门车型', '检测列车', '其他车型', '特殊涂装'];
  static const _tabIcons = [
    Icons.star_border,
    Icons.search,
    Icons.directions_railway,
    Icons.color_lens,
  ];

  // 完整图鉴链接
  static const _fullGalleryUrl = 'https://china-emu.cn/Trains/ALL/';

  final Map<int, List<TrainInfo>> _tabData = {
    0: [ // 热门车型
      TrainInfo(
        model: 'CR450AF',
        number: '0201',
        title: 'CR450AF-0201',
        infoItems: {
          '生产厂家': '中车青岛四方',
          '备注': '450级别动车组',
          '类型': '实验-实验中',
        },
      ),
      TrainInfo(
        model: 'CR450BF',
        number: '0501',
        title: 'CR450BF-0501',
        infoItems: {
          '生产厂家': '长春轨道客车',
          '备注': '450级别动车组',
          '类型': '实验-实验中',
        },
      ),
      TrainInfo(
        model: 'CR400AF-J',
        number: '2808',
        title: 'CR400AF-J-2808',
        infoItems: {
          '生产厂家': '中车青岛四方',
          '备注': '复兴号350级别高速综合检测列车',
          '类型': '检测-上线',
        },
      ),
    ],
    1: [ // 检测列车
      TrainInfo(
          model: 'CR400BF-J',
          number: '0001',
          title: 'CR400BF-J-0001',
          infoItems: {
            '代管路局': '沈阳铁路局',
            '生产厂家': '长春轨道客车',
            '备注': '复兴号350级别高速综合检测列车',
            '类型': '检测-上线',
          }
      ),
      TrainInfo(
        model: 'CR400AF-J',
        number: '0002',
        title: 'CR400AF-J-0002',
        infoItems: {
          '代管路局': '武汉铁路局',
          '生产厂家': '中车青岛四方',
          '备注': '复兴号350级别高速综合检测列车',
          '类型': '检测-上线',
        },
      ),
      TrainInfo(
        model: 'CR400BF-J',
        number: '0003',
        title: 'CR400BF-J-0003',
        infoItems: {
          '代管路局': '北京铁路局',
          '生产厂家': '中车长客股份',
          '备注': '复兴号350级别高速综合检测列车',
          '类型': '检测-上线',
        },
      ),
      TrainInfo(
        model: 'CR400AF-J',
        number: '2808',
        title: 'CR400AF-J-2808',
        infoItems: {
          '生产厂家': '中车青岛四方',
          '备注': '复兴号350级别高速综合检测列车',
          '类型': '检测-上线',
        },
      ),
      TrainInfo(
        model: 'CRH380AJ',
        number: '0201',
        title: 'CRH380AJ-0201',
        infoItems: {
          '代管路局': '广州铁路局',
          '生产厂家': '南车青岛四方',
          '备注': '和谐号380级别高速综合检测列车',
          '类型': '检测-上线',
        },
      ),
      TrainInfo(
        model: 'CRH380AJ',
        number: '0202',
        title: 'CRH380AJ-0202',
        infoItems: {
          '代管路局': '武汉铁路局',
          '生产厂家': '南车青岛四方',
          '备注': '和谐号380级别高速综合检测列车',
          '类型': '检测-上线',
        },
      ),
      TrainInfo(
        model: 'CRH380AJ',
        number: '0203',
        title: 'CRH380AJ-0203',
        infoItems: {
          '代管路局': '武汉铁路局',
          '生产厂家': '南车青岛四方',
          '备注': '和谐号380级别高速综合检测列车',
          '类型': '检测-上线',
        },
      ),
      TrainInfo(
        model: 'CRH380AM',
        number: '0204',
        title: 'CRH380AM-0204',
        infoItems: {
          '代管路局': '济南铁路局',
          '生产厂家': '南车青岛四方',
          '备注': '和谐号更高速度综合检测列车',
          '类型': '检测-上线',
        },
      ),
      TrainInfo(
        model: 'CRH2J',
        number: '0205',
        title: 'CRH2J-0205',
        infoItems: {
          '代管路局': '广州铁路局',
          '生产厂家': '南车青岛四方',
          '备注': '和谐号250级别高速综合检测列车',
          '类型': '检测-上线',
        },
      ),
      TrainInfo(
        model: 'CRH380BJ',
        number: '0301',
        title: 'CRH380BJ-0301',
        infoItems: {
          '代管路局': '北京铁路局',
          '生产厂家': '唐山轨道客车',
          '备注': '和谐号350级别高速综合检测列车',
          '类型': '检测-上线',
        },
      ),
      TrainInfo(
        model: 'CRH5J',
        number: '0501',
        title: 'CRH5J-0501',
        infoItems: {
          '代管路局': '北京铁路局',
          '生产厂家': '长春轨道客车',
          '备注': '和谐号250级别 0号高速综合检测列车',
          '类型': '检测-上线',
        },
      ),
      TrainInfo(
        model: 'CRH380BJ-A',
        number: '0504',
        title: 'CRH380BJ-A-0504',
        infoItems: {
          '代管路局': '沈阳铁路局',
          '生产厂家': '长春轨道客车',
          '备注': '和谐号350级别高速综合检测列车，CRH380CL头型',
          '类型': '检测-上线',
        },
      ),
      TrainInfo(
        model: 'CRH2A',
        number: '2010',
        title: 'CRH2A-2010',
        infoItems: {
          '代管路局': '北京铁路局',
          '生产厂家': '中车青岛四方',
          '备注': '和谐号250级别综合检测车',
          '类型': '检测-上线',
        },
      ),
      TrainInfo(
        model: 'CRH2C',
        number: '2061',
        title: 'CRH2C-2061',
        infoItems: {
          '代管路局': '上海铁路局',
          '生产厂家': '南车青岛四方',
          '备注': '和谐号350级别综合检测列车',
          '类型': '检测-上线',
        },
      ),
      TrainInfo(
        model: 'CRH2C',
        number: '2068',
        title: 'CRH2C-2068',
        infoItems: {
          '代管路局': '上海铁路局',
          '生产厂家': '南车青岛四方',
          '备注': '和谐号380级别综合检测列车',
          '类型': '检测-上线',
        },
      ),
      TrainInfo(
        model: 'CRH2C',
        number: '2150',
        title: 'CRH2C-2150',
        infoItems: {
          '代管路局': '上海铁路局',
          '生产厂家': '南车青岛四方',
          '备注': '和谐号350级别高速综合检测列车，CRH380A新头型实验列车',
          '类型': '检测-上线',
        },
      )
    ],
    2: [ // 其他车型
      TrainInfo(
          model: 'CRH380AN',
          number: '0206',
          title: 'CRH380AN-0206',
          infoItems: {
            '配属路局': '成都铁路局',
            '配属动车所': '成都东',
            '生产厂家': '南车青岛四方',
            '备注': '永磁电机实验动车组',
            '类型': '客运-上线',
          }
      ),TrainInfo(
          model: 'CR400AF',
          number: '0207',
          title: 'CR400AF-0207',
          infoItems: {
            '配属路局': '北京铁路局',
            '配属动车所': '北京西',
            '生产厂家': '南车青岛四方',
            '备注': '350km/h中国标准动车组样车',
            '类型': '客运-上线',
          }
      ),TrainInfo(
          model: 'CR400BF',
          number: '0507',
          title: 'CR400BF-0507',
          infoItems: {
            '配属路局': '广州铁路局',
            '配属动车所': '广州南',
            '生产厂家': '长春轨道客车',
            '备注': '350km/h中国标准动车组样车，白眉，橡胶风挡',
            '类型': '客运-上线',
          }
      ),TrainInfo(
          model: 'CR400AF-C',
          number: '2214',
          title: 'CR400AF-C-2214',
          infoItems: {
            '配属路局': '北京铁路局',
            '配属动车所': '雄安',
            '生产厂家': '南车青岛四方',
            '备注': '真正意义上的智能动车，具有自动驾驶功能，仅一列',
            '类型': '客运-上线',
          }
      ),TrainInfo(
          model: 'CRH2A',
          number: '2460',
          title: 'CRH2A-2460',
          infoItems: {
            '配属路局': '昆明铁路局',
            '配属动车所': '昆明南',
            '生产厂家': '南车青岛四方',
            '备注': 'CRH2G新头型实验动车组',
            '类型': '客运-上线',
          }
      ),TrainInfo(
          model: 'CRH380AL',
          number: '2541',
          title: 'CRH380AL-2541',
          infoItems: {
            '配属路局': '南昌铁路局',
            '配属动车所': '厦门北',
            '生产厂家': '中车青岛四方',
            '备注': '冲高动车组,最快可达486.1KM,曾编组号CRH380A-2541L',
            '类型': '客运-上线',
          }
      ),TrainInfo(
          model: 'CRH2A',
          number: '4020',
          title: 'CRH2A-4020',
          infoItems: {
            '配属路局': '成都铁路局',
            '配属动车所': '成都东',
            '生产厂家': '南车青岛四方',
            '备注': '2022年6月4日发生事故，头车及7车出轨受损，现已改造为货运动车组。前两节车厢无窗户',
            '类型': '货运-上线',
          }
      ),
    ],
    3: [ // 特殊涂装
      TrainInfo(
          model: 'CR400BF-Z',
          number: '0524',
          title: 'CR400BF-Z-0524',
          infoItems: {
            '配属路局': '上海铁路局',
            '配属动车所': '杭州西',
            '生产厂家': '长春轨道客车',
            '备注': '杭州亚运涂装',
            '类型': '客运-上线',
          }
      ),
      TrainInfo(
          model: 'CR400BF-C',
          number: '5162',
          title: 'CR400BF-C-5162',
          infoItems: {
            '配属路局': '北京铁路局',
            '配属动车所': '北京北',
            '生产厂家': '长春轨道客车',
            '备注': '冬奥涂装',
            '类型': '客运-上线',
          }
      ),
    ],
  };

  // 打开完整图鉴链接
  Future<void> _openFullGallery() async {
    final uri = Uri.parse(_fullGalleryUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      // 如果无法打开链接，显示提示
      final localContext = context;
      if (localContext.mounted) {
        ScaffoldMessenger.of(localContext).showSnackBar(
          const SnackBar(
            content: Text('无法打开链接'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('铁路动车组图鉴'),
      ),
      body: Column(
        children: [
          Expanded(
            child: Column(
              children: [
                _buildGalleryNavbar(),
                Expanded(
                  child: _buildCurrentTabContent(),
                ),
              ],
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              border: Border(
                top: BorderSide(
                  color: Theme.of(context).dividerColor,
                ),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: ElevatedButton(
              onPressed: _openFullGallery,
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                '跳转其他图鉴',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 构建导航栏
  Widget _buildGalleryNavbar() {
    return Container(
      color: Theme.of(context).brightness == Brightness.dark
          ? Colors.grey[900]
          : Colors.grey[50],
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: List.generate(_tabTitles.length, (index) =>
              _buildNavItem(_tabTitles[index], index, _tabIcons[index])
          ),
        ),
      ),
    );
  }

  // 构建导航项
  Widget _buildNavItem(String title, int index, IconData icon) {
    final isSelected = _currentTab == index;
    final primaryColor = Theme.of(context).colorScheme.primary;
    final unselectedColor = Theme.of(context).brightness == Brightness.dark
        ? Colors.grey[400]!
        : Colors.grey[600]!;

    return InkWell(
      onTap: () => setState(() => _currentTab = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isSelected ? primaryColor : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: isSelected ? primaryColor : unselectedColor,
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                color: isSelected ? primaryColor : unselectedColor,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 构建当前标签页内容
  Widget _buildCurrentTabContent() {
    final data = _tabData[_currentTab] ?? [];

    return SingleChildScrollView(
      child: Column(
        children: [
          for (int i = 0; i < data.length; i++) ...[
            if (i == 0 || data[i].sectionTitle != null) ...[
              if (data[i].sectionTitle != null)
                _buildSectionHeader(data[i].sectionTitle!),
              const SizedBox(height: 8),
            ],
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: _buildResultItem(data[i]),
            ),
          ],
          const SizedBox(height: 16), // 底部留白
        ],
      ),
    );
  }

  // 构建分区标题
  Widget _buildSectionHeader(String title) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      margin: const EdgeInsets.only(top: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }

  Widget _buildResultItem(TrainInfo train) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? Colors.grey[900]! : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final secondaryTextColor = isDark ? Colors.grey[300]! : Colors.grey[700]!;

    // 使用 Provider.of 获取设置
    final settings = Provider.of<AppSettings>(context, listen: false);

    return Card(
      margin: EdgeInsets.zero,
      elevation: isDark ? 0 : 2,
      color: backgroundColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: isDark ? Colors.grey[800]! : Colors.grey.shade200,
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标题行
            Row(
              children: [
                // 车型图标
                TrainIconWidget(
                    model: train.model,
                    number: train.number,
                    size: 40,
                    backgroundColor: Colors.transparent
                ),
                const SizedBox(width: 12),

                // 车型名称
                Expanded(
                  child: Text(
                    train.title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                  ),
                ),

                // 路局图标
                if (settings.showBureauIcons)
                  _buildBureauIconForTrain(train),
              ],
            ),

            const SizedBox(height: 12),

            // 详细信息
            ...train.infoItems.entries.map((entry) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      constraints: const BoxConstraints(minWidth: 80),
                      child: Text(
                        '${entry.key}:',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: textColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        entry.value,
                        style: TextStyle(
                          fontSize: 14,
                          color: secondaryTextColor,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  // 添加辅助方法构建路局图标
  Widget _buildBureauIconForTrain(TrainInfo train) {
    // 从 infoItems 中获取路局信息
    String? bureau = train.infoItems['配属路局'] ?? train.infoItems['代管路局'];
    if (bureau != null && bureau.isNotEmpty) {
      return BureauIconWidget(
        bureau: bureau,
        size: 32,
      );
    }
    return const SizedBox.shrink();
  }
}