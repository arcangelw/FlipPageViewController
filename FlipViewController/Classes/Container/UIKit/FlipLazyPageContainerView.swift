//
//  FlipLazyPageContainerView.swift
//  FlipViewController
//
//  Created by 吴哲 on 2023/6/9.
//

import UIKit

// swiftlint:disable line_length

public final class FlipLazyPageContainerView: UIView, FlipPageContainer {

    /// 当前展示的页面
    private var visibleView: FlipPageView?
    /// 当前正在刷新的页面索引
    private var currentReloadingPageIndex: Int?
    /// 需要刷新的页面索引
    private var needReloadingPageIndex: Int?
    /// 将要显示的页面索引
    private var newVisiblePageIndex: Int?
    /// 当前显示的页面索引
    private var visiblePageIndex: Int?
    /// 上一次显示的页面索引
    private var lastVisiblePageIndex: Int?

    /// 复用池
    private let reusePool = FlipReusePool()

    private lazy var pageViewClassMap: [String: FlipPageView.Type] = [:]

    override init(frame: CGRect) {
        super.init(frame: frame)
        setUpSelf()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setUpSelf() {
        clipsToBounds = true
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(didReceiveMemoryWarning(notification:)),
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    /// 内存告警 reload释放资源
    @objc
    private func didReceiveMemoryWarning(notification _: NSNotification) {
        clearReuse()
    }

    override public func layoutSubviews() {
        super.layoutSubviews()
        guard visibleView?.frame != bounds else { return }
        visibleView?.frame = bounds
    }

    /// 不可见位置
    private var invisibleRect: CGRect {
        return .init(x: 0, y: bounds.maxY, width: bounds.width, height: bounds.height)
    }

    /// 页面数量
    private var pageTotal: Int = 0

    // MARK: - FlipPageContainer

    /// 引用flipView
    public weak var flipView: FlipView!

    /// flipview 代理
    public weak var flipViewDelegate: FlipViewDelegate?

    /// flipview 数据源
    public weak var flipViewDataSource: FlipViewDataSource?

    /// 当前的PageView
    public var currentPageView: FlipPageView? {
        return visibleView
    }

    /// 当前页
    public var currentPage: Int = 0

    public func register(_ pageViewClass: FlipPageView.Type, forPageViewReuseIdentifier identifier: String) {
        assert(!identifier.isEmpty, "identifier cannot be empty")
        assert(pageViewClassMap[identifier] == nil, "\(pageViewClass) duplicate registration")
        pageViewClassMap[identifier] = pageViewClass
    }

    public func dequeuePageView(withIdentifier identifier: String, for pageIndex: Int) -> FlipPageView {
        if let currentReloadingPageIndex = currentReloadingPageIndex, let visibleView = visibleView, visibleView._reuseIdentifier == identifier, visibleView._pageIndex == currentReloadingPageIndex {
            return visibleView
        }
        if let reusableView = reusePool.dequeuePageView(withIdentifier: identifier, for: pageIndex) {
            reusableView.prepareForReuse()
            return reusableView
        } else {
            let pageViewClass: FlipPageView.Type = pageViewClassMap[identifier]!
            let pageView = pageViewClass.init()
            pageView._reuseIdentifier = identifier
            pageView.frame = invisibleRect
            return pageView
        }
    }

    public func reloadPages(to page: Int, completion: @escaping () -> Void) {
        currentPage = page
        storePageTotal()
        assemble(true, toPage: page)
        completion()
    }

    public func loadMore(_ range: Range<Int>, completion: @escaping (() -> Void)) {
        storePageTotal()
        assemble(true, toPage: currentPage)
        completion()
    }

    public func flipPage(to page: Int, completion: @escaping () -> Void) {
        currentPage = page
        assemble(false, toPage: page)
        completion()
    }

    public func pageView(at page: Int) -> FlipPageView? {
        if let visibleView = visibleView, visibleView._pageIndex == page {
            return visibleView
        } else if let pageView = flipViewDataSource?.flipView(flipView, pageViewAt: page) {
            pageView.isHidden = true
            pageView._pageIndex = page
            ///  切片用 使其不在可见范围内
            pageView.frame = invisibleRect
            /// 扔回缓存池
            reusePool.addPageView(pageView, for: pageView._reuseIdentifier)
            pageView.removeFromSuperview()
            return pageView
        }
        return nil
    }

    public func viewWillTransitionSize(to size: CGSize) {}
}

// MARK: - Clear & Reset & layout

extension FlipLazyPageContainerView {

    /// 布局切换页到指定页
    private func assemble(_ isReload: Bool, toPage: Int) {
        // 确定需要展示的页面
        let newVisablePageIndex: Int? = (0 ..< pageTotal).contains(toPage) ? toPage : nil
        /// 配置回收和刷新
        recycle(isReload, newVisablePageIndex: newVisablePageIndex)
        /// 更新索引信息
        lastVisiblePageIndex = visiblePageIndex
        visiblePageIndex = newVisablePageIndex
        newVisiblePageIndex = newVisablePageIndex
        /// 计算绘制可见视图
        generate(isReload)
    }

    /// 配置回收刷新
    private func recycle(_ isReload: Bool, newVisablePageIndex: Int?) {
        guard let visibleView = visibleView else { return }
        let isToShow = visibleView._pageIndex == newVisablePageIndex
        if !isToShow {
            /// 离开页面
            flipViewDelegate?.flipView(flipView, didEndDisplaying: visibleView, forPageAt: visibleView._pageIndex!)
            visibleView.isHidden = true
            reusePool.addPageView(visibleView, for: visibleView._reuseIdentifier)
            visibleView.removeFromSuperview()
            self.visibleView = nil

        } else if isReload {
            /// 配置需要刷新的索引
            needReloadingPageIndex = visibleView._pageIndex
        }
    }

    /// 设置当前展示视图
    private func generate(_ isReload: Bool) {
        guard let newVisablePageIndex = newVisiblePageIndex else { return }
        let isVisible = isVisible(newVisablePageIndex)
        let needReload = needReloadingPageIndex == newVisablePageIndex
        if isVisible == false || needReload, let flipViewDataSource = flipViewDataSource {
            if isVisible {
                currentReloadingPageIndex = newVisablePageIndex
            }
            let pageView = flipViewDataSource.flipView(flipView, pageViewAt: newVisablePageIndex)
            currentReloadingPageIndex = nil
            pageView._pageIndex = newVisablePageIndex
            pageView.frame = bounds
            pageView.isHidden = false
            if pageView.superview != self {
                addSubview(pageView)
            }
            if needReload, let visibleView = visibleView, visibleView !== pageView {
                /// 更新了新的pageView移除回收
                visibleView.isHidden = true
                reusePool.addPageView(visibleView, for: visibleView._reuseIdentifier)
                visibleView.removeFromSuperview()
            }
            visibleView = pageView
            needReloadingPageIndex = nil
        }

        if lastVisiblePageIndex != newVisablePageIndex, visiblePageIndex == newVisablePageIndex, let visibleView = visibleView {
            flipViewDelegate?.flipView(flipView, willDisplay: visibleView, forPageAt: visibleView._pageIndex!)
        }
        newVisiblePageIndex = nil
    }

    /// 获取页面数量
    private func storePageTotal() {
        pageTotal = flipViewDataSource?.numberOfPages(in: flipView) ?? 0
    }

    /// 清理当前显示的View
    /// - Parameter enableRecycle: 是否回收
    private func clearVisibleView(_ enableRecycle: Bool) {
        if enableRecycle, let visibleView = visibleView {
            visibleView.isHidden = true
            reusePool.addPageView(visibleView, for: visibleView._reuseIdentifier)
        }
        visibleView?.removeFromSuperview()
        visibleView = nil
    }

    /// 清理重用池
    private func clearReuse() {
        for view in reusePool.allPageViews {
            view.removeFromSuperview()
        }
        reusePool.clear()
    }

    /// 重置
    private func resetAll() {
        clearVisibleView(false)
        clearReuse()
    }

    /// 是否展示
    private func isVisible(_ pageIndex: Int) -> Bool {
        return visibleView?._pageIndex == pageIndex
    }
}

// swiftlint:enable line_length
