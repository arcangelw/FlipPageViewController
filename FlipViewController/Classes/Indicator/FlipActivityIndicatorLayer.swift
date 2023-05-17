//
//  FlipActivityIndicatorLayer.swift
//  FlipViewController
//
//  Created by 吴哲 on 2023/5/23.
//

import UIKit

/// 刷新指示器
private class FlipActivityIndicatorView: UIView {
    /// 指示器
    let indicatorView = UIActivityIndicatorView(style: .white)
    /// 标识图片
    let imageView = UIImageView()
    /// 刷新状态提示
    let titleLabel = UILabel()

    /// 指示器位置
    let indicatorStyle: FlipActivityIndicatorLayer.IndicatorStyle

    /// 通过位置初始化
    init(indicatorStyle: FlipActivityIndicatorLayer.IndicatorStyle) {
        self.indicatorStyle = indicatorStyle
        super.init(frame: .zero)
        setUpSelf()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// 标识图标旋转
    private var willTransform: Bool = false {
        didSet {
            guard oldValue != willTransform else { return }
            let transform = CGAffineTransformMakeRotation(willTransform ? .pi : (-2.0 * .pi))
            UIView.animate(withDuration: 0.2) {
                self.imageView.transform = transform
            }
        }
    }

    /// 配置元素布局
    private func setUpSelf() {
        imageView.image = Flip.image(named: "flip_refresh")
        addSubview(imageView)
        addSubview(indicatorView)
        addSubview(titleLabel)
        imageView.translatesAutoresizingMaskIntoConstraints = false
        indicatorView.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            imageView.widthAnchor.constraint(equalToConstant: 24),
            imageView.heightAnchor.constraint(equalToConstant: 24),
            imageView.leadingAnchor.constraint(equalTo: leadingAnchor),
            imageView.centerYAnchor.constraint(equalTo: centerYAnchor),
            imageView.topAnchor.constraint(equalTo: topAnchor, constant: 0),
            indicatorView.centerXAnchor.constraint(equalTo: imageView.centerXAnchor),
            indicatorView.centerYAnchor.constraint(equalTo: imageView.centerYAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: imageView.trailingAnchor, constant: 10),
            titleLabel.centerYAnchor.constraint(equalTo: imageView.centerYAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor)
        ])
    }

    /// 状态切换
    func updateState(_ state: FlipRefreshLayer.State) {
        willTransform = state == .pulling
        switch state {
        case .idle, .willRefresh:
            switch indicatorStyle {
            case .header:
                titleLabel.text = "下拉可以刷新"
            case .footer:
                titleLabel.text = "上拉可以加载更多"
            }
        case .pulling:
            titleLabel.text = "松开立即刷新"
        case .refreshing:
            switch indicatorStyle {
            case .header:
                titleLabel.text = "正在刷新数据中..."
            case .footer:
                titleLabel.text = "正在加载更多的数据..."
            }
        case .noMoreData:
            imageView.transform = .identity
            titleLabel.text = "已经全部加载完毕"
        }
        if case .refreshing = state {
            imageView.isHidden = true
            indicatorView.startAnimating()
        } else {
            imageView.isHidden = false
            indicatorView.stopAnimating()
        }
        layoutIfNeeded()
    }
}

/// 刷新指示器Layer层包装
public final class FlipActivityIndicatorLayer: FlipRefreshLayer {

    /// 指示器icon配图
    public var indicatorImage: UIImage? {
        didSet {
            indicatorView.imageView.image = indicatorImage
            setNeedsDisplay()
        }
    }

    /// 指示器文字颜色
    public var indicatorColor: UIColor? {
        didSet {
            indicatorView.titleLabel.textColor = indicatorColor
            indicatorView.indicatorView.color = indicatorColor
        }
    }

    /// 指示器文字字体
    public var indicatorFont: UIFont? {
        didSet {
            indicatorView.titleLabel.font = indicatorFont
        }
    }

    /// 横向边距
    public var horizontalMargin: CGFloat = 20

    /// 边界距离 按照 IndicatorStyle 位置配置
    public var offset: CGFloat {
        didSet {
            setNeedsDisplay()
        }
    }

    /// 位置
    public enum IndicatorStyle {
        case header
        case footer
    }

    /// UIView 指示器
    private let indicatorView: FlipActivityIndicatorView

    /// 指示器位置
    public let indicatorStyle: IndicatorStyle

    /// 通过指示器位置创建
    public init(indicatorStyle: IndicatorStyle) {
        self.indicatorStyle = indicatorStyle
        indicatorView = .init(indicatorStyle: indicatorStyle)
        offset = indicatorStyle == .header ? 50 : 60
        super.init()
        addSublayer(indicatorView.layer)
    }

    override public init(layer: Any) {
        if let layer = layer as? FlipActivityIndicatorLayer {
            indicatorStyle = layer.indicatorStyle
            indicatorView = layer.indicatorView
            offset = layer.offset
        } else {
            indicatorStyle = .header
            indicatorView = .init(indicatorStyle: indicatorStyle)
            offset = indicatorStyle == .header ? 50 : 60
        }
        super.init(layer: layer)
    }

    @available(*, unavailable)
    public required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// 布局计算
    override public func layoutSublayers() {
        super.layoutSublayers()
        if indicatorView.layer.superlayer == nil {
            addSublayer(indicatorView.layer)
        }
        guard bounds.size != .zero else { return }
        let rect = bounds.inset(
            by: UIEdgeInsets(top: offset, left: horizontalMargin, bottom: offset, right: horizontalMargin)
        )
        let size = indicatorView.systemLayoutSizeFitting(rect.size)
        switch indicatorStyle {
        case .header:
            indicatorView.frame = .init(
                x: rect.minX, y: rect.minY,
                width: rect.width, height: size.height
            )
        default:
            indicatorView.frame = .init(
                x: rect.minX, y: rect.maxY - size.height,
                width: rect.width, height: size.height
            )
        }
        indicatorView.layer.frame = indicatorView.frame
        indicatorView.layoutIfNeeded()
    }

    /// 更新状态
    override public func updateState(_ state: FlipRefreshLayer.State, delay: CGFloat? = nil) {
        super.updateState(state, delay: delay)
        indicatorView.updateState(state)
    }
}
