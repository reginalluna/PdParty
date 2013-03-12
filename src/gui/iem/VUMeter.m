/*
 * Copyright (c) 2013 Dan Wilcox <danomatika@gmail.com>
 *
 * BSD Simplified License.
 * For information on usage and redistribution, and for a DISCLAIMER OF ALL
 * WARRANTIES, see the file, "LICENSE.txt," in this distribution.
 *
 * See https://github.com/danomatika/PdParty for documentation
 *
 */
#import "VUMeter.h"

#import "Gui.h"
#include "z_libpd.h"
#include "g_all_guis.h" // iem gui

#define VU_PAD_W	2
#define VU_PAD_H	4
#define VU_MAX_SCALE_CHAT_WIDTH	4

// helper class
@interface MeterView : UIView
@property (nonatomic, weak) VUMeter* parent;
@property (nonatomic, assign) int rmsBar; // max rms led bar index
@property (nonatomic, assign) int peakBar; // peak led bar index
@property (nonatomic, assign) CGSize ledBarSize;
@end

@interface VUMeter ()
@property (assign) BOOL isDefaultFillColor;
@property (weak) MeterView *meterView;
@end

@implementation VUMeter

+ (id)vumeterFromAtomLine:(NSArray *)line withGui:(Gui *)gui {

	if(line.count < 16) { // sanity check
		DDLogWarn(@"VUMeter: Cannot create, atom line length < 16");
		return nil;
	}

	VUMeter *v = [[VUMeter alloc] initWithFrame:CGRectZero];
	
	v.receiveName = [Gui filterEmptyStringValues:[line objectAtIndex:7]];
	if(![v hasValidReceiveName]) {
		// drop something we can't interact with
		DDLogVerbose(@"VUMeter: Dropping, receive name is empty");
		return nil;
	}
	
	// constrain height to multiples of IEM_VU_STEPS
	v.originalFrame = CGRectMake(
		[[line objectAtIndex:2] floatValue], [[line objectAtIndex:3] floatValue],
		[[line objectAtIndex:5] floatValue],
		floor([[line objectAtIndex:6] floatValue] / IEM_VU_STEPS) * IEM_VU_STEPS);
	[Util logRect:v.originalFrame];
	
	v.label.text = [Gui filterEmptyStringValues:[line objectAtIndex:8]];
	v.originalLabelPos = CGPointMake([[line objectAtIndex:9] floatValue], [[line objectAtIndex:10] floatValue]);
	v.labelFontSize = [[line objectAtIndex:12] floatValue];
	
	if([[line objectAtIndex:13] integerValue] == -66577) { // check for default color value
		v.fillColor = [UIColor colorWithWhite:0.22 alpha:1.0];
		v.isDefaultFillColor = YES;
	}
	else {
		v.fillColor = [IEMWidget colorFromIEMColor:[[line objectAtIndex:13] integerValue]];
	}
	v.label.textColor = [IEMWidget colorFromIEMColor:[[line objectAtIndex:14] integerValue]];

	v.showScale = [[line objectAtIndex:15] boolValue];

	[v reshapeForGui:gui];
	
	return v;
}

- (id)initWithFrame:(CGRect)frame {    
    self = [super initWithFrame:frame];
    if(self) {
	
		self.showScale = YES;
		self.isDefaultFillColor = NO;
		
		MeterView *m = [[MeterView alloc] initWithFrame:CGRectZero];
		m.parent = self;
		self.meterView = m;
		[self addSubview:m];
	}
    return self;
}

