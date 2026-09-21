package org.nslabs.ir_blaster

import android.app.Application
import android.hardware.usb.UsbManager
import android.media.*
import android.os.SystemClock
import org.junit.Assert.*
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.nslabs.ir_blaster.audio.AudioIrTransmitter
import org.nslabs.ir_blaster.audio.AudioPcmBuilder
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config
import org.robolectric.annotation.Implementation
import org.robolectric.annotation.Implements
import org.robolectric.shadows.AudioDeviceInfoBuilder
import org.robolectric.shadows.ShadowSystemClock
import java.time.Duration
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [28], application = Application::class, shadows = [RecordingAudioTrack::class])
class AutomationAudioTest {
    private val context get() = RuntimeEnvironment.getApplication()
    private val manager get() = context.getSystemService(AudioManager::class.java)
    private val pattern = intArrayOf(9000, 4500, 560)

    @Before fun reset() {
        RecordingAudioTrack.samples = shortArrayOf()
        RecordingAudioTrack.channels = 0
        RecordingAudioTrack.releases = 0
        RecordingAudioTrack.acceptRoute = true
        RecordingAudioTrack.partialWrite = false
        RecordingAudioTrack.stalled = false
        RecordingAudioTrack.onPlay = null
        RecordingAudioTrack.started = CountDownLatch(1)
        RecordingAudioTrack.finish = CountDownLatch(0)
        manager.setStreamVolume(AudioManager.STREAM_MUSIC, 8, 0)
        shadowOf(manager).setIsStreamMute(AudioManager.STREAM_MUSIC, false)
        attach(AudioDeviceInfo.TYPE_USB_DEVICE)
    }

    private fun attach(type: Int): AudioDeviceInfo {
        val device = AudioDeviceInfoBuilder.newBuilder().setType(type).build()
        shadowOf(manager).setOutputDevices(listOf(device))
        return device
    }

    private fun send(emitter: String = "AUDIO_1_LED") = AutomationTransmitter(context).transmit(
        AutomationIrRequest.parse(38000, pattern, emitter), SystemClock.uptimeMillis() + 7000)

    @Test fun bothModesUseTheExistingPcmBuilderAndReleaseAfterCompletion() {
        for (mode in listOf<Short>(1, 2)) {
            assertEquals(AutomationResult.SENT, send("AUDIO_${mode}_LED"))
            assertEquals(mode.toInt(), RecordingAudioTrack.channels)
            assertArrayEquals(AudioPcmBuilder(38000, pattern, mode).pcm, RecordingAudioTrack.samples)
        }
        assertEquals(2, RecordingAudioTrack.releases)
        assertNull(shadowOf(context).nextStartedActivity)
    }

    @Test fun knownAb13xAdapterKeepsItsExistingStereoMirror() {
        val usb = context.getSystemService(UsbManager::class.java)
        shadowOf(usb).addOrUpdateUsbDevice(usbDevice("/dev/bus/usb/001/002", 31, 2849), false)
        assertEquals(AutomationResult.SENT, send())
        assertEquals(2, RecordingAudioTrack.channels)
        val mono = AudioPcmBuilder(38000, pattern, 1).pcm
        val expected = ShortArray(mono.size * 2) { mono[it / 2] }
        assertArrayEquals(expected, RecordingAudioTrack.samples)
    }

    @Test fun missingAmbiguousSpeakerAndBluetoothOutputsAreRejected() {
        for (type in listOf(AudioDeviceInfo.TYPE_BUILTIN_SPEAKER, AudioDeviceInfo.TYPE_BLUETOOTH_A2DP)) {
            attach(type)
            assertEquals(AutomationResult.NO_AUDIO_OUTPUT, send())
        }
        shadowOf(manager).setOutputDevices(emptyList())
        assertEquals(AutomationResult.NO_AUDIO_OUTPUT, send())
        shadowOf(manager).setOutputDevices(listOf(
            AudioDeviceInfoBuilder.newBuilder().setType(AudioDeviceInfo.TYPE_USB_DEVICE).build(),
            AudioDeviceInfoBuilder.newBuilder().setType(AudioDeviceInfo.TYPE_WIRED_HEADPHONES).build()))
        assertEquals(AutomationResult.AMBIGUOUS_DEVICE, send())
        assertTrue(RecordingAudioTrack.samples.isEmpty())
    }

