import UIKit

/// Everything a publisher would otherwise edit in source, editable on the device.
///
/// The screen is written as prose with fields in it rather than as a list of fields, because the
/// single thing people get wrong here cannot be shown as a field at all: the app never names your
/// Epom host or placement. It sends a slot id, and the mapping from that id to your inventory lives
/// on the Prebid Server. A form that only lists what it owns leaves that gap looking like a missing
/// setting, so the gap is spelled out where the ids are entered.
final class SettingsViewController: UIViewController {

    private var inputs: [(key: String, field: UITextField)] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Settings"
        view.backgroundColor = .systemBackground

        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 6

        intro(stack, "Two halves. This app knows where the auction runs and which slot to ask for. "
            + "Which Epom host and placement each slot means is not here — it lives on the Prebid "
            + "Server, and the last block says where.")

        section(stack, "The auction")
        add(to: stack, key: "server_url", label: "Prebid Server URL",
            hint: "The full endpoint, path included. Epom does not host one for you.",
            value: Settings.serverURL)
        add(to: stack, key: "account_id", label: "Prebid account id",
            hint: "Issued by whoever runs that server.",
            value: Settings.accountId)

        section(stack, "Slots")
        note(stack, "One id per screen. Each is a Prebid Server stored-request id — NOT an Epom "
            + "placement key. Get one wrong and the auction simply comes back empty; there is no "
            + "error worth the name.")
        add(to: stack, key: "config_mrec", label: "MREC 300x250",
            hint: "Both MREC screens — the one Prebid renders and the one Google renders.",
            value: Settings.configIdMREC)
        add(to: stack, key: "config_banner", label: "Mobile banner 320x50",
            hint: "The Google-rendered mobile banner.", value: Settings.configIdBanner)
        add(to: stack, key: "config_video", label: "In-banner video",
            hint: "VAST inside a 320x240 slot.", value: Settings.configIdVideo)
        add(to: stack, key: "config_native", label: "Native",
            hint: "Assets come back as JSON and the app draws them.", value: Settings.configIdNative)
        add(to: stack, key: "config_interstitial", label: "Interstitial video",
            hint: "Full screen, video only.", value: Settings.configIdInterstitial)
        add(to: stack, key: "config_interstitial_image", label: "Interstitial image",
            hint: "Full screen, banner creative only.", value: Settings.configIdInterstitialImage)
        add(to: stack, key: "config_playable", label: "Playable",
            hint: "Full screen, one HTML creative. Each full-screen screen has a slot of its own — "
                + "sharing an id lets the ad server decide which one you are looking at.",
            value: Settings.configIdPlayable)
        add(to: stack, key: "config_rewarded", label: "Rewarded video",
            hint: "Full screen, the reward arrives when the ad completes.",
            value: Settings.configIdRewarded)

        section(stack, "Google")
        note(stack, "Only the two screens that say \"Google renders\" use this. The ones that say "
            + "\"Prebid renders\" ignore it, which is why they fill on a fresh setup.")
        add(to: stack, key: "ad_unit", label: "Ad unit — MREC 300x250",
            hint: "A Prebid bid reaches it through the line items you set up against the hb_ keys.",
            value: Settings.adUnitMREC)
        add(to: stack, key: "ad_unit_banner", label: "Ad unit — mobile banner 320x50",
            hint: "A separate unit: line items built for an MREC do not fill a mobile banner.",
            value: Settings.adUnitBanner)
        note(stack, "Application id: \(Settings.googleApplicationId)\n\nFixed at build time in "
            + "Info.plist. The Mobile Ads SDK reads it while the app starts — before any of this "
            + "app's code runs — so it cannot be changed here.")

        section(stack, "Where your Epom host and placement live")
        note(stack, "Not in this app. Prebid Server looks up the stored request filed under the id "
            + "above, and that file is where your inventory is named. These two are the setup this "
            + "app ships with — copy either one and change the last two values.")

        note(stack, "A slot on a page — the MREC above:")
        code(stack, """
        {
          "id": "banner-300x250",
          "banner": {
            "format": [{ "w": 300, "h": 250 }]
          },
          "ext": { "prebid": { "bidder": {
            "epom_as": {
              "host": "ads.example.com",
              "placementKey": "d21751c4c6…"
            }
          } } }
        }
        """)

        note(stack, "A full-screen slot — the playable above. No size: it is the screen, and the "
            + "bid answers at the size of the device. Rewarded is the same with \"rwdd\": 1 in "
            + "place of \"instl\".")
        code(stack, """
        {
          "id": "playable-runes",
          "instl": 1,
          "ext": { "prebid": { "bidder": {
            "epom_as": {
              "host": "ads.example.com",
              "placementKey": "0b28983e17…"
            }
          } } }
        }
        """)

        note(stack, "host is your Epom serving domain. placementKey is on the placement itself, "
            + "under Ad tags & API. The file name is the id you type above, and it is yours to "
            + "choose — it never has to match the placement key.")

        let save = filled("Save")
        save.addAction(UIAction { [weak self] _ in self?.save() }, for: .touchUpInside)

        let reset = UIButton(type: .system)
        reset.setTitle("Reset to the values in the repository", for: .normal)
        reset.addAction(UIAction { [weak self] _ in
            Settings.reset()
            self?.navigationController?.popViewController(animated: true)
        }, for: .touchUpInside)

