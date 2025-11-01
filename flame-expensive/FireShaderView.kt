//
//  FireShaderView.kt
//  3D Fire Shader View for Android
//
//  OpenGL ES-based fire effect renderer
//

package com.example.fireshader

import android.content.Context
import android.opengl.GLES30
import android.opengl.GLSurfaceView
import android.util.AttributeSet
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.nio.FloatBuffer
import javax.microedition.khronos.egl.EGLConfig
import javax.microedition.khronos.opengles.GL10

class FireShaderView @JvmOverloads constructor(
    context: Context,
    attrs: AttributeSet? = null
) : GLSurfaceView(context, attrs) {

    private val renderer: FireRenderer

    // Shader parameters - can be adjusted in real-time
    var speed: Float
        get() = renderer.speed
        set(value) { renderer.speed = value }

    var intensity: Float
        get() = renderer.intensity
        set(value) { renderer.intensity = value }

    var height: Float
        get() = renderer.height
        set(value) { renderer.height = value }

    var turbulence: Float
        get() = renderer.turbulence
        set(value) { renderer.turbulence = value }

    var detail: Float
        get() = renderer.detail
        set(value) { renderer.detail = value }

    var colorShift: Float
        get() = renderer.colorShift
        set(value) { renderer.colorShift = value }

    var baseWidth: Float
        get() = renderer.baseWidth
        set(value) { renderer.baseWidth = value }

    var taper: Float
        get() = renderer.taper
        set(value) { renderer.taper = value }

    var twist: Float
        get() = renderer.twist
        set(value) { renderer.twist = value }

    var frequency: Float
        get() = renderer.frequency
        set(value) { renderer.frequency = value }

    init {
        setEGLContextClientVersion(3)
        renderer = FireRenderer(context)
        setRenderer(renderer)
        renderMode = RENDERMODE_CONTINUOUSLY
    }

    fun resetAnimation() {
        renderer.resetStartTime()
    }
}

class FireRenderer(private val context: Context) : GLSurfaceView.Renderer {

    // Shader parameters
    var speed: Float = 1.0f
    var intensity: Float = 1.5f
    var height: Float = 1.0f
    var turbulence: Float = 1.0f
    var detail: Float = 1.0f
    var colorShift: Float = 1.0f
    var baseWidth: Float = 1.0f
    var taper: Float = 0.3f
    var twist: Float = 0.5f
    var frequency: Float = 2.0f

    // Smoothed version of speed to prevent jerky animation
    private var smoothedSpeed: Float = 1.0f

    // Phase tracking for continuity
    private var timeOffset: Float = 0.0f
    private var lastFrameTime: Long = System.currentTimeMillis()

    private var program: Int = 0
    private var vertexBuffer: FloatBuffer

    // Uniform locations
    private var uIntensityLocation: Int = 0
    private var uHeightLocation: Int = 0
    private var uTurbulenceLocation: Int = 0
    private var uDetailLocation: Int = 0
    private var uColorShiftLocation: Int = 0
    private var uBaseWidthLocation: Int = 0
    private var uTaperLocation: Int = 0
    private var uTwistLocation: Int = 0
    private var uFrequencyLocation: Int = 0
    private var uTimeOffsetLocation: Int = 0
    private var uResolutionLocation: Int = 0

    // Screen dimensions
    private var screenWidth: Int = 0
    private var screenHeight: Int = 0

    init {
        // Create a full-screen quad
        val vertices = floatArrayOf(
            -1.0f, -1.0f,
            1.0f, -1.0f,
            -1.0f, 1.0f,
            1.0f, 1.0f
        )

        vertexBuffer = ByteBuffer.allocateDirect(vertices.size * 4).run {
            order(ByteOrder.nativeOrder())
            asFloatBuffer().apply {
                put(vertices)
                position(0)
            }
        }
    }

    override fun onSurfaceCreated(gl: GL10?, config: EGLConfig?) {
        GLES30.glClearColor(0.0f, 0.0f, 0.0f, 1.0f)

        // Load shaders
        val vertexShader = loadShader(GLES30.GL_VERTEX_SHADER, VERTEX_SHADER_CODE)
        val fragmentShader = loadShader(GLES30.GL_FRAGMENT_SHADER, FRAGMENT_SHADER_CODE)

        // Create program
        program = GLES30.glCreateProgram().also {
            GLES30.glAttachShader(it, vertexShader)
            GLES30.glAttachShader(it, fragmentShader)
            GLES30.glLinkProgram(it)

            // Check for linking errors
            val linkStatus = IntArray(1)
            GLES30.glGetProgramiv(it, GLES30.GL_LINK_STATUS, linkStatus, 0)
            if (linkStatus[0] == 0) {
                val error = GLES30.glGetProgramInfoLog(it)
                GLES30.glDeleteProgram(it)
                throw RuntimeException("Error linking program: $error")
            }
        }

        // Get uniform locations
        uIntensityLocation = GLES30.glGetUniformLocation(program, "u_intensity")
        uHeightLocation = GLES30.glGetUniformLocation(program, "u_height")
        uTurbulenceLocation = GLES30.glGetUniformLocation(program, "u_turbulence")
        uDetailLocation = GLES30.glGetUniformLocation(program, "u_detail")
        uColorShiftLocation = GLES30.glGetUniformLocation(program, "u_colorShift")
        uBaseWidthLocation = GLES30.glGetUniformLocation(program, "u_baseWidth")
        uTaperLocation = GLES30.glGetUniformLocation(program, "u_taper")
        uTwistLocation = GLES30.glGetUniformLocation(program, "u_twist")
        uFrequencyLocation = GLES30.glGetUniformLocation(program, "u_frequency")
        uTimeOffsetLocation = GLES30.glGetUniformLocation(program, "u_timeOffset")
        uResolutionLocation = GLES30.glGetUniformLocation(program, "u_resolution")
    }

