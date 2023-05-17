//
//  FlipTransformView.swift
//  FlipViewController
//
//  Created by 吴哲 on 2023/5/22.
//

import UIKit

// swiftlint:disable nesting line_length cyclomatic_complexity function_body_length file_length

extension FlipTransformView {
    /// 状态
    enum FlipState {
        /// 停止
        case stop
        /// 拖动翻页中
        case dragging
        /// 翻页动画中
        case animating
    }

    /// 拖拽方向
    enum FlipDirection {
        /// 向上翻 to next Page
        case top
        /// 向下翻 to previous page
        case bottom
    }

    /// 手势拖动信息
    private struct FlipDragger {
        /// 拖动状态
        var state: FlipState = .stop
        /// 正在被拖动的页面翻转
        var direction: FlipDirection = .top
        /// 正在被拖动的页面
        var draggingLayer: FlipLayer!

        /// 正在拖动页面索引
        var draggingNodeIndex: Int?
        /// 上次拖动位置
        var draggingLastTranslationY: CGFloat = 0
        /// 开始拖动翻页的时间
        var startTime: TimeInterval = CACurrentMediaTime()
        /// header footer
        var isHeaderOrFooterDragging = false
    }
}

/// 动画层
final class FlipTransformView: UIView {

    /// flipView
    weak var flipView: FlipView!

    /// 交互层layer
    private var transformLayer: CATransformLayer = .init()

    /// 当前交互中的layer
    private var flipLayers: [FlipLayer] {
        transformLayer.sublayers as? [FlipLayer] ?? []
    }

    /// 翻页动画节点信息缓存
    private var animationNodes: [FlipAnimationNode] = []

    /// 动画节点总量
    private(set) var totalAnimationNodeCount = 0

    override var isHidden: Bool {
        willSet {
            transformLayer.isHidden = newValue
        }
    }

    override public init(frame: CGRect) {
        super.init(frame: frame)
        setUpSelf()
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        setUpSelf()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    private func setUpSelf() {
        backgroundColor = .white
        layer.insertSublayer(transformLayer, at: 0)
        transformLayer.isDoubleSided = false
        transformLayer.name = "transformLayer"
        isHidden = true
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(didReceiveMemoryWarning(notification:)),
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil
        )
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard bounds.size != .zero else { return }
        guard transformLayer.frame != bounds else { return }
        transformLayer.frame = bounds
        /// bounds 变化 重新配置节点
        relayoutAnimationNodes()
        headerLayer?.frame = .init(x: bounds.minX, y: bounds.minY, width: bounds.width, height: bounds.midY)
        footerLayer?.frame = .init(x: bounds.minX, y: bounds.midY, width: bounds.width, height: bounds.midY)
    }

    /// layer状态管理
    private var flip = FlipDragger() {
        didSet {
            guard oldValue.state != flip.state else { return }
            updateFlipState(flip.state)
        }
    }

    /// 内存告警
    @objc
    private func didReceiveMemoryWarning(notification _: NSNotification) {
        resetAnimationNodes()
        let flipLayers = flipLayers
        for layer in flipLayers {
            layer.clearSnapshot()
        }
    }

