// AgoraCore.cpp — Security hardened
#include "AgoraCore.h"
#include "MessagingService.h"
#include "BlockchainService.h"
#include "StorageService.h"
#include "DaemonAIService.h"
#include "logos_api.h"

#include <QCryptographicHash>
#include <QDateTime>
#include <QJsonDocument>
#include <QJsonObject>
#include <QRandomGenerator>
#include <QDebug>

AgoraCore::AgoraCore(LogosAPI *logosAPI, QObject *parent)
    : QObject(parent), m_logosAPI(logosAPI)
{
    m_messaging  = new MessagingService(this);
    m_blockchain = new BlockchainService(this);
    m_storage    = new StorageService(this);
    m_daemonAI   = new DaemonAIService(this);

    connect(m_messaging, &MessagingService::intentReceived,
            this, [this](const QVariantMap &intent) { emit intentReceived(intent); });
    connect(m_messaging, &MessagingService::feedEvent,
            this, [this](const QVariantMap &event) { emit feedEvent(event); });

    m_capabilityTimer = new QTimer(this);
    m_capabilityTimer->setInterval(60000);
    connect(m_capabilityTimer, &QTimer::timeout, this, [this]() {
        m_messaging->broadcastPresence(m_agentId);
    });
}

AgoraCore::~AgoraCore()
{
    if (m_capabilityTimer) m_capabilityTimer->stop();
    // FIX-5: Zero key material on destruction
    m_privKeyHex.fill('0');
    m_privKeyHex.clear();
}

void AgoraCore::checkNodeStatus()
{
    emit nodeStatus(
        m_messaging->isConnected()  ? "live" : "mock",
        m_blockchain->isConnected() ? "live" : "mock",
        m_storage->isConnected()    ? "live" : "mock",
        m_daemonAI->isAvailable()   ? "local" : "mock"
    );
}

void AgoraCore::registerAgent(const QString &stakeNom, const QStringList &capabilities)
{
    if (m_privKeyHex.isEmpty()) {
        QByteArray privBytes(32, 0);
        for (int i = 0; i < 32; ++i)
            privBytes[i] = static_cast<char>(QRandomGenerator::global()->bounded(256));
        m_privKeyHex = privBytes.toHex();
        m_agentId = "03" + QCryptographicHash::hash(privBytes, QCryptographicHash::Sha256)
                               .toHex().left(64);
        // FIX-5: Zero private key bytes from stack immediately after use
        privBytes.fill(0);
    }

    auto result = m_blockchain->registerIdentity(m_agentId, stakeNom, capabilities);
    QVariantMap record;
    record["agentId"]      = m_agentId;
    record["txHash"]       = result["txHash"];
    record["stake"]        = stakeNom;
    record["block"]        = result["block"];
    record["mock"]         = result["mock"];
    record["capabilities"] = capabilities;
    emit agentRegistered(record);
    m_capabilityTimer->start();
}

void AgoraCore::getAgentStatus()
{
    QVariantMap status;
    status["agentId"]    = m_agentId.isEmpty() ? "not registered" : m_agentId;
    status["registered"] = !m_agentId.isEmpty();
    status["reputation"] = m_blockchain->getReputation(m_agentId);
    status["balance"]    = m_blockchain->getBalance(m_agentId);
    emit agentStatus(status);
}

void AgoraCore::loadMarketplace()
{
    emit marketplaceLoaded(m_messaging->fetchCapabilities());
}

void AgoraCore::broadcastCapabilities(const QVariantList &services)
{
    emit capabilitiesBroadcast(m_messaging->broadcastCapabilities(m_agentId, services));
}

void AgoraCore::broadcastIntent(
    const QString &category, const QString &task,
    const QString &budgetNom, const QString &maxPricePerUnit,
    int maxLatencyMs, double minReputation)
{
    emitLog("buy", "► Broadcasting buy intent via Logos Messaging…", "#4a5072");
    emitLog("buy", QString("  category: %1 · budget: %2 NOM").arg(category, budgetNom), "#7c9ef7");

    // FIX-2: Generate buyer_nonce for escrow commitment
    QByteArray nonceBytes(16, 0);
    for (int i = 0; i < 16; ++i)
        nonceBytes[i] = static_cast<char>(QRandomGenerator::global()->bounded(256));
    m_pendingBuyerNonce = nonceBytes.toHex();

    auto offers = m_messaging->broadcastIntentAndCollect(
        m_agentId, category, task, budgetNom, maxPricePerUnit, maxLatencyMs, minReputation
    );

    if (offers.isEmpty()) {
        emit buyError("No offers received");
        return;
    }

    emitLog("buy", QString("► %1 offers received · daemon-ai evaluating…").arg(offers.size()), "#4a5072");

    // FIX-1: pickBestOffer sanitises all offer data before daemon-ai sees it
    QVariantMap bestOffer = m_daemonAI->pickBestOffer(offers, budgetNom, category);
    if (bestOffer.isEmpty()) {
        emit buyError("No suitable offer found or all offers flagged as suspicious");
        return;
    }

    emitLog("buy", QString("  Selected: %1 · %2 NOM")
        .arg(bestOffer.value("sellerName","agent").toString(),
             bestOffer.value("totalPrice","0").toString()), "#2fb67a");

    emit offersReceived(offers);
}

