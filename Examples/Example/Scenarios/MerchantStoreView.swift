import SwiftUI
import XMoneyApplePay
import XMoneyCore
import XMoneyPaymentElement
import XMoneyPaymentSheet

private enum MerchantRoute: Equatable {
    case catalog
    case cart
    case checkout
    case receipt(PaymentResult)
}

struct MerchantStoreView: View {
    let brand: MerchantBrand
    @EnvironmentObject private var theme: ExampleThemeState
    @Environment(\.presentationMode) private var presentation
    @State private var quantities: [String: Int] = [:]
    @State private var route: MerchantRoute = .catalog

    private var lines: [MerchantLine] {
        merchantLines(quantities: quantities, products: brand.products)
    }

    var body: some View {
        Group {
            switch route {
            case .catalog:
                CatalogScreen(
                    brand: brand,
                    lines: lines,
                    quantityOf: { quantities[$0] ?? 0 },
                    onBack: { presentation.wrappedValue.dismiss() },
                    onAdd: { id in quantities[id, default: 0] += 1 },
                    onOpenCart: { route = .cart }
                )
            case .cart:
                CartScreen(
                    brand: brand,
                    lines: lines,
                    onBack: { route = .catalog },
                    onQty: { id, qty in
                        if qty <= 0 { quantities[id] = nil } else { quantities[id] = qty }
                    },
                    onCheckout: { route = .checkout }
                )
            case .checkout:
                switch brand.paySurface {
                case .paymentSheet:
                    SheetCheckoutScreen(
                        brand: brand,
                        lines: lines,
                        onBack: { route = .cart },
                        onFinished: { route = .receipt($0) }
                    )
                case .embedded:
                    EmbeddedCheckoutScreen(
                        brand: brand,
                        lines: lines,
                        onQty: { id, qty in
                            if qty <= 0 { quantities[id] = nil } else { quantities[id] = qty }
                        },
                        onBack: { route = .cart },
                        onFinished: { route = .receipt($0) }
                    )
                }
            case let .receipt(result):
                ReceiptScreen(
                    brand: brand,
                    lines: lines,
                    result: result,
                    onDone: {
                        quantities = [:]
                        route = .catalog
                    },
                    onRetry: { route = .checkout },
                    onBackToCart: { route = .cart }
                )
            }
        }
        .environment(\.brandAccent, brand.accent)
        .environment(\.brandOnAccent, brand.onAccent)
        .environment(\.brandAccentText, theme.isDark ? brand.accent : brand.accentText)
        .navigationBarHidden(true)
    }
}

private struct CatalogScreen: View {
    let brand: MerchantBrand
    let lines: [MerchantLine]
    let quantityOf: (String) -> Int
    let onBack: () -> Void
    let onAdd: (String) -> Void
    let onOpenCart: () -> Void
    @EnvironmentObject private var theme: ExampleThemeState