    override fun onSurfaceChanged(gl: GL10?, width: Int, height: Int) {
        GLES30.glViewport(0, 0, width, height)
        screenWidth = width
        screenHeight = height
    }

    override fun onDrawFrame(gl: GL10?) {
        GLES30.glClear(GLES30.GL_COLOR_BUFFER_BIT)

        GLES30.glUseProgram(program)

        // Calculate delta time for frame-to-frame integration
        val currentTime = System.currentTimeMillis()
        val deltaTime = (currentTime - lastFrameTime) / 1000.0f
        lastFrameTime = currentTime

        // Smooth speed (factor 0.3 balances responsiveness with smoothness)
        val smoothingFactor = 0.3f
        smoothedSpeed += (speed - smoothedSpeed) * smoothingFactor

        // Integrate speed to maintain phase continuity
        timeOffset += smoothedSpeed * deltaTime

        // Set uniforms
        GLES30.glUniform1f(uIntensityLocation, intensity)
        GLES30.glUniform1f(uHeightLocation, height)
        GLES30.glUniform1f(uTurbulenceLocation, turbulence)
        GLES30.glUniform1f(uDetailLocation, detail)
        GLES30.glUniform1f(uColorShiftLocation, colorShift)
        GLES30.glUniform1f(uBaseWidthLocation, baseWidth)
        GLES30.glUniform1f(uTaperLocation, taper)
        GLES30.glUniform1f(uTwistLocation, twist)
        GLES30.glUniform1f(uFrequencyLocation, frequency)
        GLES30.glUniform1f(uTimeOffsetLocation, timeOffset)
        GLES30.glUniform2f(uResolutionLocation, screenWidth.toFloat(), screenHeight.toFloat())

        // Draw the quad
        val positionHandle = GLES30.glGetAttribLocation(program, "a_position")
        GLES30.glEnableVertexAttribArray(positionHandle)
        GLES30.glVertexAttribPointer(
            positionHandle, 2,
            GLES30.GL_FLOAT, false,
            8, vertexBuffer
        )

        GLES30.glDrawArrays(GLES30.GL_TRIANGLE_STRIP, 0, 4)
        GLES30.glDisableVertexAttribArray(positionHandle)
    }

    private fun loadShader(type: Int, shaderCode: String): Int {
        return GLES30.glCreateShader(type).also { shader ->
            GLES30.glShaderSource(shader, shaderCode)
            GLES30.glCompileShader(shader)

            // Check for compilation errors
            val compileStatus = IntArray(1)
            GLES30.glGetShaderiv(shader, GLES30.GL_COMPILE_STATUS, compileStatus, 0)
            if (compileStatus[0] == 0) {
                val error = GLES30.glGetShaderInfoLog(shader)
                GLES30.glDeleteShader(shader)
                throw RuntimeException("Error compiling shader: $error")
            }
        }
    }

