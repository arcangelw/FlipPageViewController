//
//  FlipLayer.swift
//  FlipViewController
//
//  Created by 吴哲 on 2023/5/17.
//

import QuartzCore
import UIKit

extension FlipLayer {
    /// 位置
    enum Position {
        case front
        case back
    }

    /// 常量
    private enum Constants {
        /// 动画key
        static let flipAnimationKey = "flip-animation"
        /// 旋转key
        static let rotateDegreeKey = "rotateDegree"
    }
}

extension FlipLayer {
    /// 背景图缓存
    static var imageCache: [String: [UIImage]] = [:]
    /// 配置背景图
    static func sharedBackgroundImages(_ rect: CGRect) -> [UIImage] {
        let key = String(reflecting: rect)
        if let cache = imageCache[key] {
            return cache
        } else {
            let image = Flip.lineRadialImage(rect)
            let images = Flip.makeHsplitImages(image)
            imageCache[key] = images
            return images
        }
    }
}

extension FlipLayer {
    /// 截屏镜像
    private class SnapshotLayer: CALayer {
        /// 渐变层
        private lazy var gradientLayer = CAGradientLayer()
        /// 截图内容
        private lazy var contentsLayer = CALayer()
        /// 阴影蒙层
        private lazy var shadowMaskLayer = CALayer()
        /// 快照视图
        private var snapshotView: UIView? {
            didSet {
                oldValue?.layer.removeFromSuperlayer()
                guard let snapshotView = snapshotView else { return }
                snapshotView.layer.frame = snapshotView.bounds
                insertSublayer(snapshotView.layer, below: shadowMaskLayer)
            }
        }

        /// 设置内容截图
        var hasContents: Bool = false {
            didSet {
                if hasContents {
                    contentsLayer.frame = bounds
                    insertSublayer(contentsLayer, below: shadowMaskLayer)
                } else {
                    contentsLayer.removeFromSuperlayer()
                }
            }
        }

        /// 阴影蒙层不透明度
        var shadowMaskOpacity: Float = 0 {
            didSet {
                guard oldValue != shadowMaskOpacity else { return }
                shadowMaskLayer.opacity = shadowMaskOpacity
            }
        }

        /// 设置截屏
        func setSnapshotContents(_ contents: CGImage?) {
            CATransaction.setValue(true, forKey: kCATransactionDisableActions)
            contentsLayer.contents = contents
            hasContents = contents != nil
        }

        /// 设置截屏
        func setSnapshotView(_ view: UIView?) {
            CATransaction.setValue(true, forKey: kCATransactionDisableActions)
            snapshotView = view
        }

        /// 清理快照
        func clearSnapshot() {
            hasContents = false
            contentsLayer.contents = nil
            snapshotView = nil
        }

        // MARK: - init

        /// 初始化位置
        /// - Parameter position: 展示位置
        init(position: Position, frame: CGRect) {
            super.init()
            self.frame = frame
            masksToBounds = true
            backgroundColor = UIColor.white.cgColor
            isDoubleSided = false
            var gradientColors = [
                UIColor.black.withAlphaComponent(0.3),
                UIColor.black.withAlphaComponent(0.6)
            ].map(\.cgColor)
            switch position {
            case .front:
                name = "frontLayer"

            case .back:
                gradientColors.reverse()
                name = "backLayer"
            }
            gradientLayer.locations = [0, 1]
            gradientLayer.colors = gradientColors
            gradientLayer.startPoint = .init(x: 0.5, y: 0)
            gradientLayer.endPoint = .init(x: 0.5, y: 1)
            gradientLayer.frame = bounds
            addSublayer(gradientLayer)
            shadowMaskLayer.opacity = 0
            shadowMaskLayer.backgroundColor = UIColor.black.withAlphaComponent(0.5).cgColor
            shadowMaskLayer.frame = bounds
            addSublayer(shadowMaskLayer)
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override class func defaultAction(forKey event: String) -> CAAction? {
            return NSNull()
        }
    }
}

// swiftlint:disable line_length

final class FlipLayer: CATransformLayer, CAAnimationDelegate {

    /// 动画被取消
    private var isAnimationCancelled: Bool = false

    /// 前置页
    private let frontLayer: SnapshotLayer
    /// 后置页
    private let backLayer: SnapshotLayer

    /// 是否配置页面内容
    var hasFrontContents: Bool {
        return frontLayer.hasContents
    }

    var hasBackContents: Bool {
        return backLayer.hasContents
    }

    /// 翻转角度
    /// 起始位置是在底部，所以在底部时0度，翻转到上面时变成180度
    @NSManaged
    var rotateDegree: CGFloat

    init(frame: CGRect) {
        frontLayer = .init(position: .front, frame: .init(origin: .zero, size: frame.size))
        backLayer = .init(position: .back, frame: .init(origin: .zero, size: frame.size))
        super.init()
        self.frame = frame
        isDoubleSided = true
        anchorPoint = .init(x: 0.5, y: 0)
        position = .init(x: position.x, y: position.y - frame.height / 2.0)

        /// 正面不反转 扎实
        /// 背面图层反转180度 承载下一页上半部分
        backLayer.transform = Flip.CATransform3DPerspectSimpleWithRotate(180.0)
        addSublayer(backLayer)
        addSublayer(frontLayer)
    }

