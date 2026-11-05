import SwiftUI
import UIKit
import UniformTypeIdentifiers
import UserNotifications
import WebKit

/// Affiche l'application de gestion de tournoi (index.html embarqué, 100 % hors ligne)
/// et relie la page aux fonctions natives : sauvegarde, partage, presse-papiers, fichiers, haptique.
struct TournamentWebView: UIViewRepresentable {
    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> WKWebView {
        let controller = WKUserContentController()
        controller.addUserScript(WKUserScript(source: Bridge.startScript(saved: TournamentStore.load()),
                                              injectionTime: .atDocumentStart, forMainFrameOnly: true))
        controller.addUserScript(WKUserScript(source: Bridge.endScript,
                                              injectionTime: .atDocumentEnd, forMainFrameOnly: true))
        controller.add(context.coordinator, name: Bridge.handler)

        let config = WKWebViewConfiguration()
        config.userContentController = controller
        config.websiteDataStore = .default()
        config.dataDetectorTypes = []

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.allowsLinkPreview = false
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        context.coordinator.webView = webView

        if let url = Bundle.main.url(forResource: "index", withExtension: "html") {
            webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
        }
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    final class Coordinator: NSObject, WKScriptMessageHandler, WKNavigationDelegate, WKUIDelegate, UIDocumentPickerDelegate, UNUserNotificationCenterDelegate {
        weak var webView: WKWebView?
        private let haptic = UINotificationFeedbackGenerator()
        private var pdfJob: PDFExporter?
        private enum Pick { case backup, rankings }
        private var pick = Pick.backup

        override init() {
            super.init()
            UNUserNotificationCenter.current().delegate = self
        }

        // Rappel affiché même si l'application est ouverte au premier plan
        func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification,
                                    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
            completionHandler([.banner, .list, .sound])
        }

        // MARK: Messages envoyés par la page
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard let body = message.body as? [String: Any], let type = body["type"] as? String else { return }
            switch type {
            case "save":
                if let data = body["data"] as? String { TournamentStore.save(data) }
            case "copy":
                UIPasteboard.general.string = body["text"] as? String ?? ""
            case "share":
                present(items: [body["text"] as? String ?? ""])
            case "exportFile":
                if let data = body["data"] as? String, let url = TournamentStore.exportFile(data) {
                    present(items: [url])
                }
            case "pickFile":
                pick = .backup
                let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.json, .plainText, .text])
                picker.delegate = self
                topViewController()?.present(picker, animated: true)
            case "pickRankings":
                // Classements FFT : l'utilisateur choisit lui-même les PDF « Dames » et « Messieurs » (aucun accès réseau)
                pick = .rankings
                let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.pdf], asCopy: true)
                picker.allowsMultipleSelection = true
                picker.delegate = self
                topViewController()?.present(picker, animated: true)
            case "notifyAuth":
                // Autorisation demandée seulement quand l'utilisateur active les rappels (et jamais exigée)
                UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, _ in
                    self.sendNotifStatus(granted ? "granted" : "denied")
                }
            case "notifyStatus":
                UNUserNotificationCenter.current().getNotificationSettings { s in
                    switch s.authorizationStatus {
                    case .denied: self.sendNotifStatus("denied")
                    case .authorized, .provisional, .ephemeral: self.sendNotifStatus("granted")
                    default: self.sendNotifStatus("unknown")
                    }
                }
            case "notify":
                if let scope = body["scope"] as? String, let items = body["items"] as? [[String: Any]] {
                    scheduleNotifications(scope: scope, items: items)
                }
            case "openSettings":
                if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
            case "kiosk":
                // Affichage public : écran toujours allumé, barre d'état et indicateur masqués
                let on = body["on"] as? Bool ?? false
                UIApplication.shared.isIdleTimerDisabled = on
                AppState.shared.kiosk = on
            case "pdf":
                if let html = body["html"] as? String, let host = topViewController()?.view {
                    let name = (body["name"] as? String) ?? "tournoi.pdf"
                    pdfJob = PDFExporter(html: html, name: name, host: host) { [weak self] url in
                        self?.pdfJob = nil
                        if let url = url { self?.present(items: [url]) }
                        else { self?.webView?.evaluateJavaScript("toast('Export PDF impossible.')") }
                    }
                }
            case "haptic":
                let kind = body["kind"] as? String
                haptic.notificationOccurred(kind == "error" ? .error : kind == "warning" ? .warning : .success)
            default:
                break
            }
        }

        // MARK: Import d'une sauvegarde depuis Fichiers
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            if pick == .rankings { readRankings(urls); return }
            guard let url = urls.first else { return }
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            guard let text = try? String(contentsOf: url, encoding: .utf8) else { return }
            webView?.evaluateJavaScript("window.__btImport(\(Bridge.jsString(text)))")
        }

        private func readRankings(_ urls: [URL]) {
            DispatchQueue.global(qos: .userInitiated).async {
                var results: [(name: String, result: RankingPDF.Result)] = []
                for url in urls {
                    if let r = RankingPDF.parse(url: url) { results.append((url.lastPathComponent, r)) }
                }
                let json = RankingPDF.json(for: results)
                DispatchQueue.main.async {
                    self.webView?.evaluateJavaScript("window.__btRanks && window.__btRanks(\(json), \(urls.count))")
                }
            }
        }

        // MARK: Liens externes (WhatsApp, Ten'Up) : ouverts hors de l'app
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                     decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            if let url = navigationAction.request.url, url.scheme != "file", url.scheme != "about" {
                UIApplication.shared.open(url)
                decisionHandler(.cancel)
            } else {
                decisionHandler(.allow)
            }
        }

        func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                     for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
            if let url = navigationAction.request.url { UIApplication.shared.open(url) }
            return nil
        }

        // La page est rechargée si iOS a tué le processus web en arrière-plan
        func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
            webView.reload()
        }

        // MARK: Rappels de match (notifications locales)
        private func sendNotifStatus(_ status: String) {
            DispatchQueue.main.async {
                self.webView?.evaluateJavaScript("window.__btNotif && window.__btNotif(\(Bridge.jsString(status)))")
            }
        }

        /// Remplace les rappels en attente d'un tournoi (identifiants « scope:match »), sans toucher aux autres tournois.
        private func scheduleNotifications(scope: String, items: [[String: Any]]) {
            let center = UNUserNotificationCenter.current()
            center.getPendingNotificationRequests { pending in
                let old = pending.map(\.identifier).filter { $0.hasPrefix(scope + ":") }
                center.removePendingNotificationRequests(withIdentifiers: old)
                let now = Date().timeIntervalSince1970
                for item in items.prefix(30) {
                    guard let id = item["id"] as? String, let ts = item["ts"] as? Double, ts - now > 1 else { continue }
                    let content = UNMutableNotificationContent()
                    content.title = item["title"] as? String ?? "Match"
                    content.body = item["body"] as? String ?? ""
                    content.sound = .default
                    let trigger = UNTimeIntervalNotificationTrigger(timeInterval: ts - now, repeats: false)
                    center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
                }
            }
        }

        // MARK: Présentation
        private func present(items: [Any]) {
            guard let top = topViewController() else { return }
            let sheet = UIActivityViewController(activityItems: items, applicationActivities: nil)
            if let pop = sheet.popoverPresentationController { // iPad
                pop.sourceView = top.view
                pop.sourceRect = CGRect(x: top.view.bounds.midX, y: top.view.bounds.maxY - 80, width: 1, height: 1)
            }
            top.present(sheet, animated: true)
        }

        private func topViewController() -> UIViewController? {
            let root = UIApplication.shared.connectedScenes
                .compactMap { ($0 as? UIWindowScene)?.keyWindow }
                .first?.rootViewController
            var top = root
            while let next = top?.presentedViewController { top = next }
            return top
        }
    }
}

