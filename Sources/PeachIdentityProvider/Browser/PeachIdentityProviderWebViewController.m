//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "../include/PeachIdentityProviderWebViewController.h"
#import "../include/PeachIdentityProviderModalTransition.h"

@import libextobjc;
@import MAKVONotificationCenter;

@interface PeachIdentityProviderWebViewController ()

@property (nonatomic) NSURLRequest *request;
@property (nonatomic, copy) WKNavigationActionPolicy (^decisionHandler)(NSURL *);

@property (nonatomic) UIProgressView *progressView;
@property (nonatomic, weak) WKWebView *webView;
@property (nonatomic) UILabel *errorLabel;

@end

@implementation PeachIdentityProviderWebViewController

#pragma mark Object lifecycle

- (id)initWithRequest:(NSURLRequest *)request decisionHandler:(WKNavigationActionPolicy (^)(NSURL *URL))decisionHandler
{
    self = [super init];
    if (self) {
        self.request = request;
        self.decisionHandler = decisionHandler;
    }
    return self;
}

- (void)dealloc
{
    // Avoid iOS 9 crash: https://stackoverflow.com/questions/35529080/wkwebview-crashes-on-deinit
    self.webView.scrollView.delegate = nil;
    
    self.webView = nil;             // Unregister KVO
}

#pragma mark Getters and setters

- (void)setWebView:(WKWebView *)webView
{
    [_webView removeObserver:self keyPath:@keypath(_webView.estimatedProgress)];
    
    _webView = webView;
    
    if (_webView) {
        @weakify(self)
        [_webView addObserver:self keyPath:@keypath(webView.estimatedProgress) options:NSKeyValueObservingOptionNew block:^(MAKVONotification *notification) {
            @strongify(self)
            self.progressView.progress = self.webView.estimatedProgress;
        }];
    }
}

#pragma mark View lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    
    WKWebView *webView = [[WKWebView alloc] initWithFrame:self.view.bounds];
    webView.translatesAutoresizingMaskIntoConstraints = false;
    webView.navigationDelegate = self;
    webView.scrollView.delegate = self;
    [self.view insertSubview:webView atIndex:0];
    self.webView = webView;
    
    [self.webView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor].active = YES;
    [self.webView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor].active = YES;
    [self.webView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor].active = YES;
    [self.webView.topAnchor constraintEqualToAnchor:self.view.topAnchor].active = YES;
    
    self.progressView = [[UIProgressView alloc] initWithProgressViewStyle:UIProgressViewStyleBar];
    self.progressView.translatesAutoresizingMaskIntoConstraints = false;
    [self.view addSubview:self.progressView];
    
    [self.progressView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor].active = YES;
    [self.progressView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor].active = YES;
    [self.progressView.heightAnchor constraintEqualToConstant:2].active = YES;
    [self.progressView.topAnchor constraintEqualToAnchor:self.view.topAnchor].active = YES;
    
    // Force properties to avoid overrides with UIAppearance
    UIProgressView *progressViewAppearance = [UIProgressView appearanceWhenContainedInInstancesOfClasses:@[self.class]];
    progressViewAppearance.progressTintColor = nil;
    progressViewAppearance.trackTintColor = nil;
    progressViewAppearance.progressImage = nil;
    progressViewAppearance.trackImage = nil;
    
    self.errorLabel = [[UILabel alloc] init];
    self.errorLabel.textColor = UIColor.grayColor;
    self.errorLabel.text = nil;
    self.errorLabel.translatesAutoresizingMaskIntoConstraints = false;
    [self.view addSubview:self.errorLabel];
    
    [self.errorLabel.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor].active = YES;
    [self.errorLabel.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor].active = YES;
    
    
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh
                                                                                           target:self
                                                                                           action:@selector(refresh:)];
    
    [self.webView loadRequest:self.request];
}

- (void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
    
    if (self.movingFromParentViewController || self.beingDismissed) {
        [self.webView stopLoading];
    }
}

- (void)viewWillLayoutSubviews
{
    [super viewWillLayoutSubviews];
    
    [self updateContentInsets];
}

#pragma mark UI

- (void)updateContentInsets
{
    UIScrollView *scrollView = self.webView.scrollView;
    scrollView.scrollIndicatorInsets = UIEdgeInsetsZero;
    
    // Must adjust depending on the web page viewport-fit setting, see https://modelessdesign.com/backdrop/283
    if (@available(iOS 11, *)) {
        if (scrollView.contentInsetAdjustmentBehavior == UIScrollViewContentInsetAdjustmentAlways) {
            scrollView.contentInset = UIEdgeInsetsZero;
            return;
        }
    }
    if (@available(iOS 11, *)) {
        scrollView.contentInset = UIEdgeInsetsMake(self.view.safeAreaInsets.top, 0.f, self.view.safeAreaInsets.bottom, 0.f);
    } else {
        scrollView.contentInset = UIEdgeInsetsMake(self.topLayoutGuide.length, 0.f, self.bottomLayoutGuide.length, 0.f);
    }
    
    
}

#pragma mark UIScrollViewDelegate protocol

- (void)scrollViewDidChangeAdjustedContentInset:(UIScrollView *)scrollView
{
    [self updateContentInsets];
}

#pragma mark WKNavigationDelegate protocol

- (void)webView:(WKWebView *)webView didStartProvisionalNavigation:(WKNavigation *)navigation
{
    self.errorLabel.text = nil;
    
    [UIView animateWithDuration:0.3 animations:^{
        self.progressView.alpha = 1.f;
    }];
}

- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation
{
    self.errorLabel.text = nil;
    
    [UIView animateWithDuration:0.3 animations:^{
        self.webView.alpha = 1.f;
        self.progressView.alpha = 0.f;
    }];
}

- (void)webView:(WKWebView *)webView didFailProvisionalNavigation:(WKNavigation *)navigation withError:(NSError *)error
{
    if ([error.domain isEqualToString:NSURLErrorDomain]) {
        self.errorLabel.text = [error localizedDescription];
        
        [UIView animateWithDuration:0.3 animations:^{
            self.progressView.alpha = 0.f;
            self.webView.alpha = 0.f;
        }];
    }
    else {
        self.errorLabel.text = nil;
        
        [webView goBack];
        
        [UIView animateWithDuration:0.3 animations:^{
            self.progressView.alpha = 0.f;
        }];
    }
}

- (void)webView:(WKWebView *)webView decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler
{
    if (self.decisionHandler) {
        decisionHandler(self.decisionHandler(navigationAction.request.URL));
    }
    else {
        decisionHandler(WKNavigationActionPolicyAllow);
    }
}

#pragma mark Actions

- (void)refresh:(id)sender
{
    [self.webView loadRequest:self.request];
}

@end
