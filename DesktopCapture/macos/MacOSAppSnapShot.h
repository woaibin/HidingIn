//
// Created by 宾小康 on 2024/10/23.
//

#ifndef HIDINGIN_MACOSAPPSNAPSHOT_H
#define HIDINGIN_MACOSAPPSNAPSHOT_H
#include "QImage"
extern QImage getSnapShotFromApp(std::string, int* retWinId = nullptr);
extern std::vector<QImage> getAllSnapShotsFromApp(const std::string& appName, std::vector<int>& retWinIds);
#endif //HIDINGIN_MACOSAPPSNAPSHOT_H
