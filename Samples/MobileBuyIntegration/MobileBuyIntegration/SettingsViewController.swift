/*
MIT License

Copyright 2023 - Present, Shopify Inc.

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*/

import UIKit
import ShopifyCheckoutKit

class SettingsViewController: UITableViewController {

	// MARK: Properties
	enum Section: Int, CaseIterable {
		case vaultedState = 0
		case payButton = 1
		case colorScheme = 2
		case invalidateCache = 3
		case version = 4
		case logs = 5
		case undefined = -1

		static func from(_ rawValue: Int) -> Section {
			return Section(rawValue: rawValue) ?? .undefined
		}
	}

	private var logs: [String?] = []

	private lazy var payButtonSwitch: UISwitch = {
		let view = UISwitch()
		view.isOn = ShopifyCheckoutKit.configuration.payButton.enabled
		view.addTarget(self, action: #selector(payButtonSwitchDidChange), for: .valueChanged)
		return view
	}()

	private lazy var vaultedStateSwitch: UISwitch = {
		let view = UISwitch()
		view.isOn = appConfiguration.useVaultedState
		view.addTarget(self, action: #selector(vaultedStateSwitchDidChange), for: .valueChanged)
		return view
	}()

	// MARK: Initializers

	init() {
		super.init(style: .grouped)

		title = "Settings"

		tabBarItem.image = UIImage(systemName: "gearshape.2")
	}

	required init?(coder: NSCoder) {
		fatalError("not implemented")
	}

	// MARK: UIViewController
	override func viewDidLoad() {
		super.viewDidLoad()

		tableView.register(Cell.self, forCellReuseIdentifier: "cell")
	}

	override func viewWillAppear(_ animated: Bool) {
		super.viewWillAppear(animated)

		logs = LogReader.shared.readLogs() ?? []

		DispatchQueue.main.async {
			self.tableView.reloadSections(IndexSet(integer: Section.logs.rawValue), with: .automatic)
		}
	}

	// MARK: UITableViewDataSource

	override func numberOfSections(in tableView: UITableView) -> Int {
		return Section.allCases.count
	}

	override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
		switch Section.from(section) {
		case Section.invalidateCache:
			return "Preloading"
		case Section.logs:
			return "Logs"
		case Section.colorScheme:
			return "Color Scheme"
		default:
			return nil
		}
	}

	override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		switch Section.from(section) {
		case Section.vaultedState, Section.version, Section.invalidateCache, Section.payButton:
			return 1
		case Section.colorScheme:
			return ShopifyCheckoutKit.Configuration.ColorScheme.allCases.count
		case Section.logs:
			return logs.count > 10 ? 10 : logs.count
		default:
			return 0
		}
	}

	override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
		var content = cell.defaultContentConfiguration()

		switch Section.from(indexPath.section) {
		case Section.vaultedState:
			content.text = "Prefill buyer information"
			cell.accessoryView = vaultedStateSwitch
			cell.contentConfiguration = content
		case Section.payButton:
			content.text = "Render native pay button"
			cell.accessoryView = payButtonSwitch
			cell.contentConfiguration = content
		case Section.colorScheme:
			let scheme = colorScheme(at: indexPath)
			content.text = scheme.prettyTitle
			content.secondaryText = ShopifyCheckoutKit.configuration.colorScheme == scheme ? "Active" : ""
			cell.contentConfiguration = content
		case Section.version:
			content = UIListContentConfiguration.valueCell()
			content.text = "Version"
			content.secondaryText = currentVersion()
			cell.contentConfiguration = content
		case Section.invalidateCache:
			let clearCacheButton = UIButton(type: .system)
			if cell.contentView.subviews.isEmpty {
				clearCacheButton.setTitle("Clear Preloading Cache", for: .normal)
				clearCacheButton.addTarget(self, action: #selector(clearPreloadingCache), for: .touchUpInside)
				clearCacheButton.frame = CGRect(x: 0, y: 0, width: cell.contentView.frame.width, height: cell.contentView.frame.height)
				cell.contentView.addSubview(clearCacheButton)
			}
		case Section.logs:
			content = UIListContentConfiguration.valueCell()
			if indexPath.row < logs.count {
				content.text = logs[indexPath.row]
			} else {
				content.text = "No log available"
			}
			content.textProperties.font = UIFont.systemFont(ofSize: 12)
			cell.contentConfiguration = content
		default:
			()
		}

		return cell
	}