/// Scripts injectés dans la page. Ils n'altèrent pas le moteur du tournoi :
/// ils remplacent seulement les API web peu fiables dans une app (stockage, partage, presse-papiers).
enum Bridge {
    static let handler = "bt"

    static func jsString(_ s: String) -> String {
        guard let data = try? JSONEncoder().encode(s), let lit = String(data: data, encoding: .utf8) else { return "\"\"" }
        return lit
    }

    static func startScript(saved: String?) -> String {
        """
        (function(){
          var KEY=\(jsString(TournamentStore.storageKey)), saved=\(saved.map(jsString) ?? "null");
          var post=function(m){try{window.webkit.messageHandlers.\(handler).postMessage(m)}catch(e){}};
          window.__btPost=post;
          // Stockage : la copie native fait foi ; repli en mémoire si localStorage est indisponible
          var ls=null;try{ls=window.localStorage;ls.setItem('__t','1');ls.removeItem('__t')}catch(e){ls=null}
          if(!ls){var mem={};ls={getItem:function(k){return k in mem?mem[k]:null},setItem:function(k,v){mem[k]=String(v)},removeItem:function(k){delete mem[k]}};
            try{Object.defineProperty(window,'localStorage',{value:ls,configurable:true})}catch(e){}}
          if(saved!==null){try{ls.setItem(KEY,saved)}catch(e){}}
          // (affecter localStorage.setItem créerait une clé : on patche le prototype Storage)
          var host=(typeof Storage!=='undefined'&&ls instanceof Storage)?Storage.prototype:ls,set=host.setItem;
          host.setItem=function(k,v){set.call(this,k,v);if(this===ls&&k===KEY)post({type:'save',data:String(v)})};
          // Partage et presse-papiers natifs
          Object.defineProperty(navigator,'share',{configurable:true,value:function(d){post({type:'share',text:(d&&d.text)||''});return Promise.resolve()}});
          Object.defineProperty(navigator,'clipboard',{configurable:true,value:{writeText:function(t){post({type:'copy',text:String(t)});return Promise.resolve()}}});
        })();
        """
    }

