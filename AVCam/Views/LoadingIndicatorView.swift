import SwiftUI
import NVActivityIndicatorView

struct LoadingIndicatorView: UIViewRepresentable {
    var size: CGFloat = 60
    var color: UIColor = .white
    var type: NVActivityIndicatorType = .ballScaleMultiple

    func makeUIView(context: Context) -> NVActivityIndicatorView {
        let view = NVActivityIndicatorView(
            frame: CGRect(x: 0, y: 0, width: size, height: size),
            type: type,
            color: color,
            padding: 0
        )
        view.startAnimating()
        return view
    }

    func updateUIView(_ uiView: NVActivityIndicatorView, context: Context) {}
}
