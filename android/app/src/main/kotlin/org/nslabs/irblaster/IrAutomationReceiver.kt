package org.nslabs.ir_blaster

import android.app.Activity
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.hardware.ConsumerIrManager
import android.util.Log
import java.util.concurrent.atomic.AtomicBoolean

class IrAutomationReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != ACTION_TRANSMIT) return
        val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        if (!prefs.getBoolean(PREF_ENABLED, false)) {
            reply(DISABLED, "DISABLED")
            return
        }
        val request = try {
            @Suppress("DEPRECATION")
            AutomationIrRequest.parse(intent.extras?.get("frequency"), intent.extras?.get("pattern"))
        } catch (e: RuntimeException) {
            reply(BAD_REQUEST, "BAD_REQUEST")
            return
        }
        // No unbounded work queue: automation must wait before sending again.
        if (!busy.compareAndSet(false, true)) {
            reply(BUSY, "BUSY")
            return
        }
        val ordered = isOrderedBroadcast
        val pending = goAsync()
        fun complete(code: Int, message: String) {
            Log.i(TAG, message)
            if (ordered) pending.setResult(code, message, null)
        }
        try {
            Thread({
                try {
                    if (!prefs.getBoolean(PREF_ENABLED, false)) {
                        complete(DISABLED, "DISABLED")
                    } else {
                        val manager = context.getSystemService(ConsumerIrManager::class.java)
                        if (manager == null || !manager.hasIrEmitter()) {
                            complete(NO_IR, "NO_IR")
                        } else if (InternalIrTransmitter(manager).transmitRaw(request.frequency, request.pattern)) {
                            complete(Activity.RESULT_OK, "SENT")
                        } else {
                            complete(FAILED, "TRANSMIT_FAILED")
                        }
                    }
                } catch (e: RuntimeException) {
                    complete(FAILED, "TRANSMIT_FAILED")
                } finally {
                    busy.set(false)
                    pending.finish()
                }
            }, "ir-automation").start()
        } catch (e: RuntimeException) {
            busy.set(false)
            complete(FAILED, "TRANSMIT_FAILED")
            pending.finish()
        }
    }

    private fun reply(code: Int, message: String) {
        Log.i(TAG, message)
        if (isOrderedBroadcast) setResult(code, message, null)
    }

    companion object {
        const val ACTION_TRANSMIT = "org.irblaster.TRANSMIT"
        const val PREF_ENABLED = "flutter.automation_broadcasts_enabled_v1"
        const val DISABLED = 1
        const val BAD_REQUEST = 2
        const val BUSY = 3
        const val NO_IR = 4
        const val FAILED = 5
        private const val TAG = "IrAutomation"
        private val busy = AtomicBoolean(false)
    }
}
