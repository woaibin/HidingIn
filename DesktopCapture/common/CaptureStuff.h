//
// Created by 宾小康 on 2024/10/26.
//

#ifndef HIDINGIN_CAPTURESTUFF_H
#define HIDINGIN_CAPTURESTUFF_H
#include <vector>
#include "string"
enum class CaptureStatus{
    NotStart,
    Start,
    Stop
};

struct CaptureArgs{
    std::string captureEventName;
    std::vector<int> excludingWindowIDs; // -1 means itself.
};
struct CompositeCaptureArgs{
};
#endif //HIDINGIN_CAPTURESTUFF_H
