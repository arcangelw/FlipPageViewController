//
//  FlipPageContainerView.swift
//  FlipViewController
//
//  Created by 吴哲 on 2023/5/22.
//

import UIKit

extension FlipPageContainerView {
    private class WrapperCell: UICollectionViewCell, FlipPageViewWrapperBinder {
        var pageView: FlipPageView!

        func bindPageView(_ pageView: FlipPageView) {
            self.pageView = pageView
            contentView.addSubview(pageView)
            pageView.frame = bounds
        }

        override func apply(_ layoutAttributes: UICollectionViewLayoutAttributes) {
            super.apply(layoutAttributes)
            guard pageView?.frame != layoutAttributes.bounds else { return }
            pageView?.frame = layoutAttributes.bounds
        }

        override func layoutSubviews() {
            super.layoutSubviews()
            guard pageView?.frame != bounds else { return }
            pageView?.frame = bounds
        }

        override func prepareForReuse() {
            super.prepareForReuse()
            pageView?.prepareForReuse()
        }
    }

    private class WrapperLayout: UICollectionViewFlowLayout {

        override init() {
            super.init()
            minimumLineSpacing = 0
            minimumInteritemSpacing = 0
            headerReferenceSize = .zero
            footerReferenceSize = .zero
            scrollDirection = .vertical
            sectionInset = .zero
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override func prepare() {
            itemSize = collectionView?.bounds.size ?? .zero
            super.prepare()
        }

        override var collectionViewContentSize: CGSize {
            let width: CGFloat
            // https://openradar.appspot.com/radar?id=5025850143539200
            if let collectionView = collectionView {
                let contentInset = collectionView.adjustedContentInset
                width = collectionView.bounds.width - contentInset.left - contentInset.right - 0.0001
            } else {
                width = 0
            }
            return .init(width: width, height: super.collectionViewContentSize.height)
        }

        override func shouldInvalidateLayout(forBoundsChange newBounds: CGRect) -> Bool {
            return collectionView?.bounds != newBounds
        }
    }
}

// swiftlint:disable line_length force_cast

public final class FlipPageContainerView: UICollectionView, FlipPageContainer, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    private lazy var pageViewClassMap: [String: FlipPageView.Type] = [:]

    public init() {
        super.init(frame: .zero, collectionViewLayout: WrapperLayout())
        backgroundColor = .white
        contentInsetAdjustmentBehavior = .never
        scrollsToTop = false
        isScrollEnabled = false
        isPagingEnabled = true
        dataSource = self
        delegate = self
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

    @available(*, unavailable)
    public required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public weak var flipView: FlipView!

    public weak var flipViewDelegate: FlipViewDelegate?

    public weak var flipViewDataSource: FlipViewDataSource?

    public var currentPageView: FlipPageView? {
        return (visibleCells.first as? WrapperCell)?.pageView
    }

    public var currentPage: Int = 0

    public func register(_ pageViewClass: FlipPageView.Type, forPageViewReuseIdentifier identifier: String) {
        assert(!identifier.isEmpty, "identifier cannot be empty")
        assert(pageViewClassMap[identifier] == nil, "\(pageViewClass) duplicate registration")
        pageViewClassMap[identifier] = pageViewClass
        register(WrapperCell.self, forCellWithReuseIdentifier: identifier)
    }

    public func dequeuePageView(withIdentifier identifier: String, for pageIndex: Int) -> FlipPageView {
        guard let wrapperCell = dequeueReusableCell(withReuseIdentifier: identifier, for: .init(item: pageIndex, section: 0)) as? WrapperCell else {
            fatalError("")
        }
        if wrapperCell.pageView != nil {
            return wrapperCell.pageView
        } else {
            let pageViewClass: FlipPageView.Type = pageViewClassMap[identifier]!
            let pageView = pageViewClass.init()
            pageView.wrapper = wrapperCell
            return pageView
        }
    }

    public func reloadPages(to page: Int, completion: @escaping () -> Void) {
        currentPage = page
        let toIndexPath = IndexPath(item: page, section: 0)
        let isNotEmpty = numberOfItems(inSection: 0) > 0
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        CATransaction.setCompletionBlock(completion)
        reloadData()
        layoutIfNeeded()
        if isNotEmpty {
            scrollToItem(at: toIndexPath, at: .centeredVertically, animated: false)
        }
        CATransaction.commit()
    }

    public func loadMore(_ range: Range<Int>, completion: @escaping (() -> Void)) {
        let insertItems = range.map { IndexPath(item: $0, section: 0) }
        let lastItem = IndexPath(item: max(0, numberOfItems(inSection: 0) - 1), section: 0)
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        CATransaction.setCompletionBlock(completion)
        performBatchUpdates {
            self.insertItems(at: insertItems)
            self.reloadItems(at: [lastItem])
        }
        CATransaction.commit()
    }

    public func flipPage(to page: Int, completion: @escaping () -> Void) {
        currentPage = page
        let toIndexPath = IndexPath(item: page, section: 0)
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        CATransaction.setCompletionBlock(completion)
        scrollToItem(at: toIndexPath, at: .centeredVertically, animated: false)
        CATransaction.commit()
    }

    public func pageView(at page: Int) -> FlipPageView? {
        guard page < numberOfItems(inSection: 0) else { return nil }
        let indexPath = IndexPath(item: page, section: 0)

        if let wrapperCell = cellForItem(at: indexPath) as? WrapperCell {
            return wrapperCell.pageView
        } else {
            let wrapperCell = collectionView(self, cellForItemAt: indexPath) as! WrapperCell
            guard let layoutAttributes = layoutAttributesForItem(at: indexPath) else { return nil }
            wrapperCell.apply(layoutAttributes)
            return wrapperCell.pageView
        }
    }

    public func viewWillTransitionSize(to size: CGSize) {
        collectionViewLayout.invalidateLayout()
    }

    public func numberOfSections(in _: UICollectionView) -> Int {
        return 1
    }

    public func collectionView(_: UICollectionView, numberOfItemsInSection _: Int) -> Int {
        return flipViewDataSource?.numberOfPages(in: flipView) ?? 0
    }

    public func collectionView(_: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard
            let flipViewDataSource = flipViewDataSource,
            let wrapperCell = flipViewDataSource.flipView(flipView, pageViewAt: indexPath.item).wrapper as? WrapperCell
        else {
            fatalError()
        }
        return wrapperCell
    }

    public func collectionView(_: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        let wrapperCell = cell as! WrapperCell
        flipViewDelegate?.flipView(flipView, willDisplay: wrapperCell.pageView, forPageAt: indexPath.item)
    }

    public func collectionView(_: UICollectionView, didEndDisplaying cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        let wrapperCell = cell as! WrapperCell
        flipViewDelegate?.flipView(flipView, didEndDisplaying: wrapperCell.pageView, forPageAt: indexPath.item)
    }

    /// 内存告警 reload释放资源
    @objc
    private func didReceiveMemoryWarning(notification _: NSNotification) {
        guard let toIndexPath = indexPathsForVisibleItems.first else {
            return
        }
        let isNotEmpty = numberOfItems(inSection: 0) > 0
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        reloadData()
        layoutIfNeeded()
        if isNotEmpty {
            scrollToItem(at: toIndexPath, at: .centeredVertically, animated: false)
        }
        CATransaction.commit()
    }
}

// swiftlint:enable line_length force_cast