    var body: some View {
        let currency = ExampleSecrets.currency
        let count = lines.itemCount
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    StoreTopBar(brand: brand, count: count, onBack: onBack, onOpenCart: onOpenCart)
                    switch brand.catalogStyle {
                    case .grid:
                        LazyVGrid(
                            columns: [
                                GridItem(.flexible(), spacing: 12),
                                GridItem(.flexible(), spacing: 12),
                            ],
                            spacing: 12
                        ) {
                            ForEach(brand.products) { product in
                                GridProductCard(
                                    product: product,
                                    quantity: quantityOf(product.id),
                                    currency: currency,
                                    onAdd: { onAdd(product.id) }
                                )
                            }
                        }
                        .padding(.horizontal, 20)
                    case .menu, .plans:
                        ForEach(grouped, id: \.0) { category, products in
                            Text(category.uppercased())
                                .exampleLabelMedium()
                                .foregroundColor(theme.isDark ? ExampleColors.darkMuted : ExampleColors.lightMuted)
                                .padding(.horizontal, 20)
                                .padding(.top, 8)
                            ForEach(products) { product in
                                Group {
                                    if brand.catalogStyle == .menu {
                                        MenuRow(
                                            product: product,
                                            quantity: quantityOf(product.id),
                                            currency: currency,
                                            onAdd: { onAdd(product.id) }
                                        )
                                    } else {
                                        PlanCard(
                                            product: product,
                                            quantity: quantityOf(product.id),
                                            currency: currency,
                                            onAdd: { onAdd(product.id) }
                                        )
                                    }
                                }
                                .padding(.horizontal, 20)
                            }
                        }
                    }
                }
                .padding(.bottom, 16)
            }
            if count > 0 {
                ExampleButton(
                    label: "Cart · \(count) \(count == 1 ? "item" : "items") · \(formatMoney(lines.subtotalMinor, currency: currency))",
                    action: onOpenCart
                )
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
            }
        }
        .background((theme.isDark ? ExampleColors.darkBg : ExampleColors.lightBg).ignoresSafeArea())
    }

    private var grouped: [(String, [MerchantProduct])] {
        var order: [String] = []
        var map: [String: [MerchantProduct]] = [:]
        for product in brand.products {
            if map[product.category] == nil { order.append(product.category) }
            map[product.category, default: []].append(product)
        }
        return order.map { ($0, map[$0] ?? []) }
    }
}

private struct StoreTopBar: View {
    let brand: MerchantBrand
    let count: Int
    let onBack: () -> Void
    let onOpenCart: () -> Void

    var body: some View {
        ExampleTopBar(
            title: brand.name,
            subtitle: brand.tagline,
            showWordmark: true,
            showThemeToggle: false,
            onBack: onBack,
            actions: AnyView(CartBadge(count: count, onClick: onOpenCart))
        )
    }
}

private struct CartBadge: View {
    let count: Int
    let onClick: () -> Void
    @Environment(\.brandAccent) private var accent
    @Environment(\.brandOnAccent) private var onAccent
    @EnvironmentObject private var theme: ExampleThemeState