    /// 跳转页面 执行翻转动画
    /// - Parameters:
    ///   - pageIndex: 目标页
    ///   - completion: 动画结束回调
    func flipPage(to pageIndex: Int, completion: @escaping () -> Void) {
        snapshotWorkForAnimationNode(at: currentPage)
        snapshotWorkForAnimationNode(at: pageIndex)
        flip.state = .animating

        flip.direction = pageIndex < currentPage ? .bottom : .top
        let animatedRange = min(pageIndex, currentPage) ... (max(pageIndex, currentPage) + 1)
        let skipRange: ClosedRange<Int>?
        /// 超过十页翻页 忽略中间页 限制最多同时翻页动画
        if animatedRange.count > 10 {
            skipRange = (animatedRange.lowerBound + 5) ... (animatedRange.upperBound - 5)
        } else {
            skipRange = nil
        }
        let animatedLayerCount = animatedRange.count - (skipRange?.count ?? 0)
        addAllTransformLayer(at: animatedRange, skipRange: skipRange, for: flip.direction)
        typealias Element = (Int, FlipAnimationNode)
        let animatedNodesEnumerated: [(Int, FlipAnimationNode)]
        switch flip.direction {
        case .top:
            animatedNodesEnumerated = Array(animationNodes.enumerated())
        case .bottom:
            animatedNodesEnumerated = animationNodes.enumerated().reversed()
        }

        var delay = 0.0
        let delayRate = max(0.25, 1.0 / CGFloat(animatedRange.count))
        var completeCount = 0

        /// 动画最终需要展示的范围
        let finalVisableRange = pageIndex ... (pageIndex + 1)
        for (flipIndex, node) in animatedNodesEnumerated where animatedRange.contains(flipIndex) && !(skipRange?.contains(flipIndex) ?? false) {
            let rotateDegree = calculateRotateDegree(flipIndex, toTarget: pageIndex)
            let duration = abs(rotateDegree - node.rotateDegree) / 180.0 * fullDuration
            defer {
                delay += duration * delayRate
            }
            guard let flipLayer = node.flipLayer else {
                completeCount += 1
                continue
            }
            flipLayer.setRotateDegree(rotateDegree, duration: duration, delay: delay) { [weak self] in
                guard let self = self else { return }
                /// 非展示layer移除 防止最终切换完成后页闪烁
                if !finalVisableRange.contains(flipIndex) {
                    flipLayer.removeFromSuperlayer()
                }
                completeCount += 1
                if completeCount >= animatedLayerCount {
                    self.updatePage(pageIndex, state: .stop, completion: completion)
                }
            }
        }
    }
}

// MARK: - from FlipView

extension FlipTransformView {
    /// 刷新阈值 适用于 headerLayer / footerLayer
    /// 当翻页角度进度超过 refreshThreshold 则进入刷新状态
    private var refreshThreshold: CGFloat {
        return flipView.refreshThreshold
    }

    /// 头部活动指示器
    private var headerLayer: FlipRefreshLayer? {
        return flipView.headerLayer
    }

    /// 底部活动指示器
    private var footerLayer: FlipRefreshLayer? {
        return flipView.footerLayer
    }

    /// 最长交互动画时长
    private var fullDuration: TimeInterval {
        return flipView.fullDuration
    }

    /// 临界速度 0.0~1.0 快速滑动 超过临界角度 即翻页
    private var flipCriticalSpeed: CGFloat {
        return flipView.flipCriticalSpeed
    }

    /// 临界角度 快速滑动 超过临界角度 即翻页
    private var flipCriticalAngle: CGFloat {
        return flipView.flipCriticalAngle
    }

    /// 当前页
    private var currentPage: Int {
        return flipView.currentPage
    }

    /// Page页面数量
    private var totalPageCount: Int {
        return flipView.totalPageCount
    }
}

// MARK: - AnimationNodes

extension FlipTransformView {

    /// 刷新节点配置信息
    func reloadAnimationNodes() {
        removeTransformLayer()
        animationNodes.removeAll()
        totalAnimationNodeCount = totalPageCount > 0 ? (totalPageCount + 1) : 0
        let layerFrame = CGRect(x: 0, y: bounds.midY, width: bounds.width, height: bounds.midY)
        for _ in 0 ..< totalAnimationNodeCount {
            let node = FlipAnimationNode()
            node.layerFrame = layerFrame
            animationNodes.append(node)
        }
        updateRotateDegree()
    }

    /// 追加配置节点
    func loadMoreAnimationNodes() {
        let oldCount = totalAnimationNodeCount
        totalAnimationNodeCount = totalPageCount + 1
        let layerFrame = CGRect(x: 0, y: bounds.midY, width: bounds.width, height: bounds.midY)
        for _ in oldCount ..< totalAnimationNodeCount {
            let node = FlipAnimationNode()
            node.layerFrame = layerFrame
            animationNodes.append(node)
        }
        updateRotateDegree()
    }

