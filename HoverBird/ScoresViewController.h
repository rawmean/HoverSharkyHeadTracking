//
//  ScoresViewController.h
//  HoverBird
//
//  Created by ramin on 6/15/14.
//  Copyright (c) 2014 maadotaa.com. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <GameKit/GameKit.h>

@interface ScoresViewController : UIViewController<GKGameCenterControllerDelegate> {
    
}

@property (strong, nonatomic) UIImage* bgImage;
@property (assign, nonatomic) NSInteger score;

@end
