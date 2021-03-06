// VENTokenField.m
//
// Copyright (c) 2014 Venmo
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

#import "VENTokenField.h"

#import <FrameAccessor/FrameAccessor.h>
#import "VENToken.h"

static const CGFloat VENTokenFieldDefaultHeight             = 44.0;

static const CGFloat VENTokenFieldDefaultVerticalInset      = 7.0;
static const CGFloat VENTokenFieldDefaultHorizontalInset    = 15.0;
static const CGFloat VENTokenFieldDefaultToLabelPadding     = 5.0;
static const CGFloat VENTokenFieldDefaultTokenPadding       = 2.0;
static const CGFloat VENTokenFieldDefaultMinInputWidth      = 5.0;
static const CGFloat VENTokenFieldDefaultMaxHeight          = 150.0;

NSString * const kTextEmpty = @"\u200B"; // Zero-Width Space
NSString * const kTextHidden = @"\u200D"; // Zero-Width Joiner

@interface VENTokenField () <VENBackspaceTextFieldDelegate, UIGestureRecognizerDelegate> {
    BOOL _isFirstResponder;
    BOOL _isLineBreak;
    CGFloat _heightestHeight;
    CGFloat _contentSizeHeight;
    BOOL _loaded;
}

@property (strong, nonatomic) NSMutableArray *tokens;
@property (assign, nonatomic) CGFloat originalHeight;
@property (strong, nonatomic) UITapGestureRecognizer *tapGestureRecognizer;
@property (strong, nonatomic) VENBackspaceTextField *invisibleTextField;
@property (strong, nonatomic) UIColor *colorScheme;
@property (strong, nonatomic) UILabel *collapsedLabel;
@property (strong, nonatomic) UIScrollView *scrollView;

@end


@implementation VENTokenField

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {

    }
    return self;
}

- (void)awakeFromNib
{
    [super awakeFromNib];
    [self setUpInit];
}

- (void)layoutSubviews {
    [super layoutSubviews];
    
    if (!_loaded) {
        _loaded = YES;
        // Add invisible text field to handle backspace when we don't have a real first responder.
        [self layoutInvisibleTextField];
        
        [self layoutScrollView];
        
        [self reloadData];

    }
}

- (BOOL)becomeFirstResponder
{
    [self reloadData];
    [self inputTextFieldBecomeFirstResponder];
    return YES;
}

- (BOOL)resignFirstResponder
{
    return [self.inputTextField resignFirstResponder];
}

- (void)setUpInit
{
    // Set up default values.
    self.maxHeight = VENTokenFieldDefaultMaxHeight;
    self.defaultHeight = VENTokenFieldDefaultHeight;
    self.verticalInset = VENTokenFieldDefaultVerticalInset;
    self.horizontalInset = VENTokenFieldDefaultHorizontalInset;
    self.tokenPadding = VENTokenFieldDefaultTokenPadding;
    self.minInputWidth = VENTokenFieldDefaultMinInputWidth;
    self.colorScheme = [UIColor blueColor];
    self.toLabelTextColor =  [UIColor blackColor]; //[UIColor colorWithRed:112/255.0f green:124/255.0f blue:124/255.0f alpha:1.0f];
    self.inputTextFieldTextColor = [UIColor colorWithRed:38/255.0f green:39/255.0f blue:41/255.0f alpha:1.0f];
    
    // Accessing bare value to avoid kicking off a premature layout run.
    _toLabelText = NSLocalizedString(@"To:", nil);
    
    self.originalHeight = CGRectGetHeight(self.frame);
    
    _isFirstResponder = NO;
    _isLineBreak = NO;

    self.tapGestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleSingleTap:)];
    [self addGestureRecognizer:self.tapGestureRecognizer];
    self.tapGestureRecognizer.numberOfTapsRequired = 1;
    self.tapGestureRecognizer.delegate = self;

//    // Add invisible text field to handle backspace when we don't have a real first responder.
//    [self layoutInvisibleTextField];
//    
//    [self layoutScrollView];
    
//    [self reloadData];
}

- (void)collapse
{
    [self.collapsedLabel removeFromSuperview];
    self.scrollView.hidden = YES;
    [self setHeight:self.originalHeight animate:YES withDuration:0.3f forView:self];
//    [self setHeight:self.originalHeight];
    
    CGFloat currentX = 0;
    
    [self layoutToLabelInView:self origin:CGPointMake(self.horizontalInset, self.verticalInset) currentX:&currentX];
    [self layoutCollapsedLabelWithCurrentX:&currentX];
}

