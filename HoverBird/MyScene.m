//
//  MyScene.m
//  HoverBird
//
//  Created by ramin on 6/14/14.
//  Copyright (c) 2014 maadotaa.com. All rights reserved.
//

#import "MyScene.h"
#import <AVFoundation/AVFoundation.h>


//#import <opencv2/videoio/cap_ios.h>
//#import "opencv2/imgcodecs/ios.h"
//
//#import <opencv2/highgui/ios.h>
#import <ARKit/ARKit.h>
#import "MyScene.h"
#import "HoverShark-Swift.h"
#import "DateScore.h"
#import <GameKit/GameKit.h>




#define HARD_LEVEL_SPEED_FACTOR 1.3
#define AFTER_10_SPEED_FACTOR 1.3
#define BARREL_SCORE  10
#define TORPEDO_SCORE 15

@interface MyScene ()<SKPhysicsContactDelegate, GKGameCenterControllerDelegate> {
    SKSpriteNode* _shark;
    NSArray *sharkTexturesNormal;
    NSArray *fishTextures;
    SKAction *_moveFishesAndRemove;
    SKColor* _skyColor;
    NSMutableArray* _pipeTexturesUp;
    NSMutableArray* _pipeTexturesDown;
    SKTexture* _bulletTexture;
    SKTexture* _chainTexture;
    SKTexture* _goldMineTexture;
    float chainScale;
    float bulletScale;
    SKAction* _movePipesAndRemove;
    SKAction* _moveMineAndRemove;
    SKNode* _moving;
    SKNode* _ground;
    BOOL _canRestart;
    SKLabelNode* _scoreLabelNode;
    NSInteger _score;
    // Mat grayImage, prevGrayImage; // Removed OpenCV vars
    NSMutableArray * scoreArray;
    NSMutableArray *lifeIconArray;
    NSInteger numLivesLeft;
    NSInteger totalNumLives;
    SKAction *crashSound;
    SKAction *bigGulpSound;
    SKAction *gameOverSound;
    SKAction *organSound;
    BOOL isGameInProgress;
    AVAudioPlayer *gameSceneLoop;
    AVAudioPlayer *gameSceneLoop2;
    BOOL isTouchEnabled;
    float pipeScale;
    BOOL isMusicEnabled;
    BOOL isHoverEnabled;
    SKSpriteNode* musicButton;
    SKSpriteNode* difficultyButton;
    SKSpriteNode* hoverButton;
    BOOL isCameraAvailable;
    BOOL isGameEasy;
    float speedScale;
    BOOL isIPAD;
    NSInteger groundHeight;
    SKTexture *torpedoTexture;
    SKAction *_moveTorpedoAndRemove;
    NSArray *barrelTextures;
    SKTexture *bubbleTexture;
    SKAction *splashSound, *torpedoSound, *popSound, *bubbleSound, *gulpSound;
    float sharkScale;
    SKAction* _moveBubbleAndRemove;
    SKLabelNode* _calibrationLabel;
}
@end

@implementation MyScene

static const uint32_t sharkCategory = 1 << 0;
static const uint32_t worldCategory = 1 << 1;
static const uint32_t barrelCategory = 1 << 2;
static const uint32_t mineCategory = 1 << 3;
static const uint32_t fishCategory = 1 << 4;
static const uint32_t torpedoCategory = 1 << 5;
static const uint32_t worldBoundaryCategory = 1 << 5;
static const uint32_t worldBoundaryUpCategory = 1 << 6;

@synthesize scoreDelegate = _scoreDelegate;


#pragma mark - Buttons

- (SKSpriteNode *)hoverButtonNode
{
    SKSpriteNode *node = [SKSpriteNode spriteNodeWithImageNamed:@"hover.png"];
    node.position = CGPointMake(self.frame.size.width*0.5, self.frame.size.height*0.78);
    node.name = @"hoverButtonNode";//how the node is identified later
    node.zPosition = 1.0;
    [node setScale:.20];
    
    return node;
}

- (SKSpriteNode *)DifficultyButtonNode
{
    SKSpriteNode *node = [SKSpriteNode spriteNodeWithImageNamed:@"Easy.png"];
    node.position = CGPointMake(self.frame.size.width*0.9, self.frame.size.height*0.78);
    node.name = @"DifficultyButtonNode";//how the node is identified later
    node.zPosition = 1.0;
    [node setScale:.20];
    
    return node;
}

- (SKSpriteNode *)MusicButtonNode
{
    SKSpriteNode *musicNode = [SKSpriteNode spriteNodeWithImageNamed:@"music.png"];
    musicNode.position = CGPointMake(self.frame.size.width*0.7, self.frame.size.height*0.78);
    musicNode.name = @"musicButtonNode";//how the node is identified later
    musicNode.zPosition = 1.0;
    [musicNode setScale:.39];
    
    return musicNode;
}

//TapToStart button
- (SKSpriteNode *)startButtonNode
{
    SKSpriteNode *startNode = [SKSpriteNode spriteNodeWithImageNamed:@"startButton.png"];
    startNode.position = CGPointMake(CGRectGetMidX(self.frame), CGRectGetMidY(self.frame)*1.);
    startNode.name = @"startButtonNode";//how the node is identified later
    startNode.zPosition = 1.0;
    [startNode setScale:.50];

    return startNode;
}

//TapToReset button
- (SKSpriteNode *)restartButtonNode
{
    SKSpriteNode *startNode = [SKSpriteNode spriteNodeWithImageNamed:@"restartButton.png"];
    startNode.position = CGPointMake(CGRectGetMidX(self.frame), CGRectGetMidY(self.frame)*0.7);
    startNode.name = @"restartButtonNode";//how the node is identified later
    startNode.zPosition = 1.0;
    [startNode setScale:.50];

    return startNode;
}

//Calibrate button (Text based)
- (SKLabelNode *)calibrateButtonNode
{
    SKLabelNode *calButton = [SKLabelNode labelNodeWithFontNamed:@"MarkerFelt-Wide"];
    calButton.text = @"Calibrate";
    calButton.fontSize = 30;
    calButton.fontColor = [SKColor whiteColor];
    calButton.position = CGPointMake(self.frame.size.width*0.2, self.frame.size.height*0.78);
    calButton.name = @"calibrateButtonNode";
    calButton.zPosition = 1.0;
    return calButton;
}

-(void) waitForRadomTime {
    NSInteger delay =  3.0/_moving.speed;
    [self runAction:[SKAction waitForDuration:delay]];
}

#pragma mark - Start Spawning

