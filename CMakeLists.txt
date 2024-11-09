cmake_minimum_required(VERSION 3.27)
project(HidingIn CXX OBJC OBJCXX)

set(CMAKE_AUTOMOC ON)
# Create code from a list of Qt designer ui files
set(CMAKE_AUTOUIC ON)
# Set CMake Rcc
set(CMAKE_AUTORCC ON)

set(CMAKE_CXX_STANDARD 20)

find_package(Qt6 REQUIRED COMPONENTS Core Quick Gui QML)

qt_add_resources(QT_RESOURCES resources/resources.qrc)
# Include directories for Qt headers
include_directories(${CMAKE_BINARY_DIR})
include_directories(${CMAKE_CURRENT_LIST_DIR})
include_directories(${CMAKE_CURRENT_LIST_DIR}/3rdParty)

# Check if the compiler supports ARC and enable it
set(SOURCE "" com/NotificationCenter.h main.mm
        DesktopCapture/macos/MacOSAppSnapShot.h
        DesktopCapture/macos/MacOSAppSnapShot.mm
        DataModel/WindowAbstractListModelMacOS.mm
        DataModel/SnapShotImageProvider.cpp
        DataModel/SnapShotImageProvider.h
        Handler/AppGeneralEventHandler.cpp
        Handler/AppGeneralEventHandler.h
        DesktopCapture/CompositeCaptureMacOS.mm
        DesktopCapture/CompositeCapture.h
        DesktopCapture/common/CaptureStuff.h
        GPUPipeline/macos/MetalPipeline.h
        GPUPipeline/macos/MetalPipeline.mm
        utils/TaskQueue.h
        GPUPipeline/macos/MetalResources.h
        GPUPipeline/PipelineConfiguration.h
        GPUPipeline/macos/MetalResources.mm
        com/EventListener.h
        GPUPipeline/PipelineInOut.h
        RenderWidget/QCustomRenderNode.h
        RenderWidget/QCustomRenderNode.mm
        Handler/AppWindowListener.h
        Handler/AppWindowListener.mm)
if(APPLE)
    file(GLOB MAC_SOURCE DesktopCapture/macos/*.mm DesktopCapture/macos/*.h platform/macos/*.mm platform/macos/*.h)
elseif (WIN32)
endif ()
# Add the executable
add_executable(${PROJECT_NAME} ${SOURCE} ${MAC_SOURCE} ${QT_RESOURCES}
        DataModel/WindowModel.h
        DataModel/WindowAbstractListModel.h
        RenderWidget/QMetalGraphicsItem.mm
        RenderWidget/QMetalGraphicsItem.h
        DesktopCapture/macos/MacosCapture.mm
        DesktopCapture/macos/MacosCapture.h)

find_library(COCOA_LIBRARY Cocoa)
find_library(IOKIT_LIBRARY IOKit)
# Find the required Apple frameworks
find_library(FOUNDATION_FRAMEWORK Foundation)
find_library(VIDEO_TOOLBOX_FRAMEWORK VideoToolbox)
find_library(CORE_MEDIA_FRAMEWORK CoreMedia)
find_library(AV_FOUNDATION_FRAMEWORK AVFoundation)
find_library(CORE_VIDEO_FRAMEWORK CoreVideo)
find_library(IOSURFACE_LIB IOSurface)
find_package(OpenGL REQUIRED)
find_library(METAL_FRAMEWORK Metal)
find_library(METALKIT_FRAMEWORK MetalKit)
find_library(SCREENCAPTUREKIT_FRAMEWORK ScreenCaptureKit)
find_library(CARBON_FRAMEWORK Carbon)
find_library(MPS_FRAMEWORK MetalPerformanceShaders)
target_link_libraries(${PROJECT_NAME} PUBLIC
        ${FOUNDATION_FRAMEWORK}
        ${VIDEO_TOOLBOX_FRAMEWORK}
        ${CORE_MEDIA_FRAMEWORK}
        ${AV_FOUNDATION_FRAMEWORK}
        ${CORE_VIDEO_FRAMEWORK}
        ${IOSURFACE_LIB}
        ${METAL_FRAMEWORK}
        ${METALKIT_FRAMEWORK}
        ${COCOA_LIBRARY} ${IOKIT_LIBRARY} ${SCREENCAPTUREKIT_FRAMEWORK} ${CARBON_FRAMEWORK} ${MPS_FRAMEWORK}  "-framework CoreImage")

# Link the Qt libraries to the project
target_link_libraries(${PROJECT_NAME} PRIVATE Qt6::Core Qt6::Quick Qt6::Gui Qt6::Qml Qt6::GuiPrivate )