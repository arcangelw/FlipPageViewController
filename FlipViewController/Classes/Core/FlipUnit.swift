//
//  FlipUnit.swift
//  FlipViewController
//
//  Created by 吴哲 on 2023/5/18.
//

import Foundation
import QuartzCore
import UIKit

// swiftlint:disable line_length identifier_name

/// flip unit
enum Flip {
    /// https://stackoverflow.com/questions/12947925/how-to-flip-between-views-like-flipboard-animation-in-ios/26266025#26266025
    static func CATransform3DMakePerspective(_: CGPoint, _ z: CGFloat) -> CATransform3D {
        var transform = CATransform3DIdentity
        transform.m34 = 1.0 / -z
        return transform
    }

    /// 三维透视
    static func CATransform3DPerspect(_ t: CATransform3D, _ center: CGPoint, _ z: CGFloat) -> CATransform3D {
        return CATransform3DConcat(t, Flip.CATransform3DMakePerspective(center, z))
    }

    /// 三维透视
    static func CATransform3DPerspectSimple(_ t: CATransform3D) -> CATransform3D {
        return Flip.CATransform3DPerspect(t, .zero, 1500.0)
    }

    /// 三维透视简单带旋转
    static func CATransform3DPerspectSimpleWithRotate(_ degree: CGFloat) -> CATransform3D {
        return Flip.CATransform3DPerspectSimple(CATransform3DMakeRotation(degree * .pi / 180.0, 1, 0, 0))
    }

    /// 配置渐变
    static func setGradient(at context: CGContext, in rect: CGRect) {
        context.saveGState()
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let locations: [CGFloat] = [0.0, 1.0]
        let components: [CGFloat] = [
            1.0, 1.0, 1.0, 0.8,
            0.3, 0.3, 0.3, 1.0
        ]
        guard
            let gradient = CGGradient(colorSpace: colorSpace, colorComponents: components, locations: locations, count: locations.count)
        else { return }
        let startPoint = CGPoint(x: rect.size.width / 2.0, y: rect.size.height / 3.0)
        let startRadius = 0.0
        let endRadius = rect.size.height
        context.drawRadialGradient(
            gradient, startCenter: startPoint, startRadius: startRadius, endCenter: startPoint, endRadius: endRadius, options: .drawsAfterEndLocation
        )
        context.restoreGState()
    }

    /// 绘制图片
    static func lineRadialImage(_ rect: CGRect) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 0
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(bounds: rect, format: format)
        let image = renderer.image {
            self.setGradient(at: $0.cgContext, in: rect)
        }
        return image
    }

    /// 剪切图片
    static func makeImage(_ image: UIImage, in rect: CGRect) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 0
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(bounds: rect, format: format)
        let image = renderer.image { _ in
            image.draw(at: .zero)
        }
        return image
    }

    /// 分割图片
    static func makeHsplitImages(_ image: UIImage) -> [UIImage] {
        let rect = CGRect(origin: .zero, size: image.size)
        let topRect = CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: rect.midY)
        let bottomRect = CGRect(x: rect.minX, y: rect.midY, width: rect.width, height: rect.midY)
        let topImage = makeImage(image, in: topRect)
        let bottomImage = makeImage(image, in: bottomRect)
        return [topImage, bottomImage]
    }

    /// 截图
    static func makeImage(_ view: UIView, in rect: CGRect) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 0
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(bounds: rect, format: format)
        let image = renderer.image { _ in
            view.drawHierarchy(in: view.bounds, afterScreenUpdates: true)
        }
        return image
    }

    /// 页面切片
    static func makeHsplitImages(_ view: UIView) -> [UIImage] {
        return makeHsplitImages(makeImage(view, in: view.bounds))
    }

    /// pods bundle
    private static var podsBundle: Bundle? = {
        let bundle = Bundle(for: FlipView.self)
        guard let url = bundle.url(forResource: "FlipViewController", withExtension: "bundle") else {
            return nil
        }
        return Bundle(url: url)
    }()

    /// 获取资源图片
    static func image(named: String) -> UIImage? {
        return .init(named: named, in: podsBundle, compatibleWith: nil)
    }
}

extension UIScrollView {
    /// 是否在最顶端
    var isScrollToTop: Bool {
        return contentOffset.y == -adjustedContentInset.top
    }

    /// 滑动到底部
    func scrollToBottom() {
        setContentOffset(
            CGPoint(x: contentOffset.x, y: max(0, contentSize.height - bounds.height) + adjustedContentInset.bottom),
            animated: false
        )
    }
}

// swiftlint:enable line_length identifier_name
