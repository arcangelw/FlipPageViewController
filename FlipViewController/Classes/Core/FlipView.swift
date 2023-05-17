//
//  FlipContainerView.swift
//  FlipViewController
//
//  Created by 吴哲 on 2023/5/17.
//

import QuartzCore
import UIKit

// swiftlint:disable line_length

public protocol FlipViewDataSource: AnyObject {
    func numberOfPages(in flipView: FlipView) -> Int
    func flipView(_ flipView: FlipView, pageViewAt pageIndex: Int) -> FlipPageView
}

public protocol FlipViewDelegate: AnyObject {
    func flipView(_ flipView: FlipView, willDisplay pageView: FlipPageView, forPageAt pageIndex: Int)

    func flipView(_ flipView: FlipView, didEndDisplaying pageView: FlipPageView, forPageAt pageIndex: Int)
}

@IBDesignable
open class FlipView: UIView {
    // MARK: - public

    open weak var delegate: FlipViewDelegate? {
        didSet {
            containerView.flipViewDelegate = delegate
        }
    }

    open weak var dataSource: FlipViewDataSource? {
        didSet {
            guard isReload else { return }
            containerView.flipViewDataSource = dataSource
        }
    }

    /// pageView容器
    public let containerView: FlipPageContainer

    open class var containerViewClass: FlipPageContainer.Type {
        return FlipLazyPageContainerView.self
    }

    /// 外部决定 是否可以拖动翻页
    /// 通常配合加载数据时禁止交互
    public var flipable: Bool = true

    /// 最长交互动画时长
    public var fullDuration = 0.3

    /// 临界速度 0.0~1.0 快速滑动 超过临界角度 即翻页
    public var flipCriticalSpeed: CGFloat = 0.9

    /// 临界角度 快速滑动 超过临界角度 即翻页
    public var flipCriticalAngle: CGFloat = 30

    /// 当前展示的PageView
    public var currentPageView: FlipPageView? {
        return containerView.currentPageView
    }

    /// 刷新阈值 适用于 headerLayer / footerLayer
    /// 当翻页角度进度超过 refreshThreshold 则进入刷新状态
    public var refreshThreshold: CGFloat = 0.7

    /// 头部活动指示器
    public var headerLayer: FlipRefreshLayer? // = FlipActivityIndicatorLayer(indicatorStyle: .header)

    /// 底部活动指示器
    public var footerLayer: FlipRefreshLayer? // = FlipActivityIndicatorLayer(indicatorStyle: .footer)

    /// 当前页
    public var currentPage: Int = 0

    public func register(_ pageViewClass: FlipPageView.Type, forPageViewReuseIdentifier identifier: String) {
        containerView.register(pageViewClass, forPageViewReuseIdentifier: identifier)
    }

    public func register<T: FlipPageView>(pageViewType: T.Type) {
        register(pageViewType.self, forPageViewReuseIdentifier: String(reflecting: pageViewType))
    }

    public func dequeuePageView(withIdentifier identifier: String, for pageIndex: Int) -> FlipPageView {
        containerView.dequeuePageView(withIdentifier: identifier, for: pageIndex)
    }

    public func dequeuePageView<T: FlipPageView>(for pageIndex: Int, pageViewType: T.Type = T.self) -> T {
        let reuseView = dequeuePageView(withIdentifier: String(reflecting: pageViewType), for: pageIndex)
        guard let pageView = reuseView as? T else {
            fatalError("\(String(reflecting: pageViewType)) not registered yet.")
        }
        return pageView
    }

    /// 刷新Page页面
    public func reloadPages(to page: Int = 0, completion: (() -> Void)? = nil) {
        isReloading = true
        totalPageCount = numberOfPages()
        let page = max(0, min(page, totalPageCount - 1))
        currentPage = page
        if !isReload {
            containerView.flipViewDataSource = dataSource
            isReload = true
        }
        /// 页面稳定后 配置动画层
        containerView.reloadPages(to: page) { [weak self] in
            guard let self = self else { return }
            self.transformView.reloadAnimationNodes()
            self.gestureEnable = self.totalPageCount > 0
            completion?()
            self.isReloading = false
        }
    }

    /// 加载更多
    public func loadMore(completion: (() -> Void)? = nil) {
        isReloading = true
        let oldTotalPageCount = totalPageCount
        totalPageCount = numberOfPages()
        assert(totalPageCount > oldTotalPageCount)
        transformView.loadMoreAnimationNodes()
        let moreRange = oldTotalPageCount ..< totalPageCount
        containerView.loadMore(moreRange) {
            completion?()
            self.isReloading = false
        }
    }

    /// 跳转到指定页
    /// - Parameters:
    ///   - pageIndex: 页面索引
    ///   - animated: 是否动画
    ///   - completion: 结束回调
    public func flipPage(to pageIndex: Int, animated: Bool = true, completion: (() -> Void)? = nil) {
        if isReloading {
            DispatchQueue.main.async {
                self.flipPage(to: pageIndex, animated: animated, completion: completion)
            }
            return
        }
        guard currentPage != pageIndex, totalPageCount > 0 else { return }
        let maxPageIndex = totalPageCount - 1
        let pageIndex = max(0, min(pageIndex, maxPageIndex))
        if animated {
            transformView.flipPage(to: pageIndex) {
                completion?()
            }
        } else {
            containerView.flipPage(to: pageIndex) {
                completion?()
            }
        }
    }

    /// 翻转上一页
    public func flipPreviousPage(animated: Bool = true, completion: (() -> Void)? = nil) {
        let peviousPage = currentPage - 1
        guard peviousPage > 0 else { return }
        flipPage(to: peviousPage, animated: animated, completion: completion)
    }

