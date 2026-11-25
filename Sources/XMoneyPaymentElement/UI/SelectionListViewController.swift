import UIKit
#if canImport(XMoneyCore)
import XMoneyCore
#endif

package struct SelectionListOption: Equatable {
    package let id: String
    package let title: String
    package let searchText: String

    package init(id: String, title: String, searchText: String? = nil) {
        self.id = id
        self.title = title
        self.searchText = searchText ?? title
    }
}

package final class SelectionListViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    package var onSelect: ((String) -> Void)?
    package var onBack: (() -> Void)?

    private static let rowHeight: CGFloat = 48
    fileprivate static let rowSpacing: CGFloat = 12

    private let titleText: String
    private let options: [SelectionListOption]
    private let selectedID: String?
    private let theme: CheckoutTheme
    private let locale: String
    private let closeTopInset: CGFloat
    private let tableView = UITableView(frame: .zero, style: .plain)
    private let searchField = UITextField()
    private var filtered: [SelectionListOption] = []

    package init(
        title: String,
        options: [SelectionListOption],
        selectedID: String?,
        theme: CheckoutTheme,
        locale: String,
        closeTopInset: CGFloat = 10
    ) {
        self.titleText = title
        self.options = options
        self.selectedID = selectedID
        self.theme = theme
        self.locale = locale
        self.closeTopInset = closeTopInset
        self.filtered = options
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    package override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = theme.background

        let close = CircleCloseButton(theme: theme, locale: locale)
        close.addAction(UIAction { [weak self] _ in self?.onBack?() }, for: .touchUpInside)

        let titleLabel = UILabel()
        titleLabel.numberOfLines = 2
        titleLabel.attributedText = NSAttributedString(
            string: titleText,
            attributes: [
                .font: theme.font(ofSize: 21, weight: .semibold),
                .foregroundColor: theme.primaryText,
                .kern: -0.63,
            ]
        )
        titleLabel.accessibilityTraits = .header
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        let searchBox = makeSearchBox()

        tableView.dataSource = self
        tableView.delegate = self
        tableView.backgroundColor = .clear
        tableView.separatorStyle = .none
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = Self.rowHeight + Self.rowSpacing
        tableView.showsVerticalScrollIndicator = false
        tableView.keyboardDismissMode = .onDrag
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.register(SelectionOptionCell.self, forCellReuseIdentifier: SelectionOptionCell.reuseID)

        view.addSubview(close)
        view.addSubview(titleLabel)
        view.addSubview(searchBox)
        view.addSubview(tableView)
        NSLayoutConstraint.activate([
            close.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: closeTopInset),
            close.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 6),
            titleLabel.leadingAnchor.constraint(equalTo: close.trailingAnchor, constant: 12),
            titleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            titleLabel.centerYAnchor.constraint(equalTo: close.centerYAnchor),
            searchBox.topAnchor.constraint(equalTo: close.bottomAnchor, constant: 16),
            searchBox.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            searchBox.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            searchBox.heightAnchor.constraint(
                greaterThanOrEqualToConstant: max(48, ceil((searchField.font?.lineHeight ?? 22) + 16))
            ),
            tableView.topAnchor.constraint(equalTo: searchBox.bottomAnchor, constant: 16),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    private func makeSearchBox() -> UIView {
        let box = UIView()
        box.backgroundColor = theme.componentBackground
        box.layer.cornerRadius = 16
        box.layer.borderWidth = theme.borderWidth
        box.layer.borderColor = theme.fieldBorder.cgColor
        box.translatesAutoresizingMaskIntoConstraints = false

        let icon = UIImageView(image: EmbeddedAssets.image(named: "search")?.withRenderingMode(.alwaysTemplate))
        icon.tintColor = theme.metaText
        icon.contentMode = .scaleAspectFit
        icon.translatesAutoresizingMaskIntoConstraints = false

        searchField.font = theme.font(ofSize: 18, weight: .regular)
        searchField.textColor = theme.primaryText
        searchField.tintColor = theme.primary
        searchField.attributedPlaceholder = NSAttributedString(
            string: titleText,
            attributes: [.foregroundColor: theme.inputPlaceholder, .font: theme.font(ofSize: 18, weight: .regular)]
        )
        searchField.defaultTextAttributes[.kern] = -0.18 * theme.fontScale
        searchField.autocapitalizationType = .none
        searchField.autocorrectionType = .no
        searchField.returnKeyType = .search
        searchField.clearButtonMode = .whileEditing
        searchField.accessibilityLabel = titleText
        searchField.addAction(UIAction { [weak self] _ in self?.applyFilter() }, for: .editingChanged)
        searchField.addAction(UIAction { [weak self] _ in self?.searchField.resignFirstResponder() }, for: .editingDidEndOnExit)
        searchField.translatesAutoresizingMaskIntoConstraints = false

        box.addSubview(icon)
        box.addSubview(searchField)
        NSLayoutConstraint.activate([
            icon.leadingAnchor.constraint(equalTo: box.leadingAnchor, constant: 16),
            icon.centerYAnchor.constraint(equalTo: box.centerYAnchor),
            icon.widthAnchor.constraint(equalToConstant: 16),
            icon.heightAnchor.constraint(equalToConstant: 16),
            searchField.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: 12),
            searchField.trailingAnchor.constraint(equalTo: box.trailingAnchor, constant: -16),
            searchField.topAnchor.constraint(equalTo: box.topAnchor),
            searchField.bottomAnchor.constraint(equalTo: box.bottomAnchor),
        ])
        return box
    }

    private func applyFilter() {
        let query = (searchField.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if query.isEmpty {
            filtered = options
        } else {
            filtered = options.filter {
                $0.searchText.range(of: query, options: [.caseInsensitive, .diacriticInsensitive]) != nil
            }
        }
        tableView.reloadData()
    }

    package func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        filtered.count
    }

    package func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: SelectionOptionCell.reuseID, for: indexPath)
        let option = filtered[indexPath.row]
        (cell as? SelectionOptionCell)?.configure(
            title: option.title,
            selected: option.id == selectedID,
            theme: theme,
            rowHeight: Self.rowHeight
        )
        return cell
    }

    package func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: false)
        onSelect?(filtered[indexPath.row].id)
    }
}

