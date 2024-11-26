# HidingIn

## A macOS tool to help you protect your privacy during work hours.

Are you tired of colleagues staring at your screen, trying to see what you're doing? Do you want to obscure private content on your desktop—like chats in your social apps or other sensitive information that might not seem appropriate during work time? If so, **HidingIn** is the perfect app for you.

### What is HidingIn?

HidingIn is a lightweight macOS tool designed to help you "hide in plain sight." It allows you to obscure parts of your screen, so you can work (or relax) without worrying about prying eyes. Whether you're watching a video, chatting, or working with sensitive information, HidingIn will give you peace of mind.

Here are two examples showcasing how HidingIn works:

### **1. A Video-Playing Browser with HidingIn:**

![](./res/video.gif)

---

### **2. A Normal App Displaying Text:**

![](./res/poe.gif)

---

## Features
- **Obscure sensitive areas:** Mask parts of your screen to hide private content.
- **Customizable effects:** Adjust the appearance of the hidden areas to blend seamlessly with your desktop.
- **Easy to use:** Simple setup and operation with an intuitive interface.

---

## Future Plans

Here are some features planned for future development:

- [ ] Support for Windows.
- [ ] Better visibility adjustments for bright backgrounds.
- [ ] Waveform-like lightness effects when interacting with HidingIn.
- [ ] Sliders for fine-tuning hiding effects.
- [ ] Manual masking feature to completely hide specific screen areas.

---

## How to build

Building HidingIn project needs Qt6 and cmake. on macos, you could run your cmake commands like this to get a xcode project and build:
``` bash
cmake -G "Xcode" -DCMAKE_PREFIX_PATH=/Users/your_qt_6_path/6.8.0/macos/lib/cmake
```