import 'dart:io';

/// 递增 pubspec.yaml 中的版本号
///
/// 读取本地的 `pubspec.yaml` 文件，寻找 `version: x.y.z+n` 格式的版本号配置。
/// 将其中的 patch 版本号（z）与构建号（n）分别递增 1，然后写回该文件。
/// 执行成功时，会在标准输出打印出新的版本号，以便发布脚本读取；执行失败时退出码为 1。
void main() {
  final file = File('pubspec.yaml');
  if (!file.existsSync()) {
    print('Error: pubspec.yaml not found');
    exit(1);
  }
  
  final lines = file.readAsLinesSync();
  String? newVersion;
  
  for (int i = 0; i < lines.length; i++) {
    final line = lines[i];
    // 匹配以 version: 开头的行
    if (line.startsWith('version:')) {
      final parts = line.split(':');
      if (parts.length < 2) continue;
      final versionStr = parts[1].trim(); // 例如 "1.0.0+1"
      final match = RegExp(r'^(\d+)\.(\d+)\.(\d+)\+(\d+)$').firstMatch(versionStr);
      if (match != null) {
        final major = int.parse(match.group(1)!);
        final minor = int.parse(match.group(2)!);
        final patch = int.parse(match.group(3)!);
        final build = int.parse(match.group(4)!);
        
        final newPatch = patch + 1;
        final newBuild = build + 1;
        newVersion = '$major.$minor.$newPatch+$newBuild';
        lines[i] = 'version: $newVersion';
      }
      break;
    }
  }
  
  if (newVersion != null) {
    file.writeAsStringSync(lines.join('\n') + '\n');
    // 输出新版本号给调用此脚本的 shell
    stdout.write(newVersion);
  } else {
    print('Error: Could not parse version in pubspec.yaml');
    exit(1);
  }
}