	@objc private func clearPreloadingCache() {
		ShopifyCheckoutKit.configuration.preloading.clearCache()
	}

	override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
		switch Section.from(indexPath.section) {
		case Section.vaultedState:
			vaultedStateSwitch.isOn.toggle()
			vaultedStateSwitchDidChange()
		case Section.payButton:
			payButtonSwitch.isOn.toggle()
			payButtonSwitchDidChange()
		case Section.colorScheme:
			let newColorScheme = colorScheme(at: indexPath)
			ShopifyCheckoutKit.configuration.colorScheme = newColorScheme
			ShopifyCheckoutKit.configuration.spinnerColor = newColorScheme.spinnerColor
			ShopifyCheckoutKit.configuration.backgroundColor = newColorScheme.backgroundColor
			ShopifyCheckoutKit.configuration.borderColor = newColorScheme.borderColor
			view?.window?.overrideUserInterfaceStyle = newColorScheme.userInterfaceStyle
			tableView.reloadSections(IndexSet(integer: Section.colorScheme.rawValue), with: .automatic)
		case Section.invalidateCache:
			clearPreloadingCache()
			tableView.deselectRow(at: indexPath, animated: true)
		default:
			()
		}
	}

	// MARK: Private

	@objc private func vaultedStateSwitchDidChange() {
		appConfiguration.useVaultedState = vaultedStateSwitch.isOn
	}

	@objc private func payButtonSwitchDidChange() {
		ShopifyCheckoutKit.configuration.payButton.enabled = payButtonSwitch.isOn
	}

	private func currentColorScheme() -> Configuration.ColorScheme {
		return ShopifyCheckoutKit.configuration.colorScheme
	}

	private func colorScheme(at indexPath: IndexPath) -> Configuration.ColorScheme {
		return ShopifyCheckoutKit.Configuration.ColorScheme.allCases[indexPath.item]
	}

	private func indexPath(for colorScheme: Configuration.ColorScheme) -> IndexPath? {
		return ShopifyCheckoutKit.Configuration.ColorScheme.allCases.firstIndex(of: colorScheme).map {
			IndexPath(row: $0, section: 1)
		}
	}

	private func currentVersion() -> String {
		guard
			let info = Bundle.main.infoDictionary,
			let version = info["CFBundleShortVersionString"] as? String,
			let buildNumber = info["CFBundleVersion"] as? String
		else {
			return "--"
		}

		return "\(version) (\(buildNumber))"
	}
}

private class Cell: UITableViewCell {
	override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
		super.init(style: .subtitle, reuseIdentifier: reuseIdentifier)
		automaticallyUpdatesContentConfiguration = false
		selectionStyle = .none
	}

	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	override func prepareForReuse() {
		super.prepareForReuse()

		accessoryView = nil
	}
}

extension Configuration.ColorScheme {
	var prettyTitle: String {
		switch self {
		case .light:
			return "Light"
		case .dark:
			return "Dark"
		case .automatic:
			return "Automatic"
		case .web:
			return "Web Browser"
		}
	}

	var userInterfaceStyle: UIUserInterfaceStyle {
		switch self {
		case .light:
			return .light
		case .dark:
			return .dark
		default:
			return .unspecified
		}
	}

	var spinnerColor: UIColor {
		switch self {
		case .web:
			return UIColor(red: 0.18, green: 0.16, blue: 0.22, alpha: 1.00)
		default:
			return UIColor(red: 0.09, green: 0.45, blue: 0.69, alpha: 1.00)
		}
	}

	var payButtonBackgroundColor: UIColor {
		switch self {
		case .web:
			return UIColor(red: 0.94, green: 0.94, blue: 0.91, alpha: 1.00)
		default:
			return .systemBackground
		}
	}

	var borderColor: UIColor {
		switch self {
		case .web:
			return UIColor(red: 208/255, green: 208/255, blue: 205/255, alpha: 1.0)
		case .light:
			return UIColor(red: 222/255, green: 222/255, blue: 222/255, alpha: 1.0)
		case .dark:
			return UIColor(red: 68/255, green: 68/255, blue: 70/255, alpha: 1.0)
		default:
			return .systemGray5
		}
	}

	var backgroundColor: UIColor {
		switch self {
		case .web:
			return UIColor(red: 0.94, green: 0.94, blue: 0.91, alpha: 1.00)
		default:
			return .systemBackground
		}
	}
}
