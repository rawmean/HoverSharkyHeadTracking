//
//  ViewController.h
//  HoverBird
//

//  Copyright (c) 2014 maadotaa.com. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <GameKit/GameKit.h>
#import <SpriteKit/SpriteKit.h>
#import "MyScene.h"

@interface ViewController : UIViewController <GameSceneDelegate>

@property (assign, nonatomic) NSInteger score;

@end
