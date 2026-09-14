// Copyright (c) 2023 Hunan OpenValley Digital Industry Development Co., Ltd.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE_ODID file.
// Based on SharedPreferencesPlugin.java originally written by
// Copyright 2013 The Flutter Authors.

import {
  FlutterPlugin,
  FlutterPluginBinding
} from '@ohos/flutter_ohos/src/main/ets/embedding/engine/plugins/FlutterPlugin';
import MessageCodec from '@ohos/flutter_ohos/src/main/ets/plugin/common/MessageCodec';
import StandardMessageCodec from '@ohos/flutter_ohos/src/main/ets/plugin/common/StandardMessageCodec';
import { SharedPreferencesApi, wrapError } from './Messages';
import Log from '@ohos/flutter_ohos/src/main/ets/util/Log';
import data_preferences from '@ohos.data.preferences';
import BasicMessageChannel, { Reply } from '@ohos/flutter_ohos/src/main/ets/plugin/common/BasicMessageChannel';
import { BinaryMessenger } from '@ohos/flutter_ohos/src/main/ets/plugin/common/BinaryMessenger';

import common from '@ohos.app.ability.common';
import { 
  SharedPreferencesAsyncApi, 
  setupSharedPreferencesAsyncApi,
  SharedPreferencesPigeonOptions, 
  StringListResult, 
  StringListLookupResultType
} from './MessagesAsync';

const TAG = "SharedPreferencesOhosPlugin";
const PREFERENCES_NAME = "FlutterSharedPreferences";
const LIST_IDENTIFIER = "VGhpcyBpcyB0aGUgcHJlZml4IGZvciBhIGxpc3Qu";

// ListEncoder implementation
interface ListEncoder {
  encode(list: string[]): string;
  decode(encoded: string): string[];
}

class ListEncoderImpl implements ListEncoder {
  encode(list: string[]): string {
    return JSON.stringify(list);
  }

  decode(encoded: string): string[] {
    try {
      return JSON.parse(encoded) as string[];
    } catch (e) {
      Log.e(TAG, "Failed to decode list: " + e);
      return [];
    }
  }
}

// Extended type definition to handle all OHOS ValueType values
type ExtendedPreferenceValue = string | number | boolean | bigint | object | null;

// Async API implementation class
class SharedPreferencesAsyncApiImpl implements SharedPreferencesAsyncApi {
  private plugin: SharedPreferencesOhosPlugin;

  constructor(plugin: SharedPreferencesOhosPlugin) {
    this.plugin = plugin;
  }

  async getString(key: string, options: SharedPreferencesPigeonOptions): Promise<string | null> {
    try {
      if (this.plugin.preferences == null) {
        return null;
      }
      const value = await this.plugin.preferences.get(key, null) as ExtendedPreferenceValue;
      if (typeof value === 'string' && !value.startsWith(LIST_IDENTIFIER)) {
        return value;
      }
      return null;
    } catch (err) {
      Log.w(TAG, "Failed to getString: " + JSON.stringify(err));
      return Promise.reject(err);
    }
  }

  async getBool(key: string, options: SharedPreferencesPigeonOptions): Promise<boolean | null> {
    try {
      if (this.plugin.preferences == null) {
        return null;
      }
      const value = await this.plugin.preferences.get(key, null) as ExtendedPreferenceValue;
      return typeof value === 'boolean' ? value : null;
    } catch (err) {
      Log.w(TAG, "Failed to getBool: " + JSON.stringify(err));
      return Promise.reject(err);
    }
  }

  async getDouble(key: string, options: SharedPreferencesPigeonOptions): Promise<number | null> {
    try {
      if (this.plugin.preferences == null) {
        return null;
      }
      const value = await this.plugin.preferences.get(key, null) as ExtendedPreferenceValue;
      if (typeof value === 'number') {
        return value;
      } else if (typeof value === 'bigint') {
        return Number(value);
      }
      return null;
    } catch (err) {
      Log.w(TAG, "Failed to getDouble: " + JSON.stringify(err));
      return Promise.reject(err);
    }
  }

