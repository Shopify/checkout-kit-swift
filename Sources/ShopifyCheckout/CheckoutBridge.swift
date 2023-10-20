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

import WebKit

enum CheckoutBridge {
	static let schemaVersion = "5.1"

	static let messageHandler = "mobileCheckoutSdk"

	static var applicationName: String {
		let theme = ShopifyCheckout.configuration.colorScheme.rawValue
		return "ShopifyCheckoutSDK/\(ShopifyCheckout.version) (\(schemaVersion);\(theme))"
	}

	static func decode(_ message: WKScriptMessage) throws -> WebEvent {
		guard let body = message.body as? String, let data = body.data(using: .utf8) else {
			throw Error.invalidBridgeEvent()
		}

		do {
			return try JSONDecoder().decode(WebEvent.self, from: data)
		} catch {
			throw Error.invalidBridgeEvent(error)
		}
	}
}

extension CheckoutBridge {
	enum Error: Swift.Error {
		case invalidBridgeEvent(Swift.Error? = nil)
	}
}

extension CheckoutBridge {
	enum WebEvent: Decodable {
		case checkoutComplete
		case checkoutCanceled
		case checkoutExpired(String)
		case checkoutUnavailable(String)
		case unsupported(String)

		enum CodingKeys: String, CodingKey {
			case name
			case body
		}

		init(from decoder: Decoder) throws {
			let container = try decoder.container(keyedBy: CodingKeys.self)
			let name = try container.decode(String.self, forKey: .name)

			switch name {
			case "completed":
				self = .checkoutComplete
			case "close":
				self = .checkoutCanceled
			case "error":
				let errorPayloads = try container.decode([ErrorPayload].self, forKey: .body)
				let errorMessage = errorPayloads.first?.reason ?? Constants.defaultCheckoutUnavailableMsg
				guard let errorGroup = errorPayloads.first?.group else {
					self = .checkoutUnavailable(errorMessage)
					return
				}

				switch errorGroup {
				case ErrorGroup.internal:
					self = .checkoutExpired(Constants.defaultCheckoutExpiredMsg)
				default:
					self = .checkoutUnavailable(errorMessage)
				}
			default:
				self = .unsupported(name)
			}
		}
	}
}

class ErrorPayload: Decodable {
	var flowType: FlowType
	var group: ErrorGroup
	var type: ErrorType
	var code: String?
	var reason: String?

	init(flowType: FlowType, group: ErrorGroup, type: ErrorType, code: String? = nil, reason: String? = nil) {
		self.flowType = flowType
		self.group = group
		self.type = type
		self.code = code
		self.reason = reason
	}
}

enum FlowType: String, Decodable {
	case regular
	case shopPay
	case shopPayLogin
	case checkoutDefaults
	case applePay
	case googlePay
	case payPal
	case amazonPay
	case facebookPay
	case shopifyInstallments
}

enum ErrorGroup: String, Decodable {
	case `internal`
	case violation
	case checkout
	case vaultedPayment
	case defaults
	case authentication
	case unrecoverable
}

enum ErrorType: String, Decodable {
	case inventory
	case payment
	case other
	case discount
	case order
	case customerPersistence
	case checkoutBlocking
}
