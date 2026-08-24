import SwiftUI
import XMoneyApplePay
import XMoneyCore
import XMoneyPaymentElement
import XMoneyPaymentSheet

struct PlaygroundView: View {
    @EnvironmentObject private var theme: ExampleThemeState
    @Environment(\.presentationMode) private var presentation
    @State private var showAppearance = false
    @State private var appearance = exampleAppearance()
    @State private var fontFamily = ""

    @State private var locale = playgroundLocaleOptions[0]
    @State private var style = playgroundStyleOptions[0]
    @State private var buttonType = playgroundButtonTypeOptions[0]
    @State private var validation = playgroundValidationOptions[0]
    @State private var grouping = playgroundGroupingOptions[0]
    @State private var submitVisible = true
    @State private var applePayEnabled = true
    @State private var savedCardsEnabled = true
    @State private var saveCardOptInVisible = true
    @State private var nameCheck = false
    @State private var walletColor = playgroundWalletColorOptions[0]
    @State private var walletType = playgroundWalletTypeOptions[0]
    @State private var walletRadius: Double = 28
    @State private var mode: IntegrationMode = .paymentSheet
    @State private var amountMinor = SAMPLE_AMOUNT_MINOR

    @State private var lastResult: PaymentResult?
    @State private var inlineConsumed = false
    @State private var isLoading = false
    @State private var ready = false
    @State private var error: String?
    @State private var pendingOrder: PaymentIntent?
    @State private var didProcess = false
    @State private var showSheet = false
    @State private var presenter: UIViewController?
    @State private var payment: EmbeddedPayment?
    @State private var applePay: ApplePay?

    private var structuralKey: String {
        [
            String(applePayEnabled),
            String(savedCardsEnabled),
            String(saveCardOptInVisible),
            grouping.value,
            String(nameCheck),
            buttonType.value,
            validation.value,
            String(submitVisible),
            style.value,
            walletColor.value,
            walletType.value,
            String(Int(walletRadius)),
            fontFamily,
        ].joined(separator: "|")
    }

    var body: some View {
        let configuration = makeConfiguration()
        VStack(spacing: 0) {
            ExampleTopBar(
                title: "Playground",
                subtitle: "Toggle every option — SDK development.",
                onBack: { presentation.wrappedValue.dismiss() },
                actions: AnyView(
                    Button("Appearance") { showAppearance = true }
                        .font(ExampleFont.labelLarge)
                )
            )
            Picker("Mode", selection: $mode) {
                ForEach(IntegrationMode.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 20)
            .padding(.bottom, 8)

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    optionsCard
                    amountCard
                    checkoutCard(configuration)
                    if let error { ExampleStatusChip(error, .error) }
                    if let lastResult, (mode == .paymentSheet && orderConsumed(lastResult, didProcess: didProcess)) || inlineConsumed {
                        ExampleResultPanel(result: lastResult)
                        ExampleButton(label: "New payment", variant: .secondary, action: resetInline)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 32)
            }
        }
        .background((theme.isDark ? ExampleColors.darkBg : ExampleColors.lightBg).ignoresSafeArea())
        .background(HiddenPresenter(presenter: $presenter))
        .navigationBarHidden(true)
        .sheet(isPresented: $showAppearance) {
            AppearancePlaygroundView(appearance: $appearance, fontFamily: $fontFamily)
                .environmentObject(theme)
        }
        .background(
            Group {
                if mode == .paymentSheet, let intent = pendingOrder {
                    Color.clear.paymentSheet(
                        isPresented: $showSheet,
                        configuration: configuration,
                        intent: intent,
                        onEvent: { event in
                            switch event {
                            case .ready: isLoading = false
                            case let .processing(flag):
                                if flag { didProcess = true }
                            }
                        },
                        onCompletion: { result in
                            lastResult = result
                            isLoading = false
                            showSheet = false
                        }
                    )
                }
            }
        )
        .id(structuralKey)
        .onChange(of: structuralKey) { _ in
            remount(configuration)
            resetInline()
        }
        .onChange(of: appearance) { _ in
            payment?.updateAppearance(appearanceWithFont)
        }
        .onChange(of: locale) { _ in
            payment?.updateLocale(locale.value)
        }
        .onChange(of: amountMinor) { _ in
            if mode == .paymentSheet {
                pendingOrder = nil
            }
        }
        .onAppear {
            ApplePay.register()
            remount(configuration)
        }
        .task(id: "\(mode)-\(structuralKey)-\(amountMinor)") {
            guard mode != .paymentSheet else { return }
            await prepareInline(configuration)
        }
    }