  async getInt(key: string, options: SharedPreferencesPigeonOptions): Promise<bigint | null> {
    try {
      if (this.plugin.preferences == null) {
        return null;
      }
      const value = await this.plugin.preferences.get(key, BigInt(0)) as ExtendedPreferenceValue;
      if (typeof value ==='bigint' || typeof value === 'number'){
        return BigInt(value);
      }
      return null;
    } catch (err) {
      Log.w(TAG, "Failed to getInt: " + JSON.stringify(err));
      return Promise.reject(err);
    }
  }

  async getPlatformEncodedStringList(key: string, options: SharedPreferencesPigeonOptions): Promise<Array<string> | null> {
    try {
      if (this.plugin.preferences == null) {
        return null;
      }
      const value = await this.plugin.preferences.get(key, null) as ExtendedPreferenceValue;
      if (typeof value === 'string' && value.startsWith(LIST_IDENTIFIER)) {
        const decoded: string[] = this.plugin.listEncoder.decode(value.substring(LIST_IDENTIFIER.length));
        return decoded;
      }
      return null;
    } catch (err) {
      Log.w(TAG, "Failed to getPlatformEncodedStringList: " + JSON.stringify(err));
      return Promise.reject(err);
    }
  }

  async getStringList(key: string, options: SharedPreferencesPigeonOptions): Promise<StringListResult | null> {
    try {
      const list = await this.getPlatformEncodedStringList(key, options);
      if (list != null) {
        return new StringListResult(JSON.stringify(list), StringListLookupResultType.jsonEncoded);
      }
      return null;
    } catch (err) {
      Log.w(TAG, "Failed to getStringList: " + JSON.stringify(err));
      return Promise.reject(err);
    }
  }

  async clear(allowList: Array<string> | null, options: SharedPreferencesPigeonOptions): Promise<void> {
    try {
      if (this.plugin.preferences == null) {
        return Promise.reject(new Error("Preferences not initialized"));
      }
      const allData = await this.plugin.preferences.getAll() as Record<string, ExtendedPreferenceValue>;
      const allKeys = Object.keys(allData);
      const deletePromises: Promise<void>[] = [];
      for (let key of allKeys) {
        if (allowList == null || allowList.indexOf(key) != -1) {
          deletePromises.push(new Promise<void>((resolve, reject) => {
            this.plugin.preferences?.delete(key, (err: ESObject) => {
              if (err) {
                reject(err);
              } else {
                resolve();
              }
            });
          }));
        }
      }
      await Promise.all(deletePromises);
      return this.plugin.preferences.flush();
    } catch (err) {
      Log.w(TAG, "Failed to clear: " + JSON.stringify(err));
      return Promise.reject(err);
    }
  }

  async getAll(allowList: Array<string> | null, options: SharedPreferencesPigeonOptions): Promise<Map<string, Object>> {
    try {
      if (this.plugin.preferences == null) {
        return new Map<string, Object>();
      }
      const allData = await this.plugin.preferences.getAll() as Record<string, ExtendedPreferenceValue>;
      const result = new Map<string, Object>();
      Object.keys(allData).forEach((key: string) => {
        const value = allData[key];
        if (allowList == null || allowList.indexOf(key) != -1) {
          result.set(key, this.plugin.transformPref(value));
        }
      });
      return result;
    } catch (err) {
      Log.w(TAG, "Failed to getAll: " + JSON.stringify(err));
      return Promise.reject(err);
    }
  }

  async getKeys(allowList: Array<string> | null, options: SharedPreferencesPigeonOptions): Promise<Array<string>> {
    try {
      if (this.plugin.preferences == null) {
        return [];
      }
      const allData = await this.plugin.preferences.getAll() as Record<string, ExtendedPreferenceValue>;
      const allKeys = Object.keys(allData);
      return allKeys.filter((key: string) => allowList == null || allowList.indexOf(key) != -1);
    } catch (err) {
      Log.w(TAG, "Failed to getKeys: " + JSON.stringify(err));
      return Promise.reject(err);
    }
  }

