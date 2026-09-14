import {
  AbilityAware,
  AbilityPluginBinding,
  FlutterPlugin,
  FlutterPluginBinding,
  Log,
  MethodCall,
  MethodCallHandler,
  MethodChannel,
  MethodResult,
} from '@ohos/flutter_ohos';
import { BusinessError } from '@kit.BasicServicesKit';
import { UIAbility, Want, bundleManager, wantConstant } from '@kit.AbilityKit';
import window from '@ohos.window';
import fs from '@ohos.file.fs';
import fileuri from '@ohos.file.fileuri';

const TAG: string = 'LocalsendOhosPlugin';
const FILE_OPENER_CHANNEL: string = 'org.localsend.localsend_app/ohos_file_opener';
const PACKAGE_INFO_CHANNEL: string = 'plugins.flutter.io/package_info';
const WAKELOCK_CHANNEL: string = 'wakelock_plus';
const ACTION_VIEW_DATA: string = 'ohos.want.action.viewData';
const CAN_NOT_MATCH_ANY_COMPONENT: number = 16000019;

/**
 * LocalSend-specific HarmonyOS integrations that have no upstream ohos plugin:
 *
 * 1. `org.localsend.localsend_app/ohos_file_opener`
 *    Opens received files / folders with system apps (startAbility + viewData).
 *
 * 2. `plugins.flutter.io/package_info`
 *    Serves the same method channel protocol as package_info_plus, backed by bundleManager,
 *    so `PackageInfo.fromPlatform()` keeps working on HarmonyOS.
 *
 * 3. `wakelock_plus`
 *    Serves the wakelock_plus method channel protocol via window keep-screen-on,
 *    so `WakelockPlus.enable()/disable()` keeps working on HarmonyOS.
 */
export default class LocalsendOhosPlugin implements FlutterPlugin, MethodCallHandler, AbilityAware {
  private fileOpenerChannel: MethodChannel | null = null;
  private packageInfoChannel: MethodChannel | null = null;
  private wakelockChannel: MethodChannel | null = null;
  private ability: UIAbility | null = null;

  getUniqueClassName(): string {
    return TAG;
  }

  onAttachedToEngine(binding: FlutterPluginBinding): void {
    this.fileOpenerChannel = new MethodChannel(binding.getBinaryMessenger(), FILE_OPENER_CHANNEL);
    this.fileOpenerChannel.setMethodCallHandler(this);

    this.packageInfoChannel = new MethodChannel(binding.getBinaryMessenger(), PACKAGE_INFO_CHANNEL);
    this.packageInfoChannel.setMethodCallHandler(this);

    this.wakelockChannel = new MethodChannel(binding.getBinaryMessenger(), WAKELOCK_CHANNEL);
    this.wakelockChannel.setMethodCallHandler(this);
  }

  onDetachedFromEngine(binding: FlutterPluginBinding): void {
    this.fileOpenerChannel?.setMethodCallHandler(null);
    this.fileOpenerChannel = null;
    this.packageInfoChannel?.setMethodCallHandler(null);
    this.packageInfoChannel = null;
    this.wakelockChannel?.setMethodCallHandler(null);
    this.wakelockChannel = null;
  }

  onAttachedToAbility(binding: AbilityPluginBinding): void {
    this.ability = binding.getAbility();
  }

  onDetachedFromAbility(): void {
    this.ability = null;
  }

  onMethodCall(call: MethodCall, result: MethodResult): void {
    switch (call.method) {
      // ---- file opener ----
      case 'openFile':
        this.openPath(
          this.getStringArgument(call, 'path'),
          this.getStringArgument(call, 'mimeType') || '*/*',
          result,
        );
        break;
      case 'openFolder':
        this.openPath(
          this.getStringArgument(call, 'path'),
          '',
          result,
        );
        break;

      // ---- package_info_plus ----
      case 'getAll':
        this.getPackageInfo(result);
        break;

      // ---- wakelock_plus ----
      case 'enable':
        this.setKeepScreenOn(true, result);
        break;
      case 'disable':
        this.setKeepScreenOn(false, result);
        break;
      case 'isEnabled':
        this.isKeepScreenOn(result);
        break;

      default:
        result.notImplemented();
        break;
    }
  }

  // ------------------------------------------------------------------
  // File opener
  // ------------------------------------------------------------------