-(void) startSpawning {
    isGameInProgress = YES;
    if (isMusicEnabled) {
        if (_score <10)
            [gameSceneLoop play];
        else
            [gameSceneLoop2 play];
    }
    
    if (isHoverEnabled)
        _shark.physicsBody.mass = 0.1;
    else
        _shark.physicsBody.mass = 0.1;
    
    
    self.physicsWorld.gravity = CGVectorMake( 0.0, -1.0 );

    [self removeActionForKey:@"mineSpawn"];
    SKAction* spawn = [SKAction performSelector:@selector(spawnMines) onTarget:self];
    SKAction* delay = [SKAction waitForDuration:7.0/_moving.speed withRange:3.0/_moving.speed];
    SKAction* spawnThenDelay = [SKAction sequence:@[spawn, delay]];
    SKAction* spawnThenDelayForever = [SKAction repeatActionForever:spawnThenDelay];
    [self runAction:spawnThenDelayForever withKey:@"mineSpawn"];

    [self removeActionForKey:@"fishSpawn"];
    SKAction* spawnFish = [SKAction performSelector:@selector(spawnLittleFishes) onTarget:self];
    SKAction* delayFish = [SKAction waitForDuration:3.0/_moving.speed withRange:3./_moving.speed];
    SKAction* spawnThenDelayFish = [SKAction sequence:@[spawnFish, delayFish]];
    SKAction* spawnThenDelayFishForever = [SKAction repeatActionForever:spawnThenDelayFish];
    [self runAction:spawnThenDelayFishForever withKey:@"fishSpawn"];

    [self removeActionForKey:@"torpedoSpawn"];
    SKAction* spawnTorpedo = [SKAction performSelector:@selector(spawnTorpedos) onTarget:self];
    SKAction* delayTorpedo = [SKAction waitForDuration:4.0/_moving.speed withRange:4.0/_moving.speed];
    SKAction* spawnThenDelayTorpedo = [SKAction sequence:@[spawnTorpedo, delayTorpedo]];
    SKAction* spawnThenDelayTorpedoForever = [SKAction repeatActionForever:spawnThenDelayTorpedo];
    [self runAction:spawnThenDelayTorpedoForever withKey:@"torpedoSpawn"];

    [self removeActionForKey:@"barrelSpawn"];
    SKAction* spawnbarrel = [SKAction performSelector:@selector(spawnBarrles) onTarget:self];
    SKAction* delayBarrels = [SKAction waitForDuration:5.0/_moving.speed withRange:3/_moving.speed];
    SKAction* spawnThenDelayBarrels = [SKAction sequence:@[delayBarrels, spawnbarrel]];
    SKAction* spawnThenDelayBarrelForever = [SKAction repeatActionForever:spawnThenDelayBarrels];
    [self runAction:spawnThenDelayBarrelForever withKey:@"barrelSpawn"];

    [self removeActionForKey:@"bubbleSpawn"];
    SKAction* spawnBubbles = [SKAction performSelector:@selector(spawnBubbles) onTarget:self];
    SKAction* delayBubble = [SKAction waitForDuration:3.0/_moving.speed withRange:3.0/_moving.speed] ;
    SKAction* spawnThenDelayBubble = [SKAction sequence:@[spawnBubbles, delayBubble]];
    SKAction* spawnThenDelayBubblesForever = [SKAction repeatActionForever:spawnThenDelayBubble];
    [self runAction:spawnThenDelayBubblesForever withKey:@"bubbleSpawn"];
  
}

#pragma mark - Bullet generation

//-(void) startGeneratingBulletsWithDelay:(CGFloat)delayInterval {
//    
//    [self removeActionForKey:@"bullets"];
//    SKAction* spawn = [SKAction performSelector:@selector(spawnBullets) onTarget:self];
//    SKAction* delay = [SKAction waitForDuration:delayInterval/_moving.speed];
//    SKAction* spawnThenDelay = [SKAction sequence:@[spawn, delay]];
//    SKAction* spawnBulletThenDelayForever = [SKAction repeatActionForever:spawnThenDelay];
//    [self runAction:spawnBulletThenDelayForever withKey:@"bullets"];
//}

-(void)resetScene {
    
    [self addChild: [self startButtonNode]];
    
    if (!musicButton.parent) [self addChild: musicButton];
    if (!difficultyButton.parent) [self addChild: difficultyButton];

    if (isCameraAvailable) {
        if (!hoverButton.parent) [self addChild: hoverButton];
        [self addChild: [self calibrateButtonNode]];
    }
    
    self.physicsWorld.gravity = CGVectorMake( 0.0, 0.0 );
    [self removeActionForKey:@"mineSpawn"];
    [self removeActionForKey:@"fishSpawn"];
    [self removeActionForKey:@"torpedoSpawn"];

    // Move bird to original position and reset velocity
    _shark.position = CGPointMake(self.frame.size.width / 4, CGRectGetMidY(self.frame));
    _shark.physicsBody.velocity = CGVectorMake( 0, 0 );
    _shark.physicsBody.collisionBitMask = worldBoundaryCategory | worldBoundaryUpCategory| barrelCategory | mineCategory | torpedoCategory;
    _shark.speed = 1.0;
    _shark.zRotation = 0.0;
    
    while ([_moving childNodeWithName:@"fish"] ) {
        [[_moving childNodeWithName:@"fish"] removeFromParent];
    }
    while ([_moving childNodeWithName:@"mediumFish"] ) {
        [[_moving childNodeWithName:@"mediumFish"] removeFromParent];
    }
    while ([_moving childNodeWithName:@"mine"] ) {
        [[_moving childNodeWithName:@"mine"] removeFromParent];
    }
    while ([self childNodeWithName:@"torpedo"] ) {
        [[self childNodeWithName:@"torpedo"] removeFromParent];
    }
    while ([self childNodeWithName:@"barrel"] ) {
        [[self childNodeWithName:@"barrel"] removeFromParent];
    }

    
    // Reset _canRestart
    _canRestart = NO;
    
    if (numLivesLeft == 0) {
        numLivesLeft = totalNumLives;
        [self drawNumberOfLivesLeft:totalNumLives];

        // Reset score
        _score = 0;
        _scoreLabelNode.text = [NSString stringWithFormat:@"%ld", (long)_score];
    }
    
    // Restart animation
    if (isGameEasy)
        _moving.speed = 1;
    else
        _moving.speed = HARD_LEVEL_SPEED_FACTOR;
    
    if (_score > 10)
        _moving.speed = AFTER_10_SPEED_FACTOR*_moving.speed;

    
}

#pragma mark - Spawn Stuff

-(void)spawnBubbles {
//    NSInteger shouldSpawn = arc4random() % 5;
//    if (shouldSpawn <= 2)
    { // only spawn 3 out of 5 times
        [self runAction:bubbleSound];
        NSInteger XPos = arc4random() % (NSInteger)(self.size.width);
        SKSpriteNode *bubbleNode = [SKSpriteNode spriteNodeWithTexture:bubbleTexture];
        bubbleNode.position = CGPointMake(XPos, groundHeight);
        bubbleNode.zPosition = -10;
        
        bubbleNode.name = @"bubble";
        [bubbleNode runAction:_moveBubbleAndRemove];
        [self addChild:bubbleNode];
    }
}

