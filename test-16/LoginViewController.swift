//
//  File.swift
//  Flagship
//
//  Created by Likens, Dustin on 6/3/20.
//  Copyright © 2020 Steve Lundgren. All rights reserved.
//

import LocalAuthentication
import UIKit
import SafariServices
import MyChartLibrary

class MyChartLoginViewController: UIViewController, UITextFieldDelegate, IWPAuthenticationDelegate {
    
    // MARK: Properties
    
    var borderColor = UIColor(named: "gray5")?.cgColor
    var borderHighlightColor = UIColor(named: "primary2")?.cgColor
    var borderErrorColor = UIColor(named: "error1")?.cgColor
    var userDefaults = UserDefaults.standard
    var passcodeModal: PasscodeLoginViewController?
    var springboard: UIViewController?
    var loadingView: UIView?
    var pendingSignUp = false
    var defaultsObserver: NSObjectProtocol?
    
    // MARK: Outlets
    
    @IBOutlet weak var usernameTextField: UITextField!
    @IBOutlet weak var passwordTextField: UITextField!
    @IBOutlet weak var usernameLabel: UILabel!
    @IBOutlet weak var passwordLabel: UILabel!
    @IBOutlet weak var loginButton: UIButton!
    @IBOutlet weak var usernameErrorLabel: UILabel!
    @IBOutlet weak var passwordErrorLabel: UILabel!
    @IBOutlet weak var altLoginButton: UIButton!
    @IBOutlet weak var errorView: UIView!
    @IBOutlet weak var errorViewHeight: NSLayoutConstraint!
    
    @IBOutlet weak var errorMessage: UILabel!
    @IBOutlet weak var forgotUsernameButton: UIButton!
    @IBOutlet weak var forgotPasswordButton: UIButton!
    @IBOutlet weak var mychartHelpPhoneButton: UIButton!
    @IBOutlet weak var mychartHelpEmailButton: UIButton!
    @IBOutlet weak var headerLeading: NSLayoutConstraint!
    @IBOutlet weak var headerTrailing: NSLayoutConstraint!
    @IBOutlet weak var stackViewTrailing: NSLayoutConstraint!
    @IBOutlet weak var stackViewLeading: NSLayoutConstraint!
    @IBOutlet weak var signUpButton: UIButton!
    @IBOutlet weak var bannerView: UIView!
    @IBOutlet weak var bannerBody: UILabel!
    
    // MARK: Actions
    
    @IBAction func loginButtonClick(_ sender: Any) {
        passwordTextField.resignFirstResponder()
        usernameTextField.resignFirstResponder()
        
        userDefaults.set(self.usernameTextField.text, forKey: "username")
        
        login()
        
        recordEvent(type: .signin, properties: [.name: "Username/Password Sign In", .currentScreen: "Login"], flush: true)
    }

    @IBAction func signUpClicked(_ sender: Any) {
        dismissError()
        
        self.present(WPAPIPrelogin.getSignUpController(), animated: true, completion: nil)
        
        recordEvent(type: .click, properties: [.name: "Sign Up", .currentScreen: "Login"])
    }
    
    @IBAction func userNameRecoveryClicked(_ sender: Any) {
        dismissError()
        
        self.present(WPAPIPrelogin.getRecoverUsernameController(), animated: true, completion: nil)
        
        recordEvent(type: .signin, properties: [.name: "Forgot Username", .currentScreen: "Login"])
    }
    
    @IBAction func passwordRecoveryClicked(_ sender: Any) {
        dismissError()
        
        self.present(WPAPIPrelogin.getRecoverPasswordController(), animated: true, completion: nil)
        
        recordEvent(type: .signin, properties: [.name: "Forgot Password", .currentScreen: "Login"])
    }
    
