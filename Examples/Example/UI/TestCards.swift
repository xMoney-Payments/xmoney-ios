import SwiftUI
import UIKit

let TEST_CARD_SUCCESS_PAN = "4111111111111111"

private enum DemoCardBrand {
    case visa, mastercard
}

private struct DemoTestCard: Identifiable {
    let id: String
    let brand: DemoCardBrand
    let pan: String
    let digits: String
    let expiry: String
    let cvv: String
    let threeDS: String
    let success: Bool
    let status: String

    var copyAll: String {
        "\(pan)  \(expiry)  \(cvv)  \(threeDS)"
    }
}

private let demoTestCards: [DemoTestCard] = [
    DemoTestCard(
        id: "mc-success",
        brand: .mastercard,
        pan: "5555 5555 5555 5599",
        digits: "5555555555555599",
        expiry: "12/34",
        cvv: "123",
        threeDS: "00000",
        success: true,
        status: "Success (3DS2)"
    ),
    DemoTestCard(
        id: "visa-frictionless",
        brand: .visa,
        pan: "4111 1111 1111 1111",
        digits: TEST_CARD_SUCCESS_PAN,
        expiry: "12/26",
        cvv: "123",
        threeDS: "00000",
        success: true,
        status: "Success (3DS2 Frictionless)"
    ),
    DemoTestCard(
        id: "mc-fail",
        brand: .mastercard,
        pan: "5168 4948 9505 5780",
        digits: "5168494895055780",
        expiry: "12/26",
        cvv: "123",
        threeDS: "00000",
        success: false,
        status: "Fail (3DS2 Frictionless)"
    ),
    DemoTestCard(
        id: "visa-attempt",
        brand: .visa,
        pan: "4000 0011 1111 1118",
        digits: "4000001111111118",
        expiry: "12/30",
        cvv: "123",
        threeDS: "00000",
        success: true,
        status: "Success (3DS2 Attempt)"
    ),
]

struct TestCardsAction: View {
    var nameCheckHint: Bool = false
    @State private var open = false
    @EnvironmentObject private var theme: ExampleThemeState

    var body: some View {
        Button("Test cards") {
            open = true
        }
        .font(ExampleFont.labelLarge)
        .foregroundColor(theme.isDark ? ExampleColors.darkText : ExampleColors.lightText)
        .sheet(isPresented: $open) {
            TestCardsSheet(nameCheckHint: nameCheckHint, onDismiss: { open = false })
                .environmentObject(theme)
        }
    }
}

private struct TestCardsSheet: View {
    var nameCheckHint: Bool
    var onDismiss: () -> Void
    @State private var copied: String?
    @EnvironmentObject private var theme: ExampleThemeState

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("xMoney test cards. Tap a number to copy it into the form.")
                        .font(ExampleFont.bodyMedium)
                        .foregroundColor(theme.isDark ? ExampleColors.darkMuted : ExampleColors.lightMuted)
                    ForEach(demoTestCards) { card in
                        TestCardRow(card: card, onCopy: copy)
                    }
                    if nameCheckHint {
                        ExampleCard {
                            Text("NAME CHECK")
                                .exampleLabelMedium()
                                .foregroundColor(theme.isDark ? ExampleColors.darkMuted : ExampleColors.lightMuted)
                            Text("This sample expects John Doe. Use a test card whose account-validation result matches that name, or pay is blocked.")
                                .font(ExampleFont.bodyMedium)
                                .foregroundColor(theme.isDark ? ExampleColors.darkMuted : ExampleColors.lightMuted)
                        }
                    }
                }
                .padding(20)
            }
            .background((theme.isDark ? ExampleColors.darkBg : ExampleColors.lightBg).ignoresSafeArea())
            .overlay(copiedBanner, alignment: .bottom)
            .navigationTitle("Test cards")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close", action: onDismiss)
                }
            }
        }
        .navigationViewStyle(.stack)
        .preferredColorScheme(theme.isDark ? .dark : .light)
    }

    @ViewBuilder
    private var copiedBanner: some View {
        if let copied {
            Text("Copied \(copied)")
                .font(ExampleFont.labelLarge)
                .foregroundColor(theme.isDark ? ExampleColors.darkText : ExampleColors.lightText)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    Capsule().fill(theme.isDark ? ExampleColors.darkElevated : ExampleColors.lightCard)
                )
                .padding(.bottom, 24)
                .transition(.opacity)
        }
    }

    private func copy(_ value: String, _ label: String) {
        UIPasteboard.general.string = value
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        withAnimation { copied = label }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
            if copied == label {
                withAnimation { copied = nil }
            }
        }
    }
}

