import AVFoundation
import Foundation
import SwiftUI

@MainActor
final class AlarmGatekeeper: ObservableObject {
    enum AlarmState {
        case idle
        case ringing
        case unlocked
    }

    @Published var alarmState: AlarmState = .idle
    @Published var requiredPlankSeconds: Int = 20
    @Published var completedPlankSeconds: Int = 0
    @Published var statusText: String = "Alarm locked"

    private var timerTask: Task<Void, Never>?
    private let detector = PlankDetector()

    func startAlarm() {
        completedPlankSeconds = 0
        statusText = "Alarm ringing. Hold a plank to stop it."
        alarmState = .ringing
    }

    func stopAlarmIfUnlocked() {
        guard alarmState == .unlocked else { return }
        AlarmScheduler.cancelAlarm()
        statusText = "Alarm stopped"
        completedPlankSeconds = 0
        alarmState = .idle
    }

    func startPlankVerification(cameraFrames: AsyncStream<CGImage>) {
        guard alarmState == .ringing else { return }
        timerTask?.cancel()

        timerTask = Task {
            do {
                for await frame in cameraFrames {
                    if Task.isCancelled { return }
                    let isPlank = try await detector.detectPlank(in: frame)

                    if isPlank {
                        completedPlankSeconds += 1
                        statusText = "Plank detected: \(completedPlankSeconds)/\(requiredPlankSeconds)s"
                    } else {
                        if completedPlankSeconds > 0 {
                            completedPlankSeconds -= 1
                        }
                        statusText = "Hold steady plank posture..."
                    }

                    if completedPlankSeconds >= requiredPlankSeconds {
                        statusText = "Great job! Alarm unlocked."
                        alarmState = .unlocked
                        return
                    }

                    try await Task.sleep(for: .seconds(1))
                }
            } catch {
                statusText = "Plank detection failed: \(error.localizedDescription)"
            }
        }
    }
}