    @IBAction func altIdButtonClicked(_ sender: Any) {
        if WPAPIAuthentication.isBiometricAuthenticationEnabled() {
            if let button = sender as? UIButton {
                if button.titleLabel?.text == touchIdLoginLabel {
                    recordEvent(type: .signin, properties: [.name: "Touch ID Sign In", .currentScreen: "Login"], flush: true)
                } else if button.titleLabel?.text == faceIdLoginLabel {
                    recordEvent(type: .signin, properties: [.name: "Face ID Sign In", .currentScreen: "Login"], flush: true)
                }
            }
            WPAPIAuthentication.login(withBiometricAuthentication: self)
        } else if WPAPIAuthentication.isPasscodeEnabled() {
            recordEvent(type: .signin, properties: [.name: "Passcode Sign In", .currentScreen: "Login"])
            guard let vc = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "PasscodeLoginViewController") as? PasscodeLoginViewController else { return }
            passcodeModal = vc
            vc.loginDelegate = self
            present(vc, animated: true, completion: nil)
        }
    }
    
    @IBAction func callMyChartHelp(_ sender: Any) {
        if let url = URL(string: "tel:/555-987-4444") {
            UIApplication.shared.open(url)
        }
        
        recordEvent(type: .click, properties: [.name: "MyChart Help Call", .currentScreen: "Login"])
    }
    
    @IBAction func emailMyChartHelp(_ sender: Any) {
        // TODO: Should this be hardcoded?
        self.presentEmailSelector(to: "mychart@google.org", subject: nil, body: nil, sourceView: sender as! UIView)
        
        recordEvent(type: .click, properties: [.name: "MyChart Help Email", .currentScreen: "Login"])
    }
    
    @IBAction func faqClicked(_ sender: Any) {
        if let url = URL(string: "https://mychart.google.org/Mychart/Authentication/Login?mode=stdfile&option=faq") {
            let vc = SFSafariViewController(url: url, configuration: SFSafariViewController.Configuration())
            present(vc, animated: true)
        }
        
        recordEvent(type: .click, properties: [.name: "MyChart FAQ", .currentScreen: "Login"])
    }
    
    @IBAction func bannerTapped(_ sender: Any) {
        let url = Settings.shared.zoomAppStoreUrl
        if UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
        }
    }
    
    // MARK: Private Methods
    
    private func presentError(message: String) {
        errorMessage.text = message
        
        errorViewHeight.constant = errorMessage.intrinsicContentSize.height + 10
        UIView.animate(
            withDuration: 0.7,
            delay: 0, options:
            UIView.AnimationOptions.curveEaseInOut,
            animations: {
                self.errorView.layer.opacity = 1
                self.errorView.isHidden = false
                self.view.layoutIfNeeded()
            },
            completion: nil
        )
    }
    
    private func dismissError() {
        if errorView.isHidden == false {
            errorViewHeight.constant = 0
            errorView.isHidden = true
        }
    }
    
    private func setupBanner() {
        if let endDate = Settings.shared.zoomEndDate {
            bannerBody.text = String(format: zoomBannerBody, endDate.formatted(date: .long, time: .omitted))
        }
        bannerBody.underlineLastWord()
        
        let leftBorder = CALayer()
        leftBorder.frame = CGRect(x: 0, y: 0, width: 6, height: bannerView.frame.height)
        leftBorder.backgroundColor = UIColor(named: "primary2")?.cgColor
        bannerView.layer.addSublayer(leftBorder)
    }
    
    // MARK: Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        errorView.layer.borderColor = UIColor(named: "error2")?.cgColor
        errorView.layer.borderWidth = 2
        errorView.layer.cornerRadius = 6
        errorViewHeight.constant = 0
        errorView.layer.opacity = 0
        errorView.isHidden = true
        
        self.usernameTextField.delegate = self
        self.passwordTextField.delegate = self
        
        userDefaults.set(false, forKey: "loggedIn")
        userDefaults.synchronize()
        
        for input in [usernameTextField, passwordTextField] {
            input?.borderStyle = .none
            input?.layer.masksToBounds = true
            input?.layer.borderWidth = 2
            input?.layer.borderColor = borderColor
            input?.layer.cornerRadius = 6
            input?.setLeftPadding(12)
            input?.setRightPadding(12)
        }
        passwordTextField.isSecureTextEntry = true
        
        loginButton.layer.masksToBounds = true
        loginButton.layer.cornerRadius = 6
        
        let tap: UITapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(UIInputViewController.dismissKeyboard))
        //Uncomment the line below if you want the tap not not interfere and cancel other interactions.
        //tap.cancelsTouchesInView = false
        view.addGestureRecognizer(tap)
        
        mychartHelpEmailButton.titleLabel?.adjustsFontSizeToFitWidth = true
        
        mychartHelpEmailButton.isHidden = true
        
        defaultsObserver = NotificationCenter.default.addObserver(forName: UserDefaults.didChangeNotification, object: nil, queue: .main) { [unowned self] notification in
            flexForSharedDevices()
        }
        
        recordEvent(type: .screen, properties: [.name: "Login"])
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        clearErrorState()
        
        self.navigationController?.setNavigationBarHidden(true, animated: true)
        self.tabBarController?.tabBar.isHidden = false
        
        self.updateAltLoginButton()
        if altLoginButton.isHidden == false, userDefaults.object(forKey: "loggedIn") as! Bool == false {
            if altLoginButton.titleLabel?.text != passcodeLoginLabel {
                altIdButtonClicked(altLoginButton)
            } else {
                // Make sure the modal isn't currently dismissing
                if (passcodeModal?.isBeingDismissed == false || passcodeModal == nil)
                    && springboard == nil
                    && userDefaults.object(forKey: "hasSignedIntoMychart") as? Bool == true {
                            altIdButtonClicked(altLoginButton)
                }
            }
        }
        
        self.usernameTextField.text = userDefaults.object(forKey: "username") as! String?
        self.passwordTextField.text = ""
        
        if self.pendingSignUp == true {
            self.present(WPAPIPrelogin.getSignUpController(), animated: true, completion: nil)
            self.pendingSignUp = false
        }
        
        springboard = nil
        
        forgotUsernameButton.titleLabel?.adjustsFontSizeToFitWidth = true
        forgotUsernameButton.titleLabel?.minimumScaleFactor = 0.5
        forgotUsernameButton.titleLabel?.numberOfLines = 2
        
        forgotPasswordButton.titleLabel?.adjustsFontSizeToFitWidth = true
        forgotPasswordButton.titleLabel?.minimumScaleFactor = 0.5
        forgotPasswordButton.titleLabel?.numberOfLines = 2
        
        recordEvent(type: .screen, properties: [.name: "Login"])
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        flexForSharedDevices()
    }

    private func flexForSharedDevices() {
        let sharedDevice = userDefaults.bool(forKey: "sharedDevice")
        for view in [usernameLabel, passwordLabel, usernameTextField, passwordTextField, forgotUsernameButton, forgotPasswordButton, signUpButton, loginButton] {
            view?.layer.opacity = sharedDevice ? 0.5 : 1
            view?.isUserInteractionEnabled = !sharedDevice
        }
        if sharedDevice {
            presentError(message: sharedDeviceExplanation)
        } else {
            dismissError()
        }
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if UIDevice.current.userInterfaceIdiom == .pad {
            let screenWidth = UIScreen.main.bounds.width
            let padding = (screenWidth - 480) / 2
            headerLeading.constant = padding
            headerTrailing.constant = padding
            stackViewLeading.constant = padding
            stackViewTrailing.constant = padding
        }
        
        if UIScreen.main.bounds.width <= 320 {
            forgotUsernameButton.titleLabel?.font = forgotUsernameButton.titleLabel?.font.withSize(15)
            forgotPasswordButton.titleLabel?.font = forgotPasswordButton.titleLabel?.font.withSize(15)
        }
        
        setupBanner()
    }
    
    // MARK: login/logout
    
    func logout() {
        Task { await WPAPIAuthentication.logout() }
    }
    
    func login() {
        dismissError()
        
        usernameErrorLabel.isHidden = true
        passwordErrorLabel.isHidden = true
        
        usernameTextField.layer.borderColor = borderColor
        passwordTextField.layer.borderColor = borderColor
        
        if (usernameTextField.text == "") {
            usernameTextField.layer.borderColor = borderErrorColor
            usernameErrorLabel.text = myChartUsernameError
            usernameErrorLabel.isHidden = usernameTextField.text != ""
        }
        
        if (passwordTextField.text == "") {
            passwordTextField.layer.borderColor = borderErrorColor
            passwordErrorLabel.text = myChartPasswordError
            passwordErrorLabel.isHidden = passwordTextField.text != ""
        }
        
        if (usernameTextField.text == "" || passwordTextField.text == "") {
            return
        }

        //Disable login button during login to prevent multiple requests
        loginButton.isEnabled = false
        
        self.showLoadingView(loadingText: "\(signingInStr)...")
        
        // Delay login by 2 seconds if network unavailable
        let delay = !Reachability.isConnectedToNetwork() ? 2.0 : 0.0
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self = self else { return }
            setAnalyticsFilesImmutable(true)
            WPAPIAuthentication.login(withUsername: self.usernameTextField.text!, password: self.passwordTextField.text!, delegate: self)
        }
    }
    
    func showSpringboard(with deepLink: IWPDeepLink?) {
        passcodeModal?.dismissError()
        if let vc = WPAPIHomepage.getControllerThatManagesNavbarVisibility(true, withDeepLink: deepLink) {
            navigationController?.pushViewController(vc, animated: deepLink == nil)
            passcodeModal?.dismiss(animated: false, completion: nil)
            if let navBar = vc.navigationController?.navigationBar {
                let appearance = UINavigationBarAppearance()
                appearance.backgroundColor = UIColor(hexString: "0081A2")
                appearance.titleTextAttributes = [.foregroundColor: UIColor.white]
                appearance.largeTitleTextAttributes = [.foregroundColor: UIColor.white]
                navBar.standardAppearance = appearance
                navBar.compactAppearance = appearance
                navBar.scrollEdgeAppearance = appearance
                navBar.tintColor = .white
            }
        }
    }
    
    @objc func dismissKeyboard() {
        view.endEditing(true)
        UIApplication.shared.sendAction(#selector(UIApplication.resignFirstResponder), to: nil, from: nil, for: nil)
    }
    
    func conditionallyPresentPasscodeModal() {
        if WPAPIAuthentication.isPasscodeEnabled()
            && WPAPIUserManager.getAuthenticationStatus() == .notAuthenticated
            && WPAPIAuthentication.isBiometricAuthenticationEnabled() == false
            && (passcodeModal?.isBeingDismissed == false || passcodeModal == nil)
            && springboard == nil
            && userDefaults.object(forKey: "hasSignedIntoMychart") as? Bool == true
        {
            guard let vc = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "PasscodeLoginViewController") as? PasscodeLoginViewController else { return }
            passcodeModal = vc
            vc.loginDelegate = self
            present(vc, animated: false, completion: nil)
        }
    }
    
    //MARK: IWPAuthenticationDelegate
    
    func loginSucceeded(withDeepLink deepLink: IWPDeepLink?) {
        recordEvent(type: .signin, properties: [.name: "Sign In Succeeded", .currentScreen: "Login"], flush: true)
        
        let notificationCenter = UNUserNotificationCenter.current()
        notificationCenter.requestAuthorization(options: [.alert, .sound, .badge]) { (granted, error) in
            if granted {
                DispatchQueue.main.async {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            }
        }
        
        userDefaults.set(true, forKey: "loggedIn")
        userDefaults.set(true, forKey: "hasSignedIntoMychart")
        userDefaults.synchronize()
        
        DispatchQueue.main.async {
            self.usernameTextField.text = ""
            self.passwordTextField.text = ""
            self.loginButton.isEnabled = true
            self.showSpringboard(with: deepLink)
            self.dismissLoadingView()
        }
    }
    
    func loginFailed(withError error: Error) {
        self.loginButton.isEnabled = true
        
        DispatchQueue.main.async {
            self.updateAltLoginButton()
            self.dismissLoadingView()
        }
        
        let loginError = error as NSError
        switch(loginError.code) {
            case WPAPILoginResult.genericError.rawValue:
                usernameErrorLabel.text = myChartLoginCheckEntry
                passwordErrorLabel.text = myChartLoginCheckEntry

                usernameErrorLabel.isHidden = false
                passwordErrorLabel.isHidden = false

                usernameTextField.layer.borderColor = borderErrorColor
                passwordTextField.layer.borderColor = borderErrorColor
            case WPAPILoginResult.maxPasswordExceededCanReset.rawValue:
                // redirect user to reset their password if they have exceed the max number of password attempts
                self.present(WPAPIPrelogin.getResetPasswordControllerOnMaxPasswordAttemptsExceeded(), animated: true, completion: nil)
            case WPAPILoginResult.userCanceled.rawValue:
                // This is when the user cancels the secondary login dialog. Don't want to show errors on the fields
                // because nothing has been entered, they just canceled the action.
                usernameErrorLabel.isHidden = true
                passwordErrorLabel.isHidden = true
            case WPAPILoginResult.passcodeNotSet.rawValue:
                passcodeModal?.presentError(message: error.localizedDescription)
            case WPAPILoginResult.termsAndConditionsFailed.rawValue:
                clearErrorState()
            default:
            DispatchQueue.main.async { [self] in
                    //Check error.code against the defined failure codes in WPAPIAuthentication for error reasons.
                    //For easy debugging, just showing the localized failure reason here.
                    if passcodeModal != nil && presentedViewController == self.passcodeModal {
                        self.passcodeModal?.presentError(message: error.localizedDescription)
                    } else {
                        self.presentError(message: error.localizedDescription)
                    }
                }
        }
        
        self.dismissLoadingView()
        
        recordEvent(type: .signin, properties: [
            .name: "Sign In Failed",
            .errorMessage: loginError.localizedDescription,
            .errorCode: loginError.code,
            .currentScreen: "Login"
        ])
    }
    
    // MARK: Instance methods
    
    func getPresentationViewController() -> UIViewController {
        return passcodeModal ?? self
    }

    func updateAltLoginButton() {
        altLoginButton.isHidden = true
        
        if WPAPIAuthentication.isBiometricAuthenticationEnabled() {
            let context = LAContext()
            var authError: NSError?

            if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &authError) {
                altLoginButton.isHidden = false
                let title = context.biometryType == LABiometryType.touchID ? touchIdLoginLabel : faceIdLoginLabel
                altLoginButton.setTitle(title, for: .normal)
            }
        } else {
            if WPAPIAuthentication.isPasscodeEnabled() {
                altLoginButton.isHidden = false
                altLoginButton.setTitle(passcodeLoginLabel, for: .normal)
            }
        }
    }
    
    func clearErrorState() {
        usernameErrorLabel.isHidden = true
        passwordErrorLabel.isHidden = true
        
        usernameTextField.layer.borderColor = borderColor
        passwordTextField.layer.borderColor = borderColor
    }
    
    // MARK: textfield delegate methods
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        if (textField == self.usernameTextField) {
            self.passwordTextField.becomeFirstResponder()
        } else if (textField == self.passwordTextField) {
            login()
        }
        return false;
    }
    
    func textFieldDidBeginEditing(_ textField: UITextField) {
        if (textField == usernameTextField) {
            usernameErrorLabel.isHidden = true
        }
        else if (textField == passwordTextField) {
            passwordErrorLabel.isHidden = true
        }
        textField.layer.borderColor = borderHighlightColor
    }
    
    func textFieldDidEndEditing(_ textField: UITextField) {
        textField.layer.borderColor = borderColor
    }
    
    deinit {
        // TODO: What's the difference?
        NotificationCenter.default.removeObserver(self)
        NotificationCenter.default.removeObserver(defaultsObserver as Any)
    }
}
