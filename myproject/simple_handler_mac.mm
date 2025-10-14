// Copyright (c) 2013 The Chromium Embedded Framework Authors. All rights
// reserved. Use of this source code is governed by a BSD-style license that
// can be found in the LICENSE file.

#include "simple_handler.h"

#import <Cocoa/Cocoa.h>
#import <objc/runtime.h>

#include "include/cef_browser.h"


@interface URLFieldDelegate : NSObject <NSTextFieldDelegate> {
  CefRefPtr<CefBrowser> browser_;
}
- (id)initWithBrowser:(CefRefPtr<CefBrowser>)browser;
@end

@implementation URLFieldDelegate
- (id)initWithBrowser:(CefRefPtr<CefBrowser>)browser {
  if (self = [super init]) {
    browser_ = browser;
  }
  return self;
}

- (BOOL)control:(NSControl*)control textShouldEndEditing:(NSText*)fieldEditor {
  NSLog(@"textShouldEndEditing called");
  return YES;
}

- (void)controlTextDidEndEditing:(NSNotification*)notification {
  NSLog(@"controlTextDidEndEditing called");
  NSTextField* textField = [notification object];
  NSString* urlString = [textField stringValue];
  NSLog(@"URL string: %@", urlString);
  
  if (browser_ && [urlString length] > 0) {
    std::string url = [urlString UTF8String];
    NSLog(@"Browser exists, processing URL: %s", url.c_str());
    
    // Add http:// if no protocol specified
    if (url.find("://") == std::string::npos) {
      url = "http://" + url;
      NSLog(@"Added http:// prefix: %s", url.c_str());
    }
    
    NSLog(@"Loading URL: %s", url.c_str());
    browser_->GetMainFrame()->LoadURL(url);
  } else {
    NSLog(@"Browser is null or URL string is empty");
  }
}

- (BOOL)control:(NSControl*)control textView:(NSTextView*)textView doCommandBySelector:(SEL)commandSelector {
  NSLog(@"doCommandBySelector called with selector: %@", NSStringFromSelector(commandSelector));
  
  if (commandSelector == @selector(insertNewline:)) {
    NSLog(@"Enter key pressed!");
    NSTextField* textField = (NSTextField*)control;
    NSString* urlString = [textField stringValue];
    NSLog(@"URL string: %@", urlString);
    
    if (browser_ && [urlString length] > 0) {
      std::string url = [urlString UTF8String];
      NSLog(@"Browser exists, processing URL: %s", url.c_str());
      
      // Add http:// if no protocol specified
      if (url.find("://") == std::string::npos) {
        url = "http://" + url;
        NSLog(@"Added http:// prefix: %s", url.c_str());
      }
      
      NSLog(@"Loading URL: %s", url.c_str());
      browser_->GetMainFrame()->LoadURL(url);
    } else {
      NSLog(@"Browser is null or URL string is empty");
    }
    return YES;
  }
  
  return NO;
}
@end

@interface ToolbarButtonHandler : NSObject {
  CefRefPtr<CefBrowser> browser_;
}
- (id)initWithBrowser:(CefRefPtr<CefBrowser>)browser;
- (void)goBack:(id)sender;
- (void)goForward:(id)sender;
@end

@implementation ToolbarButtonHandler
- (id)initWithBrowser:(CefRefPtr<CefBrowser>)browser {
  if (self = [super init]) {
    browser_ = browser;
  }
  return self;
}

- (void)goBack:(id)sender {
  if (browser_ && browser_->CanGoBack()) {
    browser_->GoBack();
  }
}

- (void)goForward:(id)sender {
  if (browser_ && browser_->CanGoForward()) {
    browser_->GoForward();
  }
}
@end


