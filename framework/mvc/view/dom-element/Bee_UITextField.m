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

#import "Bee_UITextField.h"
#import "Bee_UISignalBus.h"

#import "UIView+BeeUISignal.h"
#import "UIView+LifeCycle.h"

#pragma mark -

@interface BeeUITextFieldAgent : NSObject<UITextFieldDelegate>
{
	BeeUITextField * _target;
}

@property (nonatomic, assign) BeeUITextField *	target;

@end

#pragma mark -

@implementation BeeUITextFieldAgent

@synthesize target = _target;

- (void)dealloc
{
	[NSObject cancelPreviousPerformRequestsWithTarget:self];
	
	[super dealloc];
}

#pragma mark -

- (BOOL)textFieldShouldBeginEditing:(UITextField *)textField
{
	[_target sendUISignal:BeeUITextField.WILL_ACTIVE];
	return YES;
}

- (void)textFieldDidBeginEditing:(UITextField *)textField
{
	if ( NO == textField.window.isKeyWindow )
    {
        [textField.window makeKeyAndVisible];
    }

	[_target sendUISignal:BeeUITextField.DID_ACTIVED];
}

- (BOOL)textFieldShouldEndEditing:(UITextField *)textField
{
	[_target sendUISignal:BeeUITextField.WILL_DEACTIVE];
	return YES;
}

- (void)textFieldDidEndEditing:(UITextField *)textField
{
	[_target sendUISignal:BeeUITextField.DID_DEACTIVED];
}

- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string
{
    if ( 1 == range.length )
    {
        [NSObject cancelPreviousPerformRequestsWithTarget:self];
        [self performSelector:@selector(notifyTextChanged) withObject:nil afterDelay:0.1f];
        return YES;
    }
    else
    {
        NSString * text = [_target.text stringByReplacingCharactersInRange:range withString:string];
        if ( _target.maxLength > 0 && [_target textOverFlow] )
        {
            [_target sendUISignal:BeeUITextField.TEXT_OVERFLOW];
            return NO;
        }
        else
        {
            if ( _target.isNumber )
            {
                return [_target validateNumber:string];
            }
        }
        
        [NSObject cancelPreviousPerformRequestsWithTarget:self];
        [self performSelector:@selector(notifyTextChanged) withObject:nil afterDelay:0.1f];
        return YES;
    }
}

- (BOOL)textFieldShouldClear:(UITextField *)textField
{
	BeeUISignal * signal = [_target sendUISignal:BeeUITextField.CLEAR];
	if ( signal && signal.returnValue )
	{
		return signal.boolValue;
	}

	return YES;
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
	BeeUISignal * signal = [_target sendUISignal:BeeUITextField.RETURN];
	if ( signal && signal.returnValue )
	{
		return signal.boolValue;
	}
	
	return YES;
}

- (void)notifyTextChanged
{
	[_target sendUISignal:BeeUITextField.TEXT_CHANGED withObject:_target.text];
}

@end

#pragma mark -

@interface BeeUITextField()
{
	BOOL					_inited;
	BeeUITextFieldAgent *	_agent;
	NSUInteger				_maxLength;
	UIResponder *			_nextChain;
}

- (void)initSelf;

@end

@implementation BeeUITextField

DEF_SIGNAL( WILL_ACTIVE )
DEF_SIGNAL( DID_ACTIVED )
DEF_SIGNAL( WILL_DEACTIVE )
DEF_SIGNAL( DID_DEACTIVED )
DEF_SIGNAL( TEXT_CHANGED )
DEF_SIGNAL( TEXT_OVERFLOW )
DEF_SIGNAL( CLEAR )
DEF_SIGNAL( RETURN )

@dynamic active;
@synthesize nextChain = _nextChain;
@synthesize maxLength = _maxLength;

- (id)init
{
    if( (self = [super initWithFrame:CGRectZero]) )
    {	
		[self initSelf];
    }
    return self;	
}

- (id)initWithFrame:(CGRect)frame
{
    if( (self = [super initWithFrame:frame]) )
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
		self.contentVerticalAlignment = UIControlContentVerticalAlignmentCenter;
		self.contentMode = UIViewContentModeCenter;
	
		_agent = [[BeeUITextFieldAgent alloc] init];
		_agent.target = self;
		self.delegate = _agent;
		
		_maxLength = 0;
		_inited = YES;
        
        [self addTarget:self action:@selector(textFiledEditChanged:) forControlEvents:UIControlEventEditingChanged];

//		[self load];
		[self performLoad];
	}
}

- (void)dealloc
{
//	[self unload];
	[self performUnload];

	self.delegate = nil;
	
	[_agent release];
	
    [super dealloc];
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
//		[self resignFirstResponder];
		[self endEditing:YES];
	}
}

- (void)handleUISignal:(BeeUISignal *)signal
{
	if ( [signal is:self.RETURN] )
	{
		if ( _nextChain && _nextChain != self )
		{
			[_nextChain becomeFirstResponder];
			return;
		}
		else if ( nil == _nextChain )
		{
			[self resignFirstResponder];
			return;
		}
	}

	SIGNAL_FORWARD( signal );
}

-(void)textFiledEditChanged:(UITextField *)obj
{
    [self textOverFlow];
}

- (BOOL) textOverFlow
{
    NSString *toBeString = self.text;
    NSString *lang = [[UITextInputMode currentInputMode] primaryLanguage]; // 键盘输入模式
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

#pragma mark -

- (BOOL)validateNumber:(NSString*)number
{
    BOOL res = YES;
    NSCharacterSet* tmpSet = [NSCharacterSet characterSetWithCharactersInString:@"0123456789."];
    int i = 0;
    while (i < number.length) {
        NSString * string = [number substringWithRange:NSMakeRange(i, 1)];
        NSRange range = [string rangeOfCharacterFromSet:tmpSet];
        if (range.length == 0) {
            res = NO;
            break;
        }
        i++;
    }
    return res;
}

@end

#endif	// #if (TARGET_OS_IPHONE || TARGET_IPHONE_SIMULATOR)
