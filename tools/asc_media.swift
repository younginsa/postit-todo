import Foundation
import CryptoKit

// 스크린샷/프리뷰 업로더
// usage: swift asc_media.swift screenshot <locId> <displayType> <file...>
struct ASCConfig: Decodable { let keyId: String; let issuerId: String }
let cfgPath = NSString(string: "~/.appstoreconnect/asc_config.json").expandingTildeInPath
let cfg = try! JSONDecoder().decode(ASCConfig.self, from: FileManager.default.contents(atPath: cfgPath)!)
let keyID = cfg.keyId
let issuerID = cfg.issuerId
let keyPath = NSString(string: "~/.appstoreconnect/private_keys/AuthKey_\(cfg.keyId).p8").expandingTildeInPath

func b64url(_ d: Data) -> String {
    d.base64EncodedString().replacingOccurrences(of: "+", with: "-")
        .replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "")
}
func jwt() -> String {
    let pem = try! String(contentsOfFile: keyPath, encoding: .utf8)
    let key = try! P256.Signing.PrivateKey(pemRepresentation: pem)
    let header = #"{"alg":"ES256","kid":"\#(keyID)","typ":"JWT"}"#
    let now = Int(Date().timeIntervalSince1970)
    let payload = #"{"iss":"\#(issuerID)","iat":\#(now),"exp":\#(now + 1100),"aud":"appstoreconnect-v1"}"#
    let input = b64url(header.data(using: .utf8)!) + "." + b64url(payload.data(using: .utf8)!)
    let sig = try! key.signature(for: SHA256.hash(data: input.data(using: .utf8)!))
    return input + "." + b64url(sig.rawRepresentation)
}

@discardableResult
func api(_ method: String, _ path: String, _ body: [String: Any]? = nil) -> [String: Any] {
    var req = URLRequest(url: URL(string: "https://api.appstoreconnect.apple.com" + path)!)
    req.httpMethod = method
    req.setValue("Bearer \(jwt())", forHTTPHeaderField: "Authorization")
    req.setValue("application/json", forHTTPHeaderField: "Content-Type")
    if let body { req.httpBody = try! JSONSerialization.data(withJSONObject: body) }
    var out: [String: Any] = [:]
    let sema = DispatchSemaphore(value: 0)
    URLSession.shared.dataTask(with: req) { data, resp, err in
        if let err { print("NET ERR:", err) }
        if let http = resp as? HTTPURLResponse, http.statusCode >= 400 {
            print("HTTP \(http.statusCode) \(method) \(path)")
            if let data { print(String(data: data, encoding: .utf8) ?? "") }
        }
        if let data, let j = try? JSONSerialization.jsonObject(with: data) as? [String: Any] { out = j }
        sema.signal()
    }.resume()
    sema.wait()
    return out
}

func rawPut(_ urlStr: String, headers: [[String: Any]], data: Data) {
    var req = URLRequest(url: URL(string: urlStr)!)
    req.httpMethod = "PUT"
    for h in headers {
        if let n = h["name"] as? String, let v = h["value"] as? String {
            req.setValue(v, forHTTPHeaderField: n)
        }
    }
    let sema = DispatchSemaphore(value: 0)
    URLSession.shared.uploadTask(with: req, from: data) { _, resp, err in
        if let err { print("UPLOAD ERR:", err) }
        if let http = resp as? HTTPURLResponse, http.statusCode >= 300 { print("UPLOAD HTTP \(http.statusCode)") }
        sema.signal()
    }.resume()
    sema.wait()
}

func md5hex(_ d: Data) -> String {
    Insecure.MD5.hash(data: d).map { String(format: "%02x", $0) }.joined()
}

func uploadAsset(reservePath: String, reserveType: String, setType: String, setID: String, file: String) {
    let url = URL(fileURLWithPath: file)
    let data = try! Data(contentsOf: url)
    let name = url.lastPathComponent
    let reserve = api("POST", reservePath, [
        "data": [
            "type": reserveType,
            "attributes": ["fileName": name, "fileSize": data.count],
            "relationships": [setType: ["data": ["type": setType == "appScreenshotSet" ? "appScreenshotSets" : "appPreviewSets", "id": setID]]]
        ]
    ])
    guard let d = reserve["data"] as? [String: Any],
          let id = d["id"] as? String,
          let attrs = d["attributes"] as? [String: Any],
          let ops = attrs["uploadOperations"] as? [[String: Any]] else {
        print("RESERVE FAILED for \(name)"); return
    }
    for op in ops {
        let offset = op["offset"] as? Int ?? 0
        let length = op["length"] as? Int ?? data.count
        let chunk = data.subdata(in: offset..<min(offset + length, data.count))
        rawPut(op["url"] as! String, headers: op["requestHeaders"] as? [[String: Any]] ?? [], data: chunk)
    }
    api("PATCH", "/v1/\(reserveType)/\(id)", [
        "data": ["type": reserveType, "id": id,
                 "attributes": ["uploaded": true, "sourceFileChecksum": md5hex(data)]]
    ])
    print("UPLOADED \(name) id=\(id)")
}

let args = CommandLine.arguments
let kind = args[1], versionID = args[2], typeName = args[3]
let files = Array(args.dropFirst(4))

if kind == "screenshot" {
    var setID = ""
    let existing = api("GET", "/v1/appStoreVersionLocalizations/\(versionID)/appScreenshotSets?filter[screenshotDisplayType]=\(typeName)")
    if let arr = existing["data"] as? [[String: Any]], let first = arr.first, let id = first["id"] as? String {
        setID = id
    } else {
        let created = api("POST", "/v1/appScreenshotSets", [
            "data": ["type": "appScreenshotSets",
                     "attributes": ["screenshotDisplayType": typeName],
                     "relationships": ["appStoreVersionLocalization": ["data": ["type": "appStoreVersionLocalizations", "id": versionID]]]]
        ])
        setID = (created["data"] as? [String: Any])?["id"] as? String ?? ""
    }
    guard !setID.isEmpty else { print("NO SET"); exit(1) }
    print("SET \(setID)")
    for f in files {
        uploadAsset(reservePath: "/v1/appScreenshots", reserveType: "appScreenshots",
                    setType: "appScreenshotSet", setID: setID, file: f)
    }
}