    /// 翻转下一页
    public func flipNextPage(animated: Bool = true, completion: (() -> Void)? = nil) {
        let nextPage = currentPage + 1
        guard nextPage < totalPageCount else { return }
        flipPage(to: nextPage, animated: animated, completion: completion)
    }

    public func viewWillTransitionSize(to size: CGSize) {
        didLayoutSubviews = false
        containerView.viewWillTransitionSize(to: size)
        containerView.flipPage(to: currentPage, completion: {})
    }

    // MARK: - override

    override open var backgroundColor: UIColor? {
        didSet {
            containerView.backgroundColor = backgroundColor
            transformView.backgroundColor = backgroundColor
        }
    }

    override public init(frame: CGRect) {
        containerView = type(of: self).containerViewClass.init()
        super.init(frame: frame)
        setUpSelf()
    }

    public required init?(coder: NSCoder) {
        containerView = type(of: self).containerViewClass.init()
        super.init(coder: coder)
        setUpSelf()
    }

    override public func layoutSubviews() {
        super.layoutSubviews()
        guard bounds.size != .zero else { return }
        flipToTopScrollView.scrollToBottom()
        didLayoutSubviews = true
    }

    // MARK: - private

    private func setUpSelf() {
        backgroundColor = .white
        transformView.flipView = self
        containerView.flipView = self
        flipToTopScrollView.scrollsToTop = true
        flipToTopScrollView.contentSize = .init(width: 1, height: 1)
        addSubview(flipToTopScrollView)
        flipToTopScrollView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            flipToTopScrollView.topAnchor.constraint(equalTo: topAnchor),
            flipToTopScrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            flipToTopScrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            flipToTopScrollView.heightAnchor.constraint(equalToConstant: 0)
        ])
        addSubview(containerView)
        containerView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: topAnchor),
            containerView.leadingAnchor.constraint(equalTo: leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
        addSubview(transformView)
        transformView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            transformView.topAnchor.constraint(equalTo: topAnchor),
            transformView.leadingAnchor.constraint(equalTo: leadingAnchor),
            transformView.trailingAnchor.constraint(equalTo: trailingAnchor),
            transformView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
        addGestureRecognizer(flipGesture)
        // addGestureRecognizer(upSwipeGesture)
        // addGestureRecognizer(downSwipeGesture)
        gestureEnable = false
        flipGesture.addTarget(self, action: #selector(flipPanned(_:)))
        // upSwipeGesture.addTarget(self, action: #selector(upSwipe(_:)))
        // downSwipeGesture.addTarget(self, action: #selector(downSwipe(_:)))
        // upSwipeGesture.require(toFail: flipGesture)
        // downSwipeGesture.require(toFail: flipGesture)
        flipToTopObservation = flipToTopScrollView.observe(\.contentOffset, options: [.old, .new]) { [weak self] scrollView, change in
            guard
                let self = self, self.didLayoutSubviews, scrollView.frame.size != .zero,
                change.oldValue != change.newValue, scrollView.isScrollToTop
            else { return }
            scrollView.scrollToBottom()
            self.flipToTop()
        }
    }

    // MARK: - flipToTop

    private var flipToTopObservation: NSKeyValueObservation?

    private func flipToTop() {
        flipPage(to: 0)
    }

    // MARK: - FlipGestureRecognizer

    private var gestureEnable: Bool = false {
        didSet {
            flipGesture.isEnabled = gestureEnable
            upSwipeGesture.isEnabled = gestureEnable
            downSwipeGesture.isEnabled = gestureEnable
        }
    }

    public let flipGesture: UIPanGestureRecognizer = FlipGestureRecognizer()
    // TODO: - 后期优化手势
    private let upSwipeGesture: UISwipeGestureRecognizer = {
        let upSwipeGesture = UISwipeGestureRecognizer()
        upSwipeGesture.direction = .up
        return upSwipeGesture
    }()

    private let downSwipeGesture: UISwipeGestureRecognizer = {
        let downSwipeGesture = UISwipeGestureRecognizer()
        downSwipeGesture.direction = .down
        return downSwipeGesture
    }()

    @objc
    private func flipPanned(_ gesture: FlipGestureRecognizer) {
        guard flipable, !isReloading else {
            gesture.state = .failed
            return
        }
        let translation = gesture.translation(in: self)
        switch gesture.state {
        case .began:
            transformView.dragBegan(translation)
        case .cancelled, .ended:
            transformView.dragEnded(translation)
        case .changed:
            transformView.dragging(translation)
        default: ()
        }
    }

    @objc
    private func upSwipe(_ gesture: UISwipeGestureRecognizer) {
        guard flipable, !isReloading else {
            return
        }
        flipNextPage()
    }

    @objc
    private func downSwipe(_ gesture: UISwipeGestureRecognizer) {
        guard flipable, !isReloading else {
            return
        }
        flipPreviousPage()
    }

    // MARK: - PageView

    private var isReload = false

    /// 页面数量
    private func numberOfPages() -> Int {
        return dataSource?.numberOfPages(in: self) ?? 0
    }

    internal func pageView(at pageIndex: Int) -> FlipPageView? {
        containerView.pageView(at: pageIndex)
    }

    // MARK: - Flip to top

    private let flipToTopScrollView = UIScrollView()

    // MARK: - transform animation view

    private let transformView = FlipTransformView()

    /// Page页面数量
    internal var totalPageCount: Int = 0

    /// 正在刷新
    private var isReloading = false

    /// 页面布局完成
    private var didLayoutSubviews = false
}

// swiftlint:enable line_length
