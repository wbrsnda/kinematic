# 项目使用教程

## 配置 Flutter 环境

  1. **安装 Flutter SDK** ：从[Flutter 官方网站](https://flutter.dev)下载最新版本的 Flutter SDK，并按照官方指南进行安装。
  2. **配置环境变量** ：将 Flutter SDK 的`bin`目录添加到系统的环境变量`PATH`中，以便在命令行中可以全局使用 Flutter 命令。


## 安装依赖

在项目根目录下，运行以下命令来安装项目所需的所有依赖包：

```bash
flutter pub get
```

## 运行项目

在完成上述步骤后，可以通过以下命令在 Chrome 浏览器（建议使用）中运行项目：

```bash
flutter run -d chrome
```