    @Test fun mutedAndZeroMediaVolumeDoNotReportSuccessOrChangeVolume() {
        manager.setStreamVolume(AudioManager.STREAM_MUSIC, 0, 0)
        assertEquals(AutomationResult.AUDIO_MUTED, send())
        assertEquals(0, manager.getStreamVolume(AudioManager.STREAM_MUSIC))
        manager.setStreamVolume(AudioManager.STREAM_MUSIC, 8, 0)
        shadowOf(manager).setIsStreamMute(AudioManager.STREAM_MUSIC, true)
        assertEquals(AutomationResult.AUDIO_MUTED, send())
        assertTrue(RecordingAudioTrack.samples.isEmpty())
    }

    @Test fun failuresReleaseAudioAndAllowNextSend() {
        RecordingAudioTrack.acceptRoute = false
        assertEquals(AutomationResult.TRANSMIT_FAILED, send())
        RecordingAudioTrack.acceptRoute = true
        RecordingAudioTrack.partialWrite = true
        assertEquals(AutomationResult.TRANSMIT_FAILED, send())
        RecordingAudioTrack.partialWrite = false
        RecordingAudioTrack.stalled = true
        assertEquals(AutomationResult.TRANSMIT_FAILED, send())
        RecordingAudioTrack.stalled = false
        assertEquals(AutomationResult.SENT, send())
        assertEquals(4, RecordingAudioTrack.releases)
    }

    @Test fun automationWaitsForPlaybackAndDoesNotMixWithManualAudio() {
        RecordingAudioTrack.finish = CountDownLatch(1)
        val outcome = arrayOfNulls<AutomationResult>(1)
        val thread = Thread { outcome[0] = send() }.also { it.start() }
        val manual = AudioIrTransmitter(context, 1)
        try {
            assertTrue(RecordingAudioTrack.started.await(3, TimeUnit.SECONDS))
            assertNull(outcome[0])
            assertEquals(0, RecordingAudioTrack.releases)
            assertFalse(manual.transmitRaw(38000, pattern))
        } finally {
            RecordingAudioTrack.finish.countDown()
            thread.join(3000)
            manual.stop()
        }
        assertEquals(AutomationResult.SENT, outcome[0])
        assertEquals(1, RecordingAudioTrack.releases)
    }

    @Test fun manualAudioKeepsItsAsyncBehaviorAndBlocksAutomationUntilStopped() {
        val manual = AudioIrTransmitter(context, 2)
        try {
            RecordingAudioTrack.onPlay = { assertEquals(AutomationResult.BUSY, send()) }
            assertTrue(manual.transmitRaw(38000, pattern))
            RecordingAudioTrack.onPlay = { assertEquals(AutomationResult.BUSY, send()) }
            assertTrue(manual.transmitRaw(38000, pattern))
        } finally {
            manual.stop()
        }
        assertEquals(2, RecordingAudioTrack.releases)
        assertEquals(AutomationResult.SENT, send())
    }
}

@Implements(AudioTrack::class)
class RecordingAudioTrack {
    private var output: AudioDeviceInfo? = null
    private var frames = 0
    @Implementation fun __constructor__(attributes: AudioAttributes, format: AudioFormat, size: Int, mode: Int, session: Int) {
        channels = format.channelCount
        frames = size / (2 * channels)
    }
    @Implementation fun setPreferredDevice(device: AudioDeviceInfo): Boolean { output = device; return acceptRoute }
    @Implementation fun getRoutedDevice() = output
    @Implementation fun setVolume(volume: Float) = 0
    @Implementation fun write(buffer: ShortArray, offset: Int, size: Int): Int {
        samples = buffer.copyOfRange(offset, offset + size)
        return if (partialWrite) size - 1 else size
    }
    @Implementation fun play() {
        started.countDown()
        val callback = onPlay
        onPlay = null
        callback?.invoke()
    }
    @Implementation fun getPlaybackHeadPosition(): Int {
        check(finish.await(5, TimeUnit.SECONDS))
        if (stalled) { ShadowSystemClock.advanceBy(Duration.ofSeconds(4)); return 0 }
        return frames
    }
    @Implementation fun pause() {}
    @Implementation fun flush() {}
    @Implementation fun stop() {}
    @Implementation fun release() { releases++ }
    companion object {
        @Volatile var samples = shortArrayOf()
        @Volatile var channels = 0
        @Volatile var releases = 0
        @Volatile var acceptRoute = true
        @Volatile var partialWrite = false
        @Volatile var stalled = false
        var onPlay: (() -> Unit)? = null
        var started = CountDownLatch(1)
        var finish = CountDownLatch(0)
    }
}
