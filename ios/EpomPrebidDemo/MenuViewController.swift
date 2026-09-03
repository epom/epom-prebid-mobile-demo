import UIKit

/// The format picker. Every screen behind it asks the same Prebid Server for the same account.
final class MenuViewController: UIViewController {

    private let settingsRow = UIButton(type: .system)

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        let header = brandHeader()
        let scroll = UIScrollView()
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 6

        let intro = UILabel()
        intro.text = "Every screen below asks the same Prebid Server for a bid, and Epom answers it "
            + "as the epom_as bidder. There is no Epom SDK in this app."
        intro.font = .systemFont(ofSize: 14)
        intro.textColor = .label
        intro.numberOfLines = 0
        stack.addArrangedSubview(intro)
        stack.setCustomSpacing(20, after: intro)

        // A card rather than a bare link: it is the only control on the screen that is not a
        // format, and its subtitle is where the app says what it is actually pointed at.
        var settingsConfig = UIButton.Configuration.gray()
        settingsConfig.title = "Settings"
        settingsConfig.image = UIImage(systemName: "gearshape")
        settingsConfig.imagePadding = 10
        settingsConfig.baseForegroundColor = .label
        settingsConfig.cornerStyle = .large
        settingsConfig.contentInsets = .init(top: 14, leading: 16, bottom: 14, trailing: 16)
        settingsConfig.titleAlignment = .leading
        settingsRow.configuration = settingsConfig
        settingsRow.contentHorizontalAlignment = .leading
        settingsRow.addAction(UIAction { [weak self] _ in
            self?.navigationController?.pushViewController(SettingsViewController(), animated: true)
        }, for: .touchUpInside)
        stack.addArrangedSubview(settingsRow)
        stack.setCustomSpacing(28, after: settingsRow)

        group(stack, title: "Prebid renders", colour: Brand.blue,
              note: "The Prebid SDK draws the winning creative itself. Nothing has to be set up in "
                  + "an ad server — these fill as soon as the slot ids are right.",
              formats: Format.allCases.filter { !$0.rendersThroughGoogle })

        group(stack, title: "Google renders", colour: Brand.google,
              note: "Google Ad Manager draws the winner and Prebid only bids into it. These stay "
                  + "empty until line items are set up against the hb_ keys.",
              formats: Format.allCases.filter { $0.rendersThroughGoogle })

        [header, scroll].forEach { view.addSubview($0); $0.translatesAutoresizingMaskIntoConstraints = false }
        scroll.addSubview(stack)
        stack.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: view.topAnchor),
            header.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            header.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            scroll.topAnchor.constraint(equalTo: header.bottomAnchor),
            scroll.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scroll.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            stack.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor, constant: 20),
            stack.leadingAnchor.constraint(equalTo: scroll.frameLayoutGuide.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: scroll.frameLayoutGuide.trailingAnchor, constant: -20),
            stack.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor, constant: -20),
        ])
    }

    private func brandHeader() -> UIView {
        let bar = UIView()
        bar.backgroundColor = Brand.navy

        let mark = UIImageView(image: UIImage(named: "EpomMark"))
        mark.contentMode = .scaleAspectFit

        let title = UILabel()
        title.text = "Epom Ad Server"
        title.font = .boldSystemFont(ofSize: 17)
        title.textColor = .white

        let subtitle = UILabel()
        subtitle.text = "In-app header bidding, by example"
        subtitle.font = .systemFont(ofSize: 12)
        subtitle.textColor = Brand.muted

        let text = UIStackView(arrangedSubviews: [title, subtitle])
        text.axis = .vertical

        let row = UIStackView(arrangedSubviews: [mark, text])
        row.axis = .horizontal
        row.spacing = 14
        row.alignment = .center
        row.translatesAutoresizingMaskIntoConstraints = false
        bar.addSubview(row)

        NSLayoutConstraint.activate([
            mark.widthAnchor.constraint(equalToConstant: 34),
            mark.heightAnchor.constraint(equalToConstant: 38),
            row.leadingAnchor.constraint(equalTo: bar.leadingAnchor, constant: 20),
            row.trailingAnchor.constraint(lessThanOrEqualTo: bar.trailingAnchor, constant: -20),
            row.topAnchor.constraint(equalTo: bar.safeAreaLayoutGuide.topAnchor, constant: 12),
            row.bottomAnchor.constraint(equalTo: bar.bottomAnchor, constant: -20),
        ])
        return bar
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        settingsRow.configuration?.subtitle = serverSummary()
    }

    /// What this app will ask, in one line. A demo that is not pointed anywhere should say so on
    /// the first screen rather than on the eighth failed format.
    private func serverSummary() -> String {
        guard !Settings.isPlaceholder(Settings.serverURL),
              !Settings.isPlaceholder(Settings.accountId) else {
            return "Not set yet — every screen below comes back empty until it is."
        }
        let host = URL(string: Settings.serverURL)?.host ?? Settings.serverURL
        return "\(host) · account \(Settings.accountId)"
    }

    private func group(_ stack: UIStackView, title: String, colour: UIColor, note: String,
                       formats: [Format]) {
        let heading = UILabel()
        heading.text = title.uppercased()
        heading.font = .systemFont(ofSize: 12, weight: .semibold)
        heading.textColor = colour

        let caption = UILabel()
        caption.numberOfLines = 0
        caption.font = .systemFont(ofSize: 12)
        caption.textColor = .secondaryLabel
        caption.text = note

        stack.addArrangedSubview(heading)
        stack.setCustomSpacing(6, after: heading)
        stack.addArrangedSubview(caption)
        stack.setCustomSpacing(14, after: caption)
        formats.forEach { stack.addArrangedSubview(row(for: $0)) }
        stack.setCustomSpacing(28, after: stack.arrangedSubviews.last ?? caption)
    }

    private func row(for format: Format) -> UIView {
        var config = UIButton.Configuration.filled()
        config.title = format.title
        config.subtitle = format.subtitle
        config.baseBackgroundColor = format.rendersThroughGoogle ? Brand.google : Brand.blue
        config.baseForegroundColor = .white
        config.contentInsets = .init(top: 14, leading: 16, bottom: 14, trailing: 16)
        config.titleAlignment = .leading

        let button = UIButton(configuration: config)
        button.contentHorizontalAlignment = .leading
        button.addAction(UIAction { [weak self] _ in
            self?.navigationController?.pushViewController(AdViewController(format: format), animated: true)
        }, for: .touchUpInside)
        return button
    }
}
