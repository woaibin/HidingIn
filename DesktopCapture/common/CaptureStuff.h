//
// Created by 宾小康 on 2024/10/26.
//

#ifndef HIDINGIN_CAPTURESTUFF_H
#define HIDINGIN_CAPTURESTUFF_H
#include <vector>
enum class CaptureStatus{
    NotStart,
    Start,
    Stop
};

struct DesktopCaptureArgs{
    std::vector<int> excludingWindowIDs; // -1 means itself.
};
struct CompositeCaptureArgs{
    int reqCompositeNum = 0;
};
#endif //HIDINGIN_CAPTURESTUFF_H