  // Async setter methods
  async setBool(key: string, value: boolean, options: SharedPreferencesPigeonOptions): Promise<void> {
    return this.plugin.setBool(key, value);
  }

  async setString(key: string, value: string, options: SharedPreferencesPigeonOptions): Promise<void> {
    return this.plugin.setString(key, value);
  }

  async setInt(key: string, value: bigint, options: SharedPreferencesPigeonOptions): Promise<void> {
    return this.plugin.setInt(key, value);
  }

  async setDouble(key: string, value: number, options: SharedPreferencesPigeonOptions): Promise<void> {
    return this.plugin.setDouble(key, value);
  }

  async setEncodedStringList(key: string, value: string, options: SharedPreferencesPigeonOptions): Promise<void> {
    try {
      if (this.plugin.preferences == null) {
        return Promise.reject(new Error("Preferences not initialized"));
      }
      return this.plugin.setEncodedStringList(key, value);
    } catch (err) {
      Log.w(TAG, "Failed to setEncodedStringList: " + JSON.stringify(err));
      return Promise.reject(err);
    }
  }

  async setDeprecatedStringList(key: string, value: Array<string>, options: SharedPreferencesPigeonOptions): Promise<void> {
    return this.plugin.setDeprecatedStringList(key, value);
  }
}