- (void)reloadData
{
    BOOL inputFieldShouldBecomeFirstResponder = self.inputTextField.isFirstResponder;
    
    if (_isLineBreak) {
        [self.scrollView setContentOffsetY:_contentSizeHeight];
        _isLineBreak = NO;
    }

    [self.collapsedLabel removeFromSuperview];
    // [self.scrollView.subviews makeObjectsPerformSelector:@selector(removeFromSuperview)];

    //Remove subviews, otherthan scroll indicators to allow them visibility.
    
    /*==================uncomment to allow deletion repeat==================
    [self.inputTextField removeFromSuperview];*/
    [self.tokens makeObjectsPerformSelector:@selector(removeFromSuperview)];
    
    self.scrollView.hidden = NO;
//    [self removeGestureRecognizer:self.tapGestureRecognizer];
    
    self.tokens = [NSMutableArray array];
    
    CGFloat currentX = 0;
    CGFloat currentY = 0;
    
    [self layoutToLabelInView:self.scrollView origin:CGPointZero currentX:&currentX];
    [self layoutTokensWithCurrentX:&currentX currentY:&currentY];
    [self layoutInputTextFieldWithCurrentX:&currentX currentY:&currentY isFirstResponder:_isFirstResponder];
    
    [self adjustHeightForCurrentY:currentY];
    [self.scrollView setContentSize:CGSizeMake(self.scrollView.contentSize.width, currentY+1 + [self heightForToken])];
    [self setScrollViewEnabled];
    
    [self updateInputTextField];
    
    if (inputFieldShouldBecomeFirstResponder) {
        [self inputTextFieldBecomeFirstResponder];
    } else {
        [self focusInputTextField];
    }
}

- (void)setPlaceholderText:(NSString *)placeholderText
{
    _placeholderText = placeholderText;
    self.inputTextField.placeholder = _placeholderText;
}

- (void)setInputTextFieldTextColor:(UIColor *)inputTextFieldTextColor
{
    _inputTextFieldTextColor = inputTextFieldTextColor;
    self.inputTextField.textColor = _inputTextFieldTextColor;
}

- (void)setToLabelTextColor:(UIColor *)toLabelTextColor
{
    _toLabelTextColor = toLabelTextColor;
    self.toLabel.textColor = _toLabelTextColor;
}

- (void)setToLabelText:(NSString *)toLabelText
{
    _toLabelText = toLabelText;
    [self reloadData];
}

- (void)setColorScheme:(UIColor *)color
{
    _colorScheme = color;
    self.collapsedLabel.textColor = color;
    self.inputTextField.tintColor = color;
    for (VENToken *token in self.tokens) {
        [token setColorScheme:color];
    }
}

- (NSString *)inputText
{
    return self.inputTextField.text;
}

#pragma mark - View Layout

- (void)layoutScrollView
{
    self.scrollView = [[UIScrollView alloc] initWithFrame:CGRectMake(0, 0, CGRectGetWidth(self.frame), CGRectGetHeight(self.frame))];
    self.scrollView.scrollsToTop = NO;
    self.scrollView.contentSize = CGSizeMake(CGRectGetWidth(self.frame) - self.horizontalInset * 2, CGRectGetHeight(self.frame) - self.verticalInset * 2);
    self.scrollView.contentInset = UIEdgeInsetsMake(self.verticalInset,
                                                    self.horizontalInset,
                                                    self.verticalInset,
                                                    self.horizontalInset);
    self.scrollView.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
    
    [self addSubview:self.scrollView];
}

