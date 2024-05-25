//
//  GameScene.swift
//  SpaceBattle
//
//  Created by Macbook on 2/5/20.
//  Copyright © 2020 Macbook. All rights reserved.
//

import SpriteKit
import GameplayKit

enum gameState {
    case beforeGame
    case inGame
    case afterGame
}

var curGameState = gameState.beforeGame //storing current game state
var score: Int = 0 //current score of player

class HeartSpriteNode: SKSpriteNode {
    var direction: CGVector = CGVector(dx: 0, dy: 0)
    var timeElapsed: CGFloat = 0
    
    convenience init() {
        self.init(imageNamed: "heart")
    }
}

class GameScene: SKScene {
    //Initiate 2 backgrounds - for interface purpose
    let background: SKSpriteNode = SKSpriteNode(imageNamed: "background")
    let alternateBackground: SKSpriteNode = SKSpriteNode(imageNamed: "background")
    
    let player: SKSpriteNode = SKSpriteNode(imageNamed: "playerShip")
    var gameArea: CGRect //area in which player can move
    
    var scoreLabel: SKLabelNode = SKLabelNode(fontNamed: "BradleyHandITCTT-Bold")
    var livesLabel: SKLabelNode = SKLabelNode(fontNamed: "BradleyHandITCTT-Bold")
    var startGameLabel: SKLabelNode = SKLabelNode(fontNamed: "BradleyHandITCTT-Bold")
    
    //Declare sound effects
    let shootSound = SKAction.playSoundFileNamed("Shoot.wav", waitForCompletion: false)
    //let explosionSound = SKAction.playSoundFileNamed("Explosion.wav", waitForCompletion: false)
    
    //Number of lives player has
    var lives: Int = 3 {
        didSet {
            livesLabel.text = "Lives: \(lives)"
        }
    }
    
    var lastTime: TimeInterval = 0 //record the last time the frame got updated
    var speedRate: CGFloat = 300.0 //speed of the background
    var speedHeart: CGFloat = 5.0 //speed of the heart
    
    //Type of objects
    struct Objects {
        static let None: UInt32 = 0
        static let Bullet: UInt32 = 1
        static let Player: UInt32 = 2
        static let Enemy: UInt32 = 4
        static let EnemyBullet: UInt32 = 8
        static let Heart: UInt32 = 16
        static let BlueShield: UInt32 = 32
        static let YellowShield: UInt32 = 64
        static let All: UInt32 = UInt32.max
    }
    
    //Milestone in which game will change its speed - for difficult increase purpose
    //Each phase will be interpreted as a number indicating the maximum number of scores that the game is in this phase.
    struct GamePhases {
        static let FirstPhase = 20
        static let SecondPhase = 40
        static let ThirdPhase = 60
        static let FourthPhase = 80
        static let FifthPhase = 100
    }
    
    //Store different speed of the game
    struct Speed {
        static let FirstPhase: CGFloat = 2.0
        static let SecondPhase: CGFloat = 1.75
        static let ThirdPhase: CGFloat = 1.5
        static let FourthPhase: CGFloat = 1.25
        static let FifthPhase: CGFloat = 1.0
    }
    
