package com.sashin.hippo_os

import android.content.Context
import android.view.View
import android.widget.FrameLayout
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory
import org.godotengine.godot.Godot
import org.godotengine.godot.GodotFragment
import org.godotengine.godot.GodotHost
import org.godotengine.godot.plugin.GodotPlugin
import org.json.JSONObject

class MainActivity : FlutterFragmentActivity(), GodotHost {
    companion object {
        private const val GODOT_FRAGMENT_TAG = "hippo_os_godot_fragment"
        private const val GODOT_VIEW_TYPE = "hippo_os/godot_view"
        private const val CONTROL_CHANNEL = "hippo_os/control"
        private const val EVENT_CHANNEL = "hippo_os/events"
    }

    private var godotFragment: GodotFragment? = null
    private var bridgePlugin: HippoFlutterPlugin? = null
    private var eventSink: EventChannel.EventSink? = null
    private var pendingCameraMode: String? = null
    private var pendingTimeJson: String? = null
    private val pendingActions = ArrayDeque<String>()

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        flutterEngine.platformViewsController.registry.registerViewFactory(
            GODOT_VIEW_TYPE,
            GodotPlatformViewFactory(this),
        )

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CONTROL_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "setCameraMode" -> {
                        val mode = call.arguments?.toString() ?: "cinematic"
                        pendingCameraMode = mode
                        bridgePlugin?.requestCameraMode(mode)
                        result.success(true)
                    }
                    "syncDeviceTime" -> {
                        @Suppress("UNCHECKED_CAST")
                        val payload = call.arguments as? Map<String, Any?> ?: emptyMap()
                        val json = JSONObject(payload).toString()
                        pendingTimeJson = json
                        bridgePlugin?.syncDeviceTime(json)
                        result.success(true)
                    }
                    "animalAction" -> {
                        val action = call.arguments?.toString() ?: ""
                        if (bridgePlugin == null) {
                            pendingActions.addLast(action)
                        } else {
                            bridgePlugin?.requestAnimalAction(action)
                        }
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    eventSink = events
                }

                override fun onCancel(arguments: Any?) {
                    eventSink = null
                }
            })
    }

    internal fun attachGodotFragment(container: FrameLayout) {
        if (container.id == View.NO_ID) container.id = View.generateViewId()

        val existing = supportFragmentManager.findFragmentByTag(GODOT_FRAGMENT_TAG)
        val fragment = if (existing is GodotFragment) {
            existing
        } else {
            GodotFragment()
        }
        godotFragment = fragment

        if (fragment.isAdded && fragment.id == container.id) return

        supportFragmentManager.beginTransaction()
            .replace(container.id, fragment, GODOT_FRAGMENT_TAG)
            .commitNowAllowingStateLoss()
    }

    private fun initBridgeIfNeeded(godot: Godot) {
        if (bridgePlugin != null) return
        bridgePlugin = HippoFlutterPlugin(godot) { json ->
            runOnUiThread { eventSink?.success(JSONObject(json).toMap()) }
        }
        pendingCameraMode?.let { bridgePlugin?.requestCameraMode(it) }
        pendingTimeJson?.let { bridgePlugin?.syncDeviceTime(it) }
        while (pendingActions.isNotEmpty()) {
            bridgePlugin?.requestAnimalAction(pendingActions.removeFirst())
        }
    }

    override fun getActivity() = this

    override fun getGodot() = godotFragment?.godot

    override fun getHostPlugins(godot: Godot): Set<GodotPlugin> {
        initBridgeIfNeeded(godot)
        return setOfNotNull(bridgePlugin)
    }
}

private class GodotPlatformViewFactory(
    private val activity: MainActivity,
) : PlatformViewFactory(null) {
    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        return GodotPlatformView(context, activity)
    }
}

private class GodotPlatformView(
    context: Context,
    private val activity: MainActivity,
) : PlatformView {
    private val container = FrameLayout(context).apply {
        id = View.generateViewId()
        layoutParams = FrameLayout.LayoutParams(
            FrameLayout.LayoutParams.MATCH_PARENT,
            FrameLayout.LayoutParams.MATCH_PARENT,
        )
        addOnAttachStateChangeListener(object : View.OnAttachStateChangeListener {
            override fun onViewAttachedToWindow(v: View) {
                post { activity.attachGodotFragment(this@apply) }
            }

            override fun onViewDetachedFromWindow(v: View) = Unit
        })
    }

    override fun getView(): View = container

    override fun dispose() = Unit
}

private fun JSONObject.toMap(): Map<String, Any?> {
    val result = mutableMapOf<String, Any?>()
    val keys = keys()
    while (keys.hasNext()) {
        val key = keys.next()
        result[key] = opt(key)
    }
    return result
}