-(void) spawnBarrles {
    if (_score < BARREL_SCORE)
        return;
//    NSInteger shouldSpawn = arc4random() % 5;
//    if (shouldSpawn <= 2)
    { // only spawn 3 out of 5 times
        
        NSInteger barrelType = arc4random() % barrelTextures.count;
        SKTexture *barrelTexture = barrelTextures[barrelType];
        NSInteger barrelXPos = arc4random() % (NSInteger(self.size.width) - NSInteger(barrelTexture.size.width)) + barrelTexture.size.width;
        NSLog(@"barrel xPos = %lu", barrelXPos);
        SKSpriteNode *barrelNode = [SKSpriteNode spriteNodeWithTexture:barrelTexture];
        barrelNode.zPosition = -10;
        barrelNode.name = @"barrel";
        barrelNode.position = CGPointMake(barrelXPos, self.size.height + barrelTexture.size.height);
        barrelNode.physicsBody = [SKPhysicsBody bodyWithRectangleOfSize:barrelTexture.size];
        barrelNode.physicsBody.dynamic = YES;
        barrelNode.physicsBody.categoryBitMask = barrelCategory;
        barrelNode.physicsBody.collisionBitMask = sharkCategory | worldBoundaryCategory | mineCategory;
        barrelNode.physicsBody.contactTestBitMask = sharkCategory | mineCategory;
        [self addChild:barrelNode];
        [self runAction:splashSound];
    }
}

-(void)spawnMines {
    if (_moving.speed == 0) {
        return;
    }
    NSInteger numLinks;
    if (isIPAD)
        numLinks = arc4random() % 10 + 7;
    else
        numLinks = arc4random() % 7 + 3;
    
    SKNode *chainNode = [SKNode node];
    chainNode.position = CGPointMake( self.frame.size.width + _chainTexture.size.width*chainScale, 0 );
    chainNode.zPosition = -10;
    for (int k=0; k<numLinks; k++)
    {
        SKSpriteNode* linkSprite = [SKSpriteNode spriteNodeWithTexture:_chainTexture];
        linkSprite.position = CGPointMake(0, k*_chainTexture.size.height*chainScale);
        [linkSprite setScale:chainScale];
        
        linkSprite.physicsBody = [SKPhysicsBody bodyWithRectangleOfSize:linkSprite.size];
        linkSprite.physicsBody.dynamic = NO;
        linkSprite.physicsBody.categoryBitMask = mineCategory;
        linkSprite.physicsBody.contactTestBitMask = sharkCategory;
        [chainNode addChild:linkSprite];
    }
    
    SKSpriteNode *mineHeadNode = [SKSpriteNode spriteNodeWithTexture:_goldMineTexture];
    mineHeadNode.position = CGPointMake(0, numLinks*_chainTexture.size.height*chainScale);
    
    mineHeadNode.physicsBody = [SKPhysicsBody bodyWithCircleOfRadius:_goldMineTexture.size.height/2.];
    mineHeadNode.physicsBody.dynamic = NO;
    mineHeadNode.physicsBody.categoryBitMask = worldCategory;
    mineHeadNode.physicsBody.contactTestBitMask = sharkCategory;

    [chainNode addChild:mineHeadNode];
    chainNode.name = @"mine";
    [chainNode runAction:_moveMineAndRemove];
    [_moving addChild:chainNode];

}

-(void)spawnLittleFishes {
    if (_moving.speed == 0) {
        return;
    }
    
    NSInteger fishType = arc4random() % fishTextures.count;
    NSInteger fishYPos = arc4random() % (NSInteger)(self.size.height- groundHeight - 15) +  groundHeight;
    
    
    SKSpriteNode *fishNode = [SKSpriteNode spriteNodeWithTexture:fishTextures[fishType]];
    fishNode.position = CGPointMake(self.frame.size.width + ((SKTexture *)fishTextures[fishType]).size.width/2, fishYPos);
    fishNode.zPosition = -10;
    
    fishNode.physicsBody = [SKPhysicsBody bodyWithCircleOfRadius:((SKTexture *)fishTextures[fishType]).size.height/2.];
    fishNode.physicsBody.dynamic = NO;
    fishNode.physicsBody.categoryBitMask = fishCategory;
    fishNode.physicsBody.contactTestBitMask = sharkCategory;
    
    if (fishType > 2)
        fishNode.name = @"mediumFish";
    else
        fishNode.name = @"fish";
    
    NSInteger r = arc4random() % 3;
    CGFloat fishDistanceToMove = self.frame.size.width + 1 * ((SKTexture *)fishTextures[0]).size.width;
    SKAction* movefishes = [SKAction moveByX:-fishDistanceToMove y:0 duration:speedScale*0.01/(2.5+r/1.5) * fishDistanceToMove];
    SKAction* removeFishes = [SKAction removeFromParent];
    SKAction *moveFishesAndRemove = [SKAction sequence:@[movefishes, removeFishes]];

    
    [fishNode runAction:moveFishesAndRemove];
    [_moving addChild:fishNode];
    
}


-(void)spawnTorpedos {
    if (_score < TORPEDO_SCORE)
        return;

        NSInteger YPos = arc4random() % (NSInteger)(self.size.height- groundHeight - 25) +  groundHeight;
        [self runAction:torpedoSound];
        SKSpriteNode *torpedoNode = [SKSpriteNode spriteNodeWithTexture:torpedoTexture];
        torpedoNode.position = CGPointMake(self.frame.size.width + torpedoTexture.size.width/2, YPos);
        torpedoNode.zPosition = 50;
        
        torpedoNode.physicsBody = [SKPhysicsBody bodyWithRectangleOfSize:torpedoTexture.size];
        torpedoNode.physicsBody.dynamic = YES;
        torpedoNode.physicsBody.categoryBitMask = torpedoCategory;
        torpedoNode.physicsBody.contactTestBitMask = sharkCategory | worldCategory;
        
        torpedoNode.name = @"torpedo";
        [_moving addChild:torpedoNode];
        torpedoNode.physicsBody.velocity = CGVectorMake(0, 0);
        [torpedoNode.physicsBody applyImpulse:CGVectorMake(-20, 3+5*(self.size.height/YPos))];
}


-(void) drawNumberOfLivesLeft:(NSInteger)numLives {
    for (int k=0; k < numLives; k++) {
        SKTexture* lifeTexture = [SKTexture textureWithImageNamed:@"heart"];
        lifeTexture.filteringMode = SKTextureFilteringNearest;
        
        SKSpriteNode* lifeIcon = [SKSpriteNode spriteNodeWithTexture:lifeTexture];
        [lifeIcon setScale:.70];
        
        lifeIcon.position = CGPointMake(self.frame.size.width*0.08 + k*lifeTexture.size.width*.80, self.frame.size.height*0.9);
        lifeIconArray[k] = lifeIcon;
        [self addChild:lifeIcon];

    }
}

#pragma mark - Update Speed

-(void) updateSpeed {
    
}

#pragma mark - initialization