- (void)layoutInputTextFieldWithCurrentX:(CGFloat *)currentX currentY:(CGFloat *)currentY isFirstResponder:(BOOL)isFirstResponder
{
    CGFloat inputTextFieldWidth = self.scrollView.contentSize.width - *currentX;
//    if (inputTextFieldWidth < self.minInputWidth) {
    if (inputTextFieldWidth >= self.scrollView.contentSize.width-self.minInputWidth) {
        inputTextFieldWidth = self.scrollView.contentSize.width;
        *currentY += [self heightForToken];
        *currentX = 0;
    }
    if (inputTextFieldWidth < self.minInputWidth && isFirstResponder) {
        inputTextFieldWidth = self.scrollView.contentSize.width;
        *currentY += [self heightForToken];
        *currentX = 0;
    }
    
    VENBackspaceTextField *inputTextField = self.inputTextField;
    inputTextField.text = @"";
    inputTextField.frame = CGRectMake(*currentX, *currentY + 1, inputTextFieldWidth, [self heightForToken] - 1);
    inputTextField.tintColor = self.colorScheme;
    [self.scrollView addSubview:inputTextField];
}

- (void)layoutCollapsedLabelWithCurrentX:(CGFloat *)currentX
{
    UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(*currentX, CGRectGetMinY(self.toLabel.frame), self.width - *currentX - self.horizontalInset, self.toLabel.height)];
    label.font = [UIFont fontWithName:@"HelveticaNeue" size:15.5];
    label.text = [self collapsedText];
    label.textColor = self.colorScheme;
    label.minimumScaleFactor = 5./label.font.pointSize;
    label.adjustsFontSizeToFitWidth = YES;
    [self addSubview:label];
    self.collapsedLabel = label;
}

- (void)layoutToLabelInView:(UIView *)view origin:(CGPoint)origin currentX:(CGFloat *)currentX
{
    [self.toLabel removeFromSuperview];
    self.toLabel = [self toLabel];
    
    CGRect newFrame = self.toLabel.frame;
    newFrame.origin = origin;
    
    [self.toLabel sizeToFit];
    newFrame.size.width = CGRectGetWidth(self.toLabel.frame);
    
    self.toLabel.frame = newFrame;
    
    [view addSubview:self.toLabel];
    *currentX += self.toLabel.hidden ? CGRectGetMinX(self.toLabel.frame) : CGRectGetMaxX(self.toLabel.frame) + VENTokenFieldDefaultToLabelPadding;
}

- (void)layoutTokensWithCurrentX:(CGFloat *)currentX currentY:(CGFloat *)currentY
{
    for (NSUInteger i = 0; i < [self numberOfTokens]; i++) {
        NSString *title = [self titleForTokenAtIndex:i];
        VENToken *token = [[VENToken alloc] init];
        token.colorScheme = self.colorScheme;
        
        __weak VENToken *weakToken = token;
        __weak VENTokenField *weakSelf = self;
        token.didTapTokenBlock = ^{
            [weakSelf didTapToken:weakToken];
        };
        
        //Set token's title with new attributed string:
        [token setTitleText:[self attributeString:[NSString stringWithFormat:@"\u200E%@\u200E",title]]];
        
        [self.tokens addObject:token];
        CGFloat tokenWidth = token.width;
        
        if (*currentX + token.width <= self.scrollView.contentSize.width) { // token fits in current line
            token.frame = CGRectMake(*currentX, *currentY, token.width, token.height);
        } else {
            if (tokenWidth > self.scrollView.contentSize.width) { // token is wider than max width
                CGFloat delta = 26;
                if (*currentX <= delta) {
                    *currentX = delta;
                } else {
                    *currentX = 0;
                    *currentY += token.height;
                    delta = 5;
                }
                tokenWidth = self.scrollView.contentSize.width-delta;
                token.titleLabel.frame = CGRectMake(token.titleLabel.frame.origin.x, token.titleLabel.frame.origin.y, tokenWidth, token.titleLabel.frame.size.height);
            } else {
                *currentY += token.height;
                *currentX = 0;
            }
//            CGFloat tokenWidth = token.width;
//            if (tokenWidth > self.scrollView.contentSize.width) { // token is wider than max width
//                tokenWidth = self.scrollView.contentSize.width-10;
//                token.titleLabel.frame = CGRectMake(token.titleLabel.frame.origin.x, token.titleLabel.frame.origin.y, tokenWidth, token.titleLabel.frame.size.height);
            }
            token.frame = CGRectMake(*currentX, *currentY, tokenWidth, token.height);
//        }
        *currentX += token.width + self.tokenPadding;
        [self.scrollView addSubview:token];
    }
}

