# 🍮 布丁发布 (Pudding Post) - AI 文章智能采集发布助手

布丁发布是一款专为内容创作者、博客运营人员打造的现代化暗黑科技风桌面助手。本系统基于 Flutter 构建，采用大语言模型 (LLM) 驱动，支持对互联网任意文章页、列表页进行智能解析，完美提取出结构化的 Markdown 内容，并支持一键发布/批量同步到 **Emlog 博客系统**。

---

## 🎨 视觉设计与美学

项目界面采用现代极简毛玻璃 (Glassmorphism) 与暗黑极光霓虹 (Neon Light) 结合的科技美学设计：
- **霓虹极光背景**：自研轻量级径向渐变融合高斯模糊的背景晕染动画。
- **毛玻璃侧边栏**：悬浮式导航菜单，精美的微动效与 hover 反馈。
- **卡片式分栏布局**：数据展示井然有序，富有视觉呼吸感。

---

## 🚀 核心功能模块

### 1. 内容采集 (Content Capture)
- **智能网页提取**：输入任意网页详情页 URL，借助 AI 自动过滤广告和噪点，提取核心的【文章标题】、【Markdown 格式正文】与【封面大图】。
- **智能列表解析**：输入列表页 URL，AI 自动定位所有文章链接，并精确定位“下一页”分页链接。
- **自定义提取 Prompt**：支持在发布管理中为 AI 提供专用的指令指令。

### 2. 内容管理 (Content Management)
- **已采内容库**：大表单卡片化管理已抓取回本地的数据，并支持实时全局模糊搜索。
- **内置 Markdown 编辑器**：在发布前直接在侧边编辑器中修改标题、修改封面图或实时调整 Markdown 正文排版，支持所见即所得。
- **物理删除**：随时剔除无效或者重复采集的文章，支持一键清空本地缓存。

### 3. 发布管理 (Publish Management)
- **Emlog 渠道卡片**：默认展示 Emlog 博客发布卡片，清晰呈现其是否配置、对接网址等信息。
- **API 对接配置**：点击卡片一键配置博客系统的 `Site URL` 及 `API Token`，且包含本地接口连通性测试。
- **多选批量发布**：支持在内容管理中，单篇发布或多选后一键批量推送发布至 Emlog 博客系统的特定分类。

### 4. 模型设置 (Model Settings)
- **多模型并存**：支持添加多款大语言模型（如 DeepSeek、OpenAI 或其他兼容 OpenAI 格式的本地/云端大模型）。
- **随时开启与关闭**：列表化呈现配置并提供 Switch 开关。系统将自动采用首个处于“开启”状态的模型作为当前抓取的默认 AI 核心。
- **连通性校验**：在保存前或卡片列表中随时进行 API 接口连接测试。

---

## 🛠️ 技术架构

- **UI 框架**：Flutter 3.x (Dart) 支持跨平台 (macOS Desktop, Windows, Web 等)
- **本地存储**：SQLite (基于 `sqflite_common_ffi` 引擎，保障桌面端轻量级运行)
- **网络通信**：Dio (RESTful API 请求大模型及 emlog 接口)
- **状态管理**：Provider (ChangeNotifier 状态树加载与分发)

---

## 📦 启动与部署部署说明

### 前置环境要求
1. **Flutter SDK**：请确保已安装 Flutter SDK (`>= 3.0.0`)，并且 `flutter doctor` 无异常。
2. **桌面端工具链**：
   - **macOS**：需安装 Xcode 与 CocoaPods。
   - **Windows**：需安装 Visual Studio 以及 "使用 C++ 的桌面开发" 负载。

### 1. 快速克隆与依赖安装
打开终端，进入项目目录，执行以下命令获取所有第三方插件包依赖：
```bash
flutter pub get
```

### 2. 本地调试启动
- **在 macOS 桌面平台启动运行** (推荐)：
  ```bash
  flutter run -d macos
  ```
- **在 网页浏览器 (Chrome) 中运行**：
  ```bash
  flutter run -d chrome
  ```
- **查看已连接的所有可用设备列表**：
  ```bash
  flutter devices
  ```

### 3. 生产环境编译打包
- **编译 macOS 桌面应用 (.app)**：
  ```bash
  flutter build macos
  ```
  编译完成后，您可以在以下目录找到打包好的 `.app` 应用程序：
  `build/macos/Build/Products/Release/ai_article_collector.app`

- **编译 Windows 桌面应用 (.exe)**：
  ```bash
  flutter build windows
  ```

---

## 📝 系统初始化指引

1. **第一步：进入【模型设置】**
   - 点击右上角“添加大模型配置”。
   - 填写您的大模型接口信息（如 DeepSeek，Base URL: `https://api.deepseek.com/v1`，填入 API Key 和对应的模型标识 `deepseek-chat`）。
   - 点击“测试连通性”校验无误后保存。并确保右侧的 Switch 开关处于**开启**状态。
2. **第二步：进入【发布管理】**
   - 点击 Emlog 博客渠道卡片。
   - 填入您的 Emlog 站点地址（如 `http://yourblog.com`）和在后台系统设置 -> API 中获取到的 `API Token`。
   - 点击保存。
3. **第三步：开始【内容采集】**
   - 输入您想要采集的网页文章 URL，点击“智能抓取详情”。
   - AI 提取成功后，会自动存入本地数据库并跳转至【内容管理】。
4. **第四步：编辑与【发布】**
   - 在【内容管理】选中采集的文章，确认无误后点击“发布到博客”，选择分类即可轻松上线！
