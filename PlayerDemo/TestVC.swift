//
//  TestVC.swift
//  PlayerDemo
//
//  Created by Easer Liu on 2020/1/19.
//  Copyright © 2020 EasyGoing. All rights reserved.
//

import Foundation
class TestVC: UIViewController {
    var m3u8: m3u8Test?
    override func viewDidLoad() {
        super.viewDidLoad()
        m3u8 = m3u8Test();
        let mgr = MtkMgr.shared();
        mgr.m3u8T = m3u8!;
        var url = Bundle.main.url(forResource: "123", withExtension: "png")!
//        url = Bundle.main.url(forResource: "timg", withExtension: "jpeg")!
        url = Bundle.main.url(forResource: "video", withExtension: "mp4")!
        
//        url = Bundle.main.url(forResource: "Image", withExtension: "tga")!
        mgr.displayImageFile(url)
//        mgr.mtkView.frame = CGRect(x: self.view.bounds.size.width * 0.25, y: self.view.bounds.size.height * 0.25, width: self.view.bounds.size.width * 0.5, height: self.view.bounds.size.height * 0.5);
        mgr.mtkView.frame = self.view.bounds;
        self.view.addSubview(mgr.mtkView);
    }
}
