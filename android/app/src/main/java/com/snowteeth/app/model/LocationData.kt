package com.snowteeth.app.model

data class LocationData(
    val latitude: Double,
    val longitude: Double,
    val altitude: Double,
    val timestamp: Long,
    val speed: Float, // meters per second
    val horizontalAccuracy: Float = -1.0f, // meters
    val verticalAccuracy: Float = -1.0f // meters
)