// Setup function implementation
export function setup(binaryMessenger: BinaryMessenger, api: SharedPreferencesApi | null): void {
  {
    const channel = new BasicMessageChannel<Object>(binaryMessenger, "dev.flutter.pigeon.shared_preferences_ohos.SharedPreferencesApi.remove", api?.getCodec() ?? new StandardMessageCodec());
    if (api != null) {
      channel.setMessageHandler({
        onMessage(message: Object, reply: Reply<Object>): void {
          const args = message as Array<Object>;
          const keyArg = args[0] as string;
          let wrapped: Array<Object>;
          try {
            const result = api.remove(keyArg);
            wrapped = [result];
          } catch (exception) {
            wrapped = wrapError(exception as Error);
          }
          reply.reply(wrapped);
        }
      });
    } else {
      channel.setMessageHandler(null);
    }
  }
  
  // setBool
  {
    const channel = new BasicMessageChannel<Object>(binaryMessenger, "dev.flutter.pigeon.shared_preferences_ohos.SharedPreferencesApi.setBool", api?.getCodec() ?? new StandardMessageCodec());
    if (api != null) {
      channel.setMessageHandler({
        onMessage(message: Object, reply: Reply<Object>): void {
          const args = message as Array<Object>;
          const keyArg = args[0] as string;
          const valueArg = args[1] as boolean;
          let wrapped: Array<Object> = [];
          
          api.setBool(keyArg, valueArg).then(() => {
            wrapped = [true];
            reply.reply(wrapped);
          }).catch((err: Error) => {
            const errs = wrapError(err);
            reply.reply(errs);
          });
        }
      });
    } else {
      channel.setMessageHandler(null);
    }
  }
  
  // setString
  {
    const channel = new BasicMessageChannel<Object>(binaryMessenger, "dev.flutter.pigeon.shared_preferences_ohos.SharedPreferencesApi.setString", api?.getCodec() ?? new StandardMessageCodec());
    if (api != null) {
      channel.setMessageHandler({
        onMessage(message: Object, reply: Reply<Object>): void {
          const args = message as Array<Object>;
          const keyArg = args[0] as string;
          const valueArg = args[1] as string;
          let wrapped: Array<Object> = [];
          
          api.setString(keyArg, valueArg).then(() => {
            wrapped = [true];
            reply.reply(wrapped);
          }).catch((err: Error) => {
            const errs = wrapError(err);
            reply.reply(errs);
          });
        }
      });
    } else {
      channel.setMessageHandler(null);
    }
  }
  
  // setInt
  {
    const channel = new BasicMessageChannel<Object>(binaryMessenger, "dev.flutter.pigeon.shared_preferences_ohos.SharedPreferencesApi.setInt", api?.getCodec() ?? new StandardMessageCodec());
    if (api != null) {
      channel.setMessageHandler({
        onMessage(message: Object, reply: Reply<Object>): void {
          const args = message as Array<Object>;
          const keyArg = args[0] as string;
          const valueArg = BigInt(args[1] as bigint);
          let wrapped: Array<Object> = [];
          
          api.setInt(keyArg, valueArg).then(() => {
            wrapped = [true];
            reply.reply(wrapped);
          }).catch((err: Error) => {
            const errs = wrapError(err);
            reply.reply(errs);
          });
        }
      });
    } else {
      channel.setMessageHandler(null);
    }
  }
  
  // setDouble
  {
    const channel = new BasicMessageChannel<Object>(binaryMessenger, "dev.flutter.pigeon.shared_preferences_ohos.SharedPreferencesApi.setDouble", api?.getCodec() ?? new StandardMessageCodec());
    if (api != null) {
      channel.setMessageHandler({
        onMessage(message: Object, reply: Reply<Object>): void {
          const args = message as Array<Object>;
          const keyArg = args[0] as string;
          const valueArg = args[1] as number;
          let wrapped: Array<Object> = [];
          
          api.setDouble(keyArg, valueArg).then(() => {
            wrapped = [true];
            reply.reply(wrapped);
          }).catch((err: Error) => {
            const errs = wrapError(err);
            reply.reply(errs);
          });
        }
      });
    } else {
      channel.setMessageHandler(null);
    }
  }
  
  // setEncodedStringList
  {
    const channel = new BasicMessageChannel<Object>(binaryMessenger, "dev.flutter.pigeon.shared_preferences_ohos.SharedPreferencesApi.setEncodedStringList", api?.getCodec() ?? new StandardMessageCodec());
    if (api != null) {
      channel.setMessageHandler({
        onMessage(message: Object, reply: Reply<Object>): void {
          const args = message as Array<Object>;
          const keyArg = args[0] as string;
          const valueArg = args[1] as string;
          let wrapped: Array<Object> = [];
          
          api.setEncodedStringList(keyArg, valueArg).then(() => {
            wrapped = [true];
            reply.reply(wrapped);
          }).catch((err: Error) => {
            const errs = wrapError(err);
            reply.reply(errs);
          });
        }
      });
    } else {
      channel.setMessageHandler(null);
    }
  }

  // setDeprecatedStringList
  {
    const channel = new BasicMessageChannel<Object>(binaryMessenger, "dev.flutter.pigeon.shared_preferences_ohos.SharedPreferencesApi.setDeprecatedStringList", api?.getCodec() ?? new StandardMessageCodec());
    if (api != null) {
      channel.setMessageHandler({
        onMessage(message: Object, reply: Reply<Object>): void {
          const args = message as Array<Object>;
          const keyArg = args[0] as string;
          const valueArg = args[1] as Array<string>;
          let wrapped: Array<Object> = [];
          
          api.setDeprecatedStringList(keyArg, valueArg).then(() => {
            wrapped = [true];
            reply.reply(wrapped);
          }).catch((err: Error) => {
            const errs = wrapError(err);
            reply.reply(errs);
          });
        }
      });
    } else {
      channel.setMessageHandler(null);
    }
  }
  
  // clear
  {
    const channel = new BasicMessageChannel<Object>(binaryMessenger, "dev.flutter.pigeon.shared_preferences_ohos.SharedPreferencesApi.clear", api?.getCodec() ?? new StandardMessageCodec());
    if (api != null) {
      channel.setMessageHandler({
        onMessage(message: Object, reply: Reply<Object>): void {
          const args = message as Array<Object>;
          const prefixArg = args[0] as string;
          const allowListArg = args[1] as Array<string>;
          let wrapped: Array<Object> = [];
          
          api.clear(prefixArg, allowListArg).then(() => {
            wrapped = [true];
            reply.reply(wrapped);
          }).catch((err: Error) => {
            const errs = wrapError(err);
            reply.reply(errs);
          });
        }
      });
    } else {
      channel.setMessageHandler(null);
    }
  }
  
  // getAll
  {
    const channel = new BasicMessageChannel<Object>(binaryMessenger, "dev.flutter.pigeon.shared_preferences_ohos.SharedPreferencesApi.getAll", api?.getCodec() ?? new StandardMessageCodec());
    if (api != null) {
      channel.setMessageHandler({
        onMessage(message: Object, reply: Reply<Object>): void {
          const args = message as Array<Object>;
          const prefixArg = args[0] as string;
          const allowListArg = args[1] as Array<string>;
          let wrapped: Array<Object>;
          
          api.getAll(prefixArg, allowListArg).then((result) => {
            wrapped = [result];
            reply.reply(wrapped);
          }).catch((err: Error) => {
            const errs = wrapError(err);
            reply.reply(errs);
          });
        }
      });
    } else {
      channel.setMessageHandler(null);
    }
  }
}