    override init(size: CGSize) {
        gameArea = CGRect(x: 0, y: 0, width: size.width, height: size.height)
        super.init(size: size)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func didMove(to view: SKView) {
        //print(UIDevice.current.identifierForVendor!.uuidString)
        //Setup physics world
        score = 0
        physicsWorld.gravity = .zero
        physicsWorld.contactDelegate = self
        
        //Setup background theme
        background.name = "Background"
        background.size = self.size
        background.position = CGPoint(x: self.size.width / 2, y: self.size.height / 2)
        background.zPosition = 0
        self.addChild(background)
        
        //Setup another background and alternatively rotate
        alternateBackground.name = "Background"
        alternateBackground.size = self.size
        alternateBackground.position = CGPoint(x: self.size.width / 2, y: self.size.height * 1.5)
        alternateBackground.zPosition = 0
        self.addChild(alternateBackground)
        
        //Configure player
        player.setScale(1.0)
        player.position = CGPoint(x: self.size.width / 2, y: -self.size.height * 0.2)
        player.zPosition = 2
        self.addChild(player)
        
        //Player physics body - for collision calculation
        player.physicsBody = SKPhysicsBody(rectangleOf: player.size)
        player.physicsBody?.categoryBitMask = Objects.Player
        player.physicsBody?.contactTestBitMask = Objects.Enemy
        player.physicsBody?.collisionBitMask = Objects.None
        
        //Setup score label
        scoreLabel.text = "Score: 0"
        scoreLabel.fontSize = 24
        scoreLabel.fontColor = SKColor.white
        scoreLabel.horizontalAlignmentMode = SKLabelHorizontalAlignmentMode.left //align to left
        scoreLabel.zPosition = 100
        scoreLabel.position = CGPoint(x: self.size.width * 0.05, y: self.size.height * 0.9)
        scoreLabel.alpha = 0
        self.addChild(scoreLabel)
        
        //Setup lives label
        livesLabel.text = "Lives: \(lives)"
        livesLabel.fontSize = 24
        livesLabel.fontColor = SKColor.white
        livesLabel.horizontalAlignmentMode = SKLabelHorizontalAlignmentMode.right
        livesLabel.zPosition = 100
        livesLabel.position = CGPoint(x: self.size.width * 0.95, y: self.size.height * 0.9)
        livesLabel.alpha = 0
        self.addChild(livesLabel)
        
        //Setup start game label
        startGameLabel.text = "Start Game"
        startGameLabel.fontSize = 36
        startGameLabel.fontColor = SKColor.white
        startGameLabel.zPosition = 100
        startGameLabel.position = CGPoint(x: self.size.width * 0.5, y: self.size.height * 0.5)
        self.addChild(startGameLabel)
        
        //Create a ship for each two seconds
        spawnEnemyForever()
    }
    
    func spawnEnemyForever() {
        let spawnAction: SKAction = SKAction.run(spawnEnemyBeforeGame) //for spawning
        let waitAction: SKAction = SKAction.wait(forDuration: 2.0) //wait for 2 seconds
        let sequenceAction: SKAction = SKAction.sequence([spawnAction, waitAction]) //spawning then wait
        let repeatedForeverAction: SKAction = SKAction.repeatForever(sequenceAction) //repeat above sequence
        self.run(repeatedForeverAction, withKey: "repeatedForever") //run - initiate with a key for removing action purpose
    }
    
    func enterGame() {
        //Stop all actions happening before game
        self.enumerateChildNodes(withName: "EnemyBeforeGame") { (enemy, stop) in
            enemy.removeAllActions()
            enemy.removeFromParent()
        }
        
        //Start game
        curGameState = gameState.inGame
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.startGame()
        } //delay for 1 second before actually starting game
        
        //Delete start game label
        let runAwayAction: SKAction = SKAction.moveBy(x: 0, y: self.size.width, duration: 0.3)
        let deleteAction: SKAction = SKAction.removeFromParent()
        startGameLabel.run(SKAction.sequence([runAwayAction, deleteAction]))
        
        //Show labels
        let fadeInAction: SKAction = SKAction.fadeIn(withDuration: 0.3)
        scoreLabel.run(fadeInAction)
        livesLabel.run(fadeInAction)
        
        //Move player to starting position
        let moveAction: SKAction = SKAction.moveTo(y: self.size.height * 0.2, duration: 0.3)
        player.run(moveAction)
    }
    
