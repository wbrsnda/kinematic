# 项目使用教程

## 配置 Flutter 环境

  1. **安装 Flutter SDK** ：从[Flutter 官方网站](https://flutter.dev)下载最新版本的 Flutter SDK，并按照官方指南进行安装。
  2. **配置环境变量** ：将 Flutter SDK 的`bin`目录添加到系统的环境变量`PATH`中，以便在命令行中可以全局使用 Flutter 命令。

## 克隆项目

在命令行中运行以下命令，将项目从 Git 仓库克隆到本地：

```bash
git clone http://10.1.16.174:3000/402_Laboratory/Kinematic_Jump_Flutter.git
```

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