    static let endScript = """
    (function(){
      var post=window.__btPost;
      var css=document.createElement('style');
      css.textContent='html{-webkit-tap-highlight-color:transparent}button,nav,.match,.bm{-webkit-touch-callout:none;-webkit-user-select:none;user-select:none}';
      document.head.appendChild(css);
      if(typeof ACT==='undefined')return;
      // Retour haptique sur chaque message de confirmation
      var t0=toast;toast=function(m){var ok=/enregistré|créé|importée?s?|copiée?|archivé\\.|réactivé|supprimé|mise à jour|recalculée|effectué|réinitialisé|départagées|importées?|Préparation/i.test(String(m));
        post({type:'haptic',kind:ok?'success':'warning'});return t0(m)};
      // Sauvegarde en fichier (Fichiers, AirDrop, mail) et ouverture d'un fichier de sauvegarde
      var exp=ACT.exportDB;ACT.exportDB=function(){exp();post({type:'exportFile',data:UI.bk})};
      ACT.pickFile=function(){post({type:'pickFile'})};
      window.__btImport=function(text){UI.lib=true;UI.imp=text;UI.confirm=null;render();ACT.importDB()};
      var lib=libHtml;libHtml=function(){return lib()
        .replace('Les données restent dans ce navigateur. Exporte-les pour les conserver ou les ouvrir sur un autre appareil.','Les données sont enregistrées sur cet appareil. Exporte un fichier de sauvegarde pour les conserver ou les ouvrir sur un autre iPhone.')
        .replace('data-act="exportDB">Exporter</button>','data-act="exportDB">Exporter un fichier</button><button class="btn" data-act="pickFile">Ouvrir un fichier</button>')};
      render();
    })();
    """
}

/// Convertit le document HTML d'impression en PDF A4 paysage (plusieurs pages) avec le moteur d'impression d'iOS.
final class PDFExporter: NSObject, WKNavigationDelegate {
    private let webView: WKWebView
    private let fileName: String
    private var completion: ((URL?) -> Void)?
    private var keepAlive: PDFExporter?

    private final class A4Renderer: UIPrintPageRenderer {
        override var paperRect: CGRect { CGRect(x: 0, y: 0, width: 841.89, height: 595.28) }
        override var printableRect: CGRect { paperRect.insetBy(dx: 28, dy: 28) }
    }

    init(html: String, name: String, host: UIView, completion: @escaping (URL?) -> Void) {
        let config = WKWebViewConfiguration()
        config.defaultWebpagePreferences.allowsContentJavaScript = false
        webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 786, height: 540), configuration: config)
        fileName = name.replacingOccurrences(of: "/", with: "-")
        self.completion = completion
        super.init()
        keepAlive = self
        webView.alpha = 0
        webView.isUserInteractionEnabled = false
        webView.navigationDelegate = self
        host.insertSubview(webView, at: 0)
        webView.loadHTMLString(html, baseURL: nil)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        // Laisse le temps de mettre la page en forme avant de la découper en pages
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { self.render() }
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) { finish(nil) }
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) { finish(nil) }

    private func render() {
        let renderer = A4Renderer()
        renderer.addPrintFormatter(webView.viewPrintFormatter(), startingAtPageAt: 0)
        let data = NSMutableData()
        UIGraphicsBeginPDFContextToData(data, renderer.paperRect, nil)
        let pages = renderer.numberOfPages
        renderer.prepare(forDrawingPages: NSRange(location: 0, length: pages))
        let bounds = UIGraphicsGetPDFContextBounds()
        for i in 0..<pages {
            UIGraphicsBeginPDFPage()
            renderer.drawPage(at: i, in: bounds)
        }
        UIGraphicsEndPDFContext()
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        do {
            try data.write(to: url, options: .atomic)
            finish(pages > 0 ? url : nil)
        } catch {
            finish(nil)
        }
    }

    private func finish(_ url: URL?) {
        webView.removeFromSuperview()
        completion?(url)
        completion = nil
        keepAlive = nil
    }
}
