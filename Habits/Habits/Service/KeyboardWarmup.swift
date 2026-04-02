//
//  KeyboardWarmup.swift
//  Habits
//
//  Created by Matt Adams on 14/03/2026.
//


import UIKit

enum KeyboardWarmup {
    @MainActor private static var hasWarmed = false

    @MainActor
    static func warmAfterInitialRenderIfNeeded() {
        guard !hasWarmed else { return }
        hasWarmed = true

        DispatchQueue.main.async {
            let textField = UITextField(frame: CGRect(x: -10_000, y: -10_000, width: 1, height: 1))
            textField.isHidden = true
            textField.isUserInteractionEnabled = false

            // attach temporarily to a window
            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let window = windowScene.windows.first else { return }

            window.addSubview(textField)

            textField.becomeFirstResponder()
            textField.resignFirstResponder()

            textField.removeFromSuperview()
        }
    }
}
