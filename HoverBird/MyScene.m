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
#define AFTER_10_SPEED_FACTOR 1.2

@interface MyScene ()<SKPhysicsContactDelegate, CvVideoCameraDelegate> {
    SKSpriteNode* _bird;
    SKColor* _skyColor;
    NSMutableArray* _pipeTexturesUp;
    NSMutableArray* _pipeTexturesDown;
    SKTexture* _bulletTexture;
    float bulletScale;
    SKAction* _movePipesAndRemove;
    SKAction* _moveBulletAndRemove;
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
}
@property (nonatomic, strong) CvVideoCamera* videoCamera;

@end

@implementation MyScene

static const uint32_t birdCategory = 1 << 0;
static const uint32_t worldCategory = 1 << 1;
static const uint32_t pipeCategory = 1 << 2;
static const uint32_t scoreCategory = 1 << 3;
static const uint32_t bulletCategory = 1 << 4;
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

-(void) startGeneratingPipes {
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
        self.physicsWorld.gravity = CGVectorMake( 0.0, -5.0 );
    
    [self removeActionForKey:@"pipes"];
    SKAction* spawn = [SKAction performSelector:@selector(spawnPipes) onTarget:self];
    SKAction* delay = [SKAction waitForDuration:2.0/_moving.speed];
    SKAction* spawnThenDelay = [SKAction sequence:@[spawn, delay]];
    SKAction* spawnThenDelayForever = [SKAction repeatActionForever:spawnThenDelay];
    [self runAction:spawnThenDelayForever withKey:@"pipes"];
}

#pragma mark - Bullet generation

-(void) startGeneratingBulletsWithDelay:(CGFloat)delayInterval {
    
    [self removeActionForKey:@"bullets"];
    SKAction* spawn = [SKAction performSelector:@selector(spawnBullets) onTarget:self];
    SKAction* delay = [SKAction waitForDuration:delayInterval/_moving.speed];
    SKAction* spawnThenDelay = [SKAction sequence:@[spawn, delay]];
    SKAction* spawnBulletThenDelayForever = [SKAction repeatActionForever:spawnThenDelay];
    [self runAction:spawnBulletThenDelayForever withKey:@"bullets"];
}