    /// 重新配置节点布局信息
    func relayoutAnimationNodes() {
        let layerFrame = CGRect(x: 0, y: bounds.midY, width: bounds.width, height: bounds.midY)
        for node in animationNodes {
            node.layerFrame = layerFrame
            node.clear()
        }
    }

    /// 重置节点信息
    func resetAnimationNodes() {
        for node in animationNodes {
            node.clear()
        }
    }
}

// MARK: - flipTransform

extension FlipTransformView {
    /// 更新跳转页面
    /// - Parameters:
    ///   - page: page
    ///   - state: 状态
    ///   - completion: 更新回调
    private func updatePage(_ page: Int, state: FlipState, completion: (() -> Void)? = nil) {
        flipView.containerView.flipPage(to: page) { [weak self] in
            guard let self = self else { return }
            self.flipView.currentPage = page
            self.flip.state = state
            completion?()
        }
    }

    /*
        pageViews 在 animationNodes -> flipSublayers -> transformLayer 流程创建转换映射关系
        animationNodes -> flipSublayers 是一对一创建的对应关系
        animationNodes 同 pageViews 的索引映射关系  nodeIndex = pageIndex + 1
        animationNodes 首位追加一个节点映射存储 pageViews[0] 的上半页快照信息

        页面下拉 向前翻页时 pageIndex 为 currentPage - 1, draggingLayer 为 currentPage -1  映射，初始状态反转180度
        页面上拉 向后翻页时 pageIndex 为 currentPage , draggingLayer 为 currentPage 映射，初始状态0度默认

        animationNode->flipLayer 0: backLayer是 pageIndex 上半页 初始状态反转 180度
        animationNode->flipLayer 1: frontLayer是 pageIndex 下半页 backLayer 是nextPageIndex上半页面
        animationNode->flipLayer 2: frontLayer是 nextPageIndex 下半页
        对应快照存储在 animationNode 节点中
     */
    private func addTransformLayer(at pageIndex: Int, for direction: FlipDirection) {
        let nodeIndex = pageIndex + 1
        if nodeIndex - 1 < 0, let headerLayer = headerLayer {
            switch direction {
            case .top:
                transformLayer.insertSublayer(headerLayer, at: 0)
            case .bottom:
                transformLayer.addSublayer(headerLayer)
            }
            headerLayer.setNeedsLayout()
        }
        addAllTransformLayer(at: (nodeIndex - 1) ... (nodeIndex + 1), for: direction)

        if nodeIndex + 1 >= totalAnimationNodeCount, let footerLayer = footerLayer {
            switch direction {
            case .top:
                transformLayer.insertSublayer(footerLayer, at: 0)
            case .bottom:
                transformLayer.addSublayer(footerLayer)
            }
            footerLayer.setNeedsLayout()
        }
    }

    /// 添加翻页Layer集合
    /// - Parameters:
    ///   - animatedRange: 动画范围
    ///   - skipRange: 忽略动画范围
    ///   - direction: 方向
    private func addAllTransformLayer(at animatedRange: ClosedRange<Int>, skipRange: ClosedRange<Int>? = nil, for direction: FlipDirection) {
        for (flipIndex, node) in animationNodes.enumerated() where animatedRange.contains(flipIndex) && !(skipRange?.contains(flipIndex) ?? false) {
            let flipSublayer = node.flipLayer ?? node.creatFlipLayer()
            switch direction {
            case .top:
                transformLayer.insertSublayer(flipSublayer, at: 0)
            case .bottom:
                transformLayer.addSublayer(flipSublayer)
            }
        }
        isHidden = false
    }

    /// 当翻页到一个pageIndex,为每个layer计算角度
    private func calculateRotateDegree(_ nodeIndex: Int, toTarget pageIndex: Int) -> CGFloat {
        let currentNodeIndex = pageIndex + 1
        if nodeIndex < currentNodeIndex {
            return 180.0
        } else {
            return 0
        }
    }

