//
//  MyScene.m
//  HoverBird
//
//  Created by ramin on 6/14/14.
//  Copyright (c) 2014 maadotaa.com. All rights reserved.
//

#import <opencv2/highgui/ios.h>
#import "MyScene.h"
#import "DateScore.h"
#import <GameKit/GameKit.h>


using namespace cv;

#define HARD_LEVEL_SPEED_FACTOR 1.3
#define AFTER_10_SPEED_FACTOR 1.3

@interface MyScene ()<SKPhysicsContactDelegate, CvVideoCameraDelegate> {
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
    SKNode* _pipes;
    SKNode* _ground;
    BOOL _canRestart;
    SKLabelNode* _scoreLabelNode;
    NSInteger _score;
    Mat grayImage, prevGrayImage;
    NSMutableArray * scoreArray;
    NSMutableArray *lifeIconArray;
    NSInteger numLivesLeft;
    NSInteger totalNumLives;
    SKAction *crashSound;
    SKAction *scoreSound;
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
    
}
@property (nonatomic, strong) CvVideoCamera* videoCamera;

@end

@implementation MyScene

static const uint32_t sharkCategory = 1 << 0;
static const uint32_t worldCategory = 1 << 1;
static const uint32_t pipeCategory = 1 << 2;
static const uint32_t scoreCategory = 1 << 3;
static const uint32_t mineCategory = 1 << 4;
static const uint32_t fishCategory = 1 << 5;
static const uint32_t torpedoCategory = 1 << 6;
static NSInteger const kVerticalPipeGap = 100;

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

#pragma mark - Pipes generation

