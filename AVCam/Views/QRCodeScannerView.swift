import SwiftUI
import AVFoundation

struct QRCodeScannerView: UIViewControllerRepresentable {
    typealias Completion = (Result<String, Error>) -> Void
    var completion: Completion
    
    init(completion: @escaping Completion) {
            self.completion = completion
        }
    
    func makeUIViewController(context: Context) -> ScannerViewController {
        let vc = ScannerViewController()
        vc.completion = completion
        return vc
    }
    
    func updateUIViewController(_ uiViewController: ScannerViewController, context: Context) {}
    
    class ScannerViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
        var captureSession = AVCaptureSession()
        var previewLayer: AVCaptureVideoPreviewLayer!
        var completion: QRCodeScannerView.Completion?
        
        override func viewDidLoad() {
            super.viewDidLoad()
            view.backgroundColor = .black
            
            guard let videoCaptureDevice = AVCaptureDevice.default(for: .video),
                  let videoInput = try? AVCaptureDeviceInput(device: videoCaptureDevice),
                  captureSession.canAddInput(videoInput) else {
                completion?(.failure(NSError(domain: "Camera error", code: 0)))
                return
            }
            
            captureSession.addInput(videoInput)
            
            let metadataOutput = AVCaptureMetadataOutput()
            if captureSession.canAddOutput(metadataOutput) {
                captureSession.addOutput(metadataOutput)
                metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
                metadataOutput.metadataObjectTypes = [.qr]
            }
            
            previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
            previewLayer.frame = view.layer.bounds
            previewLayer.videoGravity = .resizeAspectFill
            view.layer.addSublayer(previewLayer)
        }
        
        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            
            // Start session on background thread here
            DispatchQueue.global(qos: .userInitiated).async {
                if !self.captureSession.isRunning {
                    self.captureSession.startRunning()
                }
            }
        }
        
        override func viewWillDisappear(_ animated: Bool) {
            super.viewWillDisappear(animated)
            DispatchQueue.global(qos: .background).async {
                if self.captureSession.isRunning {
                    self.captureSession.stopRunning()
                }
            }
        }
        
        func metadataOutput(_ output: AVCaptureMetadataOutput,
                            didOutput metadataObjects: [AVMetadataObject],
                            from connection: AVCaptureConnection) {
            if let metadata = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
               metadata.type == AVMetadataObject.ObjectType.qr,
               let string = metadata.stringValue {
                DispatchQueue.global(qos: .background).async {
                    self.captureSession.stopRunning()
                }
                
                completion?(.success(string))
                dismiss(animated: true)
            }
        }
    }
}
