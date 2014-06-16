//
//  MyScene.h
//  HoverBird
//

//  Copyright (c) 2014 maadotaa.com. All rights reserved.
//

#import <SpriteKit/SpriteKit.h>

@protocol GameSceneDelegate <NSObject>
@required
- (void) didFinishGameWithScore:(NSInteger)score;
@end

@interface MyScene : SKScene {
    id <GameSceneDelegate> scoreDelegate;
}

@property  id scoreDelegate;

@end
