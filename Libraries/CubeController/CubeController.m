//
//  CubeController.m
//
//  Version 1.2
//
//  Created by Nick Lockwood on 30/06/2013.
//  Copyright (c) 2013 Charcoal Design
//
//  Distributed under the permissive zlib License
//  Get the latest version from here:
//
//  https://github.com/nicklockwood/CubeController
//
//  This software is provided 'as-is', without any express or implied
//  warranty.  In no event will the authors be held liable for any damages
//  arising from the use of this software.
//
//  Permission is granted to anyone to use this software for any purpose,
//  including commercial applications, and to alter it and redistribute it
//  freely, subject to the following restrictions:
//
//  1. The origin of this software must not be misrepresented; you must not
//  claim that you wrote the original software. If you use this software
//  in a product, an acknowledgment in the product documentation would be
//  appreciated but is not required.
//
//  2. Altered source versions must be plainly marked as such, and must not be
//  misrepresented as being the original software.
//
//  3. This notice may not be removed or altered from any source distribution.
//


#pragma GCC diagnostic ignored "-Wauto-import"
#pragma GCC diagnostic ignored "-Wreceiver-is-weak"
#pragma GCC diagnostic ignored "-Warc-repeated-use-of-weak"
#pragma GCC diagnostic ignored "-Wobjc-missing-property-synthesis"
#pragma GCC diagnostic ignored "-Wdirect-ivar-access"
#pragma GCC diagnostic ignored "-Wconversion"
#pragma GCC diagnostic ignored "-Wgnu"


#import "CubeController.h"
#import <QuartzCore/QuartzCore.h>


@implementation NSObject (CubeControllerDelegate)

- (void)cubeControllerDidScroll:(__unused CubeController *)cc {}
- (void)cubeControllerCurrentViewControllerIndexDidChange:(__unused CubeController *)cc {}
- (void)cubeControllerWillBeginDragging:(__unused CubeController *)cc {}
- (void)cubeControllerDidEndDragging:(__unused CubeController *)cc willDecelerate:(__unused BOOL)dc {}
- (void)cubeControllerWillBeginDecelerating:(__unused CubeController *)cc {}
- (void)cubeControllerDidEndDecelerating:(__unused CubeController *)cc {}
- (void)cubeControllerDidEndScrollingAnimation:(__unused CubeController *)cc {}

@end


@interface CubeController () <UIScrollViewDelegate>

@property (nonatomic, strong) NSMutableDictionary *controllers;
@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, assign) NSInteger numberOfViewControllers;
@property (nonatomic, assign) CGFloat scrollOffset;
@property (nonatomic, assign) CGFloat previousOffset;
@property (nonatomic, assign) BOOL suppressScrollEvent;

@end


@implementation CubeController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    _scrollView = [[UIScrollView alloc] initWithFrame:self.view.bounds];
    _scrollView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _scrollView.showsHorizontalScrollIndicator = NO;
    _scrollView.pagingEnabled = YES;
    _scrollView.directionalLockEnabled = YES;
    _scrollView.autoresizesSubviews = NO;
    _scrollView.delegate = self;
    [self.view addSubview:_scrollView];
    
    [self reloadData];
}

- (void)setWrapEnabled:(BOOL)wrapEnabled
{
    _wrapEnabled = wrapEnabled;
    [self updateLayout];
}

- (void)setCurrentViewControllerIndex:(NSInteger)currentViewControllerIndex
{
    [self scrollToViewControllerAtIndex:currentViewControllerIndex animated:NO];
}

- (void)scrollToViewControllerAtIndex:(NSInteger)index animated:(BOOL)animated
{
    [_scrollView setContentOffset:CGPointMake(self.view.bounds.size.width * (CGFloat)index, 0) animated:animated];
}

- (void)reloadData
{
    for (UIViewController *controller in [_controllers allValues])
    {
        [controller viewWillDisappear:NO];
        [controller.view removeFromSuperview];
        [controller removeFromParentViewController];
        [controller viewDidDisappear:NO];
    }
    _controllers = [NSMutableDictionary dictionary];
    _numberOfViewControllers = [self.dataSource numberOfViewControllersInCubeController:self];
    [self updateLayout];
}

- (void)updateLayout
{
    if (_scrollView)
    {
        NSInteger pages = (_wrapEnabled && _numberOfViewControllers > 1)? 3: MIN(3, _numberOfViewControllers);
        _scrollView.contentSize = CGSizeMake(self.view.bounds.size.width * pages, self.view.bounds.size.height);
        [self updateContentOffset];
        [self scrollViewDidScroll:_scrollView];
    }
}

- (void)updateContentOffset
{
    _suppressScrollEvent = YES;
    CGFloat offset = _scrollView.contentOffset.x / self.view.bounds.size.width;
    if (_wrapEnabled && _numberOfViewControllers > 1)
    {
        while (offset < 1.0f) offset += 1.0f;
        while (offset >= 2.0f) offset -= 1.0f;
    }
    else
    {
        while (offset < 1.0f && floor(_scrollOffset) > 0) offset += 1.0f;
        while (offset >= 2.0f && floor(_scrollOffset) < _numberOfViewControllers - 1) offset -= 1.0f;
    }
    _previousOffset = offset;
    _scrollView.contentOffset = CGPointMake(self.view.bounds.size.width * offset, 0.0f);
    _suppressScrollEvent = NO;
}

- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];
    [self updateLayout];
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
    if (!_suppressScrollEvent)
    {
        //update scroll offset
        CGFloat offset = scrollView.contentOffset.x / self.view.bounds.size.width;
        _scrollOffset += (offset - _previousOffset);
        if (_wrapEnabled)
        {
            while (_scrollOffset < 0.0f) _scrollOffset += _numberOfViewControllers;
            while (_scrollOffset >= _numberOfViewControllers) _scrollOffset -= _numberOfViewControllers;
        }
        _previousOffset = offset;
        
        //prevent error accumulation
        if (offset - floor(offset) == 0.0f) _scrollOffset = round(_scrollOffset);
        
        //update index
        NSInteger previousViewControllerIndex = _currentViewControllerIndex;
        _currentViewControllerIndex = MAX(0, MIN(_numberOfViewControllers - 1, (NSInteger)round(_scrollOffset)));
        
        //update content offset
        [self updateContentOffset];
        
        //calculate visible indices
        offset = _scrollOffset - _currentViewControllerIndex;
        NSMutableSet *visibleIndices = [NSMutableSet setWithObject:@(_currentViewControllerIndex)];
        if (_wrapEnabled || _currentViewControllerIndex < _numberOfViewControllers - 1)
        {
            [visibleIndices addObject:@(_currentViewControllerIndex + 1)];
        }
        else if (_currentViewControllerIndex > 0)
        {
            [visibleIndices addObject:@(_currentViewControllerIndex - 1)];
        }
        else if (_wrapEnabled)
        {
            [visibleIndices addObject:@(_numberOfViewControllers - 1)];
        }
        
        //remove hidden controllers
        for (NSNumber *index in [_controllers allKeys])
        {
            if (![visibleIndices containsObject:index])
            {
                UIViewController *controller = _controllers[index];
                [controller.view removeFromSuperview];
                [controller removeFromParentViewController];
                [_controllers removeObjectForKey:index];
            }
        }
        
        //load controllers
        for (NSNumber *index in visibleIndices)
        {
            NSUInteger i = [index integerValue];
            UIViewController *controller = _controllers[index];
            if (!controller && _numberOfViewControllers)
            {
                controller = [self.dataSource cubeController:self viewControllerAtIndex:i % _numberOfViewControllers];
                _controllers[index] = controller;
            }
        }
        
        //update visible controllers
        for (NSNumber *index in visibleIndices)
        {
            UIViewController *controller = _controllers[index];
            if (controller && !controller.parentViewController)
            {
                controller.view.frame = self.view.bounds;
                controller.view.autoresizingMask = UIViewAutoresizingNone;
                controller.view.layer.doubleSided = NO;
                [self addChildViewController:controller];
                [_scrollView addSubview:controller.view];
            }
            
            NSInteger i = [index integerValue];
            CGFloat angle = (_scrollOffset - i) * M_PI_2;
            while (angle < 0) angle += M_PI * 2;
            while (angle > M_PI * 2) angle -= M_PI * 2;
            CATransform3D transform = CATransform3DIdentity;
            if (angle != 0.0f)
            {
                transform.m34 = -1.0/500;
                transform = CATransform3DTranslate(transform, 0, 0, -self.view.bounds.size.width / 2.0f);
                transform = CATransform3DRotate(transform, -angle, 0, 1, 0);
                transform = CATransform3DTranslate(transform, 0, 0, self.view.bounds.size.width / 2.0f);
            }
            
            controller.view.layer.transform = transform;
            controller.view.center = CGPointMake(self.view.bounds.size.width / 2.0f + scrollView.contentOffset.x, self.view.bounds.size.height / 2.0f);
        }
        
        //update delegate
        [_delegate cubeControllerDidScroll:self];
        if (_currentViewControllerIndex != previousViewControllerIndex)
        {
            [_delegate cubeControllerCurrentViewControllerIndexDidChange:self];
        }
        
        //enable/disable interaction
        for (NSNumber *index in visibleIndices)
        {
            UIViewController *controller = _controllers[index];
            NSInteger i = [index integerValue];
            controller.view.userInteractionEnabled = (i == _currentViewControllerIndex);
        }
    }
}

- (void)scrollViewWillBeginDragging:(__unused UIScrollView *)scrollView
{
    if (!_suppressScrollEvent) [_delegate cubeControllerWillBeginDragging:self];
}

- (void)scrollViewDidEndDragging:(__unused UIScrollView *)scrollView willDecelerate:(BOOL)decelerate
{
    if (!_suppressScrollEvent) [_delegate cubeControllerDidEndDragging:self willDecelerate:decelerate];
}

- (void)scrollViewWillBeginDecelerating:(__unused UIScrollView *)scrollView
{
    if (!_suppressScrollEvent) [_delegate cubeControllerWillBeginDecelerating:self];
}

- (void)scrollViewDidEndDecelerating:(__unused UIScrollView *)scrollView
{
    if (!_suppressScrollEvent) [_delegate cubeControllerDidEndDecelerating:self];
}

- (void)scrollViewDidEndScrollingAnimation:(__unused UIScrollView *)scrollView
{
    if (!_suppressScrollEvent) [_delegate cubeControllerDidEndScrollingAnimation:self];
}

@end


@implementation UIViewController (CubeController)

- (CubeController *)cubeController
{
    if ([self.parentViewController isKindOfClass:[CubeController class]])
    {
        return (CubeController *)self.parentViewController;
    }
    return [self.parentViewController cubeController];
}

@end