-(id)initWithSize:(CGSize)size {
    if (self = [super initWithSize:size]) {
        
        musicButton = [self MusicButtonNode];
        difficultyButton = [self DifficultyButtonNode];
        hoverButton = [self hoverButtonNode];
        [self addChild: musicButton];
        [self addChild: difficultyButton];
        

        isTouchEnabled = YES;
        isMusicEnabled = YES;
        isHoverEnabled = YES;
        isGameEasy = YES;
        speedScale = 1.0;
        
        isIPAD = ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad);

        
        isGameInProgress = NO;
        
        crashSound = [SKAction playSoundFileNamed:@"whack4.m4a" waitForCompletion:NO];
        bigGulpSound = [SKAction playSoundFileNamed:@"swallow_trimmed.m4a" waitForCompletion:NO];
        gulpSound = [SKAction playSoundFileNamed:@"gulp.wav" waitForCompletion:NO];
        gameOverSound = [SKAction playSoundFileNamed:@"game_over.wav" waitForCompletion:NO];
        organSound = [SKAction playSoundFileNamed:@"organ.wav" waitForCompletion:YES];
        splashSound = [SKAction playSoundFileNamed:@"splash.wav" waitForCompletion:YES];
        torpedoSound = [SKAction playSoundFileNamed:@"Torpedo3.mp3" waitForCompletion:YES];
        popSound = [SKAction playSoundFileNamed:@"pop.m4a" waitForCompletion:YES];
        bubbleSound = [SKAction playSoundFileNamed:@"bubble.wav" waitForCompletion:YES];

        NSString *filePath = [[NSBundle mainBundle] pathForResource:@"Loopy_trimmed" ofType:@"m4a"];
        NSString *filePath2 = [[NSBundle mainBundle] pathForResource:@"HoverFlappy_level2" ofType:@"m4a"];
        NSError *error;
        
        gameSceneLoop2 = [[AVAudioPlayer alloc] initWithContentsOfURL:[NSURL fileURLWithPath:filePath2] error:&error];
        if (error) {
            NSLog(@"Error in audioPlayer: %@", [error localizedDescription]);
        } else {
            gameSceneLoop2.numberOfLoops = -1;
            [gameSceneLoop2 prepareToPlay];
        }

        gameSceneLoop = [[AVAudioPlayer alloc] initWithContentsOfURL:[NSURL fileURLWithPath:filePath] error:&error];
        if (error) {
            NSLog(@"Error in audioPlayer: %@", [error localizedDescription]);
        } else {
            gameSceneLoop.numberOfLoops = -1;
            [gameSceneLoop prepareToPlay];
        }
        
        
        // init camera
        isCameraAvailable = [HeadTrackingManager isSupported];
        if (isCameraAvailable) {
            [self addChild: hoverButton];
            [self addChild: [self calibrateButtonNode]];
            // Helper text or setup if needed
        }
        else
            isHoverEnabled = NO;
        
        totalNumLives = 3;
        numLivesLeft = totalNumLives;
        lifeIconArray = [[NSMutableArray alloc] initWithCapacity:totalNumLives];
        [self drawNumberOfLivesLeft:totalNumLives];
        
        /* Setup your scene here */
        _canRestart = NO;
        // Initialize label and create a label which holds the score
        _score = 0;
        _scoreLabelNode = [SKLabelNode labelNodeWithFontNamed:@"MarkerFelt-Wide"];
        _scoreLabelNode.position = CGPointMake( CGRectGetMidX( self.frame ), 7 * self.frame.size.height / 8 );
        _scoreLabelNode.zPosition = 100;
        _scoreLabelNode.text = [NSString stringWithFormat:@"%ld", (long)_score];
        [self addChild:_scoreLabelNode];

        self.physicsWorld.gravity = CGVectorMake( 0.0, -0.0 );
        self.physicsWorld.contactDelegate = self;
        
        _skyColor = [SKColor colorWithRed:113.0/255.0 green:197.0/255.0 blue:207.0/255.0 alpha:1.0];
//        _skyColor = [SKColor colorWithRed:120.0/255.0 green:127.0/255.0 blue:150/255.0 alpha:1.0];
        [self setBackgroundColor:_skyColor];
        
        _moving = [SKNode node];
        [self addChild:_moving];
        
        
        
        // Create shark
        ////////////////
        if (isIPAD)
            sharkScale = 1.;
        else
            sharkScale = 0.55;
        [self createSharkRegular];
        [self addChild:[self startButtonNode]];
        
        // Create ground
        //////////////////
        
        SKTexture* groundTexture = [SKTexture textureWithImageNamed:@"Ocean1_FG"];
//        groundTexture.filteringMode = SKTextureFilteringNearest;
        float groundScale;
        if (isIPAD)
            groundScale = 0.3*4 * 1.25;
        else
            groundScale = .15*4 * 1.25; // Increase scale by 25% to extend height
        
        // Logical height for game mechanics (keep roughly consistent with visual top relative to screen bottom, but adjusted for shift)
        // We shift sprite down by ~30pts. Visual top is at (Height - 30).
        groundHeight = groundTexture.size.height*groundScale - 30;

        SKAction* moveGroundSprite = [SKAction moveByX:-groundTexture.size.width*groundScale y:0 duration:speedScale*0.02 * groundTexture.size.width*groundScale];
        SKAction* resetGroundSprite = [SKAction moveByX:groundTexture.size.width*groundScale y:0 duration:0];
        SKAction* moveGroundSpritesForever = [SKAction repeatActionForever:[SKAction sequence:@[moveGroundSprite, resetGroundSprite]]];
        
        for( int i = 0; i < 2 + self.frame.size.width / ( groundTexture.size.width * groundScale ); ++i ) {
            SKSpriteNode* sprite = [SKSpriteNode spriteNodeWithTexture:groundTexture];
            [sprite setScale:groundScale];
            // Shift down by 30 points to cover the bottom safe area
            sprite.position = CGPointMake(i * sprite.size.width, sprite.size.height / 2 - 30);
            [sprite runAction:moveGroundSpritesForever];
            [_moving addChild:sprite];
        }
        
        // Create ground physics container
        
//        _ground = [SKNode node];
//        _ground.position = CGPointMake(0, groundTexture.size.height* groundScale/2);
//        _ground.physicsBody = [SKPhysicsBody bodyWithRectangleOfSize:CGSizeMake(self.frame.size.width, groundTexture.size.height * groundScale)];
//        _ground.physicsBody.dynamic = NO;
//        _ground.physicsBody.categoryBitMask = 0;
//        _ground.physicsBody.restitution = 0.5;
//        [self addChild:_ground];
        
        SKNode *worldBoundary = [SKNode node];
        worldBoundary.position = CGPointMake(0, groundTexture.size.height* groundScale/6);
        worldBoundary.physicsBody = [SKPhysicsBody bodyWithRectangleOfSize:CGSizeMake(self.frame.size.width, groundTexture.size.height * groundScale/3)];
        worldBoundary.physicsBody.dynamic = NO;
        worldBoundary.physicsBody.collisionBitMask = sharkCategory;
        worldBoundary.physicsBody.categoryBitMask = worldBoundaryCategory;
        [self addChild:worldBoundary];

        SKNode *worldBoundaryUP = [SKNode node];
        worldBoundaryUP.position = CGPointMake(0, self.frame.size.height+_shark.texture.size.height*sharkScale*.9);
        worldBoundaryUP.physicsBody = [SKPhysicsBody bodyWithRectangleOfSize:CGSizeMake(self.frame.size.width, 10)];
        worldBoundaryUP.physicsBody.dynamic = NO;
        worldBoundaryUP.physicsBody.collisionBitMask = sharkCategory;
        worldBoundaryUP.physicsBody.categoryBitMask = worldBoundaryUpCategory;
        [self addChild:worldBoundaryUP];

        
        // Create skyline
        /////////////////
        
        SKTexture* skylineTexture = [SKTexture textureWithImageNamed:@"Ocean2"];
//        skylineTexture.filteringMode = SKTextureFilteringNearest;
        float skylineScale;
        if (isIPAD)
            skylineScale = 1.5;
        else
            skylineScale = .63;
        
        // Ensure skyline covers the full screen height
        if (skylineTexture.size.height * skylineScale < self.size.height) {
            skylineScale = self.size.height / skylineTexture.size.height;
        }
        
        SKAction* moveSkylineSprite = [SKAction moveByX:-skylineTexture.size.width*skylineScale y:0 duration:speedScale*0.1 * skylineTexture.size.width*skylineScale];
        SKAction* resetSkylineSprite = [SKAction moveByX:skylineTexture.size.width*skylineScale y:0 duration:0];
        SKAction* moveSkylineSpritesForever = [SKAction repeatActionForever:[SKAction sequence:@[moveSkylineSprite, resetSkylineSprite]]];
        
        for( int i = 0; i < 2 + self.frame.size.width / ( skylineTexture.size.width * skylineScale ); ++i ) {
            SKSpriteNode* sprite = [SKSpriteNode spriteNodeWithTexture:skylineTexture];
            [sprite setScale:skylineScale];
            sprite.zPosition = -20;
//            sprite.position = CGPointMake(i * sprite.size.width, sprite.size.height / 2 + 0*groundTexture.size.height * groundScale);
            sprite.position = CGPointMake(i * sprite.size.width, self.size.height -  sprite.size.height / 2);
            [sprite runAction:moveSkylineSpritesForever];
            [_moving addChild:sprite];
        }

        
        // Create Mine
        ////////////////
        _chainTexture = [SKTexture textureWithImageNamed:@"Chain"];
        _goldMineTexture = [SKTexture textureWithImageNamed:@"goldMine"];
        chainScale = 1;
        
        CGFloat mineDistanceToMove = self.frame.size.width + 1 * _goldMineTexture.size.width;
        SKAction* moveMine = [SKAction moveByX:-mineDistanceToMove y:0 duration:speedScale*0.01*2. * mineDistanceToMove];
        SKAction* removeMine = [SKAction removeFromParent];
        _moveMineAndRemove = [SKAction sequence:@[moveMine, removeMine]];

        
        // Create fishes
        ////////////////
        fishTextures = @[[SKTexture textureWithImageNamed:@"SmallFishGreen"],
                         [SKTexture textureWithImageNamed:@"SmallFishRed"],
                         [SKTexture textureWithImageNamed:@"SmallFishYellow"],
                         [SKTexture textureWithImageNamed:@"MediumFishBrown"],
                         [SKTexture textureWithImageNamed:@"MediumFishGreen"],
                         [SKTexture textureWithImageNamed:@"MediumFishPurple"],

                         ];
        CGFloat fishDistanceToMove = self.frame.size.width + 1 * ((SKTexture *)fishTextures[0]).size.width;
        SKAction* movefishes = [SKAction moveByX:-fishDistanceToMove y:0 duration:speedScale*0.01/3. * fishDistanceToMove];
        SKAction* removeFishes = [SKAction removeFromParent];
        _moveFishesAndRemove = [SKAction sequence:@[movefishes, removeFishes]];

        // Create torpedo
        ////////////////
        torpedoTexture = [SKTexture textureWithImageNamed:@"Torpedo"];
        CGFloat torpedoDistanceToMove = self.frame.size.width + 1 * torpedoTexture.size.width;
        SKAction* moveTorpedos = [SKAction moveByX:-torpedoDistanceToMove y:0 duration:speedScale*0.01/3. * torpedoDistanceToMove];
        SKAction* removetorpedo = [SKAction removeFromParent];
        _moveTorpedoAndRemove = [SKAction sequence:@[moveTorpedos, removetorpedo]];

        // Create bubbles
        ////////////////
        bubbleTexture = [SKTexture textureWithImageNamed:@"Bubble"];
        CGFloat bubbleDistanceToMove = self.frame.size.height - groundHeight + bubbleTexture.size.height;
        SKAction* movebubbles = [SKAction moveBy:CGVectorMake(0, bubbleDistanceToMove) duration:speedScale*0.02/3. * bubbleDistanceToMove];
        SKAction* removeBubble = [SKAction removeFromParent];
        _moveBubbleAndRemove = [SKAction sequence:@[movebubbles, removeBubble]];

        
        // Create Barrels
        ////////////////
        barrelTextures = @[[SKTexture textureWithImageNamed:@"Barrel1"],
                           [SKTexture textureWithImageNamed:@"Barrel2"],
                           [SKTexture textureWithImageNamed:@"Barrel3"],
                           [SKTexture textureWithImageNamed:@"Barrel4"]];
        
//
//        if (isIPAD)
//            pipeScale = 0.25;
//        else
//            pipeScale = 0.13;
//        SKTexture *pipetexture = _pipeTexturesUp[0];
//        CGFloat distanceToMove = self.frame.size.width + 1 * pipetexture.size.width;
//        SKAction* movePipes = [SKAction moveByX:-distanceToMove y:0 duration:speedScale*0.2 * distanceToMove];
//        SKAction* removePipes = [SKAction removeFromParent];
//        _movePipesAndRemove = [SKAction sequence:@[movePipes, removePipes]];
//        


    }
    return self;
}

