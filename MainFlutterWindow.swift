import Cocoa
import AVFoundation
import FlutterMacOS
import MultipeerConnectivity

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)
    registerCameraBridge(for: flutterViewController)
    registerSensorBridge(for: flutterViewController)

    super.awakeFromNib()
  }

  private func registerSensorBridge(for controller: FlutterViewController) {
    let receiver = MacSensorReceiver()
    let events = FlutterEventChannel(
      name: "telestronomy/sensors",
      binaryMessenger: controller.engine.binaryMessenger
    )
    events.setStreamHandler(receiver)

    let methods = FlutterMethodChannel(
      name: "telestronomy/sensors",
      binaryMessenger: controller.engine.binaryMessenger
    )
    methods.setMethodCallHandler { call, result in
      switch call.method {
      case "startReceiver":
        receiver.start()
        result(nil)
      case "stopReceiver":
        receiver.stop()
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private func registerCameraBridge(for controller: FlutterViewController) {
    let channel = FlutterMethodChannel(
      name: "telestronomy/camera",
      binaryMessenger: controller.engine.binaryMessenger
    )

    channel.setMethodCallHandler { call, result in
      guard call.method == "listVideoDevices" else {
        result(FlutterMethodNotImplemented)
        return
      }

      let authorization = AVCaptureDevice.authorizationStatus(for: .video)
      if authorization == .denied || authorization == .restricted {
        result([])
        return
      }

      if authorization == .notDetermined {
        AVCaptureDevice.requestAccess(for: .video) { granted in
          DispatchQueue.main.async {
            result(granted ? Self.videoDevicePayload() : [])
          }
        }
        return
      }

      result(Self.videoDevicePayload())
    }
  }

  private static func videoDevicePayload() -> [[String: String]] {
    let discoverySession = AVCaptureDevice.DiscoverySession(
      deviceTypes: [.externalUnknown],
      mediaType: .video,
      position: .unspecified
    )
    return discoverySession.devices.map { device in
      [
        "name": device.localizedName,
        "uniqueId": device.uniqueID,
        "modelId": device.modelID,
        "manufacturer": device.manufacturer,
      ]
    }
  }
}

private final class MacSensorReceiver: NSObject, MCNearbyServiceBrowserDelegate, MCSessionDelegate, FlutterStreamHandler {
  private let peerId = MCPeerID(displayName: Host.current().localizedName ?? "Mac")
  private lazy var session = MCSession(peer: peerId, securityIdentity: nil, encryptionPreference: .required)
  private lazy var browser = MCNearbyServiceBrowser(peer: peerId, serviceType: "telesensor")
  private var sink: FlutterEventSink?

  override init() {
    super.init()
    browser.delegate = self
    session.delegate = self
  }

  func start() {
    browser.startBrowsingForPeers()
  }

  func stop() {
    browser.stopBrowsingForPeers()
    session.disconnect()
  }

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    sink = events
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    sink = nil
    return nil
  }

  func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String : String]?) {
    browser.invitePeer(peerID, to: session, withContext: nil, timeout: 15)
  }

  func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {}
  func browser(_ browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: Error) {
    sink?(["kind": "bridgeError", "message": error.localizedDescription])
  }

  func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
    sink?(["kind": "connection", "connected": state == .connected, "peer": peerID.displayName])
  }

  func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
    guard let object = try? JSONSerialization.jsonObject(with: data),
          var packet = object as? [String: Any] else { return }
    packet["kind"] = "sensorPacket"
    packet["peer"] = peerID.displayName
    DispatchQueue.main.async { [weak self] in
      self?.sink?(packet)
    }
  }

  func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {}
  func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {}
  func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {}
}
