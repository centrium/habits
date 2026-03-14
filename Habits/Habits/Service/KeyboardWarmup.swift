//
//  KeyboardWarmup.swift
//  Habits
//
//  Created by Matt Adams on 14/03/2026.
//


import UIKit

enum KeyboardWarmup {

    static func warm() {

        DispatchQueue.main.async {

            let textField = UITextField(frame: .zero)

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