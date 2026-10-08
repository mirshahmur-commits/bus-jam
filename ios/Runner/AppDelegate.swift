import Flutter
import UIKit
import StoreKit
import GameKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var store: BusJamStore?
  private var rankings: BusSurgeRankings?
  override func application(_ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "BusJamVerifiedStore") {
      store = BusJamStore(messenger: registrar.messenger())
    }
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "BusSurgeRankings") {
      rankings = BusSurgeRankings(messenger: registrar.messenger())
    }
  }
}

@MainActor final class BusSurgeRankings: NSObject, GKGameCenterControllerDelegate {
  private let channel: FlutterMethodChannel
  private var showing = false
  init(messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(name: "com.systemcraft.busjam/rankings", binaryMessenger: messenger)
    super.init()
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self = self, let args = call.arguments as? [String: Any],
        let id = args["leaderboard"] as? String, !id.isEmpty else { result(false); return }
      Task { @MainActor in
        switch call.method {
        case "submit":
          // Passive submission never interrupts play with a sign-in prompt.
          guard GKLocalPlayer.local.isAuthenticated else { result(false); return }
          self.submit(args, id: id) { ok in result(ok) }
        case "show":
          guard !self.showing else { result(false); return }
          self.showing = true
          self.authenticate { [weak self] authenticated in
            guard let self = self else { result(false); return }
            guard authenticated else { self.showing = false; result(false); return }
            self.submit(args, id: id) { _ in
              guard let host = self.host() else { self.showing = false; result(false); return }
              let view = GKGameCenterViewController(leaderboardID: id, playerScope: .global, timeScope: .allTime)
              view.gameCenterDelegate = self
              host.present(view, animated: true) { result(true) }
            }
          }
        default: result(FlutterMethodNotImplemented)
        }
      }
    }
  }
  private func host() -> UIViewController? {
    var controller = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
      .flatMap { $0.windows }.first { $0.isKeyWindow }?.rootViewController
    while let presented = controller?.presentedViewController { controller = presented }
    return controller
  }
  private func authenticate(completion: @escaping (Bool) -> Void) {
    if GKLocalPlayer.local.isAuthenticated { completion(true); return }
    var completed = false
    GKLocalPlayer.local.authenticateHandler = { [weak self] view, error in
      Task { @MainActor in
        if let view = view {
          guard let host = self?.host() else { if !completed { completed = true; completion(false) }; return }
          host.present(view, animated: true)
        } else if !completed {
          completed = true
          completion(error == nil && GKLocalPlayer.local.isAuthenticated)
        }
      }
    }
  }
  private func submit(_ args: [String: Any], id: String, completion: @escaping (Bool) -> Void) {
    guard let score = args["score"] as? Int, score >= 0 && score <= 2000,
      let seed = args["seed"] as? Int, seed >= 20000101 && seed <= 99991231 else { completion(false); return }
    GKLeaderboard.submitScore(score, context: seed, player: GKLocalPlayer.local, leaderboardIDs: [id]) { error in
      DispatchQueue.main.async { completion(error == nil) }
    }
  }
  func gameCenterViewControllerDidFinish(_ gameCenterViewController: GKGameCenterViewController) {
    gameCenterViewController.dismiss(animated: true)
    showing = false
  }
}

/// Grants entitlement only for StoreKit 2 verified non-consumable transactions.
@MainActor final class BusJamStore {
  private let id = "com.systemcraft.busJam.remove_ads"
  private let channel: FlutterMethodChannel
  private var updates: Task<Void, Never>?
  private var purchasing = false
  init(messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(name: "com.systemcraft.busjam/store", binaryMessenger: messenger)
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else { result(FlutterError(code: "disposed", message: nil, details: nil)); return }
      Task { @MainActor in
        do {
          switch call.method {
          case "price": result(try await Product.products(for: [self.id]).first?.displayPrice)
          case "entitlement": result(await self.entitled())
          case "restore":
            try await AppStore.sync()
            result(await self.entitled())
          case "purchase":
            guard !self.purchasing else { result("pending"); return }
            self.purchasing = true
            defer { self.purchasing = false }
            guard let product = try await Product.products(for: [self.id]).first else { result("unavailable"); return }
            switch try await product.purchase() {
            case .success(let verification):
              guard case .verified(let transaction) = verification,
                transaction.productID == self.id, transaction.revocationDate == nil else {
                result(FlutterError(code: "unverified", message: "Purchase verification failed", details: nil)); return
              }
              await transaction.finish()
              result("purchased")
            case .userCancelled: result("cancelled")
            case .pending: result("pending")
            @unknown default: result("error")
            }
          default: result(FlutterMethodNotImplemented)
          }
        } catch { result(FlutterError(code: "store_unavailable", message: error.localizedDescription, details: nil)) }
      }
    }
    updates = Task { [weak self] in
      for await verification in Transaction.updates {
        guard let self = self else { return }
        if case .verified(let transaction) = verification, transaction.productID == self.id {
          self.channel.invokeMethod("entitlementChanged", arguments: await self.entitled())
          await transaction.finish()
        }
      }
    }
  }
  private func entitled() async -> Bool {
    for await verification in Transaction.currentEntitlements {
      if case .verified(let transaction) = verification,
        transaction.productID == id, transaction.revocationDate == nil { return true }
    }
    return false
  }
  deinit { updates?.cancel() }
}
