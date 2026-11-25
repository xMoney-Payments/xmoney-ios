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
    @State private var selectedPresetId: String?

    @State private var locale = playgroundLocaleOptions[0]
    @State private var style = playgroundStyleOptions[0]
    @State private var buttonType = playgroundButtonTypeOptions[0]
    @State private var validation = playgroundValidationOptions[0]
    @State private var grouping = playgroundGroupingOptions[0]
    @State private var submitVisible = true
    @State private var applePayEnabled = true
    @State private var cryptoEnabled = false
    @State private var savedCardsEnabled = true
    @State private var saveCardOptInVisible = true
    @State private var nameCheck = false
    @State private var customerDetailsCard = false
    @State private var customerDetailsApplePay = false
    @State private var customerDetailsFieldsOverride = false
    @State private var customerDetailsFullName = true
    @State private var customerDetailsEmail = true
    @State private var customerDetailsPhone = false
    @State private var customerDetailsAddress = true
    @State private var customerDetailsPrefill = false
    @State private var defaultsRevision = 0
    @State private var defaultFullName = "Jane Doe"
    @State private var defaultEmail = "jane@example.com"
    @State private var defaultPhone = "+14155550100"
    @State private var defaultCountry = "US"
    @State private var defaultRegion = "CA"
    @State private var defaultCity = "San Francisco"
    @State private var defaultPostalCode = "94105"
    @State private var defaultAddress = "1 Market St"
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
            String(cryptoEnabled),
            String(savedCardsEnabled),
            String(saveCardOptInVisible),
            grouping.value,
            String(nameCheck),
            String(customerDetailsCard),
            String(customerDetailsApplePay),
            String(customerDetailsFieldsOverride),
            String(customerDetailsFullName),
            String(customerDetailsEmail),
            String(customerDetailsPhone),
            String(customerDetailsAddress),
            String(customerDetailsPrefill),
            String(defaultsRevision),
            buttonType.value,
            validation.value,
            String(submitVisible),
        ].joined(separator: "|")
    }

    private var walletAppearance: PaymentConfig.WalletAppearance {
        PaymentConfig.WalletAppearance(
            color: PaymentConfig.WalletButtonColor.from(walletColor.value == "auto" ? nil : walletColor.value),
            radius: walletRadius,
            type: playgroundWalletType(walletType.value)
        )
    }

    var body: some View {
        let configuration = makeConfiguration()
        VStack(spacing: 0) {
            ExampleTopBar(
                title: "Playground",
                onBack: { presentation.wrappedValue.dismiss() }
            )
            Picker("Mode", selection: $mode) {
                ForEach(IntegrationMode.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 20)
            .padding(.bottom, 8)

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    amountCard
                    themeCard
                    methodsCard
                    cardCard
                    customerCard
                    if applePayEnabled {
                        walletCard
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Checkout")
                            .font(ExampleFont.titleMedium)
                            .foregroundColor(theme.isDark ? ExampleColors.darkText : ExampleColors.lightText)
                        checkoutCard(configuration)
                    }
                    if let error { ExampleStatusChip(error, .error) }
                    if let lastResult, (mode == .paymentSheet && orderConsumed(lastResult, didProcess: didProcess)) || inlineConsumed {
                        ExampleResultPanel(result: lastResult)
                        ExampleButton(label: "New payment", variant: .secondary, action: resetInline)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
            }
        }
        .background((theme.isDark ? ExampleColors.darkBg : ExampleColors.lightBg).ignoresSafeArea())
        .background(HiddenPresenter(presenter: $presenter))
        .navigationBarHidden(true)
        .sheet(isPresented: $showAppearance) {
            AppearancePlaygroundView(
                appearance: $appearance,
                fontFamily: $fontFamily,
                selectedPresetId: $selectedPresetId,
                style: style
            )
            .environmentObject(theme)
        }
        .background(
            Group {
                if mode == .paymentSheet, let intent = pendingOrder {
                    Color.clear.paymentSheet(
                        isPresented: $showSheet,
                        configuration: sheetConfiguration,
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
        .onChange(of: structuralKey) { _ in
            remount(makeConfiguration())
            resetInline()
        }
        .onChange(of: appearanceWithFont) { next in
            payment?.updateAppearance(next)
            refreshApplePay()
        }
        .onChange(of: locale) { _ in
            payment?.updateLocale(locale.value)
            refreshApplePay()
        }
        .onChange(of: walletAppearance) { next in
            payment?.updateWalletAppearance(next)
            refreshApplePay()
        }
        .onChange(of: amountMinor) { _ in
            if mode == .paymentSheet {
                pendingOrder = nil
            }
        }
        .onAppear {
            ApplePay.register()
            remount(makeConfiguration())
        }
        .task(id: "\(mode)-\(structuralKey)-\(amountMinor)") {
            guard mode != .paymentSheet else { return }
            await prepareInline(makeConfiguration())
        }
    }

    private var appearanceWithFont: PaymentConfig.Appearance {
        var next = appearance
        next.fontFamily = fontFamily.isEmpty ? nil : fontFamily
        next.colorScheme = playgroundStyle(style.value)
        return next
    }

    /// Sheet ignores `submitButton.visible` and always shows Pay. Keep the value explicit.
    private var sheetConfiguration: PaymentConfig {
        var next = makeConfiguration()
        next.card.submitButton.visible = true
        return next
    }

    private func makeConfiguration() -> PaymentConfig {
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
            paymentMethods: .init(
                applePay: .init(enabled: applePayEnabled, appearance: walletAppearance),
                crypto: .init(enabled: cryptoEnabled)
            ),
            customerDetails: .init(
                card: customerDetailsCard,
                applePay: customerDetailsApplePay,
                fields: customerDetailsFields,
                defaultValues: customerDetailsDefaultValues
            ),
            options: .init(
                locale: locale.value,
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
            // A failed first load emits no `.ready`: open the gate onto the SDK failure label.
            if case .failed = result { ready = true }
            inlineConsumed = payment?.isOrderConsumed ?? true
        }
        refreshApplePay(configuration)
    }

    /// Apple Pay stores its config at init. Replace that controller only, so the page scroll stays put.
    private func refreshApplePay(_ configuration: PaymentConfig? = nil) {
        let configuration = configuration ?? makeConfiguration()
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
        let isInitial = pendingOrder == nil
        await MainActor.run {
            isLoading = true
            error = nil
            lastResult = nil
            if isInitial {
                ready = false
            }
            inlineConsumed = false
        }
        do {
            let createOrder: @MainActor () async throws -> PaymentIntent = {
                if !isInitial {
                    try await Task.sleep(nanoseconds: 300_000_000)
                }
                return try await DemoCheckoutBackend.createPaymentIntent(
                    amountMinor: amountMinor,
                    description: ExampleSecrets.orderDescription
                )
            }
            let next: PaymentIntent?
            if isInitial {
                let intent = try await createOrder()
                if mode == .applePay {
                    try await applePay?.updateOrder(intent: intent)
                }
                next = intent
            } else if mode == .embedded {
                next = try await payment?.updateOrder(createOrder: createOrder)
            } else {
                next = try await applePay?.updateOrder(createOrder: createOrder)
            }
            guard let next else { return }
            await MainActor.run {
                pendingOrder = next
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

    private func applyPreset(_ preset: AppearancePreset) {
        appearance = preset.appearance
        fontFamily = preset.appearance.fontFamily ?? ""
        selectedPresetId = preset.id
    }

    private var themeCard: some View {
        playgroundSection("Theme") {
            PlaygroundSegmentRow(title: "Style", selection: $style, options: playgroundStyleOptions)
            PlaygroundPresetSwatches(selectedId: selectedPresetId, onSelect: applyPreset)
                .padding(.horizontal, 20)
                .padding(.bottom, 4)
            Button("Customize") { showAppearance = true }
                .font(ExampleFont.labelLarge)
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
        }
    }

    private var methodsCard: some View {
        playgroundSection("Payment methods") {
            ExampleSwitchRow(title: "Apple Pay", subtitle: "", isOn: $applePayEnabled)
            ExampleSwitchRow(title: "Crypto", subtitle: "", isOn: $cryptoEnabled, showDivider: true)
            ExampleSwitchRow(title: "Saved cards", subtitle: "", isOn: $savedCardsEnabled, showDivider: true)
            if savedCardsEnabled {
                ExampleSwitchRow(title: "Save card", subtitle: "", isOn: $saveCardOptInVisible, showDivider: true)
            }
        }
    }

    private var cardCard: some View {
        playgroundSection("Card") {
            PlaygroundMenuRow(title: "Language", selection: $locale, options: playgroundLocaleOptions)
            PlaygroundSegmentRow(title: "Grouping", selection: $grouping, options: playgroundGroupingOptions)
            PlaygroundMenuRow(title: "Validation", selection: $validation, options: playgroundValidationOptions)
            PlaygroundMenuRow(title: "Pay button", selection: $buttonType, options: playgroundButtonTypeOptions)
            ExampleSwitchRow(
                title: "Show Pay button",
                subtitle: mode == .embedded ? "" : "Sheet always shows it",
                isOn: mode == .embedded ? $submitVisible : .constant(true),
                enabled: mode == .embedded,
                showDivider: true
            )
            ExampleSwitchRow(title: "Name check", subtitle: "", isOn: $nameCheck, showDivider: true)
        }
    }

    private var customerCard: some View {
        playgroundSection("Customer") {
            ExampleSwitchRow(title: "Card details", subtitle: "", isOn: $customerDetailsCard)
            ExampleSwitchRow(
                title: "Apple Pay details",
                subtitle: "",
                isOn: $customerDetailsApplePay,
                enabled: applePayEnabled,
                showDivider: true
            )
            ExampleSwitchRow(title: "Custom field list", subtitle: "", isOn: $customerDetailsFieldsOverride, showDivider: true)
            if customerDetailsFieldsOverride {
                ExampleSwitchRow(title: "Name", subtitle: "", isOn: $customerDetailsFullName, showDivider: true)
                ExampleSwitchRow(title: "Email", subtitle: "", isOn: $customerDetailsEmail, showDivider: true)
                ExampleSwitchRow(title: "Phone", subtitle: "", isOn: $customerDetailsPhone, showDivider: true)
                ExampleSwitchRow(title: "Address", subtitle: "", isOn: $customerDetailsAddress, showDivider: true)
            }
            ExampleSwitchRow(title: "Prefill card form", subtitle: "", isOn: $customerDetailsPrefill, showDivider: true)
            if customerDetailsPrefill {
                PlaygroundDefaultField(title: "Full name", text: $defaultFullName)
                PlaygroundDefaultField(title: "Email", text: $defaultEmail)
                PlaygroundDefaultField(title: "Phone", text: $defaultPhone)
                PlaygroundDefaultField(title: "Country", text: $defaultCountry)
                PlaygroundDefaultField(title: "Region", text: $defaultRegion)
                PlaygroundDefaultField(title: "City", text: $defaultCity)
                PlaygroundDefaultField(title: "Postal code", text: $defaultPostalCode)
                PlaygroundDefaultField(title: "Address", text: $defaultAddress)
                ExampleButton(label: "Apply prefill", variant: .secondary) {
                    defaultsRevision += 1
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 12)
            }
        }
    }

    private var walletCard: some View {
        playgroundSection("Wallet button") {
            PlaygroundSegmentRow(title: "Color", selection: $walletColor, options: playgroundWalletColorOptions)
            PlaygroundMenuRow(title: "Type", selection: $walletType, options: playgroundWalletTypeOptions)
            AppearanceSliderRow(title: "Radius", value: $walletRadius, range: 0...28) { "\(Int($0))" }
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
        }
    }

    private func playgroundSection<Content: View>(_ title: String, @ViewBuilder content: @escaping () -> Content) -> some View {
        ExampleCard(contentPadding: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(ExampleFont.titleMedium)
                    .foregroundColor(theme.isDark ? ExampleColors.darkText : ExampleColors.lightText)
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                content()
            }
        }
    }

    private var customerDetailsFields: PaymentConfig.CustomerDetailsConfig.Fields? {
        guard customerDetailsFieldsOverride else { return nil }
        return .init(
            fullName: customerDetailsFullName,
            email: customerDetailsEmail,
            phone: customerDetailsPhone,
            address: customerDetailsAddress
        )
    }

    private var customerDetailsDefaultValues: PaymentConfig.CustomerDetailsConfig.DefaultValues? {
        guard customerDetailsPrefill else { return nil }
        return .init(
            fullName: defaultFullName,
            email: defaultEmail,
            phone: defaultPhone,
            country: defaultCountry,
            region: defaultRegion,
            city: defaultCity,
            postalCode: defaultPostalCode,
            address: defaultAddress
        )
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
    @Binding var appearance: PaymentConfig.Appearance
    @Binding var fontFamily: String
    @Binding var selectedPresetId: String?
    let style: DemoOption
    @Environment(\.presentationMode) private var presentation
    @EnvironmentObject private var theme: ExampleThemeState
    @State private var previewPayment: EmbeddedPayment?
    @State private var previewOrder: PaymentIntent?
    @State private var previewReady = false
    @State private var previewError: String?

    var body: some View {
        VStack(spacing: 0) {
            ExampleTopBar(
                title: "Appearance",
                onBack: { presentation.wrappedValue.dismiss() },
                actions: AnyView(
                    Button("Done") { presentation.wrappedValue.dismiss() }
                        .font(ExampleFont.labelLarge)
                )
            )
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Presets")
                        .font(ExampleFont.titleMedium)
                    PlaygroundPresetSwatches(selectedId: selectedPresetId) { preset in
                        appearance = preset.appearance
                        fontFamily = preset.appearance.fontFamily ?? ""
                        selectedPresetId = preset.id
                    }
                    HexColorField(
                        title: "Brand",
                        hex: appearance.brandColor?.light.hex ?? "",
                        onCommit: { hex in
                            var next = appearance
                            next.brandColor = hex.isEmpty ? nil : PaymentConfig.ThemeColor(hex: hex)
                            appearance = next
                        }
                    )
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Corners")
                            .exampleLabelMedium()
                            .foregroundColor(theme.isDark ? ExampleColors.darkMuted : ExampleColors.lightMuted)
                        Picker("Corners", selection: corner) {
                            Text("Sharp").tag(0)
                            Text("Default").tag(1)
                            Text("Rounded").tag(2)
                        }
                        .pickerStyle(.segmented)
                    }
                    Toggle("Pill buttons", isOn: pill)
                        .tint(ExampleColors.purple)
                    PlaygroundFontMenu(fontFamily: $fontFamily)
                    preview
                }
                .padding(20)
            }
        }
        .background((theme.isDark ? ExampleColors.darkBg : ExampleColors.lightBg).ignoresSafeArea())
        .navigationBarHidden(true)
        .onAppear {
            if previewPayment == nil {
                previewPayment = EmbeddedPayment(configuration: previewConfiguration) { result in
                    if case .failed = result { previewReady = true }
                }
            }
        }
        .task {
            guard previewOrder == nil else { return }
            if let message = DemoCheckoutBackend.secretsError() {
                previewError = message
                return
            }
            do {
                previewOrder = try await DemoCheckoutBackend.createPaymentIntent(
                    description: ExampleSecrets.orderDescription
                )
            } catch {
                if isCancellation(error) { return }
                previewError = error.localizedDescription
            }
        }
        .onChange(of: previewAppearance) { next in
            previewPayment?.updateAppearance(next)
        }
    }

    private var previewAppearance: PaymentConfig.Appearance {
        var next = appearance
        next.fontFamily = fontFamily.isEmpty ? nil : fontFamily
        next.colorScheme = playgroundStyle(style.value)
        return next
    }

    private var previewConfiguration: PaymentConfig {
        PaymentConfig(
            publicKey: ExampleSecrets.publicKey,
            card: .init(savedCards: .init(enabled: false)),
            paymentMethods: .init(applePay: .init(enabled: false)),
            options: .init(locale: "en-US", appearance: previewAppearance)
        )
    }

    @ViewBuilder
    private var preview: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Preview")
                .font(ExampleFont.titleMedium)
            if let previewError {
                ExampleStatusChip(previewError, .error)
            } else if let previewPayment, let previewOrder {
                MerchantReadyGate(ready: previewReady, message: "Preparing checkout…") {
                    PaymentElementHost(payment: previewPayment, intent: previewOrder) { event in
                        if case .ready = event { previewReady = true }
                    }
                }
            } else {
                ExampleLoader(message: "Preparing checkout…")
            }
        }
    }

    private var pill: Binding<Bool> {
        Binding(
            get: { appearance.pillButtons },
            set: { value in
                var next = appearance
                next.pillButtons = value
                appearance = next
            }
        )
    }

    private var corner: Binding<Int> {
        Binding(
            get: {
                switch appearance.corners {
                case .sharp: return 0
                case .rounded: return 2
                default: return 1
                }
            },
            set: { value in
                var next = appearance
                next.corners = value == 0 ? .sharp : value == 2 ? .rounded : .default
                appearance = next
            }
        )
    }

}

private struct AppearanceSliderRow: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let format: (Double) -> String
    var caption: String? = nil
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
            if let caption {
                Text(caption)
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
                        if draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            onCommit("")
                        } else if let hex = normalizedHex(draft) {
                            onCommit(hex)
                        }
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

private struct PlaygroundSegmentRow: View {
    let title: String
    @Binding var selection: DemoOption
    let options: [DemoOption]
    @EnvironmentObject private var theme: ExampleThemeState

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .exampleLabelMedium()
                .foregroundColor(theme.isDark ? ExampleColors.darkMuted : ExampleColors.lightMuted)
            Picker(title, selection: $selection) {
                ForEach(options, id: \.self) { Text($0.label).tag($0) }
            }
            .pickerStyle(.segmented)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
    }
}

private struct PlaygroundMenuRow: View {
    let title: String
    @Binding var selection: DemoOption
    let options: [DemoOption]

    var body: some View {
        Menu {
            ForEach(options, id: \.value) { option in
                Button(option.label) { selection = option }
            }
        } label: {
            PlaygroundValueLabel(title: title, value: selection.label)
                .frame(maxWidth: .infinity)
        }
    }
}

private struct PlaygroundFontMenu: View {
    @Binding var fontFamily: String

    private var label: String {
        playgroundFontFamilyOptions.first { $0.value == fontFamily }?.label ?? "Default (Roobert)"
    }

    var body: some View {
        Menu {
            ForEach(playgroundFontFamilyOptions, id: \.value) { option in
                Button(option.label) { fontFamily = option.value }
            }
        } label: {
            PlaygroundValueLabel(title: "Font", value: label)
                .frame(maxWidth: .infinity)
        }
    }
}

private struct PlaygroundValueLabel: View {
    let title: String
    let value: String
    @EnvironmentObject private var theme: ExampleThemeState

    var body: some View {
        HStack {
            Text(title)
                .font(ExampleFont.titleMedium)
                .foregroundColor(theme.isDark ? ExampleColors.darkText : ExampleColors.lightText)
            Spacer()
            Text(value)
                .font(ExampleFont.bodyMedium)
                .foregroundColor(theme.isDark ? ExampleColors.darkMuted : ExampleColors.lightMuted)
            Image(systemName: "chevron.up.chevron.down")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(theme.isDark ? ExampleColors.darkMuted : ExampleColors.lightMuted)
        }
        .contentShape(Rectangle())
    }
}

private struct PlaygroundPresetSwatches: View {
    let selectedId: String?
    let onSelect: (AppearancePreset) -> Void
    @Environment(\.exampleSemantics) private var semantics
    @EnvironmentObject private var theme: ExampleThemeState

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 8) {
                ForEach(AppearancePresets.all) { preset in
                    let selected = selectedId == preset.id
                    Button {
                        onSelect(preset)
                    } label: {
                        VStack(spacing: 6) {
                            Circle()
                                .fill(swatch(preset))
                                .frame(width: 36, height: 36)
                                .overlay(
                                    Circle().stroke(selected ? ExampleColors.purple : semantics.hairline, lineWidth: selected ? 2.5 : 1)
                                )
                            Text(preset.label)
                                .font(ExampleFont.bodyMedium)
                                .foregroundColor(theme.isDark ? ExampleColors.darkText : ExampleColors.lightText)
                                .lineLimit(2)
                                .multilineTextAlignment(.center)
                        }
                        .frame(width: 76)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func swatch(_ preset: AppearancePreset) -> Color {
        guard let brand = preset.appearance.brandColor else { return ExampleColors.purple }
        let channel = brand.light
        return Color(red: channel.red, green: channel.green, blue: channel.blue).opacity(channel.alpha)
    }
}

private struct PlaygroundDefaultField: View {
    let title: String
    @Binding var text: String
    @EnvironmentObject private var theme: ExampleThemeState

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .exampleLabelMedium()
                .foregroundColor(theme.isDark ? ExampleColors.darkMuted : ExampleColors.lightMuted)
            TextField(title, text: $text)
                .textFieldStyle(.roundedBorder)
                .font(ExampleFont.bodyMedium)
                .autocorrectionDisabled()
        }
        .padding(.horizontal, 20)
    }
}
