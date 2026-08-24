import SwiftUI
import XMoneyCore

enum MerchantCatalogStyle {
    case menu, plans, grid
}

enum MerchantPaySurface {
    case paymentSheet, embedded
}

struct MerchantProduct: Identifiable {
    let id: String
    let name: String
    let category: String
    let blurb: String
    let priceMinor: Int64
    let imageName: String
}

struct MerchantLine: Identifiable {
    var id: String { product.id }
    let product: MerchantProduct
    let quantity: Int
    var lineTotalMinor: Int64 { product.priceMinor * Int64(quantity) }
}

struct MerchantBrand {
    let name: String
    let tagline: String
    let emptyHint: String
    let catalogStyle: MerchantCatalogStyle
    let paySurface: MerchantPaySurface
    let products: [MerchantProduct]
    let appearance: PaymentConfig.AppearanceConfig
    let accent: Color
    let onAccent: Color
    let accentText: Color
}

extension MerchantBrand {
    static let hearthTerracotta = Color(red: 0xC4 / 255, green: 0x5C / 255, blue: 0x26 / 255)

    static let lumen = MerchantBrand(
        name: "Lumen",
        tagline: "Modern essentials. Pay with Payment Sheet.",
        emptyHint: "Add a few Lumen pieces from the store, then pay with Payment Sheet.",
        catalogStyle: .grid,
        paySurface: .paymentSheet,
        products: [
            .init(id: "earbuds", name: "Aura Earbuds", category: "Audio", blurb: "Spatial audio, 32-hour case", priceMinor: 12_900, imageName: "product_earbuds"),
            .init(id: "lamp", name: "Arc Desk Lamp", category: "Lighting", blurb: "Dimmable, brushed aluminum", priceMinor: 8_900, imageName: "product_lamp"),
            .init(id: "pour-over", name: "Stone Pour-Over", category: "Kitchen", blurb: "Matte ceramic, 600 ml", priceMinor: 4_200, imageName: "product_pourover"),
            .init(id: "throw", name: "Merino Throw", category: "Home", blurb: "Undyed wool, 140 × 200", priceMinor: 7_500, imageName: "product_throw"),
            .init(id: "notebooks", name: "Oak Notebooks", category: "Stationery", blurb: "Set of three, linen cover", priceMinor: 2_400, imageName: "product_notebooks"),
            .init(id: "weekender", name: "Canvas Weekender", category: "Travel", blurb: "Vegetable-tanned straps", priceMinor: 11_800, imageName: "product_weekender"),
            .init(id: "diffuser", name: "Ceramic Diffuser", category: "Wellness", blurb: "Ultrasonic, 4-hour timer", priceMinor: 5_400, imageName: "product_diffuser"),
            .init(id: "bottle", name: "Steel Bottle", category: "Everyday", blurb: "Double-wall, 750 ml", priceMinor: 3_200, imageName: "product_bottle"),
        ],
        appearance: exampleAppearance(),
        accent: ExampleColors.purple,
        onAccent: .white,
        accentText: ExampleColors.purple
    )

    static let hearth = MerchantBrand(
        name: "Hearth",
        tagline: "Neighbourhood café. Pay in-page with Embedded Element.",
        emptyHint: "Add a coffee or a plate from the board, then check out in this screen.",
        catalogStyle: .menu,
        paySurface: .embedded,
        products: [
            .init(id: "espresso", name: "House Espresso", category: "Drinks", blurb: "Single origin, 18g", priceMinor: 350, imageName: "product_espresso"),
            .init(id: "cortado", name: "Oat Cortado", category: "Drinks", blurb: "Equal parts, steamed oat", priceMinor: 420, imageName: "product_cortado"),
            .init(id: "cold-brew", name: "Cold Brew", category: "Drinks", blurb: "16-hour steep, served over ice", priceMinor: 480, imageName: "product_coldbrew"),
            .init(id: "grain-bowl", name: "Seasonal Grain Bowl", category: "Kitchen", blurb: "Farro, greens, citrus tahini", priceMinor: 1_400, imageName: "product_grainbowl"),
            .init(id: "tartine", name: "Smoked Salmon Tartine", category: "Kitchen", blurb: "Rye, crème fraîche, dill", priceMinor: 1_250, imageName: "product_tartine"),
            .init(id: "croissant", name: "Butter Croissant", category: "Bakery", blurb: "Laminated overnight", priceMinor: 380, imageName: "product_croissant"),
            .init(id: "morning-bun", name: "Almond Morning Bun", category: "Bakery", blurb: "Orange blossom, toasted nuts", priceMinor: 440, imageName: "product_morningbun"),
            .init(id: "loaf", name: "Citrus Loaf", category: "Bakery", blurb: "Olive oil, slice", priceMinor: 410, imageName: "product_loaf"),
        ],
        appearance: exampleAppearance(primary: hearthTerracotta),
        accent: hearthTerracotta,
        onAccent: .white,
        accentText: hearthTerracotta
    )

    static let pulse = MerchantBrand(
        name: "Pulse",
        tagline: "Studio memberships and classes. Embedded checkout.",
        emptyHint: "Choose a pack or a drop-in, then pay with the form on the next screen.",
        catalogStyle: .plans,
        paySurface: .embedded,
        products: [
            .init(id: "unlimited", name: "Monthly Unlimited", category: "Membership", blurb: "All classes, guest pass once a month", priceMinor: 7_900, imageName: "product_pulse_unlimited"),
            .init(id: "pack-5", name: "5-Class Pack", category: "Packs", blurb: "Use within 8 weeks", priceMinor: 9_500, imageName: "product_pulse_pack"),
            .init(id: "drop-in", name: "Drop-in Class", category: "Classes", blurb: "Any public session today", priceMinor: 2_200, imageName: "product_pulse_dropin"),
            .init(id: "reformer", name: "Reformer Intro", category: "Classes", blurb: "50 minutes, small group", priceMinor: 4_500, imageName: "product_pulse_reformer"),
            .init(id: "recovery", name: "Recovery Session", category: "Wellness", blurb: "Stretch + breathwork", priceMinor: 3_800, imageName: "product_pulse_recovery"),
            .init(id: "swim", name: "Lane Swim Pass", category: "Wellness", blurb: "Morning lanes, 10 entries", priceMinor: 6_000, imageName: "product_pulse_swim"),
            .init(id: "heart", name: "Heart-Rate Lab", category: "Classes", blurb: "Guided intervals, 40 minutes", priceMinor: 2_800, imageName: "product_pulse_heart"),
        ],
        appearance: exampleAppearance(
            primary: ExampleColors.limeDark,
            primaryDark: ExampleColors.lime,
            buttonBackground: ExampleColors.lime,
            buttonText: ExampleColors.limeDark
        ),
        accent: ExampleColors.lime,
        onAccent: ExampleColors.limeDark,
        accentText: ExampleColors.limeDark
    )
}

extension Array where Element == MerchantLine {
    var itemCount: Int { reduce(0) { $0 + $1.quantity } }
    var subtotalMinor: Int64 { reduce(0) { $0 + $1.lineTotalMinor } }
}

func merchantLines(quantities: [String: Int], products: [MerchantProduct]) -> [MerchantLine] {
    products.compactMap { product in
        let qty = quantities[product.id] ?? 0
        guard qty > 0 else { return nil }
        return MerchantLine(product: product, quantity: qty)
    }
}
