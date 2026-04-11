#pragma once
// agora_module_plugin.h
//
// Logos Basecamp backend plugin for Agora.
// Loaded by liblogos kernel. Registered as "agora_module".
// All business logic lives here; QML calls it via the bridge.

#include "interface.h"
#include <QObject>
#include <QVariantMap>
#include <QVariantList>
#include <QString>

class LogosAPI;

class AgoraModulePlugin : public QObject, public PluginInterface
{
    Q_OBJECT
    Q_INTERFACES(PluginInterface)
    Q_PLUGIN_METADATA(IID PluginInterface_iid FILE "metadata.json")

public:
    explicit AgoraModulePlugin(QObject *parent = nullptr);
    ~AgoraModulePlugin() override;

    // PluginInterface entry point — called by liblogos on load
    void initLogos(LogosAPI *logosAPI) override;

public slots:
    // ── Agent identity ────────────────────────────────────────────
    Q_INVOKABLE void registerAgent(const QString &stakeNom,
                                    const QStringList &capabilities);
    Q_INVOKABLE void getAgentStatus();

    // ── Marketplace discovery ─────────────────────────────────────
    Q_INVOKABLE void loadMarketplace();
    Q_INVOKABLE void broadcastCapabilities(const QVariantList &services);

    // ── Buy flow ──────────────────────────────────────────────────
    Q_INVOKABLE void broadcastIntent(const QString &category,
                                      const QString &task,
                                      const QString &budgetNom,
                                      const QString &maxPricePerUnit,
                                      int maxLatencyMs,
                                      double minReputation);
    Q_INVOKABLE void acceptOffer(const QString &sessionId,
                                  const QString &sellerId,
                                  const QString &totalPrice,
                                  const QString &deliveryHash);
    Q_INVOKABLE void verifyAndRelease(const QString &escrowId,
                                       const QString &cid,
                                       const QString &outputHash);

    // ── Sell flow ─────────────────────────────────────────────────
    Q_INVOKABLE void evaluateIntent(const QVariantMap &intent);
    Q_INVOKABLE void sendOffer(const QString &sessionId,
                                const QString &buyerId,
                                const QString &capabilityId,
                                const QString &pricePerUnit,
                                int estimatedUnits,
                                const QString &totalPrice,
                                const QString &deliveryHashCommitment);
    Q_INVOKABLE void executeTask(const QString &sessionId,
                                  const QString &task,
                                  const QString &category,
                                  const QString &escrowId);

    // ── Wallet ────────────────────────────────────────────────────
    Q_INVOKABLE void getWalletState();
    Q_INVOKABLE void getTradeHistory();

    // ── Live feed ─────────────────────────────────────────────────
    Q_INVOKABLE void subscribeFeed();
    Q_INVOKABLE void unsubscribeFeed();

    // ── Node health ───────────────────────────────────────────────
    Q_INVOKABLE void checkNodeStatus();

private:
    void callClient(const QString &method, const QVariantList &args = {});
    void setupEventHandlers();

    LogosAPI *m_logosAPI = nullptr;
    static constexpr const char *kSelf = "agora_module";
};
