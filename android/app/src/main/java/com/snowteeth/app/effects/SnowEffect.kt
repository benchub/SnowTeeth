package com.snowteeth.app.effects

import android.graphics.PointF
import android.graphics.RectF
import android.util.Log
import kotlin.random.Random

/**
 * Main coordinator for snow particle system
 * Ported from iOS Swift implementation
 */
class SnowEffect {

    private val collisionDetector = CollisionDetector()
    private val surfaceSnowMaps = mutableMapOf<String, FallenSnow>()  // Height-map for each surface

    private val snowflakes = mutableListOf<Snowflake>()
    private var targetBounds = mutableListOf<CollisionDetector.CollisionTarget>()
    private var currentGravity = PointF(0f, 1f)
    private var screenWidth: Float = 0f
    private var screenHeight: Float = 0f
    private var density: Float = 1f  // Screen density (set from view context)

    private var lastSpawnTime: Long = 0L
    private val spawnInterval: Long = 150L // 150ms between spawn attempts
    private val maxFallingParticles = 80  // Reduced from 300 to improve performance
    private var lastDiagnosticLog: Long = 0L
    private val diagnosticLogInterval: Long = 5000L  // Log every 5 seconds

    // Global wind direction that affects all snow
    private var windDirection: Float = 0f  // negative = left, positive = right
    private var lastWindChange: Long = 0L
    private val windChangeInterval: Long = 5000L  // Change wind every 5 seconds

    private var lastUpdateTime: Long = 0L

    init {
        // Initialize with random wind direction
        windDirection = Random.nextFloat() * 80f - 40f  // -40 to 40
    }

    /**
     * Returns current list of snowflakes for rendering
     */
    fun getSnowflakes(): List<Snowflake> = snowflakes

    /**
     * Sets the screen size for boundary checks
     */
    fun setScreenSize(width: Float, height: Float) {
        screenWidth = width
        screenHeight = height
        // Note: surfaceSnowMaps will be recreated when setTargetBounds is called again
    }

    /**
     * Sets the screen density for dp calculations
     */
    fun setDensity(density: Float) {
        this.density = density
    }

    /**
     * Resets the snow effect by clearing all snowflakes
     */
    fun reset() {
        snowflakes.clear()
        for ((_, snowMap) in surfaceSnowMaps) {
            snowMap.reset()
        }
    }

    /**
     * Returns all surface snow maps for rendering
     */
    fun getSurfaceSnowMaps(): Map<String, FallenSnow> = surfaceSnowMaps

    /**
     * Sets collision targets (letters, buttons, etc.)
     */
    fun setTargetBounds(bounds: List<CollisionDetector.CollisionTarget>) {
        targetBounds = bounds.toMutableList()

        // Create a height-map for each surface
        surfaceSnowMaps.clear()
        for (target in bounds) {
            // Only sample integer X coordinates that are actually inside the bounds
            val startX = kotlin.math.ceil(target.bounds.left).toInt()
            val endX = kotlin.math.floor(target.bounds.right).toInt()
            val width = maxOf(0, endX - startX + 1)
            val offsetX = startX.toFloat()

            surfaceSnowMaps[target.id] = FallenSnow(
                width,
                target.bounds,
                target.path,
                offsetX,
                density
            )
        }

        // Add ground target at bottom of screen
        if (screenHeight > 0) {
            val groundBounds = RectF(0f, screenHeight - 5f, screenWidth, screenHeight + 5f)
            targetBounds.add(CollisionDetector.CollisionTarget("ground", groundBounds, null))

            val groundStartX = kotlin.math.ceil(groundBounds.left).toInt()
            val groundEndX = kotlin.math.floor(groundBounds.right).toInt()
            val groundWidth = maxOf(0, groundEndX - groundStartX + 1)
            val groundOffsetX = groundStartX.toFloat()

            surfaceSnowMaps["ground"] = FallenSnow(
                groundWidth,
                groundBounds,
                null,
                groundOffsetX,
                density,
                isGround = true
            )
        }

        // Debug: log all surfaces
        Log.d("SnowEffect", "📋 All surfaces created:")
        for ((id, snowMap) in surfaceSnowMaps) {
            Log.d("SnowEffect", "   $id: ${snowMap.getHeights().size} columns with snow")
        }
    }

