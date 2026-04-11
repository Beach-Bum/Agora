#pragma once
// DaemonAIService.h
//
// Bridge to the daemon-ai C++ runtime (Mamba SSM LLM).
// Connects to the daemon process via HTTP (JSON-RPC compatible).
// Falls back to mock responses when daemon-ai is not available.

#include <QObject>
#include <QString>
#include <QVariantMap>
#include <QVariantList>
#include <QNetworkAccessManager>
#include <QNetworkReply>

class DaemonAIService : public QObject
{
    Q_OBJECT
public:
    explicit DaemonAIService(QObject *parent = nullptr);

    // Check if daemon-ai runtime is reachable
    bool isAvailable() const { return m_available; }

    // Complete a prompt using daemon-ai (blocking for simplicity — async in production)
    QString complete(const QString &prompt,
                     const QString &system = QString(),
                     int maxTokens = 1024,
                     float temperature = 0.7f);

    // Reason about best offer from a list
    QVariantMap pickBestOffer(const QVariantList &offers,
                               const QString &budget,
                               const QString &category);

    // Decide whether to respond to an incoming intent
    QVariantMap evaluateIntent(const QVariantMap &intent);

    // Execute a task and return the output
    QString executeTask(const QString &task, const QString &category);

private:
    void checkAvailability();
    QString completeMock(const QString &prompt, const QString &category = QString());

    QNetworkAccessManager *m_nam;
    bool   m_available = false;
    QString m_baseUrl  = "http://localhost:8765";
};

    // FIX-1: Prompt injection protection helpers
    QString sanitiseMarketplaceData(const QString &input, bool *suspicious = nullptr) const;
    QString buildSecureSystemPrompt(const QString &role) const;