    /// 更新Layer层反转角度
    private func updateRotateDegree() {
        for (nodeIndex, node) in animationNodes.enumerated() {
            let rotateDegree = calculateRotateDegree(nodeIndex, toTarget: currentPage)
            node.rotateDegree = rotateDegree
        }
    }

    /// 清除切片
    private func clearSnapshot(all: Bool) {
        let currentNodeIndex = currentPage + 1
        let skipTopRange = 0 ... min(currentNodeIndex, 6)
        let skipLastRange = max(0, currentNodeIndex - 6) ..< currentNodeIndex
        for (nodeIndex, node) in animationNodes.enumerated() where all || !(skipTopRange.contains(nodeIndex) || skipLastRange.contains(nodeIndex)) {
            node.clear()
        }
    }

    /// 切片截图 给动画层Layer配置页面切片
    /// - Parameter pageIndex: 需要配置切片的页面
    internal func snapshotWorkForAnimationNode(at pageIndex: Int) {
        guard totalAnimationNodeCount > 0, pageIndex >= 0 else { return }
        let currentNodeIndex = pageIndex + 1
        let previousNodeIndex = currentNodeIndex - 1
        guard 0 ..< animationNodes.endIndex ~= previousNodeIndex, 0 ..< animationNodes.endIndex ~= currentNodeIndex else {
            return
        }
        let previousNode = animationNodes[previousNodeIndex]
        let currentNode = animationNodes[currentNodeIndex]
        guard let flipPageView = flipView.pageView(at: pageIndex) else { return }
        let snapshotViews = flipPageView.makeVerticalFlipSnapshotViews()
        // guard !snapshotViews.isEmpty else { return }
        // let snapshotImages = flipPageView.makeVerticalFlipSnapshotImages()
        // guard !snapshotImages.isEmpty else { return }
        /// 实时切片
//        previousNode.backImage = snapshotImages.first
//        currentNode.frontImage = snapshotImages.last
        previousNode.backView = snapshotViews.first
        currentNode.frontView = snapshotViews.last
    }

    /// 清除动画层
    private func removeTransformLayer() {
        /// 清除现有fliplayer
        let sublayers = transformLayer.sublayers
        sublayers?.forEach {
            $0.removeFromSuperlayer()
        }
    }
}

// MARK: - dragging

extension FlipTransformView {
    /// 更新反转状态
    /// - Parameter state: 当前状态
    private func updateFlipState(_ state: FlipState) {
        switch state {
        case .stop: /// 停止翻转
            isHidden = true
            removeShadowOnDraggngLayer()
            removeTransformLayer()
            updateRotateDegree()
            clearSnapshot(all: false)
        case .dragging: ()
        case .animating: ()
        }
    }

    /// 开始拖拽
    /// - Parameter translation: 位移
    func dragBegan(_ translation: CGPoint) {
        /// 连续动画就不拖动
        guard flip.state != .animating else { return }

        flip.startTime = CACurrentMediaTime()
        flip.draggingLastTranslationY = translation.y
        /// 如果有正在拖动的页面，取消拖动的动画
        flip.draggingLayer?.cancelDragAnimation()
        flip.state = .dragging
    }

    /// 结束拖拽
    /// - Parameter translation: 位移
    func dragEnded(_ translation: CGPoint) {
        guard flip.state == .dragging else { return }
        if flip.isHeaderOrFooterDragging {
            flip.isHeaderOrFooterDragging = false
            let translationDistance = translation.y - flip.draggingLastTranslationY
            flipView.currentPageView?.dragEnded(translationDistance)
        }
        guard flip.draggingLayer != nil else {
            /// 拖动手势可能直接从 began 到 end，如果拖动速度很快的话，这时没有拖动的页面，应该立刻结束拖动状态
            flip.state = .stop
            return
        }

        let dragDuration = abs(CACurrentMediaTime() - flip.startTime)
        ///  是否快速滑动翻页
        let isQuickDragFlip = dragDuration < (1 - flipCriticalSpeed)
        switch flip.direction {
        case .top:
            dragEndedToTopDirection(translation, isQuickDragFlip)
        case .bottom:
            dragEndedToBottomDirection(translation, isQuickDragFlip)
        }
    }

