// AgoraBridge.cpp
#include "AgoraBridge.h"
#include "logos_api.h"
#include "logos_api_client.h"
#include <QDebug>

AgoraBridge::AgoraBridge(LogosAPI *logosAPI, QObject *parent)
    : QObject(parent), m_logosAPI(logosAPI) {}

void AgoraBridge::handleEvent(const QString &eventName, const QVariantList &data)
{
    if (eventName == "node_status") {
        m_messagingStatus  = data.value(0).toString();
        m_blockchainStatus = data.value(1).toString();
        m_storageStatus    = data.value(2).toString();
        m_daemonAIStatus   = data.value(3).toString();
        emit statusChanged();
    } else if (eventName == "agent_registered") {
        auto rec = data.value(0).toMap();
        m_agentId    = rec.value("agentId").toString();
        m_stake      = rec.value("stake").toString();
        m_registered = true;
        emit agentChanged();
        emit agentRegistered(rec);
    } else if (eventName == "agent_status") {
        auto st = data.value(0).toMap();
        m_agentId    = st.value("agentId").toString();
        m_balance    = st.value("balance").toString();
        m_reputation = st.value("reputation").toDouble();
        m_registered = st.value("registered").toBool();
        emit agentChanged();
        emit agentStatus(st);
    } else if (eventName == "marketplace_loaded") {
        emit marketplaceLoaded(data.value(0).toList());
    } else if (eventName == "offers_received") {
        emit offersReceived(data.value(0).toList());
    } else if (eventName == "offer_accepted") {
        emit offerAccepted(data.value(0).toString(), data.value(1).toString());
    } else if (eventName == "buy_log") {
        emit buyLog(data.value(0).toString(), data.value(1).toString());
    } else if (eventName == "buy_complete") {
        emit buyComplete(data.value(0).toMap());
    } else if (eventName == "buy_error") {
        emit buyError(data.value(0).toString());
    } else if (eventName == "intent_received") {
        emit intentReceived(data.value(0).toMap());
    } else if (eventName == "daemon_evaluation") {
        emit daemonEvaluation(data.value(0).toString(), data.value(1).toString());
    } else if (eventName == "offer_sent") {
        emit offerSent(data.value(0).toString());
    } else if (eventName == "sell_log") {
        emit sellLog(data.value(0).toString(), data.value(1).toString());
    } else if (eventName == "task_complete") {
        emit taskComplete(data.value(0).toMap());
    } else if (eventName == "wallet_state") {
        auto st = data.value(0).toMap();
        m_balance    = st.value("balance").toString();
        m_stake      = st.value("stake").toString();
        m_reputation = st.value("reputation").toDouble();
        emit agentChanged();
        emit walletState(st);
    } else if (eventName == "trade_history") {
        emit tradeHistory(data.value(0).toList());
    } else if (eventName == "feed_event") {
        emit feedEvent(data.value(0).toMap());
    }
}

void AgoraBridge::callBackend(const QString &method, const QVariantList &args)
{
    if (!m_logosAPI) return;
    m_logosAPI->getClient(kModule)->call(method, args);
}

void AgoraBridge::registerAgent(const QString &stakeNom, const QStringList &caps)
{ callBackend("registerAgent", {stakeNom, caps}); }

void AgoraBridge::getAgentStatus()
{ callBackend("getAgentStatus"); }

void AgoraBridge::loadMarketplace()
{ callBackend("loadMarketplace"); }

void AgoraBridge::broadcastCapabilities(const QVariantList &services)
{ callBackend("broadcastCapabilities", {services}); }

void AgoraBridge::broadcastIntent(const QString &cat, const QString &task,
    const QString &budget, const QString &maxPrice, int maxLatency, double minRep)
{ callBackend("broadcastIntent", {cat, task, budget, maxPrice, maxLatency, minRep}); }

void AgoraBridge::acceptOffer(const QString &sid, const QString &seller,
    const QString &price, const QString &hash)
{ callBackend("acceptOffer", {sid, seller, price, hash}); }

void AgoraBridge::verifyAndRelease(const QString &escrow, const QString &cid, const QString &hash)
{ callBackend("verifyAndRelease", {escrow, cid, hash}); }

void AgoraBridge::evaluateIntent(const QVariantMap &intent)
{ callBackend("evaluateIntent", {intent}); }

void AgoraBridge::sendOffer(const QString &sid, const QString &buyer, const QString &capId,
    const QString &price, int units, const QString &total, const QString &hashCommit)
{ callBackend("sendOffer", {sid, buyer, capId, price, units, total, hashCommit}); }

void AgoraBridge::executeTask(const QString &sid, const QString &task,
    const QString &cat, const QString &escrow)
{ callBackend("executeTask", {sid, task, cat, escrow}); }

void AgoraBridge::getWalletState()  { callBackend("getWalletState"); }
void AgoraBridge::getTradeHistory() { callBackend("getTradeHistory"); }
void AgoraBridge::subscribeFeed()   { callBackend("subscribeFeed"); }
void AgoraBridge::unsubscribeFeed() { callBackend("unsubscribeFeed"); }

void AgoraBridge::copyToClipboard(const QString &text)
{ if (auto *cb = QGuiApplication::clipboard()) cb->setText(text); }

QString AgoraBridge::fmtAgo(qint64 ts)
{
    qint64 s = (QDateTime::currentMSecsSinceEpoch() - ts) / 1000;
    if (s < 60)   return QString::number(s) + "s ago";
    if (s < 3600) return QString::number(s/60) + "m ago";
    return QString::number(s/3600) + "h ago";
}

void AgoraBridge::checkNodeStatus() { callBackend("checkNodeStatus"); }
