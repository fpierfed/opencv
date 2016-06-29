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

#if defined __clang__
#import <AppKit/AppKit.h>
#import <Accelerate/Accelerate.h>
#import <AVFoundation/AVFoundation.h>
#import <ImageIO/ImageIO.h>
#include "opencv2/core.hpp"
#include "precomp.hpp"
#include "opencv2/imgproc.hpp"
#include "opencv2/imgcodecs.hpp"


NSImage* MatToNSImage(const cv::Mat& image);
void NSImageToMat(const NSImage* image, cv::Mat& m, bool alphaExist);

NSImage* MatToNSImage(const cv::Mat& image) {
    NSImage *finalImage;
    std::vector<unsigned char> buf;
    cv::imencode(".tiff", image, buf);
    finalImage = [[NSImage alloc] initWithData: [NSData dataWithBytes: buf.data()
                                                        length: buf.size()]];
    return finalImage;
}

void NSImageToMat(const NSImage* image, cv::Mat& m, bool alphaExist) {
    // Decompress the TIFF representation so that libtiff can handle it,
    // expecially in case of JPEG-compressed TIFFs.
    NSData* imgData = [image TIFFRepresentationUsingCompression:NSTIFFCompressionNone
                             factor: 0];
    cv::Mat buffer;
    m = cv::imdecode(cv::Mat(1,
                             [imgData length],
                             CV_8UC1,
                             (void *)[imgData bytes]),
                     CV_LOAD_IMAGE_UNCHANGED);
    if(m.data == NULL) {
        [NSException raise: @"OpenCVException"
                     format: @"Unable to read image."];
    }
}
#endif
