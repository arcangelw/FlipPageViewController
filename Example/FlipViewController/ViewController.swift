//
//  ViewController.swift
//  FlipViewController
//
//  Created by arcangel-w on 05/17/2023.
//  Copyright (c) 2023 arcangel-w. All rights reserved.
//

import FlipViewController
import UIKit

extension UIColor {
    /// 随机色
    static var randomColor: UIColor {
        UIColor(
            red: CGFloat.random(in: 0.0 ... 255.0) / 255.0,
            green: CGFloat.random(in: 0.0 ... 255.0) / 255.0,
            blue: CGFloat.random(in: 0.0 ... 255.0) / 255.0,
            alpha: 1.0
        )
    }
}

final class PageView: FlipPageView {
    let colorView = UILabel()
    var topConstraint: NSLayoutConstraint?
    override init(frame: CGRect) {
        super.init(frame: frame)
        colorView.textColor = .white
        colorView.textAlignment = .center
        colorView.font = UIFont.systemFont(ofSize: 160)
        contentView.addSubview(colorView)
        colorView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            colorView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            colorView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            colorView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -20),
        ])
        topConstraint = colorView.topAnchor.constraint(equalTo: topAnchor, constant: 20)
        topConstraint?.isActive = true
    }

    override func dragging(_ offset: CGFloat) {
        super.dragging(offset)
        topConstraint?.constant = offset + 20
    }

    override func dragEnded(_ offset: CGFloat) {
        super.dragEnded(offset)
        UIView.animate(withDuration: 0.5) {
            self.topConstraint?.constant = 20
        }
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

final class ViewController: FlipViewController {
    let colors: [UIColor] = [
        .red, .orange, .yellow, .green, .cyan, .blue, .purple,
    ]

    @IBOutlet var indicatorBackgroundView: UIView!

    @IBOutlet var indicatorView: UIActivityIndicatorView!

    var multiple = 4

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        view.bringSubviewToFront(indicatorBackgroundView)
        flipView.register(PageView.self, forPageViewReuseIdentifier: String(reflecting: PageView.self))
        view.layoutIfNeeded()
        flipView.reloadPages(to: 1)
        let header = FlipActivityIndicatorLayer(indicatorStyle: .header)
        header.refreshHandler = { [weak self] in
            self?.reload()
        }
        flipView.headerLayer = header
        let footer = FlipActivityIndicatorLayer(indicatorStyle: .footer)
        footer.refreshHandler = { [weak self] in
            self?.loadMore()
        }
        flipView.footerLayer = footer
    }

    private func reload() {
        startAnimating()
        flipView.flipable = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            self.multiple = 1
            self.flipView.flipable = true
            self.flipView.reloadPages(to: 2) { [weak self] in
                self?.stopAnimating()
            }
        }
    }

    private func loadMore() {
        startAnimating()
        flipView.flipable = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            self.multiple += 1
            self.flipView.flipable = true
            self.flipView.loadMore { [weak self] in
                self?.stopAnimating()
            }
        }
    }

    private func startAnimating() {
        indicatorBackgroundView.isHidden = false
        indicatorView.startAnimating()
    }

    private func stopAnimating() {
        indicatorBackgroundView.isHidden = true
        indicatorView.stopAnimating()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        flipView.flipPage(to: 27)
    }

    override func flipView(_ flipView: FlipView, pageViewAt pageIndex: Int) -> FlipPageView {
        let pageView = flipView.dequeuePageView(withIdentifier: String(reflecting: PageView.self), for: pageIndex) as! PageView
        let index = pageIndex % colors.count
        pageView.colorView.backgroundColor = colors[index]
        pageView.colorView.text = "\(pageIndex)"
        return pageView
    }

    override func numberOfPages(in _: FlipView) -> Int {
        return colors.count * multiple
    }
    
    override func flipView(_ flipView: FlipView, willDisplay pageView: FlipPageView, forPageAt pageIndex: Int) {
        debugPrint(#function, pageIndex)
    }
    
    override func flipView(_ flipView: FlipView, didEndDisplaying pageView: FlipPageView, forPageAt pageIndex: Int) {
        debugPrint(#function, pageIndex)
    }
}
