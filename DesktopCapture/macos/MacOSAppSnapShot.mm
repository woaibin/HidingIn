//
// Created by 宾小康 on 2024/10/23.
//
#include <QImage>
#include <ApplicationServices/ApplicationServices.h>
#include <string>

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

// Helper function to find the window ID for the app name
CGWindowID findWindowIDForApp(const std::string& appName) {
    // Convert std::string to NSString
    NSString *nsAppName = [NSString stringWithUTF8String:appName.c_str()];

    // Get a list of all windows
    CFArrayRef windowList = CGWindowListCopyWindowInfo(kCGWindowListOptionOnScreenOnly, kCGNullWindowID);

    for (NSDictionary *windowInfo in (NSArray *)windowList) {
        NSString *windowOwnerName = windowInfo[(NSString *)kCGWindowOwnerName];

        // Compare the window owner name with the app name
        if ([windowOwnerName isEqualToString:nsAppName]) {
            NSNumber *windowID = windowInfo[(NSString *)kCGWindowNumber];
            CFRelease(windowList);
            return [windowID unsignedIntValue];
        }
    }

    // Release the window list and return a null window ID if not found
    CFRelease(windowList);
    return kCGNullWindowID;
}

// Main function to get a snapshot from the app by name
extern QImage getSnapShotFromApp(std::string appName) {
    // Find the window ID of the target application
    CGWindowID windowID = findWindowIDForApp(appName);

    if (windowID != kCGNullWindowID) {
        // Capture the window image
        CGRect windowBounds = CGRectNull; // Capture the full window
        CGImageRef windowImage = CGWindowListCreateImage(windowBounds, kCGWindowListOptionIncludingWindow, windowID, kCGWindowImageDefault);

        if (windowImage != NULL) {
            // Convert CGImageRef to QImage and return it
            QImage image = CGImageToQImage(windowImage);
            CGImageRelease(windowImage); // Release CGImageRef when done
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