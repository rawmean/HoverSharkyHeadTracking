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

#define HAS_WATCHED_VIDEO @"hasWatchedVideo"

@interface ViewController () {
    
}

@property (strong, nonatomic) UIWebView *webView;

@end



@implementation ViewController
@synthesize webView = _webView;

- (void)checkLocalPlayer
{
    GKLocalPlayer *localPlayer = [GKLocalPlayer localPlayer];
    
    if (localPlayer.isAuthenticated)
    {
        NSLog(@"user authenticated!");
        // Configure the view.
        SKView * skView = (SKView *)self.view;
        skView.showsFPS = YES;
        skView.showsNodeCount = YES;
        
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




-(void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];

    BOOL hasWatchedVideo = [[NSUserDefaults standardUserDefaults] boolForKey:HAS_WATCHED_VIDEO];
//    hasWatchedVideo = NO;
    if (hasWatchedVideo) {
        GKLocalPlayer *localPlayer = [GKLocalPlayer localPlayer];
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
    else {
        [self performSegueWithIdentifier:@"ShowHelp" sender:self];
    }
//    else {
//        [[NSUserDefaults standardUserDefaults] setBool:YES forKey:HAS_WATCHED_VIDEO];
//        CGRect frame = self.view.frame;
//        float w, h;
//        w = self.view.frame.size.width/1.5;
//        h = self.view.frame.size.height/4.;
//        
//        frame = CGRectMake(self.view.frame.size.width/2.-w/2., self.view.frame.size.height/2.-h/2.,
//                           w, h);
//        
//        [self embedYouTube:@"http://www.youtube.com/embed/bw21wo2FzyI" frame:frame];
//    }
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    




}

- (BOOL)shouldAutorotate
{
        return YES;
}

- (NSUInteger)supportedInterfaceOrientations
{
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone) {
        return UIInterfaceOrientationMaskLandscape;
    } else {
        return UIInterfaceOrientationMaskLandscape ;
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