    private var appearanceWithFont: PaymentConfig.AppearanceConfig {
        var next = appearance
        next.fontFamily = fontFamily.isEmpty ? nil : fontFamily
        return next
    }

    private func makeConfiguration() -> PaymentConfig {
        let wallet = PaymentConfig.WalletAppearance(
            color: PaymentConfig.WalletButtonColor.from(walletColor.value == "auto" ? nil : walletColor.value),
            radius: walletRadius,
            type: playgroundWalletType(walletType.value)
        )
        return PaymentConfig(
            publicKey: ExampleSecrets.publicKey,
            card: .init(
                savedCards: .init(enabled: savedCardsEnabled, optInVisible: saveCardOptInVisible),
                cardHolderVerification: nameCheck
                    ? CardHolderVerification(
                        name: CardHolderName(firstName: "John", lastName: "Doe"),
                        onCardHolderVerification: { $0.status == .matched }
                    )
                    : nil,
                inputs: .init(grouping: playgroundGrouping(grouping.value)),
                validationMode: playgroundValidation(validation.value),
                submitButton: .init(visible: submitVisible, type: playgroundButtonType(buttonType.value))
            ),
            paymentMethods: .init(applePay: .init(enabled: applePayEnabled, appearance: wallet)),
            options: .init(
                locale: locale.value,
                style: playgroundStyle(style.value),
                appearance: appearanceWithFont
            )
        )
    }

    private func remount(_ configuration: PaymentConfig) {
        payment = EmbeddedPayment(configuration: configuration) { result in
            lastResult = result
            if result == .canceled, payment?.isOrderConsumed == false {
                lastResult = nil
                return
            }
            inlineConsumed = payment?.isOrderConsumed ?? true
        }
        applePay = ApplePay(configuration: configuration) { result in
            lastResult = result
            inlineConsumed = applePay?.isOrderConsumed ?? false
        }
    }

    private func resetInline() {
        lastResult = nil
        inlineConsumed = false
        ready = false
        pendingOrder = nil
        didProcess = false
        error = nil
    }

    private func prepareInline(_ configuration: PaymentConfig) async {
        if let message = DemoCheckoutBackend.secretsError() {
            await MainActor.run { error = message }
            return
        }
        await MainActor.run {
            isLoading = true
            error = nil
            lastResult = nil
            ready = false
            inlineConsumed = false
        }
        do {
            let intent = try await DemoCheckoutBackend.createPaymentIntent(
                amountMinor: amountMinor,
                description: ExampleSecrets.orderDescription
            )
            if mode == .applePay {
                try await applePay?.updateOrder(intent: intent)
            }
            await MainActor.run {
                pendingOrder = intent
                isLoading = false
                if mode != .embedded {
                    ready = true
                }
            }
        } catch {
            if isCancellation(error) { return }
            await MainActor.run {
                pendingOrder = nil
                self.error = error.localizedDescription
                isLoading = false
            }
        }
    }

