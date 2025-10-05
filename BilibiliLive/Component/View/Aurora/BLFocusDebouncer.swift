//
//  BLFocusDebouncer.swift
//  BilibiliLive
//
//  Created by Claude-4-Sonnet on 2025/10/06.
//  Performance Optimization: Focus animation debouncer for smooth scrolling
//

import Foundation

/// Focus animation debouncer
/// Delays expensive visual effects during rapid focus changes to maintain smooth scrolling
class BLFocusDebouncer {
    // MARK: - Properties

    /// Current pending task
    private var debounceTask: Task<Void, Never>?

    /// Is debouncer currently active
    private var isActive: Bool = false

    // MARK: - Public Methods

    /// Debounce an action with specified delay
    /// - Parameters:
    ///   - delay: Delay in seconds before executing action
    ///   - action: Action to execute after delay
    func debounce(delay: TimeInterval, action: @escaping () -> Void) {
        // Cancel any existing pending task
        cancel()

        isActive = true

        // Create new delayed task using Swift Concurrency
        debounceTask = Task { @MainActor in
            do {
                // Convert seconds to nanoseconds
                let nanoseconds = UInt64(delay * 1_000_000_000)
                try await Task.sleep(nanoseconds: nanoseconds)

                // Check if task wasn't cancelled
                if !Task.isCancelled && self.isActive {
                    action()
                    self.isActive = false
                }
            } catch {
                // Task was cancelled, do nothing
                self.isActive = false
            }
        }
    }

    /// Execute action immediately, cancelling any pending debounced action
    /// - Parameter action: Action to execute immediately
    func executeImmediately(action: @escaping () -> Void) {
        cancel()

        Task { @MainActor in
            action()
        }
    }

    /// Cancel any pending debounced action
    func cancel() {
        debounceTask?.cancel()
        debounceTask = nil
        isActive = false
    }

    // MARK: - Lifecycle

    deinit {
        cancel()
    }
}