-(void)resetScene {
    
    [self addChild: [self startButtonNode]];
    [self addChild: musicButton];
    [self addChild: difficultyButton];
    if (isCameraAvailable)
        [self addChild: hoverButton];
    
    self.physicsWorld.gravity = CGVectorMake( 0.0, 0.0 );
    [self removeActionForKey:@"pipes"];
    [self removeActionForKey:@"bullets"];

    // Move bird to original position and reset velocity
    _bird.position = CGPointMake(self.frame.size.width / 4, CGRectGetMidY(self.frame));
    _bird.physicsBody.velocity = CGVectorMake( 0, 0 );
    _bird.physicsBody.collisionBitMask = worldCategory | pipeCategory;
    _bird.speed = 1.0;
    _bird.zRotation = 0.0;
    // Remove all existing pipes
    [_pipes removeAllChildren];
    while ([_moving childNodeWithName:@"bullet"] ) {
        [[_moving childNodeWithName:@"bullet"] removeFromParent];
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

#pragma mark Spawn Bullets and Pipes

-(void)spawnBullets {
//    CGFloat range = 0.5;
//    CGFloat y = arc4random() % (NSInteger)( self.frame.size.height*range )+ self.frame.size.height*(0.65-range/2.);
    CGFloat y = arc4random() % (NSInteger)( self.frame.size.height );
    
    SKSpriteNode* bulletSprite = [SKSpriteNode spriteNodeWithTexture:_bulletTexture];
    [bulletSprite setScale:bulletScale];
    bulletSprite.position = CGPointMake( self.frame.size.width + _bulletTexture.size.width*bulletScale, y );
    bulletSprite.physicsBody = [SKPhysicsBody bodyWithCircleOfRadius:bulletSprite.size.height*0.5 ];
    bulletSprite.physicsBody.dynamic = NO;
    bulletSprite.physicsBody.categoryBitMask = bulletCategory;
    bulletSprite.physicsBody.contactTestBitMask = birdCategory;

    [bulletSprite runAction:_moveBulletAndRemove];
    bulletSprite.name = @"bullet";
    [_moving addChild:bulletSprite];

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
    pipe1.physicsBody.contactTestBitMask = birdCategory;
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
    pipe2.physicsBody.contactTestBitMask = birdCategory;
    
    [pipePair addChild:pipe2];
    
    SKNode* contactNode = [SKNode node];
    contactNode.position = CGPointMake( pipe1.size.width + _bird.size.width / 2, CGRectGetMidY( self.frame ) );
    contactNode.physicsBody = [SKPhysicsBody bodyWithRectangleOfSize:CGSizeMake( pipe2.size.width, self.frame.size.height )];
    contactNode.physicsBody.dynamic = NO;
    contactNode.physicsBody.categoryBitMask = scoreCategory;
    contactNode.physicsBody.contactTestBitMask = birdCategory;
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
        
        //    lifeIcon.physicsBody.categoryBitMask = birdCategory;
        //    _bird.physicsBody.collisionBitMask = worldCategory | pipeCategory;
        //    _bird.physicsBody.contactTestBitMask = worldCategory | pipeCategory;
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

//        self.physicsWorld.gravity = CGVectorMake( 0.0, -5.0 );
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
        
        SKTexture* groundTexture = [SKTexture textureWithImageNamed:@"ground_flower"];
//        groundTexture.filteringMode = SKTextureFilteringNearest;
        float groundScale;
        if (isIPAD)
            groundScale = 0.3;
        else
            groundScale = .15;

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
    //    _ground.physicsBody.contactTestBitMask = birdCategory;
        _ground.physicsBody.restitution = 0.5;

        [self addChild:_ground];
        
        // Create skyline
        /////////////////
        
        SKTexture* skylineTexture = [SKTexture textureWithImageNamed:@"Skyline_red"];
//        skylineTexture.filteringMode = SKTextureFilteringNearest;
        float skylineScale = 0.12;
        
        SKAction* moveSkylineSprite = [SKAction moveByX:-skylineTexture.size.width*skylineScale y:0 duration:speedScale*0.1 * skylineTexture.size.width*skylineScale];
        SKAction* resetSkylineSprite = [SKAction moveByX:skylineTexture.size.width*skylineScale y:0 duration:0];
        SKAction* moveSkylineSpritesForever = [SKAction repeatActionForever:[SKAction sequence:@[moveSkylineSprite, resetSkylineSprite]]];
        
        for( int i = 0; i < 2 + self.frame.size.width / ( skylineTexture.size.width * skylineScale ); ++i ) {
            SKSpriteNode* sprite = [SKSpriteNode spriteNodeWithTexture:skylineTexture];
            [sprite setScale:skylineScale];
            sprite.zPosition = -20;
            sprite.position = CGPointMake(i * sprite.size.width, sprite.size.height / 2 + groundTexture.size.height * groundScale);
            [sprite runAction:moveSkylineSpritesForever];
            [_moving addChild:sprite];
        }
        
        // Create pipes
        ////////////////
        _pipeTexturesUp = [NSMutableArray arrayWithCapacity:3];
        _pipeTexturesDown = [NSMutableArray arrayWithCapacity:3];
        [_pipeTexturesUp addObject:[SKTexture textureWithImageNamed:@"bricks1"]];
        [_pipeTexturesDown addObject:[SKTexture textureWithImageNamed:@"bricks2"]];
        
        [_pipeTexturesUp addObject:[SKTexture textureWithImageNamed:@"bricks_gray_up"]];
        [_pipeTexturesDown addObject:[SKTexture textureWithImageNamed:@"bricks_gray_down"]];

        [_pipeTexturesUp addObject:[SKTexture textureWithImageNamed:@"bricks_white_up"]];
        [_pipeTexturesDown addObject:[SKTexture textureWithImageNamed:@"bricks_white_down"]];

        if (isIPAD)
            pipeScale = 0.25;
        else
            pipeScale = 0.13;
        SKTexture *pipetexture = _pipeTexturesUp[0];
        CGFloat distanceToMove = self.frame.size.width + 1 * pipetexture.size.width;
        SKAction* movePipes = [SKAction moveByX:-distanceToMove y:0 duration:speedScale*0.01 * distanceToMove];
        SKAction* removePipes = [SKAction removeFromParent];
        _movePipesAndRemove = [SKAction sequence:@[movePipes, removePipes]];
        

        // Create bullet
        ////////////////
        
        _bulletTexture = [SKTexture textureWithImageNamed:@"Bullet-B"];
        bulletScale = 0.1;
        
        CGFloat bulletDistanceToMove = self.frame.size.width + 1 * _bulletTexture.size.width;
        SKAction* moveBullets = [SKAction moveByX:-bulletDistanceToMove y:0 duration:speedScale*0.01/2. * bulletDistanceToMove];
        SKAction* removeBullets = [SKAction removeFromParent];
        _moveBulletAndRemove = [SKAction sequence:@[moveBullets, removeBullets]];

        
        // Create bird
        ////////////////
        NSArray *birdTextures = @[[SKTexture textureWithImageNamed:@"a1"],
                                  [SKTexture textureWithImageNamed:@"a2"],
                                  [SKTexture textureWithImageNamed:@"a3"],
                                  [SKTexture textureWithImageNamed:@"a4"],
                                  [SKTexture textureWithImageNamed:@"a5"],
                                  [SKTexture textureWithImageNamed:@"a6"],
                                  [SKTexture textureWithImageNamed:@"a7"],
                                  [SKTexture textureWithImageNamed:@"a8"]];
        
        SKAction* flap = [SKAction repeatActionForever:[SKAction animateWithTextures:birdTextures timePerFrame:0.05]];
        _bird = [SKSpriteNode spriteNodeWithTexture:birdTextures[0]];
        [_bird setScale:.05];
        
        _bird.position = CGPointMake(self.frame.size.width / 4, CGRectGetMidY(self.frame));
        _bird.physicsBody = [SKPhysicsBody bodyWithCircleOfRadius:_bird.size.height / 2];
        _bird.physicsBody.dynamic = YES;
        _bird.physicsBody.allowsRotation = NO;
        _bird.physicsBody.restitution = 0.3;
        _bird.physicsBody.friction = 0.9;
        
        _bird.physicsBody.categoryBitMask = birdCategory;
        _bird.physicsBody.collisionBitMask = worldCategory | pipeCategory;
        _bird.physicsBody.contactTestBitMask = worldCategory | pipeCategory;
        
        
        [self addChild:_bird];
        [_bird runAction:flap withKey:@"flapRegular"];
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

#pragma mark - Bird Creation


-(void) createDeadBird {
    CGPoint lastPosition = _bird.position;
    [_bird removeFromParent];
    NSArray *birdTextures = @[[SKTexture textureWithImageNamed:@"g1"],
                              [SKTexture textureWithImageNamed:@"g2"],
                              [SKTexture textureWithImageNamed:@"g3"],
                              [SKTexture textureWithImageNamed:@"g4"],
                              [SKTexture textureWithImageNamed:@"g5"],
                              [SKTexture textureWithImageNamed:@"g6"],
                              [SKTexture textureWithImageNamed:@"g7"],
                              [SKTexture textureWithImageNamed:@"g8"]];
    
    SKAction* flap = [SKAction repeatActionForever:[SKAction animateWithTextures:birdTextures timePerFrame:0.15]];
    _bird = [SKSpriteNode spriteNodeWithTexture:birdTextures[0]];
    [_bird setScale:.05];
    
    _bird.position = lastPosition;
    _bird.physicsBody = [SKPhysicsBody bodyWithCircleOfRadius:_bird.size.height / 2];
    _bird.physicsBody.dynamic = YES;
    _bird.physicsBody.allowsRotation = NO;
    _bird.physicsBody.restitution = 0.3;
    _bird.physicsBody.friction = 0.9;
    
    _bird.physicsBody.categoryBitMask = birdCategory;
    _bird.physicsBody.collisionBitMask = worldCategory;
    _bird.physicsBody.contactTestBitMask = worldCategory | pipeCategory;
    
    
    [self addChild:_bird];
//    SKAction* delay = [SKAction waitForDuration:5.0];
//    SKAction* delayThenGotoHeaven = [SKAction sequence:@[delay, flap]];

//    [self removeActionForKey:@"flapAfterCrash"];
    [_bird runAction:flap withKey:@"flapAfterDeath"];
    [self performSelector:@selector(reverseGravity) withObject:nil afterDelay:1];


}


-(void) createCrashedBird {
    CGPoint lastPosition = _bird.position;
    [_bird removeFromParent];
    NSArray *birdTextures = @[[SKTexture textureWithImageNamed:@"d1"],
                              [SKTexture textureWithImageNamed:@"d2"],
                              [SKTexture textureWithImageNamed:@"d3"],
                              [SKTexture textureWithImageNamed:@"d4"],
                              [SKTexture textureWithImageNamed:@"d5"],
                              [SKTexture textureWithImageNamed:@"d6"],
                              [SKTexture textureWithImageNamed:@"d7"],
                              [SKTexture textureWithImageNamed:@"d8"]];
    
    SKAction* flap = [SKAction repeatActionForever:[SKAction animateWithTextures:birdTextures timePerFrame:0.15]];
    _bird = [SKSpriteNode spriteNodeWithTexture:birdTextures[0]];
    [_bird setScale:.05];

    _bird.position = lastPosition;
    _bird.physicsBody = [SKPhysicsBody bodyWithCircleOfRadius:_bird.size.height / 2];
    _bird.physicsBody.dynamic = YES;
    _bird.physicsBody.allowsRotation = NO;
    _bird.physicsBody.restitution = 0.3;
    _bird.physicsBody.friction = 0.9;
    
    _bird.physicsBody.categoryBitMask = birdCategory;
    _bird.physicsBody.collisionBitMask = worldCategory | pipeCategory;
    _bird.physicsBody.contactTestBitMask = worldCategory | pipeCategory;

    
    [self addChild:_bird];
//    [self removeActionForKey:@"flapRegular"];
    [_bird runAction:flap withKey:@"flapAfterCrash"];
    [self createSmoke];
}

-(void) createBirdRegular {
    [_bird removeFromParent];
    NSArray *birdTextures = @[[SKTexture textureWithImageNamed:@"a1"],
                              [SKTexture textureWithImageNamed:@"a2"],
                              [SKTexture textureWithImageNamed:@"a3"],
                              [SKTexture textureWithImageNamed:@"a4"],
                              [SKTexture textureWithImageNamed:@"a5"],
                              [SKTexture textureWithImageNamed:@"a6"],
                              [SKTexture textureWithImageNamed:@"a7"],
                              [SKTexture textureWithImageNamed:@"a8"]];
    
    SKAction* flap = [SKAction repeatActionForever:[SKAction animateWithTextures:birdTextures timePerFrame:0.15]];
    _bird = [SKSpriteNode spriteNodeWithTexture:birdTextures[0]];
    [_bird setScale:.05];
    
    _bird.position = CGPointMake(self.frame.size.width / 4, CGRectGetMidY(self.frame));
    _bird.physicsBody = [SKPhysicsBody bodyWithCircleOfRadius:_bird.size.height / 2];
    _bird.physicsBody.dynamic = YES;
    _bird.physicsBody.allowsRotation = NO;
    _bird.physicsBody.restitution = 0.3;
    _bird.physicsBody.friction = 0.9;
    
    _bird.physicsBody.categoryBitMask = birdCategory;
    _bird.physicsBody.collisionBitMask = worldCategory | pipeCategory;
    _bird.physicsBody.contactTestBitMask = worldCategory | pipeCategory;

    
    [self addChild:_bird];
    [self removeActionForKey:@"flapAfterCrash"];
    [_bird runAction:flap withKey:@"flapRegular"];
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
    
    smokeNode.position = _bird.position;
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
            [self startGeneratingBulletsWithDelay:2.0];
        }
        if (_score >= 20) {
            [self startGeneratingBulletsWithDelay:1.0];
            _bulletTexture = [SKTexture textureWithImageNamed:@"Bullet-A"];
        }

        
        [self startGeneratingPipes];
        if (isHoverEnabled)
            [self.videoCamera start];

        isGameInProgress = YES;

//        _bird.physicsBody.velocity = CGVectorMake(0, 0);
//        [_bird.physicsBody applyImpulse:CGVectorMake(0, 12)];

    } else if ([node.name isEqualToString:@"restartButtonNode"])
    {
        [node removeFromParent];
        [self removeActionForKey:@"organPlaying"];
        
        [self resetScene];
        [self createBirdRegular];
    } else if (isGameInProgress)
    {
        _bird.physicsBody.velocity = CGVectorMake(0, 0);
        [_bird.physicsBody applyImpulse:CGVectorMake(0, 10)];
    }
    
    
    
    /* Called when a touch begins */
//    if( _moving.speed > 0 ) {
//        _bird.physicsBody.velocity = CGVectorMake(0, 0);
//        [_bird.physicsBody applyImpulse:CGVectorMake(0, 6)];
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
        
        if( ( contact.bodyA.categoryBitMask & scoreCategory ) == scoreCategory || ( contact.bodyB.categoryBitMask & scoreCategory ) == scoreCategory ) {
            // Bird has contact with score entity
            
            if ( (contact.bodyA.categoryBitMask & scoreCategory ) == scoreCategory) {
                [contact.bodyA.node removeFromParent];
            }
            if ( (contact.bodyB.categoryBitMask & scoreCategory ) == scoreCategory) {
                [contact.bodyB.node removeFromParent];
            }
            
            _score++;
            if ((_score > 20) || (_score > 50))
                [self updateAchievements];
            if (_score == 10) {
                _moving.speed = AFTER_10_SPEED_FACTOR*_moving.speed;
                [self startGeneratingBulletsWithDelay:2.0];
            }
            if (_score == 10)
                if (isMusicEnabled) {
                    [gameSceneLoop stop];
                    [gameSceneLoop2 play];
                }
            if (_score == 20) {
                _bulletTexture = [SKTexture textureWithImageNamed:@"Bullet-A"];
                [self startGeneratingBulletsWithDelay:1.0];
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
            [self createCrashedBird];
            if (isMusicEnabled) {
                [gameSceneLoop stop];
                [gameSceneLoop2 stop];
            }
        
            isGameInProgress = NO;
            [self runAction:crashSound];
            
            _moving.speed = 0;
            
            _bird.physicsBody.collisionBitMask = worldCategory;
            
            [_bird runAction:[SKAction rotateByAngle:M_PI * _bird.position.y * 0.01 duration:_bird.position.y * 0.003] completion:^{
                _bird.speed = 0;
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
                [self performSelector:@selector(createDeadBird) withObject:nil afterDelay:.5];
                [self addChild: [self restartButtonNode]];
            }

        }
    }
}

-(void) restartGame {
    [self.scoreDelegate didFinishGameWithScore:_score];
//    [[self childNodeWithName:@"restartButtonNode"] removeFromParent];
    [self resetScene];
    [self createBirdRegular];

}

-(void)update:(CFTimeInterval)currentTime {
    /* Called before each frame is rendered */
    if( _moving.speed > 0 ) {
        _bird.zRotation = clamp( -1, 0.5, _bird.physicsBody.velocity.dy * ( _bird.physicsBody.velocity.dy < 0 ? 0.003 : 0.001 ) );
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
//                _bird.physicsBody.velocity = CGVectorMake(0, 0);
//                [_bird.physicsBody applyImpulse:CGVectorMake(meanFlow.val[0]*0, 9)];
//            }
//        }

        
        if( _moving.speed > 0 ) {
            _bird.physicsBody.velocity = CGVectorMake(0, 0);
            if (isIPAD)
                [_bird.physicsBody applyImpulse:CGVectorMake(meanFlow.val[1]*(-5), -meanFlow.val[0]*5)];
            else
                [_bird.physicsBody applyImpulse:CGVectorMake(meanFlow.val[1]*(-4), -meanFlow.val[0]*4)];
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