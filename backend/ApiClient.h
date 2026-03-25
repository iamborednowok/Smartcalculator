#pragma once
#include <QObject>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QTimer>
#include <QtQml/qqmlregistration.h>

class ApiClient : public QObject {
    Q_OBJECT
    QML_ELEMENT
    Q_PROPERTY(bool loading READ loading NOTIFY loadingChanged)
public:
    explicit ApiClient(QObject *parent = nullptr);

    bool loading() const { return m_loading; }

    Q_INVOKABLE void sendToAI(const QString &systemPrompt,
                              const QVariantList &messages,
                              const QString &apiKey,
                              const QString &model);
    Q_INVOKABLE void cancel();

signals:
    void loadingChanged();
    void responseReceived(const QString &content, bool isError);

private slots:
    void onReplyFinished();

private:
    void setLoading(bool v);

    QNetworkAccessManager m_nam;
    QNetworkReply *m_reply = nullptr;
    QTimer        m_timeout;
    bool m_loading = false;
};