    private var optionsCard: some View {
        ExampleCard(contentPadding: 0) {
            optionPicker("Locale", $locale, playgroundLocaleOptions)
            optionPicker("Style", $style, playgroundStyleOptions)
            optionPicker("Pay button", $buttonType, playgroundButtonTypeOptions)
            optionPicker("Validation", $validation, playgroundValidationOptions)
            optionPicker("Grouping", $grouping, playgroundGroupingOptions)
            ExampleSwitchRow(title: "SDK Pay button", subtitle: "Embedded only", isOn: $submitVisible, enabled: mode == .embedded, showDivider: true)
            ExampleSwitchRow(title: "Apple Pay", subtitle: "Wallet in Sheet / Element / standalone", isOn: $applePayEnabled, showDivider: true)
            ExampleSwitchRow(title: "Saved cards", subtitle: "Offer previously saved cards", isOn: $savedCardsEnabled, showDivider: true)
            ExampleSwitchRow(title: "Save-card opt-in", subtitle: "Show the save checkbox", isOn: $saveCardOptInVisible, enabled: savedCardsEnabled, showDivider: true)
            ExampleSwitchRow(title: "Name check", subtitle: "John Doe must match", isOn: $nameCheck, showDivider: true)
            optionPicker("Wallet color", $walletColor, playgroundWalletColorOptions)
            optionPicker("Wallet type", $walletType, playgroundWalletTypeOptions)
            VStack(alignment: .leading, spacing: 8) {
                Text("Wallet radius \(Int(walletRadius))")
                    .font(ExampleFont.titleMedium)
                    .padding(.horizontal, 20)
                Slider(value: $walletRadius, in: 0...28, step: 1)
                    .tint(ExampleColors.purple)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 12)
            }
        }
    }

    private func optionPicker(_ title: String, _ selection: Binding<DemoOption>, _ options: [DemoOption]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .exampleLabelMedium()
                .foregroundColor(theme.isDark ? ExampleColors.darkMuted : ExampleColors.lightMuted)
            Picker(title, selection: selection) {
                ForEach(options, id: \.self) { Text($0.label).tag($0) }
            }
            .pickerStyle(.menu)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
    }

    private var amountCard: some View {
        ExampleCard {
            Text("AMOUNT")
                .exampleLabelMedium()
                .foregroundColor(theme.isDark ? ExampleColors.darkMuted : ExampleColors.lightMuted)
            HStack {
                Text(formatMoney(amountMinor, currency: ExampleSecrets.currency))
                    .font(ExampleFont.headlineMedium)
                Spacer()
                AmountStepper(amountMinor: amountMinor, enabled: !inlineConsumed) { amountMinor = $0 }
            }
        }
    }

    @ViewBuilder
    private func checkoutCard(_ configuration: PaymentConfig) -> some View {
        switch mode {
        case .paymentSheet:
            ExampleButton(label: lastResult == .canceled && !orderConsumed(lastResult ?? .canceled, didProcess: didProcess) ? "Continue" : "Pay", loading: isLoading) {
                isLoading = true
                error = nil
                Task {
                    do {
                        let intent: PaymentIntent
                        if let pendingOrder {
                            intent = pendingOrder
                        } else {
                            intent = try await DemoCheckoutBackend.createPaymentIntent(amountMinor: amountMinor)
                        }
                        await MainActor.run {
                            pendingOrder = intent
                            didProcess = false
                            showSheet = true
                        }
                    } catch {
                        if isCancellation(error) { return }
                        await MainActor.run {
                            self.error = error.localizedDescription
                            isLoading = false
                        }
                    }
                }
            }
        case .embedded:
            if inlineConsumed {
                EmptyView()
            } else if let payment, let pendingOrder {
                MerchantReadyGate(ready: ready, message: "Preparing checkout…") {
                    PaymentElementHost(payment: payment, intent: pendingOrder) { event in
                        if case .ready = event { ready = true }
                    }
                }
            } else {
                ExampleLoader(message: "Preparing checkout…")
            }
        case .applePay:
            #if targetEnvironment(simulator)
            ExampleStatusChip("Apple Pay needs a physical device.", .neutral)
            #endif
            if inlineConsumed {
                EmptyView()
            } else if let applePay, pendingOrder != nil {
                ApplePayButtonView(
                    appearance: configuration.paymentMethods.applePay.appearance,
                    isEnabled: applePay.isInteractionEnabled,
                    isDarkBackground: theme.isDark,
                    onTap: {
                        guard let presenter, let pendingOrder else { return }
                        applePay.present(from: presenter, intent: pendingOrder)
                    }
                )
                .frame(height: 56)
            } else {
                ExampleLoader(message: "Preparing Apple Pay…")
            }
        }
    }
}