-(void) reverseGravity {
    self.physicsWorld.gravity = CGVectorMake( 0.0, 1.0 );
    if (isMusicEnabled)
        [self runAction:organSound withKey:@"organPlaying"];
    isTouchEnabled = YES;

}

#pragma mark - Shark Creation

-(void) createCrashedShark {
    CGPoint lastPosition = _shark.position;
    [_shark removeFromParent];

    _shark = [SKSpriteNode spriteNodeWithTexture:[SKTexture textureWithImageNamed:@"DeadShark"]];
    [_shark setScale:sharkScale];

    _shark.position = lastPosition;
    _shark.physicsBody = [SKPhysicsBody bodyWithCircleOfRadius:_shark.size.height / 2];
    _shark.physicsBody.dynamic = YES;
    _shark.physicsBody.allowsRotation = NO;
    _shark.physicsBody.restitution = 0.3;
    _shark.physicsBody.friction = 0.9;
    
    _shark.physicsBody.categoryBitMask = sharkCategory;
    _shark.physicsBody.collisionBitMask = worldCategory ;
    _shark.physicsBody.contactTestBitMask = worldCategory ;

    
    [self addChild:_shark];
    [self createSmokeAtPosition:_shark.position];
}

-(void) createSharkRegular {
    [_shark removeFromParent];
    
    sharkTexturesNormal = @[[SKTexture textureWithImageNamed:@"Shark1-01"],
                            [SKTexture textureWithImageNamed:@"Shark2-01"],
                            [SKTexture textureWithImageNamed:@"Shark3-01"],
                            [SKTexture textureWithImageNamed:@"Shark4-01"],
                            [SKTexture textureWithImageNamed:@"Shark5-01"],
                            [SKTexture textureWithImageNamed:@"Shark6-01"],
                            [SKTexture textureWithImageNamed:@"Shark8-01"],
                            [SKTexture textureWithImageNamed:@"Shark9-01"]];

    
    SKAction* flap = [SKAction repeatActionForever:[SKAction animateWithTextures:sharkTexturesNormal timePerFrame:0.15]];
    _shark = [SKSpriteNode spriteNodeWithTexture:sharkTexturesNormal[0]];
    [_shark setScale:sharkScale];
    
    _shark.position = CGPointMake(self.frame.size.width/5, CGRectGetMidY(self.frame));
    _shark.physicsBody = [SKPhysicsBody bodyWithCircleOfRadius:_shark.size.height / 2];
    _shark.physicsBody.dynamic = YES;
    _shark.physicsBody.allowsRotation = NO;
    _shark.physicsBody.restitution = 0.3;
    _shark.physicsBody.friction = 0.9;
    
    _shark.physicsBody.categoryBitMask = sharkCategory;
    _shark.physicsBody.collisionBitMask = worldBoundaryCategory | worldBoundaryUpCategory;
    _shark.physicsBody.contactTestBitMask = worldCategory;

    
    [self addChild:_shark];
    [self removeActionForKey:@"flapAfterCrash"];
    [_shark runAction:flap withKey:@"flapRegular"];
}

