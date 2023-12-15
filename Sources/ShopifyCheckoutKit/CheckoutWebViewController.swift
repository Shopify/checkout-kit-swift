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
import WebKit

class CheckoutWebViewController: UIViewController, UIAdaptivePresentationControllerDelegate {

	// MARK: Properties

	weak var delegate: CheckoutDelegate?

	private let checkoutView: CheckoutWebView

	private lazy var spinner: SpinnerView = {
		let spinner = SpinnerView(frame: .zero)
		spinner.translatesAutoresizingMaskIntoConstraints = false
		return spinner
	}()

	private var initialNavigation: Bool = true

	private let checkoutURL: URL

	private lazy var closeBarButtonItem: UIBarButtonItem = {
		return UIBarButtonItem(
			barButtonSystemItem: .close, target: self, action: #selector(close)
		)
	}()

	// MARK: Initializers

	public init(checkoutURL url: URL, delegate: CheckoutDelegate? = nil) {
		self.checkoutURL = url
		self.delegate = delegate

		let checkoutView = CheckoutWebView.for(checkout: url)
		checkoutView.translatesAutoresizingMaskIntoConstraints = false
		checkoutView.scrollView.contentInsetAdjustmentBehavior = .never
		self.checkoutView = checkoutView

		super.init(nibName: nil, bundle: nil)

		title = "Checkout"

		navigationItem.rightBarButtonItem = closeBarButtonItem

		checkoutView.viewDelegate = self
	}

	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	// MARK: UIViewController Lifecycle

	override public func viewDidLoad() {
		super.viewDidLoad()

		view.backgroundColor = ShopifyCheckoutKit.configuration.backgroundColor

		view.addSubview(checkoutView)
		NSLayoutConstraint.activate([
			checkoutView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
			checkoutView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
			checkoutView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
			checkoutView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
		])

		view.addSubview(spinner)
		NSLayoutConstraint.activate([
			spinner.centerXAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerXAnchor),
			spinner.centerYAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerYAnchor)
		])
		view.bringSubviewToFront(spinner)

		if checkoutView.isLoading == false {
			self.displayNativePayButton()
		}

		loadCheckout()
	}

	private func displayNativePayButton() {
		let payButtonView = PayButtonView()
		payButtonView.tag = 1337
		payButtonView.translatesAutoresizingMaskIntoConstraints = false

		view.addSubview(payButtonView)

		NSLayoutConstraint.activate([
			payButtonView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
			payButtonView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
			payButtonView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
		])

		self.checkoutView.evaluateJavaScript("const style = document.createElement('style'); document.head.appendChild(style); style.appendChild(document.createTextNode('#checkout-sdk-pay-button-container { display: none !important; }'));")

		payButtonView.buttonPressedAction = {
			print("button pressed")
			self.checkoutView.evaluateJavaScript("window.MobileCheckoutSdk.dispatchMessage('submitPayment');")
		}
	}

	private func loadCheckout() {
		if checkoutView.url == nil {
			checkoutView.alpha = 0
			initialNavigation = true
			checkoutView.load(checkout: checkoutURL)
		} else if checkoutView.isLoading && initialNavigation {
			checkoutView.alpha = 0
			spinner.startAnimating()
		}
	}

	@IBAction internal func close() {
		didCancel()
	}

	public func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
		didCancel()
	}

	private func didCancel() {
		delegate?.checkoutDidCancel()
	}
}

extension CheckoutWebViewController: CheckoutWebViewDelegate {

	func checkoutViewDidStartNavigation() {
		if initialNavigation {
			spinner.startAnimating()
		}
	}

	func checkoutViewDidFinishNavigation() {
		spinner.stopAnimating()
		initialNavigation = false

		if ShopifyCheckoutKit.configuration.payButton.enabled {
			displayNativePayButton()
		}

		UIView.animate(withDuration: UINavigationController.hideShowBarDuration) { [weak checkoutView] in
			checkoutView?.alpha = 1
		}
	}

	func checkoutViewDidCompleteCheckout() {
		ConfettiCannon.fire(in: view)
		CheckoutWebView.invalidate()

		if ShopifyCheckoutKit.configuration.payButton.enabled {
			if let payButtonView = self.view.viewWithTag(1337) {
				payButtonView.removeFromSuperview()
			}
		}

		delegate?.checkoutDidComplete()
	}

	func checkoutViewDidFailWithError(error: CheckoutError) {
		CheckoutWebView.invalidate()
		delegate?.checkoutDidFail(error: error)
	}

	func checkoutViewDidClickLink(url: URL) {
		delegate?.checkoutDidClickLink(url: url)
	}

	func checkoutViewDidToggleModal(modalVisible: Bool) {
		guard let navigationController = self.navigationController else { return }
		navigationController.setNavigationBarHidden(modalVisible, animated: true)
	}
}
