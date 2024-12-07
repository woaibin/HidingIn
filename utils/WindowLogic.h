//
// Created by 宾小康 on 2024/11/2.
//

#ifndef HIDINGIN_WINDOWLOGIC_H
#define HIDINGIN_WINDOWLOGIC_H

#include <tuple>

// Define a structure to represent a 2D size (width and height)
struct WindowSize {
    int width;
    int height;
    WindowSize(int width, int height);
};

// Define a structure to represent a 2D point (x and y coordinates)
struct WindowPoint {
    int x;
    int y;

    WindowPoint(int x, int y);
};

// Define a structure to represent a rectangle (x, y, width, height)
struct WindowRect {
    int x = -1;
    int y = -1;
    int width = 0;
    int height = 0;
    int compensateX = 0; // used when org x is negative
    int compensateY = 0; // used when org y is negative

    WindowRect(int x, int y, int width, int height);
};

// Function to calculate the centered rectangle for a window on a desktop
WindowRect calculateRectForWindowAtPosition(const WindowSize& desktopSize, const WindowSize& windowSize, const WindowPoint& windowPosition);

// Function to check if one rectangle is inside another
bool isRectInside(const std::tuple<int, int, int, int>& target, const std::tuple<int, int, int, int>& cmp);

#endif //HIDINGIN_WINDOWLOGIC_H