#pragma once
// MessagingService.h — Logos Messaging integration
// FIX-6: Nonce added to all outgoing messages (replay prevention)
// FIX-9: Rate limiting + minimum reputation check on incoming intents
#include <QObject>
#include <QString>
#include <QVariantMap>
#include <QVariantList>
#include <QStringList>
#include <QNetworkAccessManager>
#include <QDateTime>
#include <QSet>
#include <QHash>

// FIX-6: Reject messages older than this
static constexpr qint64 kMessageValidityWindowMs = 5 * 60 * 1000;
// FIX-9: Max messages per sender per minute
static constexpr int kRateLimitPerSenderPerMin = 10;
// FIX-9: Minimum reputation to have intents processed
static constexpr double kMinSenderReputation = 0.30;

class MessagingService : public QObject {
    Q_OBJECT
public:
    explicit MessagingService(QObject *parent = nullptr);
    bool isConnected() const;

    QVariantList fetchCapabilities();
    bool broadcastCapabilities(const QString &agentId, const QVariantList &services);
    bool broadcastPresence(const QString &agentId);
    QVariantList broadcastIntentAndCollect(
        const QString &agentId, const QString &category, const QString &task,
        const QString &budget, const QString &maxPrice, int maxLatencyMs, double minRep);
    bool sendAccept(const QString &sessionId, const QString &buyerId, const QString &sellerId);
    bool sendOffer(const QString &sessionId, const QString &sellerId, const QString &buyerId,
                   const QString &capId, const QString &price, int units,
                   const QString &total, const QString &hashCommit);
    bool sendDelivery(const QString &sessionId, const QString &escrowId,
                      const QString &sellerId, const QString &cid, const QString &hash);
    void subscribeFeed();
    void unsubscribeFeed();

signals:
    void intentReceived(const QVariantMap &intent);
    void feedEvent(const QVariantMap &event);

private:
    QNetworkAccessManager *m_nam;
    QString m_nodeUrl    = "http://localhost:8645";
    bool    m_connected  = false;
    bool    m_feedActive = false;

    // FIX-6: Seen nonces — map nonce -> expiry time
    QHash<QString, qint64> m_seenNonces;
    // FIX-9: Rate limiting — map senderId -> list of message timestamps
    QHash<QString, QList<qint64>> m_rateLimitWindows;

    void checkConnection();
    bool publish(const QString &topic, const QVariantMap &payload);
    QVariantList pollStore(const QString &topic, qint64 sinceMs);
    QString generateNonce() const;

    // FIX-6: Returns true if message is fresh and nonce is unseen
    bool validateIncoming(const QVariantMap &msg);
    // FIX-9: Returns true if sender is under rate limit
    bool checkRateLimit(const QString &senderId);
    // Evict expired nonces from cache
    void evictExpiredNonces();
};