- (void)reshapeForGui:(Gui *)gui {
	
	// meter
	CGRect meterFrame = CGRectMake(0, 0,
		self.originalFrame.size.width + VU_PAD_W + 1,
		self.originalFrame.size.height + VU_PAD_H + 1);
	if(self.showScale) {
		meterFrame.origin.y = round(self.label.font.lineHeight/2); // offset for scale text
	}
	self.meterView.frame = meterFrame;
	
	// bounds from meter size + optional scale width
	CGRect bounds = CGRectMake(
		round(self.originalFrame.origin.x * gui.scaleX),
		round(self.originalFrame.origin.y * gui.scaleY),
		CGRectGetWidth(self.meterView.frame),
		CGRectGetHeight(self.meterView.frame));
	if(self.showScale) {
		CGSize charSize = [@"0" sizeWithFont:self.label.font]; // assumes monspaced font
		bounds.size.width += charSize.width * VU_MAX_SCALE_CHAT_WIDTH;
		bounds.size.height += self.label.font.lineHeight;
	}
	self.frame = bounds;
	
	// label
	self.label.font = [UIFont fontWithName:GUI_FONT_NAME size:self.labelFontSize];
	[self.label sizeToFit];
	CGRect labelFrame = CGRectMake(
		round(self.originalLabelPos.x * gui.scaleX),
		round((self.originalLabelPos.y * gui.scaleY) - (self.labelFontSize* 0.75)),
		CGRectGetWidth(self.label.frame),
		CGRectGetHeight(self.label.frame));
	if(self.showScale) { // shift label down slightly since meter is shifted down
		labelFrame.origin.y += meterFrame.origin.y;
	}
	self.label.frame = labelFrame;
	
//	// led bar
//	int w2=self.originalFrame.size.width/2;
//	ledBarSize = CGSizeMake(self.originalFrame.size.width-w2-1, (self.frame.size.height / IEM_VU_STEPS) - 1);// * gui.scaleX);
}

- (void)drawRect:(CGRect)rect {

    CGContextRef context = UIGraphicsGetCurrentContext();
	CGContextTranslateCTM(context, 0.5, 0.5); // snap to nearest pixel
	
	int w4=self.originalFrame.size.width/4, w2=self.originalFrame.size.width/2;
	
	// vu scale text
	if(self.showScale) {
		CGPoint pos = CGPointMake(w4 + VU_PAD_W, 0);
		int k1=self.meterView.ledBarSize.height+1, k2=IEM_VU_STEPS+1, k3=k1/2;
		int k4=-k3;
		for(int i = 0; i < IEM_VU_STEPS+2; ++i) {
			pos.y = k4 + k1*(k2-i+1) + 1;
			NSString * vuString = [NSString stringWithUTF8String:iemgui_vu_scale_str[i]];
			if(vuString.length > 0) {
				CGContextSetFillColorWithColor(context, self.label.textColor.CGColor);
				[vuString drawAtPoint:CGPointMake(self.originalFrame.size.width + VU_PAD_W + 2, pos.y) withFont:self.label.font];
			}
		}
	}
}

#pragma mark Overridden Getters / Setters

//- (void)setValue:(float)f {
//	[super setValue:MIN(self.maxValue, MAX(self.minValue, f))];
//}

//- (void)setFillColor:(UIColor *)fillColor {
//	//	if([[line objectAtIndex:12] integerValue] == -66577) { // check for default color value
////		v.fillColor = [UIColor colorWithWhite:0.25 alpha:1.0];
////		v.isDefaultFillColor = YES;
////	}
////	else {
//		v.fillColor = [Gui colorFromIEMColor:[[line objectAtIndex:12] integerValue]];
////	}
//	_fillColor = fillColor;
//}

- (void)setValue:(float)f {
    int i;
	if(f <= IEM_VU_MINDB) {
        self.meterView.rmsBar = 0;
    }
	else if(f >= IEM_VU_MAXDB) {
        self.meterView.rmsBar = IEM_VU_STEPS;
    }
	else {
        i = (int)(2.0 * (f + IEM_VU_OFFSET));
        self.meterView.rmsBar = iemgui_vu_db2i[i];
    }
    i = (int)((100.0 * f) + 10000.5);
    [super setValue:(0.01 * (i - 10000))];
	[self.meterView setNeedsDisplay];
}