    override func update(_ currentTime: TimeInterval) {
        //Update UI per timeframe
        if curGameState != gameState.inGame {
            return
        }
        
        var deltaFrameTime: TimeInterval = 0
        
        if lastTime == 0 {
            lastTime = currentTime
        }
        else {
            deltaFrameTime = currentTime - lastTime
            lastTime = currentTime
        }
        
        let movedAmount: CGFloat = speedRate * CGFloat(deltaFrameTime) //calculate amount of distance that backgrounds have to move
        
        self.enumerateChildNodes(withName: "Background") { (background, stop) in
            background.position.y -= movedAmount
            if background.position.y < -self.size.height / 2 {
                background.position.y += self.size.height * 2
            }
        }
        
        self.enumerateChildNodes(withName: "Heart") { (heart, stop) in
            if let actualHeart = heart as? HeartSpriteNode {
                actualHeart.timeElapsed += CGFloat(deltaFrameTime)
                
                //Heart can exist up to 8 seconds. After that, it will be removed
                
                if actualHeart.timeElapsed < 8.0 {
                    actualHeart.position.x += actualHeart.direction.dx * self.speedHeart
                    actualHeart.position.y += actualHeart.direction.dy * self.speedHeart
                    
                    if actualHeart.position.x <= actualHeart.size.width / 2 { //left border
                        actualHeart.direction.dx = -actualHeart.direction.dx
                    }
                    if actualHeart.position.x >= self.size.width - actualHeart.size.width / 2 { //right border
                        actualHeart.direction.dx = -actualHeart.direction.dx
                    }
                    if actualHeart.position.y <= actualHeart.size.height / 2 { //bottom border
                        actualHeart.direction.dy = -actualHeart.direction.dy
                    }
                    if actualHeart.position.y >= self.size.height - actualHeart.size.height / 2 { //top border
                        actualHeart.direction.dy = -actualHeart.direction.dy
                    }
                    
                    //Ensuring that this heart is in game area
                    actualHeart.position.x = max(actualHeart.position.x, 0)
                    actualHeart.position.x = min(actualHeart.position.x, self.size.width)
                    actualHeart.position.y = max(actualHeart.position.y, 0)
                    actualHeart.position.y = min(actualHeart.position.y, self.size.height)
                }
                else {
                    actualHeart.removeFromParent()
                }
            }
        }
    }
    
    func startGame() {
        //Spawn enemies forever
        let spawnAction: SKAction = SKAction.run(spawnEnemy) //spawn enemy
        let waitAction: SKAction = SKAction.wait(forDuration: 0.75) //wait for 0.75 seconds before spawning another enemy
        let seqAction: SKAction = SKAction.sequence([waitAction, spawnAction]) //spawn then wait
        let repeatedAction: SKAction = SKAction.repeatForever(seqAction) //repeat above sequence
        self.run(repeatedAction, withKey: "spawningEnemies") //run with specific key - for removing purpose
    }
    
    func addScore() {
        score += 1
        scoreLabel.text = "Score: \(score)"
    }
    
    func loseLife() {
        lives -= 1
        
        if lives == 0 { //if number of lives equal to 0, then the game is over
            executeGameOver()
            return
        }
    }
    
    func gainLife() {
        lives += 1
    }
    
    func executeGameOver() {
        //Stop the game and proceed to game over scene
        curGameState = gameState.afterGame
        
        //remove all actions
        self.removeAllActions()
        self.enumerateChildNodes(withName: "Bullet") { (bullet, stop) in
            bullet.removeAllActions()
        }
        
        self.enumerateChildNodes(withName: "Enemy") { (enemy, stop) in
            enemy.removeAllActions()
        }
        
        self.enumerateChildNodes(withName: "EnemyBullet") { (enemyBullet, stop) in
            enemyBullet.removeAllActions()
        }
        
        //Wait for 0.5 seconds before moving to game over scene
        let waitAction: SKAction = SKAction.wait(forDuration: 0.5)
        let changeSceneAction: SKAction = SKAction.run(changeScene)
        self.run(SKAction.sequence([waitAction, changeSceneAction]))
    }
    
