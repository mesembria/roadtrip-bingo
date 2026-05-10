import Foundation
import MultipeerConnectivity

protocol MultipeerSessionDelegate: AnyObject {
    func multipeerSession(_ session: MultipeerSession, didReceive message: MultipeerMessage, from peerName: String)
    func multipeerSession(_ session: MultipeerSession, peerDidConnect peerName: String)
    func multipeerSession(_ session: MultipeerSession, peerDidDisconnect peerName: String)
    func multipeerSession(_ session: MultipeerSession, foundPeer peerName: String)
    func multipeerSession(_ session: MultipeerSession, lostPeer peerName: String)
}

final class MultipeerSession: NSObject {
    private let serviceType = "rtbingo"
    private let localPeer: MCPeerID
    private let mcSession: MCSession
    private var advertiser: MCNearbyServiceAdvertiser?
    private var browser: MCNearbyServiceBrowser?
    private var foundPeerIDs: [String: MCPeerID] = [:]

    weak var delegate: MultipeerSessionDelegate?

    var connectedPeerNames: [String] { mcSession.connectedPeers.map(\.displayName) }

    init(displayName: String) {
        self.localPeer = MCPeerID(displayName: displayName)
        self.mcSession = MCSession(peer: localPeer, securityIdentity: nil, encryptionPreference: .none)
        super.init()
        self.mcSession.delegate = self
    }

    // MARK: - Host side

    func startAdvertising() {
        advertiser = MCNearbyServiceAdvertiser(peer: localPeer, discoveryInfo: nil, serviceType: serviceType)
        advertiser?.delegate = self
        advertiser?.startAdvertisingPeer()
    }

    func stopAdvertising() {
        advertiser?.stopAdvertisingPeer()
        advertiser = nil
    }

    // MARK: - Joiner side

    func startBrowsing() {
        browser = MCNearbyServiceBrowser(peer: localPeer, serviceType: serviceType)
        browser?.delegate = self
        browser?.startBrowsingForPeers()
    }

    func stopBrowsing() {
        browser?.stopBrowsingForPeers()
        browser = nil
    }

    func invitePeer(named name: String) {
        guard let peer = foundPeerIDs[name] else { return }
        browser?.invitePeer(peer, to: mcSession, withContext: nil, timeout: 30)
    }

    // MARK: - Shared

    func send(_ message: MultipeerMessage) {
        guard !mcSession.connectedPeers.isEmpty,
              let data = try? JSONEncoder().encode(message) else { return }
        try? mcSession.send(data, toPeers: mcSession.connectedPeers, with: .reliable)
    }

    func disconnect() {
        stopAdvertising()
        stopBrowsing()
        mcSession.disconnect()
    }
}

// MARK: - MCSessionDelegate

extension MultipeerSession: MCSessionDelegate {
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        DispatchQueue.main.async {
            switch state {
            case .connected:
                self.delegate?.multipeerSession(self, peerDidConnect: peerID.displayName)
            case .notConnected:
                self.delegate?.multipeerSession(self, peerDidDisconnect: peerID.displayName)
            default:
                break
            }
        }
    }

    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        guard let message = try? JSONDecoder().decode(MultipeerMessage.self, from: data) else { return }
        DispatchQueue.main.async {
            self.delegate?.multipeerSession(self, didReceive: message, from: peerID.displayName)
        }
    }

    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {}
    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {}
    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {}
}

// MARK: - MCNearbyServiceAdvertiserDelegate

extension MultipeerSession: MCNearbyServiceAdvertiserDelegate {
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        invitationHandler(true, mcSession)
    }

    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: Error) {
        print("[MultipeerSession] Failed to start advertising: \(error)")
    }
}

// MARK: - MCNearbyServiceBrowserDelegate

extension MultipeerSession: MCNearbyServiceBrowserDelegate {
    func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String: String]?) {
        DispatchQueue.main.async {
            self.foundPeerIDs[peerID.displayName] = peerID
            self.delegate?.multipeerSession(self, foundPeer: peerID.displayName)
        }
    }

    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        DispatchQueue.main.async {
            self.foundPeerIDs.removeValue(forKey: peerID.displayName)
            self.delegate?.multipeerSession(self, lostPeer: peerID.displayName)
        }
    }

    func browser(_ browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: Error) {
        print("[MultipeerSession] Failed to start browsing: \(error)")
    }
}