    override init(layer: Any) {
        let size = (layer as? CALayer)?.frame.size ?? .zero
        frontLayer = .init(position: .front, frame: .init(origin: .zero, size: size))
        backLayer = .init(position: .back, frame: .init(origin: .zero, size: size))
        super.init(layer: layer)
        guard let layer = layer as? FlipLayer else {
            return
        }
        rotateDegree = layer.rotateDegree
        isAnimationCancelled = layer.isAnimationCancelled
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Animation

    override class func defaultValue(forKey key: String) -> Any? {
        switch key {
        case #keyPath(rotateDegree):
            return nil
        default:
            return super.defaultValue(forKey: key)
        }
    }

    override func action(forKey event: String) -> CAAction? {
        switch event {
        case #keyPath(rotateDegree):
            let flipAnimation = CABasicAnimation(keyPath: event)
            flipAnimation.fillMode = .both
            flipAnimation.beginTime = convertTime(CACurrentMediaTime(), from: nil)
            flipAnimation.duration = 0
            flipAnimation.fromValue = presentation()?.rotateDegree
            flipAnimation.toValue = rotateDegree
            flipAnimation.isRemovedOnCompletion = true
            return flipAnimation
        default:
            return super.action(forKey: event)
        }
    }

    override class func needsDisplay(forKey key: String) -> Bool {
        guard key == #keyPath(rotateDegree) else {
            return super.needsDisplay(forKey: key)
        }
        return true
    }

    override func shouldArchiveValue(forKey key: String) -> Bool {
        switch key {
        case #keyPath(rotateDegree):
            return true
        default:
            return super.shouldArchiveValue(forKey: key)
        }
    }

    override func display() {
        CATransaction.setValue(true, forKey: kCATransactionDisableActions)
        let rotateDegree = presentation()?.rotateDegree ?? rotateDegree
        fixLayerFlashing(rotateDegree)
        transform = Flip.CATransform3DPerspectSimpleWithRotate(rotateDegree)
    }

    // TODO: - 之后如有需求，需要优化Layer层级
    /// 层级控制 iOS15以上系统在翻转时 isDoubleSided 层级闪烁
    /// 通过翻转角度隐藏不在可视范围的layer层级来暂时处理
    private func fixLayerFlashing(_ rotateDegree: CGFloat) {
        // frontLayer.isHidden = rotateDegree >= 90
        // backLayer.isHidden = rotateDegree <= 90
    }

    /// 配置反转角度
    /// - Parameters:
    ///   - rotateDegree: 角度
    ///   - duration: 动画时间
    ///   - delay: 延时
    ///   - completion: 动画结束回调
    func setRotateDegree(_ rotateDegree: CGFloat, duration: CGFloat, delay: TimeInterval, completion: (() -> Void)? = nil) {
        guard animation(forKey: Constants.flipAnimationKey) == nil else { return }

        CATransaction.begin()
        let flipAnimation = CABasicAnimation(keyPath: Constants.rotateDegreeKey)
        CATransaction.setValue(true, forKey: kCATransactionDisableActions)
        flipAnimation.delegate = self
        flipAnimation.duration = duration
        flipAnimation.fillMode = .both
        flipAnimation.beginTime = convertTime(CACurrentMediaTime(), from: nil) + delay
        flipAnimation.toValue = rotateDegree
        flipAnimation.fromValue = self.rotateDegree
        flipAnimation.isRemovedOnCompletion = true
        CATransaction.setCompletionBlock {
            if self.isAnimationCancelled {
                self.isAnimationCancelled = false
            } else {
                self.isAnimationCancelled = false
                completion?()
            }
        }
        add(flipAnimation, forKey: Constants.flipAnimationKey)
        self.rotateDegree = rotateDegree
        CATransaction.commit()
    }

    /// 取消拖动后的动画
    func cancelDragAnimation() {
        if animation(forKey: Constants.flipAnimationKey) != nil {
            rotateDegree = presentation()?.rotateDegree ?? rotateDegree
            isAnimationCancelled = true
            removeAnimation(forKey: Constants.flipAnimationKey)
        }
    }

    // MARK: - SnapshotView

    /// 配置页面快照
    /// - Parameters:
    ///   - contents: 快照
    ///   - position: 位置
    func setSnapshotContents(_ contents: CGImage?, on position: Position) {
        switch position {
        case .front:
            frontLayer.setSnapshotContents(contents)
        case .back:
            backLayer.setSnapshotContents(contents)
        }
    }

    /// 配置页面快照
    /// - Parameters:
    ///   - snapshotView: 快照
    ///   - position: 位置
    func setSnapshotView(_ snapshotView: UIView?, on position: Position) {
        switch position {
        case .front:
            frontLayer.setSnapshotView(snapshotView)
        case .back:
            backLayer.setSnapshotView(snapshotView)
        }
    }

    /// 清除切片
    func clearSnapshot() {
        frontLayer.clearSnapshot()
        backLayer.clearSnapshot()
    }

    // MARK: - shadow

    /// 显示图层阴影，设置opacity是比较费时的操作
    /// - Parameter opacity: 不透明度
    func showShadowOpacity(_ opacity: Float) {
        CATransaction.setValue(true, forKey: kCATransactionDisableActions)
        frontLayer.shadowMaskOpacity = opacity
        backLayer.shadowMaskOpacity = opacity
    }

    /// 显示图层阴影，设置opacity是比较费时的操作
    /// - Parameters:
    ///   - opacity: 不透明度
    ///   - position: 位置
    func showShadowOpacity(_ opacity: Float, on position: Position) {
        CATransaction.setValue(true, forKey: kCATransactionDisableActions)
        switch position {
        case .front:
            frontLayer.shadowMaskOpacity = opacity
            backLayer.shadowMaskOpacity = 0
        case .back:
            frontLayer.shadowMaskOpacity = 0
            backLayer.shadowMaskOpacity = opacity
        }
    }

    /// 移除阴影
    func removeShadow() {
        CATransaction.setValue(true, forKey: kCATransactionDisableActions)
        frontLayer.shadowMaskOpacity = 0
        backLayer.shadowMaskOpacity = 0
    }
}

// swiftlint:enable line_length
