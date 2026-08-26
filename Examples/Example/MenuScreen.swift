import SwiftUI

private enum MenuSection: String, CaseIterable {
    case integrations = "Integrations"
    case exampleApp = "Example app"
    case advanced = "Advanced"
    case internalSection = "Internal"

    var muted: Bool { self == .internalSection }
}

private enum MenuDestination: String, Hashable {
    case sheet, element, apple
    case lumen, hearth, pulse
    case merchantCTA, update, namecheck
    case playground
}

private struct MenuItem: Identifiable {
    var id: String { destination.rawValue }
    let title: String
    let subtitle: String
    let section: MenuSection
    let imageName: String?
    let destination: MenuDestination
}

struct MenuScreen: View {
    @EnvironmentObject private var theme: ExampleThemeState

    private let items: [MenuItem] = [
        MenuItem(
            title: "Payment Sheet",
            subtitle: "Drop-in checkout sheet — copy-paste starting point",
            section: .integrations,
            imageName: nil,
            destination: .sheet
        ),
        MenuItem(
            title: "Embedded Payment Element",
            subtitle: "Card, saved cards, and Apple Pay in your layout",
            section: .integrations,
            imageName: nil,
            destination: .element
        ),
        MenuItem(
            title: "Apple Pay",
            subtitle: "Standalone wallet button",
            section: .integrations,
            imageName: nil,
            destination: .apple
        ),
        MenuItem(
            title: "Lumen shop",
            subtitle: "Lifestyle store — catalog, cart, Payment Sheet",
            section: .exampleApp,
            imageName: "product_earbuds",
            destination: .lumen
        ),
        MenuItem(
            title: "Hearth Café",
            subtitle: "Food menu — cart and Embedded checkout",
            section: .exampleApp,
            imageName: "product_espresso",
            destination: .hearth
        ),
        MenuItem(
            title: "Pulse Studio",
            subtitle: "Memberships and classes — Embedded checkout",
            section: .exampleApp,
            imageName: "product_pulse_unlimited",
            destination: .pulse
        ),
        MenuItem(
            title: "Merchant Pay button",
            subtitle: "Embedded form, your CTA via confirm()",
            section: .advanced,
            imageName: nil,
            destination: .merchantCTA
        ),
        MenuItem(
            title: "Update order",
            subtitle: "updateOrder() a new PaymentIntent on a mounted Element",
            section: .advanced,
            imageName: nil,
            destination: .update
        ),
        MenuItem(
            title: "Card holder verification",
            subtitle: "Pre-pay name check via CardHolderVerification",
            section: .advanced,
            imageName: nil,
            destination: .namecheck
        ),
        MenuItem(
            title: "Playground",
            subtitle: "Toggle every option — SDK development",
            section: .internalSection,
            imageName: nil,
            destination: .playground
        ),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ExampleTopBar(
                    title: "Examples",
                    subtitle: "Copy-paste samples, merchant scenarios, and an internal playground.",
                    showWordmark: true
                )
                ForEach(MenuSection.allCases, id: \.self) { section in
                    let sectionItems = items.filter { $0.section == section }
                    if !sectionItems.isEmpty {
                        Text(section.rawValue.uppercased())
                            .exampleLabelMedium()
                            .foregroundColor(theme.isDark ? ExampleColors.darkMuted : ExampleColors.lightMuted)
                            .opacity(section.muted ? 0.7 : 1)
                            .padding(.horizontal, 20)
                            .padding(.top, 20)
                            .padding(.bottom, 4)
                        ForEach(Array(sectionItems.enumerated()), id: \.element.id) { index, item in
                            NavigationLink {
                                destinationView(item.destination)
                            } label: {
                                MenuRow(item: item)
                            }
                            .buttonStyle(.plain)
                            if index < sectionItems.count - 1 {
                                Divider()
                                    .padding(.leading, 20)
                                    .background(theme.isDark ? ExampleColors.darkHairline : ExampleColors.lightHairline)
                            }
                        }
                    }
                }
                Spacer(minLength: 32)
            }
        }
        .background((theme.isDark ? ExampleColors.darkBg : ExampleColors.lightBg).ignoresSafeArea())
        .navigationBarHidden(true)
    }

    @ViewBuilder
    private func destinationView(_ destination: MenuDestination) -> some View {
        switch destination {
        case .sheet: PaymentSheetSampleView()
        case .element: EmbeddedPaymentSampleView()
        case .apple: ApplePaySampleView()
        case .lumen: MerchantStoreView(brand: .lumen)
        case .hearth: MerchantStoreView(brand: .hearth)
        case .pulse: MerchantStoreView(brand: .pulse)
        case .merchantCTA: MerchantPayButtonSampleView()
        case .update: UpdateOrderSampleView()
        case .namecheck: CardHolderVerificationSampleView()
        case .playground: PlaygroundView()
        }
    }
}

private struct MenuRow: View {
    let item: MenuItem
    @EnvironmentObject private var theme: ExampleThemeState

    var body: some View {
        HStack(spacing: 12) {
            if let imageName = item.imageName {
                ExampleProductPhoto(imageName: imageName)
                    .frame(width: 52, height: 52)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(ExampleFont.titleMedium)
                    .foregroundColor(theme.isDark ? ExampleColors.darkText : ExampleColors.lightText)
                Text(item.subtitle)
                    .font(ExampleFont.bodyMedium)
                    .foregroundColor(theme.isDark ? ExampleColors.darkMuted : ExampleColors.lightMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(theme.isDark ? ExampleColors.darkMuted : ExampleColors.lightMuted)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .contentShape(Rectangle())
    }
}
