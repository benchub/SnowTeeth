package com.snowteeth.app

import android.os.Bundle
import android.widget.*
import androidx.appcompat.app.AppCompatActivity
import com.google.android.material.button.MaterialButtonToggleGroup
import com.google.android.material.switchmaterial.SwitchMaterial
import com.snowteeth.app.model.VisualizationStyle
import com.snowteeth.app.util.AppPreferences
import com.snowteeth.app.view.ThresholdSliderView

class ConfigurationActivity : AppCompatActivity() {

    private lateinit var prefs: AppPreferences

    private lateinit var sliderDownhill: ThresholdSliderView
    private lateinit var sliderUphill: ThresholdSliderView
    private lateinit var toggleGroupUnits: MaterialButtonToggleGroup
    private lateinit var toggleGroupVisStyle: MaterialButtonToggleGroup
    private lateinit var switchAlternateAscent: SwitchMaterial
    private lateinit var tvDownhillHeader: TextView
    private lateinit var tvUphillHeader: TextView

    private var previouslyMetric: Boolean = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_configuration)
        supportActionBar?.setDisplayHomeAsUpEnabled(true)

        prefs = AppPreferences(this)
        initializeViews()
        loadCurrentSettings()
        setupSaveButton()
    }

    private fun initializeViews() {
        sliderDownhill = findViewById(R.id.sliderDownhill)
        sliderUphill = findViewById(R.id.sliderUphill)
        toggleGroupUnits = findViewById(R.id.toggleGroupUnits)
        toggleGroupVisStyle = findViewById(R.id.toggleGroupVisStyle)
        switchAlternateAscent = findViewById(R.id.switchAlternateAscent)
        tvDownhillHeader = findViewById(R.id.tvDownhillHeader)
        tvUphillHeader = findViewById(R.id.tvUphillHeader)

        // Configure downhill slider
        sliderDownhill.minValue = 0.0f
        sliderDownhill.maxValue = 30.0f

        // Configure uphill slider
        sliderUphill.minValue = 0.0f
        sliderUphill.maxValue = 15.0f

        // Update headers and convert values when unit toggle changes
        toggleGroupUnits.addOnButtonCheckedListener { _, checkedId, isChecked ->
            if (isChecked) {
                val newUseMetric = checkedId == R.id.btnScience
                updateThresholdHeaders(newUseMetric)

                // Convert threshold values if unit system changed
                if (previouslyMetric != newUseMetric) {
                    convertThresholds(newUseMetric)
                    previouslyMetric = newUseMetric
                }
            }
        }
    }

    private fun loadCurrentSettings() {
        // Load downhill thresholds into slider
        sliderDownhill.easyThreshold = prefs.downhillEasyThreshold
        sliderDownhill.mediumThreshold = prefs.downhillMediumThreshold
        sliderDownhill.hardThreshold = prefs.downhillHardThreshold

        // Load uphill thresholds into slider
        sliderUphill.easyThreshold = prefs.uphillEasyThreshold
        sliderUphill.mediumThreshold = prefs.uphillMediumThreshold
        sliderUphill.hardThreshold = prefs.uphillHardThreshold

        // Load and set unit system
        previouslyMetric = prefs.useMetric
        if (prefs.useMetric) {
            toggleGroupUnits.check(R.id.btnScience)
        } else {
            toggleGroupUnits.check(R.id.btnEmpire)
        }
        updateThresholdHeaders(prefs.useMetric)

        // Load visualization style
        when (prefs.visualizationStyle) {
            VisualizationStyle.FLAME -> toggleGroupVisStyle.check(R.id.btnFlame)
            VisualizationStyle.DATA -> toggleGroupVisStyle.check(R.id.btnData)
            VisualizationStyle.YETI -> toggleGroupVisStyle.check(R.id.btnYeti)
        }

        // Load alternate ascent setting
        switchAlternateAscent.isChecked = prefs.useAlternateAscentVisualization
    }

    private fun updateThresholdHeaders(useMetric: Boolean) {
        val unit = if (useMetric) "km/h" else "mph"
        tvDownhillHeader.text = "Downhill Thresholds ($unit)"
        tvUphillHeader.text = "Uphill Thresholds ($unit)"
    }

    private fun convertThresholds(toMetric: Boolean) {
        val conversionFactor = if (toMetric) {
            1.60934f  // mph to km/h
        } else {
            1.0f / 1.60934f  // km/h to mph
        }

        // Convert downhill thresholds
        sliderDownhill.easyThreshold *= conversionFactor
        sliderDownhill.mediumThreshold *= conversionFactor
        sliderDownhill.hardThreshold *= conversionFactor
        sliderDownhill.maxValue *= conversionFactor

        // Convert uphill thresholds
        sliderUphill.easyThreshold *= conversionFactor
        sliderUphill.mediumThreshold *= conversionFactor
        sliderUphill.hardThreshold *= conversionFactor
        sliderUphill.maxValue *= conversionFactor

        // Force redraw of sliders
        sliderDownhill.invalidate()
        sliderUphill.invalidate()
    }

    private fun setupSaveButton() {
        findViewById<Button>(R.id.btnReset).setOnClickListener {
            resetToDefaults()
        }
    }

    private fun resetToDefaults() {
        prefs.downhillHardThreshold = AppPreferences.DEFAULT_DOWNHILL_HARD
        prefs.downhillMediumThreshold = AppPreferences.DEFAULT_DOWNHILL_MEDIUM
        prefs.downhillEasyThreshold = AppPreferences.DEFAULT_DOWNHILL_EASY
        prefs.uphillEasyThreshold = AppPreferences.DEFAULT_UPHILL_EASY
        prefs.uphillMediumThreshold = AppPreferences.DEFAULT_UPHILL_MEDIUM
        prefs.uphillHardThreshold = AppPreferences.DEFAULT_UPHILL_HARD
        prefs.useMetric = false
        prefs.visualizationStyle = VisualizationStyle.FLAME
        prefs.useAlternateAscentVisualization = false

        loadCurrentSettings()
        Toast.makeText(this, "Reset to defaults", Toast.LENGTH_SHORT).show()
    }

    override fun onPause() {
        super.onPause()
        // Auto-save settings when leaving the screen
        saveSettings()
    }

    private fun saveSettings() {
        // Get values from sliders (no validation needed as sliders enforce constraints)
        prefs.downhillEasyThreshold = sliderDownhill.easyThreshold
        prefs.downhillMediumThreshold = sliderDownhill.mediumThreshold
        prefs.downhillHardThreshold = sliderDownhill.hardThreshold

        prefs.uphillEasyThreshold = sliderUphill.easyThreshold
        prefs.uphillMediumThreshold = sliderUphill.mediumThreshold
        prefs.uphillHardThreshold = sliderUphill.hardThreshold

        // Save unit system
        prefs.useMetric = toggleGroupUnits.checkedButtonId == R.id.btnScience

        // Save visualization style
        prefs.visualizationStyle = when (toggleGroupVisStyle.checkedButtonId) {
            R.id.btnData -> VisualizationStyle.DATA
            R.id.btnYeti -> VisualizationStyle.YETI
            else -> VisualizationStyle.FLAME
        }

        // Save alternate ascent setting
        prefs.useAlternateAscentVisualization = switchAlternateAscent.isChecked
    }

    override fun onSupportNavigateUp(): Boolean {
        finish()
        return true
    }
}
