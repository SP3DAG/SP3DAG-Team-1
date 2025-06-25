import UIKit
import MapKit
import NVActivityIndicatorView

class VerificationViewController: UIViewController,
                                  UIImagePickerControllerDelegate,
                                  UINavigationControllerDelegate {

    // MARK: – UI elements
    private let statusLabel   = UILabel()
    private let selectButton  = UIButton(type: .system)
    private let anotherButton = UIButton(type: .system)
    private let mapView       = MKMapView()

    /// Three-dot animation displayed while we’re awaiting the API response
    private lazy var pulseIndicator: NVActivityIndicatorView = {
        let side: CGFloat = 24
        let indicator = NVActivityIndicatorView(
            frame: CGRect(x: 0, y: 0, width: side, height: side),
            type: .ballPulseSync,
            color: .label,
            padding: 0
        )
        indicator.translatesAutoresizingMaskIntoConstraints = false
        indicator.isHidden = true          // start hidden until we need it
        return indicator
    }()

    // We’ll group the label and the indicator horizontally
    private var statusStack: UIStackView!
    private var mainStack  : UIStackView!

    private var selectedImage: UIImage?

    // MARK: – View lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        title = "Verify Image"
        setupUI()
    }

    // MARK: – UI setup
    private func setupUI() {
        // Status label
        statusLabel.text = "Please select an image to verify."
        statusLabel.font = .systemFont(ofSize: 16)
        statusLabel.textAlignment = .center
        statusLabel.numberOfLines = 0

        // Label + dots horizontally
        statusStack = UIStackView(arrangedSubviews: [statusLabel, pulseIndicator])
        statusStack.axis = .horizontal
        statusStack.spacing = 8
        statusStack.alignment = .center

        // Select button
        selectButton.setTitle("Select Image", for: .normal)
        selectButton.titleLabel?.font = .systemFont(ofSize: 18)
        selectButton.addTarget(self, action: #selector(selectImage), for: .touchUpInside)

        // Another-image button (hidden until first verify completes)
        anotherButton.setTitle("Select Another Image", for: .normal)
        anotherButton.titleLabel?.font = .systemFont(ofSize: 18)
        anotherButton.addTarget(self, action: #selector(selectImage), for: .touchUpInside)
        anotherButton.isHidden = true

        // MapView for geo tag
        mapView.translatesAutoresizingMaskIntoConstraints = false
        mapView.layer.cornerRadius = 10
        mapView.layer.borderColor = UIColor.lightGray.cgColor
        mapView.layer.borderWidth  = 1
        mapView.isHidden = true

        // Vertical stack
        mainStack = UIStackView(arrangedSubviews: [
            statusStack,
            selectButton,
            mapView,
            anotherButton
        ])
        mainStack.axis = .vertical
        mainStack.spacing = 20
        mainStack.alignment = .center
        mainStack.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(mainStack)

        NSLayoutConstraint.activate([
            mainStack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            mainStack.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            mainStack.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 20),
            mainStack.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -20),

            // keep the indicator square
            pulseIndicator.widthAnchor.constraint(equalToConstant: 24),
            pulseIndicator.heightAnchor.constraint(equalTo: pulseIndicator.widthAnchor),

            mapView.widthAnchor .constraint(equalToConstant: 300),
            mapView.heightAnchor.constraint(equalToConstant: 200)
        ])
    }

    // MARK: – Image Picker
    @objc private func selectImage() {
        let picker = UIImagePickerController()
        picker.delegate = self
        picker.sourceType = .photoLibrary
        present(picker, animated: true)
    }

    func imagePickerController(_ picker: UIImagePickerController,
                               didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        picker.dismiss(animated: true)

        guard let image = info[.originalImage] as? UIImage else {
            updateStatus("Failed to load image.", state: .error)
            return
        }

        selectedImage = image
        selectButton.isHidden = true
        verifyImage(image)
    }

    // MARK: – Verification

    private func verifyImage(_ image: UIImage) {
        updateStatus("Verifying", state: .idle)
        setVerifying(true)

        // reset map
        mapView.isHidden = true
        mapView.removeAnnotations(mapView.annotations)

        guard let data = image.pngData() else {
            setVerifying(false)
            updateStatus("Failed to convert image.", state: .error)
            return
        }

        Task {
            do {
                let result = try await APIService.verifyImage(imageData: data)
                setVerifying(false)

                // Parse the API’s decoded_message
                let message   = result.decoded_message
                let rawTime   = message.components(separatedBy: " | ").first ?? message
                let formatted = formatTimestamp(rawTime)
                updateStatus("Verified on \(formatted)", state: .success)

                // Pull out “Location: lat,lon” if present
                if let locRange = message.range(of: "Location: ") {
                    let coordsString = message[locRange.upperBound...].trimmingCharacters(in: .whitespaces)
                    let parts = coordsString.split(separator: ",")
                    if parts.count == 2,
                       let lat = Double(parts[0].trimmingCharacters(in: .whitespaces)),
                       let lon = Double(parts[1].trimmingCharacters(in: .whitespaces)) {
                        let coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)
                        let annotation = MKPointAnnotation()
                        annotation.coordinate = coordinate
                        annotation.title = "Captured Location"
                        mapView.addAnnotation(annotation)
                        mapView.setRegion(
                            MKCoordinateRegion(center: coordinate,
                                               latitudinalMeters: 500,
                                               longitudinalMeters: 500),
                            animated: true
                        )
                        mapView.isHidden = false
                    }
                }

                anotherButton.isHidden = false

            } catch {
                setVerifying(false)
                updateStatus(error.localizedDescription, state: .error)
                anotherButton.isHidden = false
            }
        }
    }

    // Helper: show / hide the three-dot animation
    private func setVerifying(_ active: Bool) {
        pulseIndicator.isHidden = !active
        active ? pulseIndicator.startAnimating()
               : pulseIndicator.stopAnimating()
    }

    // MARK: – Timestamp formatting
    private func formatTimestamp(_ text: String) -> String {
        let prefix = "Captured at: "
        guard text.hasPrefix(prefix) else { return text }
        let timestamp = String(text.dropFirst(prefix.count))

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss 'GMT'Z"
        formatter.locale = Locale(identifier: "en_US_POSIX")

        if let date = formatter.date(from: timestamp) {
            let output = DateFormatter()
            output.dateStyle = .long
            output.timeStyle = .short
            return output.string(from: date)
        }
        return text
    }

    // MARK: – Status Handling
    private enum VerificationState {
        case idle, success, error
    }

    private func updateStatus(_ message: String, state: VerificationState) {
        statusLabel.text = message
        switch state {
        case .idle:    statusLabel.textColor = .label
        case .success: statusLabel.textColor = .systemBlue
        case .error:   statusLabel.textColor = .systemRed
        }
    }
}