    var body: some View {
        Button(action: onClick) {
            ZStack(alignment: .topTrailing) {
                Image(systemName: "bag")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(theme.isDark ? ExampleColors.darkText : ExampleColors.lightText)
                    .frame(width: 44, height: 44)
                if count > 0 {
                    Text(count > 9 ? "9+" : "\(count)")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(onAccent)
                        .frame(width: 16, height: 16)
                        .background(accent)
                        .clipShape(Circle())
                        .offset(x: -6, y: 6)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Cart")
    }
}

private struct GridProductCard: View {
    let product: MerchantProduct
    let quantity: Int
    let currency: String
    let onAdd: () -> Void
    @Environment(\.brandAccentText) private var accentText
    @Environment(\.exampleSemantics) private var semantics
    @EnvironmentObject private var theme: ExampleThemeState

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ExampleProductPhoto(imageName: product.imageName, aspectRatio: 1)
            VStack(alignment: .leading, spacing: 8) {
                Text(product.category.uppercased())
                    .exampleLabelMedium()
                    .foregroundColor(theme.isDark ? ExampleColors.darkMuted : ExampleColors.lightMuted)
                Text(product.name)
                    .font(ExampleFont.titleMedium)
                    .lineLimit(1)
                HStack {
                    Text(formatMoney(product.priceMinor, currency: currency))
                        .font(ExampleFont.titleMedium)
                        .foregroundColor(accentText)
                    Spacer()
                    ExampleAddChip(quantity: quantity, action: onAdd)
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 12)
            .padding(.bottom, 14)
        }
        .background(theme.isDark ? ExampleColors.darkCard : ExampleColors.lightCard)
        .clipShape(RoundedRectangle(cornerRadius: ExampleRadii.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: ExampleRadii.card, style: .continuous)
                .stroke(semantics.hairline, lineWidth: 1)
        )
    }
}

private struct MenuRow: View {
    let product: MerchantProduct
    let quantity: Int
    let currency: String
    let onAdd: () -> Void
    @Environment(\.brandAccentText) private var accentText
    @Environment(\.exampleSemantics) private var semantics
    @EnvironmentObject private var theme: ExampleThemeState

    var body: some View {
        HStack(spacing: 12) {
            ExampleProductPhoto(imageName: product.imageName)
                .frame(width: 72, height: 72)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(product.name).font(ExampleFont.titleMedium).lineLimit(1)
                Text(product.blurb)
                    .font(ExampleFont.bodyMedium)
                    .foregroundColor(theme.isDark ? ExampleColors.darkMuted : ExampleColors.lightMuted)
                    .lineLimit(1)
                Text(formatMoney(product.priceMinor, currency: currency))
                    .font(ExampleFont.titleMedium)
                    .foregroundColor(accentText)
            }
            Spacer()
            ExampleAddChip(quantity: quantity, action: onAdd)
        }
        .padding(10)
        .background(theme.isDark ? ExampleColors.darkCard : ExampleColors.lightCard)
        .clipShape(RoundedRectangle(cornerRadius: ExampleRadii.inner, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: ExampleRadii.inner, style: .continuous)
                .stroke(semantics.hairline, lineWidth: 1)
        )
    }
}

private struct PlanCard: View {
    let product: MerchantProduct
    let quantity: Int
    let currency: String
    let onAdd: () -> Void
    @Environment(\.brandAccentText) private var accentText
    @Environment(\.exampleSemantics) private var semantics
    @EnvironmentObject private var theme: ExampleThemeState

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ExampleProductPhoto(imageName: product.imageName, aspectRatio: 16 / 9)
            VStack(alignment: .leading, spacing: 8) {
                Text(product.category.uppercased())
                    .exampleLabelMedium()
                    .foregroundColor(theme.isDark ? ExampleColors.darkMuted : ExampleColors.lightMuted)
                Text(product.name).font(ExampleFont.titleLarge)
                Text(product.blurb)
                    .font(ExampleFont.bodyMedium)
                    .foregroundColor(theme.isDark ? ExampleColors.darkMuted : ExampleColors.lightMuted)
                HStack {
                    Text(formatMoney(product.priceMinor, currency: currency))
                        .font(ExampleFont.headlineMedium)
                        .foregroundColor(accentText)
                    Spacer()
                    ExampleAddChip(quantity: quantity, action: onAdd)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
        .background(theme.isDark ? ExampleColors.darkCard : ExampleColors.lightCard)
        .clipShape(RoundedRectangle(cornerRadius: ExampleRadii.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: ExampleRadii.card, style: .continuous)
                .stroke(semantics.hairline, lineWidth: 1)
        )
    }
}

private struct CartScreen: View {
    let brand: MerchantBrand
    let lines: [MerchantLine]
    let onBack: () -> Void
    let onQty: (String, Int) -> Void
    let onCheckout: () -> Void
    @EnvironmentObject private var theme: ExampleThemeState
    @Environment(\.exampleSemantics) private var semantics

