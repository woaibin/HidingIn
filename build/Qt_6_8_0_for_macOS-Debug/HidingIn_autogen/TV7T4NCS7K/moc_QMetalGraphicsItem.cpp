/****************************************************************************
** Meta object code from reading C++ file 'QMetalGraphicsItem.h'
**
** Created by: The Qt Meta Object Compiler version 68 (Qt 6.8.0)
**
** WARNING! All changes made in this file will be lost!
*****************************************************************************/

#include "../../../../RenderWidget/QMetalGraphicsItem.h"
#include <QtCore/qmetatype.h>

#include <QtCore/qtmochelpers.h>

#include <memory>


#include <QtCore/qxptype_traits.h>
#if !defined(Q_MOC_OUTPUT_REVISION)
#error "The header file 'QMetalGraphicsItem.h' doesn't include <QObject>."
#elif Q_MOC_OUTPUT_REVISION != 68
#error "This file was generated using the moc from 6.8.0. It"
#error "cannot be used with the include files from this version of Qt."
#error "(The moc has changed too much.)"
#endif

#ifndef Q_CONSTINIT
#define Q_CONSTINIT
#endif

QT_WARNING_PUSH
QT_WARNING_DISABLE_DEPRECATED
QT_WARNING_DISABLE_GCC("-Wuseless-cast")
namespace {

#ifdef QT_MOC_HAS_STRINGDATA
struct qt_meta_stringdata_CLASSQMetalGraphicsItemENDCLASS_t {};
constexpr auto qt_meta_stringdata_CLASSQMetalGraphicsItemENDCLASS = QtMocHelpers::stringData(
    "QMetalGraphicsItem",
    "onBeforeRendering",
    "",
    "onBeforeRenderPassRecording",
    "handleWindowChanged",
    "QQuickWindow*",
    "win",
    "sync",
    "cleanup"
);
#else  // !QT_MOC_HAS_STRINGDATA
#error "qtmochelpers.h not found or too old."
#endif // !QT_MOC_HAS_STRINGDATA
} // unnamed namespace

Q_CONSTINIT static const uint qt_meta_data_CLASSQMetalGraphicsItemENDCLASS[] = {

 // content:
      12,       // revision
       0,       // classname
       0,    0, // classinfo
       5,   14, // methods
       0,    0, // properties
       0,    0, // enums/sets
       0,    0, // constructors
       0,       // flags
       0,       // signalCount

 // slots: name, argc, parameters, tag, flags, initial metatype offsets
       1,    0,   44,    2, 0x08,    1 /* Private */,
       3,    0,   45,    2, 0x08,    2 /* Private */,
       4,    1,   46,    2, 0x08,    3 /* Private */,
       7,    0,   49,    2, 0x0a,    5 /* Public */,
       8,    0,   50,    2, 0x0a,    6 /* Public */,

 // slots: parameters
    QMetaType::Void,
    QMetaType::Void,
    QMetaType::Void, 0x80000000 | 5,    6,
    QMetaType::Void,
    QMetaType::Void,

       0        // eod
};

Q_CONSTINIT const QMetaObject QMetalGraphicsItem::staticMetaObject = { {
    QMetaObject::SuperData::link<QQuickItem::staticMetaObject>(),
    qt_meta_stringdata_CLASSQMetalGraphicsItemENDCLASS.offsetsAndSizes,
    qt_meta_data_CLASSQMetalGraphicsItemENDCLASS,
    qt_static_metacall,
    nullptr,
    qt_incomplete_metaTypeArray<qt_meta_stringdata_CLASSQMetalGraphicsItemENDCLASS_t,
        // Q_OBJECT / Q_GADGET
        QtPrivate::TypeAndForceComplete<QMetalGraphicsItem, std::true_type>,
        // method 'onBeforeRendering'
        QtPrivate::TypeAndForceComplete<void, std::false_type>,
        // method 'onBeforeRenderPassRecording'
        QtPrivate::TypeAndForceComplete<void, std::false_type>,
        // method 'handleWindowChanged'
        QtPrivate::TypeAndForceComplete<void, std::false_type>,
        QtPrivate::TypeAndForceComplete<QQuickWindow *, std::false_type>,
        // method 'sync'
        QtPrivate::TypeAndForceComplete<void, std::false_type>,
        // method 'cleanup'
        QtPrivate::TypeAndForceComplete<void, std::false_type>
    >,
    nullptr
} };

void QMetalGraphicsItem::qt_static_metacall(QObject *_o, QMetaObject::Call _c, int _id, void **_a)
{
    if (_c == QMetaObject::InvokeMetaMethod) {
        auto *_t = static_cast<QMetalGraphicsItem *>(_o);
        (void)_t;
        switch (_id) {
        case 0: _t->onBeforeRendering(); break;
        case 1: _t->onBeforeRenderPassRecording(); break;
        case 2: _t->handleWindowChanged((*reinterpret_cast< std::add_pointer_t<QQuickWindow*>>(_a[1]))); break;
        case 3: _t->sync(); break;
        case 4: _t->cleanup(); break;
        default: ;
        }
    } else if (_c == QMetaObject::RegisterMethodArgumentMetaType) {
        switch (_id) {
        default: *reinterpret_cast<QMetaType *>(_a[0]) = QMetaType(); break;
        case 2:
            switch (*reinterpret_cast<int*>(_a[1])) {
            default: *reinterpret_cast<QMetaType *>(_a[0]) = QMetaType(); break;
            case 0:
                *reinterpret_cast<QMetaType *>(_a[0]) = QMetaType::fromType< QQuickWindow* >(); break;
            }
            break;
        }
    }
}

const QMetaObject *QMetalGraphicsItem::metaObject() const
{
    return QObject::d_ptr->metaObject ? QObject::d_ptr->dynamicMetaObject() : &staticMetaObject;
}

void *QMetalGraphicsItem::qt_metacast(const char *_clname)
{
    if (!_clname) return nullptr;
    if (!strcmp(_clname, qt_meta_stringdata_CLASSQMetalGraphicsItemENDCLASS.stringdata0))
        return static_cast<void*>(this);
    return QQuickItem::qt_metacast(_clname);
}

int QMetalGraphicsItem::qt_metacall(QMetaObject::Call _c, int _id, void **_a)
{
    _id = QQuickItem::qt_metacall(_c, _id, _a);
    if (_id < 0)
        return _id;
    if (_c == QMetaObject::InvokeMetaMethod) {
        if (_id < 5)
            qt_static_metacall(this, _c, _id, _a);
        _id -= 5;
    } else if (_c == QMetaObject::RegisterMethodArgumentMetaType) {
        if (_id < 5)
            qt_static_metacall(this, _c, _id, _a);
        _id -= 5;
    }
    return _id;
}
QT_WARNING_POP
