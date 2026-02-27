// LockScreenView.swift
// VeloBrowser
//
// Lock screen overlay requiring biometric authentication to access the app.

import SwiftUI
import LocalAuthentication

/// Full-screen lock overlay that requires biometric authentication.
///
/// Displays the app logo, a prompt, and a button to trigger Face ID / Touch ID.
/// Automatically attempts authentication on appear.
struct LockScreenView: View {
    let appLockService: AppLockServiceProtocol

    @State private var isAuthenticating = false

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [
                    Color(red: 0.05, green: 0.05, blue: 0.15),
                    Color(red: 0.1, green: 0.1, blue: 0.3)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: DesignSystem.Spacing.xl) {
                Spacer()

                // App icon
                VeloLogoView(size: 80)
                    .padding(.bottom, DesignSystem.Spacing.md)

                Text("Velo Browser")
                    .font(.title.bold())
                    .foregroundStyle(.white)

                Text("Unlock to continue")
                    .font(DesignSystem.Typography.subheadline)
                    .foregroundStyle(.white.opacity(0.7))

                Spacer()

                // Unlock button
                Button {
                    Task { await unlock() }
                } label: {
                    Label(
                        unlockButtonLabel,
                        systemImage: unlockButtonIcon
                    )
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(DesignSystem.Colors.accent.opacity(0.9))
                    .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.button))
                }
                .disabled(isAuthenticating)
                .padding(.horizontal, DesignSystem.Spacing.xl)
                .accessibilityLabel("Unlock with biometrics")

                Spacer()
                    .frame(height: DesignSystem.Spacing.xl)
            }
        }
        .task {
            // Auto-trigger biometric on appear
            await unlock()
        }
    }

    // MARK: - Private

    private var unlockButtonLabel: String {
        switch appLockService.biometryType {
        case .faceID: return "Unlock with Face ID"
        case .touchID: return "Unlock with Touch ID"
        case .opticID: return "Unlock with Optic ID"
        @unknown default: return "Unlock"
        }
    }

    private var unlockButtonIcon: String {
        switch appLockService.biometryType {
        case .faceID: return "faceid"
        case .touchID: return "touchid"
        case .opticID: return "opticid"
        @unknown default: return "lock.open"
        }
    }

    private func unlock() async {
        guard !isAuthenticating else { return }
        isAuthenticating = true
        _ = await appLockService.authenticate()
        isAuthenticating = false
    }
}