    companion object {
        private const val VERTEX_SHADER_CODE = """
            #version 300 es
            precision highp float;

            in vec4 a_position;

            void main() {
                gl_Position = a_position;
            }
        """

        private const val FRAGMENT_SHADER_CODE = """
            #version 300 es
            precision highp float;

            uniform float u_intensity;
            uniform float u_height;
            uniform float u_turbulence;
            uniform float u_detail;
            uniform float u_colorShift;
            uniform float u_baseWidth;
            uniform float u_taper;
            uniform float u_twist;
            uniform float u_frequency;
            uniform float u_timeOffset;
            uniform vec2 u_resolution;

            out vec4 fragColor;

            // Tanh approximation for tone mapping
            vec4 tanhApprox(vec4 x) {
                vec4 x2 = x * x;
                return x * (3.0 + x2) / (3.0 + 3.0 * x2);
            }

            // Temperature-based color mapping with improved contrast
            vec3 temperatureToColor(float temp, float variation) {
                float t = clamp((temp - 0.5) / 1.5, 0.0, 1.0);
                t += variation * 0.05;
                t = clamp(t, 0.0, 1.0);

                vec3 red = vec3(1.0, 0.0, 0.0);
                vec3 orange = vec3(1.0, 0.4, 0.0);
                vec3 yellow = vec3(1.0, 0.9, 0.0);
                vec3 green = vec3(0.0, 0.5, 0.1);
                vec3 cyan = vec3(0.0, 0.8, 1.0);
                vec3 blue = vec3(0.2, 0.4, 1.0);
                vec3 white = vec3(1.0, 1.0, 1.0);

                if (t < 0.166) {
                    return mix(red, orange, t / 0.166);
                } else if (t < 0.333) {
                    return mix(orange, yellow, (t - 0.166) / 0.167);
                } else if (t < 0.5) {
                    return mix(yellow, green, (t - 0.333) / 0.167);
                } else if (t < 0.666) {
                    return mix(green, cyan, (t - 0.5) / 0.166);
                } else if (t < 0.833) {
                    return mix(cyan, blue, (t - 0.666) / 0.167);
                } else {
                    return mix(blue, white, (t - 0.833) / 0.167);
                }
            }

            void main() {
                vec2 fragCoord = gl_FragCoord.xy;
                vec2 iResolution = u_resolution;

                vec2 uv = (fragCoord * 2.0 - iResolution) / iResolution.y;
                uv.y = -uv.y;

                float t = u_timeOffset;
                float z = 0.0;
                vec4 O = vec4(0.0);

                for(float step = 0.0; step < 50.0; step++) {
                    vec3 p = z * normalize(vec3(uv, -1.0));
                    p.z += 5.0 + cos(t) * 0.5;
                    p.y += uv.y + 1.0;

                    float pYOriginal = p.y;

                    float angle = p.y * 0.5 * u_twist;
                    float cosVal = cos(angle);
                    float sinVal = sin(angle);
                    mat2 rotMat = mat2(cosVal, -sinVal, sinVal, cosVal);
                    float scaleFactor = max(p.y * 0.15 + 1.0, 0.5);
                    p.xz = (rotMat * p.xz) / scaleFactor;

                    float freq = u_frequency;
                    float baseAmplitude = u_turbulence * u_frequency;
                    float octaveFactor = mix(0.75, 0.45, (u_detail - 0.5) / 1.5);
                    for(int turbLoop = 0; turbLoop < 8; turbLoop++) {
                        vec3 offset = vec3(t * 10.0, t, freq);
                        p += cos((p.yzx - offset) * freq) * baseAmplitude / freq;
                        freq = freq / octaveFactor;
                    }

                    float coneRadius = length(p.xz);
                    float baseRadius = u_baseWidth * 0.5;
                    float flameBase = -2.887;
                    float flameTop = flameBase + u_height * 7.774;

                    float targetRadius;
                    if (pYOriginal <= flameTop) {
                        float heightFactor = clamp((pYOriginal - flameBase) / (flameTop - flameBase), 0.0, 1.0);
                        float topRadius = u_taper * 2.0 * baseRadius;
                        targetRadius = mix(baseRadius, topRadius, heightFactor);
                        targetRadius = max(targetRadius, 0.02);
                    } else {
                        float fadeHeight = 0.3;
                        float topRadius = u_taper * 2.0 * baseRadius;
                        float shrinkFactor = 1.0 - clamp((pYOriginal - flameTop) / fadeHeight, 0.0, 1.0);
                        targetRadius = topRadius * shrinkFactor;
                        targetRadius = max(targetRadius, 0.001);
                    }
                    float dist = 0.01 + abs(coneRadius - targetRadius) / 7.0;
                    z += dist;

                    float brightVariation = sin(z / 3.0) * 0.5 + sin(z / 1.5) * 0.3 + cos(z / 2.0 + t) * 0.2;
                    float colorVariation = sin(z / 2.0) * cos(z / 4.0);
                    float tempNorm = clamp((u_colorShift - 0.5) / 1.5, 0.0, 1.0);
                    vec3 baseColor = temperatureToColor(u_colorShift, colorVariation);
                    float variationStrength = mix(0.6, 1.4, tempNorm);
                    float brightness = variationStrength + brightVariation * 0.4;
                    brightness = max(brightness, 0.2);
                    vec3 color = baseColor * brightness / dist;

                    float topFadeWidth = max((flameTop - flameBase) * 0.3, 0.3);
                    float topFadeStart = flameTop - topFadeWidth;
                    float heightFade = 1.0 - smoothstep(topFadeStart, flameTop, pYOriginal);
                    O.rgb += color * u_intensity * heightFade;
                    O.a += u_intensity / dist * heightFade;
                }

                O = tanhApprox(O / 1000.0);
                O.a = 1.0;
                fragColor = O;
            }
        """
    }
}
