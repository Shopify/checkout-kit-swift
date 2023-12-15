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

class PayButtonView: UIView {
	private var button: UIButton!
	var buttonPressedAction: (() -> Void)?

	override init(frame: CGRect) {
		super.init(frame: frame)
		setupView()
	}

	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	private func setupView() {
		backgroundColor = ShopifyCheckoutKit.configuration.backgroundColor

		let border = UIView()
		border.backgroundColor = ShopifyCheckoutKit.configuration.borderColor
		border.autoresizingMask = [.flexibleWidth, .flexibleBottomMargin]
		border.frame = CGRect(x: 0, y: 0, width: frame.size.width, height: 1)
		addSubview(border)

		button = UIButton(type: .custom)
		button.setTitle("Pay now", for: .normal)
		button.setTitleColor(.white, for: .normal)
		button.titleLabel?.font = UIFont.boldSystemFont(ofSize: 18)
		button.backgroundColor = ShopifyCheckoutKit.configuration.spinnerColor
		button.layer.cornerRadius = 8
		button.contentEdgeInsets = UIEdgeInsets(top: 0, left: 21, bottom: 0, right: 21)
		button.layer.borderWidth = 1
		button.layer.borderColor = ShopifyCheckoutKit.configuration.borderColor.cgColor

		button.translatesAutoresizingMaskIntoConstraints = false
		addSubview(button)

		NSLayoutConstraint.activate([
			button.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 21),
			button.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -21),
			button.topAnchor.constraint(equalTo: topAnchor, constant: 18),
			button.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -32),
			button.heightAnchor.constraint(equalToConstant: 55)
		])

		button.addTarget(self, action: #selector(buttonTouchUp), for: .touchUpInside)
		button.addTarget(self, action: #selector(buttonTouchDown), for: .touchDown)
	}

	@objc private func buttonTouchUp() {
		buttonPressedAction?()

		UIView.animate(withDuration: 0.15, delay: 0.15, options: .curveEaseOut) {
			self.button.backgroundColor = UIColor(red: 23/255, green: 115/255, blue: 176/255, alpha: 1.0)
		}
	}

	@objc private func buttonTouchDown() {
		UIView.animate(withDuration: 0.15, delay: 0.0, options: .curveEaseOut) {
			self.button.backgroundColor = UIColor(red: 16/255, green: 89/255, blue: 137/255, alpha: 1.0)
		}
	}
}
