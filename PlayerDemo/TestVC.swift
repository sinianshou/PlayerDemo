//
//  TestVC.swift
//  PlayerDemo
//
//  Created by Easer Liu on 2020/1/19.
//  Copyright © 2020 EasyGoing. All rights reserved.
//

import Foundation
class TestVC: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        let mgr = MtkMgr.shared();
        var url = Bundle.main.url(forResource: "123", withExtension: "png")!
        url = Bundle.main.url(forResource: "timg", withExtension: "jpeg")!
//        url = Bundle.main.url(forResource: "Image", withExtension: "tga")!
        mgr.displayImageFile(url)
        mgr.mtkView.frame = self.view.bounds;
        self.view.addSubview(mgr.mtkView);
    }
}
