//
//  HelpVideoVCViewController.m
//  HoverFlappy
//
//  Created by ramin on 7/6/14.
//  Copyright (c) 2014 maadotaa.com. All rights reserved.
//

#import "HelpVideoVCViewController.h"

#define HAS_WATCHED_VIDEO @"hasWatchedVideo"


@interface HelpVideoVCViewController () <UIGestureRecognizerDelegate>

@property (strong, nonatomic) UIWebView *webView;
@property (weak, nonatomic) IBOutlet UIButton *doneButton;
- (IBAction)didTapDone:(id)sender;

@end

@implementation HelpVideoVCViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

-(void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    NSLog(@"outch!!");
}

- (void)embedYouTube:(NSString*)url frame:(CGRect)frame {
//    NSString* embedHTML = @"<html><head><style type=\"text/html\">\\body {\\background-color: transparent;color: white;}</style></head><body style=\"margin:0\">  <iframe id=\"ytplayer\" src=\"%@?rel=0&showinfo=0\"  width=\"%0.0f\" height=\"%0.0f\"></iframe></body></html>";
    
    NSString* embedHTML = @"<iframe id=\"ytplayer\" type=\"text/html\" src=\"%@?rel=0&showinfo=0\"  width=\"%0.0f\" height=\"%0.0f\" frameborder=\"0\" ></iframe>";
    NSString* html = [NSString stringWithFormat:embedHTML, url, frame.size.width, frame.size.height];
    if(self.webView == nil) {
        self.webView = [[UIWebView alloc] initWithFrame:frame];
        
        UITapGestureRecognizer *webViewTapped = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(didPlayVideo)];
        webViewTapped.numberOfTapsRequired = 1;
        webViewTapped.delegate = self;
        [self.webView addGestureRecognizer:webViewTapped];
        
        [self.view addSubview:self.webView];
    }
    [self.webView loadHTMLString:html baseURL:nil];
    
    
}

-(void)viewWillLayoutSubviews {
    [super viewWillLayoutSubviews];
    NSLog(@"here!!!!!!!!");
    CGRect frame;
    float w, h;
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone) {
        w = self.view.frame.size.width/1.5;
        h = self.view.frame.size.height/4.;
        frame = CGRectMake(self.view.frame.size.width/2.-w/2., self.view.frame.size.height/2.-h/2., w, h);
    }
    else {
//        w = self.view.frame.size.width/1.5;
//        h = self.view.frame.size.height/1.2;
        w = 560;
        h = 315;
        frame = CGRectMake(self.view.frame.size.width/2.-w/2., self.view.frame.size.height/2.-h/2., w, h);
        
    }
    
    [self embedYouTube:@"http://www.youtube.com/embed/bw21wo2FzyI" frame:frame];
}

-(void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];


    BOOL hasWatchedVideo = [[NSUserDefaults standardUserDefaults] boolForKey:HAS_WATCHED_VIDEO];
    if (hasWatchedVideo) {
        self.doneButton.hidden = NO;
    }
    else {
        self.doneButton.hidden = YES;
//        [[NSUserDefaults standardUserDefaults] setBool:YES forKey:HAS_WATCHED_VIDEO];
    }
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view.

}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer
{
    return YES;
}

-(void) didPlayVideo {
    NSLog(@"Did play video!!!!!!");
    self.doneButton.hidden = NO;
    [[NSUserDefaults standardUserDefaults] setBool:YES forKey:HAS_WATCHED_VIDEO];
    
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

- (IBAction)didTapDone:(id)sender {
    [self dismissViewControllerAnimated:YES completion:nil];
}
@end
