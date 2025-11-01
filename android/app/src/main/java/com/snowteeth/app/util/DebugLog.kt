package com.snowteeth.app.util

import android.util.Log
import com.snowteeth.app.BuildConfig

/**
 * Debug logging utilities that are automatically disabled in release builds.
 *
 * These functions check BuildConfig.DEBUG at runtime and only log in debug builds.
 * In release builds, the logging statements are still compiled but the check prevents execution.
 *
 * For even better performance in release builds (no runtime check), use ProGuard rules to
 * strip these calls entirely.
 */
object DebugLog {

    /**
     * Debug log - only logs in DEBUG builds.
     * Use this for verbose development logging that shouldn't appear in production.
     *
     * Usage: DebugLog.d("MyTag", "Debug message")
     */
    fun d(tag: String, message: String) {
        if (BuildConfig.DEBUG) {
            Log.d(tag, message)
        }
    }

    /**
     * Info log - only logs in DEBUG builds.
     * Use this for informational messages during development.
     *
     * Usage: DebugLog.i("MyTag", "Info message")
     */
    fun i(tag: String, message: String) {
        if (BuildConfig.DEBUG) {
            Log.i(tag, message)
        }
    }

    /**
     * Warning log - logs in ALL builds.
     * Use this for important warnings that should be logged in production.
     *
     * Usage: DebugLog.w("MyTag", "Warning message")
     */
    fun w(tag: String, message: String) {
        Log.w(tag, message)
    }

    /**
     * Error log - logs in ALL builds.
     * Use this for errors that should be logged in production.
     *
     * Usage: DebugLog.e("MyTag", "Error message")
     * Usage: DebugLog.e("MyTag", "Error message", exception)
     */
    fun e(tag: String, message: String, throwable: Throwable? = null) {
        if (throwable != null) {
            Log.e(tag, message, throwable)
        } else {
            Log.e(tag, message)
        }
    }
}
