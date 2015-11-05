//
//	 ______    ______    ______
//	/\  __ \  /\  ___\  /\  ___\
//	\ \  __<  \ \  __\_ \ \  __\_
//	 \ \_____\ \ \_____\ \ \_____\
//	  \/_____/  \/_____/  \/_____/
//
//
//	Copyright (c) 2014-2015, Geek Zoo Studio
//	http://www.bee-framework.com
//
//
//	Permission is hereby granted, free of charge, to any person obtaining a
//	copy of this software and associated documentation files (the "Software"),
//	to deal in the Software without restriction, including without limitation
//	the rights to use, copy, modify, merge, publish, distribute, sublicense,
//	and/or sell copies of the Software, and to permit persons to whom the
//	Software is furnished to do so, subject to the following conditions:
//
//	The above copyright notice and this permission notice shall be included in
//	all copies or substantial portions of the Software.
//
//	THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//	IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//	FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//	AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//	LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
//	FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
//	IN THE SOFTWARE.
//

#if (TARGET_OS_IPHONE || TARGET_IPHONE_SIMULATOR)

#import "Bee_UITextView.h"
#import "Bee_UISignalBus.h"

#import "UIView+BeeUISignal.h"
#import "UIView+LifeCycle.h"

#pragma mark -

@interface BeeUITextViewAgent : NSObject<UITextViewDelegate>
{
	BeeUITextView *	_target;
}

@property (nonatomic, assign) BeeUITextView *	target;

@end

#pragma mark -

@implementation BeeUITextViewAgent

@synthesize target = _target;

- (BOOL)textViewShouldBeginEditing:(UITextView *)textView
{
	[_target updatePlaceHolder];
	[_target sendUISignal:BeeUITextView.WILL_ACTIVE];
	return YES;
}

- (void)textViewDidBeginEditing:(UITextView *)textView
{
	[_target updatePlaceHolder];
	[_target sendUISignal:BeeUITextView.DID_ACTIVED];
}

- (BOOL)textViewShouldEndEditing:(UITextView *)textView
{
	[_target updatePlaceHolder];
	[_target sendUISignal:BeeUITextView.WILL_DEACTIVE];
	return YES;
}

- (void)textViewDidEndEditing:(UITextView *)textView
{
	[_target updatePlaceHolder];
	[_target sendUISignal:BeeUITextView.DID_DEACTIVED];
}

- (BOOL)textView:(UITextView *)textView shouldChangeTextInRange:(NSRange)range replacementText:(NSString *)string
{
	if ( 1 == range.length )
	{
		[_target sendUISignal:BeeUITextView.TEXT_CHANGED];
		return YES;
	}
	
	if ( [string isEqualToString:@"\n"] || [string isEqualToString:@"\r"] )
	{
		BeeUISignal * signal = [_target sendUISignal:BeeUITextView.RETURN];
		if ( signal && _target.noNewLine)
		{
			return signal.boolValue;
		}
	}
    NSString * text = [_target.text empty] ? string : _target.text;
    // if ( _target.maxLength > 0 && text.length > _target.maxLength )
    // 计算汉字和联想输入导致的字符变化
    if ( _target.maxLength > 0 && [_target textOverFlow:text] )
	{
		[_target sendUISignal:BeeUITextView.TEXT_OVERFLOW];
        [_target sendUISignal:BeeUITextView.TEXT_CHANGED];
		return NO;
	}
	return YES;
}

- (void)textViewDidChange:(UITextView *)textView
{
	[_target updatePlaceHolder];
    NSString * string  = [_target.text empty] ? textView.text : _target.text;
    // if ( _target.maxLength > 0 && text.length > _target.maxLength )
    // 计算汉字和联想输入导致的字符变化
    if ( _target.maxLength > 0 && [_target textOverFlow:string] )
    {
        [_target sendUISignal:BeeUITextView.TEXT_OVERFLOW];
    }
    
    [_target sendUISignal:BeeUITextView.TEXT_CHANGED];
}

- (void)textViewDidChangeSelection:(UITextView *)textView
{
	[_target updatePlaceHolder];
	[_target sendUISignal:BeeUITextView.SELECTION_CHANGED];
}

@end

#pragma mark -

@interface BeeUITextView()
{
	BOOL					_inited;
	BeeUITextViewAgent *	_agent;
    NSString *				_placeholder;
    UIColor *				_placeHolderColor;
    UILabel *				_placeHolderLabel;
	NSUInteger				_maxLength;
	UIResponder *			_nextChain;
}

- (void)initSelf;

@end

#pragma mark -

@implementation BeeUITextView

DEF_SIGNAL( WILL_ACTIVE )
DEF_SIGNAL( DID_ACTIVED )
DEF_SIGNAL( WILL_DEACTIVE )
DEF_SIGNAL( DID_DEACTIVED )
DEF_SIGNAL( TEXT_CHANGED )
DEF_SIGNAL( TEXT_OVERFLOW )
DEF_SIGNAL( SELECTION_CHANGED )
DEF_SIGNAL( RETURN )

@synthesize active;
@synthesize placeholder = _placeholder;
@synthesize placeHolderLabel = _placeHolderLabel;
@synthesize placeHolderColor = _placeHolderColor;
@synthesize maxLength = _maxLength;
@synthesize nextChain = _nextChain;

