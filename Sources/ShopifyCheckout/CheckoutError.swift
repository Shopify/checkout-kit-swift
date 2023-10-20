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

/// A type representing Shopify Checkout specific errors.
public enum CheckoutError: Swift.Error {
	/// Issued when an internal error within Shopify Checkout SDK
	/// In event of an sdkError you could use the stacktrace to inform you of how to proceed,
	/// if the issue persists, it is recommended to open a bug report in http://github.com/Shopify/mobile-checkout-sdk-ios
	case sdkError(underlying: Swift.Error)

	/// Issued when checkout has encountered a unrecoverable error (for example server side error)
	/// if the issue persists, it is recommended to open a bug report in http://github.com/Shopify/mobile-checkout-sdk-ios
	case checkoutUnavailable(message: String)

	/// Issued when checkout is no longer available and will no longer be available with the checkout url supplied.
	/// This may happen when the user has paused on checkout for a long period (hours) and then attempted to proceed again with the same checkout url
	/// In event of checkoutExpired, a new checkout url will need to be generated
	case checkoutExpired(message: String)
}

enum Constants {
	static let defaultCheckoutExpiredMsg = "Checkout expired. Checkout needs to be reinitialised"
	static let defaultCheckoutUnavailableMsg = "Checkout unavailable due to error"
}
