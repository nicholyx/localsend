

<p align="center">
  <h1 align="center"> <code>path_provider</code> </h1>
</p>

本项目基于 [path_provider@2.1.2](https://pub.dev/packages/path_provider/versions/2.1.2) 开发。

## 1. 安装与使用

### 1.1 安装方式

进入到工程目录并在 pubspec.yaml 中添加以下依赖：

<!-- tabs:start -->

#### pubspec.yaml

```yaml
...

dependencies:
  path_provider:
    git: 
      url: https://gitcode.com/openharmony-tpc/flutter_packages.git
      path: packages/path_provider/path_provider

...
```

执行命令

```bash
flutter pub get
```

<!-- tabs:end -->

### 1.2 使用案例

使用案例详见 [ohos/example](./example)

## 2. 约束与限制

### 2.1 兼容性

在以下版本中已测试通过

1. Flutter: 3.27.5-ohos-0.0.1; SDK: 5.0.0(12); IDE: DevEco Studio: 5.1.0.828; ROM: 5.1.0.130 SP8;

### 2.2 权限要求

以下权限中有`system_basic` 权限，而默认的应用权限是 `normal` ，只能使用 `normal` 等级的权限，所以可能会在安装hap包时报错**9568289**，请参考 [文档](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides-V5/bm-tool-V5#ZH-CN_TOPIC_0000001884757326__%E5%AE%89%E8%A3%85hap%E6%97%B6%E6%8F%90%E7%A4%BAcode9568289-error-install-failed-due-to-grant-request-permissions-failed) 修改应用等级为 `system_basic`

####  2.2.1在 entry 目录下的module.json5中添加权限

打开 `entry/src/main/module.json5`，添加：

```yaml
"requestPermissions": [
  {
   "name": "ohos.permission.INTERNET",
    "reason": "$string:network_reason",
    "usedScene": {
      "abilities": [
        "EntryAbility"
      ],
      "when":"inuse"
    }
  },
]
```

####  2.2.2在 entry 目录下添加申请以上权限的原因

打开 `entry/src/main/resources/base/element/string.json`，添加：

```
...
{
  "string": [
    {
      "name": "network_reason",
      "value": "使用网络"
    },
  ]
}
```

## 3. API

> [!TIP] "ohos Support"列为 yes 表示 ohos 平台支持该属性；no 则表示不支持；partially 表示部分支持。使用方法跨平台一致，效果对标 iOS 或 Android 的效果。

| Name                | return value                        |  Description               | Type       | ohos Support |
|---------------------|-------------------------------------------------------------------------------------------------------|------|-------|-------------------|
| getTemporaryPath()   |   Future<String?>             |         获取设备上未备份的临时目录路径，适合存放下载文件的缓存     | function | yes               |
| getApplicationSupportPath()   |    Future<String?>     |    获取应用程序支持文件目录路径的方法，应用程序可能放置应用程序支持文件的目录的路径，如果该目录不存在，则自动创建。         | function | yes               |
| getApplicationDocumentsPath() |     Future<String?>  |          获取应用程序文件路径的方法，应用程序可以在其中放置用户生成的数据，或者不能由应用程序重新创建的数据。       | function | yes               |
| getApplicationCachePath()   | Future<String?>       |          获取应用程序缓存路径的方法，应用程序可能放置特定于应用程序的缓存文件目录的路径，如果该目录不存在，则自动创建。      | function       | yes              |
| getExternalCachePaths()     | Future<List<String?>> | 获取应用程序的缓存数据可以存储在外部的目录路径，这些路径通常位于外部存储上，如单独的分区或SD卡。手机可能有多个可用的存储目录  | function       | yes               |
| getExternalStoragePath()    |   Future<String?>         |       获取应用程序顶级存储路径的方法，应用程序可以在其中访问顶级存储的目录路径。     |        function       | yes               |
| getExternalStoragePaths([StorageDirectory](#StorageDirectory) arg_directory)   | Future<List<String?>> |   获取应用程序顶级存储路径的方法，应用程序特定的数据可以存储在外部目录的路径，这些路径通常位于外部存储上，如单独的分区或SD卡。手机可能有多个可用的存储目录。 | function       | yes               |

## 4. 属性

### StorageDirectory

| Name              | Description                                                | Type                                        | ohos Support |
| ----------------- | ---------------------------------------------------------- | ------------------------------------------- | ------------ |
|  StorageDirectory.root  | 存储目录的根目录类型 |  enum | yes   |
|  StorageDirectory.music  | 存储目录的音乐文件类型 |  enum | yes   |
|  StorageDirectory.podcasts  | 存储目录的音频文件类型 |  enum | yes   |
|  StorageDirectory.ringtones  | 存储目录的铃声文件类型 |  enum | yes   |
|  StorageDirectory.alarms  | 存储目录的闹钟铃声文件类型 |  enum | yes   |
|  StorageDirectory.notifications  | 存储目录的通知文件类型 |  enum | yes   |
|  StorageDirectory.pictures  | 存储目录的图片文件类型 |  enum | yes   |
|  StorageDirectory.movies  | 存储目录的电影文件类型 |  enum | yes   |
|  StorageDirectory.downloads  | 存储目录的下载文件类型 |  enum | yes   |
|  StorageDirectory.dcim  | 存储目录的照片和视频文件类型 |  enum | yes   |
|  StorageDirectory.documents  | 存储目录的普通文件类型 |  enum | yes   |

## 5. 遗留问题

## 6. 其他

## 7. 开源协议

本项目基于 [TBSD-3-Clause](https://gitcode.com/ymcel/flutter_packages/blob/master/packages/path_provider/path_provider/LICENSE) ，请自由地享受和参与开源。


> 模板版本: v0.0.1