- (id)init
{
	self = [super initWithFrame:CGRectZero];
    if( self )
    {
		[self initSelf];
    }
    return self;	
}

- (id)initWithFrame:(CGRect)frame
{
	self = [super initWithFrame:frame];
    if( self )
    {
		[self initSelf];
    }
    return self;
}

// thanks to @ilikeido
- (id)initWithCoder:(NSCoder *)aDecoder
{
	self = [super initWithCoder:aDecoder];
	if ( self )
	{
		[self initSelf];
	}
	return self;
}

- (void)initSelf
{
	if ( NO == _inited )
	{
		self.opaque = NO;
		self.backgroundColor = [UIColor clearColor];
		self.font = [UIFont systemFontOfSize:14.0f];
		self.userInteractionEnabled = YES;
		self.editable = YES;

		self.placeholder = @"";
		self.placeHolderColor = [UIColor grayColor];

		_agent = [[BeeUITextViewAgent alloc] init];
		_agent.target = self;
		self.delegate = _agent;
		
		_maxLength = 0;
		_inited = YES;
        _noNewLine = YES;
		
//		[self load];
		[self performLoad];
	}
}

- (void)dealloc
{
//	[self unload];
	[self performUnload];

	[_agent release];
	
	self.placeHolderLabel = nil;
	self.placeHolderColor = nil;
	self.placeholder = nil;

    [super dealloc];
}

- (void)drawRect:(CGRect)rect
{
	[self updatePlaceHolder];
    [super drawRect:rect];
}

- (void)updatePlaceHolder
{
    if ( self.frame.size.width )
    {
        if ( [_placeholder length] > 0 )
        {
            if ( nil == _placeHolderLabel )
            {
                CGRect labelFrame = CGRectMake( 9.0f, 8.0f, self.frame.size.width - 18.0f, 0.0f );
                
                _placeHolderLabel = [[UILabel alloc] initWithFrame:labelFrame];
                _placeHolderLabel.lineBreakMode = UILineBreakModeCharacterWrap;
                _placeHolderLabel.numberOfLines = 0;
                _placeHolderLabel.font =  self.font;
                _placeHolderLabel.backgroundColor = [UIColor clearColor];
                _placeHolderLabel.textColor = _placeHolderColor;
                _placeHolderLabel.alpha = 0.0f;
                _placeHolderLabel.opaque = NO;
                [self addSubview:_placeHolderLabel];
            }
            
            _placeHolderLabel.frame = CGRectMake(9.0f, 8.0f, self.frame.size.width - 18.0f, 0);
            _placeHolderLabel.lineBreakMode = UILineBreakModeCharacterWrap;
            _placeHolderLabel.numberOfLines = 0;
            _placeHolderLabel.text = self.placeholder;
            [_placeHolderLabel sizeToFit];
            [self sendSubviewToBack:_placeHolderLabel];
        }
        
        if ( _placeHolderLabel )
        {
            _placeHolderLabel.text = _placeholder;
            [_placeHolderLabel sizeToFit];
            
            if ( [_placeholder length] > 0 )
            {
                if ( 0 == [self.text length] )
                {
                    [_placeHolderLabel setAlpha:1.0f];
                }
                else
                {
                    [_placeHolderLabel setAlpha:0.0f];
                }
            }
        }
    }
}

- (BOOL)active
{
	return [self isFirstResponder];
}

- (void)setActive:(BOOL)flag
{
	if ( flag )
	{
		[self becomeFirstResponder];
	}
	else
	{
		[self resignFirstResponder];
	}
}

- (BOOL) textOverFlow:(NSString *)text
{
    NSString *toBeString = text;
    NSString *lang = [[UIApplication sharedApplication]textInputMode].primaryLanguage;
    // NSString *lang = [[UITextInputMode currentInputMode] primaryLanguage]; // 键盘输入模式
    if ([lang isEqualToString:@"zh-Hans"]) { // 简体中文输入，包括简体拼音，健体五笔，简体手写
        UITextRange *selectedRange = [self markedTextRange];
        //获取高亮部分
        UITextPosition *position = [self positionFromPosition:selectedRange.start offset:0];
        // 没有高亮选择的字，则对已输入的文字进行字数统计和限制
        if (!position) {
            if (_maxLength > 0 && toBeString.length > _maxLength) {
                self.text = [toBeString substringToIndex:_maxLength];
                return YES;
            }
        }
        // 有高亮选择的字符串，则暂不对文字进行统计和限制
        else{
            
        }
    }
    // 中文输入法以外的直接对其统计限制即可，不考虑其他语种情况
    else{
        if (_maxLength > 0 && toBeString.length > _maxLength) {
            self.text = [toBeString substringToIndex:_maxLength];
            return YES;
        }
    }
    return NO;
}

- (void)handleUISignal:(BeeUISignal *)signal
{
	if ( [signal is:self.RETURN] && _noNewLine ) // 按回车时，是否新起一行
	{
		if ( _nextChain && _nextChain != self )
		{
			[_nextChain becomeFirstResponder];
			return;
		}
		else
		{
			[self resignFirstResponder];
		}
	}
	
	SIGNAL_FORWARD( signal );
}

@end

#endif	// #if (TARGET_OS_IPHONE || TARGET_IPHONE_SIMULATOR)