/// A 48pt choice row with a radio; the selected row gets the card fill. Spacing comes from the cell's extra height.
final class SelectionOptionCell: UITableViewCell {
    static let reuseID = "option"

    private let container = UIView()
    private let titleLabel = UILabel()
    private var radio: RadioIndicator?
    private var heightConstraint: NSLayoutConstraint?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        selectionStyle = .none
        container.layer.cornerRadius = 12
        container.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(container)
        container.addSubview(titleLabel)
        NSLayoutConstraint.activate([
            container.topAnchor.constraint(equalTo: contentView.topAnchor),
            container.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            container.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            container.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -SelectionListViewController.rowSpacing),
            titleLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 12),
            titleLabel.topAnchor.constraint(equalTo: container.topAnchor, constant: 12),
            titleLabel.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -12),
        ])
        titleLabel.numberOfLines = 0
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(title: String, selected: Bool, theme: CheckoutTheme, rowHeight: CGFloat) {
        if heightConstraint == nil {
            let height = container.heightAnchor.constraint(greaterThanOrEqualToConstant: rowHeight)
            height.isActive = true
            heightConstraint = height
        }
        if radio == nil {
            let indicator = RadioIndicator(theme: theme)
            container.addSubview(indicator)
            NSLayoutConstraint.activate([
                indicator.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -12),
                indicator.centerYAnchor.constraint(equalTo: container.centerYAnchor),
                titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: indicator.leadingAnchor, constant: -12),
            ])
            radio = indicator
        }
        titleLabel.attributedText = NSAttributedString(
            string: title,
            attributes: theme.titleAttributes(size: 18, weight: .medium, color: theme.primaryText)
        )
        container.backgroundColor = selected ? theme.componentBackground : .clear
        radio?.setSelected(selected, theme: theme, animated: false)
        accessibilityLabel = title
        accessibilityTraits = selected ? [.button, .selected] : .button
    }
}