- (NSAttributedString *)attributeString:(NSString *)string {
    //Creating an attributed string, for commas need to be black:
    NSMutableAttributedString *new = [[NSMutableAttributedString alloc]initWithString:string];
    NSMutableAttributedString *commaText = [[NSMutableAttributedString alloc] initWithString:@","];
    
    [commaText addAttribute:NSForegroundColorAttributeName value:[UIColor blackColor] range:NSMakeRange(0, 1)];
    [new appendAttributedString:commaText];
    return new;
}
#pragma mark - Private

- (CGFloat)heightForToken
{
    return 29;
}

- (void)setHeight:(CGFloat)newHeight animate:(BOOL)animate withDuration:(CGFloat)duration forView:(UIView *)view {
    CGRect newFrame = view.frame;
    newFrame.size.height = newHeight;

    if (animate) {
        [UIView animateWithDuration:duration delay:0.0f options:UIViewAnimationOptionCurveEaseInOut animations:^{
            view.frame = newFrame;
        } completion:nil];
    } else {
        view.frame = newFrame;
    }
}

- (void)layoutInvisibleTextField
{
    self.invisibleTextField = [[VENBackspaceTextField alloc] initWithFrame:CGRectZero];
    self.invisibleTextField.delegate = self;
    self.invisibleTextField.autocorrectionType = UITextAutocorrectionTypeNo;
    self.invisibleTextField.returnKeyType = UIReturnKeyDone;
    [self.invisibleTextField addTarget:self action:@selector(textFieldShouldReturn:) forControlEvents:UIControlEventEditingDidEnd];
    [self addSubview:self.invisibleTextField];
}

- (void)inputTextFieldBecomeFirstResponder
{
//    if (self.inputTextField.isFirstResponder) {
//        return;
//    }
    
    [self.inputTextField becomeFirstResponder];
    if (self.tokens.count) {
        [self.inputTextField setText:kTextEmpty];
    }
    _inputTextField.alpha = 1.0;
    if ([self.delegate respondsToSelector:@selector(tokenFieldDidBeginEditing:)]) {
        [self.delegate tokenFieldDidBeginEditing:self];
    }
}

- (UILabel *)toLabel
{
    if (!_toLabel) {
        _toLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        _toLabel.textColor = self.toLabelTextColor;
        _toLabel.font = [UIFont fontWithName:@"HelveticaNeue" size:15.5];
        _toLabel.x = 0;
        [_toLabel sizeToFit];
        [_toLabel setHeight:[self heightForToken]];
    }
    if (![_toLabel.text isEqualToString:_toLabelText]) {
        _toLabel.text = _toLabelText;
    }
    return _toLabel;
}

- (void)adjustHeightForCurrentY:(CGFloat)currentY
{
    CGFloat newHeight;
    CGFloat duration = 0.3f;
    
    if (currentY + [self heightForToken] > CGRectGetHeight(self.frame)) { // needs to grow
        if (currentY + [self heightForToken] <= self.maxHeight) {
            newHeight = currentY + [self heightForToken] + self.verticalInset * 2;
            [self setHeight:newHeight animate:YES withDuration:duration forView:self];
        } else {
            newHeight = self.maxHeight + 6;
            [self setHeight:newHeight animate:YES withDuration:duration forView:self];
        }
    } else { // needs to shrink
        if (currentY + [self heightForToken] > self.originalHeight) {
            newHeight = currentY + [self heightForToken] + self.verticalInset * 2;
            [self setHeight:newHeight animate:YES withDuration:duration forView:self];
        } else {
            newHeight = self.originalHeight;
            [self setHeight:newHeight animate:YES withDuration:duration forView:self];
        }
    }
    //Send a message to delegate regarding height changes
    if (self.height != self.maxHeight || ((self.height == self.maxHeight) && _isFirstResponder)) {
        if ([self.delegate respondsToSelector:@selector(tokenField:didChangeHeight:withAnimation:andDuration:)]) {
            [self.delegate tokenField:self didChangeHeight:self.height withAnimation:YES andDuration:duration];
        }
    }
}

- (void)setScrollViewEnabled {
    CGFloat height = self.scrollView.contentSize.height;
    if (height <= self.maxHeight+6) {
        [self.scrollView setScrollEnabled:NO];
    } else {
        [self.scrollView setScrollEnabled:YES];
    }
}

