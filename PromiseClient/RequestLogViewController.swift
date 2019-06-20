//
//  RequestLogViewController.swift
//  PromiseClient
//
//  Created by Brandon Anthony on 2019-06-20.
//  Copyright © 2019 SO. All rights reserved.
//

import Foundation
import UIKit
import Jarvis

class RequestLogViewController: UIViewController {
    private var packets = [RequestLogger.RequestPacket]()
    private var packetObserver: RequestLogger.RequestLogObserver?
    private let tableView = UITableView(frame: .zero, style: .grouped)
    
    init(_ logger: RequestLogger) {
        super.init(nibName: nil, bundle: nil)
        
        self.packetObserver = logger.requestLogs.observe({ [weak self] new, _ in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                self.packets = new
                self.tableView.reloadData()
            }
        })
    }
    
    deinit {
        packetObserver?.dispose()
        packetObserver = nil
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableView.register(RequestLogCell.self, forCellReuseIdentifier: String(describing: RequestLogCell.self))
        
        view.addSubview(tableView)
        NSLayoutConstraint.activate([
            tableView.leftAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leftAnchor),
            tableView.rightAnchor.constraint(equalTo: view.safeAreaLayoutGuide.rightAnchor),
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        ])
        tableView.translatesAutoresizingMaskIntoConstraints = false
        
        self.tableView.delegate = self
        self.tableView.dataSource = self
    }
}

extension RequestLogViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let detailsController = RequestLogDetailsViewController()
        
        if let navigationController = self.navigationController {
            navigationController.pushViewController(detailsController, animated: true)
        }
        else {
            present(detailsController, animated: true, completion: nil)
        }
    }
}

extension RequestLogViewController: UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return packets.count
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return UITableView.automaticDimension
    }
    
    func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
        return 100.0
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: String(describing: RequestLogCell.self), for: indexPath) as! RequestLogCell //swiftlint:disable:this force_unwrapping
        
        cell.setRequest(packets[indexPath.row])
        return cell
    }
}

extension RequestLogViewController {
    private enum RequestStatus {
        case pending
        case error
        case complete
    }
    
    private class RequestLogStatusView: UIView {
        private let stackView = UIStackView(frame: .zero)
        private let dateLabel = UILabel(frame: .zero)
        private let elapsedTimeLabel = UILabel(frame: .zero)
        private let separator = UIView(frame: .zero)
        
        override init(frame: CGRect) {
            super.init(frame: .zero)
            
            stackView.axis = .vertical
            stackView.distribution = .fill
            stackView.alignment = .fill
            stackView.isLayoutMarginsRelativeArrangement = true
            stackView.layoutMargins = UIEdgeInsets(top: 12.0, left: 12.0, bottom: 12.0, right: 12.0)
            stackView.spacing = 8.0
            
            dateLabel.font = .systemFont(ofSize: 12.0, weight: .bold)
            dateLabel.textColor = .white
            dateLabel.textAlignment = .center
            
            elapsedTimeLabel.font = .systemFont(ofSize: 11.5, weight: .medium)
            elapsedTimeLabel.textColor = .white
            elapsedTimeLabel.textAlignment = .center
            
            separator.backgroundColor = .groupTableViewBackground
            
            addSubview(stackView)
            addSubview(separator)
            stackView.addArrangedSubview(dateLabel)
            stackView.addArrangedSubview(elapsedTimeLabel)
            
            NSLayoutConstraint.activate([
                stackView.leftAnchor.constraint(equalTo: leftAnchor),
                stackView.rightAnchor.constraint(equalTo: rightAnchor),
                stackView.topAnchor.constraint(equalTo: topAnchor),
                
                separator.leftAnchor.constraint(equalTo: leftAnchor),
                separator.rightAnchor.constraint(equalTo: rightAnchor),
                separator.topAnchor.constraint(equalTo: stackView.bottomAnchor),
                separator.bottomAnchor.constraint(equalTo: bottomAnchor),
                separator.heightAnchor.constraint(equalToConstant: 1.0)
            ])
            stackView.translatesAutoresizingMaskIntoConstraints = false
            separator.translatesAutoresizingMaskIntoConstraints = false
        }
        