-(void) startGeneratingMines {
    isGameInProgress = YES;
    if (isMusicEnabled) {
        if (_score <10)
            [gameSceneLoop play];
        else
            [gameSceneLoop2 play];
    }
    
    if (isHoverEnabled)
        self.physicsWorld.gravity = CGVectorMake( 0.0, 0.0 );
    else
        self.physicsWorld.gravity = CGVectorMake( 0.0, -1.0 );
    
    [self removeActionForKey:@"mineSpawn"];
    SKAction* spawn = [SKAction performSelector:@selector(spawnMines) onTarget:self];
    SKAction* delay = [SKAction waitForDuration:7.0/_moving.speed];
    SKAction* spawnThenDelay = [SKAction sequence:@[spawn, delay]];
    SKAction* spawnThenDelayForever = [SKAction repeatActionForever:spawnThenDelay];
    [self runAction:spawnThenDelayForever withKey:@"mineSpawn"];

    [self removeActionForKey:@"fishSpawn"];
    SKAction* spawnFish = [SKAction performSelector:@selector(spawnLittleFishes) onTarget:self];
    SKAction* delayFish = [SKAction waitForDuration:3.0/_moving.speed];
    SKAction* spawnThenDelayFish = [SKAction sequence:@[spawnFish, delayFish]];
    SKAction* spawnThenDelayFishForever = [SKAction repeatActionForever:spawnThenDelayFish];
    [self runAction:spawnThenDelayFishForever withKey:@"fishSpawn"];

    [self removeActionForKey:@"torpedoSpawn"];
    SKAction* spawnTorpedo = [SKAction performSelector:@selector(spawnTorpedos) onTarget:self];
    SKAction* delayTorpedo = [SKAction waitForDuration:3.0/_moving.speed];
    SKAction* spawnThenDelayTorpedo = [SKAction sequence:@[spawnTorpedo, delayTorpedo]];
    SKAction* spawnThenDelayTorpedoForever = [SKAction repeatActionForever:spawnThenDelayTorpedo];
    [self runAction:spawnThenDelayTorpedoForever withKey:@"torpedoSpawn"];

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
    [self addChild: musicButton];
    [self addChild: difficultyButton];
    if (isCameraAvailable)
        [self addChild: hoverButton];
    
    self.physicsWorld.gravity = CGVectorMake( 0.0, 0.0 );
    [self removeActionForKey:@"mineSpawn"];
    [self removeActionForKey:@"fishSpawn"];
    [self removeActionForKey:@"torpedoSpawn"];

    // Move bird to original position and reset velocity
    _shark.position = CGPointMake(self.frame.size.width / 4, CGRectGetMidY(self.frame));
    _shark.physicsBody.velocity = CGVectorMake( 0, 0 );
    _shark.physicsBody.collisionBitMask = worldCategory | pipeCategory;
    _shark.speed = 1.0;
    _shark.zRotation = 0.0;
    // Remove all existing pipes
    [_pipes removeAllChildren];
    
    while ([_moving childNodeWithName:@"fish"] ) {
        [[_moving childNodeWithName:@"fish"] removeFromParent];
    }
    while ([_moving childNodeWithName:@"mine"] ) {
        [[_moving childNodeWithName:@"mine"] removeFromParent];
    }
    while ([_moving childNodeWithName:@"torpedo"] ) {
        [[_moving childNodeWithName:@"torpedo"] removeFromParent];
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

#pragma mark Spawn Stuff

-(void)spawnMines {
    if (_moving.speed == 0) {
        return;
    }
    
    NSInteger numLinks = arc4random() % 7 + 3;
    
    SKNode *chainNode = [SKNode node];
    chainNode.position = CGPointMake( self.frame.size.width + _chainTexture.size.width*chainScale, 0 );
    chainNode.zPosition = -10;
    for (int k=0; k<numLinks; k++) {
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
    mineHeadNode.physicsBody.categoryBitMask = mineCategory;
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
    
    fishNode.name = @"fish";
    [fishNode runAction:_moveFishesAndRemove];
    [_moving addChild:fishNode];
    
}


-(void)spawnTorpedos {
    if (_moving.speed == 0) {
        return;
    }
    
    NSInteger YPos = arc4random() % (NSInteger)(self.size.height- groundHeight - 25) +  groundHeight;
    
    
    SKSpriteNode *torpedoNode = [SKSpriteNode spriteNodeWithTexture:torpedoTexture];
    torpedoNode.position = CGPointMake(self.frame.size.width + torpedoTexture.size.width/2, YPos);
    torpedoNode.zPosition = -10;
    
    torpedoNode.physicsBody = [SKPhysicsBody bodyWithRectangleOfSize:torpedoTexture.size];
    torpedoNode.physicsBody.dynamic = NO;
    torpedoNode.physicsBody.categoryBitMask = torpedoCategory;
    torpedoNode.physicsBody.contactTestBitMask = sharkCategory;
    
    torpedoNode.name = @"torpedo";
    [torpedoNode runAction:_moveTorpedoAndRemove];
    [_moving addChild:torpedoNode];
    
}

-(void)spawnPipes {
    
    NSInteger pipeType = arc4random() % _pipeTexturesUp.count;
//    pipeType = 0; // justuse the first one for now
    SKTexture* pipeTextureUp = _pipeTexturesUp[pipeType];
    SKTexture* pipeTexturedown = _pipeTexturesDown[pipeType];
    
    SKNode* pipePair = [SKNode node];
    pipePair.position = CGPointMake( self.frame.size.width + pipeTextureUp.size.width*pipeScale, 0 );
    pipePair.zPosition = -10;
    
    CGFloat y = arc4random() % (NSInteger)( self.frame.size.height / 3 ) ;
    
    SKSpriteNode* pipe1 = [SKSpriteNode spriteNodeWithTexture:pipeTextureUp];
    [pipe1 setScale:pipeScale];
    pipe1.position = CGPointMake( 0, y );
    pipe1.physicsBody = [SKPhysicsBody bodyWithRectangleOfSize:pipe1.size];
    pipe1.physicsBody.dynamic = NO;
    pipe1.physicsBody.categoryBitMask = pipeCategory;
    pipe1.physicsBody.contactTestBitMask = sharkCategory;
//    pipe1.physicsBody.restitution = 0.1;
    
    [pipePair addChild:pipe1];
    
    float distanceScale = (_score > 20) ? 1.2:1.0;
    distanceScale = (_score > 50) ? 1.3:1.2;
    
//    distanceScale = MIN(15.0*_score/100. + 1., 1.6);
    
    if (!isGameEasy)
        distanceScale *= 1.2;
    
    SKSpriteNode* pipe2 = [SKSpriteNode spriteNodeWithTexture:pipeTexturedown];
    [pipe2 setScale:pipeScale];
    pipe2.position = CGPointMake( 0, y + pipe1.size.height + kVerticalPipeGap/distanceScale );
    pipe2.physicsBody = [SKPhysicsBody bodyWithRectangleOfSize:pipe2.size];
    pipe2.physicsBody.dynamic = NO;
    pipe2.physicsBody.categoryBitMask = pipeCategory;
    pipe2.physicsBody.contactTestBitMask = sharkCategory;
    
    [pipePair addChild:pipe2];
    
    SKNode* contactNode = [SKNode node];
    contactNode.position = CGPointMake( pipe1.size.width + _shark.size.width / 2, CGRectGetMidY( self.frame ) );
    contactNode.physicsBody = [SKPhysicsBody bodyWithRectangleOfSize:CGSizeMake( pipe2.size.width, self.frame.size.height )];
    contactNode.physicsBody.dynamic = NO;
    contactNode.physicsBody.categoryBitMask = scoreCategory;
    contactNode.physicsBody.contactTestBitMask = sharkCategory;
    contactNode.name = @"scoreNode";
    [pipePair addChild:contactNode];
    
    pipePair.name = @"pipePair";
    
    [pipePair runAction:_movePipesAndRemove];
    
    [_pipes addChild:pipePair];
}

-(void) drawNumberOfLivesLeft:(NSInteger)numLives {
    for (int k=0; k < numLives; k++) {
        SKTexture* lifeTexture = [SKTexture textureWithImageNamed:@"heart"];
        lifeTexture.filteringMode = SKTextureFilteringNearest;
        
        SKSpriteNode* lifeIcon = [SKSpriteNode spriteNodeWithTexture:lifeTexture];
        [lifeIcon setScale:.70];
        
        lifeIcon.position = CGPointMake(self.frame.size.width*0.08 + k*lifeTexture.size.width*.80, self.frame.size.height*0.9);
//        lifeIcon.physicsBody = [SKPhysicsBody bodyWithCircleOfRadius:lifeIcon.size.height / 2];
//        lifeIcon.physicsBody.dynamic = NO;
//        lifeIcon.physicsBody.allowsRotation = NO;
        lifeIconArray[k] = lifeIcon;
        [self addChild:lifeIcon];
        
        //    lifeIcon.physicsBody.categoryBitMask = sharkCategory;
        //    _shark.physicsBody.collisionBitMask = worldCategory | pipeCategory;
        //    _shark.physicsBody.contactTestBitMask = worldCategory | pipeCategory;
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
        scoreSound = [SKAction playSoundFileNamed:@"score.wav" waitForCompletion:NO];
        gameOverSound = [SKAction playSoundFileNamed:@"game_over.wav" waitForCompletion:NO];
        organSound = [SKAction playSoundFileNamed:@"organ.wav" waitForCompletion:YES];
//        bgMusic = [SKAction playSoundFileNamed:@"Loopy_trimmed.m4a" waitForCompletion:YES];

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
        isCameraAvailable = [UIImagePickerController isCameraDeviceAvailable:UIImagePickerControllerCameraDeviceFront];
//        isCameraAvailable = YES; // DEBUG
        if (isCameraAvailable) {
            [self addChild: hoverButton];

            self.videoCamera = [[CvVideoCamera alloc] init];
            self.videoCamera.delegate = self;
            self.videoCamera.defaultAVCaptureDevicePosition = AVCaptureDevicePositionFront;
            self.videoCamera.defaultAVCaptureSessionPreset = AVCaptureSessionPreset352x288;
            //                                AVCaptureSessionPreset640x480;
            self.videoCamera.defaultAVCaptureVideoOrientation =
            AVCaptureVideoOrientationPortrait;
            self.videoCamera.defaultFPS = 15;
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
        [self setBackgroundColor:_skyColor];
        
        _moving = [SKNode node];
        [self addChild:_moving];
        
        _pipes = [SKNode node];
        [_moving addChild:_pipes];
        
        // Create ground
        //////////////////
        
        SKTexture* groundTexture = [SKTexture textureWithImageNamed:@"Ocean1_FG"];
//        groundTexture.filteringMode = SKTextureFilteringNearest;
        float groundScale;
        if (isIPAD)
            groundScale = 0.3*4;
        else
            groundScale = .15*4;
        
        groundHeight = groundTexture.size.height*groundScale;

        SKAction* moveGroundSprite = [SKAction moveByX:-groundTexture.size.width*groundScale y:0 duration:speedScale*0.02 * groundTexture.size.width*groundScale];
        SKAction* resetGroundSprite = [SKAction moveByX:groundTexture.size.width*groundScale y:0 duration:0];
        SKAction* moveGroundSpritesForever = [SKAction repeatActionForever:[SKAction sequence:@[moveGroundSprite, resetGroundSprite]]];
        
        for( int i = 0; i < 2 + self.frame.size.width / ( groundTexture.size.width * groundScale ); ++i ) {
            SKSpriteNode* sprite = [SKSpriteNode spriteNodeWithTexture:groundTexture];
            [sprite setScale:groundScale];
            sprite.position = CGPointMake(i * sprite.size.width, sprite.size.height / 2);
            [sprite runAction:moveGroundSpritesForever];
            [_moving addChild:sprite];
        }
        
        // Create ground physics container
        
        _ground = [SKNode node];
        _ground.position = CGPointMake(0, groundTexture.size.height* groundScale/2);
        _ground.physicsBody = [SKPhysicsBody bodyWithRectangleOfSize:CGSizeMake(self.frame.size.width, groundTexture.size.height * groundScale)];
        _ground.physicsBody.dynamic = NO;
        _ground.physicsBody.categoryBitMask = worldCategory;
//    _ground.physicsBody.contactTestBitMask = sharkCategory;
        _ground.physicsBody.restitution = 0.5;

        [self addChild:_ground];
        
        // Create skyline
        /////////////////
        
        SKTexture* skylineTexture = [SKTexture textureWithImageNamed:@"Ocean2"];
//        skylineTexture.filteringMode = SKTextureFilteringNearest;
        float skylineScale = 0.63;
        
        SKAction* moveSkylineSprite = [SKAction moveByX:-skylineTexture.size.width*skylineScale y:0 duration:speedScale*0.1 * skylineTexture.size.width*skylineScale];
        SKAction* resetSkylineSprite = [SKAction moveByX:skylineTexture.size.width*skylineScale y:0 duration:0];
        SKAction* moveSkylineSpritesForever = [SKAction repeatActionForever:[SKAction sequence:@[moveSkylineSprite, resetSkylineSprite]]];
        
        for( int i = 0; i < 2 + self.frame.size.width / ( skylineTexture.size.width * skylineScale ); ++i ) {
            SKSpriteNode* sprite = [SKSpriteNode spriteNodeWithTexture:skylineTexture];
            [sprite setScale:skylineScale];
            sprite.zPosition = -20;
            sprite.position = CGPointMake(i * sprite.size.width, sprite.size.height / 2 + 0*groundTexture.size.height * groundScale);
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
        SKAction* movefishes = [SKAction moveByX:-fishDistanceToMove y:0 duration:speedScale*0.01/2. * fishDistanceToMove];
        SKAction* removeFishes = [SKAction removeFromParent];
        _moveFishesAndRemove = [SKAction sequence:@[movefishes, removeFishes]];

        // Create torpedo
        ////////////////
        torpedoTexture = [SKTexture textureWithImageNamed:@"Torpedo"];
        CGFloat torpedoDistanceToMove = self.frame.size.width + 1 * torpedoTexture.size.width;
        SKAction* moveTorpedos = [SKAction moveByX:-torpedoDistanceToMove y:0 duration:speedScale*0.01/3. * torpedoDistanceToMove];
        SKAction* removetorpedo = [SKAction removeFromParent];
        _moveTorpedoAndRemove = [SKAction sequence:@[moveTorpedos, removetorpedo]];
        


        if (isIPAD)
            pipeScale = 0.25;
        else
            pipeScale = 0.13;
        SKTexture *pipetexture = _pipeTexturesUp[0];
        CGFloat distanceToMove = self.frame.size.width + 1 * pipetexture.size.width;
        SKAction* movePipes = [SKAction moveByX:-distanceToMove y:0 duration:speedScale*0.2 * distanceToMove];
        SKAction* removePipes = [SKAction removeFromParent];
        _movePipesAndRemove = [SKAction sequence:@[movePipes, removePipes]];
        

        
        // Create shark
        ////////////////
        [self createSharkRegular];
        /*
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
        [_shark setScale:.7];
        
        _shark.position = CGPointMake(self.frame.size.width/5, CGRectGetMidY(self.frame));
        _shark.physicsBody = [SKPhysicsBody bodyWithCircleOfRadius:_shark.size.height / 2];
        _shark.physicsBody.dynamic = YES;
        _shark.physicsBody.allowsRotation = NO;
        _shark.physicsBody.restitution = 0.3;
        _shark.physicsBody.friction = 0.9;
        
        _shark.physicsBody.categoryBitMask = sharkCategory;
        _shark.physicsBody.collisionBitMask = worldCategory | pipeCategory;
        _shark.physicsBody.contactTestBitMask = worldCategory | pipeCategory;
        
        
        [self addChild:_shark];
        [_shark runAction:flap withKey:@"flapRegular"];
        */
        
        [self addChild:[self startButtonNode]];
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
    [_shark setScale:.7];

    _shark.position = lastPosition;
    _shark.physicsBody = [SKPhysicsBody bodyWithCircleOfRadius:_shark.size.height / 2];
    _shark.physicsBody.dynamic = YES;
    _shark.physicsBody.allowsRotation = NO;
    _shark.physicsBody.restitution = 0.3;
    _shark.physicsBody.friction = 0.9;
    
    _shark.physicsBody.categoryBitMask = sharkCategory;
    _shark.physicsBody.collisionBitMask = worldCategory | pipeCategory;
    _shark.physicsBody.contactTestBitMask = worldCategory | pipeCategory;

    
    [self addChild:_shark];
    [self createSmoke];
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
    [_shark setScale:.7];
    
    _shark.position = CGPointMake(self.frame.size.width/5, CGRectGetMidY(self.frame));
    _shark.physicsBody = [SKPhysicsBody bodyWithCircleOfRadius:_shark.size.height / 2];
    _shark.physicsBody.dynamic = YES;
    _shark.physicsBody.allowsRotation = NO;
    _shark.physicsBody.restitution = 0.3;
    _shark.physicsBody.friction = 0.9;
    
    _shark.physicsBody.categoryBitMask = sharkCategory;
    _shark.physicsBody.collisionBitMask = worldCategory | pipeCategory;
    _shark.physicsBody.contactTestBitMask = worldCategory | pipeCategory;

    
    [self addChild:_shark];
    [self removeActionForKey:@"flapAfterCrash"];
    [_shark runAction:flap withKey:@"flapRegular"];
}

-(void) createSmoke {
    NSArray *smokeTextures = @[[SKTexture textureWithImageNamed:@"s1"],
                              [SKTexture textureWithImageNamed:@"s2"],
                              [SKTexture textureWithImageNamed:@"s3"],
                              [SKTexture textureWithImageNamed:@"s4"],
                               [SKTexture textureWithImageNamed:@"s5"]];
                               
    SKAction* explode = [SKAction animateWithTextures:smokeTextures timePerFrame:0.2];
    SKSpriteNode* smokeNode = [SKSpriteNode spriteNodeWithTexture:smokeTextures[0]];
    [smokeNode setScale:.05];
    
    smokeNode.position = _shark.position;
    [self addChild:smokeNode];
    SKAction* explodeThenRemove = [SKAction sequence:@[explode, [SKAction removeFromParent]]];
    [smokeNode runAction:explodeThenRemove];
}



#pragma mark - Touch handling

-(void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    
    if (!isTouchEnabled) {
        return;
    }
    
    UITouch *touch = [touches anyObject];
    CGPoint location = [touch locationInNode:self];
    SKNode *node = [self nodeAtPoint:location];
    
    if ([node.name isEqualToString:@"musicButtonNode"]) {
        isMusicEnabled = !isMusicEnabled;
        if (isMusicEnabled) {
            SKAction *changeImage = [SKAction setTexture:[SKTexture textureWithImageNamed:@"music.png"]];
            [musicButton runAction:changeImage];
        }
        else {
            SKAction *changeImage = [SKAction setTexture:[SKTexture textureWithImageNamed:@"no-music.png"]];
            [musicButton runAction:changeImage];
        }
        return;
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
    
    //if start button touched, bring the pipes and gravity
    if ([node.name isEqualToString:@"startButtonNode"]) {
        [[UIApplication sharedApplication] setIdleTimerDisabled:YES];
        [node removeFromParent];
        [musicButton removeFromParent];
        [hoverButton removeFromParent];
        [difficultyButton removeFromParent];
        
        if (_score >= 10) {
//            [self startGeneratingBulletsWithDelay:2.0];
        }
        if (_score >= 20) {
//            [self startGeneratingBulletsWithDelay:1.0];
            _bulletTexture = [SKTexture textureWithImageNamed:@"Bullet-A"];
        }

        
        [self startGeneratingMines];
        if (isHoverEnabled)
            [self.videoCamera start];

        isGameInProgress = YES;

//        _shark.physicsBody.velocity = CGVectorMake(0, 0);
//        [_shark.physicsBody applyImpulse:CGVectorMake(0, 12)];

    } else if ([node.name isEqualToString:@"restartButtonNode"])
    {
        [node removeFromParent];
        [self removeActionForKey:@"organPlaying"];
        
        [self resetScene];
        [self createSharkRegular];
    } else if (isGameInProgress)
    {
        _shark.physicsBody.velocity = CGVectorMake(0, 0);
        [_shark.physicsBody applyImpulse:CGVectorMake(0, 10)];
    }
    
    
    
    /* Called when a touch begins */
//    if( _moving.speed > 0 ) {
//        _shark.physicsBody.velocity = CGVectorMake(0, 0);
//        [_shark.physicsBody applyImpulse:CGVectorMake(0, 6)];
//    } else if( _canRestart ) {
//        [self resetScene];
//    }
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



#pragma mark - Contact

- (void)didBeginContact:(SKPhysicsContact *)contact {
    // Flash background if contact is detected
    if( _moving.speed > 0 ) {
        
        if( ( contact.bodyA.categoryBitMask & fishCategory ) == fishCategory || ( contact.bodyB.categoryBitMask & fishCategory ) == fishCategory ) {
            // Bird has contact with score entity
            
            if ( (contact.bodyA.categoryBitMask & fishCategory ) == fishCategory) {
                [contact.bodyA.node removeFromParent];
            }
            if ( (contact.bodyB.categoryBitMask & fishCategory ) == fishCategory) {
                [contact.bodyB.node removeFromParent];
            }
            
            _score++;
            if ((_score > 20) || (_score > 50))
                [self updateAchievements];
            if (_score == 10) {
                _moving.speed = AFTER_10_SPEED_FACTOR*_moving.speed;
//                [self startGeneratingBulletsWithDelay:2.0];
            }
            if (_score == 10)
                if (isMusicEnabled) {
                    [gameSceneLoop stop];
                    [gameSceneLoop2 play];
                }
            if (_score == 20) {
//                _bulletTexture = [SKTexture textureWithImageNamed:@"Bullet-A"];
//                [self startGeneratingBulletsWithDelay:1.0];
            }

            
            _scoreLabelNode.text = [NSString stringWithFormat:@"%ld", (long)_score];
            // Add a little visual feedback for the score increment
            [_scoreLabelNode runAction:[SKAction sequence:@[scoreSound, [SKAction scaleTo:1.5 duration:0.1], [SKAction scaleTo:1.0 duration:0.1]]]];
        } else {
            [[UIApplication sharedApplication] setIdleTimerDisabled:NO];

            // Bird has collided with world or a bullet
            isTouchEnabled = NO;
            if (isHoverEnabled)
                [self.videoCamera stop];
            [self createCrashedShark];
            if (isMusicEnabled) {
                [gameSceneLoop stop];
                [gameSceneLoop2 stop];
            }
        
            isGameInProgress = NO;
            [self runAction:crashSound];
            
            _moving.speed = 0;
            
            _shark.physicsBody.collisionBitMask = worldCategory;
            
            [_shark runAction:[SKAction rotateByAngle:M_PI * _shark.position.y * 0.01 duration:_shark.position.y * 0.003] completion:^{
                _shark.speed = 0;
            }];
            

            
//            [self removeActionForKey:@"flash"];
//            [self runAction:[SKAction sequence:@[[SKAction repeatAction:[SKAction sequence:@[[SKAction runBlock:^{
//                self.backgroundColor = [SKColor redColor];
//            }], [SKAction waitForDuration:0.05], [SKAction runBlock:^{
//                self.backgroundColor = _skyColor;
//            }], [SKAction waitForDuration:0.05]]] count:4], [SKAction runBlock:^{
//                _canRestart = YES;
//            }]]] withKey:@"flash"];
            
            numLivesLeft--;
            [ lifeIconArray[numLivesLeft] runAction:[SKAction removeFromParent] ];
            if (numLivesLeft == 0) {
                // Game over
                [self runAction:gameOverSound];
                [self performSelector:@selector(restartGame) withObject:nil afterDelay:2];
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

-(void) restartGame {
    [self.scoreDelegate didFinishGameWithScore:_score];
//    [[self childNodeWithName:@"restartButtonNode"] removeFromParent];
    [self resetScene];
    [self createSharkRegular];

}

-(void)update:(CFTimeInterval)currentTime {
    /* Called before each frame is rendered */
    if( _moving.speed > 0 ) {
        _shark.zRotation = clamp( -1, 0.5, _shark.physicsBody.velocity.dy * ( _shark.physicsBody.velocity.dy < 0 ? 0.003 : 0.001 ) );
    }
}

#pragma mark - opencv callback

- (void)processImage:(Mat&)image
{
    Mat filteredImage;
    
    cvtColor(image, grayImage, COLOR_BGR2GRAY);
    
    Mat cflow, flow;
    pyrDown(grayImage, grayImage);
    pyrDown(grayImage, grayImage);
    
    if (prevGrayImage.data)
    {
        calcOpticalFlowFarneback(prevGrayImage, grayImage, flow, 0.5, 3, 15, 3, 5, 1.2, 0);
        Scalar meanFlow = mean(flow);
//        NSLog(@"mean flowmeanFlow.val[1] = %f, %f", meanFlow.val[0], meanFlow.val[1]);
        
//        if( _moving.speed >0  ) {
//            if (meanFlow.val[1] < -1.) {
//                _shark.physicsBody.velocity = CGVectorMake(0, 0);
//                [_shark.physicsBody applyImpulse:CGVectorMake(meanFlow.val[0]*0, 9)];
//            }
//        }

        
        if( _moving.speed > 0 ) {
            _shark.physicsBody.velocity = CGVectorMake(0, 0);
            if (isIPAD)
                [_shark.physicsBody applyImpulse:CGVectorMake(meanFlow.val[1]*(-5), -meanFlow.val[0]*5)];
            else
                [_shark.physicsBody applyImpulse:CGVectorMake(meanFlow.val[1]*(-8), -meanFlow.val[0]*8)];
        }
    }
    std::swap(prevGrayImage, grayImage);

}


-(void)updateAchievements{
    float progressPercentage = 0.0;
    NSArray *scoreAchievementIDs = @[@"Achieved20Score_ID", @"Achieved50Score_ID"];
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


@end