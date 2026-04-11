#pragma once
// BlockchainService.h — Logos Blockchain LSSA integration
#include <QObject>
#include <QString>
#include <QVariantMap>
#include <QVariantList>
#include <QStringList>
#include <QNetworkAccessManager>

class BlockchainService : public QObject {
    Q_OBJECT
public:
    explicit BlockchainService(QObject *parent = nullptr);
    bool isConnected() const;

    QVariantMap registerIdentity(const QString &agentId, const QString &stakeNom, const QStringList &caps);
    double getReputation(const QString &agentId);
    QString getBalance(const QString &agentId);
    QVariantMap createEscrow(const QString &privKeyHex, const QString &sellerId, // FIX-2
                              const QString &amount, const QString &deliveryHash,
                              const QString &buyerNonce,    // FIX-2
                              int timeoutMs, int slashBps);
    bool releaseEscrow(const QString &privKeyHex, const QString &escrowId,
                       const QString &outputHash,
                       const QString &buyerNonce = QString()); // FIX-2
    bool openDispute(const QString &privKeyHex, const QString &escrowId, const QString &reason);
    QVariantList getTradeHistory(const QString &agentId);

private:
    QNetworkAccessManager *m_nam;
    QString m_nodeUrl   = "http://localhost:3001";
    bool    m_connected = false;
    void checkConnection();
    QVariantMap mockEscrow(const QString &sellerId, const QString &amount);
};