        required init?(coder aDecoder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func setRequest(_ startDate: Date, _ endDate: Date, status: RequestStatus) {
            //Colours taken from: https://simplicable.com/new/colors
            switch status {
            case .pending:
                backgroundColor = #colorLiteral(red: 0.3647058824, green: 0.6784313725, blue: 0.9254901961, alpha: 1)
                
            case .error:
                backgroundColor = #colorLiteral(red: 0.862745098, green: 0.07843137255, blue: 0.2352941176, alpha: 1)
                
            case .complete:
                backgroundColor = #colorLiteral(red: 0, green: 0.8, blue: 0.6, alpha: 1)
            }
            
            let components = Calendar.current.dateComponents([.second, .minute, .hour], from: startDate)
            dateLabel.text = String(format: "[%02ld:%02ld:%02ld]", components.hour!, components.minute!, components.second!) //swiftlint:disable:this force_unwrapping
            
            let timeInterval = endDate.timeIntervalSince(startDate)
            elapsedTimeLabel.text = "\(String(format: "%.3fs", timeInterval))"
        }
    }
    
    class RequestLogCell: UITableViewCell {
        private let contentStackView = UIStackView(frame: .zero)
        private let stackView = UIStackView(frame: .zero)
        private let statusView = RequestLogStatusView(frame: .zero)
        private let hostLabel = UILabel(frame: .zero)
        private let pathLabel = UILabel(frame: .zero)
        private let methodLabel = UILabel(frame: .zero)
        
        override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
            super.init(style: style, reuseIdentifier: reuseIdentifier)
            
            setTheme()
            doLayout()
        }
        
        required init?(coder aDecoder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        private func setTheme() {
            separatorInset = .zero
            selectionStyle = .none
            
            contentStackView.axis = .horizontal
            contentStackView.alignment = .fill
            contentStackView.distribution = .fill
            
            stackView.axis = .vertical
            stackView.distribution = .fillEqually
            stackView.alignment = .fill
            stackView.isLayoutMarginsRelativeArrangement = true
            stackView.layoutMargins = UIEdgeInsets(top: 12.0, left: 12.0, bottom: 12.0, right: 12.0)
            stackView.spacing = 4.0
            
            hostLabel.font = .systemFont(ofSize: 12.0, weight: .bold)
            hostLabel.textColor = .black
            
            pathLabel.font = .systemFont(ofSize: 12.0, weight: .medium)
            pathLabel.textColor = .lightGray
            
            methodLabel.font = .systemFont(ofSize: 12.0, weight: .medium)
            methodLabel.textColor = .lightGray
        }
        
        private func doLayout() {
            contentView.addSubview(contentStackView)
            contentStackView.addArrangedSubview(statusView)
            contentStackView.addArrangedSubview(stackView)
            
            stackView.addArrangedSubview(hostLabel)
            stackView.addArrangedSubview(pathLabel)
            stackView.addArrangedSubview(methodLabel)
            
            NSLayoutConstraint.activate([
                contentStackView.leftAnchor.constraint(equalTo: contentView.leftAnchor),
                contentStackView.rightAnchor.constraint(equalTo: contentView.rightAnchor),
                contentStackView.topAnchor.constraint(equalTo: contentView.topAnchor),
                contentStackView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
            ])
            contentStackView.translatesAutoresizingMaskIntoConstraints = false
            
            NSLayoutConstraint.activate([
                statusView.widthAnchor.constraint(equalToConstant: 100.0)
            ])
        }
        
        func setRequest(_ packet: RequestLogger.RequestPacket) {
            let status: RequestStatus = packet.response.statusCode == 200 ? .complete : .error
            statusView.setRequest(packet.startDate, packet.endDate, status: status)
            
            var host = packet.request.url?.host ?? ""
            host = host.isEmpty ? "localhost" : host
            hostLabel.text = "Host: \(host)"
            
            var path = packet.request.url?.path ?? ""
            path = path.isEmpty ? "/" : path
            pathLabel.text = "Path: \(path)"
            
            var method = packet.request.httpMethod?.uppercased() ?? "GET"
            method += "    "
            method += packet.response.allHeaderFields["Content-Type"] as? String ?? "Unknown Content-Type"
            methodLabel.text = "Method: \(method)"
        }
    }
}
