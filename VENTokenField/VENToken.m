// VENToken.m
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

#import "VENToken.h"

@interface VENToken ()
@property (strong, nonatomic) UITapGestureRecognizer *tapGestureRecognizer;
@property (strong, nonatomic) IBOutlet UIView *backgroundView;
@end

@implementation VENToken

- (id)initWithFrame:(CGRect)frame
{
    self = [[[NSBundle mainBundle] loadNibNamed:NSStringFromClass([self class]) owner:self options:nil] firstObject];
    if (self) {
        [self setUpInit];
    }
    return self;
}

- (void)setUpInit
{
    self.backgroundView.layer.cornerRadius = 5;
    self.tapGestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(didTapToken:)];
    self.colorScheme = [UIColor blueColor];
    self.titleLabel.textColor = self.colorScheme;
    [self addGestureRecognizer:self.tapGestureRecognizer];
}

- (void)setTitleText:(NSAttributedString *)text
{
    //Text has to be attributed for the comma colored black
    self.titleLabel.attributedText = text;

    self.titleLabel.lineBreakMode = NSLineBreakByTruncatingTail;

    [self.titleLabel sizeToFit];
    self.frame = CGRectMake(CGRectGetMinX(self.frame), CGRectGetMinY(self.frame), CGRectGetMaxX(self.titleLabel.frame) + 3, CGRectGetHeight(self.frame));

    CGRect frame = _titleLabel.frame;
    //Set universal height size for label
    frame.size.height += 3;
    
    CGFloat deltaH = (frame.size.height - _titleLabel.frame.size.height) / 2;
    frame.origin.y -= deltaH;
    _titleLabel.frame = frame;
}

- (void)setHighlighted:(BOOL)highlighted
{
    _highlighted = highlighted;
    UIColor *textColor = highlighted ? [UIColor whiteColor] : self.colorScheme;
    UIColor *backgroundColor = highlighted ? self.colorScheme : [UIColor clearColor];
    self.titleLabel.textColor = textColor;
    self.backgroundView.backgroundColor = backgroundColor;
}

- (void)setColorScheme:(UIColor *)colorScheme
{
    _colorScheme = colorScheme;
    self.titleLabel.textColor = self.colorScheme;
    [self setHighlighted:_highlighted];
}


#pragma mark - Private

- (void)didTapToken:(UITapGestureRecognizer *)tapGestureRecognizer
{
    if (self.didTapTokenBlock) {
        self.didTapTokenBlock();
    }
}

@end
