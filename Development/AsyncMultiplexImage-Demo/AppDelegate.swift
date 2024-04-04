//
//  AppDelegate.swift
//  SwiftUIBook
//
//  Created by muukii on 2019/07/29.
//  Copyright © 2019 muukii. All rights reserved.
//
import UIKit
import SwiftUI

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
  
  var window: UIWindow?
  
  func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
    // Override point for customization after application launch.
    
    let window = UIWindow()
    
    let controller = UIHostingController(rootView: ContentView())
    
    window.rootViewController = controller
    self.window = window
    
    window.makeKeyAndVisible()
        
    return true
  }
   
}