        stack.setCustomSpacing(28, after: stack.arrangedSubviews.last ?? save)
        stack.addArrangedSubview(save)
        stack.setCustomSpacing(4, after: save)
        stack.addArrangedSubview(reset)

        // The form is taller than any phone, and without this the two buttons above sit off the
        // bottom edge with no way to reach them.
        let scroll = UIScrollView()
        scroll.keyboardDismissMode = .onDrag
        scroll.alwaysBounceVertical = true
        scroll.translatesAutoresizingMaskIntoConstraints = false
        stack.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(stack)
        view.addSubview(scroll)

        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scroll.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scroll.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            stack.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor, constant: 16),
            stack.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor, constant: -40),
            stack.leadingAnchor.constraint(equalTo: scroll.frameLayoutGuide.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: scroll.frameLayoutGuide.trailingAnchor, constant: -20),
        ])
    }

    // MARK: - Pieces

    private func intro(_ stack: UIStackView, _ text: String) {
        let label = UILabel()
        label.numberOfLines = 0
        label.font = .systemFont(ofSize: 14)
        label.textColor = .label
        label.text = text
        stack.addArrangedSubview(label)
        stack.setCustomSpacing(4, after: label)
    }

    private func section(_ stack: UIStackView, _ title: String) {
        let label = UILabel()
        label.text = title.uppercased()
        label.font = .systemFont(ofSize: 12, weight: .semibold)
        label.textColor = Brand.blue
        stack.setCustomSpacing(28, after: stack.arrangedSubviews.last ?? label)
        stack.addArrangedSubview(label)
        stack.setCustomSpacing(10, after: label)
    }

    private func note(_ stack: UIStackView, _ text: String) {
        let label = UILabel()
        label.numberOfLines = 0
        label.font = .systemFont(ofSize: 12)
        label.textColor = .secondaryLabel
        label.text = text
        stack.addArrangedSubview(label)
        stack.setCustomSpacing(14, after: label)
    }

    private func code(_ stack: UIStackView, _ text: String) {
        let label = UILabel()
        label.numberOfLines = 0
        label.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        label.textColor = .label
        label.text = text
        let box = UIView()
        box.backgroundColor = .secondarySystemBackground
        box.layer.cornerRadius = 10
        box.translatesAutoresizingMaskIntoConstraints = false
        label.translatesAutoresizingMaskIntoConstraints = false
        box.addSubview(label)
        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: box.topAnchor, constant: 12),
            label.bottomAnchor.constraint(equalTo: box.bottomAnchor, constant: -12),
            label.leadingAnchor.constraint(equalTo: box.leadingAnchor, constant: 12),
            label.trailingAnchor.constraint(equalTo: box.trailingAnchor, constant: -12),
        ])
        stack.addArrangedSubview(box)
        stack.setCustomSpacing(14, after: box)
    }

    private func filled(_ title: String) -> UIButton {
        let button = UIButton(type: .system)
        var config = UIButton.Configuration.filled()
        config.title = title
        config.baseBackgroundColor = Brand.blue
        config.cornerStyle = .large
        config.contentInsets = NSDirectionalEdgeInsets(top: 12, leading: 20, bottom: 12, trailing: 20)
        button.configuration = config
        return button
    }

    private func add(to stack: UIStackView, key: String, label: String, hint: String, value: String) {
        let caption = UILabel()
        caption.text = label
        caption.font = .systemFont(ofSize: 13, weight: .medium)
        caption.textColor = .label

        let field = UITextField()
        field.text = value
        field.borderStyle = .roundedRect
        field.autocapitalizationType = .none
        field.autocorrectionType = .no
        field.clearButtonMode = .whileEditing
        field.font = .monospacedSystemFont(ofSize: 13, weight: .regular)

        let help = UILabel()
        help.numberOfLines = 0
        help.text = hint
        help.font = .systemFont(ofSize: 11)
        help.textColor = .secondaryLabel

        stack.addArrangedSubview(caption)
        stack.setCustomSpacing(4, after: caption)
        stack.addArrangedSubview(field)
        stack.setCustomSpacing(4, after: field)
        stack.addArrangedSubview(help)
        stack.setCustomSpacing(18, after: help)
        inputs.append((key, field))
    }

    private func save() {
        inputs.forEach { key, field in
            let text = field.text ?? ""
            switch key {
            case "server_url": Settings.serverURL = text
            case "account_id": Settings.accountId = text
            case "config_mrec": Settings.configIdMREC = text
            case "config_banner": Settings.configIdBanner = text
            case "config_video": Settings.configIdVideo = text
            case "config_native": Settings.configIdNative = text
            case "config_interstitial": Settings.configIdInterstitial = text
            case "config_interstitial_image": Settings.configIdInterstitialImage = text
            case "config_playable": Settings.configIdPlayable = text
            case "config_rewarded": Settings.configIdRewarded = text
            case "ad_unit": Settings.adUnitMREC = text
            case "ad_unit_banner": Settings.adUnitBanner = text
            default: break
            }
        }
        // Prebid keeps the server it was initialised with for the life of the process, so the change
        // only takes hold on a fresh start. Saying so beats leaving the user to wonder.
        let alert = UIAlertController(title: "Saved",
                                      message: "Restart the app for it to take effect.",
                                      preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in
            self.navigationController?.popViewController(animated: true)
        })
        present(alert, animated: true)
    }
}
