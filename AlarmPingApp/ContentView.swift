import SwiftUI

struct ContentView: View {
    @State private var selectedTime: Date = .now
    @StateObject private var gatekeeper = AlarmGatekeeper()
    @State private var cameraFeed = CameraFeed()

    var body: some View {
        NavigationStack {
            Form {
                DatePicker("Alarm time", selection: $selectedTime, displayedComponents: .hourAndMinute)
                    .datePickerStyle(.wheel)

                Stepper("Required plank: \(gatekeeper.requiredPlankSeconds) sec", value: $gatekeeper.requiredPlankSeconds, in: 5...120, step: 5)

                Button("Set Daily Alarm") {
                    Task {
                        await setAlarm()
                    }
                }

                if gatekeeper.alarmState == .ringing {
                    Button("Start Plank Check") {
                        Task {
                            do {
                                let frames = try await cameraFeed.start()
                                gatekeeper.startPlankVerification(cameraFrames: frames)
                            } catch {
                                gatekeeper.statusText = "Camera error: \(error.localizedDescription)"
                            }
                        }
                    }
                }

                Button("Stop Alarm") {
                    gatekeeper.stopAlarmIfUnlocked()
                }
                .disabled(gatekeeper.alarmState != .unlocked)

                Button("Simulate Alarm Ring") {
                    gatekeeper.startAlarm()
                }

                Section("Status") {
                    Text(gatekeeper.statusText)
                }
            }
            .navigationTitle("Alarm Ping")
        }
    }

    private func setAlarm() async {
        let components = Calendar.current.dateComponents([.hour, .minute], from: selectedTime)
        guard let hour = components.hour, let minute = components.minute else {
            gatekeeper.statusText = "Couldn't read selected time"
            return
        }

        do {
            try await AlarmScheduler.scheduleAlarm(hour: hour, minute: minute)
            gatekeeper.statusText = String(format: "Daily alarm set for %02d:%02d", hour, minute)
        } catch {
            gatekeeper.statusText = "Failed to set alarm: \(error.localizedDescription)"
        }
    }
}

#Preview {
    ContentView()
}
