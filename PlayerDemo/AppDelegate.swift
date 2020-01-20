//
//  AppDelegate.swift
//  PlayerDemo
//
//  Created by Easer Liu on 2019/12/27.
//  Copyright © 2019 EasyGoing. All rights reserved.
//

import UIKit

import AVKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        
        // Override point for customization after application launch.
//        let audioSession = AVAudioSession.sharedInstance()
//        do {
//            try audioSession.setCategory(.playback, mode: .moviePlayback)
//        }
//        catch {
//            print("Setting category to AVAudioSessionCategoryPlayback failed.")
//        }
        
        var controller = TestVC()
//        var controller = MTKManager()
                
        //        let url = URL(string: "https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_adv_example_hevc/master.m3u8")!
        //        // Create an AVPlayer, passing it the HTTP Live Streaming URL.
        //        let player = AVPlayer(url: url)
        //
        //        // Create a new AVPlayerViewController and pass it a reference to the player.
        //        let controller = AVPlayerViewController()
        //        controller.player = player
        //        player.play()
                
                
                
                // Use a UIHostingController as window root view controller.
                let window = UIWindow()
                //            window.rootViewController = UIHostingController(rootView: contentView)
                        window.rootViewController = controller
                            self.window = window
                            window.makeKeyAndVisible()
        
        return true
    }

    // MARK: UISceneSession Lifecycle

//    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
//        // Called when a new scene session is being created.
//        // Use this method to select a configuration to create the new scene with.
//        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
//    }
//
//    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
//        // Called when the user discards a scene session.
//        // If any sessions were discarded while the application was not running, this will be called shortly after application:didFinishLaunchingWithOptions.
//        // Use this method to release any resources that were specific to the discarded scenes, as they will not return.
//    }


}

