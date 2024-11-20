//
// Created by 宾小康 on 2024/11/19.
//

#ifndef GLOBALEVENTHANDLER_H
#define GLOBALEVENTHANDLER_H
#include <functional>
#include <utility>
using KeysPressedCB = std::function<void(int keyCode)>;

class GlobalEventHandler {
public:
    GlobalEventHandler();
    ~GlobalEventHandler();

    // Start listening for global key events
    void startListening();

    // Stop listening for global key events
    void stopListening();

    // Internal method to handle key events (pure C++)
    bool handleKeyPress(int keycode, bool isCommandPressed);

    void setCtrlColonPressedCB(KeysPressedCB cb){
        ctrlColonPressedCB = std::move(cb);
    }

    void setCtrlDoubleQuotePressedCB(KeysPressedCB cb){
        ctrlDoubleQuotePressedCB = std::move(cb);
    }

private:

    // macOS-specific implementation
    void* eventTap;  // Placeholder for event tap reference
    void* runLoopSource;  // Placeholder for run loop source
    KeysPressedCB ctrlColonPressedCB;
    KeysPressedCB ctrlDoubleQuotePressedCB;
};

#endif // GLOBALEVENTHANDLER_H