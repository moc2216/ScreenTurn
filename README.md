# ScreenTurn

> [English](README.en.md) | **简体中文**

ScreenTurn 是一个轻量的 macOS 菜单栏应用，用来在横屏和竖屏之间快速切换指定显示器。

它保留了脚本工具的效率，也提供了菜单栏操作、可录入的全局快捷键、多显示器选择与恢复上次显示状态等功能。

## 主要功能

- 菜单栏一键切换横屏和竖屏
- 可自定义全局快捷键
- 设置窗口直接选择目标显示器
- 记录并恢复上一次显示状态
- 支持开机启动
- 提供命令行工具 **screenturn** 与短别名 **st**
- 自动检查并安装所需的 **displayplacer**

ScreenTurn 使用 [displayplacer](https://github.com/jakehilborn/displayplacer) 完成 macOS 显示器旋转。

## 下载发布版

发布版只支持 Apple Silicon Mac，也就是 M 系列芯片的 Mac。它不需要安装 Xcode 或 Swift。

从 GitHub 的 Releases 页面下载 **ScreenTurn-<版本>-macos.zip**，然后在终端运行：

~~~bash
unzip ScreenTurn-<版本>-macos.zip
cd ScreenTurn-<版本>
./install.sh
~~~

安装器会自动：

- 检查 **displayplacer** 是否存在；如果安装了 Homebrew，会自动安装它
- 安装 **ScreenTurn.app** 到 **~/Applications**
- 安装 **screenturn** 和 **st** 到 **~/.local/bin**
- 尝试把 **~/.local/bin** 加入终端 PATH

每个发布包都附带同名的 **.sha256** 文件，可用于核对下载文件是否完整。

> 当前发布包没有 Apple Developer 签名和公证。macOS 首次打开从 GitHub 下载的 App 时，可能会要求你确认一次。

## 源码安装

如果你是从 GitHub 克隆项目源码安装，需要：

- macOS 13 或更高版本
- Xcode Command Line Tools
- Homebrew

安装依赖：

~~~bash
brew install displayplacer
~~~

然后在项目目录运行：

~~~bash
./scripts/install.sh
~~~

## 首次设置

安装完成后，先执行：

~~~bash
st doctor
st s
st -n
~~~

含义分别是：

1. **st doctor**：检查依赖、配置和显示器状态。
2. **st s**：自动检测当前目标显示器，并保存横竖屏参数。
3. **st -n**：只预览下一次切换命令，不会真的旋转屏幕。

随后启动 App：

~~~bash
open ~/Applications/ScreenTurn.app
~~~

## 菜单栏使用

- 左键点击菜单栏图标：切换屏幕方向。
- 右键点击，或按住 Control 点击：打开菜单。
- 菜单会显示当前屏幕方向、分辨率和当前快捷键。
- 使用 **Launch at Login** 控制是否开机自动启动。

## 设置快捷键和显示器

在菜单栏中选择 **Settings...**：

1. 从 **Target Display** 下拉列表选择需要旋转的显示器。
2. 显示器刚接入或移除时，点击旁边的刷新按钮重新检测。
3. 点击快捷键框，再按下想使用的组合键。
4. 点击 **Save** 保存。

快捷键必须至少包含一个修饰键：Control、Option、Shift 或 Command。

设置窗口打开时，ScreenTurn 会临时停用当前全局快捷键，避免录入新快捷键时误触发屏幕旋转。

默认快捷键是：

~~~text
Control + Option + Command + R
~~~

## 多显示器

ScreenTurn 保存的是某一台显示器的独立配置。选择新的显示器并保存时，会同步记录它的分辨率、旋转角度、刷新率、色深、缩放和位置。

也可以使用命令行查看与选择显示器：

~~~bash
st ls
st use <显示器ID>
~~~

## 恢复上一次方向

每次成功旋转前，ScreenTurn 会保存当前显示状态。

若想回到切换前的状态，可以：

- 在菜单中选择 **Restore Last Rotation**
- 或运行：

~~~bash
st restore
~~~

只想先预览恢复命令：

~~~bash
st -n restore
~~~

恢复成功后，恢复记录会被清除。选择另一台显示器时，旧显示器的恢复记录也会被清除。

## 命令行

~~~bash
st                    # 切换屏幕方向
st t                  # 切换屏幕方向
st s                  # 自动检测并保存显示器配置
st s <显示器ID>       # 为指定显示器保存配置
st use <显示器ID>     # 选择已检测到的显示器
st use --force <ID>   # 没有检测结果时直接保存显示器 ID
st restore            # 恢复上一次切换前的显示状态
st status             # 查看配置和检测到的显示器
st ls                 # status 的短别名
st doctor             # 检查准备状态
st path               # 显示配置文件位置
st open               # 打开配置文件
st -n                 # 预览下一次切换，不实际执行
st -n restore         # 预览恢复命令，不实际执行
st help               # 显示帮助
st version            # 显示版本
~~~

完整命令 **screenturn** 也可使用，例如：

~~~bash
screenturn toggle
screenturn setup
screenturn status
~~~

## 配置文件

配置文件默认位于：

~~~text
~/Library/Application Support/ScreenTurn/config.json
~~~

通常应通过 **Settings...** 修改设置。需要手动排查问题时，可以在菜单中选择 **Open Config**，或运行：

~~~bash
st open
~~~

## 构建和测试

从源码构建 App：

~~~bash
./scripts/build-app.sh
~~~

运行自测：

~~~bash
./scripts/test.sh
~~~

生成 ARM64 发布包：

~~~bash
APP_VERSION=0.1.0 ./scripts/package.sh
~~~

生成的 ZIP 和校验文件位于 **dist/**。

## GitHub 自动化

GitHub Actions 会在每次推送代码或提交 Pull Request 时自动：

1. 运行自测。
2. 构建图标和 ARM64 App。
3. 生成可下载的发布包。

在 GitHub 创建正式 Release 时，自动化会把 ZIP 和校验文件附加到 Release 页面。

## 卸载

~~~bash
./scripts/uninstall.sh
~~~

卸载不会删除你的配置文件。
