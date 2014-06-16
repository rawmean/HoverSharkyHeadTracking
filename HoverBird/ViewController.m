//
//  ViewController.m
//  HoverBird
//
//  Created by ramin on 6/14/14.
//  Copyright (c) 2014 maadotaa.com. All rights reserved.
//

#import "ViewController.h"
#import "MyScene.h"

@implementation ViewController

- (void)viewDidLoad
{
    [super viewDidLoad];

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

- (BOOL)shouldAutorotate
{
    return YES;
}

- (NSUInteger)supportedInterfaceOrientations
{
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone) {
        return UIInterfaceOrientationMaskAllButUpsideDown;
    } else {
        return UIInterfaceOrientationMaskAll;
    }
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Release any cached data, images, etc that aren't in use.
}

-(void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
//    if ([segue.identifier isEqualToString:@"showScores"]) {
//        <#statements#>
//    }
    
}

#pragma Game delegate
-(void)didFinishGameWithScore:(NSInteger)score {
    [self performSegueWithIdentifier:@"ShowScores" sender:self];

}

@end
