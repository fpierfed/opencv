/*M///////////////////////////////////////////////////////////////////////////////////////
//
//  IMPORTANT: READ BEFORE DOWNLOADING, COPYING, INSTALLING OR USING.
//
//  By downloading, copying, installing or using the software you agree to this license.
//  If you do not agree to this license, do not download, install,
//  copy or use the software.
//
//
//                          License Agreement
//                For Open Source Computer Vision Library
//
// Copyright (C) 2000-2008, Intel Corporation, all rights reserved.
// Copyright (C) 2009, Willow Garage Inc., all rights reserved.
// Third party copyrights are property of their respective owners.
//
// Redistribution and use in source and binary forms, with or without modification,
// are permitted provided that the following conditions are met:
//
//   * Redistribution's of source code must retain the above copyright notice,
//     this list of conditions and the following disclaimer.
//
//   * Redistribution's in binary form must reproduce the above copyright notice,
//     this list of conditions and the following disclaimer in the documentation
//     and/or other materials provided with the distribution.
//
//   * The name of the copyright holders may not be used to endorse or promote products
//     derived from this software without specific prior written permission.
//
// This software is provided by the copyright holders and contributors "as is" and
// any express or implied warranties, including, but not limited to, the implied
// warranties of merchantability and fitness for a particular purpose are disclaimed.
// In no event shall the Intel Corporation or contributors be liable for any direct,
// indirect, incidental, special, exemplary, or consequential damages
// (including, but not limited to, procurement of substitute goods or services;
// loss of use, data, or profits; or business interruption) however caused
// and on any theory of liability, whether in contract, strict liability,
// or tort (including negligence or otherwise) arising in any way out of
// the use of this software, even if advised of the possibility of such damage.
//
//M*/

#import <AppKit/AppKit.h>
#import <Accelerate/Accelerate.h>
#import <AVFoundation/AVFoundation.h>
#import <ImageIO/ImageIO.h>
#include "opencv2/core.hpp"
#include "precomp.hpp"

NSImage* MatToNSImage(const cv::Mat& image);
void NSImageToMat(const NSImage* image, cv::Mat& m, bool alphaExist);

NSImage* MatToNSImage(const cv::Mat& image) {
    int bytespp = image.elemSize1();
    NSData *data = [NSData dataWithBytes:image.data
                                  length:image.elemSize()*image.total()];

    CGColorSpaceRef colorSpace;

    if (image.elemSize() == bytespp) {
        colorSpace = CGColorSpaceCreateDeviceGray();
    } else {
        colorSpace = CGColorSpaceCreateDeviceRGB();
    }

    CGDataProviderRef provider =
            CGDataProviderCreateWithCFData((__bridge CFDataRef)data);

    // Preserve alpha transparency, if exists
    bool alpha = image.channels() == 4;
    CGBitmapInfo bitmapInfo = (alpha ? kCGImageAlphaLast : kCGImageAlphaNone) | kCGBitmapByteOrderDefault;

    // Creating CGImage from cv::Mat
    CGImageRef imageRef = CGImageCreate(image.cols,
                                        image.rows,
                                        bytespp * 8,
                                        bytespp * 8 * image.elemSize(),
                                        image.step.p[0],
                                        colorSpace,
                                        bitmapInfo,
                                        provider,
                                        NULL,
                                        false,
                                        kCGRenderingIntentDefault
                                        );


    // Getting NSImage from CGImage
    NSImage *finalImage = [[NSImage alloc] initWithCGImage:imageRef size: NSZeroSize];
    CGImageRelease(imageRef);
    CGDataProviderRelease(provider);
    CGColorSpaceRelease(colorSpace);

    return finalImage;
}

void NSImageToMat(const NSImage* image, cv::Mat& m, bool alphaExist) {
    CGImageRef imageRef = [image CGImageForProposedRect: NULL context: NULL hints: NULL];
    size_t bpp = CGImageGetBitsPerComponent(imageRef);
    int components = 0;
    CGColorSpaceRef colorSpace = CGImageGetColorSpace(imageRef);
    CGFloat cols = image.size.width, rows = image.size.height;
    CGContextRef contextRef;
    CGBitmapInfo bitmapInfo = kCGImageAlphaPremultipliedLast;
    if (CGColorSpaceGetModel(colorSpace) == 0) {
        components = 1;
        if(bpp == 8) {
            m.create(rows, cols, CV_8UC1); // 8 bits per component, 1 channel
        } else if (bpp == 16) {
            m.create(rows, cols, CV_16UC1); // 16 bits per component, 1 channel
        } else {
            [NSException raise: @"OpenCVException"
                         format: @"Only 16 and 8 bit-per-pixel images are supported (bpp=%d).",
                         bpp];
        }
        bitmapInfo = kCGImageAlphaNone;
        if (!alphaExist)
            bitmapInfo = kCGImageAlphaNone;
    } else {
        components = 4;
        if(bpp == 8) {
            m.create(rows, cols, CV_8UC4); // 8 bits per component, 4 channels
        } else if (bpp == 16) {
            m.create(rows, cols, CV_16UC4); // 16 bits per component, 4 channels
        } else {
            [NSException raise: @"OpenCVException"
                         format: @"Only 16 and 8 bit-per-pixel images are supported (bpp=%d).",
                         bpp];
        }
        if (!alphaExist)
            components--;
            bitmapInfo = kCGImageAlphaNoneSkipLast |
                                kCGBitmapByteOrderDefault;
    }
    // NSLog(@"cols:%d, rows:%d, planes:%d, bpp:%d", m.cols, m.rows, components, bpp);
    contextRef = CGBitmapContextCreate(m.data, cols, rows, bpp,
                                       m.step[0], colorSpace, bitmapInfo);
    CGContextDrawImage(contextRef, CGRectMake(0, 0, cols, rows), imageRef);
    CGContextRelease(contextRef);
}