namespace {

static const void* kToolbarIdentifierKey = &kToolbarIdentifierKey;
static const void* kButtonHandlerKey = &kButtonHandlerKey;
static const void* kURLFieldDelegateKey = &kURLFieldDelegateKey;

NSWindow* GetNSWindowForBrowser(CefRefPtr<CefBrowser> browser) {
  NSView* view =
      CAST_CEF_WINDOW_HANDLE_TO_NSVIEW(browser->GetHost()->GetWindowHandle());
  return [view window];
}

void AddToolbarToWindow(NSWindow* window, CefRefPtr<CefBrowser> browser) {
  NSLog(@"AddToolbarToWindow called");
  NSView* contentView = [window contentView];
  
  // Check if toolbar already exists by looking for associated object
  for (NSView* subview in [contentView subviews]) {
    NSNumber* toolbarId = (NSNumber*)objc_getAssociatedObject(subview, kToolbarIdentifierKey);
    if (toolbarId && [toolbarId intValue] == 999) {
      NSLog(@"Toolbar already exists, skipping creation");
      return;
    }
  }
  
  NSRect contentFrame = [contentView frame];
  NSLog(@"Content frame: %@", NSStringFromRect(contentFrame));
  
  // Create toolbar view at the top
  NSRect toolbarFrame = NSMakeRect(0, 
                                   contentFrame.size.height - 40,
                                   contentFrame.size.width, 
                                   40);
  
  NSView* toolbarView = [[NSView alloc] initWithFrame:toolbarFrame];
  [toolbarView setAutoresizingMask:(NSViewWidthSizable | NSViewMinYMargin)];
  [toolbarView setWantsLayer:YES];
  // Store reference to toolbar view for later identification
  // objc_setAssociatedObject(toolbarView, kToolbarIdentifierKey, @(999), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
  [[toolbarView layer] setBackgroundColor:[[NSColor controlBackgroundColor] CGColor]];
  
  // Create button handler and retain it
  ToolbarButtonHandler* buttonHandler = [[ToolbarButtonHandler alloc] initWithBrowser:browser];
  objc_setAssociatedObject(toolbarView, kButtonHandlerKey, buttonHandler, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
  
  // Back button
  NSButton* backButton = [[NSButton alloc] initWithFrame:NSMakeRect(5, 5, 60, 30)];
  [backButton setTitle:@"Back"];
  [backButton setBezelStyle:NSBezelStyleRounded];
  [backButton setTarget:buttonHandler];
  [backButton setAction:@selector(goBack:)];
  backButton.enabled = NO;
  [toolbarView addSubview:backButton];
  
  // Forward button
  NSButton* forwardButton = [[NSButton alloc] initWithFrame:NSMakeRect(70, 5, 60, 30)];
  [forwardButton setTitle:@"Forward"];
  [forwardButton setBezelStyle:NSBezelStyleRounded];
  [forwardButton setTarget:buttonHandler];
  [forwardButton setAction:@selector(goForward:)];
  forwardButton.enabled = NO;
  [toolbarView addSubview:forwardButton];
  
  // URL text field
  NSTextField* urlField = [[NSTextField alloc] initWithFrame:NSMakeRect(135, 8, 
                                                                         contentFrame.size.width - 145, 
                                                                         24)];
  [urlField setAutoresizingMask:NSViewWidthSizable];
  [urlField setTag:100]; // Tag to find it later
  [[urlField cell] setPlaceholderString:@"Enter URL"];
  
  // Set up delegate for Enter key handling
  URLFieldDelegate* delegate = [[URLFieldDelegate alloc] initWithBrowser:browser];
  [urlField setDelegate:delegate];
  objc_setAssociatedObject(urlField, kURLFieldDelegateKey, delegate, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
  NSLog(@"URL field delegate set up with browser: %p", browser.get());
  
  [toolbarView addSubview:urlField];
  
  // Adjust browser view frame to make room for toolbar
  NSView* browserView = [[contentView subviews] firstObject];
  if (browserView) {
    NSRect browserFrame = [browserView frame];
    browserFrame.size.height -= 40;
    [browserView setFrame:browserFrame];
    [browserView setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];
  }
  
  [contentView addSubview:toolbarView];
}

}  // namespace


void SimpleHandler::PlatformTitleChange(CefRefPtr<CefBrowser> browser,
                                        const CefString& title) {
  NSWindow* window = GetNSWindowForBrowser(browser);
  std::string titleStr(title);
  NSString* str = [NSString stringWithUTF8String:titleStr.c_str()];
  [window setTitle:str];
}

void SimpleHandler::PlatformShowWindow(CefRefPtr<CefBrowser> browser) {
  NSWindow* window = GetNSWindowForBrowser(browser);
  [window makeKeyAndOrderFront:window];

  // Add toolbar after window is set up
  NSLog(@"Adding toolbar to window");
  AddToolbarToWindow(window, browser);
}

// Add these helper methods to enable back/forward navigation
void SimpleHandler::GoBack(CefRefPtr<CefBrowser> browser) {
  if (browser && browser->CanGoBack()) {
    browser->GoBack();
  }
}

void SimpleHandler::GoForward(CefRefPtr<CefBrowser> browser) {
  if (browser && browser->CanGoForward()) {
    browser->GoForward();
  }
}

void SimpleHandler::OnAddressChange(CefRefPtr<CefBrowser> browser,
                                    CefRefPtr<CefFrame> frame,
                                    const CefString& url) {
  if (!frame->IsMain())
    return;
  
  NSWindow* window = GetNSWindowForBrowser(browser);
  NSView* contentView = [window contentView];
  NSTextField* urlField = [contentView viewWithTag:100];
  
  if (urlField) {
    std::string urlStr = url.ToString();
    [urlField setStringValue:[NSString stringWithUTF8String:urlStr.c_str()]];
  }
}
