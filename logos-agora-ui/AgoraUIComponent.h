#pragma once
// AgoraUIComponent.h — IComponent for Logos Basecamp
#include <IComponent.h>
#include <QObject>
#include <QWidget>

class LogosAPI;
class AgoraBridge;

class AgoraUIComponent : public QObject, public IComponent
{
    Q_OBJECT
    Q_INTERFACES(IComponent)
    Q_PLUGIN_METADATA(IID IComponent_iid FILE "metadata.json")

public:
    explicit AgoraUIComponent(QObject *parent = nullptr);
    ~AgoraUIComponent() override;

    QWidget *createWidget(LogosAPI *logosAPI = nullptr) override;
    void     destroyWidget(QWidget *widget)             override;
};
