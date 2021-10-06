//
//  ContentView.swift
//  ImageAnchor
//
//  Created by Nien Lam on 9/21/21.
//  Copyright © 2021 Line Break, LLC. All rights reserved.
//

import SwiftUI
import ARKit
import RealityKit
import Combine
import CoreMotion
import AVFoundation
import CoreAudio



// MARK: - Varying Stats
let currentTimerLength = 15
let totalEnemiesAndItems = 3

// MARK: - View model for handling communication between the UI and ARView.
class ViewModel: ObservableObject {
    
    @Published var isStart: Bool = true
    @Published var isInProgress: Bool = false
    @Published var isWin: Bool = false
    @Published var isLose: Bool = false
    
    @Published var timeLeft: String = "\(currentTimerLength)"
    @Published var gameStatus = "START"

    let uiSignal = PassthroughSubject<UISignal, Never>()
    
    enum UISignal {
        case restartButtonPress
     }
    
    func resetFlags(){
        self.isStart = false;
        self.isInProgress = false;
        self.isWin = false;
        self.isLose = false;
    }
}


// MARK: - UI Layer.
struct ContentView : View {
    @StateObject var viewModel: ViewModel

    var body: some View {
        
            ZStack {
                
                if(viewModel.isStart){
                    Color.black
                    VStack(alignment: .center){
                        
                        HStack{
                            Text("Monsters Under the Bed")
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .foregroundColor(.orange)
                                .font(.system(.largeTitle))
                                .font(.system(size: 72))

                        }
                        
                        HStack{
                            Text("Protect your candy before time runs!\nTap the monsters to keep them at bay.\nIf you lose all your sweets, it's game over!")
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .foregroundColor(.gray)
                                .font(.system(.headline))
                                .padding(20)
                        }
                                               
                        HStack{
                            Button {
                                viewModel.resetFlags();
                                viewModel.isInProgress = true;
                            } label: {
                                Text("Start Game")
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                                    .font(.system(.largeTitle))
                                    .foregroundColor(.white)
                            }

                        }
                    }
                }
                
                else if (viewModel.isInProgress){
                     ARViewContainer(viewModel: viewModel)
                    
                        Text("Time Left:\n\(viewModel.timeLeft)s")
                        .background(.black)
                            .foregroundColor(.orange)
                            .font(.system(.largeTitle))
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                            .padding(30)
                }
                
                else if viewModel.isWin{
                    Color(.black)

                    VStack(alignment: .center){
                        HStack{
                            Text("You kept your candy safe from the monsters!\nGood job!")
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                                .foregroundColor(.orange)
                                .font(.system(.largeTitle))
                        }
                                               
                        HStack{
                            Image("candy-bucket")
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 300, height: 300, alignment: .center)
                                .clipShape(Circle())
                        }
                        
                        HStack{
                            Button {
                                viewModel.uiSignal.send(.restartButtonPress)
                            } label: {
                                Text("Play Again")
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                                    .font(.system(.largeTitle))
                                    .foregroundColor(.white)
                            }
                        }
                    }
                }
                
                if viewModel.isLose{
                    Color.black

                    VStack(alignment: .center){
                        
                        HStack{
                            Text("You lost your candy to the monsters!")
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .foregroundColor(.orange)
                                .font(.system(.largeTitle))
                        }
                                               
                        HStack{
                            Image("game-over")
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 250, height: 250, alignment: .center)
                                .clipShape(Circle())
                        }
                        
                        HStack{
                            Button {
                                viewModel.uiSignal.send(.restartButtonPress)
                            } label: {
                                Text("Restart Game")
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                                    .font(.system(.largeTitle))
                                    .foregroundColor(.white)
                            }
                        }
                    }
                }
            }
            .edgesIgnoringSafeArea(.all)
            .statusBar(hidden: true)
         
        
        }
        
}


// MARK: - AR View.
struct ARViewContainer: UIViewRepresentable {
    let viewModel: ViewModel
    
    func makeUIView(context: Context) -> ARView {
        SimpleARView(frame: .zero, viewModel: viewModel)
    }
    
    func updateUIView(_ uiView: ARView, context: Context) {}
}

class SimpleARView: ARView, ARSessionDelegate {
    var viewModel: ViewModel
    var arView: ARView { return self }
    var subscriptions = Set<AnyCancellable>()
    
    // Dictionary for tracking image anchors.
    var imageAnchorToEntity: [ARImageAnchor: AnchorEntity] = [:]

    // Variable adjust animation timing
    var lastUpdateTime = Date()
            
    let numItems = 2
    var allEaten = false

    
    var totalGameTimeLeft = currentTimerLength;
    var timer: Timer?
  
        
    // TODO: Update target image and physical width in meters. //////////////////////////////////////
    var background: ModelEntity?
    
