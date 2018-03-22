//
//  ViewController.swift
//  MobileLabARKit
//
//  Created by Nien Lam on 3/21/18.
//  Copyright © 2018 Mobile Lab. All rights reserved.
//

import UIKit
import SceneKit
import ARKit

let ModelAssets: [(name: String, nodeName: String)] = [
    ("Ship",  "shipMesh"),
    ("Orange",  "orange"),
    ("2D Plane", "plane"),
    ("Box", "box")]


class ViewController: UIViewController, ARSCNViewDelegate, ARSessionDelegate {

    @IBOutlet var sceneView: ARSCNView!

    @IBOutlet weak var sessionInfoView: UIView!
    @IBOutlet weak var modeAssetButtonView: UIView!
    @IBOutlet weak var undoButtonView: UIView!
    @IBOutlet weak var sessionInfoLabel: UILabel!
    @IBOutlet weak var modelAssetButton: UIButton!

    // Structure for cycling through model assets.
    var modelAssets = CycleArray(ModelAssets)
    
    var currentModelAsset: SCNNode!

    var modelsInScene = [SCNNode]()
    
    var isMenuHidden = false
    
    var mainScene: SCNScene!

    var modelAssetScene: SCNScene!


    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Set the view's delegate
        sceneView.delegate = self
        
        // Show statistics such as fps and timing information
        sceneView.showsStatistics = false

        mainScene = SCNScene(named: "art.scnassets/main_scene.scn")!

        // Scene for model assets.
        modelAssetScene = SCNScene(named: "art.scnassets/model_asset_scene.scn")!
        
        currentModelAsset = modelAssetScene.rootNode.childNode(withName: modelAssets.currentElement!.nodeName, recursively: true)
        
        // Set the scene to the view
        sceneView.scene = mainScene

        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        sceneView.addGestureRecognizer(tapGesture)


        modelAssetButton.setTitle(modelAssets.currentElement!.name, for: .normal)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        // Check if ARKit is supported on device.
        checkARKitSupport()
        
