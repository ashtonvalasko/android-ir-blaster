package org.nslabs.ir_blaster

import android.app.Activity
import android.app.Application
import android.content.BroadcastReceiver
import android.content.Context
import android.content.ComponentName
import android.content.Intent
import android.hardware.ConsumerIrManager
import android.os.Handler
import android.os.Looper
import org.junit.After
import org.junit.Assert.*
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config
import org.robolectric.annotation.Implementation
import org.robolectric.annotation.Implements
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicInteger

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [28], application = Application::class, shadows = [RecordingIrManager::class])
class IrAutomationReceiverTest {
    private val context get() = RuntimeEnvironment.getApplication()

    @Before fun reset() {
        context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE).edit().clear().commit()
        RecordingIrManager.available = true
        RecordingIrManager.fail = false
        RecordingIrManager.pattern = null
        RecordingIrManager.frequency = 0
        RecordingIrManager.mainThread = true
        RecordingIrManager.calls.set(0)
        RecordingIrManager.release = CountDownLatch(0)
        RecordingIrManager.started = CountDownLatch(1)
    }

    @After fun releaseWorker() { RecordingIrManager.release.countDown() }

    private fun enable(value: Boolean = true) {
        context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE).edit()
            .putBoolean(IrAutomationReceiver.PREF_ENABLED, value).commit()
    }

    private fun intent() = Intent(context, IrAutomationReceiver::class.java)
        .setAction(IrAutomationReceiver.ACTION_TRANSMIT)
        .putExtra("frequency", 38000)
        .putExtra("pattern", "9000,4500,560")

    private fun dispatch(intent: Intent = intent()): AtomicInteger {
        val result = AtomicInteger(Int.MIN_VALUE)
        context.sendOrderedBroadcast(intent, null, object : BroadcastReceiver() {
            override fun onReceive(context: Context, intent: Intent) { result.set(resultCode) }
        }, Handler(Looper.getMainLooper()), 0, null, null)
        shadowOf(Looper.getMainLooper()).idle()
        return result
    }

    private fun await(result: AtomicInteger): Int {
        val deadline = System.nanoTime() + TimeUnit.SECONDS.toNanos(5)
        while (result.get() == Int.MIN_VALUE && System.nanoTime() < deadline) {
            shadowOf(Looper.getMainLooper()).idle()
            Thread.sleep(5)
        }
        assertNotEquals("Broadcast did not finish", Int.MIN_VALUE, result.get())
        return result.get()
    }

    @Test fun disabledByDefaultAndAfterOptOut() {
        assertEquals(IrAutomationReceiver.DISABLED, await(dispatch()))
        enable()
        enable(false)
        assertEquals(IrAutomationReceiver.DISABLED, await(dispatch()))
        assertNull(RecordingIrManager.pattern)
    }

    @Test fun unexpectedActionIsIgnoredEvenWithExplicitComponent() {
        enable()
        assertEquals(0, await(dispatch(intent().setAction("other.ACTION"))))
        assertNull(RecordingIrManager.pattern)
    }

    @Test fun invalidExtrasDoNotTransmit() {
        enable()
        assertEquals(IrAutomationReceiver.BAD_REQUEST, await(dispatch(intent().putExtra("pattern", "1,,2"))))
        assertEquals(IrAutomationReceiver.BAD_REQUEST, await(dispatch(intent().putExtra("frequency", true))))
        assertEquals(IrAutomationReceiver.BAD_REQUEST, await(dispatch(intent().putExtra("emitter", "AUTO"))))
        assertEquals(IrAutomationReceiver.BAD_REQUEST, await(dispatch(intent().putExtra("emitter", 1))))
        assertNull(RecordingIrManager.pattern)
    }

    @Test fun externalEmitterRequestsNeverFallBackToInternal() {
        enable()
        assertEquals(AutomationResult.NO_USB_DEVICE.code, await(dispatch(intent().putExtra("emitter", "USB"))))
        assertEquals(AutomationResult.NO_AUDIO_OUTPUT.code, await(dispatch(intent().putExtra("emitter", "AUDIO_1_LED"))))
        assertEquals(AutomationResult.NO_AUDIO_OUTPUT.code, await(dispatch(intent().putExtra("emitter", "AUDIO_2_LED"))))
        assertEquals(0, RecordingIrManager.calls.get())
    }

    @Test fun omittedEmitterIgnoresNormalRemotePreference() {
        enable()
        context.getSharedPreferences("ir_blaster_prefs", Context.MODE_PRIVATE).edit()
            .putString("tx_type", "USB").commit()
        assertEquals(Activity.RESULT_OK, await(dispatch()))
        assertEquals(1, RecordingIrManager.calls.get())
    }

    @Test fun transmitsExactlyOnceOffTheMainThreadWithoutOpeningActivity() {
        enable()
        assertEquals(Activity.RESULT_OK, await(dispatch()))
        assertEquals(38000, RecordingIrManager.frequency)
        assertArrayEquals(intArrayOf(9000, 4500, 560), RecordingIrManager.pattern)
        assertEquals(1, RecordingIrManager.calls.get())
        assertFalse(RecordingIrManager.mainThread)
        assertNull(shadowOf(context).nextStartedActivity)
    }

    @Test fun receiverIsExportedAndPackageTargetedBroadcastResolves() {
        val info = context.packageManager.getReceiverInfo(
            ComponentName(context, IrAutomationReceiver::class.java), 0)
        assertTrue(info.exported)
        enable()
        assertEquals(Activity.RESULT_OK,
            await(dispatch(intent().setComponent(null).setPackage(context.packageName))))
    }

    @Test fun normalBroadcastAlsoTransmits() {
        enable()
        context.sendBroadcast(intent())
        val deadline = System.nanoTime() + TimeUnit.SECONDS.toNanos(5)
        while (RecordingIrManager.pattern == null && System.nanoTime() < deadline) {
            shadowOf(Looper.getMainLooper()).idle()
            Thread.sleep(5)
        }
        assertArrayEquals(intArrayOf(9000, 4500, 560), RecordingIrManager.pattern)
        // Wait for goAsync completion before the next test uses the busy guard.
        var result = await(dispatch())
        while (result == IrAutomationReceiver.BUSY && System.nanoTime() < deadline) {
            result = await(dispatch())
        }
        assertEquals(Activity.RESULT_OK, result)
    }

    @Test fun missingHardwareDoesNotFallBackToActivityUsbOrAudio() {
        enable()
        RecordingIrManager.available = false
        assertEquals(IrAutomationReceiver.NO_IR, await(dispatch()))
        assertNull(RecordingIrManager.pattern)
        assertNull(shadowOf(context).nextStartedActivity)
    }

    @Test fun transmitFailureFinishesAndAllowsNextRequest() {
        enable()
        RecordingIrManager.fail = true
        assertEquals(IrAutomationReceiver.FAILED, await(dispatch()))
        RecordingIrManager.fail = false
        assertEquals(Activity.RESULT_OK, await(dispatch()))
    }

    @Test fun concurrentBroadcastIsRejectedRatherThanQueued() {
        enable()
        RecordingIrManager.release = CountDownLatch(1)
        val first = dispatch()
        assertTrue(RecordingIrManager.started.await(5, TimeUnit.SECONDS))
        try {
            assertEquals(IrAutomationReceiver.BUSY, await(dispatch()))
        } finally {
            RecordingIrManager.release.countDown()
        }
        assertEquals(Activity.RESULT_OK, await(first))
    }
}

@Implements(ConsumerIrManager::class)
class RecordingIrManager {
    // No real consumer_ir Binder service exists in the JVM test environment.
    @Implementation fun __constructor__(context: Context) {}

    @Implementation fun hasIrEmitter() = available

    @Implementation fun transmit(carrierFrequency: Int, durations: IntArray) {
        calls.incrementAndGet()
        started.countDown()
        check(release.await(5, TimeUnit.SECONDS))
        check(!fail) { "Simulated hardware failure" }
        frequency = carrierFrequency
        pattern = durations.copyOf()
        mainThread = Looper.myLooper() == Looper.getMainLooper()
    }

    companion object {
        @Volatile var available = true
        @Volatile var fail = false
        @Volatile var frequency = 0
        @Volatile var pattern: IntArray? = null
        @Volatile var mainThread = true
        val calls = AtomicInteger(0)
        var started = CountDownLatch(1)
        var release = CountDownLatch(0)
    }
}
