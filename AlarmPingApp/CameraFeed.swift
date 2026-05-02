import AVFoundation
import CoreGraphics
import Foundation

final class CameraFeed: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    private let session = AVCaptureSession()
    private let output = AVCaptureVideoDataOutput()
    private var continuation: AsyncStream<CGImage>.Continuation?

    func start() async throws -> AsyncStream<CGImage> {
        try await requestCameraPermission()
        try configureSession()
        session.startRunning()

        return AsyncStream { continuation in
            self.continuation = continuation
        }
    }

    func stop() {
        session.stopRunning()
        continuation?.finish()
    }

    private func requestCameraPermission() async throws {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            return
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            if !granted {
                throw NSError(domain: "CameraFeed", code: 403, userInfo: [NSLocalizedDescriptionKey: "Camera permission denied"])
            }
        default:
            throw NSError(domain: "CameraFeed", code: 403, userInfo: [NSLocalizedDescriptionKey: "Camera permission denied"])
        }
    }

    private func configureSession() throws {
        session.beginConfiguration()
        defer { session.commitConfiguration() }

        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) else {
            throw NSError(domain: "CameraFeed", code: 404, userInfo: [NSLocalizedDescriptionKey: "No front camera available"])
        }

        let input = try AVCaptureDeviceInput(device: device)
        if session.canAddInput(input) {
            session.addInput(input)
        }

        output.setSampleBufferDelegate(self, queue: DispatchQueue(label: "camera.feed.queue"))
        if session.canAddOutput(output) {
            session.addOutput(output)
        }
    }

    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let context = CIContext()
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else { return }
        continuation?.yield(cgImage)
    }
}