private struct AppearancePlaygroundView: View {
    @Binding var appearance: PaymentConfig.AppearanceConfig
    @Binding var fontFamily: String
    @EnvironmentObject private var theme: ExampleThemeState
    @Environment(\.presentationMode) private var presentation

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    sectionLabel("Presets")
                    ForEach(AppearancePresets.all) { preset in
                        Button {
                            appearance = preset.appearance
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(preset.label).font(ExampleFont.titleMedium)
                                Text(preset.description)
                                    .font(ExampleFont.bodyMedium)
                                    .foregroundColor(theme.isDark ? ExampleColors.darkMuted : ExampleColors.lightMuted)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(16)
                            .background(theme.isDark ? ExampleColors.darkCard : ExampleColors.lightCard)
                            .clipShape(RoundedRectangle(cornerRadius: ExampleRadii.inner, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }

                    sectionLabel("Colors")
                    Text(usesSplitColors ? "Editing \(theme.isDark ? "dark" : "light") tokens for this preset." : "Shared colors — both light and dark.")
                        .font(ExampleFont.bodyMedium)
                        .foregroundColor(theme.isDark ? ExampleColors.darkMuted : ExampleColors.lightMuted)
                    ExampleCard {
                        ForEach(appearanceColorFields, id: \.title) { field in
                            HexColorField(
                                title: field.title,
                                hex: colorValue(field.keyPath),
                                onCommit: { setColor(field.keyPath, $0) }
                            )
                        }
                    }

                    sectionLabel("Shapes")
                    ExampleCard {
                        AppearanceSliderRow(
                            title: "Border radius",
                            value: borderRadius,
                            range: 0...32,
                            format: { "\(Int($0.rounded())) pt" }
                        )
                        AppearanceSliderRow(
                            title: "Border width",
                            value: borderWidth,
                            range: 0...3,
                            format: { String(format: "%.1f pt", $0) }
                        )
                    }

                    sectionLabel("Pay button")
                    ExampleCard {
                        HexColorField(
                            title: "Background",
                            hex: payButtonColor(\.background),
                            onCommit: { setPayButtonColor(\.background, $0) }
                        )
                        HexColorField(
                            title: "Text",
                            hex: payButtonColor(\.text),
                            onCommit: { setPayButtonColor(\.text, $0) }
                        )
                        Toggle(isOn: payButtonPill) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Pill")
                                    .font(ExampleFont.titleMedium)
                                Text("borderRadius 9999")
                                    .font(ExampleFont.bodyMedium)
                                    .foregroundColor(theme.isDark ? ExampleColors.darkMuted : ExampleColors.lightMuted)
                            }
                        }
                        .tint(ExampleColors.purple)
                        if !payButtonPill.wrappedValue {
                            AppearanceSliderRow(
                                title: "Button radius",
                                value: payButtonRadius,
                                range: 0...32,
                                format: { "\(Int($0.rounded())) pt" }
                            )
                        }
                    }

                    sectionLabel("Type")
                    ExampleCard {
                        Picker("Font", selection: $fontFamily) {
                            ForEach(playgroundFontFamilyOptions, id: \.value) { Text($0.label).tag($0.value) }
                        }
                        .pickerStyle(.menu)
                        AppearanceSliderRow(
                            title: "Font scale",
                            value: fontScale,
                            range: 0.8...1.4,
                            format: { String(format: "%.2f×", $0) }
                        )
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .background((theme.isDark ? ExampleColors.darkBg : ExampleColors.lightBg).ignoresSafeArea())
            .navigationTitle("Appearance")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { presentation.wrappedValue.dismiss() }
                }
            }
        }
        .navigationViewStyle(.stack)
        .preferredColorScheme(theme.isDark ? .dark : .light)
    }

    private var usesSplitColors: Bool {
        appearance.colorsLight != nil || appearance.colorsDark != nil
    }

    private var borderRadius: Binding<Double> {
        Binding(
            get: { appearance.borderRadius ?? 8 },
            set: { appearance.borderRadius = $0 }
        )
    }

    private var borderWidth: Binding<Double> {
        Binding(
            get: { appearance.borderWidth ?? 1 },
            set: { appearance.borderWidth = $0 }
        )
    }

    private var fontScale: Binding<Double> {
        Binding(
            get: { appearance.fontScale ?? 1 },
            set: { appearance.fontScale = $0 }
        )
    }

    private var payButtonRadius: Binding<Double> {
        Binding(
            get: {
                let value = appearance.primaryButton?.borderRadius ?? 16
                return value >= 100 ? 16 : value
            },
            set: {
                var button = appearance.primaryButton ?? .init()
                button.borderRadius = $0
                appearance.primaryButton = button
            }
        )
    }

    private var payButtonPill: Binding<Bool> {
        Binding(
            get: { (appearance.primaryButton?.borderRadius ?? 0) >= 100 },
            set: { on in
                var button = appearance.primaryButton ?? .init()
                button.borderRadius = on ? 9999 : 16
                appearance.primaryButton = button
            }
        )
    }

    private func sectionLabel(_ title: String) -> some View {
        Text(title)
            .exampleLabelMedium()
            .foregroundColor(theme.isDark ? ExampleColors.darkMuted : ExampleColors.lightMuted)
    }

    private func editingColors() -> PaymentConfig.AppearanceColors {
        if usesSplitColors {
            return theme.isDark
                ? (appearance.colorsDark ?? appearance.colors ?? .init())
                : (appearance.colorsLight ?? appearance.colors ?? .init())
        }
        return appearance.colors ?? .init()
    }

    private func colorValue(_ keyPath: WritableKeyPath<PaymentConfig.AppearanceColors, String?>) -> String {
        editingColors()[keyPath: keyPath] ?? ""
    }

    private func setColor(_ keyPath: WritableKeyPath<PaymentConfig.AppearanceColors, String?>, _ hex: String) {
        var next = appearance
        if usesSplitColors {
            if theme.isDark {
                var colors = next.colorsDark ?? next.colors ?? .init()
                colors[keyPath: keyPath] = hex
                next.colorsDark = colors
            } else {
                var colors = next.colorsLight ?? next.colors ?? .init()
                colors[keyPath: keyPath] = hex
                next.colorsLight = colors
            }
        } else {
            var colors = next.colors ?? .init()
            colors[keyPath: keyPath] = hex
            next.colors = colors
        }
        appearance = next
    }

    private func editingPayColors() -> PaymentConfig.PrimaryButtonColors {
        let button = appearance.primaryButton
        if button?.colorsLight != nil || button?.colorsDark != nil {
            return theme.isDark
                ? (button?.colorsDark ?? button?.colors ?? .init())
                : (button?.colorsLight ?? button?.colors ?? .init())
        }
        return button?.colors ?? .init()
    }

    private func payButtonColor(_ keyPath: WritableKeyPath<PaymentConfig.PrimaryButtonColors, String?>) -> String {
        editingPayColors()[keyPath: keyPath] ?? ""
    }

    private func setPayButtonColor(_ keyPath: WritableKeyPath<PaymentConfig.PrimaryButtonColors, String?>, _ hex: String) {
        var next = appearance
        var button = next.primaryButton ?? .init()
        if button.colorsLight != nil || button.colorsDark != nil {
            if theme.isDark {
                var colors = button.colorsDark ?? button.colors ?? .init()
                colors[keyPath: keyPath] = hex
                button.colorsDark = colors
            } else {
                var colors = button.colorsLight ?? button.colors ?? .init()
                colors[keyPath: keyPath] = hex
                button.colorsLight = colors
            }
        } else {
            var colors = button.colors ?? .init()
            colors[keyPath: keyPath] = hex
            button.colors = colors
        }
        next.primaryButton = button
        appearance = next
    }
}