    /// next page
    private func dragEndedToTopDirection(_: CGPoint, _ isQuickDragFlip: Bool) {
        guard
            let nodeIndex = flip.draggingNodeIndex
        else { return }
        /// 不是最后一页，要么翻页超过90度，要么快速翻页超过临界度
        /// 手势滑动过程中有1度的临界角度 ，此时表明已经结束或者回到起始点
        let isCriticalDegree = abs(flip.draggingLayer.rotateDegree - 180.0) <= 1 || abs(flip.draggingLayer.rotateDegree) <= 1
        if nodeIndex != totalAnimationNodeCount - 1, flip.draggingLayer.rotateDegree >= 90.0 || (flip.draggingLayer.rotateDegree >= flipCriticalAngle && isQuickDragFlip) {
            removeShadowOnDraggngLayer()
            let nextPage = currentPage + 1
            let newRotateDegree = calculateRotateDegree(nodeIndex, toTarget: nextPage)
            let duration: CGFloat = isCriticalDegree ? 0 : duration(with: newRotateDegree - flip.draggingLayer.rotateDegree)
            let work = { [weak self] in
                guard let self = self else { return }
                /// 反转完成 移除最上层layer防止差位闪烁
                self.transformLayer.sublayers?.last?.removeFromSuperlayer()
                self.flip.draggingLayer = nil
                self.updatePage(nextPage, state: .stop)
            }
            if isCriticalDegree {
                flip.draggingLayer.rotateDegree = newRotateDegree
                work()
            } else {
                flip.draggingLayer.setRotateDegree(newRotateDegree, duration: duration, delay: 0.0, completion: work)
            }
        } else {
            /// 返回当前页面
            let oldRotateDegree = calculateRotateDegree(nodeIndex, toTarget: currentPage)
            let duration: CGFloat = isCriticalDegree ? 0 : duration(with: oldRotateDegree - flip.draggingLayer.rotateDegree)
            if nodeIndex == totalAnimationNodeCount - 1, footerLayer?.state != .noMoreData {
                /// 反转进度超过阈值 进入刷新
                let pullingPercent = flip.draggingLayer.rotateDegree / 90.0
                if pullingPercent >= refreshThreshold {
                    footerLayer?.updateState(.refreshing, delay: duration)
                }
            }
            let work = { [weak self] in
                guard let self = self else { return }
                self.flip.draggingLayer = nil
                self.flip.state = .stop
            }
            if isCriticalDegree {
                flip.draggingLayer.rotateDegree = oldRotateDegree
                work()
            } else {
                flip.draggingLayer.setRotateDegree(oldRotateDegree, duration: duration, delay: 0, completion: work)
            }
        }
    }

