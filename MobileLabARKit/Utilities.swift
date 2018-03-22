//
//  Utilities.swift
//  MobileLab3DKit
//
//  Created by Nien Lam on 3/16/18.
//  Copyright © 2018 Mobile Lab. All rights reserved.
//

import SceneKit


// Structure for cycling through a generic array of elements.
struct CycleArray<T> {
    private var array: [T]
    private var cycleIndex: Int
    
    var currentElement: T? {
        get { return array.count > 0 ? array[cycleIndex] : nil }
    }
    
    init(_ array: [T]) {
        self.array = array
        self.cycleIndex = 0
    }
    
    mutating func cycle() -> T?  {
        cycleIndex = cycleIndex + 1 == array.count ? 0 : cycleIndex + 1
        return currentElement
    }
}


// For loading animations with in collada model.
extension SCNAnimationPlayer {
    class func loadAnimation(fromSceneNamed sceneName: String) -> SCNAnimationPlayer {
        let scene = SCNScene( named: sceneName )!
        // find top level animation
        var animationPlayer: SCNAnimationPlayer! = nil
        scene.rootNode.enumerateChildNodes { (child, stop) in
            if !child.animationKeys.isEmpty {
                animationPlayer = child.animationPlayer(forKey: child.animationKeys[0])
                stop.pointee = true
            }
        }
        return animationPlayer
    }
}
