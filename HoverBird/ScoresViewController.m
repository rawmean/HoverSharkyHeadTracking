//
//  ScoresViewController.m
//  HoverBird
//
//  Created by ramin on 6/15/14.
//  Copyright (c) 2014 maadotaa.com. All rights reserved.
//

#import "ScoresViewController.h"
#import <iAd/iAd.h>

@interface ScoresViewController ()<UITableViewDataSource, ADBannerViewDelegate> {
    NSDictionary* scoreDict;
    NSMutableArray* scoreArray;
    NSMutableArray* dateArray;
}
@property (weak, nonatomic) IBOutlet UITableView *scoresTableView;
@property (strong, nonatomic) ADBannerView *rectangleAdView;
@property (weak, nonatomic) IBOutlet UIImageView *backgroundImage;

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

-(void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    self.backgroundImage.image = _bgImage;

}

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.canDisplayBannerAds = YES;

    // Do any additional setup after loading the view.
    self.scoresTableView.dataSource = self;
    [self.scoresTableView registerClass:[UITableViewCell class] forCellReuseIdentifier:@"scores"];

    self.rectangleAdView = [[ADBannerView alloc]
                        initWithAdType:ADAdTypeMediumRectangle];
    self.rectangleAdView.frame = CGRectMake(0, 0, self.view.frame.size.width, self.view.frame.size.height/2);
    self.rectangleAdView.center = self.view.center;
    
    self.rectangleAdView.delegate = self;
    
    scoreDict = [[NSUserDefaults standardUserDefaults] objectForKey:@"scoreArray"];
    
    NSEnumerator *enumerator = [scoreDict keyEnumerator];
    id key;
    
    scoreArray = [[NSMutableArray alloc] init];
    dateArray  =[[NSMutableArray alloc] init];
    while ((key = [enumerator nextObject])) {
        /* code that uses the returned key */
        [scoreArray addObject:scoreDict[key]];
        [dateArray addObject:key];
    }
    
    
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

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    // Return the number of sections.
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    // Return the number of rows in the section.
    return scoreArray.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"scores" forIndexPath:indexPath];
    
    // Configure the cell...
    cell.textLabel.text = [NSString stringWithFormat:@"%@:\t\t%@",
                           dateArray[indexPath.row], scoreArray[indexPath.row]];
    cell.textLabel.backgroundColor = [UIColor clearColor];
    cell.backgroundColor = [UIColor clearColor];
    
    return cell;
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


@end
