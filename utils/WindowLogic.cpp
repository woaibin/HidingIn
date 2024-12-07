#include "WindowLogic.h"
#include <iostream>
#include <algorithm> // For std::max and std::min

// Implementation of WindowSize constructor
WindowSize::WindowSize(int width, int height) {
    this->width = width;
    this->height = height;
}

// Implementation of WindowPoint constructor
WindowPoint::WindowPoint(int x, int y) {
    this->x = x;
    this->y = y;
}

// Implementation of WindowRect constructor
WindowRect::WindowRect(int x, int y, int width, int height) {
    this->x = x;
    this->y = y;
    this->width = width;
    this->height = height;
}

// Implementation of calculateRectForWindowAtPosition function
WindowRect calculateRectForWindowAtPosition(const WindowSize& desktopSize, const WindowSize& windowSize, const WindowPoint& windowPosition) {
    int x, y;

    // Ensure the window fits within the desktop bounds by adjusting its position if necessary
    if (windowPosition.x + windowSize.width < desktopSize.width) {
        x = (int)std::max(0.0f, (float)std::min(windowPosition.x, desktopSize.width - windowSize.width));
    } else {
        x = (int)std::max(0.0f, (float)std::max(windowPosition.x, desktopSize.width - windowSize.width));
    }

    if (windowPosition.y + windowSize.height < desktopSize.height) {
        y = (int)std::max(0.0f, (float)std::min(windowPosition.y, desktopSize.height - windowSize.height));
    } else {
        y = (int)std::max(0.0f, (float)std::max(windowPosition.y, desktopSize.height - windowSize.height));
    }

    // Create a Rect with the adjusted position and window size
    WindowRect windowRect = {x, y, windowSize.width, windowSize.height};

    if (windowPosition.x < 0) {
        windowRect.compensateX = std::abs(windowPosition.x);
    }

    if (windowPosition.y < 0) {
        windowRect.compensateY = std::abs(windowPosition.y);
    }

    return windowRect;
}

// Implementation of isRectInside function
bool isRectInside(const std::tuple<int, int, int, int>& target, const std::tuple<int, int, int, int>& cmp) {
    // Unpack target and cmp rectangles
    int tx, ty, tw, th;
    int cx, cy, cw, ch;

    std::tie(tx, ty, tw, th) = target;
    std::tie(cx, cy, cw, ch) = cmp;

    // Check if cmp is inside target
    return (cx >= tx) &&                          // Left edge
           (cx + cw <= tx + tw) &&                // Right edge
           (cy >= ty) &&                          // Top edge
           (cy + ch <= ty + th);                  // Bottom edge
}