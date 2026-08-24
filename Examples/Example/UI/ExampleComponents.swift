import SwiftUI
import UIKit
import XMoneyCore

enum ExampleButtonVariant {
    case primary, secondary
}

struct ExampleCard<Content: View>: View {
    var contentPadding: CGFloat = 20
    @ViewBuilder var content: () -> Content
    @Environment(\.exampleSemantics) private var semantics
    @EnvironmentObject private var theme: ExampleThemeState

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            content()
        }
        .padding(contentPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.isDark ? ExampleColors.darkCard : ExampleColors.lightCard)
        .clipShape(RoundedRectangle(cornerRadius: ExampleRadii.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: ExampleRadii.card, style: .continuous)
                .stroke(semantics.hairline, lineWidth: 1)
        )
    }
}

struct ExampleButton: View {
    let label: String
    var enabled: Bool = true
    var loading: Bool = false
    var variant: ExampleButtonVariant = .primary
    let action: () -> Void

    @Environment(\.brandAccent) private var accent
    @Environment(\.brandOnAccent) private var onAccent
    @EnvironmentObject private var theme: ExampleThemeState

    var body: some View {
        let isPrimary = variant == .primary
        Button(action: action) {
            Group {
                if loading {
                    HStack(spacing: 10) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: isPrimary ? onAccent : textColor))
                        Text("Processing…")
                            .font(ExampleFont.labelLarge)
                    }
                } else {
                    Text(label)
                        .font(ExampleFont.labelLarge)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .foregroundColor(isPrimary ? onAccent : textColor)
            .background(isPrimary ? accent.opacity(enabled && !loading ? 1 : 0.45) : surface)
            .clipShape(Capsule())
            .overlay(
                Capsule().stroke(isPrimary ? Color.clear : hairline, lineWidth: 1)
            )
        }
        .shadow(
            color: isPrimary && enabled && !loading ? accent.opacity(0.28) : .clear,
            radius: 10,
            y: 4
        )
        .shadow(
            color: isPrimary && enabled && !loading ? accent.opacity(0.38) : .clear,
            radius: 10,
            y: 4
        )
        .disabled(!enabled || loading)
    }

    private var surface: Color {
        theme.isDark ? ExampleColors.darkCard : ExampleColors.lightCard
    }

    private var textColor: Color {
        theme.isDark ? ExampleColors.darkText : ExampleColors.lightText
    }

    private var hairline: Color {
        theme.isDark ? ExampleColors.darkHairline : ExampleColors.lightHairline
    }
}

enum ExampleStatusKind {
    case success, error, neutral
}

struct ExampleStatusChip: View {
    let text: String
    let kind: ExampleStatusKind
    @Environment(\.exampleSemantics) private var semantics
    @EnvironmentObject private var theme: ExampleThemeState

    init(_ text: String, _ kind: ExampleStatusKind) {
        self.text = text
        self.kind = kind
    }

    init(text: String, kind: ExampleStatusKind) {
        self.text = text
        self.kind = kind
    }

    var body: some View {
        let colors: (Color, Color) = {
            switch kind {
            case .success: return (semantics.successSoft, semantics.success)
            case .error: return (semantics.dangerSoft, ExampleColors.error)
            case .neutral:
                return (
                    theme.isDark ? ExampleColors.darkElevated : ExampleColors.lightBg,
                    theme.isDark ? ExampleColors.darkMuted : ExampleColors.lightMuted
                )
            }
        }()
        Text(text)
            .font(ExampleFont.bodyMedium)
            .foregroundColor(colors.1)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(colors.0)
            .clipShape(RoundedRectangle(cornerRadius: ExampleRadii.inner, style: .continuous))
    }
}

struct ExampleKeyValueRow: View {
    let label: String
    let value: String
    @EnvironmentObject private var theme: ExampleThemeState

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(label)
                .font(ExampleFont.bodyMedium)
                .foregroundColor(theme.isDark ? ExampleColors.darkMuted : ExampleColors.lightMuted)
            Text(value)
                .font(ExampleFont.titleMedium)
                .foregroundColor(theme.isDark ? ExampleColors.darkText : ExampleColors.lightText)
                .multilineTextAlignment(.trailing)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }
}

