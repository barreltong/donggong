import SwiftUI
import UIKit

/// One reader page, or a two-page spread, with pinch zoom and pan.
///
/// UIScrollView supplies the zoom so it composes with the SwiftUI paging scroll
/// view the way nested UIKit scroll views do: at rest it lets pans through to the
/// pager, and while zoomed it pans until an edge before the pager takes over.
struct ZoomableImageView: UIViewRepresentable {
    let images: [UIImage?]
    /// Changing this value returns the page to fit, so a revisited page never keeps an old zoom.
    let resetToken: Int
    let onTap: () -> Void

    func makeUIView(context: Context) -> ZoomScrollView {
        let view = ZoomScrollView()
        view.onTap = onTap
        view.resetToken = resetToken
        view.setImages(images)
        return view
    }

    func updateUIView(_ view: ZoomScrollView, context: Context) {
        view.onTap = onTap
        view.setImages(images)
        if view.resetToken != resetToken {
            view.resetToken = resetToken
            view.setZoomScale(view.minimumZoomScale, animated: false)
        }
    }
}

final class ZoomScrollView: UIScrollView, UIScrollViewDelegate {
    var onTap: (() -> Void)?
    var resetToken = 0

    private let stack = UIStackView()
    private var lastBoundsSize = CGSize.zero

    init() {
        super.init(frame: .zero)
        delegate = self
        minimumZoomScale = 1
        maximumZoomScale = 5
        bouncesZoom = true
        showsHorizontalScrollIndicator = false
        showsVerticalScrollIndicator = false
        contentInsetAdjustmentBehavior = .never
        decelerationRate = .fast
        backgroundColor = .clear

        stack.axis = .horizontal
        stack.distribution = .fillEqually
        stack.alignment = .fill
        addSubview(stack)

        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        addGestureRecognizer(tap)
    }

    required init?(coder: NSCoder) {
        nil
    }

    func setImages(_ images: [UIImage?]) {
        let views = stack.arrangedSubviews.compactMap { $0 as? UIImageView }
        if views.count != images.count {
            views.forEach { $0.removeFromSuperview() }
            for image in images {
                let imageView = UIImageView(image: image)
                imageView.contentMode = .scaleAspectFit
                imageView.clipsToBounds = true
                stack.addArrangedSubview(imageView)
            }
        } else {
            for (imageView, image) in zip(views, images) where imageView.image !== image {
                imageView.image = image
            }
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        if bounds.size != lastBoundsSize {
            lastBoundsSize = bounds.size
            zoomScale = minimumZoomScale
            stack.frame = CGRect(origin: .zero, size: bounds.size)
            contentSize = bounds.size
        }
    }

    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        stack
    }

    @objc private func handleTap() {
        onTap?()
    }
}