private struct TestCardRow: View {
    let card: DemoTestCard
    let onCopy: (String, String) -> Void
    @EnvironmentObject private var theme: ExampleThemeState

    var body: some View {
        ExampleCard {
            HStack(alignment: .top, spacing: 12) {
                BrandTile(brand: card.brand)
                VStack(alignment: .leading, spacing: 8) {
                    Button {
                        onCopy(card.pan, "PAN")
                    } label: {
                        HStack(alignment: .firstTextBaseline) {
                            Text(card.pan)
                                .font(ExampleFont.titleMedium)
                                .foregroundColor(theme.isDark ? ExampleColors.darkText : ExampleColors.lightText)
                                .multilineTextAlignment(.leading)
                            Spacer(minLength: 8)
                            Text("Copy")
                                .font(ExampleFont.labelLarge)
                                .foregroundColor(ExampleColors.purple)
                        }
                    }
                    .buttonStyle(.plain)
                    TestCardStatusPill(success: card.success, label: card.status)
                }
            }
            HStack(alignment: .top, spacing: 8) {
                TestCardCopyField(title: "Expiry", value: card.expiry) {
                    onCopy(card.expiry, "expiry")
                }
                TestCardCopyField(title: "CVV", value: card.cvv) {
                    onCopy(card.cvv, "CVV")
                }
                TestCardCopyField(title: "3DS", value: card.threeDS) {
                    onCopy(card.threeDS, "3DS")
                }
            }
            Button("Copy all") {
                onCopy(card.copyAll, "card")
            }
            .font(ExampleFont.labelLarge)
            .foregroundColor(ExampleColors.purple)
        }
    }
}

private struct TestCardCopyField: View {
    let title: String
    let value: String
    let onCopy: () -> Void
    @EnvironmentObject private var theme: ExampleThemeState

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .exampleLabelMedium()
                .foregroundColor(theme.isDark ? ExampleColors.darkMuted : ExampleColors.lightMuted)
            Button(action: onCopy) {
                HStack(spacing: 4) {
                    Text(value)
                        .font(ExampleFont.titleMedium)
                        .foregroundColor(theme.isDark ? ExampleColors.darkText : ExampleColors.lightText)
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(theme.isDark ? ExampleColors.darkMuted : ExampleColors.lightMuted)
                }
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct TestCardStatusPill: View {
    let success: Bool
    let label: String
    @EnvironmentObject private var theme: ExampleThemeState
    @Environment(\.exampleSemantics) private var semantics

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(success ? semantics.success : ExampleColors.error)
                .frame(width: 6, height: 6)
            Text(label)
                .font(ExampleFont.labelMedium)
                .foregroundColor(success ? semantics.success : ExampleColors.error)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            Capsule().fill(success ? semantics.successSoft : semantics.dangerSoft)
        )
    }
}

private struct BrandTile: View {
    let brand: DemoCardBrand

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color.white)
            switch brand {
            case .visa:
                Text("VISA")
                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                    .italic()
                    .foregroundColor(Color(red: 0x14 / 255, green: 0x34 / 255, blue: 0xCB / 255))
            case .mastercard:
                HStack(spacing: -7) {
                    Circle().fill(Color(red: 0xEB / 255, green: 0x00 / 255, blue: 0x1B / 255))
                    Circle().fill(Color(red: 0xF7 / 255, green: 0x9E / 255, blue: 0x1B / 255))
                }
                .frame(width: 28, height: 16)
            }
        }
        .frame(width: 44, height: 32)
        .overlay(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .stroke(Color.black.opacity(0.08), lineWidth: 1)
        )
        .accessibilityLabel(brand == .visa ? "Visa" : "Mastercard")
    }
}
