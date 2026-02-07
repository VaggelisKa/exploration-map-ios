//
//  ShareSheet.swift
//  exploration-map
//

import SwiftUI
import UIKit

/// Presents the system share sheet from the key window (no SwiftUI sheet), so the system preview works correctly.
enum SharePresenter {
    /// Presents UIActivityViewController with the given items from the key window's top view controller.
    /// Call from MainActor. `onComplete` is called when the user dismisses the share sheet.
    static func present(activityItems: [Any], onComplete: @escaping () -> Void) {
        guard let windowScene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }),
              let window = windowScene.windows.first(where: { $0.isKeyWindow }) ?? windowScene.windows.first,
              let rootVC = window.rootViewController else {
            onComplete()
            return
        }
        var top = rootVC
        while let presented = top.presentedViewController { top = presented }

        let activityVC = UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
        activityVC.completionWithItemsHandler = { _, _, _, _ in
            DispatchQueue.main.async { onComplete() }
        }
        if let popover = activityVC.popoverPresentationController {
            popover.sourceView = top.view
            popover.sourceRect = CGRect(x: top.view.bounds.midX, y: top.view.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }
        top.present(activityVC, animated: true)
    }
}
