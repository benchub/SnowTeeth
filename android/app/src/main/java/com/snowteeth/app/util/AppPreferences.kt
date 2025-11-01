package com.snowteeth.app.util

import android.content.Context
import android.content.SharedPreferences
import com.snowteeth.app.model.VisualizationStyle

class AppPreferences(context: Context) {
    private val prefs: SharedPreferences =
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

    companion object {
        private const val PREFS_NAME = "SnowTeethPrefs"

        // Threshold keys
        private const val KEY_DOWNHILL_HARD = "downhill_hard"
        private const val KEY_DOWNHILL_MEDIUM = "downhill_medium"
        private const val KEY_DOWNHILL_EASY = "downhill_easy"
        private const val KEY_UPHILL_EASY = "uphill_easy"
        private const val KEY_UPHILL_MEDIUM = "uphill_medium"
        private const val KEY_UPHILL_HARD = "uphill_hard"

        // Settings keys
        private const val KEY_USE_METRIC = "use_metric"
        private const val KEY_VIS_STYLE = "visualization_style"
        private const val KEY_TRACKING = "is_tracking"
        private const val KEY_ALTERNATE_ASCENT = "use_alternate_ascent_visualization"

        // Default values (in mph)
        const val DEFAULT_DOWNHILL_HARD = 10.0f
        const val DEFAULT_DOWNHILL_MEDIUM = 6.0f
        const val DEFAULT_DOWNHILL_EASY = 2.0f
        const val DEFAULT_UPHILL_EASY = 1.0f
        const val DEFAULT_UPHILL_MEDIUM = 3.0f
        const val DEFAULT_UPHILL_HARD = 5.0f
    }

    // Threshold getters/setters
    var downhillHardThreshold: Float
        get() = prefs.getFloat(KEY_DOWNHILL_HARD, DEFAULT_DOWNHILL_HARD)
        set(value) = prefs.edit().putFloat(KEY_DOWNHILL_HARD, value).apply()

    var downhillMediumThreshold: Float
        get() = prefs.getFloat(KEY_DOWNHILL_MEDIUM, DEFAULT_DOWNHILL_MEDIUM)
        set(value) = prefs.edit().putFloat(KEY_DOWNHILL_MEDIUM, value).apply()

    var downhillEasyThreshold: Float
        get() = prefs.getFloat(KEY_DOWNHILL_EASY, DEFAULT_DOWNHILL_EASY)
        set(value) = prefs.edit().putFloat(KEY_DOWNHILL_EASY, value).apply()

    var uphillEasyThreshold: Float
        get() = prefs.getFloat(KEY_UPHILL_EASY, DEFAULT_UPHILL_EASY)
        set(value) = prefs.edit().putFloat(KEY_UPHILL_EASY, value).apply()

    var uphillMediumThreshold: Float
        get() = prefs.getFloat(KEY_UPHILL_MEDIUM, DEFAULT_UPHILL_MEDIUM)
        set(value) = prefs.edit().putFloat(KEY_UPHILL_MEDIUM, value).apply()

    var uphillHardThreshold: Float
        get() = prefs.getFloat(KEY_UPHILL_HARD, DEFAULT_UPHILL_HARD)
        set(value) = prefs.edit().putFloat(KEY_UPHILL_HARD, value).apply()

    // Settings getters/setters
    var useMetric: Boolean
        get() = prefs.getBoolean(KEY_USE_METRIC, false)
        set(value) = prefs.edit().putBoolean(KEY_USE_METRIC, value).apply()

    var visualizationStyle: VisualizationStyle
        get() {
            val styleName = prefs.getString(KEY_VIS_STYLE, VisualizationStyle.FLAME.name)
            return VisualizationStyle.valueOf(styleName ?: VisualizationStyle.FLAME.name)
        }
        set(value) = prefs.edit().putString(KEY_VIS_STYLE, value.name).apply()

    var isTracking: Boolean
        get() = prefs.getBoolean(KEY_TRACKING, false)
        set(value) = prefs.edit().putBoolean(KEY_TRACKING, value).apply()

    var useAlternateAscentVisualization: Boolean
        get() = prefs.getBoolean(KEY_ALTERNATE_ASCENT, false)
        set(value) = prefs.edit().putBoolean(KEY_ALTERNATE_ASCENT, value).apply()
}
