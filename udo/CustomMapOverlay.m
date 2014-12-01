//
//  CustomMapOverlay.m
//  MapView
//
//  Modified by Orb on 3/27/14.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
// 
// http://www.apache.org/licenses/LICENSE-2.0
// 
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//
// Special thanks to: https://github.com/yickhong/YHMapDemo/tree/master/YHMapDemo
//


#import "CustomMapOverlay.h"

@implementation CustomMKCircleOverlay
@synthesize MINDIS;
@synthesize MAXDIS;
@synthesize circlebounds;
@synthesize alpha;
@synthesize border;
@synthesize delegate;
@synthesize handleBounds;

#define MINDISTANCE 100.0
#define MAXDISTANCE 2000.0
#define DEFAULT_ALPHA .3
#define DEFAULT_BORDER 15

double radius;
double mapRadius;

-(id)initWithCircle:(MKCircle *)circle withRadius:(CGFloat)radius withMin:(int)min withMax:(int)max{
    self = [super initWithCircle:circle];
    
    if(max > min && min > 0){
        MINDIS = min;
        MAXDIS = max;
    }else if(min > 0){
        NSLog(@"Max distance smaller than Min");
        MINDIS = min;
        MAXDIS = min;
    }else{
        NSLog(@"Trying to set a negative radius--Using Default");
        MINDIS = MINDISTANCE;
        MAXDIS = MAXDISTANCE;
    }
    if(radius > 0){
        mapRadius = radius;
    }
    [self commonInit];
    return self;
}

-(id)initWithCircle:(MKCircle *)circle withRadius:(CGFloat)radius{
    self = [super initWithCircle:circle];
    MINDIS = MINDISTANCE;
    MAXDIS = MAXDISTANCE;
    if(radius > 0){
        mapRadius = radius;
    }
    [self commonInit];
    return self;
}

-(id)initWithCircle:(MKCircle *)circle{
    self = [super initWithCircle:circle];
    MINDIS = MINDISTANCE;
    MAXDIS = MAXDISTANCE;
    [self commonInit];
    return self;
}

-(void)commonInit{
    alpha = DEFAULT_ALPHA;
    border = DEFAULT_BORDER;
}

-(void)setCircleRadius:(CGFloat)radius{
    if(radius > MAXDIS){
        mapRadius = MAXDIS;
    }else if(radius < MINDIS){
        mapRadius = MINDIS;
    }else{
        mapRadius = radius;
    }
    [self invalidatePath];
}

-(CGFloat)getCircleRadius{
    return mapRadius;
}

- (void)drawMapRect:(MKMapRect)mapRect
          zoomScale:(MKZoomScale)zoomScale
          inContext:(CGContextRef)ctx{

    MKMapPoint mpoint = MKMapPointForCoordinate([[self overlay] coordinate]);
    
    CGFloat radiusAtLatitude = (mapRadius)*MKMapPointsPerMeterAtLatitude([[self overlay] coordinate].latitude);
    circlebounds = MKMapRectMake(mpoint.x, mpoint.y, radiusAtLatitude *2, radiusAtLatitude * 2);
    CGRect overlayRect = [self rectForMapRect:circlebounds];
    
    CGContextSaveGState(ctx);
    // draw circle
    CGContextSetStrokeColorWithColor(ctx, self.fillColor.CGColor);
    CGContextSetFillColorWithColor(ctx, [self.fillColor colorWithAlphaComponent:alpha].CGColor);
    CGContextSetLineWidth(ctx, border);
    CGContextSetShouldAntialias(ctx, YES);
    CGContextAddArc(ctx, overlayRect.origin.x, overlayRect.origin.y, radiusAtLatitude, 0, 2 * M_PI, true);
    CGContextDrawPath(ctx, kCGPathFillStroke);
    
    // draw radius line
    CGContextSetAlpha(ctx, 1.0);
    CGContextSetStrokeColorWithColor(ctx, [UIColor blackColor].CGColor);
    CGFloat dashArray[] = {80,40};
    CGContextSetLineDash(ctx, 0 , dashArray, 2);
    CGContextMoveToPoint(ctx, overlayRect.origin.x, overlayRect.origin.y);
    CGContextAddLineToPoint(ctx, overlayRect.origin.x + radiusAtLatitude, overlayRect.origin.y);
    CGContextDrawPath(ctx, kCGPathFillStroke);
    
    // draw handle
    CGFloat handleSize = 5.0 * MKRoadWidthAtZoomScale(zoomScale);
    handleBounds = MKMapRectMake(mpoint.x + radiusAtLatitude - handleSize/2 , mpoint.y - handleSize/2, handleSize, handleSize);
    //CGRect handleRect = [self rectForMapRect:handleBounds]; CGContextFillRect(ctx, handleRect);
    CGContextSetFillColorWithColor(ctx, [UIColor blackColor].CGColor);
    CGContextSetLineDash(ctx,0,nil,0);
    CGContextAddArc(ctx, overlayRect.origin.x + radiusAtLatitude, overlayRect.origin.y, handleSize/2 , 0, 2 * M_PI, true);
    CGContextDrawPath(ctx, kCGPathFillStroke);
    
    //draw the text...
    NSString *radiusText = [NSString stringWithFormat:@"%d m", (int) mapRadius];
    UIGraphicsPushContext(ctx);
    [[UIColor blackColor] set];
    UIFont *font = [UIFont systemFontOfSize:(5.0 * MKRoadWidthAtZoomScale(zoomScale))];
    /// Make a copy of the default paragraph style
    NSMutableParagraphStyle *paragraphStyle = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
    /// Set line break mode
    paragraphStyle.lineBreakMode = NSLineBreakByTruncatingTail;
    /// Set text alignment
    paragraphStyle.alignment = NSTextAlignmentLeft;
    NSDictionary *attributes = @{ NSFontAttributeName: font,
                                  NSParagraphStyleAttributeName: paragraphStyle };
    CGPoint textPoint = [self pointForMapPoint:mpoint];
    textPoint.y += 100;
    [radiusText drawAtPoint:textPoint withAttributes:attributes];
    UIGraphicsPopContext();
    
    if(delegate){
        dispatch_async(dispatch_get_main_queue(), ^{
            [delegate onRadiusChange:mapRadius];
        });
    }
    
    CGContextRestoreGState(ctx);
}

@end
