//
//  FlipPageContainer.swift
//  FlipViewController
//
//  Created by 吴哲 on 2023/5/22.
//

import UIKit

/// PageView容器
public protocol FlipPageContainer: UIView {
    var flipView: FlipView! { get set }

    var flipViewDelegate: FlipViewDelegate? { get set }

    var flipViewDataSource: FlipViewDataSource? { get set }

    /// 当前页面pageView
    var currentPageView: FlipPageView? { get }

    /// 当前页
    var currentPage: Int { get }

    /// 注册page
    func register(_ pageViewClass: FlipPageView.Type, forPageViewReuseIdentifier identifier: String)

    /// 从缓存池获取PageView
    func dequeuePageView(withIdentifier identifier: String, for pageIndex: Int) -> FlipPageView

    /// 刷新并定位到指定page
    /// - Parameters:
    ///   - page: 指定页
    ///   - completion: 完成回调
    func reloadPages(to page: Int, completion: @escaping () -> Void)

    /// 加载更多
    /// - Parameters:
    ///   - range: 新增page区间
    ///   - completion: 完成回调
    func loadMore(_ range: Range<Int>, completion: @escaping (() -> Void))

    /// 翻转到指定页
    /// - Parameters:
    ///   - page: 指定配置
    ///   - completion: 跳转回调
    func flipPage(to page: Int, completion: @escaping () -> Void)

    /// 获取指定页PageView
    /// - Parameter page: 指定page
    /// - Returns: PageView
    func pageView(at page: Int) -> FlipPageView?

    /// 屏幕旋转
    func viewWillTransitionSize(to size: CGSize)
}

/// PageView 容器
public protocol FlipPageViewWrapperBinder: AnyObject {
    var pageView: FlipPageView! { get set }
    func bindPageView(_ pageView: FlipPageView)
}
