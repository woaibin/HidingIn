//
// Created by 宾小康 on 2024/10/23.
//
#include "WindowAbstractListModel.h"
#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
#import <ApplicationServices/ApplicationServices.h>
#include <DesktopCapture/macos/MacOSAppSnapShot.h>
void WindowAbstractListModel::enum10Apps() {
    NSArray *runningApps = [[NSWorkspace sharedWorkspace] runningApplications];

    for (NSRunningApplication *app in runningApps) {
        if(m_windows.count() == 10){
            break;
        }
        auto appName = std::string([app.localizedName UTF8String]);
        auto snapShot = getSnapShotFromApp(appName);
        if(snapShot.isNull()){
            continue;
        }
        m_snapShotImageProvider.addImage(QString::fromStdString(appName), snapShot);
        auto constructImgUrl = QString("image://appsnapshotprovider/") + QString::fromStdString(appName);
        WindowModel model(QString::number((app.processIdentifier)),
                          QString::fromUtf8([app.localizedName UTF8String]),constructImgUrl);
        m_windows.push_back(model);
    }
}