private let appearanceColorFields: [(title: String, keyPath: WritableKeyPath<PaymentConfig.AppearanceColors, String?>)] = [
    ("Primary", \.primary),
    ("Background", \.background),
    ("Component background", \.componentBackground),
    ("Primary text", \.primaryText),
    ("Secondary text", \.secondaryText),
    ("Error", \.error),
]

private struct AppearanceSliderRow: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let format: (Double) -> String
    @EnvironmentObject private var theme: ExampleThemeState

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title).font(ExampleFont.titleMedium)
                Spacer()
                Text(format(value))
                    .font(ExampleFont.bodyMedium)
                    .foregroundColor(theme.isDark ? ExampleColors.darkMuted : ExampleColors.lightMuted)
            }
            Slider(value: $value, in: range)
                .tint(ExampleColors.purple)
        }
    }
}

private struct HexColorField: View {
    let title: String
    let hex: String
    let onCommit: (String) -> Void
    @State private var draft = ""
    @EnvironmentObject private var theme: ExampleThemeState
    @Environment(\.exampleSemantics) private var semantics

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(colorFromHex(normalizedDraft) ?? Color.gray.opacity(0.2))
                .frame(width: 28, height: 28)
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(semantics.hairline, lineWidth: 1)
                )
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(ExampleFont.bodyMedium)
                    .foregroundColor(theme.isDark ? ExampleColors.darkMuted : ExampleColors.lightMuted)
                TextField("#RRGGBB", text: $draft, onCommit: commit)
                    .font(ExampleFont.titleMedium)
                    .autocapitalization(.allCharacters)
                    .disableAutocorrection(true)
                    .onChange(of: draft) { _ in
                        if let hex = normalizedHex(draft) { onCommit(hex) }
                    }
            }
        }
        .onAppear { draft = hex }
        .onChange(of: hex) { newValue in draft = newValue }
    }

    private var normalizedDraft: String {
        normalizedHex(draft) ?? draft
    }

    private func commit() {
        if let hex = normalizedHex(draft) {
            onCommit(hex)
            draft = hex
        }
    }
}

