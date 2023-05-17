//
//  FlipLayerNode.swift
//  FlipViewController
//
//  Created by 吴哲 on 2023/6/9.
//

import UIKit

/// 翻页动画节点
final class FlipAnimationNode {
    /// FlipLayer frame
    var layerFrame: CGRect = .zero
    /// 翻转角度
    var rotateDegree: CGFloat = 0
    /// 前置页快照
    var frontImage: UIImage?
    /// 后置页快照
    var backImage: UIImage?
    /// 前置页快照视图
    var frontView: UIView?
    /// 后置页快照视图
    var backView: UIView?

    /// 对应的FlipLayer引用
    weak var flipLayer: FlipLayer?

    /// 根据节点信息创建flipLayer
    func creatFlipLayer() -> FlipLayer {
        let layer = FlipLayer(frame: layerFrame)
        layer.rotateDegree = rotateDegree
        // layer.setSnapshotContents(frontImage?.cgImage, on: .front)
        // layer.setSnapshotContents(backImage?.cgImage, on: .back)
        layer.setSnapshotView(frontView, on: .front)
        layer.setSnapshotView(backView, on: .back)
        flipLayer = layer
        return layer
    }

    /// 清理节点
    func clear() {
        flipLayer?.clearSnapshot()
        frontImage = nil
        backImage = nil
        frontView = nil
        backView = nil
    }
}
