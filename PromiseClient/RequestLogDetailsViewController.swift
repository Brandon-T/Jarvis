//
//  RequestLogDetailsViewController.swift
//  PromiseClient
//
//  Created by Brandon Anthony on 2019-06-20.
//  Copyright © 2019 SO. All rights reserved.
//

import Foundation
import UIKit
import Jarvis

class RequestLogDetailsViewController: UIViewController {
    private let tabBar = TabBar(tabTitles: ["Request", "Response"])
    private let infoView = UITextView(frame: .zero)
    
    var requestLog: RequestLogger.RequestPacket? {
        didSet {
            updateInfoView(index: 0)
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = .white
        infoView.showsVerticalScrollIndicator = true
        infoView.isEditable = false
        
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
            
            self?.infoView.text = ""
            self?.updateInfoView(index: index)
        })
    }
    
    private func attributedText(_ text: String, weight: UIFont.Weight, size: CGFloat, colour: UIColor) -> NSAttributedString {
        return NSAttributedString(string: text, attributes: [
            .font: UIFont.systemFont(ofSize: size, weight: weight),
            .foregroundColor: colour
        ])
    }
    
    private func updateInfoView(index: Int) {
        guard let requestLog = requestLog else {
            return
        }
        
        if index == 0 {
            let startDate = requestLog.startDate
            let components = Calendar.current.dateComponents([.second, .minute, .hour], from: startDate)
            let date = String(format: "[%02ld:%02ld:%02ld]", components.hour!, components.minute!, components.second!) //swiftlint:disable:this force_unwrapping
            
            let logData = NSMutableAttributedString(string: "", attributes: [
                .font: UIFont.systemFont(ofSize: 12.0, weight: .medium),
                .foregroundColor: UIColor.lightGray
            ])
            
            // Normalize host
            var host = requestLog.request.url?.host ?? ""
            host = host.isEmpty ? "localhost" : host
            
            // Normalize path
            var path = requestLog.request.url?.path ?? ""
            path = path.isEmpty ? "/" : path
            
            // Normalize query
            let query = requestLog.request.url?.query ?? ""
            
            // Normalize headers
            var requestHeaders = requestLog.request.allHTTPHeaderFields ?? [:]
            requestHeaders.removeValue(forKey: "Host")
            
            logData.append(attributedText("\(date) ", weight: .bold, size: 12.0, colour: .orange))
            logData.append(attributedText("\(requestLog.request.httpMethod?.uppercased() ?? "GET") ", weight: .bold, size: 12.0, colour: .black))
            logData.append(attributedText("\(path)\n", weight: .bold, size: 12.0, colour: .black))
            
            logData.append(attributedText("Host: ", weight: .bold, size: 12.0, colour: .orange))
            logData.append(attributedText("\(host)\n", weight: .medium, size: 12.0, colour: .black))
            
            if !query.isEmpty {
                logData.append(attributedText("Query: ", weight: .bold, size: 12.0, colour: .orange))
                logData.append(attributedText("\(query)\n", weight: .medium, size: 12.0, colour: .black))
            }
            
            logData.append(attributedText("\n", weight: .medium, size: 12.0, colour: .black))
            
            logData.append(attributedText("Headers:\n", weight: .bold, size: 12.0, colour: .orange))
            logData.append(attributedText("\(indent(requestHeaders.compactMap({ "\($0.key): \($0.value)" }).joined(separator: "\n")))\n\n", weight: .medium, size: 12.0, colour: .black))
            
            let body = String(data: requestLog.request.httpBody ?? Data(), encoding: .utf8) ?? ""
            if !body.isEmpty {
                logData.append(attributedText("Body:\n", weight: .bold, size: 12.0, colour: .orange))
                logData.append(attributedText("\(indent(body))\n\n", weight: .medium, size: 12.0, colour: .black))
            }
            
            infoView.attributedText = logData
        }
        else {
            let startDate = requestLog.startDate
            let endDate = requestLog.endDate
            let timeInterval = endDate.timeIntervalSince(startDate)
            
            let components = Calendar.current.dateComponents([.second, .minute, .hour], from: startDate)
            let date = String(format: "[%02ld:%02ld:%02ld]", components.hour!, components.minute!, components.second!) //swiftlint:disable:this force_unwrapping
            
            let logData = NSMutableAttributedString(string: "", attributes: [
                .font: UIFont.systemFont(ofSize: 12.0, weight: .medium),
                .foregroundColor: UIColor.lightGray
            ])
            
            // Normalize host
            var host = requestLog.request.url?.host ?? ""
            host = host.isEmpty ? "localhost" : host
            
            // Normalize path
            var path = requestLog.request.url?.path ?? ""
            path = path.isEmpty ? "/" : path
            
            // Normalize headers
            var responseHeaders = requestLog.response.allHeaderFields
            responseHeaders.removeValue(forKey: "Host")
            
            // Normalize body
            let contentType = requestLog.response.allHeaderFields["Content-Type"] as? String ?? "application/octet-stream"
            
            logData.append(attributedText("\(date) ", weight: .bold, size: 12.0, colour: .orange))
            logData.append(attributedText("\(requestLog.request.httpMethod?.uppercased() ?? "GET") ", weight: .bold, size: 12.0, colour: .black))
            logData.append(attributedText("\(path)\n", weight: .bold, size: 12.0, colour: .black))
            
            logData.append(attributedText("Host: ", weight: .bold, size: 12.0, colour: .orange))
            logData.append(attributedText("\(host)\n", weight: .medium, size: 12.0, colour: .black))
            
            logData.append(attributedText("\n", weight: .medium, size: 12.0, colour: .black))
            
            // Log Status Code
            if let error = requestLog.error as? URLError, error.code == .cancelled {
                logData.append(attributedText("Status: ", weight: .bold, size: 12.0, colour: .orange))
                logData.append(attributedText("\(requestLog.response.statusCode) CANCELLED\n\n", weight: .medium, size: 12.0, colour: .black))
            }
            else {
                logData.append(attributedText("Status: ", weight: .bold, size: 12.0, colour: .orange))
                logData.append(attributedText("\(requestLog.response.statusCode) \(requestLog.response.statusCode == 200 ? "OK" : HTTPURLResponse.localizedString(forStatusCode: requestLog.response.statusCode).uppercased())\n\n", weight: .medium, size: 12.0, colour: .black))
            }
            
            logData.append(attributedText("Elapsed Time: ", weight: .bold, size: 12.0, colour: .orange))
            logData.append(attributedText("\(String(format: "%.3fs", timeInterval))\n", weight: .medium, size: 12.0, colour: .black))
            
            logData.append(attributedText("Headers:\n", weight: .bold, size: 12.0, colour: .orange))
            logData.append(attributedText("\(indent(responseHeaders.compactMap({ "\($0.key): \($0.value)" }).joined(separator: "\n")))\n\n", weight: .medium, size: 12.0, colour: .black))
            
            let body = requestLog.responseData ?? Data()
            if !body.isEmpty {
                var bodyData = ""
                if contentType.starts(with: "text") {
                    let decodedBody = String(data: body, encoding: .utf8) ?? String(data: body, encoding: .ascii) ?? ""
                    bodyData += decodedBody.isEmpty ? "" : indent(decodedBody)
                }
                else if contentType.starts(with: "image") {
                    bodyData += indent(body.base64EncodedString())
                }
                else if contentType.starts(with: "application/octet-stream") {
                    bodyData += indent(body.base64EncodedString())
                }
                else {
                    bodyData += indent(body.base64EncodedString())
                }
                
                logData.append(attributedText("Body:\n", weight: .bold, size: 12.0, colour: .orange))
                logData.append(attributedText("\(bodyData)\n\n", weight: .medium, size: 12.0, colour: .black))
                
                infoView.attributedText = logData
            }
        }
    }
    
    private func indent(_ input: String, amount: Int = 4) -> String {
        let indentation = String(repeating: " ", count: amount)
        return "\(indentation)\(input.components(separatedBy: "\n").joined(separator: "\n\(indentation)"))"
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
