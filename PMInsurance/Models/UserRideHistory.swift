import Foundation
import CoreLocation

/// One day of PM ride summary for a single user. 7-day demo seed.
struct DailyRide: Identifiable, Sendable {
    let id: Int            // 0 = oldest, 6 = yesterday
    let dayLabel: String   // Korean weekday (월/화/수/...)
    let distanceKm: Double
    let pmShare: Double    // %, 0~100
    let rs: Double         // 0~100
    let nightRatio: Double // %, 0~100
    let tripCount: Int
    let sidewalkAlerts: Int
}

/// PM ride seed for the live demo. Holds the 7-day distribution,
/// yesterday's path, and the sidewalk hotspots. The schema can later
/// be populated from a real PM API.
enum UserRideHistory {

    static let last7Days: [DailyRide] = [
        .init(id: 0, dayLabel: "월", distanceKm: 4.8,  pmShare: 55, rs: 72, nightRatio: 14, tripCount: 2, sidewalkAlerts: 0),
        .init(id: 1, dayLabel: "화", distanceKm: 6.2,  pmShare: 64, rs: 78, nightRatio: 11, tripCount: 3, sidewalkAlerts: 0),
        .init(id: 2, dayLabel: "수", distanceKm: 3.1,  pmShare: 48, rs: 65, nightRatio: 22, tripCount: 2, sidewalkAlerts: 1),
        .init(id: 3, dayLabel: "목", distanceKm: 7.5,  pmShare: 70, rs: 81, nightRatio: 9,  tripCount: 4, sidewalkAlerts: 0),
        .init(id: 4, dayLabel: "금", distanceKm: 5.6,  pmShare: 58, rs: 74, nightRatio: 16, tripCount: 3, sidewalkAlerts: 0),
        .init(id: 5, dayLabel: "토", distanceKm: 9.4,  pmShare: 78, rs: 88, nightRatio: 8,  tripCount: 5, sidewalkAlerts: 0),
        .init(id: 6, dayLabel: "일", distanceKm: 6.3,  pmShare: 62, rs: 78, nightRatio: 13, tripCount: 3, sidewalkAlerts: 1),
    ]

    static var weeklyRSValues: [Int] {
        last7Days.map { Int($0.rs) }
    }
    static var weeklyDayLabels: [String] {
        last7Days.map(\.dayLabel)
    }
    static var averageRS: Double {
        last7Days.reduce(0) { $0 + $1.rs } / Double(last7Days.count)
    }
    static var averagePMShare: Double {
        last7Days.reduce(0) { $0 + $1.pmShare } / Double(last7Days.count)
    }
    static var averageNightRatio: Double {
        last7Days.reduce(0) { $0 + $1.nightRatio } / Double(last7Days.count)
    }
    static var totalDistanceKm: Double {
        last7Days.reduce(0) { $0 + $1.distanceKm }
    }
    static var totalSidewalkAlerts: Int {
        last7Days.reduce(0) { $0 + $1.sidewalkAlerts }
    }
    static var totalTripCount: Int {
        last7Days.reduce(0) { $0 + $1.tripCount }
    }

    /// CLLocationCoordinate2D is Sendable on iOS 17+.
    static let yesterdayPath: [CLLocationCoordinate2D] = [
        .init(latitude: 37.3219, longitude: 127.1262),  // Dankook Univ. main gate
        .init(latitude: 37.3221, longitude: 127.1240),
        .init(latitude: 37.3224, longitude: 127.1218),
        .init(latitude: 37.3227, longitude: 127.1196),
        .init(latitude: 37.3229, longitude: 127.1174),
        .init(latitude: 37.3230, longitude: 127.1152),
        .init(latitude: 37.3231, longitude: 127.1130),
        .init(latitude: 37.3232, longitude: 127.1108),
        .init(latitude: 37.3232, longitude: 127.1090),  // Jukjeon station
    ]

    /// Sidewalk-entry hotspots. Two synthetic points along the path.
    static let sidewalkHotspots: [SidewalkHotspot] = [
        .init(id: 0, coordinate: .init(latitude: 37.3227, longitude: 127.1196), reason: "보도 진입 12초"),
        .init(id: 1, coordinate: .init(latitude: 37.3231, longitude: 127.1130), reason: "보도 진입 8초"),
    ]

    /// Initial map center.
    static let mapCenter: CLLocationCoordinate2D = .init(latitude: 37.3226, longitude: 127.1175)
    static let mapSpanDegrees: Double = 0.006
}

struct SidewalkHotspot: Identifiable, Sendable {
    let id: Int
    let coordinate: CLLocationCoordinate2D
    let reason: String
}
