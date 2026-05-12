import SwiftUI
import MapKit
import CoreLocation

struct MiniMapCard: View {
    let path: [CLLocationCoordinate2D]
    let hotspots: [SidewalkHotspot]
    let center: CLLocationCoordinate2D
    let spanDegrees: Double

    private var initialRegion: MKCoordinateRegion {
        MKCoordinateRegion(
            center: center,
            span: MKCoordinateSpan(latitudeDelta: spanDegrees, longitudeDelta: spanDegrees)
        )
    }

    var body: some View {
        Map(initialPosition: .region(initialRegion), interactionModes: []) {
            MapPolyline(coordinates: path)
                .stroke(
                    LinearGradient(colors: [.iosBlue, Color(hex: "60A5FA")], startPoint: .leading, endPoint: .trailing),
                    style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round)
                )

            if let start = path.first {
                Annotation("출발", coordinate: start, anchor: .center) {
                    endpointDot(color: .zoneI)
                }
                .annotationTitles(.hidden)
            }
            if let end = path.last {
                Annotation("도착", coordinate: end, anchor: .center) {
                    endpointDot(color: .zoneII)
                }
                .annotationTitles(.hidden)
            }

            ForEach(hotspots) { hotspot in
                Annotation(hotspot.reason, coordinate: hotspot.coordinate, anchor: .center) {
                    SidewalkMarker()
                }
                .annotationTitles(.hidden)
            }
        }
        .mapStyle(.standard(elevation: .flat, emphasis: .muted, pointsOfInterest: .excludingAll))
        .frame(height: 220)
        .clipShape(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                .strokeBorder(.white.opacity(0.10), lineWidth: 1)
        )
    }

    private func endpointDot(color: Color) -> some View {
        ZStack {
            Circle()
                .fill(color)
                .frame(width: 14, height: 14)
            Circle()
                .strokeBorder(.white, lineWidth: 2)
                .frame(width: 14, height: 14)
        }
        .shadow(color: .black.opacity(0.4), radius: 4)
    }
}

private struct SidewalkMarker: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(Color.iosRed)
                .frame(width: 22, height: 22)
            Circle()
                .strokeBorder(.white, lineWidth: 2)
                .frame(width: 22, height: 22)
            Image(systemName: "exclamationmark")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.white)
        }
        .shadow(color: Color.iosRed.opacity(0.5), radius: 5)
    }
}
