//
// Created by 宾小康 on 2024/10/22.
//

#ifndef HIDINGIN_MACUTILS_H
#define HIDINGIN_MACUTILS_H
#include <tuple>
extern float getScalingFactor();
std::tuple<int, int, int, int, int> getWindowSizesForPID(pid_t targetPID);
// Function declaration
void stickToApp(int targetAppWinId, int targetAppPID, void *overlayWindow);
std::vector<int> getCurrentAppWindowIDVec();
std::vector<int> getWindowIDsForAppByName(const std::string &appName);
bool getWindowGeometry(int windowID, std::tuple<int, int, int, int>& rectGeometry);
std::tuple<int, int, int, int> resizeAndMoveOverlayWindow(void* nativeWindowHandle, int targetAppWinId);
bool isAppInForeground(int pid);
void wakeUpAppByPID(int pid);
bool isMouseInWindowWithID(void *viewPtr);
void disableShadow(void* winId);
std::tuple<int, int>getScreenSizeInPixels();
std::tuple<int, int, int, int> getVisibleRect(
        int winLeft, int winTop, int winWidth, int winHeight,
        int screenWidth, int screenHeight);
#endif //HIDINGIN_MACUTILS_H
