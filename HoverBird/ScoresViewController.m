//
//  ScoresViewController.m
//  HoverBird
//
//  Created by ramin on 6/15/14.
//  Copyright (c) 2014 maadotaa.com. All rights reserved.
//

#import "ScoresViewController.h"
#import <iAd/iAd.h>

#define LEADERBOARD_ID @"hoverflappy_leaderboardID"

@interface ScoresViewController ()<ADBannerViewDelegate> {
    NSDictionary* scoreDict;
    NSMutableArray* scoreArray;
    NSMutableArray* dateArray;
    NSInteger maxScore;
}
@property (weak, nonatomic) IBOutlet UITableView *scoresTableView;
@property (strong, nonatomic) ADBannerView *rectangleAdView;
@property (weak, nonatomic) IBOutlet UIImageView *backgroundImage;
@property (weak, nonatomic) IBOutlet UILabel *highestScoreLabel;
@property (weak, nonatomic) IBOutlet UILabel *currentScore;
@property (weak, nonatomic) IBOutlet UILabel *rankLabel;

- (IBAction)didTapLeaderboard:(id)sender;

- (IBAction)didTapNewGame:(id)sender;


@end



@implementation ScoresViewController

@synthesize bgImage = _bgImage;

- (instancetype)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

//-(void)setBgImage:(UIImage *)bgImage {
//    _bgImage = bgImage;
//}

- (BOOL)shouldAutorotate
{
    return YES;
}

- (NSUInteger)supportedInterfaceOrientations
{
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone) {
        return UIInterfaceOrientationMaskPortrait;
    } else {
        return UIInterfaceOrientationMaskLandscape ;
    }
}

-(void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    

    
    self.backgroundImage.image = _bgImage;
    
    NSInteger highestScore = [[NSUserDefaults standardUserDefaults] integerForKey:@"highestScore"];
    highestScore = MAX(highestScore, self.score);

    [[NSUserDefaults standardUserDefaults] setInteger:highestScore forKey:@"highestScore"];
    [[NSUserDefaults standardUserDefaults]  synchronize];
    maxScore = highestScore;
    [self reportScore:self.score forLeaderboardID:LEADERBOARD_ID];

    [self updateHighestScore];
//    self.highestScoreLabel.text = [NSString stringWithFormat:@"%ld", (long)maxScore];
    self.currentScore.text = [NSString stringWithFormat:@"%ld", (long)self.score];

}

- (void)viewDidLoad
{
    [super viewDidLoad];

    // Do any additional setup after loading the view.
//    [self.scoresTableView registerClass:[UITableViewCell class] forCellReuseIdentifier:@"scores"];
    
    NSString *reqSysVer = @"8.0";
    NSString *currSysVer = [[UIDevice currentDevice] systemVersion];
    BOOL isIOS8 = ([currSysVer compare:reqSysVer options:NSNumericSearch] != NSOrderedAscending);
    
    if (isIOS8) {
        self.rectangleAdView = [[ADBannerView alloc]
                                initWithAdType:ADAdTypeMediumRectangle];
        self.rectangleAdView.frame = CGRectMake(0, 0, self.view.frame.size.width, self.view.frame.size.height/2);
        self.rectangleAdView.center = self.view.center;
        
        self.rectangleAdView.delegate = self;
    }
    else
        self.canDisplayBannerAds = YES;
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/


- (IBAction)didTapLeaderboard:(id)sender {
    [self presentLeaderboards];
    
}

- (IBAction)didTapNewGame:(id)sender {
    [self dismissViewControllerAnimated:YES completion:nil];
}

#pragma iAd Delegate

- (void) bannerViewDidLoadAd:(ADBannerView *)banner
{
    NSLog(@"Did get iAd!");
    [self.view addSubview:banner];
    [self.view layoutIfNeeded];
}

- (void) bannerView:(ADBannerView *)banner didFailToReceiveAdWithError:(NSError *)error
{
    //NSLog(@"No iAd!, error:%@", error.description);
    
    [banner removeFromSuperview];
    [self.view layoutIfNeeded];
}


#pragma mark - Reporting Score to GameCenter

- (void) reportScore: (int64_t) score forLeaderboardID: (NSString*) identifier
{
    GKScore *scoreReporter = [[GKScore alloc] initWithLeaderboardIdentifier: identifier];
    scoreReporter.value = score;
    scoreReporter.context = 0;
    
    NSArray *scores = @[scoreReporter];
    [GKScore  reportScores:scores withCompletionHandler:^(NSError *error) {
//        [self presentLeaderboards];
    }];
}


-(void) updateHighestScore {
    GKLeaderboard *leaderboardRequest = [[GKLeaderboard alloc] init];
    if (leaderboardRequest != nil) {
        leaderboardRequest.identifier = LEADERBOARD_ID;
        leaderboardRequest.range = NSMakeRange(1,1);

        [leaderboardRequest loadScoresWithCompletionHandler:^(NSArray *scores, NSError *error){
            if (error != nil) {
                //Handle error
                NSLog(@"Trouble getting highest score: %@", error.description);
            }
            else{
                self.highestScoreLabel.text = [NSString stringWithFormat:@"%ld", (long)leaderboardRequest.localPlayerScore.value];
                self.rankLabel.text = [NSString stringWithFormat:@"%ld", (long)leaderboardRequest.localPlayerScore.rank];
                NSLog(@"highscore: %@", self.highestScoreLabel.text);
            }
        }];
    }
}


- (void) presentLeaderboards {
    GKGameCenterViewController* gameCenterController = [[GKGameCenterViewController alloc] init];
    gameCenterController.viewState = GKGameCenterViewControllerStateLeaderboards;
    gameCenterController.gameCenterDelegate = self;
    gameCenterController.topViewController.canDisplayBannerAds = YES;

    
    [self presentViewController:gameCenterController animated:YES completion: nil];
    
//    [self performSegueWithIdentifier:@"ShowLeaderboard" sender:self];

    
//    gameCenterController.modalTransitionStyle = UIModalTransitionStylePartialCurl;
//    [self presentViewController:gameCenterController animated:YES completion:nil];
}

- (void) gameCenterViewControllerDidFinish:(GKGameCenterViewController*) gameCenterViewController {
    [self dismissViewControllerAnimated:YES completion:nil];
    self.canDisplayBannerAds = YES;
}




@end
