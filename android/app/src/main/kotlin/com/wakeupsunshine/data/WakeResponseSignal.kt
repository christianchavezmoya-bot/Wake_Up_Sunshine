package com.wakeupsunshine.data

import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.SharedFlow

data class WakeResponseEvent(val receiverName: String, val action: String)

object WakeResponseSignal {
    private val _signal = MutableSharedFlow<WakeResponseEvent>(extraBufferCapacity = 1)
    val signal: SharedFlow<WakeResponseEvent> = _signal

    fun emit(event: WakeResponseEvent) { _signal.tryEmit(event) }
}
