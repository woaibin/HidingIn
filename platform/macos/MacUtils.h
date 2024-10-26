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
#endif //HIDINGIN_MACUTILS_H
