//
//  MainActivity.kt
//  Example Android activity demonstrating the fire shader
//
//  Copy this file to your Android project's main activity
//

package com.example.fireshader

import android.os.Bundle
import android.view.View
import android.widget.Button
import android.widget.LinearLayout
import android.widget.SeekBar
import android.widget.TextView
import androidx.appcompat.app.AppCompatActivity
import androidx.core.view.isVisible

class MainActivity : AppCompatActivity() {

    private lateinit var fireView: FireShaderView
    private lateinit var controlsLayout: LinearLayout
    private lateinit var toggleButton: Button

    // Slider references
    private lateinit var speedSlider: SeekBar
    private lateinit var intensitySlider: SeekBar
    private lateinit var heightSlider: SeekBar
    private lateinit var turbulenceSlider: SeekBar
    private lateinit var colorShiftSlider: SeekBar

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_main)

        setupViews()
        setupControls()
        setDefaults()
    }

    private fun setupViews() {
        fireView = findViewById(R.id.fireShaderView)
        controlsLayout = findViewById(R.id.controlsLayout)
        toggleButton = findViewById(R.id.toggleControlsButton)

        toggleButton.setOnClickListener {
            controlsLayout.isVisible = !controlsLayout.isVisible
            toggleButton.text = if (controlsLayout.isVisible) "Hide Controls" else "Show Controls"
        }
    }

    private fun setupControls() {
        // Speed control
        speedSlider = findViewById(R.id.speedSlider)
        val speedValue = findViewById<TextView>(R.id.speedValue)
        speedSlider.setOnSeekBarChangeListener(createSeekBarListener { progress ->
            val value = 0.5f + (progress / 100f) * 1.5f
            fireView.speed = value
            speedValue.text = String.format("%.2f", value)
        })

        // Intensity control
        intensitySlider = findViewById(R.id.intensitySlider)
        val intensityValue = findViewById<TextView>(R.id.intensityValue)
        intensitySlider.setOnSeekBarChangeListener(createSeekBarListener { progress ->
            val value = 0.5f + (progress / 100f) * 2.5f
            fireView.intensity = value
            intensityValue.text = String.format("%.2f", value)
        })

        // Height control
        heightSlider = findViewById(R.id.heightSlider)
        val heightValue = findViewById<TextView>(R.id.heightValue)
        heightSlider.setOnSeekBarChangeListener(createSeekBarListener { progress ->
            val value = 0.5f + (progress / 100f) * 1.5f
            fireView.height = value
            heightValue.text = String.format("%.2f", value)
        })

        // Turbulence control
        turbulenceSlider = findViewById(R.id.turbulenceSlider)
        val turbulenceValue = findViewById<TextView>(R.id.turbulenceValue)
        turbulenceSlider.setOnSeekBarChangeListener(createSeekBarListener { progress ->
            val value = 0.5f + (progress / 100f) * 1.5f
            fireView.turbulence = value
            turbulenceValue.text = String.format("%.2f", value)
        })

        // Color shift control
        colorShiftSlider = findViewById(R.id.colorShiftSlider)
        val colorShiftValue = findViewById<TextView>(R.id.colorShiftValue)
        colorShiftSlider.setOnSeekBarChangeListener(createSeekBarListener { progress ->
            val value = 0.5f + (progress / 100f) * 1.5f
            fireView.colorShift = value
            colorShiftValue.text = String.format("%.2f", value)
        })

        // Preset buttons
        findViewById<Button>(R.id.campfireButton).setOnClickListener { setCampfire() }
        findViewById<Button>(R.id.infernoButton).setOnClickListener { setInferno() }
        findViewById<Button>(R.id.resetButton).setOnClickListener { setDefaults() }
    }

    private fun createSeekBarListener(onChange: (Int) -> Unit): SeekBar.OnSeekBarChangeListener {
        return object : SeekBar.OnSeekBarChangeListener {
            override fun onProgressChanged(seekBar: SeekBar?, progress: Int, fromUser: Boolean) {
                onChange(progress)
            }
            override fun onStartTrackingTouch(seekBar: SeekBar?) {}
            override fun onStopTrackingTouch(seekBar: SeekBar?) {}
        }
    }

    private fun setDefaults() {
        speedSlider.progress = 33 // 1.0
        intensitySlider.progress = 40 // 1.5
        heightSlider.progress = 33 // 1.0
        turbulenceSlider.progress = 33 // 1.0
        colorShiftSlider.progress = 33 // 1.0
    }

    private fun setCampfire() {
        speedSlider.progress = 7  // 0.6
        intensitySlider.progress = 20 // 1.0
        heightSlider.progress = 13 // 0.7
        turbulenceSlider.progress = 47 // 1.2
        colorShiftSlider.progress = 33 // 1.0
    }

    private fun setInferno() {
        speedSlider.progress = 100 // 2.0
        intensitySlider.progress = 100 // 3.0
        heightSlider.progress = 67 // 1.5
        turbulenceSlider.progress = 100 // 2.0
        colorShiftSlider.progress = 67 // 1.5
    }
}
