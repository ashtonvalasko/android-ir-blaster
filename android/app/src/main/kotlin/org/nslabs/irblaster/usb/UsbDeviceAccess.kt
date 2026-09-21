package org.nslabs.ir_blaster

// A learning session must never claim a dongle that is transmitting, or vice versa.
internal object UsbDeviceAccess {
    private val owners = mutableMapOf<String, Lease>()

    @Synchronized fun reserve(deviceName: String): Lease? {
        if (owners.containsKey(deviceName)) return null
        return Lease(deviceName).also { owners[deviceName] = it }
    }

    @Synchronized fun isOwned(deviceName: String) = owners.containsKey(deviceName)

    fun borrow(deviceName: String): UsbIrTransmitter.AutomationLease? {
        val supplier = synchronized(this) { owners[deviceName]?.borrow }
        return supplier?.invoke()
    }

    class Lease internal constructor(private val deviceName: String) : AutoCloseable {
        @Volatile var borrow: (() -> UsbIrTransmitter.AutomationLease?)? = null

        override fun close() {
            synchronized(UsbDeviceAccess) {
                if (owners[deviceName] === this) owners.remove(deviceName)
            }
        }
    }
}
