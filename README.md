EmuAIO - 动车组全信息查询系统

项目简介

EmuAIO 是一个基于 Flutter 开发的综合性动车组信息查询应用，提供车次查询、车号查询、路局查询、动车图鉴等全方位功能，为铁路爱好者和专业人士提供便捷的动车组信息检索服务。

主要功能

智能查询系统

• 车次查询：支持 G/D/C 字头车次查询，输入车次数字即可快速检索

• 车号查询：通过动车组编号精确查询车辆信息

• 路局查询：按配属路局浏览动车组，支持分页加载

• 交路信息：可选显示列车运行交路和实时状态

动车图鉴

• 热门车型：CR450AF、CR400BF-J 等最新实验车型

• 检测列车：全路高速综合检测列车详细信息

• 特殊涂装：亚运涂装、冬奥涂装等特色动车组

• 完整图鉴：内置 WebView 直接访问 china-emu.cn 完整图鉴

个性化设置

• 主题切换：支持浅色/深色/深夜模式

• 图标包管理：可自定义导入图标包

• 路局图标：显示各铁路局专属图标

• 多语言支持：完整的国际化支持

技术架构

前端框架

• Flutter 3.19+：跨平台 UI 框架

• Dart 3.3+：强类型编程语言

状态管理

• Provider：轻量级状态管理

• SharedPreferences：本地数据持久化

网络请求

• http：REST API 调用

• WebView：内嵌网页浏览

数据存储

• JSON 本地存储：快速数据检索

• 文件系统：图标包管理

安装与运行

系统要求

• Flutter 3.19.0 或更高版本

• Dart 3.3.0 或更高版本

• Android SDK 21+ 或 iOS 12.0+

安装步骤

1. 克隆项目
git clone https://github.com/CrYinLang/EmuAIO.git
cd EmuAIO


2. 获取依赖
flutter pub get


3. 运行应用
# 调试模式
flutter run

# 发布模式
flutter run --release


构建发布

Android APK
flutter build apk --release


iOS App
flutter build ios --release


Web 版本
flutter build web --release


项目结构


lib/
├── main.dart                 # 应用入口
├── home_page.dart           # 首页查询功能
├── gallery_page.dart        # 动车图鉴页面
├── settings_page.dart       # 设置页面
├── about_page.dart          # 关于页面
├── train_model.dart         # 数据模型
├── color_theme.dart         # 主题配置
└── assets/
    ├── data.json           # 本地数据库
    └── icon/               # 图标资源
        ├── train/          # 动车图标
        └── bureau/         # 路局图标


核心特性

智能搜索算法

应用实现了模糊匹配算法，支持多种查询方式：
• 车次查询：根据前缀（G/D/C）+ 车号在交路信息中查找

• 车号查询：在车组号字段中精确匹配

• 路局查询：支持路局名称和简称的模糊匹配

数据同步机制

• 本地 JSON 数据库缓存，支持离线快速查询

• 实时 API 数据获取（集成 rail.re API）

• 智能缓存策略，提升查询效率

图标包系统

支持自定义图标包导入和管理：
• 支持 ZIP 格式图标包

• 自动解析 manifest.json 配置文件

• 图标映射和元信息提取

• 多图标包切换功能

API 接口

应用集成以下数据源：
• rail.re API：实时交路信息查询

• china-emu.cn：完整动车图鉴数据

• 本地数据库：离线快速查询支持

更新日志

v2.1.1.2 (2026-01-24)

• 新增路局查询分页功能

• 优化图标包导入流程

• 修复交路信息显示问题

• 改进深夜模式视觉效果

v2.1.0 (2025-12-15)

• 重构项目架构

• 新增图标包管理系统

• 优化搜索算法性能

• 增强离线支持能力

开发团队

• Cr.YinLang - 主要开发者和维护者

• Email: iceiswpan@163.com

• GitHub: https://github.com/CrYinLang

许可证

本项目采用 MIT 许可证 - 查看 LICENSE 文件了解详情。

贡献指南

我们欢迎各种形式的贡献！请阅读贡献指南了解如何参与项目开发。

相关链接

• https://github.com/CrYinLang/EmuAIO/wiki - 详细开发文档

• https://github.com/CrYinLang/EmuAIO/issues - 报告 Bug 或提出建议

• https://github.com/CrYinLang/EmuAIO/releases - 下载最新版本

联系方式

如有任何问题或建议，请通过以下方式联系我们：
• 问题反馈：在 GitHub Issues 中提交

• 邮件联系：iceiswpan@163.com

• 社交媒体：关注抖音账号获取最新动态