struct ExampleResultPanel: View {
    let result: PaymentResult
    var fallbackAmount: String? = nil
    var successTitle: String = "Payment complete"
    var failureTitle: String = "Payment didn’t go through"
    var canceledTitle: String = "Payment canceled"
    @EnvironmentObject private var theme: ExampleThemeState
    @Environment(\.exampleSemantics) private var semantics

    var body: some View {
        let hero = heroContent
        VStack(spacing: 20) {
            ZStack {
                Circle().fill(hero.bg).frame(width: 72, height: 72)
                Image(systemName: hero.icon)
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundColor(hero.tint)
            }
            VStack(spacing: 6) {
                Text(hero.title)
                    .font(ExampleFont.headlineMedium)
                    .multilineTextAlignment(.center)
                Text(hero.subtitle)
                    .font(ExampleFont.bodyMedium)
                    .foregroundColor(theme.isDark ? ExampleColors.darkMuted : ExampleColors.lightMuted)
                    .multilineTextAlignment(.center)
            }
            ExampleCard(contentPadding: 8) {
                VStack(spacing: 0) {
                    ForEach(Array(resultRows.enumerated()), id: \.offset) { index, row in
                        if index > 0 {
                            Divider().background(semantics.hairline)
                        }
                        ExampleKeyValueRow(label: row.label, value: row.value)
                            .padding(.vertical, 10)
                            .padding(.horizontal, 12)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var heroContent: (title: String, subtitle: String, icon: String, tint: Color, bg: Color) {
        switch result {
        case .complete:
            return (successTitle, "Your payment went through.", "checkmark", ExampleColors.purple, ExampleColors.purple.opacity(0.12))
        case .failed:
            return (failureTitle, "Something went wrong. You can try again.", "xmark", ExampleColors.error, ExampleColors.error.opacity(0.12))
        case .canceled:
            return (
                canceledTitle,
                "You closed checkout before finishing.",
                "minus",
                theme.isDark ? ExampleColors.darkMuted : ExampleColors.lightMuted,
                theme.isDark ? ExampleColors.darkElevated : ExampleColors.lightBg
            )
        }
    }

    private var resultRows: [(label: String, value: String)] {
        switch result {
        case let .complete(tx):
            let customer = tx.customerData
            let name = [customer?.firstName, customer?.lastName]
                .compactMap { $0 }
                .filter { !$0.isEmpty }
                .joined(separator: " ")
            var rows: [(String, String)] = []
            rows.append(("Status", (tx.status?.isEmpty == false ? tx.status! : "Complete")))
            if let amount = formatAmount(tx.amount, tx.currencyKey, fallbackAmount) {
                rows.append(("Amount", amount))
            }
            if let euro = tx.amountInEuro, !euro.isEmpty {
                rows.append(("Amount in EUR", "€\(euro)"))
            }
            if let id = tx.id, !id.isEmpty { rows.append(("Transaction", id)) }
            if let ext = tx.externalOrderId, !ext.isEmpty { rows.append(("External order", ext)) }
            if let desc = tx.description, !desc.isEmpty { rows.append(("Description", desc)) }
            if !name.isEmpty { rows.append(("Customer", name)) }
            if let email = customer?.email, !email.isEmpty { rows.append(("Email", email)) }
            return rows
        case let .failed(error):
            return [
                ("Status", "Failed"),
                ("Error code", error.code),
                ("Message", error.merchantMessage()),
            ]
        case .canceled:
            return [
                ("Status", "Canceled"),
                ("Message", "No charge was made."),
            ]
        }
    }
}

private func formatAmount(_ amount: String?, _ currency: String?, _ fallback: String?) -> String? {
    guard let raw = amount, !raw.isEmpty else { return fallback }
    switch currency?.uppercased() ?? "" {
    case "EUR": return "€\(raw)"
    case "USD": return "$\(raw)"
    case "GBP": return "£\(raw)"
    case "": return raw
    default: return "\(raw) \(currency!.uppercased())"
    }
}

struct ExampleLoader: View {
    var message: String? = nil
    @EnvironmentObject private var theme: ExampleThemeState

    var body: some View {
        VStack(spacing: 12) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: ExampleColors.purple))
                .scaleEffect(1.2)
            if let message {
                Text(message)
                    .font(ExampleFont.bodyMedium)
                    .foregroundColor(theme.isDark ? ExampleColors.darkMuted : ExampleColors.lightMuted)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }
}

/// Merchant loading chrome for the **initial** bind. Always keeps `content`
/// in the tree so `PaymentElement` / `ApplePayButton` can emit `.ready`. After
/// the first Ready, the surface stays visible — `updateOrder` must not hide it.
struct MerchantReadyGate<Content: View>: View {
    let ready: Bool
    let message: String
    @ViewBuilder var content: () -> Content
    @State private var hasBound = false

    var body: some View {
        ZStack(alignment: .top) {
            content()
                .opacity(hasBound ? 1 : 0)
                .accessibilityHidden(!hasBound)
            if !hasBound {
                ExampleLoader(message: message)
            }
        }
        .frame(maxWidth: .infinity)
        .onAppear {
            if ready { hasBound = true }
        }
        .onChange(of: ready) { isReady in
            if isReady { hasBound = true }
        }
    }
}

struct ExampleWordmark: View {
    @EnvironmentObject private var theme: ExampleThemeState

    var body: some View {
        Image("xmoney-wordmark")
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .frame(height: 18)
            .foregroundColor(theme.isDark ? ExampleColors.darkText : ExampleColors.lightText)
            .accessibilityLabel("xMoney")
    }
}

struct ExampleProductPhoto: View {
    let imageName: String
    var aspectRatio: CGFloat? = nil
    @EnvironmentObject private var theme: ExampleThemeState

    var body: some View {
        Group {
            if let ui = UIImage(named: imageName) {
                photo(Image(uiImage: ui))
            } else {
                placeholder
            }
        }
        .accessibilityHidden(false)
    }

    @ViewBuilder
    private func photo(_ image: Image) -> some View {
        if let aspectRatio {
            Color.clear
                .aspectRatio(aspectRatio, contentMode: .fit)
                .overlay(image.resizable().scaledToFill())
                .clipped()
        } else {
            image.resizable().scaledToFill()
        }
    }

    @ViewBuilder
    private var placeholder: some View {
        let fill = theme.isDark ? ExampleColors.darkElevated : ExampleColors.lightHairline
        if let aspectRatio {
            Color.clear
                .aspectRatio(aspectRatio, contentMode: .fit)
                .overlay(fill)
        } else {
            Rectangle().fill(fill)
        }
    }
}

struct ExampleTopBar: View {
    let title: String
    var subtitle: String? = nil
    var showWordmark: Bool = false
    var showThemeToggle: Bool = true
    var onBack: (() -> Void)? = nil
    var actions: AnyView? = nil

    @EnvironmentObject private var theme: ExampleThemeState

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if showWordmark {
                ExampleWordmark()
            }
            HStack(spacing: 8) {
                if let onBack {
                    Button(action: onBack) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(theme.isDark ? ExampleColors.darkText : ExampleColors.lightText)
                            .frame(width: 44, height: 44)
                    }
                }
                Text(title)
                    .font(ExampleFont.headlineMedium)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if let actions { actions }
                if showThemeToggle {
                    Button(action: { theme.toggle() }) {
                        Image(systemName: theme.isDark ? "moon" : "sun.max")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(theme.isDark ? ExampleColors.darkText : ExampleColors.lightText)
                            .frame(width: 44, height: 44)
                    }
                    .accessibilityLabel(theme.isDark ? "Switch to light theme" : "Switch to dark theme")
                }
            }
            if let subtitle {
                Text(subtitle)
                    .font(ExampleFont.bodyMedium)
                    .foregroundColor(theme.isDark ? ExampleColors.darkMuted : ExampleColors.lightMuted)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }
}

struct ExampleAddChip: View {
    let quantity: Int
    let action: () -> Void
    @Environment(\.brandAccent) private var accent
    @Environment(\.brandOnAccent) private var onAccent
    @Environment(\.brandAccentText) private var accentText

    var body: some View {
        let filled = quantity > 0
        Button(action: action) {
            Text(filled ? "\(quantity)" : "Add")
                .font(ExampleFont.labelLarge)
                .foregroundColor(filled ? accentText : onAccent)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(filled ? accent.opacity(0.12) : accent)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

struct ExampleSwitchRow: View {
    let title: String
    let subtitle: String
    @Binding var isOn: Bool
    var enabled: Bool = true
    var showDivider: Bool = false
    @Environment(\.exampleSemantics) private var semantics
    @EnvironmentObject private var theme: ExampleThemeState

    var body: some View {
        VStack(spacing: 0) {
            if showDivider {
                Divider().background(semantics.hairline)
            }
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(ExampleFont.titleMedium)
                        .foregroundColor((theme.isDark ? ExampleColors.darkText : ExampleColors.lightText).opacity(enabled ? 1 : 0.38))
                    Text(subtitle)
                        .font(ExampleFont.bodyMedium)
                        .foregroundColor((theme.isDark ? ExampleColors.darkMuted : ExampleColors.lightMuted).opacity(enabled ? 1 : 0.38))
                }
                Spacer()
                Toggle("", isOn: $isOn)
                    .labelsHidden()
                    .tint(ExampleColors.purple)
                    .disabled(!enabled)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
        }
    }
}

struct SampleOrderCard: View {
    var description: String = ExampleSecrets.orderDescription.isEmpty
        ? "Checkout item"
        : ExampleSecrets.orderDescription
    var amountMinor: Int64 = SAMPLE_AMOUNT_MINOR
    var currency: String = ExampleSecrets.currency

    @EnvironmentObject private var theme: ExampleThemeState

    var body: some View {
        ExampleCard {
            Text("ORDER")
                .exampleLabelMedium()
                .foregroundColor(theme.isDark ? ExampleColors.darkMuted : ExampleColors.lightMuted)
            Text(description)
                .font(ExampleFont.titleLarge)
            Text(formatMoney(amountMinor, currency: currency))
                .font(ExampleFont.headlineMedium)
        }
    }
}

struct SampleScaffold<Content: View>: View {
    let title: String
    let subtitle: String
    var scrollable: Bool = true
    var showTestCards: Bool = false
    var nameCheckHint: Bool = false
    var showUIKitToggle: Bool = false
    @Binding var useUIKit: Bool
    @ViewBuilder var content: () -> Content

    @Environment(\.presentationMode) private var presentation
    @EnvironmentObject private var theme: ExampleThemeState

    init(
        title: String,
        subtitle: String,
        scrollable: Bool = true,
        showTestCards: Bool = false,
        nameCheckHint: Bool = false,
        showUIKitToggle: Bool = false,
        useUIKit: Binding<Bool> = .constant(false),
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.scrollable = scrollable
        self.showTestCards = showTestCards
        self.nameCheckHint = nameCheckHint
        self.showUIKitToggle = showUIKitToggle
        self._useUIKit = useUIKit
        self.content = content
    }

    var body: some View {
        VStack(spacing: 0) {
            ExampleTopBar(
                title: title,
                subtitle: subtitle,
                onBack: { presentation.wrappedValue.dismiss() },
                actions: AnyView(
                    HStack(spacing: 0) {
                        if showTestCards {
                            TestCardsAction(nameCheckHint: nameCheckHint)
                        }
                    }
                )
            )
            if showUIKitToggle {
                Picker("API", selection: $useUIKit) {
                    Text("SwiftUI").tag(false)
                    Text("UIKit").tag(true)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 20)
                .padding(.bottom, 8)
            }
            if scrollable {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        content()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .padding(.bottom, 24)
                }
            } else {
                VStack(alignment: .leading, spacing: 16) {
                    content()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
        }
        .background((theme.isDark ? ExampleColors.darkBg : ExampleColors.lightBg).ignoresSafeArea())
        .navigationBarHidden(true)
    }
}