    func changeScene() {
        //Move to game over scene
        let nextScene = GameOverScene(size: self.size)
        nextScene.scaleMode = self.scaleMode //set scale for new scene
        let myTransition: SKTransition = SKTransition.fade(withDuration: 0.5) //fade with 0.5 seconds then present new scene
        self.view!.presentScene(nextScene, transition: myTransition)
    }
    
    func fireBullet(at point: CGPoint) {
        //Fire bullet from a specific location
        if curGameState != gameState.inGame {
            return
        }
        
        let imageName: String = "bullet"
        let bullet: SKSpriteNode = SKSpriteNode(imageNamed: imageName)
        bullet.name = "Bullet"
        bullet.setScale(1.0)
        bullet.position = point
        bullet.zPosition = 1
        self.addChild(bullet)
        
        //Bullet physics body - for collision calculation
        bullet.physicsBody = SKPhysicsBody(rectangleOf: bullet.size)
        bullet.physicsBody?.categoryBitMask = Objects.Bullet
        bullet.physicsBody?.contactTestBitMask = Objects.Enemy
        bullet.physicsBody?.collisionBitMask = Objects.None
        bullet.physicsBody?.usesPreciseCollisionDetection = true
        
        let moveBullet: SKAction = SKAction.moveTo(y: self.size.height * 1.2, duration: 1.5) //move bullet to a specific coordinate
        let removeBullet: SKAction = SKAction.removeFromParent() //remove bullet
        let seqAction: SKAction = SKAction.sequence([shootSound, moveBullet, removeBullet]) //emit sound, move then remove
        bullet.run(seqAction)
    }
    
    func bulletFromEnemy(at point: CGPoint) {
        //Fire enemy bullet from a specific location
        if curGameState != gameState.inGame {
            return
        }
        
        let imageName: String = "reversedBullet"
        let bullet: SKSpriteNode = SKSpriteNode(imageNamed: imageName)
        bullet.name = "EnemyBullet"
        bullet.setScale(1.0)
        bullet.position = point
        bullet.zPosition = 1
        self.addChild(bullet)
        
        //Bullet physics body - for collision calculation
        bullet.physicsBody = SKPhysicsBody(rectangleOf: bullet.size)
        bullet.physicsBody?.categoryBitMask = Objects.EnemyBullet
        bullet.physicsBody?.contactTestBitMask = Objects.Player
        bullet.physicsBody?.collisionBitMask = Objects.None
        bullet.physicsBody?.usesPreciseCollisionDetection = true
        
        let moveBullet: SKAction = SKAction.moveTo(y: -self.size.height * 0.2, duration: 2.0) //move bullet
        let removeBullet: SKAction = SKAction.removeFromParent() //remove
        let seqAction: SKAction = SKAction.sequence([moveBullet, removeBullet]) //move then remove
        bullet.run(seqAction)
    }
    