- (VENBackspaceTextField *)inputTextField
{
    if (!_inputTextField) {
        _inputTextField = [[VENBackspaceTextField alloc] init];
        [_inputTextField setKeyboardType:self.inputTextFieldKeyboardType];
        _inputTextField.textColor = self.inputTextFieldTextColor;
        _inputTextField.font = [UIFont fontWithName:@"HelveticaNeue" size:15.5];
        _inputTextField.accessibilityLabel = NSLocalizedString(@"To", nil);
        _inputTextField.autocorrectionType = UITextAutocorrectionTypeNo;
        _inputTextField.tintColor = self.colorScheme;
        _inputTextField.delegate = self;
        self.inputTextField.returnKeyType = UIReturnKeyDone;
        _inputTextField.placeholder = self.placeholderText;
        [_inputTextField addTarget:self action:@selector(inputTextFieldDidChange:) forControlEvents:UIControlEventEditingChanged];
    }
    return _inputTextField;
}

- (void)setInputTextFieldKeyboardType:(UIKeyboardType)inputTextFieldKeyboardType
{
    _inputTextFieldKeyboardType = inputTextFieldKeyboardType;
    [self.inputTextField setKeyboardType:self.inputTextFieldKeyboardType];
}

- (void)inputTextFieldDidChange:(UITextField *)textField
{
    //Get the siz of the entered text
    CGSize size = [textField.text sizeWithFont:[UIFont fontWithName:@"HelveticaNeue-Medium" size:15]];
    //If typing exceeded the width of the screen, need to break a line
    if (textField.x + size.width > self.scrollView.contentSize.width-10) {
        //Don't break a line if the size of the text is bigger then scroll's width
        if (size.width < self.scrollView.contentSize.width-20) {
            CGFloat newHeight = 0;
            CGFloat newYposition = self.scrollView.contentSizeHeight;
            //Before reaching maxHeight, we can fit 3 lines, so first deal with line 1 and line 2
            if (self.height < self.maxHeight) {
                if (self.height <= self.originalHeight) {
                    newHeight = self.scrollView.contentOffsetY + [self heightForToken] + self.verticalInset * 2;
                } else {
                    newHeight = self.height + [self heightForToken];
                }
            } else {
                //Reached the height limit, need to refresh the scrollView
                [self.collapsedLabel removeFromSuperview];
                [self.tokens makeObjectsPerformSelector:@selector(removeFromSuperview)];
                self.tokens = [NSMutableArray array];

                //Set values to return to when reloading data again, so the display won't freeze
                _contentSizeHeight = self.scrollView.contentOffsetY;
                _isLineBreak = YES;

                CGFloat currentX = 25.5;
                CGFloat currentY = 0.0;
                [self layoutTokensWithCurrentX:&currentX currentY:&currentY];
                newHeight = currentY;
            }
            //Finally, break a line
            self.inputTextField.frame = CGRectMake(0, newYposition, self.scrollView.contentSize.width, textField.height);
            //Adjust new height for the view and in there call delegate to animate
            [self adjustHeightForCurrentY:newHeight];
            //Set new height for scrollView
            [self.scrollView setContentSize:CGSizeMake(self.scrollView.contentSize.width, newHeight+1 + [self heightForToken])];

            [self setScrollViewEnabled];
            [self focusInputTextField];
        }
    }
    
    if ([self.delegate respondsToSelector:@selector(tokenField:didChangeText:)]) {
        [self.delegate tokenField:self didChangeText:textField.text];
    }
}

- (void)handleSingleTap:(UITapGestureRecognizer *)gestureRecognizer
{
    _isFirstResponder = YES;
    [self becomeFirstResponder];
}

- (void)didTapToken:(VENToken *)token
{
    for (VENToken *aToken in self.tokens) {
        if (aToken == token) {
            aToken.highlighted = !aToken.highlighted;
        } else {
            if (aToken.highlighted) {
                aToken.highlighted = NO;
            }
        }
    }
    [self setCursorVisibility];
}

- (void)unhighlightAllTokens
{
    for (VENToken *token in self.tokens) {
        if (token.highlighted) {
            token.highlighted = NO;
            
            //Reset token to be attributed
            token.titleLabel.text = [token.titleLabel.text stringByReplacingOccurrencesOfString:@"," withString:@""];
            NSString *title = [NSString stringWithFormat:@"\u200E%@\u200E",token.titleLabel.text];
            [token setTitleText:[self attributeString:title]];
        }
    }
    [self setCursorVisibility];
}

