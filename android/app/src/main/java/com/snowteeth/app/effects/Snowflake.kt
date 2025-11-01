package com.snowteeth.app.effects

import android.graphics.PointF

/**
 * Particle states for snow lifecycle
 */
sealed class ParticleState {
    object Falling : ParticleState()
    data class Stuck(val targetId: String) : ParticleState()
    data class Sliding(val directionX: Float, val directionY: Float) : ParticleState()
    object Gone : ParticleState()
}

/**
 * Core snowflake particle model
 * Ported from iOS Swift implementation
 */
data class Snowflake(
    var position: PointF,
    var velocity: PointF,
    val size: Float,
    val opacity: Float,
    var state: ParticleState = ParticleState.Falling
) {
    /**
     * Updates particle position based on current state
     * @param deltaTime Time elapsed since last update in seconds
     */
    fun update(deltaTime: Float) {
        when (val currentState = state) {
            is ParticleState.Falling -> {
                position.x += velocity.x * deltaTime
                position.y += velocity.y * deltaTime
            }
            is ParticleState.Stuck -> {
                // Don't move
            }
            is ParticleState.Sliding -> {
                position.x += currentState.directionX * deltaTime * 100f
                position.y += currentState.directionY * deltaTime * 100f
            }
            is ParticleState.Gone -> {
                // Don't move
            }
        }
    }

    /**
     * Checks if particle has moved offscreen
     */
    fun isOffscreen(screenHeight: Float, screenWidth: Float): Boolean {
        return position.y > screenHeight + size ||
               position.x < -size ||
               position.x > screenWidth + size
    }
}