// Main plugin class
export default class SharedPreferencesOhosPlugin implements FlutterPlugin, SharedPreferencesApi {
  private context: common.UIAbilityContext | null = null;
  preferences: data_preferences.Preferences | null = null;
  listEncoder: ListEncoderImpl = new ListEncoderImpl();
  private asyncApiImpl: SharedPreferencesAsyncApiImpl;

  constructor() {
    this.asyncApiImpl = new SharedPreferencesAsyncApiImpl(this);
  }

  getUniqueClassName(): string {
    return "SharedPreferencesOhosPlugin";
  }

  onAttachedToEngine(binding: FlutterPluginBinding): void {
    this.context = binding.getApplicationContext() as common.UIAbilityContext;
    
    // Register sync API first (doesn't depend on preferences initialization)
    setup(binding.getBinaryMessenger(), this);
    
    // Initialize preferences and register async API after initialization
    data_preferences.getPreferences(this.context, PREFERENCES_NAME).then((preferences) => {
      this.preferences = preferences;
      Log.i(TAG, 'Preferences initialized successfully');
      
      // Register async API only after preferences are initialized
      setupSharedPreferencesAsyncApi(binding.getBinaryMessenger(), this.asyncApiImpl, '.data_store');
      Log.i(TAG, 'Async API registered successfully');
    }).catch((err: Error) => {
      Log.e(TAG, 'Failed to get preferences.' + err.message);
      // Even if preferences initialization fails, we should still register the async API
      // so that it can properly return errors instead of hanging
      setupSharedPreferencesAsyncApi(binding.getBinaryMessenger(), this.asyncApiImpl, '.data_store');
    });
  }

  onDetachedFromEngine(binding: FlutterPluginBinding): void {
    // Unregister APIs
  // Unregister APIs
    setup(binding.getBinaryMessenger(), null);
    setupSharedPreferencesAsyncApi(binding.getBinaryMessenger(), null, '.data_store');
    this.preferences = null;
    this.context = null;
  }

  // Implement setup method required by SharedPreferencesApi interface
  setup(messenger: BinaryMessenger, api: SharedPreferencesApi): void {
    setup(messenger, api);
  }

  // SharedPreferencesApi sync methods implementation
  remove(key: string): boolean {
    try {
      if (this.preferences == null) {
        return false;
      }
      this.preferences.deleteSync(key);
      this.preferences.flushSync();
      return true;
    } catch (err) {
      Log.e(TAG, "Failed to delete. " + JSON.stringify(err));
      return false;
    }
  }

  async setString(key: string, value: string): Promise<void> {
    if (value.startsWith(LIST_IDENTIFIER)) {
      return Promise.reject(new Error(
        "StorageError: This string cannot be stored as it clashes with special identifier prefixes"));
    }
    return this.put(key, value);
  }