-(void) createSmokeAtPosition:(CGPoint)position {
    NSArray *smokeTextures = @[[SKTexture textureWithImageNamed:@"s1"],
                              [SKTexture textureWithImageNamed:@"s2"],
                              [SKTexture textureWithImageNamed:@"s3"],
                              [SKTexture textureWithImageNamed:@"s4"],
                               [SKTexture textureWithImageNamed:@"s5"]];
                               
    SKAction* explode = [SKAction animateWithTextures:smokeTextures timePerFrame:0.2];
    SKSpriteNode* smokeNode = [SKSpriteNode spriteNodeWithTexture:smokeTextures[0]];
    [smokeNode setScale:.05];
    
    smokeNode.position = position;
    [self addChild:smokeNode];
    SKAction* explodeThenRemove = [SKAction sequence:@[explode, [SKAction removeFromParent]]];
    [smokeNode runAction:explodeThenRemove];
}

-(void) createExplosionAtPosition:(CGPoint)position {
    NSArray *smokeTextures = @[[SKTexture textureWithImageNamed:@"exp1-01"],
                               [SKTexture textureWithImageNamed:@"exp2-01"],
                               [SKTexture textureWithImageNamed:@"exp3-01"],
                               [SKTexture textureWithImageNamed:@"exp4-01"],
                               [SKTexture textureWithImageNamed:@"exp5-01"],
                               [SKTexture textureWithImageNamed:@"exp6-01"],
                               [SKTexture textureWithImageNamed:@"exp7-01"]];
    
    SKAction* explode = [SKAction animateWithTextures:smokeTextures timePerFrame:0.1];
    SKSpriteNode* smokeNode = [SKSpriteNode spriteNodeWithTexture:smokeTextures[0]];
    [smokeNode setScale:.8];
    
    smokeNode.position = position;
    [self addChild:smokeNode];
    SKAction* explodeThenRemove = [SKAction sequence:@[explode, [SKAction removeFromParent]]];
    [smokeNode runAction:explodeThenRemove];
}





CGFloat clamp(CGFloat min, CGFloat max, CGFloat value) {
    if( value > max ) {
        return max;
    } else if( value < min ) {
        return min;
    } else {
        return value;
    }
}

-(void) removeContactObject:(SKPhysicsContact *)contact WithCategory:(uint32_t)category {
    if( ( contact.bodyA.categoryBitMask & category ) == category || ( contact.bodyB.categoryBitMask & category ) == category ) {
        // object has hit something
        if ( (contact.bodyA.categoryBitMask & category ) == category) {
            [contact.bodyA.node removeFromParent];
            [self createExplosionAtPosition:contact.bodyA.node.position];
        }
        if ( (contact.bodyB.categoryBitMask & category ) == category) {
            [contact.bodyB.node removeFromParent];
            [self createExplosionAtPosition:contact.bodyB.node.position];
        }
        [self runAction:popSound];
    }
}
#pragma mark - Contact

