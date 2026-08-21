//
//  SceneDelegate.swift
//  Tracker
//
//  Created by User on 20.03.2025.
//

import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    
    var window: UIWindow?
    
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        
        guard let windowScene = (scene as? UIWindowScene) else { return }
        
        window = UIWindow(windowScene: windowScene)
        
        if isFirstLaunch() {
            showOnboardingScreen()
        } else {
            showMainAppScreen()
        }
        
        window?.makeKeyAndVisible()
    }
    
    private func isFirstLaunch() -> Bool {
        return !UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
    }
    
    private func showOnboardingScreen() {
        let onboardingVC = OnboardingPageViewController()
        window?.rootViewController = onboardingVC
    }
    
    private func showMainAppScreen() {
        let tabBarController = TabBarController()
        window?.rootViewController = tabBarController
    }
    
    func completeOnboarding() {
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
    }
    
    func changeRootViewController(_ vc: UIViewController, animated: Bool = true) {
        guard let window = self.window else { return }
        
        if animated {
            UIView.transition(with: window,
                              duration: 0.5,
                              options: .transitionFlipFromRight,
                              animations: {
                window.rootViewController = vc
            },
                              completion: nil)
        } else {
            window.rootViewController = vc
        }
    }
}

