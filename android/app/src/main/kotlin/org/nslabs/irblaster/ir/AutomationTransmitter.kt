package org.nslabs.ir_blaster

import android.app.Activity
import android.content.Context
import android.hardware.ConsumerIrManager
import android.hardware.usb.UsbManager
import android.media.AudioDeviceInfo
import android.media.AudioManager
import android.os.SystemClock
import org.nslabs.ir_blaster.audio.AudioIrTransmitter

internal enum class AutomationResult(val code: Int) {
    SENT(Activity.RESULT_OK),
    BUSY(IrAutomationReceiver.BUSY),
    NO_IR(IrAutomationReceiver.NO_IR),
    TRANSMIT_FAILED(IrAutomationReceiver.FAILED),
    NO_USB_DEVICE(6), USB_PERMISSION_REQUIRED(7), USB_OPEN_FAILED(8),
    NO_AUDIO_OUTPUT(9), AUDIO_MUTED(10), AMBIGUOUS_DEVICE(11),
}

internal class AutomationTransmitter(private val context: Context) {
    fun transmit(request: AutomationIrRequest, deadlineMs: Long): AutomationResult {
        if (SystemClock.uptimeMillis() >= deadlineMs) return AutomationResult.TRANSMIT_FAILED
        return when (request.emitter) {
            AutomationEmitter.INTERNAL -> {
                val manager = context.getSystemService(ConsumerIrManager::class.java)
                if (manager == null || !manager.hasIrEmitter()) AutomationResult.NO_IR
                else result(InternalIrTransmitter(manager).transmitRaw(request.frequency, request.pattern))
            }
            AutomationEmitter.USB -> transmitUsb(request, deadlineMs)
            AutomationEmitter.AUDIO_1_LED, AutomationEmitter.AUDIO_2_LED -> transmitAudio(request, deadlineMs)
        }
    }

    private fun transmitUsb(request: AutomationIrRequest, deadlineMs: Long): AutomationResult {
        val manager = context.getSystemService(UsbManager::class.java) ?: return AutomationResult.NO_USB_DEVICE
        val discovery = UsbDiscoveryManager(context, manager)
        val devices = discovery.scanSupported()
        if (devices.isEmpty()) return AutomationResult.NO_USB_DEVICE
        if (devices.size != 1) return AutomationResult.AMBIGUOUS_DEVICE
        val device = devices.single()
        if (!manager.hasPermission(device)) return AutomationResult.USB_PERMISSION_REQUIRED
        val borrowed = UsbDeviceAccess.borrow(device.deviceName)
        if (borrowed != null) {
            borrowed.use { return result(it.transmit(request.frequency, request.pattern, deadlineMs)) }
        }
        if (UsbDeviceAccess.isOwned(device.deviceName)) return AutomationResult.BUSY
        val tx = discovery.openTransmitter(device, deadlineMs)
            ?: return if (UsbDeviceAccess.isOwned(device.deviceName)) AutomationResult.BUSY
                else AutomationResult.USB_OPEN_FAILED
        try {
            val handle = tx.borrowForAutomation() ?: return AutomationResult.BUSY
            handle.use { return result(it.transmit(request.frequency, request.pattern, deadlineMs)) }
        } finally {
            tx.close()
        }
    }

    private fun transmitAudio(request: AutomationIrRequest, deadlineMs: Long): AutomationResult {
        val manager = context.getSystemService(AudioManager::class.java) ?: return AutomationResult.NO_AUDIO_OUTPUT
        val outputs = manager.getDevices(AudioManager.GET_DEVICES_OUTPUTS).filter {
            it.type == AudioDeviceInfo.TYPE_USB_DEVICE || it.type == AudioDeviceInfo.TYPE_USB_HEADSET ||
                it.type == AudioDeviceInfo.TYPE_WIRED_HEADSET || it.type == AudioDeviceInfo.TYPE_WIRED_HEADPHONES ||
                it.type == AudioDeviceInfo.TYPE_LINE_ANALOG
        }
        if (outputs.isEmpty()) return AutomationResult.NO_AUDIO_OUTPUT
        if (outputs.size != 1) return AutomationResult.AMBIGUOUS_DEVICE
        if (manager.isStreamMute(AudioManager.STREAM_MUSIC) || manager.getStreamVolume(AudioManager.STREAM_MUSIC) == 0) {
            return AutomationResult.AUDIO_MUTED
        }
        val mode: Short = if (request.emitter == AutomationEmitter.AUDIO_1_LED) 1 else 2
        val tx = AudioIrTransmitter(context.applicationContext, mode)
        return try {
            result(tx.transmitRawAndWait(request.frequency, request.pattern, outputs.single(), deadlineMs))
        } finally {
            tx.stop()
        }
    }

    private fun result(sent: Boolean?): AutomationResult = when (sent) {
        true -> AutomationResult.SENT
        false -> AutomationResult.TRANSMIT_FAILED
        null -> AutomationResult.BUSY
    }
}
