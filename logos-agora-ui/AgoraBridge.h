#pragma once
// AgoraBridge.h
// Injected into QML as context property "agora".
// Routes QML calls → LogosAPI IPC → agora_module backend.
// Routes incoming Logos events → Qt signals → QML Connections{}.

#include <QObject>
#include <QVariantMap>
#include <QVariantList>
#include <QString>
#include <QStringList>
#include <QClipboard>
#include <QGuiApplication>
#include <QDateTime>

class LogosAPI;

class AgoraBridge : public QObject
{
    Q_OBJECT

    Q_PROPERTY(QString messagingStatus  READ messagingStatus  NOTIFY statusChanged)
    Q_PROPERTY(QString blockchainStatus READ blockchainStatus NOTIFY statusChanged)
    Q_PROPERTY(QString storageStatus    READ storageStatus    NOTIFY statusChanged)
    Q_PROPERTY(QString daemonAIStatus   READ daemonAIStatus   NOTIFY statusChanged)
    Q_PROPERTY(QString agentId          READ agentId          NOTIFY agentChanged)
    Q_PROPERTY(QString balance          READ balance          NOTIFY agentChanged)
    Q_PROPERTY(QString stake            READ stake            NOTIFY agentChanged)
    Q_PROPERTY(double  reputation       READ reputation       NOTIFY agentChanged)
    Q_PROPERTY(bool    registered       READ registered       NOTIFY agentChanged)

public:
    explicit AgoraBridge(LogosAPI *logosAPI, QObject *parent = nullptr);
    void handleEvent(const QString &eventName, const QVariantList &data);

    QString messagingStatus()  const { return m_messagingStatus; }
    QString blockchainStatus() const { return m_blockchainStatus; }
    QString storageStatus()    const { return m_storageStatus; }
    QString daemonAIStatus()   const { return m_daemonAIStatus; }
    QString agentId()          const { return m_agentId; }
    QString balance()          const { return m_balance; }
    QString stake()            const { return m_stake; }
    double  reputation()       const { return m_reputation; }
    bool    registered()       const { return m_registered; }

public slots:
    // Agent identity
    Q_INVOKABLE void registerAgent(const QString &stakeNom, const QStringList &capabilities);
    Q_INVOKABLE void getAgentStatus();

    // Marketplace
    Q_INVOKABLE void loadMarketplace();
    Q_INVOKABLE void broadcastCapabilities(const QVariantList &services);

    // Buy flow
    Q_INVOKABLE void broadcastIntent(const QString &category, const QString &task,
                                      const QString &budgetNom, const QString &maxPricePerUnit,
                                      int maxLatencyMs, double minReputation);
    Q_INVOKABLE void acceptOffer(const QString &sessionId, const QString &sellerId,
                                  const QString &totalPrice, const QString &deliveryHash);
    Q_INVOKABLE void verifyAndRelease(const QString &escrowId, const QString &cid,
                                       const QString &outputHash);

    // Sell flow
    Q_INVOKABLE void evaluateIntent(const QVariantMap &intent);
    Q_INVOKABLE void sendOffer(const QString &sessionId, const QString &buyerId,
                                const QString &capabilityId, const QString &pricePerUnit,
                                int estimatedUnits, const QString &totalPrice,
                                const QString &deliveryHashCommitment);
    Q_INVOKABLE void executeTask(const QString &sessionId, const QString &task,
                                  const QString &category, const QString &escrowId);

    // Wallet
    Q_INVOKABLE void getWalletState();
    Q_INVOKABLE void getTradeHistory();

    // Feed
    Q_INVOKABLE void subscribeFeed();
    Q_INVOKABLE void unsubscribeFeed();

    // Utilities
    Q_INVOKABLE void copyToClipboard(const QString &text);
    Q_INVOKABLE QString fmtAgo(qint64 timestampMs);
    Q_INVOKABLE void checkNodeStatus();

signals:
    void statusChanged();
    void agentChanged();

    // Identity
    void agentRegistered(const QVariantMap &record);
    void agentStatus(const QVariantMap &status);

    // Marketplace
    void marketplaceLoaded(const QVariantList &agents);

    // Buy
    void offersReceived(const QVariantList &offers);
    void offerAccepted(const QString &sessionId, const QString &escrowId);
    void buyLog(const QString &message, const QString &color);
    void buyComplete(const QVariantMap &receipt);
    void buyError(const QString &error);

    // Sell
    void intentReceived(const QVariantMap &intent);
    void daemonEvaluation(const QString &action, const QString &reason);
    void offerSent(const QString &sessionId);
    void sellLog(const QString &message, const QString &color);
    void taskComplete(const QVariantMap &result);

    // Wallet
    void walletState(const QVariantMap &state);
    void tradeHistory(const QVariantList &trades);

    // Feed
    void feedEvent(const QVariantMap &event);

private:
    void callBackend(const QString &method, const QVariantList &args = {});
    LogosAPI *m_logosAPI;
    QString m_messagingStatus  = "connecting";
    QString m_blockchainStatus = "connecting";
    QString m_storageStatus    = "connecting";
    QString m_daemonAIStatus   = "connecting";
    QString m_agentId;
    QString m_balance  = "0";
    QString m_stake    = "0";
    double  m_reputation = 0.5;
    bool    m_registered = false;
    static constexpr const char *kModule = "agora_module";
};
