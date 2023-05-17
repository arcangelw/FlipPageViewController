//
//  FlipRefreshLayer.swift
//  FlipViewController
//
//  Created by 吴哲 on 2023/5/19.
//

import UIKit

/// loading指示器
open class FlipRefreshLayer: CALayer {
    /// 刷新回调
    public var refreshHandler: (() -> Void)?

    /// 刷新状态
    public enum State {
        /// 空闲状态
        case idle
        /// 即将刷新
        case willRefresh
        /// 松开就可以进行刷新
        case pulling
        /// 刷新中
        case refreshing
        /// 没有更多数据
        case noMoreData
    }

    open dynamic var state: State = .idle {
        didSet {
            guard oldValue != state else { return }
            updateState(state)
        }
    }

    /// 调度
    private var workItem: DispatchWorkItem?

    override public init() {
        super.init()
    }

    override public init(layer: Any) {
        super.init(layer: layer)
        guard let layer = layer as? FlipRefreshLayer else {
            return
        }
        state = layer.state
        refreshHandler = layer.refreshHandler
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    open func beginRefresh() {
        guard state != .noMoreData else { return }
        state = .refreshing
    }

    open func endRefresh() {
        state = .idle
    }

    open func endRefreshWithNoMoreData() {
        state = .noMoreData
    }

    /// 状态变化
    /// - Parameters:
    ///   - state: 状态
    ///   - delay: 延时调用时间
    open func updateState(_ state: State, delay: CGFloat? = nil) {
        if case .refreshing = state, let refreshHandler = refreshHandler {
            workItem?.cancel()
            workItem = .init(block: refreshHandler)
            if let delay = delay {
                DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem!)
            } else {
                workItem?.perform()
            }
        }
        setNeedsDisplay()
    }
}
