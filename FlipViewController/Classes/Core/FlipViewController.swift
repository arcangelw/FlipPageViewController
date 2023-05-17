//
//  FlipViewController.swift
//  FlipViewController
//
//  Created by 吴哲 on 2023/5/17.
//

import UIKit

open class FlipViewController: UIViewController, FlipViewDataSource, FlipViewDelegate {

    public let flipView = flipViewClass.init()

    open class var flipViewClass: FlipView.Type {
        return FlipView.self
    }

    override open func viewDidLoad() {
        super.viewDidLoad()
        view.addSubview(flipView)
        flipView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            view.topAnchor.constraint(equalTo: flipView.topAnchor),
            view.bottomAnchor.constraint(equalTo: flipView.bottomAnchor),
            view.leadingAnchor.constraint(equalTo: flipView.leadingAnchor),
            view.trailingAnchor.constraint(equalTo: flipView.trailingAnchor)
        ])
        flipView.delegate = self
        flipView.dataSource = self
    }

    override open func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        coordinator.animate(alongsideTransition: { _ in
            self.view.layoutIfNeeded()
            self.flipView.viewWillTransitionSize(to: size)
        })
    }

    open func numberOfPages(in flipView: FlipView) -> Int {
        fatalError("Subclass implementation \(flipView)")
    }

    open func flipView(_ flipView: FlipView, pageViewAt pageIndex: Int) -> FlipPageView {
        fatalError("Subclass implementation \(flipView) \(pageIndex)")
    }

    open func flipView(_ flipView: FlipView, willDisplay pageView: FlipPageView, forPageAt pageIndex: Int) {}

    open func flipView(_ flipView: FlipView, didEndDisplaying pageView: FlipPageView, forPageAt pageIndex: Int) {}
}