private func normalizedHex(_ raw: String) -> String? {
    var value = raw.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    if value.hasPrefix("#") { value.removeFirst() }
    guard value.allSatisfy({ $0.isHexDigit }) else { return nil }
    switch value.count {
    case 3:
        let chars = Array(value)
        return "#\(chars[0])\(chars[0])\(chars[1])\(chars[1])\(chars[2])\(chars[2])"
    case 6, 8:
        return "#\(value)"
    default:
        return nil
    }
}

private func colorFromHex(_ hex: String) -> Color? {
    guard let normalized = normalizedHex(hex) else { return nil }
    let value = String(normalized.dropFirst())
    var rgb: UInt64 = 0
    Scanner(string: value).scanHexInt64(&rgb)
    let a, r, g, b: Double
    if value.count == 8 {
        a = Double((rgb >> 24) & 0xFF) / 255
        r = Double((rgb >> 16) & 0xFF) / 255
        g = Double((rgb >> 8) & 0xFF) / 255
        b = Double(rgb & 0xFF) / 255
    } else if value.count == 6 {
        a = 1
        r = Double((rgb >> 16) & 0xFF) / 255
        g = Double((rgb >> 8) & 0xFF) / 255
        b = Double(rgb & 0xFF) / 255
    } else {
        return nil
    }
    return Color(red: r, green: g, blue: b).opacity(a)
}
