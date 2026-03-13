//
//  ShareSheet.swift
//  Habits
//
//  Created by Matt Adams on 13/03/2026.
//


import SwiftUI
import UIKit

struct ShareSheet: UIViewControllerRepresentable {
    let items: [URL]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) { }
}
