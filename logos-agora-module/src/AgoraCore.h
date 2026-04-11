#pragma once
// AgoraCore.h
//
// Orchestrator for the Agora backend module.
// Coordinates DaemonAI, MessagingService, BlockchainService, StorageService.

#include <QObject>
#include <QString>
#include <QVariantMap>
#include <QVariantList>
#include <QStringList>
#include <QTimer>
#include <memory>

class LogosAPI;
class MessagingService;
class BlockchainService;
class StorageService;
class DaemonAIService;

class AgoraCore : public QObject
{
    Q_OBJECT
public:
    explicit AgoraCore(LogosAPI *logosAPI, QObject *parent = nullptr);
    ~AgoraCore() override;

    // ── Agent identity ────────────────────────────────────────────
    void registerAgent(const QString &stakeNom, const QStringList &capabilities);
    void getAgentStatus();

    // ── Marketplace ───────────────────────────────────────────────
    void loadMarketplace();
    void broadcastCapabilities(const QVariantList &services);

    // ── Buy flow ──────────────────────────────────────────────────
    void broadcastIntent(const QString &category, const QString &task,
                         const QString &budgetNom, const QString &maxPricePerUnit,
                         int maxLatencyMs, double minReputation);
    void acceptOffer(const QString &sessionId, const QString &sellerId,
                     const QString &totalPrice, const QString &deliveryHash);
    void verifyAndRelease(const QString &escrowId, const QString &cid,
                          const QString &outputHash);

    // ── Sell flow ─────────────────────────────────────────────────
    void evaluateIntent(const QVariantMap &intent);
    void sendOffer(const QString &sessionId, const QString &buyerId,
                   const QString &capabilityId, const QString &pricePerUnit,
                   int estimatedUnits, const QString &totalPrice,
                   const QString &deliveryHashCommitment);
    void executeTask(const QString &sessionId, const QString &task,
                     const QString &category, const QString &escrowId);

    // ── Wallet ────────────────────────────────────────────────────
    void getWalletState();
    void getTradeHistory();

    // ── Feed ──────────────────────────────────────────────────────
    void subscribeFeed();
    void unsubscribeFeed();

    // ── Status ────────────────────────────────────────────────────
    void checkNodeStatus();

signals:
    // Status
    void nodeStatus(const QString &messaging, const QString &blockchain, const QString &storage, const QString &daemonAI);

    // Identity
    void agentRegistered(const QVariantMap &record);
    void agentStatus(const QVariantMap &status);

    // Marketplace
    void marketplaceLoaded(const QVariantList &agents);
    void capabilitiesBroadcast(bool ok);

    // Buy flow
    void offersReceived(const QVariantList &offers);
    void offerAccepted(const QString &sessionId, const QString &escrowId);
    void buyLog(const QString &message, const QString &color);
    void buyComplete(const QVariantMap &receipt);
    void buyError(const QString &error);

    // Sell flow
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
    void emitLog(const QString &to, const QString &msg, const QString &color);

    LogosAPI         *m_logosAPI;
    MessagingService *m_messaging  = nullptr;
    BlockchainService*m_blockchain = nullptr;
    StorageService   *m_storage    = nullptr;
    DaemonAIService  *m_daemonAI   = nullptr;

    QTimer  *m_capabilityTimer = nullptr;
    QString  m_agentId;
    QString  m_pendingBuyerNonce;  // FIX-2: buyer nonce for current trade
    qint64   m_agreedDocSize = 0;  // FIX-7: agreed delivery size from offer
    QString  m_privKeyHex;
};