    var allHands:[HandEntity] = []
    var allCandy:[CandyEntity] = []

    init(frame: CGRect, viewModel: ViewModel) {
        self.viewModel = viewModel
        super.init(frame: frame)
    }
    
    required init?(coder decoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    required init(frame frameRect: CGRect) {
        fatalError("init(frame:) has not been implemented")
    }
    
    override func didMoveToSuperview() {
        super.didMoveToSuperview()
        
        UIApplication.shared.isIdleTimerDisabled = true
         
        setupScene()
        
    }
    
 
    func setupScene() {
        // Setup world tracking and plane detection.
        let configuration = ARImageTrackingConfiguration()
        arView.renderOptions = [.disableDepthOfField, .disableMotionBlur]


        // TODO: Update target image and physical width in meters. //////////////////////////////////////
        let targetImage    = "bed2.png"
        let physicalWidth  = 0.1524
        
        if let refImage = UIImage(named: targetImage)?.cgImage {
            let arReferenceImage = ARReferenceImage(refImage, orientation: .up, physicalWidth: physicalWidth)
            var set = Set<ARReferenceImage>()
            set.insert(arReferenceImage)
            configuration.trackingImages = set
        } else {
            print("❗️ Error loading target image")
        }
        
        arView.session.run(configuration)
        
        // Called every frame.
        scene.subscribe(to: SceneEvents.Update.self) { event in
            // Call renderLoop method on every frame.
            self.renderLoop()
        }.store(in: &subscriptions)
        
        // Process UI signals.
        viewModel.uiSignal.sink { [weak self] in
            self?.processUISignal($0)
        }.store(in: &subscriptions)
        
        // Respond to collision events.
        arView.scene.subscribe(to: CollisionEvents.Began.self) { event in

            for i in 0..<totalEnemiesAndItems{
                if (self.viewModel.isInProgress && event.entityA.name == "hand-\(i)" && event.entityB.name == "candy-\(i)"){
                    self.allCandy[i].handleGrabCandy()
                }
                
            }
        }.store(in: &subscriptions)
        
        // Setup tap gesture.
        let tap = UITapGestureRecognizer(target: self, action: #selector(self.handleTap(_:)))
        arView.addGestureRecognizer(tap)
    
        // Set session delegate.
        arView.session.delegate = self
         
        // arView.debugOptions = [.showPhysics]
    }
    
    func processUISignal(_ signal: ViewModel.UISignal) {
        switch signal {
            case .restartButtonPress:
                print("restart button press")
                self.resetGame()
                viewModel.resetFlags()
                viewModel.isStart = true
                break;
        }
    }

    
    // Handle taps.
    @objc func handleTap(_ sender: UITapGestureRecognizer? = nil) {
        guard let touchInView = sender?.location(in: self),
              let hitEntity = arView.entity(at: touchInView) else { return }

        if(hitEntity.name.contains("hand")){
            handleHitHand(handEntity: hitEntity)
        }
    }
    
    func handleHitHand(handEntity: Entity){
        print(handEntity.name)
//        handEntity.position.y -= Float(0.055)
        let idx = Int(handEntity.name.components(separatedBy: "-")[1])
        allHands[idx!].handleTap()
        //handEntity.scale *= [1.2, 1.2, 1.2]
    }
    
    func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
        anchors.compactMap { $0 as? ARImageAnchor }.forEach {
            // Create anchor from image.
            let anchorEntity = AnchorEntity(anchor: $0)
            
            // Track image anchors added to scene.
            imageAnchorToEntity[$0] = anchorEntity
            
            // Add anchor to scene.
            arView.scene.addAnchor(anchorEntity)
            
            // Call setup method for entities.
            // IMPORTANT: Play USDZ animations after entity is added to the scene.
            setupEntities(anchorEntity: anchorEntity)
        }
    }
    
    // TODO: Setup entities. //////////////////////////////////////
    // IMPORTANT: Attach to anchor entity. Called when image target is found.

    func setupEntities(anchorEntity: AnchorEntity) {
        
        background = try! Entity.loadModel(named: "plane.usda")
        background?.scale = [0.5, 0.25, 0.15]
        background?.position.y = 0.005
        background?.orientation *= simd_quatf(angle: (Float.pi)/2, axis: [1, 0, 0])
        anchorEntity.addChild(background!)
    
        for ind in 0..<totalEnemiesAndItems {
            let name = "hand-\(ind)"
            let hand = HandEntity(name: name, ind: Float(ind))
            anchorEntity.addChild(hand)
            allHands.append(hand)
        }
        
        for ind in 0..<totalEnemiesAndItems {
            let name = "candy-\(ind)"
            let candy = CandyEntity(name: name, ind: Float(ind))
            anchorEntity.addChild(candy)
            allCandy.append(candy)
        }
        
    }
    
    func resetGame(){
        timer?.invalidate()
        timer = nil
         
        allEaten = false
        totalGameTimeLeft = currentTimerLength
        for hand in allHands {
            hand.resetSelf()
         }
        for candy in allCandy {
            candy.isCaught = false
            candy.isEnabled = true
        }
      }
    
    
    // TODO: Animate entities. //////////////////////////////////////
    func renderLoop() {
        
        if(viewModel.isInProgress){
        
            if (timer == nil){
            timer = Timer.scheduledTimer(timeInterval: 1, target: self, selector: #selector(onTimerFires), userInfo: nil, repeats: true)
            }
            renderGame()
            
        }

    }
    
    @objc func onTimerFires(){
        totalGameTimeLeft = totalGameTimeLeft-1
        viewModel.timeLeft = String(totalGameTimeLeft)
        
        if(totalGameTimeLeft<=0 && viewModel.isInProgress ){
            timer?.invalidate()
            timer = nil
            
            viewModel.resetFlags()
            viewModel.isWin = true
        }
        else if(viewModel.isInProgress == false){
            timer?.invalidate()
            timer = nil
        }
    }
    
    func renderGame(){
        
        // Time interval from last animated material update.
        let currentTime  = Date()
        let timeInterval = currentTime.timeIntervalSince(lastUpdateTime)
        
        if (timeInterval > 1/30 && allHands.count > 0) {
            
            for hand in allHands {
                hand.model.position.y += hand.speed
            }
            lastUpdateTime = currentTime
        }

        for candy in allCandy {
            if(candy.isCaught == true){
                allEaten = true
            }
            else {
                allEaten = false
            }
        }
        if(allEaten == true){
            viewModel.resetFlags()
            viewModel.isLose = true
        }
    }
    
}

class HandEntity: Entity, HasModel, HasCollision  {
    var health = 8
    var model: Entity
    var speed = Float(0.0025)
    var hasCandy = false
    var startingYPos = Float(0.00015)
//      var colorMat: PhysicallyBasedMaterial
//      var originalMat: RealityKit.Material

    init(name: String, ind: Float) {
        //model = try! Entity.loadModel(named: "hand.usdz")
        model = try! Entity.loadModel(named: "orc-hand.usdz")

        model.name = name
        model.generateCollisionShapes(recursive: true)
        
        super.init()

        // Set transform:
        self.position.y = self.startingYPos

        //self.position.x = 0.07*ind
        self.position.x = (0.035)*ind
        self.model.orientation *= simd_quatf(angle: -(Float.pi)/2, axis: [1, 0, 0])
        self.model.orientation *= simd_quatf(angle: -(Float.pi)/2, axis: [0, 1, 0])

        self.model.scale = [0.75, 0.75, 0.75]
         
        self.collision = CollisionComponent(shapes: [.generateBox(size: [0.2095, 0.13725, 0.1275])])

        self.addChild(model)
    }
    
    required init() {
        fatalError("init() has not been implemented")
    }
    
    // TODO: change it so that the lower health it is, farther it gets knocked back, but speeds up more quickly
    func handleTap(){
        self.health = self.health - 1
        
        self.position.y = self.position.y - Float(0.1)

         if(self.health <= 3){
            self.speed *= 1.5
        }
//        if(self.health<=0){
//            self.resetSelf()
//            self.isEnabled = false;
//        }
    }
    
    func resetSelf(){
        print("In reset self");
       // self.position.y = startingYPos
        self.position.y = self.startingYPos
        self.speed = Float(0.0025);
        self.health = 10
        
    }
}

class CandyEntity: Entity, HasModel, HasCollision {
    var isCaught = false
    var model: Entity
    var size = Float(1.383)
    
    init(name: String, ind: Float) {
        model = try! Entity.loadModel(named: "gumdrop.usdz")

        model.name = name
        model.generateCollisionShapes(recursive: true)
        
        // Set transform:
        self.model.scale = [0.055,0.055,0.055]
        self.model.position.y = 0.30
        self.model.position.x = (0.035)*ind
        self.model.orientation *= simd_quatf(angle: -(Float.pi)/2, axis: [1, 0, 0])
        
        super.init()
         

        self.collision = CollisionComponent(shapes: [.generateBox(size: [0.076065, 0.0605935, 0.076065])])


        self.addChild(model)
    }
    
    required init() {
        fatalError("init() has not been implemented")
    }
    
    func handleGrabCandy(){
        self.isCaught = true;
        self.isEnabled = false;
    }
    
}
    
