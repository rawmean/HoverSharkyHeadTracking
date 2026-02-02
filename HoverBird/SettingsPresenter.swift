//
//  SettingsPresenter.swift
//  HoverSharky
//
//  Factory class to present settings from Objective-C
//

import SwiftUI
import UIKit

@MainActor
@objc class SettingsPresenter: NSObject {
    
    /// Present the settings view from an Objective-C view controller
    /// - Parameter viewController: The presenting view controller
    @objc static func showSettings(from viewController: UIViewController) {
        let settingsView = SettingsView()
        let hostingController = UIHostingController(rootView: settingsView)
        hostingController.modalPresentationStyle = .overFullScreen
        hostingController.modalTransitionStyle = .crossDissolve
        
        // Find the topmost presented view controller to present from
        var presenter = viewController
        while let presented = presenter.presentedViewController {
            presenter = presented
        }
        
        presenter.present(hostingController, animated: true)
    }
    
    /// Present the settings from a UIView's window
    /// - Parameter view: The view whose window will be used to present
    @objc static func showSettings(fromView view: UIView) {
        guard let rootVC = view.window?.rootViewController else {
            print("SettingsPresenter: No root view controller found")
            return
        }
        showSettings(from: rootVC)
    }
}
