//
//  GameViewController.swift
//  SpaceBattle
//
//  Created by Macbook on 2/5/20.
//  Copyright © 2020 Macbook. All rights reserved.
//

import UIKit
import SpriteKit
import GameplayKit

class GameViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        
        let scene = GameScene(size: view.bounds.size)
        let view = self.view as! SKView
        // Load the SKScene from 'GameScene.sks'
        // Set the scale mode to scale to fit the window
        scene.scaleMode = .aspectFill
                
        // Present the scene
        view.presentScene(scene)
            
        view.ignoresSiblingOrder = true
            
        //view.showsFPS = true
        //view.showsNodeCount = true
    }

    override var shouldAutorotate: Bool {
        return true
    }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        if UIDevice.current.userInterfaceIdiom == .phone {
            return .allButUpsideDown
        } else {
            return .all
        }
    }

    override var prefersStatusBarHidden: Bool {
        return true
    }
}
