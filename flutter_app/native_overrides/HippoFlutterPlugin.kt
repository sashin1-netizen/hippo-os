package com.sashin.hippo_os

import org.godotengine.godot.Godot
import org.godotengine.godot.plugin.GodotPlugin
import org.godotengine.godot.plugin.SignalInfo
import org.godotengine.godot.plugin.UsedByGodot

class HippoFlutterPlugin(
    godot: Godot,
    private val statusEmitter: (String) -> Unit,
) : GodotPlugin(godot) {

    companion object {
        val CAMERA_MODE_REQUESTED = SignalInfo("camera_mode_requested", String::class.java)
        val DEVICE_TIME_SYNCED = SignalInfo("device_time_synced", String::class.java)
        val ANIMAL_ACTION_REQUESTED = SignalInfo("animal_action_requested", String::class.java)
        val CUSTOMIZATION_REQUESTED = SignalInfo("customization_requested", String::class.java)
    }

    override fun getPluginName() = "HippoFlutterBridge"

    override fun getPluginSignals() = setOf(
        CAMERA_MODE_REQUESTED,
        DEVICE_TIME_SYNCED,
        ANIMAL_ACTION_REQUESTED,
        CUSTOMIZATION_REQUESTED,
    )

    fun requestCameraMode(mode: String) {
        emitSignal(CAMERA_MODE_REQUESTED.name, mode)
    }

    fun syncDeviceTime(json: String) {
        emitSignal(DEVICE_TIME_SYNCED.name, json)
    }

    fun requestAnimalAction(action: String) {
        emitSignal(ANIMAL_ACTION_REQUESTED.name, action)
    }

    fun requestCustomization(json: String) {
        emitSignal(CUSTOMIZATION_REQUESTED.name, json)
    }

    @UsedByGodot
    fun pushStatus(json: String) {
        runOnHostThread { statusEmitter(json) }
    }
}
