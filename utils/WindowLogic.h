//
// Created by 宾小康 on 2024/11/2.
//

#ifndef HIDINGIN_WINDOWLOGIC_H
#define HIDINGIN_WINDOWLOGIC_H
#include <iostream>
#include <algorithm> // For std::max and std::min

// Define a structure to represent a 2D size (width and height)
struct WindowSize {
    int width;
    int height;
    WindowSize(int width, int height){
        this->width = width;
        this->height = height;
    }
};

// Define a structure to represent a 2D point (x and y coordinates)
struct WindowPoint {
    int x;
    int y;

    WindowPoint(int x, int y){
        this->x = x;
        this->y = y;
    }
};

// Define a structure to represent a rectangle (x, y, width, height)
struct WindowRect {
    int x = -1;
    int y = -1;
    int width = 0;
    int height = 0;
    int compensateX = 0; // used when org x is negative
    int compensateY = 0; // used when org y is negative

    WindowRect(int x, int y, int width, int height){
        this->x = x;
        this->y = y;
        this->width = width;
        this->height = height;
    }
};

// Function to calculate the centered rectangle for a window on a desktop
WindowRect calculateRectForWindowAtPosition(const WindowSize& desktopSize, const WindowSize& windowSize, const WindowPoint& windowPosition) {
    // Ensure the window fits within the desktop bounds by adjusting its position if necessary
    int x,y;
    if(windowPosition.x + windowSize.width < desktopSize.width){
        x = (int)std::max(0.0f, (float)std::min(windowPosition.x, desktopSize.width - windowSize.width));
    }else{
        x = (int)std::max(0.0f, (float)std::max(windowPosition.x, desktopSize.width - windowSize.width));
    }

    if(windowPosition.y + windowSize.height < desktopSize.height){
        y = (int)std::max(0.0f, (float)std::min(windowPosition.y, desktopSize.height - windowSize.height));
    }else{
        y = (int)std::max(0.0f, (float)std::max(windowPosition.y, desktopSize.height - windowSize.height));
    }

    // Create a Rect with the adjusted position and window size
    WindowRect windowRect = {x, y, windowSize.width, windowSize.height};

    if(windowPosition.x < 0){
        windowRect.compensateX = std::abs(windowPosition.x);
    }

    if(windowPosition.y < 0){
        windowRect.compensateY = std::abs(windowPosition.y);
    }

    return windowRect;
}

#endif //HIDINGIN_WINDOWLOGIC_H