    func spawnEnemyBeforeGame() {
        //Spawn enemies before game - for decoration purpose
        if curGameState != gameState.beforeGame {
            self.removeAction(forKey: "repeatedForever")
            return
        }
        
        let enemy: SKSpriteNode = SKSpriteNode(imageNamed: "enemyShip")
        enemy.name = "EnemyBeforeGame"
        enemy.setScale(1)
        
        //Starting coordinates and ending coordinates of the trajectory
        let startX = random(minValue: gameArea.minX + enemy.size.width / 2, maxValue: gameArea.maxX - enemy.size.width / 2)
        let endX = random(minValue: gameArea.minX + enemy.size.width / 2, maxValue: gameArea.maxX - enemy.size.width / 2)
        let startY = self.size.height + enemy.size.height / 2
        let endY = -self.size.height * 0.2
    
        //Randomly choose a y-coordinate stop -> Use math to calculate x-coordinate of stop point
        let stopY = random(minValue: 100, maxValue: self.size.height - 100)
        let stopX = (startY - stopY) * (endX - startX) / (startY - endY) + startX
        
        let dx = endX - startX //amount of move with respect to x-coordinate
        let dy = endY - startY //amount of move with respect to y-coordinate
        let angle = atan2(dy, dx) //angle created by the trajectory and x-coordinate
        var complementAngle: CGFloat //angle created by the line connecting stop point and center of circle and x-coordinate
        var startAngle: CGFloat
        enemy.zRotation = angle
        
        let radius: CGFloat = 50 //radius of the circle
        let timePerInterval = 1.0 / 360.0
        var center: CGPoint = CGPoint() //center of circle
        var circlePath: [CGPoint] = [] //store all points in the circle
        
        //Make circle path
        if dx >= 0 {
            complementAngle = CGFloat.pi / 2 - abs(angle)
            center.x = stopX + radius * cos(complementAngle)
            center.y = stopY + radius * sin(complementAngle)
            startAngle = CGFloat.pi + complementAngle
            startAngle = toDegree(radian: startAngle)
            
            for theta in stride(from: ceil(startAngle), through: 360.0, by: 1) {
                let toRadianTheta = toRadian(degree: theta)
                let point = CGPoint(x: center.x + radius * cos(toRadianTheta), y: center.y + radius * sin(toRadianTheta))
                circlePath.append(point)
            }
            
            for theta in stride(from: 0, through: floor(startAngle), by: 1) {
                let toRadianTheta = toRadian(degree: theta)
                let point = CGPoint(x: center.x + radius * cos(toRadianTheta), y: center.y + radius * sin(toRadianTheta))
                circlePath.append(point)
            }
        }
        else {
            complementAngle = CGFloat.pi / 2 - (CGFloat.pi - abs(angle))
            center.x = stopX - radius * cos(complementAngle)
            center.y = stopY + radius * sin(complementAngle)
            startAngle = CGFloat.pi - complementAngle
            startAngle = toDegree(radian: startAngle)
            
            for theta in stride(from: 360.0, through: ceil(startAngle), by: -1) {
                let toRadianTheta = toRadian(degree: theta)
                let point = CGPoint(x: center.x + radius * cos(toRadianTheta), y: center.y + radius * sin(toRadianTheta))
                circlePath.append(point)
            }
            
            for theta in stride(from: floor(startAngle), through: 0, by: -1) {
                let toRadianTheta = toRadian(degree: theta)
                let point = CGPoint(x: center.x + radius * cos(toRadianTheta), y: center.y + radius * sin(toRadianTheta))
                circlePath.append(point)
            }
        }
        
        /*var path = CGMutablePath()
        path.move(to: CGPoint(x: stopX, y: stopY))
        for point in circlePath {
            path.addLine(to: point)
        }
        
        var pathShape: SKShapeNode = SKShapeNode()
        pathShape.path = path
        pathShape.strokeColor = .red
        pathShape.lineWidth = 1
        pathShape.zPosition = 1
        self.addChild(pathShape)*/
        
        enemy.zPosition = 2
        enemy.position = CGPoint(x: startX, y: startY)
        self.addChild(enemy)
        
        //Create list of actions
        let moveFirstPhase = SKAction.move(to: CGPoint(x: stopX, y: stopY), duration: 1.0) //move before stop
        let moveSecondPhase = SKAction.move(to: CGPoint(x: endX, y: endY), duration: 1.0) //move after stop
        let removeAction = SKAction.removeFromParent()
        var arrayAction: [SKAction] = [] //store all actions
        arrayAction.append(moveFirstPhase)
        
        var moveAction: SKAction
        var rotateAction: SKAction
        for point in circlePath {
            rotateAction = SKAction.run({
                enemy.zRotation = self.calculateRotationAngle(x1: enemy.position.x, y1: enemy.position.y, x2: point.x, y2: point.y)
            })
            
            moveAction = SKAction.move(to: point, duration: timePerInterval)
            arrayAction.append(rotateAction)
            arrayAction.append(moveAction)
        }
        
        rotateAction = SKAction.run({
            enemy.zRotation = self.calculateRotationAngle(x1: enemy.position.x, y1: enemy.position.y, x2: endX, y2: endY)
        })
        
        arrayAction.append(rotateAction)
        arrayAction.append(moveSecondPhase)
        arrayAction.append(removeAction)
        enemy.run(SKAction.sequence(arrayAction))
    }
    
