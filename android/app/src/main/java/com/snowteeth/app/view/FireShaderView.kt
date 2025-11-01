package com.snowteeth.app.view

import android.content.Context
import android.opengl.GLES30
import android.opengl.GLSurfaceView
import android.util.AttributeSet
import android.util.Log
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

    // Shader parameters - can be adjusted in real-time (updated for 2D fire shader)
    var speed: Float
        get() = renderer.speed
        set(value) { renderer.speed = value }

    var intensity: Float
        get() = renderer.intensity
        set(value) { renderer.intensity = value }

    var height: Float
        get() = renderer.height
        set(value) { renderer.height = value }

    var colorShift: Float
        get() = renderer.colorShift
        set(value) { renderer.colorShift = value }

    var baseWidth: Float
        get() = renderer.baseWidth
        set(value) { renderer.baseWidth = value }

    var colorBlend: Float
        get() = renderer.colorBlend
        set(value) { renderer.colorBlend = value }

    init {
        setEGLContextClientVersion(3)
        renderer = FireRenderer(context)
        setRenderer(renderer)
        renderMode = RENDERMODE_CONTINUOUSLY
    }

    // Apply a preset configuration
    fun applyPreset(
        speed: Float, intensity: Float, height: Float,
        colorShift: Float, baseWidth: Float, colorBlend: Float
    ) {
        this.speed = speed
        this.intensity = intensity
        this.height = height
        this.colorShift = colorShift
        this.baseWidth = baseWidth
        this.colorBlend = colorBlend
    }
}

class FireRenderer(private val context: Context) : GLSurfaceView.Renderer {

    // Target shader parameters (set from outside) - updated for 2D fire shader
    var speed: Float = 0.47f
    var intensity: Float = 1.98f
    var height: Float = 0.44f
    var colorShift: Float = 0.72f
    var baseWidth: Float = 0.3f
    var colorBlend: Float = 0.67f

    // Smoothed versions to prevent jerky animation
    private var smoothedSpeed: Float = 0.47f
    private var smoothedIntensity: Float = 1.98f
    private var smoothedHeight: Float = 0.44f
    private var smoothedColorShift: Float = 0.72f
    private var smoothedBaseWidth: Float = 0.3f
    private var smoothedColorBlend: Float = 0.67f

    // Phase tracking for continuity
    private var timeOffset: Float = 0.0f
    private var lastFrameTime: Long = System.currentTimeMillis()

    private var program: Int = 0
    private var vertexBuffer: FloatBuffer