    /// previous page
    /// - Parameters:
    ///   - translation:
    ///   - isQuickDragFlip: 快速拖动翻页
    private func dragEndedToBottomDirection(_: CGPoint, _ isQuickDragFlip: Bool) {
        guard
            let nodeIndex = flip.draggingNodeIndex
        else { return }
        /// 返回现在的页面，超过90度或者临界角度度快速滑动
        /// 不是第一页，要么翻页超过90度，要么快速翻页超过临界度
        /// 手势滑动过程中有1度的临界角度 ，此时表明已经结束或者回到起始点
        let isCriticalDegree = abs(flip.draggingLayer.rotateDegree - 180.0) <= 1 || abs(flip.draggingLayer.rotateDegree) <= 1
        if nodeIndex != 0, flip.draggingLayer.rotateDegree <= 90.0 || (flip.draggingLayer.rotateDegree <= 180.0 - flipCriticalAngle && isQuickDragFlip) {
            removeShadowOnDraggngLayer()
            let previousPage = currentPage - 1
            let newRotateDegree = calculateRotateDegree(nodeIndex, toTarget: previousPage)
            let duration: CGFloat = isCriticalDegree ? 0 : duration(with: newRotateDegree - flip.draggingLayer.rotateDegree)
            let work = { [weak self] in
                guard let self = self else { return }
                /// 反转完成 移除最上层layer防止差位闪烁
                self.transformLayer.sublayers?.last?.removeFromSuperlayer()
                self.flip.draggingLayer = nil
                self.flip.draggingNodeIndex = nil
                self.updatePage(previousPage, state: .stop)
            }
            if isCriticalDegree {
                flip.draggingLayer.rotateDegree = newRotateDegree
                work()
            } else {
                flip.draggingLayer.setRotateDegree(newRotateDegree, duration: duration, delay: 0, completion: work)
            }
        } else {
            /// 返回当前页面
            let oldRotateDegree = calculateRotateDegree(nodeIndex, toTarget: currentPage)
            let duration: CGFloat = isCriticalDegree ? 0 : duration(with: oldRotateDegree - flip.draggingLayer.rotateDegree)
            if nodeIndex == 0 {
                /// 反转进度超过阈值 进入刷新
                let pullingPercent = (180 - flip.draggingLayer.rotateDegree) / 90.0
                if pullingPercent >= refreshThreshold {
                    headerLayer?.updateState(.refreshing, delay: duration)
                }
            }
            let work = { [weak self] in
                guard let self = self else { return }
                self.flip.draggingLayer = nil
                self.flip.draggingNodeIndex = nil
                self.flip.state = .stop
            }
            if isCriticalDegree {
                flip.draggingLayer.rotateDegree = oldRotateDegree
                work()
            } else {
                flip.draggingLayer.setRotateDegree(oldRotateDegree, duration: duration, delay: 0, completion: work)
            }
        }
    }

    /// 动画时间转换
    /// - Parameter rotateDegree: 翻转角度
    /// - Returns: 动画时间
    private func duration(with rotateDegree: CGFloat) -> CGFloat {
        return max((abs(rotateDegree) / 180.0) * fullDuration, fullDuration * 0.25)
    }

    /// 正在拖拽
    /// - Parameter translation: 位移
    func dragging(_ translation: CGPoint) {
        guard flip.state == .dragging else { return }

        /// 处理 header 和 footer刷新边界
        if translation.y > 0, currentPage == 0, headerLayer == nil {
            flip.isHeaderOrFooterDragging = true
            let translationDistance = translation.y - flip.draggingLastTranslationY
            flipView.currentPageView?.dragging(translationDistance)
            return
        }

        if translation.y <= 0, currentPage == totalPageCount - 1, footerLayer == nil {
            flip.isHeaderOrFooterDragging = true
            let translationDistance = translation.y - flip.draggingLastTranslationY
            flipView.currentPageView?.dragging(translationDistance)
            return
        }

        /// 一开始的时候要知道是在拖动那一页 获取需要拖动的页面和方向
        if flip.draggingLayer == nil {
            let previousPage = currentPage - 1
            let nextPage = currentPage + 1
            snapshotWorkForAnimationNode(at: currentPage)
            if translation.y > 0 {
                let nodeIndex = previousPage + 1
                snapshotWorkForAnimationNode(at: previousPage)
                flip.draggingLayer = animationNodes[nodeIndex].creatFlipLayer()
                flip.draggingNodeIndex = nodeIndex
                flip.direction = .bottom
                addTransformLayer(at: previousPage, for: .bottom)
            } else {
                let nodeIndex = currentPage + 1
                snapshotWorkForAnimationNode(at: nextPage)
                flip.draggingLayer = animationNodes[nodeIndex].creatFlipLayer()
                flip.draggingNodeIndex = nodeIndex
                flip.direction = .top
                addTransformLayer(at: currentPage, for: .top)
            }
        }
        let diffDegree = (translation.y - flip.draggingLastTranslationY) * 0.5
        var rotateDegree = flip.draggingLayer.rotateDegree - diffDegree
        switch flip.direction {
        case .top: /// next Page
            /// 最后一页无法继续翻转 处理footerLayer的逻辑
            if flip.draggingNodeIndex == totalAnimationNodeCount - 1 {
                rotateDegree = min(rotateDegree, 89.0)
                let pullingPercent = rotateDegree / 90.0
                /// 反转进度超过阈值 进入刷新
                if footerLayer?.state != .noMoreData {
                    if pullingPercent >= refreshThreshold {
                        footerLayer?.updateState(.pulling)
                    } else {

                        footerLayer?.updateState(.willRefresh)
                    }
                }
            } else {
                rotateDegree = min(rotateDegree, 179.0)
            }
            rotateDegree = max(rotateDegree, 1.0)
            flip.draggingLayer.rotateDegree = rotateDegree
        case .bottom:
            rotateDegree = min(rotateDegree, 179.0)
            /// 第一页是无法继续翻转 处理headerLayer的逻辑
            if flip.draggingNodeIndex == 0 {
                rotateDegree = max(rotateDegree, 91.0)
                let pullingPercent = (180 - rotateDegree) / 90.0
                /// 反转进度超过阈值 进入刷新
                if pullingPercent >= refreshThreshold {
                    headerLayer?.updateState(.pulling)
                } else {
                    headerLayer?.updateState(.willRefresh)
                }
            } else {
                rotateDegree = max(rotateDegree, 1.0)
            }
            flip.draggingLayer.rotateDegree = rotateDegree
        }

        flip.draggingLastTranslationY = translation.y

        /// 设置阴影
        showShadowOnDraggingLayer()
    }
}