    /**
     * Main update loop - call this every frame
     */
    fun update() {
        val currentTime = System.currentTimeMillis()

        if (lastUpdateTime == 0L) {
            lastUpdateTime = currentTime
            return
        }

        val deltaTime = (currentTime - lastUpdateTime) / 1000f  // Convert to seconds
        lastUpdateTime = currentTime

        // Change wind direction periodically
        if (currentTime - lastWindChange >= windChangeInterval) {
            windDirection = Random.nextFloat() * 80f - 40f  // -40 to 40
            lastWindChange = currentTime
        }

        // Sort targets by Y position (top to bottom) for collision detection
        val sortedTargets = targetBounds.sortedBy { it.bounds.top }

        // Update all snowflakes
        var activeFallingCount = 0
        var slidingCount = 0

        for (i in snowflakes.indices) {
            val snowflake = snowflakes[i]

            // Check for collisions if falling
            if (snowflake.state is ParticleState.Falling) {
                // Check collision with each surface's height-map (from top to bottom)
                for (target in sortedTargets) {
                    val surfaceMap = surfaceSnowMaps[target.id]
                    // Check collision at snowflake center, not bottom, to avoid "floating" appearance
                    if (surfaceMap != null && surfaceMap.collides(snowflake.position.x, snowflake.position.y)) {
                        // Hit this surface - add snow to all columns covered by the snowflake's width
                        // BUT only to columns that have a valid baseline at this Y level
                        val radius = snowflake.size / 2f
                        val leftEdge = snowflake.position.x - radius
                        val rightEdge = snowflake.position.x + radius
                        val collisionY = snowflake.position.y

                        // Add 1 pixel of snow to each column that:
                        // 1. The snowflake overlaps, AND
                        // 2. Has a baseline at approximately the collision Y (within tolerance)
                        val startColumn = kotlin.math.ceil(leftEdge).toInt()
                        val endColumn = kotlin.math.floor(rightEdge).toInt()
                        val baselineTolerance = 10f  // Allow 10px variance in baseline height

                        for (columnX in startColumn..endColumn) {
                            // Check if this column has a valid baseline at the collision Y
                            val baselineY = surfaceMap.getBaselineY(columnX.toFloat())
                            if (baselineY < target.bounds.bottom + 100f && kotlin.math.abs(baselineY - collisionY) < baselineTolerance) {
                                surfaceMap.addSnow(columnX.toFloat(), 1.0f)
                            }
                        }

                        // Erode a random stack somewhere else for natural dynamics
                        surfaceMap.erodeRandom()

                        snowflake.state = ParticleState.Gone
                        break
                    }
                }
            }

            // Update position
            snowflake.update(deltaTime)

            // Check if offscreen
            when (snowflake.state) {
                is ParticleState.Stuck -> {
                    // No longer tracking stuck particles
                }
                is ParticleState.Falling -> {
                    if (snowflake.isOffscreen(screenHeight, screenWidth)) {
                        snowflake.state = ParticleState.Gone
                    } else {
                        activeFallingCount++
                    }
                }
                is ParticleState.Sliding -> {
                    if (snowflake.isOffscreen(screenHeight, screenWidth)) {
                        snowflake.state = ParticleState.Gone
                    } else {
                        slidingCount++
                    }
                }
                is ParticleState.Gone -> {
                    // Already gone
                }
            }
        }

        // Remove gone particles
        snowflakes.removeAll { it.state is ParticleState.Gone }

        // Spawn new snowflakes if needed (only limit falling particles)
        if (currentTime - lastSpawnTime >= spawnInterval && activeFallingCount < maxFallingParticles) {
            // Spawn fewer particles per interval for better performance
            val particlesToSpawn = Random.nextInt(3, 8)  // 3-7 particles per spawn (was 50-100)
            val remainingCapacity = maxFallingParticles - activeFallingCount
            val actualSpawnCount = minOf(particlesToSpawn, remainingCapacity)

            repeat(actualSpawnCount) {
                spawnSnowflake()
            }
            lastSpawnTime = currentTime
        }

        // Diagnostic logging every 5 seconds
        if (currentTime - lastDiagnosticLog >= diagnosticLogInterval) {
            val totalSnowColumns = surfaceSnowMaps.values.sumOf { it.getHeights().size }
            Log.d("SnowEffect", "❄️ Performance: ${snowflakes.size} particles (${activeFallingCount} falling, ${slidingCount} sliding), ${surfaceSnowMaps.size} surfaces, ${totalSnowColumns} snow columns")
            lastDiagnosticLog = currentTime
        }
    }

    private fun spawnSnowflake() {
        // Size scaled for typical Android density (3x for xhdpi)
        val baseSize = Random.nextFloat() * 1.5f + 2f  // 2-3.5 dp
        val size = baseSize * 3f  // Scale to pixels (6-10.5 pixels)
        val speed = Random.nextFloat() * 30f + 20f  // 20-50

        // Use global wind direction with occasional gusts
        val gustChance = Random.nextFloat()
        val windSpeed = if (gustChance < 0.15f) windDirection * 1.5f else windDirection

        // Randomly choose spawn location based on wind direction
        val spawnChoice = Random.nextFloat()

        val position: PointF
        val velocity: PointF

        if (spawnChoice < 0.7f) {
            // Spawn from top of screen (most common)
            val x = Random.nextFloat() * screenWidth
            position = PointF(x, -size)

            velocity = PointF(
                windSpeed,
                speed  // Always fall downward on screen
            )
        } else {
            // Spawn from the upwind edge so snow blows across screen
            val y = Random.nextFloat() * screenHeight

            if (windDirection > 0) {
                // Wind blowing right, spawn from left
                position = PointF(-size, y)
            } else {
                // Wind blowing left, spawn from right
                position = PointF(screenWidth + size, y)
            }

            // All snow moves with the wind and downward
            velocity = PointF(
                windSpeed * 0.7f,  // Less horizontal when spawning from edge
                speed * 0.5f  // Downward movement
            )
        }

        val snowflake = Snowflake(
            position = position,
            velocity = velocity,
            size = size,
            opacity = Random.nextFloat() * 0.4f + 0.6f  // 0.6-1.0
        )

        snowflakes.add(snowflake)
    }

}
