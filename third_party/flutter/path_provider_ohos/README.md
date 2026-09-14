

<p align="center">
  <h1 align="center"> <code>path_provider</code> </h1>
</p>



This project is based on [path_provider@2.1.2](https://pub.dev/packages/path_provider/versions/2.1.2).

## 1. Installation and Usage

### 1.1 Installation

Go to the project directory and add the following dependencies in pubspec.yaml

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

Execute Command

```bash
flutter pub get
```

<!-- tabs:end -->

### 1.2 Usage

For use cases [ohos/example](./example)

## 2. Constraints

### 2.1 Compatibility

This document is verified based on the following versions:

1. Flutter: 3.27.5-ohos-0.0.1; SDK: 5.0.0(12); IDE: DevEco Studio: 5.1.0.828; ROM: 5.1.0.130 SP8;

### 2.2 **Permission Requirements**

The following permissions include the `system_basic` permission, but the default application permission is `normal`. Only the `normal` permission can be used. Therefore, the error **9568289** may be reported during the installation of the HAP package. For details, see [Document](https://developer.huawei.com/consumer/en/doc/harmonyos-guides-V5/bm-tool-V5#EN_TOPIC_0000001884757326__%E5%AE%89%E8%A3%85hap%E6%97%B6%E6%8F%90%E7%A4%BAcode9568289-error-install-failed-due-to-grant-request-permissions-failed) Change the application level to `system_basic`.

####  2.2.1 **Add permissions to the module.json5 file in the entry directory**

Open  `entry/src/main/module.json5` and add the following information:

```diff
"requestPermissions": [
      {
        "name": "ohos.permission.INTERNET",
        "reason": "$string:network_reason",
        "usedScene": {
          "abilities": [
            "EntryAbility"
          ],
          "when": "inuse"
        }
      },
    ]
```

#### 2.2.2 **Add the reason for applying for the preceding permission to the entry directory**

Open  `entry/src/main/resources/base/element/string.json` and add the following information:

```diff
{
  "string": [
    {
      "name": "network_reason",
      "value": "use network"
    }
  ]
}
```


## 3. API

> [!TIP] If the value of **ohos Support** is **yes**, it means that the ohos platform supports this property; **no** means the opposite; **partially** means some capabilities of this property are supported. The usage method is the same on different platforms and the effect is the same as that of iOS or Android.

| Name                | return value                        |  Description               | Type       | ohos Support |
|---------------------|-------------------------------------------------------------------------------------------------------|------|-------|-------------------|
| getTemporaryPath()   |   Future<String?>             |         Obtain the unbacked temporary directory path on the device, which is suitable for storing the cache of downloaded files.     | function | yes               |
| getApplicationSupportPath()   |    Future<String?>     |    The method to obtain the path of the directory of the application support files, the path of the directory where the application may place the application support files. If the directory does not exist, it will be automatically created.       | function | yes               |
| getApplicationDocumentsPath() |     Future<String?>  |          The method to obtain the file path of the application, in which the application can place user-generated data or data that cannot be recreated by the application.       | function | yes               |
| getApplicationCachePath()   | Future<String?>       |          The method to obtain the application cache path: The application may place a path specific to the application cache file directory. If the directory does not exist, it will be automatically created.      | function       | yes              |
| getExternalCachePaths()     | Future<List<String?>> | Obtaining the cached data of the application can be stored in external directory paths, which are usually located on external storage, such as separate partitions or SD cards. A mobile phone may have multiple available storage directories.  | function       | yes               |
| getExternalStoragePath()    |   Future<String?>         |       The method of obtaining the top-level storage path of the application, where the application can access the directory path of the top-level storage.     |        function       | yes               |
| getExternalStoragePaths([StorageDirectory](#StorageDirectory) arg_directory)   | Future<List<String?>> |   The method of obtaining the top-level storage path of the application, the paths where application-specific data can be stored in external directories, and these paths are usually located on external storage, such as separate partitions or SD cards. A mobile phone may have multiple available storage directories. | function       | yes               |

## 4. Properties

### StorageDirectory

| Name              | Description                                                | Type                                        | ohos Support |
| ----------------- | ---------------------------------------------------------- | ------------------------------------------- | ------------ |
|  StorageDirectory.root  | The root directory type of the storage directory |  enum | yes   |
|  StorageDirectory.music  | The type of music file stored in the directory |  enum | yes   |
|  StorageDirectory.podcasts  | The audio file type of the storage directory |  enum | yes   |
|  StorageDirectory.ringtones  | The ringtone file type of the storage directory |  enum | yes   |
|  StorageDirectory.alarms  | The file type of the alarm bell in the storage directory |  enum | yes   |
|  StorageDirectory.notifications  | The notification file type of the storage directory |  enum | yes   |
|  StorageDirectory.pictures  | The image file type of the storage directory |  enum | yes   |
|  StorageDirectory.movies  | The movie file type of the storage directory |  enum | yes   |
|  StorageDirectory.downloads  | The download file type of the storage directory |  enum | yes   |
|  StorageDirectory.dcim  | The types of photo and video files stored in the directory |  enum | yes   |
|  StorageDirectory.documents  | The common file types of the storage directory |  enum | yes   |

## 5. Known Issues

## 6. Others

## 7. License

This project is licensed under [TBSD-3-Clause](https://gitcode.com/ymcel/flutter_packages/blob/master/packages/path_provider/path_provider/LICENSE)


> Template version: v0.0.1
