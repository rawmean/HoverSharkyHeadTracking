//
//  ViewController.m
//  HoverBird
//
//  Created by ramin on 6/14/14.
//  Copyright (c) 2014 maadotaa.com. All rights reserved.
//


#import "ViewController.h"
#import "MyScene.h"
#import "UIImage+ImageEffects.h"
#import "ScoresViewController.h"




@implementation ViewController


- (void)checkLocalPlayer
{
    GKLocalPlayer *localPlayer = [GKLocalPlayer localPlayer];
    
    if (localPlayer.isAuthenticated)
    {
        NSLog(@"user authenticated!");
        /* Perform additional tasks for the authenticated player here */
        // Configure the view.
        SKView * skView = (SKView *)self.view;
//        skView.showsFPS = YES;
//        skView.showsNodeCount = YES;
        
        // Create and configure the scene.
        MyScene * scene = [MyScene sceneWithSize:skView.bounds.size];
        scene.scaleMode = SKSceneScaleModeAspectFill;
        scene.scoreDelegate = self; // for game over
        
        // Present the scene.
        [skView presentScene:scene];
    }
    else
    {
        /* Perform additional tasks for the non-authenticated player here */
        NSLog(@"user failed to authenticate");
    }
}


- (void)viewDidLoad
{
    [super viewDidLoad];
    
    GKLocalPlayer *localPlayer = [GKLocalPlayer localPlayer];

    // ios 6.0 and above
    [localPlayer setAuthenticateHandler:(^(UIViewController* viewcontroller, NSError *error) {
        if (!error && viewcontroller)
        {
            [self presentViewController:viewcontroller animated:YES completion:nil];
        }
        else
        {
            [self checkLocalPlayer];
        }
    })];



}

- (BOOL)shouldAutorotate
{
    return NO;
}

- (NSUInteger)supportedInterfaceOrientations
{
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone) {
        return UIInterfaceOrientationMaskPortrait;
    } else {
        return UIInterfaceOrientationLandscapeLeft;
    }
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Release any cached data, images, etc that aren't in use.
}

-(void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([segue.identifier isEqualToString:@"ShowScores"]) {
        ScoresViewController *svc = [segue destinationViewController];
        svc.bgImage = [self captureBlurredScreenshot];
        svc.score = self.score;
    
    }
    
}

-(UIImage*) captureBlurredScreenshot {
    if ([[UIScreen mainScreen] respondsToSelector:@selector(scale)])
        UIGraphicsBeginImageContextWithOptions(self.view.bounds.size, NO, [UIScreen mainScreen].scale);
    else
        UIGraphicsBeginImageContext(self.view.bounds.size);
    [self.view drawViewHierarchyInRect:self.view.bounds afterScreenUpdates:YES];

//    [self.view.layer renderInContext:UIGraphicsGetCurrentContext()];
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return [image applyLightEffect];
}


//- (void) presentLeaderboards {
//    GKGameCenterViewController* gameCenterController = [[GKGameCenterViewController alloc] init];
//    gameCenterController.viewState = GKGameCenterViewControllerStateLeaderboards;
//    gameCenterController.gameCenterDelegate = self;
//    [self presentViewController:gameCenterController animated:YES completion:nil];
//}

#pragma Game delegate
-(void)didFinishGameWithScore:(NSInteger)score {
    self.score = score;
//    [self presentLeaderboards];
    [self performSegueWithIdentifier:@"ShowScores" sender:self];

}

@end
