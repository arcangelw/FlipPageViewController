//
//  LazyScrollContainerView.swift
//  FlipViewController
//
//  Created by 吴哲 on 2023/6/8.
//

import LazyScroll
import UIKit

extension FlipPageView: TMLazyItemViewProtocol {

    public func mui_prepareForReuse() {
        prepareForReuse()
    }

    public func mui_didEnter(withTimes times: UInt) {
        mui_didEnter = true
        guard
            let flipView = flipView, let muiID = muiID, let pageIndex = Int(muiID)
        else { return }
        flipView.delegate?.flipView(flipView, willDisplay: self, forPageAt: pageIndex)
    }

    public func mui_didLeave() {
        guard
            mui_didEnter, let flipView = flipView,
            let muiID = muiID, let pageIndex = Int(muiID)
        else { return }
        mui_didEnter = false
        flipView.delegate?.flipView(flipView, didEndDisplaying: self, forPageAt: pageIndex)
    }
}

// swiftlint:disable force_cast

public final class LazyScrollContainerView: UIView, FlipPageContainer, TMLazyScrollViewDataSource {

    // MARK: - lazyScroll

    private let lazyScroll = TMLazyScrollView()

    private lazy var pageViewClassMap: [String: FlipPageView.Type] = [:]

    override public init(frame: CGRect) {
        super.init(frame: frame)
        setUpSelf()
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setUpSelf() {
        backgroundColor = .white
        lazyScroll.autoAddSubview = true
        lazyScroll.autoClearGestures = false
        lazyScroll.contentInsetAdjustmentBehavior = .never
        lazyScroll.scrollsToTop = false
        lazyScroll.isScrollEnabled = false
        lazyScroll.isPagingEnabled = true
        lazyScroll.dataSource = self
        addSubview(lazyScroll)
        lazyScroll.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            lazyScroll.topAnchor.constraint(equalTo: topAnchor),
            lazyScroll.bottomAnchor.constraint(equalTo: bottomAnchor),
            lazyScroll.leadingAnchor.constraint(equalTo: leadingAnchor),
            lazyScroll.trailingAnchor.constraint(equalTo: trailingAnchor)
        ])
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

    private var didLayoutSubviews: Bool = false

    override public func layoutSubviews() {
        super.layoutSubviews()
        guard bounds.size != .zero, !didLayoutSubviews else { return }
        didLayoutSubviews = true
        relayout(bounds.size)
    }

    // MARK: - FlipPageContainer

    public weak var flipView: FlipView!

    public weak var flipViewDelegate: FlipViewDelegate?

    public weak var flipViewDataSource: FlipViewDataSource?

    public var currentPageView: FlipPageView? {
        return lazyScroll.inScreenVisibleItems.first as? FlipPageView
    }

    public var currentPage: Int = 0

    public func register(_ pageViewClass: FlipPageView.Type, forPageViewReuseIdentifier identifier: String) {
        assert(!identifier.isEmpty, "identifier cannot be empty")
        assert(pageViewClassMap[identifier] == nil, "\(pageViewClass) duplicate registration")
        pageViewClassMap[identifier] = pageViewClass
    }

    public func dequeuePageView(withIdentifier identifier: String, for pageIndex: Int) -> FlipPageView {
        if let reusableView = lazyScroll.dequeueReusableItem(withIdentifier: identifier, muiID: "\(pageIndex)") {
            return reusableView as! FlipPageView
        } else {
            let pageViewClass: FlipPageView.Type = pageViewClassMap[identifier]!
            let pageView = pageViewClass.init()
            pageView.reuseIdentifier = identifier
            pageView.flipView = flipView
            return pageView
        }
    }

    public func reloadPages(to page: Int, completion: @escaping () -> Void) {
        guard let flipViewDataSource = flipViewDataSource else {
            fatalError()
        }
        currentPage = page
        pageTotal = flipViewDataSource.numberOfPages(in: flipView)
        lazyScroll.reloadData()
        lazyScroll.scrollRectToVisible(rects[page], animated: false)
        completion()
    }

