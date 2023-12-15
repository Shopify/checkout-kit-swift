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

protocol CheckoutWebViewDelegate: AnyObject {
	func checkoutViewDidStartNavigation()
	func checkoutViewDidCompleteCheckout()
	func checkoutViewDidFinishNavigation()
	func checkoutViewDidClickLink(url: URL)
	func checkoutViewDidFailWithError(error: CheckoutError)
	func checkoutViewDidToggleModal(modalVisible: Bool)
}

class CheckoutWebView: WKWebView {

	private static var cache: CacheEntry?

	static func `for`(checkout url: URL) -> CheckoutWebView {
		guard ShopifyCheckoutKit.configuration.preloading.enabled else {
			CheckoutWebView.cache = nil
			return CheckoutWebView()
		}

		let cacheKey = url.absoluteString

		guard let cache = cache, cacheKey == cache.key, !cache.isStale else {
			let view = CheckoutWebView()
			CheckoutWebView.cache = CacheEntry(key: cacheKey, view: view)
			return view
		}

		return cache.view
	}

	static func invalidate() {
		cache = nil
	}

	// MARK: Properties

	weak var viewDelegate: CheckoutWebViewDelegate?

	// MARK: Initializers

	override init(frame: CGRect, configuration: WKWebViewConfiguration) {
		configuration.applicationNameForUserAgent = CheckoutBridge.applicationName

		super.init(frame: frame, configuration: configuration)

		#if DEBUG
			if #available(iOS 16.4, *) {
				isInspectable = true
			}
		#endif

		navigationDelegate = self
	}

	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	// MARK: -

	override func didMoveToSuperview() {
		super.didMoveToSuperview()

		configuration.userContentController
			.removeScriptMessageHandler(forName: CheckoutBridge.messageHandler)

		if superview != nil {
			configuration.userContentController
				.add(self, name: CheckoutBridge.messageHandler)
		}
	}

	func load(checkout url: URL) {
		load(URLRequest(url: url))
	}
}

extension CheckoutWebView: WKScriptMessageHandler {
	func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
		do {
			switch try CheckoutBridge.decode(message) {
			case .checkoutComplete:
				CheckoutWebView.cache = nil
				viewDelegate?.checkoutViewDidCompleteCheckout()
			case .checkoutUnavailable:
				CheckoutWebView.cache = nil
				viewDelegate?.checkoutViewDidFailWithError(error: .checkoutUnavailable(message: "Checkout unavailable."))
			case let .checkoutModalToggled(modalVisible):
				viewDelegate?.checkoutViewDidToggleModal(modalVisible: modalVisible)
			default:
				()
			}
		} catch {
			viewDelegate?.checkoutViewDidFailWithError(error: .sdkError(underlying: error))
		}
	}
}

private var timer: Date?

extension CheckoutWebView: WKNavigationDelegate {
	func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {

		guard let url = action.request.url else {
			decisionHandler(.allow)
			return
		}

		if isExternalLink(action) || isMailOrTelLink(url) {
			viewDelegate?.checkoutViewDidClickLink(url: removeExternalParam(url))
			decisionHandler(.cancel)
			return
		}

		decisionHandler(.allow)
	}

	func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse, decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
		if let response = navigationResponse.response as? HTTPURLResponse {
			decisionHandler(handleResponse(response))
			return
		}
		decisionHandler(.allow)
	}

	func handleResponse(_ response: HTTPURLResponse) -> WKNavigationResponsePolicy {
		if isCheckout(url: response.url) && response.statusCode >= 400 {
			CheckoutWebView.cache = nil
			switch response.statusCode {
			case 410:
				viewDelegate?.checkoutViewDidFailWithError(error: .checkoutExpired(message: "Checkout has expired"))
			case 404:
				viewDelegate?.checkoutViewDidFailWithError(error: .checkoutLiquidNotMigrated(message: "The checkout url provided has resulted in an error. The store is still using checkout.liquid, whereas the checkout SDK only supports checkout with extensibility."))
			case 500:
				viewDelegate?.checkoutViewDidFailWithError(error: .checkoutUnavailable(message: "Checkout unavailable due to error"))
			default:
				()
			}

			return .cancel
		}

		return .allow
	}

	func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
		timer = Date()
		viewDelegate?.checkoutViewDidStartNavigation()
	}

	func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
		timer = nil
	}

	func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
		viewDelegate?.checkoutViewDidFinishNavigation()

		if let startTime = timer {
			let endTime = Date()
			let diff = endTime.timeIntervalSince(startTime)
			let preloading = String(ShopifyCheckoutKit.Configuration().preloading.enabled)
			let message = "Preloaded checkout in \(String(format: "%.2f", diff))s"
			ShopifyCheckoutKit.configuration.logger.log(message)
			CheckoutBridge.instrument(self, InstrumentationPayload(name: "checkout_finished_loading", value: Int(diff * 1000), type: .histogram, tags: ["preloading": preloading]))
		}

		timer = nil
	}

	func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
		timer = nil
		CheckoutWebView.cache = nil
		viewDelegate?.checkoutViewDidFailWithError(error: .sdkError(underlying: error))
	}

	private func isExternalLink(_ action: WKNavigationAction) -> Bool {
		if action.navigationType == .linkActivated && action.targetFrame == nil { return true }

		guard let url = action.request.url else { return false }
		guard let url = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return false }

		guard let openExternally = url.queryItems?.first(where: { $0.name == "open_externally" })?.value else { return false }

		return openExternally.lowercased() == "true" || openExternally == "1"
	}

	private func removeExternalParam(_ url: URL) -> URL {
		guard var urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
			return url
		}
		urlComponents.queryItems = urlComponents.queryItems?.filter { !($0.name == "open_externally") }
		return urlComponents.url ?? url
	}

	private func isMailOrTelLink(_ url: URL) -> Bool {
		return ["mailto", "tel"].contains(url.scheme)
	}

	private func isCheckout(url: URL?) -> Bool {
		return self.url == url
	}

}

extension CheckoutWebView {
	fileprivate struct CacheEntry {
		let key: String

		let view: CheckoutWebView

		private let timestamp = Date()

		private let timeout = TimeInterval(60 * 5)

		var isStale: Bool {
			abs(timestamp.timeIntervalSinceNow) >= timeout
		}
	}
}