- (void)didBeginContact:(SKPhysicsContact *)contact {
    // Flash background if contact is detected
    if( _moving.speed > 0 ) {
            if( ( contact.bodyA.categoryBitMask & fishCategory ) == fishCategory || ( contact.bodyB.categoryBitMask & fishCategory ) == fishCategory ) {
                // Shark has ate a fish
                
                if ( (contact.bodyA.categoryBitMask & fishCategory ) == fishCategory) {
                    [contact.bodyA.node removeFromParent];
                    NSLog(@"Fish type: %@", contact.bodyA.node.name);
                    if ([contact.bodyA.node.name hasPrefix:@"medium"])
                        [self runAction:bigGulpSound];
                    else
                        [self runAction:gulpSound];
                }
                if ( (contact.bodyB.categoryBitMask & fishCategory ) == fishCategory) {
                    [contact.bodyB.node removeFromParent];
                    NSLog(@"Fish type: %@", contact.bodyB.node.name);
                    if ([contact.bodyB.node.name hasPrefix:@"medium"])
                        [self runAction:bigGulpSound];
                    else
                        [self runAction:gulpSound];
                }
                
                _score++;
                if ((_score > 20) || (_score > 50))
                    [self updateAchievements];
                
                if (_score == 10) {
                    _moving.speed = AFTER_10_SPEED_FACTOR*_moving.speed;
                }
                if (_score == 10)
                    if (isMusicEnabled) {
                        [gameSceneLoop stop];
                        [gameSceneLoop2 play];
                    }
                _scoreLabelNode.text = [NSString stringWithFormat:@"%ld", (long)_score];
                // Add a little visual feedback for the score increment
                [_scoreLabelNode runAction:[SKAction sequence:@[[SKAction scaleTo:1.5 duration:0.1], [SKAction scaleTo:1.0 duration:0.1]]]];
                [_shark runAction:[SKAction sequence:@[[SKAction scaleTo:1.2*sharkScale duration:0.2], [SKAction scaleTo:sharkScale duration:0.2]]]];
            } else {
                [self removeContactObject:contact WithCategory:barrelCategory];
                [self removeContactObject:contact WithCategory:torpedoCategory];
                
                if( ( contact.bodyA.categoryBitMask & sharkCategory ) == sharkCategory || ( contact.bodyB.categoryBitMask & sharkCategory ) == sharkCategory ) {
                    
                    [[UIApplication sharedApplication] setIdleTimerDisabled:NO];
                    
                    // Shark has collided with world or a bullet
                    isTouchEnabled = NO;
                    if (isHoverEnabled) {
                        // Stop tracking if needed
                    }
                    [self createCrashedShark];
                    if (isMusicEnabled) {
                        [gameSceneLoop stop];
                        [gameSceneLoop2 stop];
                    }
                    [self removeActionForKey:@"barrelSpawn"];
                    [self removeActionForKey:@"torpedoSpawn"];
                    [self removeActionForKey:@"bubbleSpawn"];
                    
                    isGameInProgress = NO;
                    [self runAction:crashSound];
                    
                    _moving.speed = 0;
                    
                    _shark.physicsBody.collisionBitMask = _shark.physicsBody.collisionBitMask;
                    
                    [_shark runAction:[SKAction rotateByAngle:M_PI * _shark.position.y * 0.01 duration:_shark.position.y * 0.003] completion:^{
                        _shark.speed = 0;
                    }];
                    
                    numLivesLeft--;
                    [ lifeIconArray[numLivesLeft] runAction:[SKAction removeFromParent] ];
                    if (numLivesLeft == 0) {
                        // Game over
                        [self updateAchievements];
                        [self showGameOver];
                        //[self runAction:gameOverSound];
                        //[self performSelector:@selector(restartGame) withObject:nil afterDelay:2];
                        isTouchEnabled = YES;
                    }
                    else {
                        //                [self performSelector:@selector(createDeadBird) withObject:nil afterDelay:.5];
                        [self performSelector:@selector(reverseGravity) withObject:nil afterDelay:1];
                        [self addChild: [self restartButtonNode]];
                    }
                    
                }
            }
    }
}

#pragma mark - Game Over & Leaderboard

-(void)showGameOver {
    SKLabelNode *gameOverLabel = [SKLabelNode labelNodeWithFontNamed:@"MarkerFelt-Wide"];
    gameOverLabel.text = @"GAME OVER";
    gameOverLabel.fontSize = 60;
    gameOverLabel.fontColor = [SKColor redColor];
    gameOverLabel.position = CGPointMake(CGRectGetMidX(self.frame), CGRectGetMidY(self.frame));
    gameOverLabel.zPosition = 100;
    gameOverLabel.name = @"GameOverLabel";
    [self addChild:gameOverLabel];
    
    [self runAction:[SKAction sequence:@[[SKAction scaleTo:1.2 duration:0.2], [SKAction scaleTo:1.0 duration:0.2]]]];
    [self runAction:gameOverSound];
    
    // Show leaderboard after delay
    [self performSelector:@selector(showLeaderboard) withObject:nil afterDelay:2.0];
}

-(void)showLeaderboard {
    GKGameCenterViewController *gcViewController = [[GKGameCenterViewController alloc] init];
    gcViewController.gameCenterDelegate = self;
    gcViewController.viewState = GKGameCenterViewControllerStateLeaderboards;
    gcViewController.leaderboardIdentifier = @"HoverSharkyLeaderBoardID"; // Ensure this matches constant in ScoresViewController if needed
    
    // Get the root view controller to present
    UIViewController *rootVC = self.view.window.rootViewController;
    [rootVC presentViewController:gcViewController animated:YES completion:nil];
}

- (void)gameCenterViewControllerDidFinish:(GKGameCenterViewController *)gameCenterViewController {
    [gameCenterViewController dismissViewControllerAnimated:YES completion:^{
        [self restartGame];
    }];
}

-(void) restartGame {
    [[self childNodeWithName:@"GameOverLabel"] removeFromParent]; // Remove label if it exists
    [self.scoreDelegate didFinishGameWithScore:_score];
    [[self childNodeWithName:@"restartButtonNode"] removeFromParent];
    [self resetScene];
    [self createSharkRegular];
}

-(void)update:(CFTimeInterval)currentTime {
    /* Called before each frame is rendered */
    if( _moving.speed > 0 ) {
        _shark.zRotation = clamp( -1, 0.5, _shark.physicsBody.velocity.dy * ( _shark.physicsBody.velocity.dy < 0 ? 0.003 : 0.001 ) );
        [self updateHeadTrackingControl];
    }
    
    //remove any nodes named "yourNode" that make it off screen
//    [self enumerateChildNodesWithName:@"torpedo" usingBlock:^(SKNode *node, BOOL *stop) {
//        
//        if (node.position.x < 0){
//            [node removeFromParent];
//        }
//    }];
    
    // Clamp shark position to screen bounds
    if (_shark) {
        CGPoint pos = _shark.position;
        CGSize size = _shark.size;
        CGFloat halfWidth = size.width / 2.0;
        CGFloat halfHeight = size.height / 2.0;
        
        BOOL didClamp = NO;
        if (pos.x < halfWidth) { pos.x = halfWidth; didClamp = YES; }
        if (pos.x > self.size.width - halfWidth) { pos.x = self.size.width - halfWidth; didClamp = YES; }
        if (pos.y < halfHeight) { pos.y = halfHeight; didClamp = YES; }
        if (pos.y > self.size.height - halfHeight) { pos.y = self.size.height - halfHeight; didClamp = YES; }
        
        if (didClamp) {
            _shark.position = pos;
            // Zero out velocity if we hit a wall to prevent sticking/jittering
            // _shark.physicsBody.velocity = CGVectorMake(0, 0); // Optional: might feel sticky
        }
    }
    
    // Update Calibration UI if active
    if (self.headTracker.headCalibrationStep != HeadCalibrationStepIdle) {
        if (!_calibrationLabel) {
            _calibrationLabel = [SKLabelNode labelNodeWithFontNamed:@"MarkerFelt-Wide"];
            _calibrationLabel.fontSize = 40;
            _calibrationLabel.fontColor = [SKColor yellowColor];
            _calibrationLabel.position = CGPointMake(CGRectGetMidX(self.frame), CGRectGetMidY(self.frame));
            _calibrationLabel.zPosition = 1000;
            [self addChild:_calibrationLabel];
            
            // Hide menu UI
            [[self childNodeWithName:@"startButtonNode"] setHidden:YES];
            [[self childNodeWithName:@"restartButtonNode"] setHidden:YES];
            [[self childNodeWithName:@"calibrateButtonNode"] setHidden:YES];
            [musicButton setHidden:YES];
            [difficultyButton setHidden:YES];
            [hoverButton setHidden:YES];
        }
        _calibrationLabel.text = self.headTracker.calibrationStatusMessage;
    } else {
        if (_calibrationLabel) {
            [_calibrationLabel removeFromParent];
            _calibrationLabel = nil;
            // Restore buttons if game not running
            if (!isGameInProgress) {
                [[self childNodeWithName:@"startButtonNode"] setHidden:NO];
                [[self childNodeWithName:@"restartButtonNode"] setHidden:NO];
                [[self childNodeWithName:@"calibrateButtonNode"] setHidden:NO];
                [musicButton setHidden:NO];
                [difficultyButton setHidden:NO];
                [hoverButton setHidden:NO];
            }
        }
    }
}

