//
//  SnowEffectView.swift
//  SnowTeeth
//
//  SwiftUI view for rendering snow particles
//

import SwiftUI

struct SnowEffectView: View {
    @ObservedObject var snowEffect: SnowEffect

    var body: some View {
        GeometryReader { geometry in
            Canvas { context, size in
                // Draw fallen snow from all surface height maps
                let surfaceMaps = snowEffect.getSurfaceSnowMaps()
                for (surfaceId, surfaceMap) in surfaceMaps {
                    let heights = surfaceMap.getHeights()
                    for heightData in heights {
                        let x = heightData.x
                        let height = heightData.height
                        let baselineY = heightData.baselineY
                        let topY = baselineY - height

                        // Draw a vertical line representing accumulated snow at this x coordinate
                        // For ground, draw to bottom of screen; for other surfaces, draw just the height
                        let bottomY = surfaceId == "ground" ? size.height : baselineY
                        let path = Path { p in
                            p.move(to: CGPoint(x: x, y: topY))
                            p.addLine(to: CGPoint(x: x, y: bottomY))
                        }
                        context.stroke(path, with: .color(.white), lineWidth: 1)
                    }
                }

                // Draw all snowflakes (centered at position)
                for snowflake in snowEffect.snowflakes {
                    let halfSize = snowflake.size / 2
                    let rect = CGRect(
                        x: snowflake.position.x - halfSize,
                        y: snowflake.position.y - halfSize,
                        width: snowflake.size,
                        height: snowflake.size
                    )

                    context.fill(
                        Circle().path(in: rect),
                        with: .color(.white.opacity(Double(snowflake.opacity)))
                    )
                }
            }
            .onAppear {
                snowEffect.setScreenSize(geometry.size)
            }
            .onChange(of: geometry.size) { oldSize, newSize in
                snowEffect.setScreenSize(newSize)
            }
        }
        .allowsHitTesting(false) // Let touches pass through to UI below
    }
}
