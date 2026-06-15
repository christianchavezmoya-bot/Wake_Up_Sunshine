package com.wakeupsunshine.data

import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.SharedFlow

object ContactsRefreshSignal {
    private val _signal = MutableSharedFlow<Unit>(extraBufferCapacity = 1)
    val signal: SharedFlow<Unit> = _signal

    fun emit() {
        _signal.tryEmit(Unit)
    }
}