#pragma mark - Head Tracking Controls

-(void)updateHeadTrackingControl {
    if (_moving.speed > 0 && self.headTracker && self.headTracker.isTracking) {
        float headX = self.headTracker.headPositionX;
        float headY = self.headTracker.headPositionY;
        
        // Debug logging (throttled)
        static int logCounter = 0;
        if (logCounter++ % 60 == 0) {
            NSLog(@"HeadTracking: X=%.4f, Y=%.4f", headX, headY);
        }

        // Map Head X/Y to Velocity
        // Sensitivity factors - Increased significantly to respond to small head movements (in meters)
        float sensitivityX = self.headTracker.headSensitivityX; // Use calibrated sensitivity
        float sensitivityY = self.headTracker.headSensitivityY; // Use calibrated sensitivity
        
        // Invert X because moving head right (positive) should probably move shark right?
        // Let's assume standard coordinate system: Right is +X.
        // If shark is at left, we want to move it right.
        
        // Simply apply impulse or set velocity based on head offset from center (0,0)
        // Or mapping head position directly to screen position (absolute positioning) might be better?
        // The original code used optical flow (velocity). Let's try velocity based on head offset.
        
        float velX = headX * sensitivityX;
        float velY = headY * sensitivityY;
        
        // Clamp velocity
        // _shark.physicsBody.velocity = CGVectorMake(velX, velY); // Setting velocity directly gives absolute control feel
        
        // Or apply impulse
        // Resetting velocity to 0 and applying impulse makes it behave like "velocity control"
        // effectively canceling gravity each frame.
         _shark.physicsBody.velocity = CGVectorMake(0, 0);
         [_shark.physicsBody applyImpulse:CGVectorMake(velX, velY)];
    } else {
        // If tracking is lost or unsupported, maybe we should prevent it from falling?
        // For now, let physics take over (gravity), but boundaries will catch it.
        // Or we can set velocity to 0 to make it hover?
        if (_shark && _moving.speed > 0) {
             _shark.physicsBody.velocity = CGVectorMake(0, 0); // Hover if no tracking
        }
    }
}


-(void)updateAchievements{
    float progressPercentage = 0.0;
    NSArray *scoreAchievementIDs = @[@"SharkAchieved20Score_ID", @"SharkAchieved50Score_ID"];
    NSArray *scoreThreshold = @[@20, @50];
    NSMutableArray *scoreAchievements = [NSMutableArray array];
    
    GKAchievement *scoreAchievement = nil;

    for (int k=0; k < scoreAchievementIDs.count; k++) {
        NSNumber *threshold = scoreThreshold[k];
        progressPercentage = MIN(_score/threshold.integerValue*100., 100.);

        scoreAchievement = [[GKAchievement alloc] initWithIdentifier:scoreAchievementIDs[k]];
        scoreAchievement.percentComplete = progressPercentage;
        [scoreAchievements addObject:scoreAchievement];
    }

    [GKAchievement reportAchievements:scoreAchievements withCompletionHandler:^(NSError *error) {
        if (error != nil) {
            NSLog(@"%@", [error localizedDescription]);
        }
    }];

}

-(void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    /* Called when a touch begins */
    
    UITouch *touch = [touches anyObject];
    CGPoint location = [touch locationInNode:self];
    SKNode *node = [self nodeAtPoint:location];

    if ([node.name isEqualToString:@"startButtonNode"]) {
        [self startSpawning];
        [node removeFromParent];
        [[self childNodeWithName:@"calibrateButtonNode"] removeFromParent]; // Hide calibrate
        
        [musicButton removeFromParent];
        [difficultyButton removeFromParent];
        [hoverButton removeFromParent];
        [[self childNodeWithName:@"restartButtonNode"] removeFromParent];
        
        // Disable idle timer
         [[UIApplication sharedApplication] setIdleTimerDisabled:YES];
        return;
    }
    
    if ([node.name isEqualToString:@"restartButtonNode"]) {
        [self restartGame];
        [[UIApplication sharedApplication] setIdleTimerDisabled:YES];
        return;
    }
    
    if ([node.name isEqualToString:@"musicButtonNode"]) {
         // ... existing music toggle logic if any ...
         // For now, simple toggle
         isMusicEnabled = !isMusicEnabled;
         if (isMusicEnabled) {
              [node runAction:[SKAction setTexture:[SKTexture textureWithImageNamed:@"music.png"]]];
              [gameSceneLoop play];
         }
         else {
              [node runAction:[SKAction setTexture:[SKTexture textureWithImageNamed:@"no-music.png"]]];
             [gameSceneLoop stop];
             [gameSceneLoop2 stop];
         }
        // return; // Don't return, as touches often pass through
    }
    
    if ([node.name isEqualToString:@"DifficultyButtonNode"]) {
        isGameEasy = !isGameEasy;
        if (isGameEasy) {
            _moving.speed = 1.0;
            SKAction *changeImage = [SKAction setTexture:[SKTexture textureWithImageNamed:@"Easy.png"]];
            [difficultyButton runAction:changeImage];
        }
        else {
            _moving.speed = HARD_LEVEL_SPEED_FACTOR;
            SKAction *changeImage = [SKAction setTexture:[SKTexture textureWithImageNamed:@"Hard.png"]];
            [difficultyButton runAction:changeImage];
        }
        return;
    }

    if ([node.name isEqualToString:@"hoverButtonNode"]) {
        isHoverEnabled = !isHoverEnabled;
        if (isHoverEnabled) {
            SKAction *changeImage = [SKAction setTexture:[SKTexture textureWithImageNamed:@"hover.png"]];
            [hoverButton runAction:changeImage];
        }
        else {
            SKAction *changeImage = [SKAction setTexture:[SKTexture textureWithImageNamed:@"tap.png"]];
            [hoverButton runAction:changeImage];
        }
        return;
    }
    
    if ([node.name isEqualToString:@"calibrateButtonNode"]) {
        [self.headTracker startHeadCalibration];
        return;
    }
    
    // Check if we are in calibration mode
    if (self.headTracker.headCalibrationStep != HeadCalibrationStepIdle) {
        [self.headTracker nextHeadCalibrationStep];
        return;
    }

    if (isTouchEnabled) {
         _shark.physicsBody.velocity = CGVectorMake(0, 0);
         [_shark.physicsBody applyImpulse:CGVectorMake(0, 30)];
        [self runAction:splashSound];
    }
}

@end