- (void)setCursorVisibility
{
    NSArray *highlightedTokens = [self.tokens filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(VENToken *evaluatedObject, NSDictionary *bindings) {
        return evaluatedObject.highlighted;
    }]];
    BOOL visible = [highlightedTokens count] == 0;
    if (visible) {
        [self inputTextFieldBecomeFirstResponder];
    } else {
        [self.invisibleTextField becomeFirstResponder];
        [self.invisibleTextField setText:kTextHidden];
    }
}

- (void)updateInputTextField
{
    self.inputTextField.placeholder = [self.tokens count] ? nil : self.placeholderText;
}

- (void)focusInputTextField
{
    CGPoint contentOffset = self.scrollView.contentOffset;
    CGFloat targetY = self.inputTextField.y + [self heightForToken] - self.maxHeight;
    if (targetY > contentOffset.y) {
        [self.scrollView setContentOffset:CGPointMake(contentOffset.x, targetY) animated:NO];
    }
}

#pragma mark - Data Source

- (NSString *)titleForTokenAtIndex:(NSUInteger)index
{
    if ([self.dataSource respondsToSelector:@selector(tokenField:titleForTokenAtIndex:)]) {
        return [self.dataSource tokenField:self titleForTokenAtIndex:index];
    }
    return [NSString string];
}

- (NSUInteger)numberOfTokens
{
    if ([self.dataSource respondsToSelector:@selector(numberOfTokensInTokenField:)]) {
        return [self.dataSource numberOfTokensInTokenField:self];
    }
    return 0;
}

- (NSString *)collapsedText
{
    if ([self.dataSource respondsToSelector:@selector(tokenFieldCollapsedText:)]) {
        return [self.dataSource tokenFieldCollapsedText:self];
    }
    return @"";
}

- (void)deleteHighlighted {
    for (VENToken *aToken in self.tokens) {
        if (aToken.highlighted) {
            aToken.highlighted = NO;
            [self deleteHighlightedToken:aToken];
            break;
        }
    }
}

#pragma mark - UITextFieldDelegate

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    _isFirstResponder = NO;
    
    if ([self.delegate respondsToSelector:@selector(tokenField:didEnterText:)]) {
        //        if ([textField.text length]) {
        if (textField == self.invisibleTextField) {
            [self unhighlightAllTokens];
        }
        [self.delegate tokenField:self didEnterText:textField.text];
        
        //        }
    }
    [self reloadData];

    return YES;
}

- (void)textFieldDidBeginEditing:(UITextField *)textField
{
    if (textField == self.inputTextField) {
        [self unhighlightAllTokens];
    }
}

- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string {
    if (self.tokens.count && [string isEqualToString:@""] && [textField.text isEqualToString:kTextEmpty]){
        VENToken *lastToken = [self.tokens lastObject];
        lastToken.highlighted = YES;
        [_inputTextField setText:kTextHidden];
        _inputTextField.alpha = 0.0;
        return NO;
    }
    
    if ([textField.text isEqualToString:kTextHidden]){
        [self deleteHighlighted];
        [self unhighlightAllTokens];

        return (![string isEqualToString:@""]);
    }

    //If there are any highlighted tokens, delete
    [self deleteHighlighted];
    return YES;
}

- (void)deleteHighlightedToken:(VENToken *)token {
    [self.delegate tokenField:self didDeleteTokenAtIndex:[self.tokens indexOfObject:token]];
    //    [self setCursorVisibility];
}

//#pragma mark - VENBackspaceTextFieldDelegate
//
//- (void)textFieldDidEnterBackspace:(VENBackspaceTextField *)textField
//{
//    if ([self.delegate respondsToSelector:@selector(tokenField:didDeleteTokenAtIndex:)] && [self numberOfTokens]) {
//        BOOL didDeleteToken = NO;
//        for (VENToken *token in self.tokens) {
//            if (token.highlighted) {
//                [self.delegate tokenField:self didDeleteTokenAtIndex:[self.tokens indexOfObject:token]];
//                didDeleteToken = YES;
//                break;
//            }
//        }
//        if (!didDeleteToken) {
//            VENToken *lastToken = [self.tokens lastObject];
//            lastToken.highlighted = YES;
//        }
//        [self setCursorVisibility];
//    }
//}

@end
