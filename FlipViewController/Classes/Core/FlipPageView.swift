//
//  FlipPageView.swift
//  FlipViewController
//
//  Created by 吴哲 on 2023/5/17.
//

import UIKit

// swiftlint:disable identifier_name line_length

/// 可以重用Page
open class FlipPageView: UIView {
    // MARK: - internal for private

    internal var _reuseIdentifier: String = ""
    internal var _pageIndex: Int?

    #if canImport(LazyScroll)
    internal weak var flipView: FlipView!
    internal var mui_didEnter = false
    #endif

    /// for
    internal weak var wrapper: FlipPageViewWrapperBinder! {
        didSet {
            wrapper.bindPageView(self)
        }
    }

    /// 内容视图
    open var contentView = UIView() {
        didSet {
            contentView.backgroundColor = oldValue.backgroundColor
            oldValue.removeFromSuperview()
            insertContentView(contentView)
        }
    }

    override public init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .white
        insertContentView(contentView)
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        backgroundColor = .white
        insertContentView(contentView)
    }

    /// 配置插入内容视图
    private func insertContentView(_ contentView: UIView) {
        insertSubview(contentView, at: 0)
        contentView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            contentView.leadingAnchor.constraint(equalTo: leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: trailingAnchor),
            contentView.topAnchor.constraint(equalTo: topAnchor),
            contentView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
        guard bounds.size != .zero else { return }
        layoutIfNeeded()
    }

    // MARK: - open

    open func prepareForReuse() {}

    /// 在header 、 footer时的手势滑动偏移量
    /// - Parameter offset: 位移
    open func dragging(_ offset: CGFloat) {}

    /// 结束拖拽
    /// - Parameter offset: 位移
    open func dragEnded(_ offset: CGFloat) {}

    /// 制作垂直翻转快照
    /// - Returns: [topSnapshotView, bottomSnapshotView]
    open func makeVerticalFlipSnapshotViews() -> [UIView] {
        let oriHidden = isHidden
        isHidden = false
        defer {
            isHidden = oriHidden
        }
        let topRect = CGRect(x: bounds.minX, y: bounds.minY, width: bounds.width, height: bounds.midY)
        let bottomRect = CGRect(x: bounds.minX, y: bounds.midY, width: bounds.width, height: bounds.midY)
        guard
            let topSnapshotView = resizableSnapshotView(from: topRect, afterScreenUpdates: true, withCapInsets: .zero),
            let bottomSnapshotView = resizableSnapshotView(from: bottomRect, afterScreenUpdates: true, withCapInsets: .zero)
        else { return [] }
        return [topSnapshotView, bottomSnapshotView]
    }

    /// 制作垂直翻转快照
    /// - Returns: [topSnapshotView, bottomSnapshotView]
    open func makeVerticalFlipSnapshotImages() -> [UIImage] {
        let oriHidden = isHidden
        isHidden = false
        defer {
            isHidden = oriHidden
        }
        return Flip.makeHsplitImages(self)
    }
}

// swiftlint:enable identifier_name line_length
