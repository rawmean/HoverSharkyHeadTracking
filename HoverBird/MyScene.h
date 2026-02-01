//
//  MyScene.h
//  HoverBird
//

//  Copyright (c) 2014 maadotaa.com. All rights reserved.
//

#import <SpriteKit/SpriteKit.h>

@class HeadTrackingManager;

@protocol MySceneDelegate <NSObject>
@required
- (void) didFinishGameWithScore:(NSInteger)score;
@end

@interface MyScene : SKScene {
    id <MySceneDelegate> scoreDelegate;
}

@property (nonatomic, weak) id <MySceneDelegate> scoreDelegate;
@property (nonatomic, strong) HeadTrackingManager *headTracker;

@end