- (void)setPeakValue:(float)peakValue {
    int i;
    if(peakValue <= IEM_VU_MINDB) {
        self.meterView.peakBar = 0;
	}
    else if(peakValue >= IEM_VU_MAXDB) {
        self.meterView.peakBar = IEM_VU_STEPS;
	}
    else {
        i = (int)(2.0 * (peakValue + IEM_VU_OFFSET));
        self.meterView.peakBar = iemgui_vu_db2i[i];
    }
    i = (int)(100.0 * peakValue + 10000.5);
    _peakValue = 0.01 * (i - 10000);
	// dosen't call setNeedsDisplay,
	// rms & peak values come in pairs so only redisplay once when setting rms
}

- (NSString *)type {
	return @"VUMeter";
}

#pragma mark WidgetListener

- (void)receiveBangFromSource:(NSString *)source {
// no sendName
}

- (void)receiveFloat:(float)received fromSource:(NSString *)source {
	self.value = received;
}

- (void)receiveList:(NSArray *)list fromSource:(NSString *)source {
	if(list.count > 1) {
		if([Util isNumberIn:list at:0] && [Util isNumberIn:list at:1]) {
			self.peakValue = [[list objectAtIndex:1] floatValue];
			self.value = [[list objectAtIndex:0] floatValue];
		}
	}
	else {
		[super receiveList:list fromSource:source];
	}
}

@end

#pragma mark Meter

@implementation MeterView

- (id)initWithFrame:(CGRect)frame {    
    self = [super initWithFrame:frame];
    if(self) {
		self.ledBarSize = CGSizeMake(IEM_VU_DEFAULTSIZE * 2, IEM_VU_DEFAULTSIZE);
	}
    return self;
}

- (void)drawRect:(CGRect)rect {

    CGContextRef context = UIGraphicsGetCurrentContext();
	CGContextTranslateCTM(context, 0.5, 0.5); // snap to nearest pixel
	CGContextSetLineWidth(context, 1.0);
	
	// background
	CGContextSetFillColorWithColor(context, self.parent.fillColor.CGColor);
	CGContextFillRect(context, rect);
	
	// border
	CGContextSetStrokeColorWithColor(context, self.parent.frameColor.CGColor);
	CGContextStrokeRect(context, CGRectMake(0, 0, CGRectGetWidth(rect)-1, CGRectGetHeight(rect)-1));
	
	// led bars
	int w2=self.parent.originalFrame.size.width/2;
	self.ledBarSize = CGSizeMake(self.parent.originalFrame.size.width-w2-1, (self.frame.size.height / IEM_VU_STEPS) - 1);// * gui.scaleX);
	int w4=self.parent.originalFrame.size.width/4;
	
	CGPoint pos = CGPointMake(w4 + VU_PAD_W, 0);
	int k1=self.ledBarSize.height+1, k2=IEM_VU_STEPS+1, k3=k1/2;
    int k4=-k3;
	for(int i = 1; i <= IEM_VU_STEPS; ++i) {
		if(i == self.peakBar || i <= self.rmsBar) {
			pos.y = k4 + k1*(k2-i) + 1;
			CGRect bar;
			if(i == self.peakBar) {
				bar = CGRectMake(1, pos.y, rect.size.width - VU_PAD_W - 1, self.ledBarSize.height-1);
			}
			else {
				bar = CGRectMake(pos.x, pos.y, self.ledBarSize.width, self.ledBarSize.height-1);
			}
			UIColor *barColor = [IEMWidget colorFromIEMColor:iemgui_vu_col[i]];
			CGContextSetFillColorWithColor(context, barColor.CGColor);
			CGContextSetStrokeColorWithColor(context, barColor.CGColor);
			CGContextFillRect(context, bar);
			CGContextStrokeRect(context, bar);
		}
	}
}

@end
