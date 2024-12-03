//
// Created by 宾小康 on 2024/10/23.
//
#include <QImage>
#include <ApplicationServices/ApplicationServices.h>
#include <string>
#import <CoreImage/CoreImage.h>
#import <CoreGraphics/CoreGraphics.h>

// Helper function to convert CGImageRef to QImage
QImage CGImageToQImage(CGImageRef imageRef) {
    if (!imageRef) {
        return QImage();
    }

    // Get image dimensions
    size_t width = CGImageGetWidth(imageRef);
    size_t height = CGImageGetHeight(imageRef);
    size_t bitsPerComponent = CGImageGetBitsPerComponent(imageRef);
    size_t bitsPerPixel = CGImageGetBitsPerPixel(imageRef);
    size_t bytesPerRow = CGImageGetBytesPerRow(imageRef);

    // Get the color space and data provider
    CGColorSpaceRef colorSpace = CGImageGetColorSpace(imageRef);
    CGDataProviderRef provider = CGImageGetDataProvider(imageRef);
    CFDataRef dataRef = CGDataProviderCopyData(provider);
    const uint8_t* buffer = CFDataGetBytePtr(dataRef);

    // Determine the QImage format based on bits per pixel
    QImage::Format format = QImage::Format_ARGB32; // Default format, can be adjusted based on bitsPerPixel

    if (bitsPerPixel == 32) {
        format = QImage::Format_ARGB32;
    } else if (bitsPerPixel == 24) {
        format = QImage::Format_RGB888;
    }

    // Create a QImage from the buffer
    QImage image(buffer, width, height, bytesPerRow, format);

    // Copy the image to ensure memory safety (as the buffer will be released)
    QImage finalImage = image.copy();

    // Release the Core Graphics data
    CFRelease(dataRef);

    return finalImage;
}

CGWindowID findWindowIDForApp(const std::string& appName) {
    // Convert std::string to NSString
    NSString *nsAppName = [NSString stringWithUTF8String:appName.c_str()];

    // Get a list of all windows
    CFArrayRef windowList = CGWindowListCopyWindowInfo(kCGWindowListOptionOnScreenOnly, kCGNullWindowID);

    for (NSDictionary *windowInfo in (NSArray *)windowList) {
        NSString *windowOwnerName = windowInfo[(NSString *)kCGWindowOwnerName];
        // Compare the window owner name with the app name
        if ([windowOwnerName containsString:nsAppName]) {
            // Get the window's bounds (position and size)
            NSDictionary *boundsDict = windowInfo[(NSString *)kCGWindowBounds];
            CGRect windowBounds;
            CGRectMakeWithDictionaryRepresentation((CFDictionaryRef)boundsDict, &windowBounds);

            // Filter out windows that start at (0, 0) and have width or height less than 50
            if ((windowBounds.size.width < 50 || windowBounds.size.height < 50)) {
                continue; // Skip this window
            }

            // If the window passes the filter, return its ID
            NSNumber *windowID = windowInfo[(NSString *)kCGWindowNumber];
            CFRelease(windowList);
            return [windowID unsignedIntValue];
        }
    }

    // Release the window list and return a null window ID if not found
    CFRelease(windowList);
    return kCGNullWindowID;
}

CGImageRef applyHighPassFilter(CGImageRef inputImage, CGFloat blurRadius) {
    // Step 1: Create CIImage from CGImageRef
    CIImage *ciInput = [CIImage imageWithCGImage:inputImage];

    // Step 2: Apply Gaussian Blur to Extract Low-Frequency Components
    CIFilter *gaussianBlur = [CIFilter filterWithName:@"CIGaussianBlur"];
    [gaussianBlur setValue:ciInput forKey:kCIInputImageKey];
    [gaussianBlur setValue:@(blurRadius) forKey:kCIInputRadiusKey];
    CIImage *blurredImage = [gaussianBlur valueForKey:kCIOutputImageKey];

    // Step 3: Subtract Blurred Image from Original Image
    CIFilter *differenceBlend = [CIFilter filterWithName:@"CISubtractBlendMode"];
    [differenceBlend setValue:ciInput forKey:kCIInputImageKey];
    [differenceBlend setValue:blurredImage forKey:kCIInputBackgroundImageKey];
    CIImage *highPassImage = [differenceBlend valueForKey:kCIOutputImageKey];

    // Step 4: Render the Resulting CIImage Back to CGImageRef
    CIContext *context = [CIContext contextWithOptions:nil];
    CGImageRef outputImage = [context createCGImage:highPassImage fromRect:[ciInput extent]];

    return outputImage; // The caller is responsible for releasing this CGImageRef
}

