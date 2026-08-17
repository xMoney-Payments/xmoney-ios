import UIKit
import WebKit

package final class ThreeDSViewController: UIViewController, WKNavigationDelegate, WKUIDelegate {
    private let url: URL
    private let returnURLMatcher: (URL) -> Bool
    private let completion: (Bool) -> Void
    private let locale: String
    private var didFinish = false
    private var didHideOverlay = false
    private var dots: [UIView] = []

    private lazy var headerView: UIView = makeHeader()
    private lazy var webView: WKWebView = makeWebView()
    private lazy var loadingOverlay: UIView = makeLoadingOverlay()

    package init(
        url: URL,
        returnURLMatcher: @escaping (URL) -> Bool,
        completion: @escaping (Bool) -> Void,
        locale: String = "en-US"
    ) {
        self.url = url
        self.returnURLMatcher = returnURLMatcher
        self.completion = completion
        self.locale = locale
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .fullScreen
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    package override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        navigationController?.setNavigationBarHidden(true, animated: false)

        view.addSubview(webView)
        view.addSubview(loadingOverlay)
        view.addSubview(headerView)

        NSLayoutConstraint.activate([
            headerView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            headerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            headerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            webView.topAnchor.constraint(equalTo: headerView.bottomAnchor),
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            webView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            loadingOverlay.topAnchor.constraint(equalTo: view.topAnchor),
            loadingOverlay.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            loadingOverlay.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            loadingOverlay.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        webView.load(URLRequest(url: url))
    }

    package override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: false)
    }

    package override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        startDotAnimations()
    }

    // MARK: - Builders

    private func makeHeader() -> UIView {
        let header = UIView()
        header.backgroundColor = .white
        header.translatesAutoresizingMaskIntoConstraints = false

        let close = UIButton(type: .system)
        close.setTitle("✕", for: .normal)
        close.setTitleColor(UIColor(red: 0x16 / 255, green: 0x14 / 255, blue: 0x1A / 255, alpha: 1), for: .normal)
        close.titleLabel?.font = .systemFont(ofSize: 13, weight: .medium)
        close.backgroundColor = UIColor(red: 0xF2 / 255, green: 0xF2 / 255, blue: 0xF2 / 255, alpha: 1)
        close.layer.cornerRadius = 18
        close.translatesAutoresizingMaskIntoConstraints = false
        close.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)

        let title = UILabel()
        title.text = Strings.text("sheet.authentication", locale: locale)
        title.font = .systemFont(ofSize: 17, weight: .semibold)
        title.textColor = UIColor(red: 0x16 / 255, green: 0x14 / 255, blue: 0x1A / 255, alpha: 1)
        title.textAlignment = .center
        title.translatesAutoresizingMaskIntoConstraints = false

        let spacer = UIView()
        spacer.translatesAutoresizingMaskIntoConstraints = false

        header.addSubview(close)
        header.addSubview(title)
        header.addSubview(spacer)

        NSLayoutConstraint.activate([
            header.heightAnchor.constraint(equalToConstant: 60),
            close.leadingAnchor.constraint(equalTo: header.leadingAnchor, constant: 16),
            close.centerYAnchor.constraint(equalTo: header.centerYAnchor),
            close.widthAnchor.constraint(equalToConstant: 36),
            close.heightAnchor.constraint(equalToConstant: 36),

            spacer.trailingAnchor.constraint(equalTo: header.trailingAnchor, constant: -16),
            spacer.centerYAnchor.constraint(equalTo: header.centerYAnchor),
            spacer.widthAnchor.constraint(equalToConstant: 36),
            spacer.heightAnchor.constraint(equalToConstant: 36),

            title.leadingAnchor.constraint(equalTo: close.trailingAnchor, constant: 8),
            title.trailingAnchor.constraint(equalTo: spacer.leadingAnchor, constant: -8),
            title.centerYAnchor.constraint(equalTo: header.centerYAnchor),
        ])
        return header
    }

    private func makeWebView() -> WKWebView {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .nonPersistent()
        config.preferences.javaScriptCanOpenWindowsAutomatically = true
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.backgroundColor = .white
        webView.isOpaque = true
        webView.translatesAutoresizingMaskIntoConstraints = false
        return webView
    }

    private func makeLoadingOverlay() -> UIView {
        let overlay = UIView()
        overlay.backgroundColor = .white
        overlay.translatesAutoresizingMaskIntoConstraints = false

        let content = UIStackView()
        content.axis = .vertical
        content.alignment = .center
        content.spacing = 24
        content.translatesAutoresizingMaskIntoConstraints = false

        let dotsRow = UIStackView()
        dotsRow.axis = .horizontal
        dotsRow.alignment = .center
        dotsRow.spacing = 8

        let delays: [CFTimeInterval] = [0, 0.15, 0.3, 0.45, 0.6]
        let dotColor = UIColor(red: 0x7C / 255, green: 0x4D / 255, blue: 0xFF / 255, alpha: 1)
        for delay in delays {
            let dot = UIView()
            dot.backgroundColor = dotColor
            dot.layer.cornerRadius = 4
            dot.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                dot.widthAnchor.constraint(equalToConstant: 8),
                dot.heightAnchor.constraint(equalToConstant: 8),
            ])
            dot.layer.setValue(delay, forKey: "dotDelay")
            dotsRow.addArrangedSubview(dot)
            dots.append(dot)
        }

        let label = UILabel()
        label.text = Strings.text("sheet.processingPayment", locale: locale)
        label.font = .systemFont(ofSize: 16, weight: .medium)
        label.textColor = UIColor(red: 0x6B / 255, green: 0x6B / 255, blue: 0x6B / 255, alpha: 1)
        label.textAlignment = .center

        content.addArrangedSubview(dotsRow)
        content.addArrangedSubview(label)

        let brand = UIImageView()
        brand.image = CoreAssets.image(named: "xmoney-3ds-brand")
        brand.contentMode = .scaleAspectFit
        brand.translatesAutoresizingMaskIntoConstraints = false

        overlay.addSubview(content)
        overlay.addSubview(brand)

        NSLayoutConstraint.activate([
            content.centerXAnchor.constraint(equalTo: overlay.centerXAnchor),
            content.centerYAnchor.constraint(equalTo: overlay.centerYAnchor),
            content.leadingAnchor.constraint(greaterThanOrEqualTo: overlay.leadingAnchor, constant: 32),
            content.trailingAnchor.constraint(lessThanOrEqualTo: overlay.trailingAnchor, constant: -32),

            brand.centerXAnchor.constraint(equalTo: overlay.centerXAnchor),
            brand.bottomAnchor.constraint(equalTo: overlay.safeAreaLayoutGuide.bottomAnchor, constant: -24),
            brand.widthAnchor.constraint(equalToConstant: 89),
            brand.heightAnchor.constraint(equalToConstant: 24),
        ])
        return overlay
    }

    private func startDotAnimations() {
        for dot in dots {
            guard dot.layer.animation(forKey: "dotPulse") == nil else { continue }
            let delay = (dot.layer.value(forKey: "dotDelay") as? CFTimeInterval) ?? 0

            let opacity = CABasicAnimation(keyPath: "opacity")
            opacity.fromValue = 0.35
            opacity.toValue = 1
            opacity.autoreverses = true
            opacity.duration = 0.6

            let scale = CABasicAnimation(keyPath: "transform.scale")
            scale.fromValue = 0.9
            scale.toValue = 1
            scale.autoreverses = true
            scale.duration = 0.6

            let group = CAAnimationGroup()
            group.animations = [opacity, scale]
            group.duration = 1.2
            group.beginTime = CACurrentMediaTime() + delay
            group.repeatCount = .infinity
            group.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            dot.layer.add(group, forKey: "dotPulse")
        }
    }

    @objc private func cancelTapped() {
        finish(false)
    }

    private func finish(_ success: Bool) {
        guard !didFinish else { return }
        didFinish = true
        tearDownWebView()
        completion(success)
        dismiss(animated: true)
    }

    private func tearDownWebView() {
        webView.stopLoading()
        webView.navigationDelegate = nil
        webView.uiDelegate = nil
    }

    /// Allows only https and about:blank; blocks javascript:, file:, http, and custom schemes.
    private func isAllowedNavigation(_ url: URL) -> Bool {
        guard let scheme = url.scheme?.lowercased() else { return false }
        return scheme == "https" || scheme == "about"
    }

    private func hideLoadingOverlay() {
        guard !didHideOverlay else { return }
        didHideOverlay = true
        UIView.animate(withDuration: 0.2, animations: {
            self.loadingOverlay.alpha = 0
        }, completion: { _ in
            self.loadingOverlay.isHidden = true
            self.dots.forEach { $0.layer.removeAllAnimations() }
        })
    }

    // MARK: - WKNavigationDelegate

    package func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
    ) {
        guard let url = navigationAction.request.url else {
            decisionHandler(.cancel)
            return
        }
        if returnURLMatcher(url) {
            decisionHandler(.cancel)
            finish(true)
            return
        }
        guard isAllowedNavigation(url) else {
            decisionHandler(.cancel)
            return
        }
        decisionHandler(.allow)
    }

    package func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        hideLoadingOverlay()
    }

    // MARK: - WKUIDelegate

    package func webView(
        _ webView: WKWebView,
        createWebViewWith configuration: WKWebViewConfiguration,
        for navigationAction: WKNavigationAction,
        windowFeatures: WKWindowFeatures
    ) -> WKWebView? {
        // Load target=_blank / window.open in the existing web view; avoid orphaned popups.
        if let url = navigationAction.request.url, isAllowedNavigation(url) {
            webView.load(URLRequest(url: url))
        }
        return nil
    }
}
