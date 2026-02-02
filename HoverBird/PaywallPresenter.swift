//
//  PaywallPresenter.swift
//  HoverSharky
//
//  Factory class to present paywall from Objective-C
//

import SwiftUI
import UIKit

@MainActor
@objc class PaywallPresenter: NSObject {
    
    /// Present the paywall from an Objective-C view controller
    /// - Parameter viewController: The presenting view controller
    @objc static func showPaywall(from viewController: UIViewController) {
        let paywallView = StylishPaywallView()
        let hostingController = UIHostingController(rootView: paywallView)
        hostingController.modalPresentationStyle = .pageSheet
        
        if let sheet = hostingController.sheetPresentationController {
            sheet.detents = [.large()]
            sheet.prefersGrabberVisible = true
        }
        
        viewController.present(hostingController, animated: true)
    }
    
    /// Present the paywall from a UIView's window
    /// - Parameter view: The view whose window will be used to present
    @objc static func showPaywall(fromView view: UIView) {
        guard let rootVC = view.window?.rootViewController else {
            print("PaywallPresenter: No root view controller found")
            return
        }
        showPaywall(from: rootVC)
    }
}