// Main function to get a snapshot from the app by name
extern QImage getSnapShotFromApp(std::string appName, int *retWinId) {
    // Find the window ID of the target application
    CGWindowID windowID = findWindowIDForApp(appName);
    *retWinId = windowID;
    if (windowID != kCGNullWindowID) {
        // Capture the window image
        CGRect windowBounds = CGRectNull; // Capture the full window
        CGImageRef windowImage = CGWindowListCreateImage(windowBounds, kCGWindowListOptionIncludingWindow, windowID, kCGWindowImageDefault);
        auto highPassResult = applyHighPassFilter(windowImage, 5.0);

        if (highPassResult != NULL) {
            // Convert CGImageRef to QImage and return it
            QImage image = CGImageToQImage(highPassResult);
            CGImageRelease(highPassResult); // Release CGImageRef when done
            return image;
        } else {
            // Return an empty QImage if capture failed
            return QImage();
        }
    } else {
        // Return an empty QImage if no window found for the application
        return QImage();
    }
}

// Helper function to find all window IDs for a given app name
std::vector<CGWindowID> findAllWindowIDsForApp(const std::string& appName) {
    // Convert std::string to NSString
    NSString *nsAppName = [NSString stringWithUTF8String:appName.c_str()];

    // Get a list of all windows
    CFArrayRef windowList = CGWindowListCopyWindowInfo(kCGWindowListOptionOnScreenOnly, kCGNullWindowID);
    std::vector<CGWindowID> windowIDs;

    for (NSDictionary *windowInfo in (NSArray *)windowList) {
        NSString *windowOwnerName = windowInfo[(NSString *)kCGWindowOwnerName];
        // Compare the window owner name with the app name
        if ([windowOwnerName containsString:nsAppName]) {
            // Get the window's bounds (position and size)
            NSDictionary *boundsDict = windowInfo[(NSString *)kCGWindowBounds];
            CGRect windowBounds;
            CGRectMakeWithDictionaryRepresentation((CFDictionaryRef)boundsDict, &windowBounds);

            // Filter out windows that start at (0, 0) and have width or height less than 50
            if ((windowBounds.size.width < 50 || windowBounds.size.height < 50)) {
                continue; // Skip this window
            }

            // If the window passes the filter, add its ID to the list
            NSNumber *windowID = windowInfo[(NSString *)kCGWindowNumber];
            windowIDs.push_back([windowID unsignedIntValue]);
        }
    }

    // Release the window list
    CFRelease(windowList);
    return windowIDs;
}

// Function to get snapshots of all windows for a given app
std::vector<QImage> getAllSnapShotsFromApp(const std::string& appName, std::vector<int>& retWinIds) {
    // Find all window IDs of the target application
    std::vector<CGWindowID> windowIDs = findAllWindowIDsForApp(appName);
    std::vector<QImage> snapshots;

    for (CGWindowID windowID : windowIDs) {
        // Store the window ID in the output parameter
        retWinIds.push_back(windowID);

        // Capture the window image
        CGRect windowBounds = CGRectNull; // Capture the full window
        CGImageRef windowImage = CGWindowListCreateImage(windowBounds, kCGWindowListOptionIncludingWindow, windowID, kCGWindowImageDefault);

        if (windowImage) {
            // Optionally apply a high-pass filter or other transformations
            auto highPassResult = applyHighPassFilter(windowImage, 5.0);
            if (highPassResult != NULL) {
                // Convert CGImageRef to QImage and add it to the snapshots list
                QImage image = CGImageToQImage(highPassResult);
                snapshots.push_back(image);
                CGImageRelease(highPassResult); // Release CGImageRef when done
            } else {
                // If filtering fails, add the original image
                QImage image = CGImageToQImage(windowImage);
                snapshots.push_back(image);
            }

            CGImageRelease(windowImage); // Release CGImageRef when done
        } else {
            // Add an empty QImage as a placeholder if capture failed
            snapshots.push_back(QImage());
        }
    }

    return snapshots;
}