    var body: some View {
        let currency = ExampleSecrets.currency
        let empty = lines.isEmpty
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    ExampleTopBar(
                        title: "Cart",
                        subtitle: empty ? "No items yet." : "\(lines.itemCount) items",
                        showThemeToggle: false,
                        onBack: onBack
                    )
                    if empty {
                        ExampleCard {
                            Text("Your bag is empty").font(ExampleFont.titleLarge)
                            Text(brand.emptyHint)
                                .font(ExampleFont.bodyMedium)
                                .foregroundColor(theme.isDark ? ExampleColors.darkMuted : ExampleColors.lightMuted)
                            ExampleButton(label: "Continue shopping", variant: .secondary, action: onBack)
                        }
                        .padding(.horizontal, 20)
                    } else {
                        ExampleCard(contentPadding: 8) {
                            VStack(spacing: 0) {
                                ForEach(Array(lines.enumerated()), id: \.element.id) { index, line in
                                    if index > 0 { Divider().background(semantics.hairline) }
                                    CartLineRow(line: line, currency: currency, onQty: { onQty(line.product.id, $0) })
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                }
                .padding(.bottom, 16)
            }
            if !empty {
                VStack(spacing: 10) {
                    TotalsBlock(lines: lines, currency: currency)
                    ExampleButton(
                        label: "Checkout · \(formatMoney(lines.subtotalMinor, currency: currency))",
                        action: onCheckout
                    )
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
            }
        }
        .background((theme.isDark ? ExampleColors.darkBg : ExampleColors.lightBg).ignoresSafeArea())
    }
}

private struct CartLineRow: View {
    let line: MerchantLine
    let currency: String
    let onQty: (Int) -> Void
    @EnvironmentObject private var theme: ExampleThemeState

    var body: some View {
        HStack(spacing: 12) {
            ExampleProductPhoto(imageName: line.product.imageName)
                .frame(width: 64, height: 64)
                .clipShape(RoundedRectangle(cornerRadius: ExampleRadii.inner, style: .continuous))
            VStack(alignment: .leading, spacing: 4) {
                Text(line.product.name).font(ExampleFont.titleMedium).lineLimit(1)
                Text(formatMoney(line.product.priceMinor, currency: currency))
                    .font(ExampleFont.bodyMedium)
                    .foregroundColor(theme.isDark ? ExampleColors.darkMuted : ExampleColors.lightMuted)
                QtyStepper(quantity: line.quantity, onQty: onQty)
            }
            Spacer()
            Text(formatMoney(line.lineTotalMinor, currency: currency))
                .font(ExampleFont.titleMedium)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 8)
    }
}

private struct QtyStepper: View {
    let quantity: Int
    let onQty: (Int) -> Void
    @Environment(\.exampleSemantics) private var semantics
    @EnvironmentObject private var theme: ExampleThemeState

    var body: some View {
        let ink = theme.isDark ? ExampleColors.darkText : ExampleColors.lightText
        HStack(spacing: 0) {
            Button { onQty(quantity - 1) } label: {
                Image(systemName: "minus")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(ink)
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.plain)
            Text("\(quantity)")
                .font(ExampleFont.labelLarge)
                .foregroundColor(ink)
                .padding(.horizontal, 4)
            Button { onQty(quantity + 1) } label: {
                Image(systemName: "plus")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(ink)
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.plain)
        }
        .overlay(Capsule().stroke(semantics.hairline, lineWidth: 1))
    }
}

private struct TotalsBlock: View {
    let lines: [MerchantLine]
    let currency: String
    @EnvironmentObject private var theme: ExampleThemeState

    var body: some View {
        VStack(spacing: 6) {
            HStack {
                Text("Subtotal")
                    .font(ExampleFont.bodyMedium)
                    .foregroundColor(theme.isDark ? ExampleColors.darkMuted : ExampleColors.lightMuted)
                Spacer()
                Text(formatMoney(lines.subtotalMinor, currency: currency))
                    .font(ExampleFont.bodyMedium)
            }
            HStack {
                Text("Total").font(ExampleFont.titleMedium)
                Spacer()
                Text(formatMoney(lines.subtotalMinor, currency: currency))
                    .font(ExampleFont.titleMedium)
            }
        }
    }
}

private struct OrderSummaryCard: View {
    let lines: [MerchantLine]
    let currency: String
    var onQty: ((String, Int) -> Void)? = nil
    @Environment(\.exampleSemantics) private var semantics
    @EnvironmentObject private var theme: ExampleThemeState

    var body: some View {
        ExampleCard {
            Text("ORDER")
                .exampleLabelMedium()
                .foregroundColor(theme.isDark ? ExampleColors.darkMuted : ExampleColors.lightMuted)
            ForEach(lines) { line in
                if let onQty {
                    CartLineRow(line: line, currency: currency, onQty: { onQty(line.product.id, $0) })
                } else {
                    HStack {
                        Text("\(line.product.name) × \(line.quantity)")
                            .font(ExampleFont.bodyMedium)
                        Spacer()
                        Text(formatMoney(line.lineTotalMinor, currency: currency))
                            .font(ExampleFont.titleMedium)
                    }
                }
            }
            Divider().background(semantics.hairline)
            TotalsBlock(lines: lines, currency: currency)
        }
    }
}

private struct SheetCheckoutScreen: View {
    let brand: MerchantBrand
    let lines: [MerchantLine]
    let onBack: () -> Void
    let onFinished: (PaymentResult) -> Void
    @EnvironmentObject private var theme: ExampleThemeState
    @State private var error: String?
    @State private var loading = false
    @State private var heldIntent: PaymentIntent?
    @State private var didProcess = false
    @State private var showSheet = false

    var body: some View {
        let currency = ExampleSecrets.currency
        let total = lines.subtotalMinor
        let description = "\(brand.name) · \(lines.itemCount) \(lines.itemCount == 1 ? "item" : "items")"
        let configuration = defaultPaymentConfig(isDark: theme.isDark, appearance: brand.appearance)

        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    ExampleTopBar(
                        title: "Checkout",
                        subtitle: "Pay with Payment Sheet.",
                        showThemeToggle: false,
                        onBack: onBack
                    )
                    OrderSummaryCard(lines: lines, currency: currency)
                        .padding(.horizontal, 20)
                }
            }
            VStack(spacing: 12) {
                if let error { ExampleStatusChip(error, .error) }
                ExampleButton(label: "Pay \(formatMoney(total, currency: currency))", loading: loading) {
                    loading = true
                    error = nil
                    Task {
                        do {
                            let intent: PaymentIntent
                            if let heldIntent {
                                intent = heldIntent
                            } else {
                                intent = try await DemoCheckoutBackend.createPaymentIntent(
                                    amountMinor: total,
                                    description: description
                                )
                            }
                            await MainActor.run {
                                heldIntent = intent
                                didProcess = false
                                showSheet = true
                            }
                        } catch {
                            if isCancellation(error) { return }
                            await MainActor.run {
                                self.error = error.localizedDescription
                                loading = false
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .background((theme.isDark ? ExampleColors.darkBg : ExampleColors.lightBg).ignoresSafeArea())
        .background(
            Group {
                if let intent = heldIntent {
                    Color.clear.paymentSheet(
                        isPresented: $showSheet,
                        configuration: configuration,
                        intent: intent,
                        onEvent: { event in
                            switch event {
                            case .ready: loading = false
                            case let .processing(isProcessing):
                                if isProcessing { didProcess = true }
                            }
                        },
                        onCompletion: { result in
                            loading = false
                            showSheet = false
                            if orderConsumed(result, didProcess: didProcess) {
                                heldIntent = nil
                                onFinished(result)
                            }
                        }
                    )
                }
            }
        )
        .id(theme.isDark)
    }
}

private struct EmbeddedCheckoutScreen: View {
    let brand: MerchantBrand
    let lines: [MerchantLine]
    let onQty: (String, Int) -> Void
    let onBack: () -> Void
    let onFinished: (PaymentResult) -> Void
    @EnvironmentObject private var theme: ExampleThemeState
    @State private var intent: PaymentIntent?
    @State private var error: String?
    @State private var retryKey = 0
    @State private var payment: EmbeddedPayment?
    @State private var ready = false

    var body: some View {
        let currency = ExampleSecrets.currency
        let total = lines.subtotalMinor
        let description = "\(brand.name) · \(lines.itemCount) \(lines.itemCount == 1 ? "item" : "items")"
        let configuration = defaultPaymentConfig(isDark: theme.isDark, appearance: brand.appearance)

        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ExampleTopBar(
                    title: "Checkout",
                    subtitle: "Pay with Embedded Payment Element.",
                    showThemeToggle: false,
                    onBack: onBack
                )
                OrderSummaryCard(lines: lines, currency: currency, onQty: onQty)
                    .padding(.horizontal, 12)
                if let payment, let intent {
                    MerchantReadyGate(ready: ready, message: "Preparing checkout…") {
                        PaymentElementHost(payment: payment, intent: intent) { event in
                            if case .ready = event { ready = true }
                        }
                    }
                    .padding(.horizontal, 12)
                } else {
                    ExampleLoader(message: "Preparing checkout…")
                }
                if let error {
                    ExampleStatusChip(error, .error)
                        .padding(.horizontal, 12)
                    ExampleButton(label: "Try again", variant: .secondary) { retryKey += 1 }
                        .padding(.horizontal, 12)
                }
            }
            .padding(.bottom, 24)
        }
        .background((theme.isDark ? ExampleColors.darkBg : ExampleColors.lightBg).ignoresSafeArea())
        .onAppear {
            ApplePay.register()
            if payment == nil {
                payment = EmbeddedPayment(configuration: configuration) { result in
                    if result == .canceled, payment?.isOrderConsumed == false { return }
                    onFinished(result)
                }
            }
            if lines.isEmpty { onBack() }
        }
        .onChange(of: theme.isDark) { _ in
            payment = EmbeddedPayment(configuration: configuration) { result in
                if result == .canceled, payment?.isOrderConsumed == false { return }
                onFinished(result)
            }
            ready = false
        }
        .task(id: "\(total)-\(description)-\(retryKey)-\(theme.isDark)-\(payment != nil)") {
            if lines.isEmpty || payment == nil { return }
            if intent != nil {
                try? await Task.sleep(nanoseconds: 300_000_000)
            }
            error = nil
            do {
                let next = try await DemoCheckoutBackend.createPaymentIntent(
                    amountMinor: total,
                    description: description
                )
                guard !Task.isCancelled else { return }
                await MainActor.run { intent = next }
            } catch {
                guard !isCancellation(error) else { return }
                await MainActor.run { self.error = error.localizedDescription }
            }
        }
    }
}

private struct ReceiptScreen: View {
    let brand: MerchantBrand
    let lines: [MerchantLine]
    let result: PaymentResult
    let onDone: () -> Void
    let onRetry: () -> Void
    let onBackToCart: () -> Void
    @EnvironmentObject private var theme: ExampleThemeState

    var body: some View {
        let currency = ExampleSecrets.currency
        let success = if case .complete = result { true } else { false }
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    ExampleTopBar(
                        title: success ? "Receipt" : "Payment",
                        showWordmark: true,
                        showThemeToggle: false
                    )
                    ExampleResultPanel(
                        result: result,
                        fallbackAmount: formatMoney(lines.subtotalMinor, currency: currency),
                        successTitle: "Order confirmed",
                        failureTitle: "Payment didn’t go through"
                    )
                    .padding(.horizontal, 20)
                    if !lines.isEmpty {
                        ExampleCard {
                            Text("ITEMS")
                                .exampleLabelMedium()
                                .foregroundColor(theme.isDark ? ExampleColors.darkMuted : ExampleColors.lightMuted)
                            ForEach(lines) { line in
                                HStack {
                                    Text("\(line.product.name) × \(line.quantity)")
                                    Spacer()
                                    Text(formatMoney(line.lineTotalMinor, currency: currency))
                                }
                                .font(ExampleFont.bodyMedium)
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                }
                .padding(.bottom, 16)
            }
            VStack(spacing: 10) {
                if success {
                    ExampleButton(label: "Back to \(brand.name)", action: onDone)
                } else {
                    ExampleButton(label: "Try again", action: onRetry)
                    ExampleButton(label: "Back to cart", variant: .secondary, action: onBackToCart)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .background((theme.isDark ? ExampleColors.darkBg : ExampleColors.lightBg).ignoresSafeArea())
    }
}