// MARK: - Shadow

extension FlipTransformView {

    /// 根据现在的页面拖动的角度计算另外两层页面的阴影
    func showShadowOnDraggingLayer() {
        /// 当前正在拖动的这层有一个固定明度的阴影
        let minOpacity: Float = 0.01
        flip.draggingLayer?.showShadowOpacity(minOpacity)
        guard
            let nodeIndex = flip.draggingNodeIndex
        else {
            return
        }
        var previousShadowLayer: FlipLayer?
        if 0 ..< animationNodes.endIndex ~= nodeIndex - 1 {
            previousShadowLayer = animationNodes[nodeIndex - 1].flipLayer
        }

        var nextShadowLayer: FlipLayer?
        if 0 ..< animationNodes.endIndex ~= nodeIndex + 1 {
            nextShadowLayer = animationNodes[nodeIndex + 1].flipLayer
        }
        if flip.draggingLayer.rotateDegree < 90 {
            let progress = flip.draggingLayer.rotateDegree / 90.0
            previousShadowLayer?.removeShadow()
            nextShadowLayer?.showShadowOpacity(max(minOpacity, Float(1 - progress) / 2.0), on: .front)
        } else {
            let progress = flip.draggingLayer.rotateDegree / 90.0 - 1.0
            previousShadowLayer?.showShadowOpacity(max(minOpacity, Float(progress) / 2.0), on: .back)
            nextShadowLayer?.removeShadow()
        }
    }

    /// 去掉图层阴影
    func removeShadowOnDraggngLayer() {
        /// 不循环所有层，只处理涉及当前翻页交互的几层
        flip.draggingLayer?.removeShadow()
        guard
            flip.draggingLayer != nil,
            let nodeIndex = flip.draggingNodeIndex
        else {
            return
        }
        if 0 ..< animationNodes.endIndex ~= nodeIndex - 1 {
            animationNodes[nodeIndex - 1].flipLayer?.removeShadow()
        }
        if 0 ..< animationNodes.endIndex ~= nodeIndex + 1 {
            animationNodes[nodeIndex + 1].flipLayer?.removeShadow()
        }
    }
}

// swiftlint:enable nesting line_length cyclomatic_complexity function_body_length file_length
