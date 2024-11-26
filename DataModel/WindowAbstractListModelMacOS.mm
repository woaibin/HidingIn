//
// Created by 宾小康 on 2024/10/23.
//
#include "WindowAbstractListModel.h"
#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
#import <ApplicationServices/ApplicationServices.h>
#include <DesktopCapture/macos/MacOSAppSnapShot.h>
void WindowAbstractListModel::enumAllApps() {
    NSArray *runningApps = [[NSWorkspace sharedWorkspace] runningApplications];

    for (NSRunningApplication *app in runningApps) {
        if(!app.localizedName || [app.localizedName length] <= 0){
            continue;
        }
        auto appName = std::string([app.localizedName UTF8String]);
        int retWinId;
        auto snapShot = getSnapShotFromApp(appName, &retWinId);
        if(snapShot.isNull()){
            continue;
        }
        // to-do: lazy load images, the high pass result is time-consuming:
        m_snapShotImageProvider.addImage(QString::fromStdString(appName), snapShot);
        auto constructImgUrl = QString("image://appsnapshotprovider/") + QString::fromStdString(appName);
        WindowModel model(QString::number((retWinId)),
                          QString::fromUtf8([app.localizedName UTF8String]),constructImgUrl, QString::number((app.processIdentifier)));
        m_windowsFull.push_back(model);
    }

    // Copy up to the top 10 windows from m_windowsFull to m_windowsForShow
    m_windowsForShow.clear();  // Clear the list before copying
    int windowCount = std::min((float)10, (float)m_windowsFull.size());

    for (int i = 0; i < windowCount; ++i) {
        m_windowsForShow.push_back(m_windowsFull[i]);
    }
}