    public func loadMore(_ range: Range<Int>, completion: @escaping (() -> Void)) {
        guard let flipViewDataSource = flipViewDataSource else {
            fatalError()
        }
        pageTotal = flipViewDataSource.numberOfPages(in: flipView)
        lazyScroll.clearVisibleItems(true)
        lazyScroll.reloadData()
        lazyScroll.scrollRectToVisible(rects[currentPage], animated: false)
        completion()
    }

    public func flipPage(to page: Int, completion: @escaping () -> Void) {
        currentPage = page
        lazyScroll.scrollRectToVisible(rects[page], animated: false)
        completion()
    }

    public func pageView(at page: Int) -> FlipPageView? {
        let muiId = "\(page)"
        if let visibleView = lazyScroll.visibleItems.first(where: { $0.muiID == muiId }) as? FlipPageView {
            return visibleView
        } else if let pageView = scrollView(lazyScroll, itemByMuiID: "\(page)") as? FlipPageView {
            /// 提前创建了就不要浪费 扔缓存
            if pageView.superview == nil {
                lazyScroll.reusePool.addItemView(pageView, forReuseIdentifier: pageView.reuseIdentifier)
            }
            return pageView
        }
        return nil
    }

    public func viewWillTransitionSize(to size: CGSize) {
        relayout(size)
    }

    // MARK: -

    public var rects: [CGRect] = []

    public var pageTotal: Int = 0 {
        didSet {
            guard oldValue != pageTotal else { return }
            reloadRects(oldValue)
        }
    }

    private func reloadRects(_ oldTotal: Int) {
        let lazyScrollSize = lazyScroll.frame.size
        if oldTotal >= pageTotal {
            rects.removeSubrange(pageTotal ..< oldTotal)
        } else {
            for index in oldTotal ..< pageTotal {
                let rect = CGRect(
                    origin: .init(x: 0, y: lazyScrollSize.height * CGFloat(index)),
                    size: lazyScrollSize
                )
                rects.append(rect)
            }
        }
        if let maxY = rects.map(\.maxY).max() {
            lazyScroll.contentSize = .init(width: lazyScrollSize.width, height: maxY)
        } else {
            lazyScroll.contentSize = lazyScrollSize
        }
    }

    private func relayout(_ lazyScrollSize: CGSize) {

        let lazyScrollSize = lazyScroll.frame.size
        var rects: [CGRect] = []
        for index in 0 ..< pageTotal {
            let rect = CGRect(
                origin: .init(x: 0, y: lazyScrollSize.height * CGFloat(index)),
                size: lazyScrollSize
            )
            rects.append(rect)
        }
        if let maxY = rects.map(\.maxY).max() {
            lazyScroll.contentSize = .init(width: lazyScrollSize.width, height: maxY)
        } else {
            lazyScroll.contentSize = lazyScrollSize
        }
        self.rects = rects
        lazyScroll.reloadData()
        guard !rects.isEmpty else { return }
        lazyScroll.scrollRectToVisible(rects[currentPage], animated: false)
    }

    public func numberOfItems(in scrollView: TMLazyScrollView) -> UInt {
        return UInt(pageTotal)
    }

    public func scrollView(_ scrollView: TMLazyScrollView, itemModelAt index: UInt) -> TMLazyItemModel {
        let rect = rects[Int(index)]
        let rectModel = TMLazyItemModel()
        rectModel.absRect = rect
        rectModel.muiID = "\(index)"
        return rectModel
    }

    public func scrollView(_ scrollView: TMLazyScrollView, itemByMuiID muiID: String) -> UIView {
        guard
            let flipViewDataSource = flipViewDataSource,
            let index = Int(muiID)
        else {
            fatalError()
        }
        let view = flipViewDataSource.flipView(flipView, pageViewAt: index)
        view.frame = rects[index]
        return view
    }

    /// 内存告警 reload释放资源
    @objc
    private func didReceiveMemoryWarning(notification _: NSNotification) {
        lazyScroll.clearReuseItems()
    }
}

// swiftlint:enable force_cast
