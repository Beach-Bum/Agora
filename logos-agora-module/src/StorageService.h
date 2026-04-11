#pragma once
// StorageService.h — Logos Storage integration
// FIX-7: Max download size enforced before hash verification
#include <QObject>
#include <QString>
#include <QVariantMap>
#include <QByteArray>
#include <QNetworkAccessManager>

// FIX-7: Hard cap on download size — prevents OOM from malicious CIDs
static constexpr qint64 kMaxDownloadBytes = 50LL * 1024 * 1024; // 50 MB
static constexpr double kMaxDocSizeMultiplier = 1.1;             // 10% tolerance over agreed

class StorageService : public QObject {
    Q_OBJECT
public:
    explicit StorageService(QObject *parent = nullptr);
    bool isConnected() const;

    QVariantMap upload(const QByteArray &content, const QString &mimeType,
                       const QString &filename);
    // FIX-7: agreedSize cap applied before hash verification
    QByteArray  download(const QString &cid,
                         qint64 maxBytes = kMaxDownloadBytes,
                         qint64 agreedSize = 0);
    bool        verifyHash(const QByteArray &content, const QString &expectedHash);
    // FIX-7: Full delivery check — hash + size + MIME
    QPair<bool,QString> verifyDelivery(const QByteArray &content,
                                        const QString &expectedHash,
                                        qint64 agreedSize = 0);

private:
    QNetworkAccessManager *m_nam;
    QString m_nodeUrl   = "http://localhost:8080";
    bool    m_connected = false;
    void checkConnection();
};
