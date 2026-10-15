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

package final class SelectionListViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, UISearchBarDelegate {
    package var onSelect: ((String) -> Void)?
    package var onBack: (() -> Void)?

    private let titleText: String
    private let options: [SelectionListOption]
    private let selectedID: String?
    private let theme: CheckoutTheme
    private let locale: String
    private let tableView = UITableView(frame: .zero, style: .plain)
    private let searchBar = UISearchBar()
    private var filtered: [SelectionListOption] = []

    package init(
        title: String,
        options: [SelectionListOption],
        selectedID: String?,
        theme: CheckoutTheme,
        locale: String
    ) {
        self.titleText = title
        self.options = options
        self.selectedID = selectedID
        self.theme = theme
        self.locale = locale
        self.filtered = options
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    package override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = theme.background

        let back = UIButton(type: .system)
        back.setImage(
            EmbeddedAssets.image(named: "chevron-left")?.withRenderingMode(.alwaysTemplate),
            for: .normal
        )
        back.tintColor = theme.primaryText
        back.backgroundColor = theme.neutralChip
        back.layer.cornerRadius = 18
        back.accessibilityLabel = Strings.text("personalDetails.back", locale: locale)
        back.addAction(UIAction { [weak self] _ in self?.onBack?() }, for: .touchUpInside)
        back.translatesAutoresizingMaskIntoConstraints = false

        let titleLabel = UILabel()
        titleLabel.text = titleText
        titleLabel.font = theme.font(ofSize: 18, weight: .bold)
        titleLabel.textColor = theme.primaryText
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        searchBar.placeholder = titleText
        searchBar.searchBarStyle = .minimal
        searchBar.delegate = self
        searchBar.autocapitalizationType = .none
        searchBar.autocorrectionType = .no
        searchBar.translatesAutoresizingMaskIntoConstraints = false

        tableView.dataSource = self
        tableView.delegate = self
        tableView.backgroundColor = .clear
        tableView.separatorColor = theme.fieldDivider
        tableView.rowHeight = 52
        tableView.keyboardDismissMode = .onDrag
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "option")

        view.addSubview(back)
        view.addSubview(titleLabel)
        view.addSubview(searchBar)
        view.addSubview(tableView)
        NSLayoutConstraint.activate([
            back.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            back.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            back.widthAnchor.constraint(equalToConstant: 36),
            back.heightAnchor.constraint(equalToConstant: 36),
            titleLabel.centerYAnchor.constraint(equalTo: back.centerYAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: back.trailingAnchor, constant: 12),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -20),
            searchBar.topAnchor.constraint(equalTo: back.bottomAnchor, constant: 8),
            searchBar.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
            searchBar.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),
            tableView.topAnchor.constraint(equalTo: searchBar.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    package func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        filtered.count
    }

    package func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "option", for: indexPath)
        let option = filtered[indexPath.row]
        var content = cell.defaultContentConfiguration()
        content.text = option.title
        content.textProperties.font = theme.font(ofSize: 16, weight: .medium)
        content.textProperties.color = theme.primaryText
        cell.contentConfiguration = content
        cell.backgroundColor = .clear
        cell.accessoryType = option.id == selectedID ? .checkmark : .none
        cell.tintColor = theme.primary
        return cell
    }

    package func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        onSelect?(filtered[indexPath.row].id)
    }

    package func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if query.isEmpty {
            filtered = options
        } else {
            filtered = options.filter {
                $0.searchText.range(of: query, options: [.caseInsensitive, .diacriticInsensitive]) != nil
            }
        }
        tableView.reloadData()
    }
}
