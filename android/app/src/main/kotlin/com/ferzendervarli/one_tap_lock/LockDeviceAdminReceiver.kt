package com.ferzendervarli.one_tap_lock

import android.app.admin.DeviceAdminReceiver

/**
 * Empty Device Admin receiver. Its mere registration (plus the `force-lock`
 * policy in res/xml/device_admin.xml) is what allows DevicePolicyManager.lockNow().
 */
class LockDeviceAdminReceiver : DeviceAdminReceiver()