    func spawnEnemy() {
        let enemy: SKSpriteNode = SKSpriteNode(imageNamed: "enemyShip")
        enemy.name = "Enemy"
        enemy.setScale(1)
        
        let randomStartX = random(minValue: gameArea.minX + enemy.size.width / 2, maxValue: gameArea.maxX - enemy.size.width / 2)
        let randomEndX = random(minValue: gameArea.minX + enemy.size.width / 2, maxValue: gameArea.maxX - enemy.size.width / 2)
        let randomShootY = random(minValue: self.size.height - 100, maxValue: self.size.height)
        
        let startPoint: CGPoint = CGPoint(x: randomStartX, y: self.size.height + enemy.size.height / 2)
        let endPoint: CGPoint = CGPoint(x: randomEndX, y: -self.size.height * 0.2)
        
        enemy.position = startPoint
        enemy.zPosition = 2
        self.addChild(enemy)
        
        enemy.physicsBody = SKPhysicsBody(rectangleOf: enemy.size)
        enemy.physicsBody?.categoryBitMask = Objects.Enemy
        enemy.physicsBody?.contactTestBitMask = Objects.Player | Objects.Bullet
        enemy.physicsBody?.collisionBitMask = Objects.None
        
        let dx = endPoint.x - startPoint.x
        let dy = endPoint.y - startPoint.y
        let angle = atan2(dy, dx)
        enemy.zRotation = angle
        
        var durationTaken: CGFloat = Speed.FirstPhase //amount of time this enemy takes to complete the trajectory
        
        if score <= GamePhases.FirstPhase {
            durationTaken = Speed.FirstPhase
        }
        else if score <= GamePhases.SecondPhase {
            durationTaken = Speed.SecondPhase
        }
        else if score <= GamePhases.ThirdPhase {
            durationTaken = Speed.ThirdPhase
        }
        else if score <= GamePhases.FourthPhase {
            durationTaken = Speed.FourthPhase
        }
        else {
            durationTaken = Speed.FifthPhase
        }
        
        let randomNumber = CGFloat.random(in: 0...1) //random a number between 0 and 1. 20% probability that this enemy will shoot.
        
        //Calculate stop point
        if randomNumber <= 0.2 {
            let randomShootX = (startPoint.y - randomShootY) * (endPoint.x - startPoint.x) / (startPoint.y - endPoint.y) + startPoint.x
            let stopPoint: CGPoint = CGPoint(x: randomShootX, y: randomShootY)
            let distance1 = dist(p1: startPoint, p2: stopPoint)
            let totalDistance = dist(p1: startPoint, p2: endPoint)
            let time1 = distance1 * durationTaken / totalDistance
            let time2 = durationTaken - time1
            
            let movePhase1: SKAction = SKAction.move(to: stopPoint, duration: TimeInterval(time1))
            let waitAction: SKAction = SKAction.wait(forDuration: 0.1)
            let movePhase2: SKAction = SKAction.move(to: endPoint, duration: TimeInterval(time2))
            let removeEnemy: SKAction = SKAction.removeFromParent()
            let loseLifeAction: SKAction = SKAction.run(loseLife)
            
            if curGameState == gameState.inGame {
                enemy.run(SKAction.sequence([movePhase1, waitAction]))
                bulletFromEnemy(at: enemy.position)
            }
            
            let seqAction: SKAction = SKAction.sequence([movePhase2, removeEnemy, loseLifeAction])
            if curGameState == gameState.inGame {
                enemy.run(seqAction)
            }
        }
        else {
            let moveAction: SKAction = SKAction.move(to: endPoint, duration: TimeInterval(durationTaken))
            let removeAction: SKAction = SKAction.removeFromParent()
            let loseLifeAction: SKAction = SKAction.run(loseLife)
            
            if curGameState == gameState.inGame {
                enemy.run(SKAction.sequence([moveAction, removeAction, loseLifeAction]))
            }
        }
    }
    
