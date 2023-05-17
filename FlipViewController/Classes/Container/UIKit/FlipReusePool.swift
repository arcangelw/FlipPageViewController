//
//  FlipReusePool.swift
//  FlipViewController
//
//  Created by 吴哲 on 2023/5/17.
//

import Foundation
import UIKit

/// PageView缓存池
final class FlipReusePool {

    /// 缓存
    private lazy var reuseNodeMap: [String: ReuseNode] = [:]

    /// 添加到缓存
    func addPageView(_ pageView: FlipPageView, for reuseIdentifier: String) {
        guard !reuseIdentifier.isEmpty else {
            assertionFailure("reuseIdentifier can not empty")
            return
        }
        let reuseNode: ReuseNode
        if let node = reuseNodeMap[reuseIdentifier] {
            reuseNode = node
        } else {
            reuseNode = .init()
            reuseNodeMap[reuseIdentifier] = reuseNode
        }
        reuseNode.set.insert(pageView)
    }

    /// 获取缓存
    /// - Parameters:
    ///   - identifier: 复用标识符
    ///   - pageIndex: page索引
    /// - Returns: 缓存pageView
    func dequeuePageView(withIdentifier identifier: String, for pageIndex: Int? = nil) -> FlipPageView? {
        guard !identifier.isEmpty else {
            assertionFailure("reuseIdentifier can not empty")
            return nil
        }

        guard let reuseNode = reuseNodeMap[identifier], !reuseNode.set.isEmpty else { return nil }

        let pageView: FlipPageView
        if let pageIndex = pageIndex, let reuseView = reuseNode.set.first(where: { $0._pageIndex == pageIndex }) {
            pageView = reuseView
        } else {
            pageView = reuseNode.set.randomElement()!
        }
        reuseNode.set.remove(pageView)

        return pageView
    }

    /// 清理所有缓存
    func clear() {
        reuseNodeMap.removeAll()
    }

    /// 获取所有缓存
    var allPageViews: Set<FlipPageView> {
        return reuseNodeMap.values.reduce(into: Set<FlipPageView>()) {
            $0.formUnion($1.set)
        }
    }
}

extension FlipReusePool {

    /// 缓存节点
    private class ReuseNode {
        lazy var set: Set<FlipPageView> = .init()
    }
}
