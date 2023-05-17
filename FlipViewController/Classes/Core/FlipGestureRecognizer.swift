//
//  FlipGestureRecognizer.swift
//  FlipViewController
//
//  Created by 吴哲 on 2023/5/17.
//

import UIKit

/// Flip 翻页手势
/// http://stackoverflow.com/questions/7100884/uipangesturerecognizer-only-vertical-or-horizontal%E2%80%8B
final class FlipGestureRecognizer: UIPanGestureRecognizer {

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesMoved(touches, with: event)
        guard case .began = state else { return }
        let velocity = velocity(in: view)
        if abs(velocity.x) > abs(velocity.y) {
            state = .failed
        }
    }
}
