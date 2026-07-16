import Foundation
import CryptoKit

// ASC API 호출기 — usage: swift asc.swift METHOD PATH [bodyfile]
// 인증 정보는 ~/.appstoreconnect/asc_config.json + AuthKey_<keyId>.p8 (저장소에 커밋 금지!)
struct ASCConfig: Decodable { let keyId: String; let issuerId: String }
let cfgPath = NSString(string: "~/.appstoreconnect/asc_config.json").expandingTildeInPath
guard let cfgData = FileManager.default.contents(atPath: cfgPath),
      let cfg = try? JSONDecoder().decode(ASCConfig.self, from: cfgData) else {
    print("설정 파일 없음: ~/.appstoreconnect/asc_config.json  ({\"keyId\":\"...\",\"issuerId\":\"...\"})")
    exit(1)
}
let keyPath = NSString(string: "~/.appstoreconnect/private_keys/AuthKey_\(cfg.keyId).p8").expandingTildeInPath

func b64url(_ d: Data) -> String {
    d.base64EncodedString().replacingOccurrences(of: "+", with: "-")
        .replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "")
}
func jwt() -> String {
    let pem = try! String(contentsOfFile: keyPath, encoding: .utf8)
    let key = try! P256.Signing.PrivateKey(pemRepresentation: pem)
    let header = #"{"alg":"ES256","kid":"\#(cfg.keyId)","typ":"JWT"}"#
    let now = Int(Date().timeIntervalSince1970)
    let payload = #"{"iss":"\#(cfg.issuerId)","iat":\#(now),"exp":\#(now + 1100),"aud":"appstoreconnect-v1"}"#
    let input = b64url(header.data(using: .utf8)!) + "." + b64url(payload.data(using: .utf8)!)
    let sig = try! key.signature(for: SHA256.hash(data: input.data(using: .utf8)!))
    return input + "." + b64url(sig.rawRepresentation)
}

let args = CommandLine.arguments
guard args.count >= 3 else { print("usage: asc.swift METHOD PATH [bodyfile]"); exit(1) }
let method = args[1], path = args[2]

var req = URLRequest(url: URL(string: "https://api.appstoreconnect.apple.com" + path)!)
req.httpMethod = method
req.setValue("Bearer \(jwt())", forHTTPHeaderField: "Authorization")
req.setValue("application/json", forHTTPHeaderField: "Content-Type")
if args.count >= 4 {
    req.httpBody = try! Data(contentsOf: URL(fileURLWithPath: args[3]))
}

let sema = DispatchSemaphore(value: 0)
URLSession.shared.dataTask(with: req) { data, resp, err in
    if let err { print("NET ERR:", err) }
    if let http = resp as? HTTPURLResponse { print("HTTP \(http.statusCode)") }
    if let data, !data.isEmpty,
       let obj = try? JSONSerialization.jsonObject(with: data),
       let pretty = try? JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted, .sortedKeys]) {
        print(String(data: pretty, encoding: .utf8) ?? "")
    }
    sema.signal()
}.resume()
sema.wait()