    func emitHeart(at position: CGPoint) {
        //Emit a heart at position with specific probability (10%)
        let prob: CGFloat = random()
        if (prob > 0.05) { return }
        
        /*** Do work ***/
        //Create a random emitted angle
        var angle = random(minValue: -45, maxValue: 45)
        angle = toRadian(degree: angle) //Convert to radian
        
        var heart = HeartSpriteNode()
        heart.direction = CGVector(dx: sin(angle), dy: -cos(angle))
        heart.name = "Heart"
        heart.position = position
        heart.zPosition = 1
        heart.setScale(1)
        heart.physicsBody = SKPhysicsBody(rectangleOf: heart.size)
        heart.physicsBody?.categoryBitMask = Objects.Heart
        heart.physicsBody?.contactTestBitMask = Objects.Player
        heart.physicsBody?.collisionBitMask = Objects.None
        self.addChild(heart)
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        if curGameState == gameState.inGame {
            fireBullet(at: player.position)
        }
        else {
            for touch: AnyObject in touches {
                let curTouch = touch.location(in: self)
                if startGameLabel.contains(curTouch) {
                    enterGame()
                    return
                }
            }
        }
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        if curGameState != gameState.inGame {
            return
        }
        for touch: AnyObject in touches {
            let curTouch = touch.location(in: self)
            let prevTouch = touch.previousLocation(in: self)
            let dx = curTouch.x - prevTouch.x
            let dy = curTouch.y - prevTouch.y
            
            if curGameState == gameState.inGame {
                player.position.x += dx
                player.position.y += dy
            }
            
            if player.position.x >= gameArea.maxX - player.size.width / 2 {
                player.position.x = gameArea.maxX - player.size.width / 2
            }
            if player.position.x <= gameArea.minX + player.size.width / 2 {
                player.position.x = gameArea.minX + player.size.width / 2
            }
            if player.position.y - player.size.height / 2 <= 0 {
                player.position.y = player.size.height / 2
            }
            if player.position.y + player.size.height / 2 >= self.size.height {
                player.position.y = self.size.height - player.size.height / 2
            }
        }
    }
    
    func createExplosion (at position: CGPoint) {
        //Create explosion at a specific position
        let explosion: SKSpriteNode = SKSpriteNode(imageNamed: "explosion")
        explosion.setScale(0)
        explosion.zPosition = 1
        explosion.position = position
        self.addChild(explosion)
        
        let scaleInAction: SKAction = SKAction.scale(to: 1, duration: 0.1)
        let fadeOutAction: SKAction = SKAction.fadeOut(withDuration: 0.1)
        let removeAction: SKAction = SKAction.removeFromParent()
        explosion.run(SKAction.sequence([scaleInAction, fadeOutAction, removeAction]))
    }
    
    func collide(objA: SKSpriteNode?, objB: SKSpriteNode?) {
        if objB?.physicsBody?.categoryBitMask == Objects.Heart {
            gainLife()
            objB?.removeFromParent()
        }
        else if objB?.physicsBody?.categoryBitMask != Objects.EnemyBullet {
            var position: CGPoint? = nil
            if objA?.physicsBody?.categoryBitMask == Objects.Enemy {
                position = objA!.position
            }
            
            if objB?.physicsBody?.categoryBitMask == Objects.Enemy {
                position = objB!.position
            }
            
            if position != nil {
                createExplosion(at: position!)
            }
            
            if objA?.physicsBody?.categoryBitMask != Objects.Player { //bullet collide with enemy
                objA?.removeFromParent()
                objB?.removeFromParent()
                addScore()
                if position != nil {
                    emitHeart(at: position!)
                }
            }
            else { //player collide with enemy
                if lives != 1 {
                    let fadeOutAction: SKAction = SKAction.fadeOut(withDuration: 0.1)
                    let fadeInAction: SKAction = SKAction.fadeIn(withDuration: 0.1)
                    objA?.run(SKAction.sequence([fadeOutAction, fadeInAction]))
                }
                else {
                    createExplosion(at: player.position)
                    objA?.removeFromParent()
                }
                
                loseLife()
                objB?.removeFromParent()
            }
        }
        else { //player collide with enemy bullet
            if lives != 1 {
                let fadeOutAction: SKAction = SKAction.fadeOut(withDuration: 0.1)
                let fadeInAction: SKAction = SKAction.fadeIn(withDuration: 0.1)
                objA?.run(SKAction.sequence([fadeOutAction, fadeInAction]))
            }
            else {
                createExplosion(at: player.position)
                objA?.removeFromParent()
            }
            
            loseLife()
            objB?.removeFromParent()
        }
    }
    