  async setInt(key: string, value: bigint): Promise<void> {
    return this.put(key, value);
  }

  put(key: string, value: ESObject): Promise<void> {
    try {
      if (this.preferences == null) {
        return Promise.reject(new Error("Preferences not initialized"));
      } else {
        this.preferences.put(key, value);
        return this.preferences.flush();
      }
    } catch (err) {
      Log.w(TAG, "Failed to put value. " + JSON.stringify(err));
      return Promise.reject(err);
    }
  }

  async setDouble(key: string, value: number): Promise<void> {
    return this.put(key, value);
  }

  async setBool(key: string, value: boolean): Promise<void> {
    return this.put(key, value);
  }

  async setEncodedStringList(key: string, value: string): Promise<void> {
    return this.put(key, value);
  }

  async setDeprecatedStringList(key: string, value: string[]): Promise<void> {
    Log.w(TAG, "setStringList :" + value);
    Log.w(TAG, "setStringList encoded:" + (LIST_IDENTIFIER + this.listEncoder.encode(value)));
    return this.put(key, LIST_IDENTIFIER + this.listEncoder.encode(value));
  }

  async clear(prefix: string, allowList: string[]): Promise<void> {
    try {
      if (this.preferences == null) {
        return Promise.reject(new Error("Preferences not initialized"));
      }
      const allData = await this.preferences.getAll() as Record<string, ExtendedPreferenceValue>;
      const allKeys = Object.keys(allData);
      const deletePromises: Promise<void>[] = [];
      for (let key of allKeys) {
        if (key.startsWith(prefix) && (allowList == null || allowList.indexOf(key) != -1)) {
          deletePromises.push(new Promise<void>((resolve, reject) => {
            this.preferences?.delete(key, (err: ESObject) => {
              if (err) {
                reject(err);
              } else {
                resolve();
              }
            });
          }));
        }
      }
      await Promise.all(deletePromises);
      return this.preferences.flush();
    } catch (err) {
      Log.w(TAG, "Failed to clear." + JSON.stringify(err));
      return Promise.reject(err);
    }
  }

  transformPref(value: ExtendedPreferenceValue): ESObject {
    if (typeof value === 'string' && value.startsWith(LIST_IDENTIFIER)) {
      try {
        const decoded: string[] = this.listEncoder.decode(value.substring(LIST_IDENTIFIER.length));
        return decoded;
      } catch (err) {
        Log.w(TAG, "Failed to decode list: " + JSON.stringify(err));
        return value;
      }
    }
    if (typeof value === 'bigint') {
      return BigInt(value);
    }
    if (typeof value === 'object' && value !== null) {
      return value;
    }
    return value;
  }

  filterData(value: [string, ExtendedPreferenceValue], prefix: string, allowList: string[]): Map<string, Object> {
    const result = new Map<string, Object>();
    const key = value[0];
    const val = value[1];
    if (key.startsWith(prefix) && (allowList == null || allowList.indexOf(key) != -1)) {
      result.set(key, this.transformPref(val));
    }
    return result;
  }

  async getAll(prefix: string, allowList: string[]): Promise<Map<string, Object>> {
    try {
      if (this.preferences == null) {
        return new Map<string, Object>();
      }
      const allData = await this.preferences.getAll() as Record<string, ExtendedPreferenceValue>;
      const result = new Map<string, Object>();
      Object.entries(allData).forEach((entry: [string, ExtendedPreferenceValue]) => {
        const filteredData = this.filterData(entry, prefix, allowList);
        filteredData.forEach((value, key) => {
          result.set(key, value);
        });
      });
      return result;
    } catch (err) {
      Log.w(TAG, "Failed to getAll." + JSON.stringify(err));
      return Promise.reject(err);
    }
  }

  getCodec(): MessageCodec<Object> {
    return new StandardMessageCodec();
  }
}
