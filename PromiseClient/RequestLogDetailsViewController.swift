//
//  RequestLogDetailsViewController.swift
//  PromiseClient
//
//  Created by Brandon Anthony on 2019-06-20.
//  Copyright © 2019 SO. All rights reserved.
//

import Foundation
import UIKit

class RequestLogDetailsViewController: UIViewController {
    private let tabBar = TabBar(tabTitles: ["Request", "Response"])
    private let infoView = UITextView(frame: .zero)
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = .white
        
        view.addSubview(tabBar)
        view.addSubview(infoView)
        NSLayoutConstraint.activate([
            tabBar.leftAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leftAnchor),
            tabBar.rightAnchor.constraint(equalTo: view.safeAreaLayoutGuide.rightAnchor),
            tabBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tabBar.heightAnchor.constraint(equalToConstant: 60.0),
            
            infoView.leftAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leftAnchor),
            infoView.rightAnchor.constraint(equalTo: view.safeAreaLayoutGuide.rightAnchor),
            infoView.topAnchor.constraint(equalTo: tabBar.bottomAnchor),
            infoView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        ])
        
        tabBar.translatesAutoresizingMaskIntoConstraints = false
        infoView.translatesAutoresizingMaskIntoConstraints = false
        
        tabBar.addEventHandler(runnable: { [weak self] index in
            self?.tabBar.enableTabs()
        })
    }
}

extension RequestLogDetailsViewController {
    final class TabBar: UIView {
        private var tabs: [TabButton] = []
        private var titles: [String]
        private let stackView = UIStackView(frame: .zero)
        private let verticalStackView = UIStackView(frame: .zero)
        private var eventHandlers = [(Int) -> Void]()
        
        init(tabTitles: [String]) {
            titles = tabTitles
            super.init(frame: .zero)
            
            //Create tabs.
            for title in titles {
                let tab = TabButton(frame: .zero)
                tab.setTitle(title, for: .normal)
                tabs.append(tab)
                tab.addTarget(self, action: #selector(onButtonPressed(tab:)), for: .touchUpInside)
                tab.addTarget(self, action: #selector(onTouchDown(tab:)), for: .touchDown)
            }
            
            //Theme self
            setTheme()
            setActiveTab(index: 0)
            
            //Layout tabs
            for tab in tabs {
                stackView.addArrangedSubview(tab)
            }
            
            //Layout stackView
            addSubview(verticalStackView)
            NSLayoutConstraint.activate([
                verticalStackView.leftAnchor.constraint(equalTo: leftAnchor),
                verticalStackView.rightAnchor.constraint(equalTo: rightAnchor),
                verticalStackView.topAnchor.constraint(equalTo: topAnchor),
                verticalStackView.bottomAnchor.constraint(equalTo: bottomAnchor)
            ])
            
            verticalStackView.addArrangedSubview(stackView)
        }
        
        @available(*, unavailable)
        required init?(coder aDecoder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        private func setTheme() {
            stackView.axis = .horizontal
            stackView.distribution = .fillEqually
            stackView.translatesAutoresizingMaskIntoConstraints = false
            
            verticalStackView.axis = .vertical
            verticalStackView.translatesAutoresizingMaskIntoConstraints = false
        }
        
        func setActiveTab(index: Int) {
            for enumerated in tabs.enumerated() {
                enumerated.element.setBorderHidden(true)
                
                if enumerated.offset == index {
                    enumerated.element.setBorderHidden(false)
                }
            }
        }
        
        func enableTabs() {
            for tab in tabs {
                tab.isUserInteractionEnabled = true
            }
        }
        
        @objc
        private func onButtonPressed(tab: TabButton) {
            if let index = tabs.firstIndex(of: tab) {
                setActiveTab(index: index)
                eventHandlers.forEach({ $0(index) })
            }
        }
        
        @objc
        private func onTouchDown(tab: TabButton) {
            for tab in self.tabs {
                tab.isUserInteractionEnabled = false
            }
            
            tab.isUserInteractionEnabled = true
        }
        
        func addEventHandler(runnable: @escaping (_ selectedIndex: Int) -> Void) {
            eventHandlers.append(runnable)
        }
    }
    
    private final class TabButton: UIButton {
        private let borderView = UIView()
        private let borderThickness: CGFloat = 5.0
        
        override init(frame: CGRect) {
            super.init(frame: frame)
            setTheme()
        }
        
        required init?(coder aDecoder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        private func setTheme() {
            addSubview(borderView)
            contentEdgeInsets = UIEdgeInsets(top: 0.0, left: 0.0, bottom: borderThickness, right: 0.0)
            
            borderView.backgroundColor = .red
            setTitleColor(.blue, for: .normal)
            titleLabel?.font = .systemFont(ofSize: 17.0, weight: .bold)
        }
        
        override func layoutSubviews() {
            super.layoutSubviews()
            
            borderView.frame = CGRect(x: 0.0, y: frame.size.height - borderThickness, width: frame.size.width, height: borderThickness)
        }
        
        func setBorderColour(_ colour: UIColor) {
            borderView.backgroundColor = colour
        }
        
        func setBorderHidden(_ hidden: Bool) {
            borderView.isHidden = hidden
            
            if hidden {
                titleLabel?.font = .systemFont(ofSize: 17.0, weight: .medium)
            } else {
                titleLabel?.font = .systemFont(ofSize: 17.0, weight: .bold)
            }
        }
    }
}
