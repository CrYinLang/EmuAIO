import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'main.dart';
import 'tool.dart';

class UpdateService {
  static Future<Map<String, dynamic>?> checkForUpdate() async {
    try {
      final response = await http
          .get(Uri.parse(Vars.urlServer))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        return {'error': '网络错误 ${response.statusCode}'};
      }
    } catch (e) {
      return {'error': e.toString()};
    }
  }
}

/// ================= 对外调用入口 =================
class UpdateUI {
  static Future<void> showUpdateFlow(BuildContext context) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _CheckingDialog(),
    );

    final versionInfo = await UpdateService.checkForUpdate();

    if (context.mounted) Navigator.of(context, rootNavigator: true).pop();

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (_) => UpdateResultDialog(versionInfo: versionInfo),
    );
  }
}

/// ================= 检测中弹窗 =================
class _CheckingDialog extends StatelessWidget {
  const _CheckingDialog();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: const Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 60,
              height: 60,
              child: CircularProgressIndicator(strokeWidth: 4),
            ),
            SizedBox(height: 20),
            Text('正在检测更新...', style: TextStyle(fontSize: 16)),
          ],
        ),
      ),
    );
  }
}

/// ================= 更新结果弹窗 =================
class UpdateResultDialog extends StatelessWidget {
  final Map<String, dynamic>? versionInfo;

  const UpdateResultDialog({super.key, required this.versionInfo});

  // 添加链接为空时的提示对话框
  void _showNoLinkDialog(BuildContext context, String linkName) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('提示'),
          content: Text('$linkName暂不可用，请选择其他下载方式'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('确定'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentBuild = int.tryParse(Vars.build) ?? 0;
    final currentVersion = Vars.version;

    bool hasUpdate = false;
    String resultMessage = '';
    Color resultColor = Colors.green;
    IconData resultIcon = Icons.check_circle;
    String? describeText;
    String? githubUrl;
    String? giteeUrl;
    String? qqUrl;
    String? newVersion;
    String? updateTime;

    if (versionInfo != null && versionInfo!.containsKey('error')) {
      resultMessage = '检查更新失败: ${versionInfo!['error']}';
      resultColor = Colors.red;
      resultIcon = Icons.error;
    } else if (versionInfo != null) {
      final remoteBuild = int.tryParse(versionInfo!['Build'].toString()) ?? 0;
      newVersion = versionInfo!['Version'];
      updateTime = versionInfo!['LastUpdate'];

      // 修正字段名：根据你的JSON结构
      githubUrl = versionInfo!['github'];
      giteeUrl = versionInfo!['gitee'];
      qqUrl = versionInfo!['qq'];

      describeText = versionInfo!['describe'] ?? '修复了一些已知问题';

      if (remoteBuild > currentBuild) {
        hasUpdate = true;
        resultMessage = '发现新版本\n\n'
            '当前版本: $currentVersion ($currentBuild)\n'
            '最新版本: $newVersion ($remoteBuild)\n\n'
            '更新时间: $updateTime\n\n'
            '更新内容:\n$describeText';
        resultColor = Colors.orange;
        resultIcon = Icons.system_update;
      } else {
        resultMessage = '已是最新版本\n\n'
            '当前版本: $currentVersion ($currentBuild)\n'
            '最新版本: $newVersion ($remoteBuild)';
      }
    } else {
      resultMessage = '检查更新失败: 未知错误';
      resultColor = Colors.red;
      resultIcon = Icons.error;
    }

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(resultIcon, size: 60, color: resultColor),
                const SizedBox(height: 20),
                Text(
                  hasUpdate ? '发现新版本' : '检查完成',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),

                // 更新描述区域
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SelectableText(
                    resultMessage,
                    style: TextStyle(
                      fontSize: 16,
                      height: 1.5,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                if (hasUpdate) ...[
                  // 第一行：蓝色QQ群 + 绿色Gitee
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            if (qqUrl != null && qqUrl.isNotEmpty) {
                              Tool.launchBrowser(context, qqUrl);
                            } else {
                              _showNoLinkDialog(context, 'QQ群链接');
                            }
                          },
                          icon: const Icon(Icons.group, size: 20),
                          label: const Text('QQ群下载', style: TextStyle(fontSize: 14)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            if (giteeUrl != null && giteeUrl.isNotEmpty) {
                              Tool.launchBrowser(context, giteeUrl);
                            } else {
                              _showNoLinkDialog(context, 'Gitee链接');
                            }
                          },
                          icon: const Icon(Icons.code, size: 20),
                          label: const Text('Gitee下载', style: TextStyle(fontSize: 14)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // 第二行：灰色Github + 关闭按钮
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            if (githubUrl != null && githubUrl.isNotEmpty) {
                              Tool.launchBrowser(context, githubUrl);
                            } else {
                              _showNoLinkDialog(context, 'Github链接');
                            }
                          },
                          icon: const Icon(Icons.cloud_download, size: 20),
                          label: const Text('Github', style: TextStyle(fontSize: 14)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: const Text('关闭', style: TextStyle(fontSize: 14)),
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  // 没有更新时的关闭按钮
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text('关闭', style: TextStyle(fontSize: 14)),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}