  private openPath(rawPath: string, type: string, result: MethodResult): void {
    if (this.ability == null) {
      result.error('NO_ABILITY', 'OHOS ability is not attached.', null);
      return;
    }

    const targetPath = rawPath.trim();
    if (targetPath.length == 0) {
      result.error('INVALID_PATH', 'File path cannot be empty.', null);
      return;
    }

    if (this.shouldCheckPath(targetPath) && !this.exists(targetPath)) {
      result.error('FILE_NOT_FOUND', 'File path does not exist: ' + targetPath, null);
      return;
    }

    const targetUri = this.toUri(targetPath);
    const want: Want = {
      flags: wantConstant.Flags.FLAG_AUTH_WRITE_URI_PERMISSION | wantConstant.Flags.FLAG_AUTH_READ_URI_PERMISSION,
      action: ACTION_VIEW_DATA,
      uri: targetUri,
    };
    if (type.length > 0) {
      want.type = type;
    }

    Log.i(TAG, 'Opening path: ' + targetPath + ', uri: ' + targetUri + ', type: ' + type);
    this.ability.context.startAbility(want)
      .then(() => {
        result.success(true);
      })
      .catch((err: BusinessError) => {
        Log.e(TAG, 'startAbility failed: ' + JSON.stringify(err));
        if (err.code == CAN_NOT_MATCH_ANY_COMPONENT) {
          result.error('NO_APP', 'No application found to open this path.', err.message);
        } else {
          result.error('OPEN_FAILED', err.message, err.code);
        }
      });
  }

  private getStringArgument(call: MethodCall, name: string): string {
    if (!call.hasArgument(name)) {
      return '';
    }

    const value: ESObject = call.argument(name);
    if (value == null || value == undefined) {
      return '';
    }
    return String(value);
  }

  private shouldCheckPath(path: string): boolean {
    return path.startsWith('/') && !path.startsWith('//');
  }

  private exists(path: string): boolean {
    try {
      return fs.accessSync(path);
    } catch (err) {
      Log.e(TAG, 'accessSync failed: ' + JSON.stringify(err));
      return false;
    }
  }

  private toUri(path: string): string {
    if (path.startsWith('content://') || path.startsWith('file://') || path.startsWith('file:/')) {
      return path;
    }
    if (path.startsWith('/')) {
      return fileuri.getUriFromPath(path);
    }
    return path;
  }

  // ------------------------------------------------------------------
  // package_info_plus compatibility
  // ------------------------------------------------------------------

  private getPackageInfo(result: MethodResult): void {
    try {
      const info = bundleManager.getBundleInfoForSelfSync(bundleManager.BundleFlag.GET_BUNDLE_INFO_WITH_APPLICATION);
      result.success({
        'appName': this.resolveAppName(info),
        'packageName': info.name,
        'version': info.versionName,
        'buildNumber': String(info.versionCode),
        'buildSignature': '',
      });
    } catch (err) {
      Log.e(TAG, 'getBundleInfoForSelfSync failed: ' + JSON.stringify(err));
      result.error('UNAVAILABLE', 'Failed to read bundle info.', JSON.stringify(err));
    }
  }

  private resolveAppName(info: bundleManager.BundleInfo): string {
    try {
      const appInfo = info.appInfo;
      if (appInfo != undefined && appInfo.label != undefined && appInfo.label.length > 0 && !appInfo.label.startsWith('$')) {
        return appInfo.label;
      }
    } catch (err) {
      Log.w(TAG, 'resolveAppName failed: ' + JSON.stringify(err));
    }
    return info.name;
  }

  // ------------------------------------------------------------------
  // wakelock_plus compatibility
  // ------------------------------------------------------------------

  private setKeepScreenOn(enabled: boolean, result: MethodResult): void {
    if (this.ability == null) {
      result.error('NO_ABILITY', 'OHOS ability is not attached.', null);
      return;
    }

    window.getLastWindow(this.ability.context)
      .then((win: window.Window) => {
        return win.setWindowKeepScreenOn(enabled);
      })
      .then(() => {
        Log.i(TAG, 'Keep screen on: ' + enabled);
        result.success(null);
      })
      .catch((err: BusinessError) => {
        Log.e(TAG, 'setWindowKeepScreenOn failed: ' + JSON.stringify(err));
        result.error('WAKELOCK_FAILED', err.message, err.code);
      });
  }

  private isKeepScreenOn(result: MethodResult): void {
    if (this.ability == null) {
      result.error('NO_ABILITY', 'OHOS ability is not attached.', null);
      return;
    }

    window.getLastWindow(this.ability.context)
      .then((win: window.Window) => {
        result.success(win.getWindowProperties().isKeepScreenOn);
      })
      .catch((err: BusinessError) => {
        Log.e(TAG, 'getLastWindow failed: ' + JSON.stringify(err));
        result.error('WAKELOCK_FAILED', err.message, err.code);
      });
  }
}