    func random() -> CGFloat {
        return CGFloat.random(in: 0...1)
    }
    
    func random(minValue min: CGFloat, maxValue max: CGFloat) -> CGFloat {
        return random() * (max - min) + min
    }
    
    func dist(p1: CGPoint, p2: CGPoint) -> CGFloat {
        return sqrt((p1.x - p2.x) * (p1.x - p2.x) + (p1.y - p2.y) * (p1.y - p2.y))
    }
    
    func toDegree(radian: CGFloat) -> CGFloat {
        return radian * 180.0 / CGFloat.pi
    }
    
    func toRadian(degree: CGFloat) -> CGFloat {
        return degree * CGFloat.pi / 180.0
    }
    
    func calculateRotationAngle(x1: CGFloat, y1: CGFloat, x2: CGFloat, y2: CGFloat) -> CGFloat {
        let dy = y2 - y1
        let dx = x2 - x1
        return atan2(dy, dx)
    }
}

extension GameScene: SKPhysicsContactDelegate {
    func didBegin(_ contact: SKPhysicsContact) {
        var firstBody: SKPhysicsBody
        var secondBody: SKPhysicsBody
        
        if contact.bodyA.categoryBitMask < contact.bodyB.categoryBitMask {
            firstBody = contact.bodyA
            secondBody = contact.bodyB
        }
        else {
            firstBody = contact.bodyB
            secondBody = contact.bodyA
        }
        
        guard let _ = firstBody.node else { return }
        guard let _ = secondBody.node else { return }
        
        //player collide with enemy
        if firstBody.categoryBitMask & Objects.Player != 0 && secondBody.categoryBitMask & Objects.Enemy != 0 {
            let objA: SKSpriteNode? = firstBody.node as! SKSpriteNode?
            let objB: SKSpriteNode? = secondBody.node as! SKSpriteNode?
            collide(objA: objA, objB: objB)
        }
        
        //player collide with enemy bullet
        if firstBody.categoryBitMask & Objects.Player != 0 && secondBody.categoryBitMask & Objects.EnemyBullet != 0 {
            let objA: SKSpriteNode? = firstBody.node as! SKSpriteNode?
            let objB: SKSpriteNode? = secondBody.node as! SKSpriteNode?
            collide(objA: objA, objB: objB)
        }
        
        //player collide with heart
        if firstBody.categoryBitMask & Objects.Player != 0 && secondBody.categoryBitMask & Objects.Heart != 0 {
            let objA: SKSpriteNode? = firstBody.node as! SKSpriteNode?
            let objB: SKSpriteNode? = secondBody.node as! SKSpriteNode?
            collide(objA: objA, objB: objB)
        }
        
        //bullet collide with enemy
        if firstBody.categoryBitMask & Objects.Bullet != 0 && secondBody.categoryBitMask & Objects.Enemy != 0 {
            let objA: SKSpriteNode? = firstBody.node as! SKSpriteNode?
            let objB: SKSpriteNode? = secondBody.node as! SKSpriteNode?
            collide(objA: objA, objB: objB)
        }
    }
}
