//
//  KeyboardObserver.swift
//  EulerityForm
//
//  Observes UIResponder keyboard notifications and publishes the current
//  keyboard height. Used by views that need to position themselves relative
//  to the keyboard manually — which is necessary on iOS 26 because the
//  SwiftUI .ignoresSafeArea(.keyboard) + safeAreaInset + ZStack combinations
//  don't reliably produce the layout we want (Save button at screen bottom,
//  Done bar above keyboard, neither lifted by SwiftUI's auto-avoidance).
//
//  Old-school UIKit pattern — slightly more code than pure SwiftUI but
//  totally predictable across iOS versions.
//

import SwiftUI
import Combine
import UIKit

final class KeyboardObserver: ObservableObject {
    @Published var height: CGFloat = 0

    private var cancellables: Set<AnyCancellable> = []

    init() {
        let willShow = NotificationCenter.default
            .publisher(for: UIResponder.keyboardWillShowNotification)
            .compactMap { notification -> CGFloat? in
                guard let frame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else {
                    return nil
                }
                return frame.height
            }

        let willHide = NotificationCenter.default
            .publisher(for: UIResponder.keyboardWillHideNotification)
            .map { _ in CGFloat(0) }

        Publishers.Merge(willShow, willHide)
            .receive(on: RunLoop.main)
            .assign(to: \.height, on: self)
            .store(in: &cancellables)
    }
}
