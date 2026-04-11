// agora_module_plugin.cpp
#include "agora_module_plugin.h"
#include "src/MessagingService.h"
#include "src/BlockchainService.h"
#include "src/StorageService.h"
#include "src/DaemonAIService.h"
#include "src/AgoraCore.h"

#include "logos_api.h"
#include "logos_api_client.h"

#include <QDebug>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QTimer>

AgoraModulePlugin::AgoraModulePlugin(QObject *parent)
    : QObject(parent)
{
    qDebug() << "AgoraModulePlugin: created";
}

AgoraModulePlugin::~AgoraModulePlugin()
{
    qDebug() << "AgoraModulePlugin: destroyed";
}

void AgoraModulePlugin::initLogos(LogosAPI *logosAPI)
{
    qDebug() << "AgoraModulePlugin: initLogos";
    m_logosAPI = logosAPI;
    setupEventHandlers();

    // Check node status on init
    QTimer::singleShot(500, this, &AgoraModulePlugin::checkNodeStatus);
}

void AgoraModulePlugin::setupEventHandlers()
{
    if (!m_logosAPI) return;

    // Route all incoming Logos events to the UI bridge via IPC
    m_logosAPI->getClient(kSelf)->onEvent([this](const QString &event, const QVariantList &data) {
        Q_UNUSED(event); Q_UNUSED(data);
        // Events are forwarded to the UI component via LogosAPI event bus
    });
}

void AgoraModulePlugin::callClient(const QString &method, const QVariantList &args)
{
    if (!m_logosAPI) { qWarning() << "AgoraModule: no LogosAPI"; return; }
    m_logosAPI->getClient(kSelf)->call(method, args);
}

// ── Agent identity ────────────────────────────────────────────────

void AgoraModulePlugin::registerAgent(const QString &stakeNom, const QStringList &capabilities)
{
    callClient("registerAgent", { stakeNom, capabilities });
}

void AgoraModulePlugin::getAgentStatus()
{
    callClient("getAgentStatus");
}

// ── Marketplace ───────────────────────────────────────────────────

void AgoraModulePlugin::loadMarketplace()
{
    // Poll Logos Messaging store for recent capability broadcasts
    callClient("loadMarketplace");
}

void AgoraModulePlugin::broadcastCapabilities(const QVariantList &services)
{
    callClient("broadcastCapabilities", { QVariant(services) });
}

// ── Buy flow ──────────────────────────────────────────────────────

void AgoraModulePlugin::broadcastIntent(
    const QString &category, const QString &task,
    const QString &budgetNom, const QString &maxPricePerUnit,
    int maxLatencyMs, double minReputation)
{
    callClient("broadcastIntent", {
        category, task, budgetNom, maxPricePerUnit, maxLatencyMs, minReputation
    });
}

void AgoraModulePlugin::acceptOffer(
    const QString &sessionId, const QString &sellerId,
    const QString &totalPrice, const QString &deliveryHash)
{
    callClient("acceptOffer", { sessionId, sellerId, totalPrice, deliveryHash });
}

void AgoraModulePlugin::verifyAndRelease(
    const QString &escrowId, const QString &cid, const QString &outputHash)
{
    callClient("verifyAndRelease", { escrowId, cid, outputHash });
}

// ── Sell flow ─────────────────────────────────────────────────────

void AgoraModulePlugin::evaluateIntent(const QVariantMap &intent)
{
    // DaemonAI reasons about whether to respond
    callClient("evaluateIntent", { intent });
}

void AgoraModulePlugin::sendOffer(
    const QString &sessionId, const QString &buyerId,
    const QString &capabilityId, const QString &pricePerUnit,
    int estimatedUnits, const QString &totalPrice,
    const QString &deliveryHashCommitment)
{
    callClient("sendOffer", {
        sessionId, buyerId, capabilityId,
        pricePerUnit, estimatedUnits, totalPrice, deliveryHashCommitment
    });
}

void AgoraModulePlugin::executeTask(
    const QString &sessionId, const QString &task,
    const QString &category, const QString &escrowId)
{
    // Runs daemon-ai locally, pins to Logos Storage, sends delivery notification
    callClient("executeTask", { sessionId, task, category, escrowId });
}

// ── Wallet ────────────────────────────────────────────────────────

void AgoraModulePlugin::getWalletState()
{
    callClient("getWalletState");
}

void AgoraModulePlugin::getTradeHistory()
{
    callClient("getTradeHistory");
}

// ── Live feed ─────────────────────────────────────────────────────

void AgoraModulePlugin::subscribeFeed()
{
    callClient("subscribeFeed");
}

void AgoraModulePlugin::unsubscribeFeed()
{
    callClient("unsubscribeFeed");
}

// ── Node health ───────────────────────────────────────────────────

void AgoraModulePlugin::checkNodeStatus()
{
    callClient("checkNodeStatus");
}
