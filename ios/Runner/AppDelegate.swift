import UIKit
import Flutter
import AVKit
import AVFoundation
import MediaPlayer

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {

    private var mediaChannel: FlutterMethodChannel?

    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        UIApplication.shared.beginReceivingRemoteControlEvents()
        setupAudioSession()
        setupRemoteCommands()
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }

    private func setupAudioSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .moviePlayback, options: [.allowAirPlay, .allowBluetooth])
            try session.setActive(true)
        } catch {
            print("Failed to set audio session category: \(error)")
        }

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleInterruption),
            name: AVAudioSession.interruptionNotification,
            object: session
        )
    }

    @objc private func handleInterruption(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeRaw = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeRaw)
        else { return }

        if type == .began {
            mediaChannel?.invokeMethod("audio_interruption_began", arguments: nil)
        } else if type == .ended {
            mediaChannel?.invokeMethod("audio_interruption_ended", arguments: nil)
        }
    }

    private func setupRemoteCommands() {
        let commandCenter = MPRemoteCommandCenter.shared()

        commandCenter.playCommand.addTarget { [weak self] event in
            self?.mediaChannel?.invokeMethod("remote_play", arguments: nil)
            return .success
        }

        commandCenter.pauseCommand.addTarget { [weak self] event in
            self?.mediaChannel?.invokeMethod("remote_pause", arguments: nil)
            return .success
        }

        commandCenter.togglePlayPauseCommand.addTarget { [weak self] event in
            self?.mediaChannel?.invokeMethod("remote_togglePlayPause", arguments: nil)
            return .success
        }

        commandCenter.changePlaybackPositionCommand.addTarget { [weak self] event in
            if let e = event as? MPChangePlaybackPositionCommandEvent {
                self?.mediaChannel?.invokeMethod(
                    "remote_seek",
                    arguments: ["position": e.positionTime]
                )
                return .success
            }
            return .commandFailed
        }
    }

    private func updateNowPlayingInfo(args: [String: Any]) {
        var nowPlayingInfo = [String: Any]()

        if let title = args["title"] as? String {
            nowPlayingInfo[MPMediaItemPropertyTitle] = title
        }

        if let duration = args["duration"] as? Double {
            nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = duration
        }

        if let position = args["position"] as? Double {
            nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = position
        }

        if let playing = args["playing"] as? Bool {
            nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = playing ? 1.0 : 0.0
        }

        let center = MPNowPlayingInfoCenter.default()
        center.nowPlayingInfo = nowPlayingInfo
        center.playbackState = (nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] as? Double ?? 0) > 0
            ? .playing
            : .paused
    }

    func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
        GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

        self.mediaChannel = FlutterMethodChannel(
            name: "com.predidit.kazumi/intent",
            binaryMessenger: engineBridge.applicationRegistrar.messenger()
        )
        mediaChannel?.setMethodCallHandler { [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) in
            switch call.method {
                case "openWithReferer":
                    if let myArgs = call.arguments as? [String: Any],
                        let url = myArgs["url"] as? String,
                        let referer = myArgs["referer"] as? String {
                            self?.openVideoWithReferer(url: url, referer: referer)
                    }
                    result(nil)

                case "updateNowPlaying":
                    if let args = call.arguments as? [String: Any] {
                        self?.updateNowPlayingInfo(args: args)
                    }
                    result(nil)

                default:
                    result(FlutterMethodNotImplemented)
                }
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