    // Uniform locations
    private var uIntensityLocation: Int = 0
    private var uHeightLocation: Int = 0
    private var uColorShiftLocation: Int = 0
    private var uBaseWidthLocation: Int = 0
    private var uColorBlendLocation: Int = 0
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
        uColorShiftLocation = GLES30.glGetUniformLocation(program, "u_colorShift")
        uBaseWidthLocation = GLES30.glGetUniformLocation(program, "u_baseWidth")
        uColorBlendLocation = GLES30.glGetUniformLocation(program, "u_colorBlend")
        uTimeOffsetLocation = GLES30.glGetUniformLocation(program, "u_timeOffset")
        uResolutionLocation = GLES30.glGetUniformLocation(program, "u_resolution")
    }

    override fun onSurfaceChanged(gl: GL10?, width: Int, height: Int) {
        // Set viewport to full screen size
        GLES30.glViewport(0, 0, width, height)

        // Use full resolution for shader calculations to fill screen properly
        screenWidth = width
        screenHeight = height

        Log.i(TAG, "Rendering at: ${screenWidth}x${screenHeight} (${(screenWidth * screenHeight) / 1_000_000f}M pixels)")
    }

    override fun onDrawFrame(gl: GL10?) {
        GLES30.glClear(GLES30.GL_COLOR_BUFFER_BIT)

        GLES30.glUseProgram(program)

        // Calculate delta time for frame-to-frame integration
        val currentTime = System.currentTimeMillis()
        val deltaTime = (currentTime - lastFrameTime) / 1000.0f
        lastFrameTime = currentTime

        // Smooth all parameters (factor 0.15 gives smooth, gradual transitions)
        val smoothingFactor = 0.15f
        smoothedSpeed += (speed - smoothedSpeed) * smoothingFactor
        smoothedIntensity += (intensity - smoothedIntensity) * smoothingFactor
        smoothedHeight += (height - smoothedHeight) * smoothingFactor
        smoothedColorShift += (colorShift - smoothedColorShift) * smoothingFactor
        smoothedBaseWidth += (baseWidth - smoothedBaseWidth) * smoothingFactor
        smoothedColorBlend += (colorBlend - smoothedColorBlend) * smoothingFactor

        // Integrate speed to maintain phase continuity
        timeOffset += smoothedSpeed * deltaTime

        // Set uniforms using smoothed values
        GLES30.glUniform1f(uIntensityLocation, smoothedIntensity)
        GLES30.glUniform1f(uHeightLocation, smoothedHeight)
        GLES30.glUniform1f(uColorShiftLocation, smoothedColorShift)
        GLES30.glUniform1f(uBaseWidthLocation, smoothedBaseWidth)
        GLES30.glUniform1f(uColorBlendLocation, smoothedColorBlend)
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
        private const val TAG = "FireRenderer"

        private val VERTEX_SHADER_CODE = """
            #version 300 es
            precision highp float;

            in vec4 a_position;

            void main() {
                gl_Position = a_position;
            }
        """.trimIndent()

        private val FRAGMENT_SHADER_CODE = """
            #version 300 es
            precision highp float;

            uniform float u_intensity;
            uniform float u_height;
            uniform float u_colorShift;
            uniform float u_baseWidth;
            uniform float u_colorBlend;
            uniform float u_timeOffset;
            uniform vec2 u_resolution;

            out vec4 fragColor;

            // Apply turbulence to coordinates
            vec2 turbulence(vec2 p, float iTime, float turbFreq, float turbNum, float turbSpeed, float turbAmp, float turbExp) {
                // Turbulence starting scale
                float freq = turbFreq;

                // Turbulence rotation matrix
                mat2 rot = mat2(0.6, -0.8, 0.8, 0.6);

                // Loop through turbulence octaves
                for(float i = 0.0; i < turbNum; i += 1.0) {
                    // Scroll along the rotated y coordinate
                    vec2 rotP = p * rot;
                    float phase = freq * rotP.y + turbSpeed * iTime + i;
                    // Add a perpendicular sine wave offset
                    p += turbAmp * rot[0] * sin(phase) / freq;

                    // Rotate for the next octave
                    rot = rot * mat2(0.6, -0.8, 0.8, 0.6);
                    // Scale down for the next octave
                    freq *= turbExp;
                }

                return p;
            }

            // Temperature-based color mapping (optimized with constants and smoothstep)
            vec3 temperatureToColor(float temp) {
                float t = clamp((temp - 0.5) / 1.5, 0.0, 1.0);

                // Use smoothstep blending instead of branching for better GPU performance
                float t5 = t * 5.0;  // Map [0,1] to [0,5] for 5 color zones

                // Color constants
                const vec3 orange = vec3(1.0, 0.5, 0.0);
                const vec3 yellow = vec3(1.0, 0.9, 0.0);
                const vec3 green = vec3(0.0, 1.0, 0.0);
                const vec3 cyan = vec3(0.0, 0.8, 1.0);
                const vec3 blue = vec3(0.0, 0.3, 1.0);
                const vec3 white = vec3(1.0, 1.0, 1.0);

                // Branchless color interpolation
                vec3 col = orange;
                col = mix(col, yellow, smoothstep(0.0, 1.0, t5));
                col = mix(col, green, smoothstep(1.0, 2.0, t5));
                col = mix(col, cyan, smoothstep(2.0, 3.0, t5));
                col = mix(col, blue, smoothstep(3.0, 4.0, t5));
                col = mix(col, white, smoothstep(4.0, 5.0, t5));

                return col;
            }

            // Simple procedural noise function
            float hash(vec2 p) {
                float h = dot(p, vec2(127.1, 311.7));
                return fract(sin(h) * 43758.5453123);
            }

            float noise(vec2 p) {
                vec2 i = floor(p);
                vec2 f = fract(p);
                f = f * f * (3.0 - 2.0 * f); // Smoothstep

                float a = hash(i);
                float b = hash(i + vec2(1.0, 0.0));
                float c = hash(i + vec2(0.0, 1.0));
                float d = hash(i + vec2(1.0, 1.0));

                return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
            }

            void main() {
                vec2 fragCoord = gl_FragCoord.xy;
                vec2 iResolution = u_resolution;
                float iTime = u_timeOffset;

                // Algorithm parameters (configurable via uniforms)
                float RADIUS = 0.4 * u_height;  // Height controls flame size
                float GRADIENT = 0.3;
                float SCROLL = 1.6;
                float scrollTime = SCROLL * iTime;

                float TURB_NUM = 8.0;
                float TURB_AMP = 0.4;
                float TURB_SPEED = 6.0;
                float TURB_FREQ = 7.0;
                float TURB_EXP = 1.3;

                // Screen coordinates, centered and aspect corrected
                vec2 p = (fragCoord * 2.0 - iResolution) / iResolution.y;

                // In OpenGL, Y=0 is at bottom, so no flip needed for upward flame
                // (keeping Y as-is means negative at bottom, positive at top)

                // Apply width control
                p.x /= u_baseWidth;

                // Expand vertically
                float xstretch = 2.0 - 1.5 * smoothstep(-2.0, 2.0, p.y);
                // Decelerate horizontally
                float ystretch = 1.0 - 0.5 / (1.0 + p.x * p.x);
                // Combine
                vec2 stretch = vec2(xstretch, ystretch);
                // Stretch coordinates
                p *= stretch;

                // Scroll upward
                p.y -= scrollTime;

                p = turbulence(p, iTime, TURB_FREQ, TURB_NUM, TURB_SPEED, TURB_AMP, TURB_EXP);

                // Reverse the scrolling offset
                p.y += scrollTime;

                // Distance to fireball
                float dist = length(min(p, p / vec2(1, stretch.y))) - RADIUS;
                // Attenuate outward and fade vertically (optimized pow to multiplication)
                float distSq = dist * dist + GRADIENT * max(p.y + 0.5, 0.0);
                float light = 1.0 / (distSq * distSq * distSq);
                // Coordinates relative to the source
                vec2 source = p + 2.0 * vec2(0, RADIUS) * stretch;

                // Temperature-based color with edge blending
                vec3 coreColor = temperatureToColor(u_colorShift);
                vec3 edgeColor = vec3(1.0, 0.2, 0.0);  // Red-orange edge

                // Blend from core to edge based on distance from center
                float centerDist = length(source);
                float colorMix = smoothstep(0.0, u_colorBlend, centerDist);
                vec3 flameColor = mix(coreColor, edgeColor, colorMix);

                // Use uniform falloff to preserve colors
                float falloff = 0.1 / (1.0 + centerDist * 2.0);
                vec3 grad = flameColor * falloff;

                // Ambient lighting (no flicker) - optimized to reuse dot product
                float pDotP = dot(p, p);
                vec3 amb = 16.0 / (1.0 + pDotP) * grad;

                // Generate procedural noise for texture
                vec2 uv = (p - vec2(0, scrollTime)) / 100.0 * TURB_FREQ;
                float tex = noise(uv * 10.0); // Generate noise at higher frequency
                vec3 texCol = vec3(tex, tex, tex);

                // Combine ambient and direct fire
                vec3 col = amb + light * grad * texCol * u_intensity;
                // Exponential tonemap
                col = 1.0 - exp(-col);

                fragColor = vec4(col, 1.0);
            }
        """.trimIndent()
    }
}