        // Start the view's AR session with a configuration that uses the rear camera,
        // device position and orientation tracking, and plane detection.
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.horizontal]
        sceneView.session.run(configuration)
        
        // Set a delegate to track the number of plane anchors for providing UI feedback.
        sceneView.session.delegate = self
        
        // Prevent the screen from being dimmed after a while as users will likely
        // have long periods of interaction without touching the screen or buttons.
        UIApplication.shared.isIdleTimerDisabled = true
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Pause the view's session
        sceneView.session.pause()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Release any cached data, images, etc that aren't in use.
    }

    
    @objc
    func handleTap(_ recognizer: UITapGestureRecognizer) {
        let location = recognizer.location(in: sceneView)
        
        // When tapped on the object, call the object's method to react on it
        let sceneHitTestResult = sceneView.hitTest(location, options: nil)
        if !sceneHitTestResult.isEmpty {
            print("Hit Object")
            return
        }
        
        // When tapped on a plane, reposition the content
//        let arHitTestResult = sceneView.hitTest(location, types: .existingPlane)
//        if !arHitTestResult.isEmpty {
//            let hit = arHitTestResult.first!
//            node.position = SCNVector3Make(hit.worldTransform.columns.3.x,
//                                           hit.worldTransform.columns.3.y,
//                                           hit.worldTransform.columns.3.z)
//        }
        
        
        guard let currentFrame = sceneView.session.currentFrame else {
            return
        }
        
        var translation = matrix_identity_float4x4
        translation.columns.3.z = -0.1

        let modelAsset = currentModelAsset.clone() as SCNNode

        let currentScale = modelAsset.simdScale
        modelAsset.simdTransform = matrix_multiply(currentFrame.camera.transform, translation)
        modelAsset.simdScale = currentScale
        
        sceneView.scene.rootNode.addChildNode(modelAsset);
        
        modelsInScene.append(modelAsset)
    }
    
    
    @IBAction func handleModelAssetButton(_ sender: UIButton) {
        
        let modelAsset = modelAssets.cycle()!
        
        currentModelAsset = modelAssetScene.rootNode.childNode(withName: modelAsset.nodeName, recursively: true)
    
        sender.setTitle(modelAsset.name, for: .normal)
    }
    
    @IBAction func handleUndoButton(_ sender: UIButton) {
        if let lastModel = modelsInScene.popLast() {
            lastModel.removeFromParentNode()
        }
    }
    
    @IBAction func handleToggleMenuButton(_ sender: UIButton) {
        isMenuHidden = !isMenuHidden

        sessionInfoView.isHidden = isMenuHidden
        modeAssetButtonView.isHidden = isMenuHidden
        undoButtonView.isHidden = isMenuHidden
    }
    
    // MARK: - ARSCNViewDelegate
    
    /// - Tag: PlaceARContent
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        // Place content only for anchors found by plane detection.
        guard let planeAnchor = anchor as? ARPlaneAnchor else { return }
        
        // Create a SceneKit plane to visualize the plane anchor using its position and extent.
        let plane = SCNPlane(width: CGFloat(planeAnchor.extent.x), height: CGFloat(planeAnchor.extent.z))
        let planeNode = SCNNode(geometry: plane)
        planeNode.simdPosition = float3(planeAnchor.center.x, 0, planeAnchor.center.z)
        
        /*
         `SCNPlane` is vertically oriented in its local coordinate space, so
         rotate the plane to match the horizontal orientation of `ARPlaneAnchor`.
         */
        planeNode.eulerAngles.x = -.pi / 2
        
        // Make the plane visualization semitransparent to clearly show real-world placement.
        planeNode.opacity = 0.25
        
        planeNode.name = "anchor"
        
        /*
         Add the plane visualization to the ARKit-managed node so that it tracks
         changes in the plane anchor as plane estimation continues.
         */
        node.addChildNode(planeNode)
    }
    
    /// - Tag: UpdateARContent
    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        // Update content only for plane anchors and nodes matching the setup created in `renderer(_:didAdd:for:)`.
        guard let planeAnchor = anchor as?  ARPlaneAnchor,
            let planeNode = node.childNodes.first,
            let plane = planeNode.geometry as? SCNPlane
            else { return }
        
        // Plane estimation may shift the center of a plane relative to its anchor's transform.
        planeNode.simdPosition = float3(planeAnchor.center.x, 0, planeAnchor.center.z)
        
        /*
         Plane estimation may extend the size of the plane, or combine previously detected
         planes into a larger one. In the latter case, `ARSCNView` automatically deletes the
         corresponding node for one plane, then calls this method to update the size of
         the remaining plane.
         */
        plane.width = CGFloat(planeAnchor.extent.x)
        plane.height = CGFloat(planeAnchor.extent.z)
    }
    
    // MARK: - ARSessionDelegate
    
    func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
        guard let frame = session.currentFrame else { return }
        updateSessionInfoLabel(for: frame, trackingState: frame.camera.trackingState)
    }
    
    func session(_ session: ARSession, didRemove anchors: [ARAnchor]) {
        guard let frame = session.currentFrame else { return }
        updateSessionInfoLabel(for: frame, trackingState: frame.camera.trackingState)
    }
    
    func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) {
        updateSessionInfoLabel(for: session.currentFrame!, trackingState: camera.trackingState)
    }
    
    // MARK: - ARSessionObserver
    
    func sessionWasInterrupted(_ session: ARSession) {
        // Inform the user that the session has been interrupted, for example, by presenting an overlay.
        sessionInfoLabel.text = "Session was interrupted"
    }
    
    func sessionInterruptionEnded(_ session: ARSession) {
        // Reset tracking and/or remove existing anchors if consistent tracking is required.
        sessionInfoLabel.text = "Session interruption ended"
        resetTracking()
    }
    
    func session(_ session: ARSession, didFailWithError error: Error) {
        // Present an error message to the user.
        sessionInfoLabel.text = "Session failed: \(error.localizedDescription)"
        resetTracking()
    }
    
    // MARK: - Private methods
    
    private func updateSessionInfoLabel(for frame: ARFrame, trackingState: ARCamera.TrackingState) {
        // Update the UI to provide feedback on the state of the AR experience.
        let message: String
        
        switch trackingState {
        case .normal where frame.anchors.isEmpty:
            // No planes detected; provide instructions for this app's AR interactions.
            message = "Move the device around to detect horizontal surfaces."
            
        case .normal:
            // No feedback needed when tracking is normal and planes are visible.
            message = ""
            
        case .notAvailable:
            message = "Tracking unavailable."
            
        case .limited(.excessiveMotion):
            message = "Tracking limited - Move the device more slowly."
            
        case .limited(.insufficientFeatures):
            message = "Tracking limited - Point the device at an area with visible surface detail, or improve lighting conditions."
            
        case .limited(.initializing):
            message = "Initializing AR session."
            
        }
        
        sessionInfoLabel.text = message
        sessionInfoView.isHidden = message.isEmpty
    }
    
    private func resetTracking() {
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = .horizontal
        sceneView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
    }
    
    private func checkARKitSupport() {
        guard ARWorldTrackingConfiguration.isSupported else {
            fatalError("""
                ARKit is not available on this device. For apps that require ARKit
                for core functionality, use the `arkit` key in the key in the
                `UIRequiredDeviceCapabilities` section of the Info.plist to prevent
                the app from installing. (If the app can't be installed, this error
                can't be triggered in a production scenario.)
                In apps where AR is an additive feature, use `isSupported` to
                determine whether to show UI for launching AR experiences.
            """) // For details, see https://developer.apple.com/documentation/arkit
        }
    }
}
