//
// Created by 宾小康 on 2024/10/22.
//

#ifndef HIDINGIN_MACUTILS_H
#define HIDINGIN_MACUTILS_H
#include <tuple>
extern float getScalingFactor();
std::tuple<int, int, int,int> getWindowSizesForPID(pid_t targetPID);
#endif //HIDINGIN_MACUTILS_H