void AgoraCore::acceptOffer(
    const QString &sessionId, const QString &sellerId,
    const QString &totalPrice, const QString &deliveryHash)
{
    emitLog("buy", "► Sending accept via Logos Messaging…", "#4a5072");
    m_messaging->sendAccept(sessionId, m_agentId, sellerId);

    emitLog("buy", "► Locking escrow on Logos Blockchain LSSA…", "#4a5072");

    // FIX-2: Pass buyer_nonce to escrow contract
    auto escrow = m_blockchain->createEscrow(
        m_privKeyHex, sellerId, totalPrice, deliveryHash,
        m_pendingBuyerNonce,   // FIX-2
        60000, 500
    );

    emitLog("buy", QString("  escrow: %1… · %2 NOM locked")
        .arg(escrow["escrowId"].toString().left(24), totalPrice), "#7c9ef7");

    emit offerAccepted(sessionId, escrow["escrowId"].toString());
}

void AgoraCore::verifyAndRelease(
    const QString &escrowId, const QString &cid, const QString &outputHash)
{
    // FIX-7: Download with size limit from agreed commitment
    emitLog("buy", "► Downloading from Logos Storage (size-limited)…", "#4a5072");

    QByteArray content;
    try {
        content = m_storage->download(cid, kMaxDownloadBytes, m_agreedDocSize);
    } catch (const std::exception &e) {
        emitLog("buy", QString("✗ Download rejected: %1").arg(e.what()), "#e05252");
        m_blockchain->openDispute(m_privKeyHex, escrowId, "oversized_delivery");
        emit buyError(QString("Delivery rejected: %1").arg(e.what()));
        return;
    }

    // FIX-7: Full delivery verification — hash + size
    auto [valid, reason] = m_storage->verifyDelivery(content, outputHash, m_agreedDocSize);
    if (!valid) {
        emitLog("buy", QString("✗ Delivery invalid: %1").arg(reason), "#e05252");
        m_blockchain->openDispute(m_privKeyHex, escrowId, reason);
        emit buyError("Delivery verification failed: " + reason);
        return;
    }

    emitLog("buy", "  ✓ Hash and size verified", "#2fb67a");
    emitLog("buy", "► Releasing escrow via Blend Network…", "#4a5072");

    // FIX-2: Pass buyer_nonce when releasing — LSSA contract verifies it
    m_blockchain->releaseEscrow(m_privKeyHex, escrowId, outputHash, m_pendingBuyerNonce);
    emitLog("buy", "  ✓ Payment released", "#2fb67a");

    QVariantMap receipt;
    receipt["escrowId"]   = escrowId;
    receipt["cid"]        = cid;
    receipt["outputHash"] = outputHash;
    receipt["output"]     = QString::fromUtf8(content);
    emit buyComplete(receipt);

    // FIX-5: Clear sensitive nonce after use
    m_pendingBuyerNonce.clear();
}

void AgoraCore::evaluateIntent(const QVariantMap &intent)
{
    // FIX-1: evaluateIntent sanitises before daemon-ai
    auto decision = m_daemonAI->evaluateIntent(intent);
    if (decision.value("suspicious", false).toBool()) {
        qWarning() << "AgoraCore: suspicious intent — dropping";
        emit daemonEvaluation("reject", "suspicious_content");
        return;
    }
    emit daemonEvaluation(decision["action"].toString(), decision["reason"].toString());
}

void AgoraCore::sendOffer(
    const QString &sessionId, const QString &buyerId,
    const QString &capabilityId, const QString &pricePerUnit,
    int estimatedUnits, const QString &totalPrice,
    const QString &deliveryHashCommitment)
{
    m_messaging->sendOffer(sessionId, m_agentId, buyerId, capabilityId,
                           pricePerUnit, estimatedUnits, totalPrice, deliveryHashCommitment);
    emitLog("sell", QString("► Offer sent · session %1 · %2 NOM")
        .arg(sessionId.left(8), totalPrice), "#2fb67a");
    emit offerSent(sessionId);
}

void AgoraCore::executeTask(
    const QString &sessionId, const QString &task,
    const QString &category, const QString &escrowId)
{
    emitLog("sell", "► Executing task with daemon-ai (isolated, no tools)…", "#4a5072");

    // FIX-1 + FIX-8: executeTask sanitises task and uses isolated system prompt
    QString output = m_daemonAI->executeTask(task, category);
    emitLog("sell", "  ✓ Task complete", "#2fb67a");

    emitLog("sell", "► Pinning to Logos Storage…", "#4a5072");
    auto storageResult = m_storage->upload(output.toUtf8(), "text/plain",
        QString("task_%1.txt").arg(sessionId.left(8)));
    emitLog("sell", QString("  CID: %1…").arg(storageResult["cid"].toString().left(24)), "#7c9ef7");

    emitLog("sell", "► Sending delivery notification…", "#4a5072");
    m_messaging->sendDelivery(sessionId, escrowId, m_agentId,
        storageResult["cid"].toString(), storageResult["hash"].toString());
    emitLog("sell", "  ✓ Delivery notified · awaiting escrow release", "#2fb67a");

    QVariantMap result;
    result["sessionId"] = sessionId;
    result["escrowId"]  = escrowId;
    result["cid"]       = storageResult["cid"];
    result["hash"]      = storageResult["hash"];
    result["output"]    = output;
    emit taskComplete(result);
}

void AgoraCore::getWalletState()
{
    QVariantMap state;
    state["agentId"]    = m_agentId;
    state["balance"]    = m_blockchain->getBalance(m_agentId);
    state["stake"]      = "5000";
    state["reputation"] = m_blockchain->getReputation(m_agentId);
    emit walletState(state);
}

void AgoraCore::getTradeHistory()
{
    emit tradeHistory(m_blockchain->getTradeHistory(m_agentId));
}

void AgoraCore::subscribeFeed()   { m_messaging->subscribeFeed(); }
void AgoraCore::unsubscribeFeed() { m_messaging->unsubscribeFeed(); }

void AgoraCore::emitLog(const QString &to, const QString &msg, const QString &color)
{
    if (to == "buy")  emit buyLog(msg, color);
    if (to == "sell") emit sellLog(msg, color);
}
