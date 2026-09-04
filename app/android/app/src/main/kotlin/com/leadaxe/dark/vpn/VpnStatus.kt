package com.leadaxe.dark.vpn

enum class VpnStatus {
    Stopped,
    Starting,
    Started,
    Stopping;

    val nativeName: String get() = name
}
