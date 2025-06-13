import UIKit
import MapKit

class VerificationViewController: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate {

    private let introLabel = UILabel()
    private let geoCamPrefixLabel = UILabel()
    private let deviceNumberField = UITextField()
    private let statusLabel = UILabel()
    private let selectButton = UIButton(type: .system)
    private let anotherButton = UIButton(type: .system)
    private let mapView = MKMapView()
    
    private let resetButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Start Over", for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .regular)
        button.addTarget(self, action: #selector(resetUI), for: .touchUpInside)
        button.isHidden = true
        return button
    }()

    private var selectedImage: UIImage?

    private var deviceIDStack: UIStackView!
    private var mainStack: UIStackView!

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        title = "Verify Image"
        setupUI()
    }

    private func setupUI() {
        // Intro label
        introLabel.text = "Please enter the GeoCam ID:"
        introLabel.font = .systemFont(ofSize: 16)
        introLabel.textAlignment = .center

        // Prefix label
        geoCamPrefixLabel.text = "GeoCam_"
        geoCamPrefixLabel.font = .systemFont(ofSize: 16)

        // Input field
        deviceNumberField.placeholder = "e.g. 1"
        deviceNumberField.borderStyle = .roundedRect
        deviceNumberField.keyboardType = .numberPad
        deviceNumberField.widthAnchor.constraint(equalToConstant: 80).isActive = true

        let toolbar = UIToolbar()
        toolbar.sizeToFit()
        let flex = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        let done = UIBarButtonItem(title: "Done", style: .done, target: self, action: #selector(dismissKeyboard))
        toolbar.setItems([flex, done], animated: false)
        deviceNumberField.inputAccessoryView = toolbar

        deviceIDStack = UIStackView(arrangedSubviews: [geoCamPrefixLabel, deviceNumberField])
        deviceIDStack.axis = .horizontal
        deviceIDStack.spacing = 5
        deviceIDStack.alignment = .center

        // Status label
        statusLabel.text = "Please select an image to verify."
        statusLabel.font = .systemFont(ofSize: 16)
        statusLabel.textAlignment = .center
        statusLabel.numberOfLines = 0

        // Buttons
        selectButton.setTitle("Select Image", for: .normal)
        selectButton.titleLabel?.font = .systemFont(ofSize: 18)
        selectButton.addTarget(self, action: #selector(selectImage), for: .touchUpInside)

        anotherButton.setTitle("Select Another Image", for: .normal)
        anotherButton.titleLabel?.font = .systemFont(ofSize: 18)
        anotherButton.addTarget(self, action: #selector(selectImage), for: .touchUpInside)
        anotherButton.isHidden = true

        // Map View
        mapView.translatesAutoresizingMaskIntoConstraints = false
        mapView.layer.cornerRadius = 10
        mapView.layer.borderColor = UIColor.lightGray.cgColor
        mapView.layer.borderWidth = 1
        mapView.isHidden = true

        mainStack = UIStackView(arrangedSubviews: [
            introLabel,
            deviceIDStack,
            statusLabel,
            selectButton,
            mapView,
            anotherButton,
            resetButton
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
            mapView.widthAnchor.constraint(equalToConstant: 300),
            mapView.heightAnchor.constraint(equalToConstant: 200)
        ])
    }

    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }

    @objc private func selectImage() {
        dismissKeyboard()
        let picker = UIImagePickerController()
        picker.delegate = self
        picker.sourceType = .photoLibrary
        present(picker, animated: true)
    }
    
    @objc private func resetUI() {
        selectedImage = nil
        deviceNumberField.text = ""
        
        introLabel.isHidden = false
        deviceIDStack.isHidden = false
        selectButton.isHidden = false
        anotherButton.isHidden = true
        resetButton.isHidden = true
        mapView.isHidden = true
        mapView.removeAnnotations(mapView.annotations)

        statusLabel.text = "Please select an image to verify."
    }
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        picker.dismiss(animated: true)

        guard let image = info[.originalImage] as? UIImage else {
            statusLabel.text = "Failed to load image."
            return
        }

        selectedImage = image
        selectButton.isHidden = true

        if let id = deviceNumberField.text, !id.isEmpty {
            verifyImage(image)
        } else {
            statusLabel.text = "Please enter a GeoCam ID and reselect the image."
            anotherButton.isHidden = false
        }
    }

    private func verifyImage(_ image: UIImage) {
        guard let id = deviceNumberField.text, !id.isEmpty else {
            statusLabel.text = "Please enter a valid GeoCam ID."
            return
        }

        let deviceID = "GeoCam_\(id)"
        statusLabel.text = "Verifying..."
        mapView.isHidden = true
        mapView.removeAnnotations(mapView.annotations)

        guard let data = image.pngData() else {
            statusLabel.text = "Failed to convert image."
            return
        }

        Task {
            do {
                let result = try await APIService.verifyImage(deviceUUID: deviceID, imageData: data)
                let message = result.decoded_message

                let rawTime = message.components(separatedBy: " | ").first ?? message
                let formatted = formatTimestamp(rawTime)

                statusLabel.text = "Verified on \(formatted)"

                // Handle location
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
                        mapView.setRegion(MKCoordinateRegion(center: coordinate, latitudinalMeters: 500, longitudinalMeters: 500), animated: true)
                        mapView.isHidden = false
                    }
                }

                introLabel.isHidden = true
                deviceIDStack.isHidden = true
                selectButton.isHidden = true
                anotherButton.isHidden = false
                resetButton.isHidden = false

            } catch {
                statusLabel.text = "API Error: \(error.localizedDescription)"
                anotherButton.isHidden = false
            }
        }
    }

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
}
