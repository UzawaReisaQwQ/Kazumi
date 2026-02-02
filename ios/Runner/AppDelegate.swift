import UIKit
import Flutter
import AVKit
import MediaPlayer
import AVFoundation

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {

    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        setupAudioSession()
        becomeFirstResponder()
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }

    override func applicationDidBecomeActive(_ application: UIApplication) {
        application.beginReceivingRemoteControlEvents()
    }

    override var canBecomeFirstResponder: Bool {
        return true
    }

    func setupAudioSession() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .moviePlayback, options: [])
        try? session.setActive(true)
    }

    func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
        GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

        let channel = FlutterMethodChannel(
            name: "com.predidit.kazumi/intent",
            binaryMessenger: engineBridge.applicationRegistrar.messenger()
        )
        channel.setMethodCallHandler { [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) in
            switch call.method {
                case "updateNowPlaying":
                    if let args = call.arguments as? [String: Any],
                    let title = args["title"] as? String,
                    let duration = args["duration"] as? Double,
                    let position = args["position"] as? Double,
                    let isPlaying = args["isPlaying"] as? Bool {
                        self?.updateNowPlayingInfo(title: title, duration: duration, position: position, isPlaying: isPlaying)
                    }
                    result(nil)
                    
                case "setupRemoteCommands":
                    self?.setupRemoteCommandCenter(
                        playCallback: {
                            channel.invokeMethod("remotePlay", arguments: nil)
                        },
                        pauseCallback: {
                            channel.invokeMethod("remotePause", arguments: nil)
                        },
                        seekCallback: { position in
                            channel.invokeMethod("remoteSeek", arguments: position)
                        }
                    )
                    result(nil)
                case "openWithReferer":
                    if let myArgs = call.arguments as? [String: Any],
                        let url = myArgs["url"] as? String,
                        let referer = myArgs["referer"] as? String {
                            self?.openVideoWithReferer(url: url, referer: referer)
                    }
                    result(nil)
                default:
                    result(FlutterMethodNotImplemented)
            }
        }
    }

    func updateNowPlayingInfo(title: String, duration: Double, position: Double, isPlaying: Bool) {
        DispatchQueue.main.async {
            var nowPlayingInfo: [String: Any] = [
                MPMediaItemPropertyTitle: title,
                MPMediaItemPropertyPlaybackDuration: duration,
                MPNowPlayingInfoPropertyElapsedPlaybackTime: position,
                MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1.0 : 0.0
            ]

            MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
        }
    }

    func setupRemoteCommandCenter(playCallback: @escaping () -> Void,
                                pauseCallback: @escaping () -> Void,
                                seekCallback: @escaping (Double) -> Void) {

        let commandCenter = MPRemoteCommandCenter.shared()

        commandCenter.playCommand.removeTarget(nil)
        commandCenter.pauseCommand.removeTarget(nil)
        commandCenter.changePlaybackPositionCommand.removeTarget(nil)

        commandCenter.playCommand.isEnabled = true
        commandCenter.pauseCommand.isEnabled = true
        commandCenter.changePlaybackPositionCommand.isEnabled = true

        commandCenter.playCommand.addTarget { _ in
            playCallback()
            return .success
        }

        commandCenter.pauseCommand.addTarget { _ in
            pauseCallback()
            return .success
        }

        commandCenter.changePlaybackPositionCommand.addTarget { event in
            if let positionEvent = event as? MPChangePlaybackPositionCommandEvent {
                seekCallback(positionEvent.positionTime)
                return .success
            }
            return .commandFailed
        }
    }

    // TODO: ADD VLC SUPPORT
    // VLC can be downloaded from iOS App Store, but don't know how to build selectable app lists, while checking if it is installled.
    // VLC supports more video formats than AVPlayer but does not support referer while AVPlayer does
    private func openVideoWithReferer(url: String, referer: String) {
        guard let videoUrl = URL(string: url) else { return }

        let headers: [String: String] = [
            "Referer": referer,
        ]
        let asset = AVURLAsset(url: videoUrl, options: ["AVURLAssetHTTPHeaderFieldsKey": headers])
        let playerItem = AVPlayerItem(asset: asset)
        let player = AVPlayer(playerItem: playerItem)
        let playerViewController = AVPlayerViewController()
        playerViewController.player = player
        playerViewController.videoGravity = AVLayerVideoGravity.resizeAspect

        // Use UIScene API instead of deprecated keyWindow
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            return
        }

        rootViewController.present(playerViewController, animated: true) {
            playerViewController.player?.play()
        }

//        guard let appURL = URL(string: "vlc-x-callback://x-callback-url/stream?url=" + url) else {
//            return
//        }
//        if UIApplication.shared.canOpenURL(appURL) && referer.isEmpty {
//            UIApplication.shared.open(appURL, options: [:], completionHandler: nil)
//        }
    }
}
