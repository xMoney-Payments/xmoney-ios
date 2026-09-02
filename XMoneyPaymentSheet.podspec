Pod::Spec.new do |s|
  s.name             = 'XMoneyPaymentSheet'
  s.version          = '0.0.3'
  s.summary          = 'Native xMoney checkout SDK for iOS'
  s.description      = 'Drop-in payment sheet, embedded Payment Element, and Apple Pay for xMoney.'
  s.homepage         = 'https://github.com/xMoney-Payments/xmoney-ios'
  s.license          = { type: 'MIT', file: 'LICENSE' }
  s.author           = { 'xMoney' => 'support@xmoney.com' }
  s.source           = { git: 'https://github.com/xMoney-Payments/xmoney-ios.git', tag: s.version.to_s }
  s.swift_version    = '5.9'
  s.ios.deployment_target = '15.0'
  s.resource_bundles = { 'XMoneyPaymentSheet' => 'PrivacyInfo.xcprivacy' }
  # CocoaPods is not SPM: `package` needs -package-name. Sibling SPM modules
  # compile into this one target — sources use `#if canImport(XMoneyCore)`.
  # Keep $(inherited) so CocoaPods' own OTHER_SWIFT_FLAGS (-D COCOAPODS) survive.
  pod_swift_xcconfig = {
    'OTHER_SWIFT_FLAGS' => '$(inherited) -package-name XMoneyPaymentSheet'
  }
  s.pod_target_xcconfig = pod_swift_xcconfig

  s.default_subspecs = 'PaymentSheet'

  s.subspec 'Core' do |core|
    core.source_files = 'Sources/XMoneyCore/**/*.swift'
    core.resources    = 'Resources/**/*', 'Sources/XMoneyCore/Resources/**/*'
    core.resource_bundles = { 'XMoneyCore' => 'PrivacyInfo.xcprivacy' }
    core.frameworks   = 'UIKit', 'WebKit'
    core.pod_target_xcconfig = pod_swift_xcconfig
  end

  s.subspec 'ApplePay' do |apple|
    apple.source_files = 'Sources/XMoneyApplePay/**/*.swift', 'Sources/XMoneyApplePayObjC/**/*.{h,m}'
    apple.dependency 'XMoneyPaymentSheet/Core'
    apple.frameworks   = 'PassKit', 'WebKit'
    apple.pod_target_xcconfig = pod_swift_xcconfig
  end

  s.subspec 'PaymentElement' do |emb|
    emb.source_files = 'Sources/XMoneyPaymentElement/**/*.swift'
    emb.dependency 'XMoneyPaymentSheet/Core'
    emb.resources    = [
      'Sources/XMoneyPaymentElement/Resources/XMoneyAssets.xcassets',
      'Sources/XMoneyPaymentElement/Resources/Fonts/*',
    ]
    emb.frameworks   = 'PassKit', 'WebKit'
    emb.pod_target_xcconfig = pod_swift_xcconfig
  end

  s.subspec 'PaymentSheet' do |sheet|
    sheet.source_files = 'Sources/XMoneyPaymentSheet/**/*.swift'
    sheet.dependency 'XMoneyPaymentSheet/Core'
    sheet.dependency 'XMoneyPaymentSheet/PaymentElement'
    sheet.dependency 'XMoneyPaymentSheet/ApplePay'
    sheet.frameworks   = 'PassKit', 'WebKit'
    sheet.pod_target_xcconfig = pod_swift_xcconfig
  end
end
